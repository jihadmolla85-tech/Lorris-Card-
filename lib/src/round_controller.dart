import 'dart:math';

import 'loris_card.dart';

/// Small adapter so the game can be driven by a UI, AI, Bluetooth or online host.
class DartRandomSource implements RandomSource {
  DartRandomSource([int? seed]) : _random = Random(seed);
  final Random _random;

  @override
  void shuffle<T>(List<T> values) => values.shuffle(_random);
}

enum RoundPhase { ready, bidding, trumpSelection, playing, roundComplete, matchComplete }

class LorisRoundController {
  LorisRoundController({
    required this.playerCount,
    required Map<int, LorisTeam> teamBySeat,
    required int dealerSeat,
    required this.matchScore,
    RandomSource? random,
  })  : teamBySeat = Map<int, LorisTeam>.unmodifiable(teamBySeat),
        random = random ?? DartRandomSource() {
    _validateTeams();
    if (dealerSeat < 0 || dealerSeat >= playerCount.value) {
      throw ArgumentError.value(dealerSeat, 'dealerSeat');
    }
    _dealerSeat = dealerSeat;
  }

  final PlayerCount playerCount;
  final Map<int, LorisTeam> teamBySeat;
  final LorisMatchScore matchScore;
  final RandomSource random;

  late int _dealerSeat;
  int get dealerSeat => _dealerSeat;
  RoundPhase phase = RoundPhase.ready;
  Deal? deal;
  BiddingRound<int?>? bidding;
  int? winningBidderSeat;
  int? contractBid;
  Suit? trumpSuit;
  int? currentPlayerSeat;
  int? trickLeaderSeat;
  Suit? ledSuit;
  final List<PlayedCard> currentTrick = <PlayedCard>[];
  final List<List<PlayedCard>> completedTricks = <List<PlayedCard>>[];
  TrickScoreTracker? trickScores;
  ContractScore? lastContractScore;
  int redealCount = 0;

  int get teamOneTricks => trickScores?.pointsFor(LorisTeam.teamOne) ?? 0;
  int get teamTwoTricks => trickScores?.pointsFor(LorisTeam.teamTwo) ?? 0;
  bool get isMatchOver => matchScore.winner != null;
  List<Card> handFor(int seat) => List<Card>.unmodifiable(deal?.hands[seat] ?? const <Card>[]);

  void _validateTeams() {
    if (teamBySeat.length != playerCount.value ||
        List<int>.generate(playerCount.value, (i) => i).any((i) => !teamBySeat.containsKey(i))) {
      throw ArgumentError('Provide one team for every seat.');
    }
    final one = teamBySeat.values.where((t) => t == LorisTeam.teamOne).length;
    final two = teamBySeat.values.where((t) => t == LorisTeam.teamTwo).length;
    if (one != playerCount.value ~/ 2 || two != playerCount.value ~/ 2) {
      throw ArgumentError('Teams must be balanced.');
    }
  }

  /// Deals and automatically redeals if the low-hand rule or all-pass rule applies.
  void startRound() {
    if (isMatchOver) {
      phase = RoundPhase.matchComplete;
      return;
    }
    do {
      deal = LorisDeck.deal(playerCount, dealerSeat: _dealerSeat, random: random);
      redealCount++;
    } while (LorisRedealRule.shouldRedeal(deal!));
    bidding = BiddingRound<int?>(playerCount: playerCount, deal: deal!, dealerSeat: _dealerSeat);
    winningBidderSeat = null;
    contractBid = null;
    trumpSuit = null;
    currentPlayerSeat = bidding!.nextPlayerToBid;
    trickLeaderSeat = null;
    ledSuit = null;
    currentTrick.clear();
    completedTricks.clear();
    trickScores = TrickScoreTracker(playerCount: playerCount, teamBySeat: teamBySeat);
    lastContractScore = null;
    phase = RoundPhase.bidding;
  }

  void submitBid({required int seat, int? bid}) {
    if (phase != RoundPhase.bidding) throw StateError('The game is not in bidding phase.');
    bidding!.submit(seat: seat, bid: bid);
    if (!bidding!.isComplete) {
      currentPlayerSeat = bidding!.nextPlayerToBid;
      return;
    }
    final submissions = bidding!.submissions;
    if (submissions.values.every((value) => value == null)) {
      startRound();
      return;
    }
    winningBidderSeat = BiddingWinner.selectHighestBidder(
      playerCount: playerCount,
      submissions: submissions,
    );
    contractBid = submissions[winningBidderSeat!];
    phase = RoundPhase.trumpSelection;
    currentPlayerSeat = winningBidderSeat;
  }

  void declareTrump({required int seat, required Suit suit}) {
    if (phase != RoundPhase.trumpSelection || seat != winningBidderSeat) {
      throw StateError('Only the winning bidder may declare trump now.');
    }
    final declaration = TrumpDeclaration.declare(
      playerCount: playerCount,
      winningPlayerSeat: seat,
      suit: suit,
      biddingComplete: bidding!.isComplete,
    );
    trumpSuit = declaration.suit;
    trickLeaderSeat = (_dealerSeat - 1 + playerCount.value) % playerCount.value;
    currentPlayerSeat = trickLeaderSeat;
    phase = RoundPhase.playing;
  }

  bool isLegalCard(int seat, Card card) {
    if (phase != RoundPhase.playing || seat != currentPlayerSeat) return false;
    final hand = deal!.hands[seat]!;
    if (!hand.contains(card)) return false;
    if (currentTrick.isEmpty) return true;
    return TrickRules.isLegalPlay(
      hand: hand,
      card: card,
      ledSuit: ledSuit!,
      trumpSuit: trumpSuit!,
      cardsAlreadyPlayed: currentTrick,
    );
  }

  void playCard({required int seat, required Card card}) {
    if (!isLegalCard(seat, card)) throw StateError('Illegal card or not this player\'s turn.');
    if (currentTrick.isEmpty) {
      // LORIS occupies the Spades low-rank slot; when it leads, Spades is led.
      ledSuit = card.isLoris ? Suit.spades : card.suit;
    }
    deal!.hands[seat]!.remove(card);
    currentTrick.add(PlayedCard(seat: seat, card: card));
    if (currentTrick.length < playerCount.value) {
      currentPlayerSeat = (seat - 1 + playerCount.value) % playerCount.value;
      return;
    }

    final trick = List<PlayedCard>.unmodifiable(currentTrick);
    final winner = TrickRules.winnerSeat(plays: trick, ledSuit: ledSuit!, trumpSuit: trumpSuit!);
    completedTricks.add(trick);
    trickScores!.recordTrickWinner(winner);
    currentTrick.clear();
    ledSuit = null;
    trickLeaderSeat = winner;
    currentPlayerSeat = winner;

    if (trickScores!.isComplete) _finishRound();
  }

  void _finishRound() {
    final bidderTeam = teamBySeat[winningBidderSeat!]!;
    final pointsTaken = bidderTeam == LorisTeam.teamOne ? teamOneTricks : teamTwoTricks;
    final dealerTeamIsOne = teamBySeat[_dealerSeat] == LorisTeam.teamOne;
    final previousDealerTeamScore = dealerTeamIsOne
        ? matchScore.teamOneScore
        : matchScore.teamTwoScore;
    final score = LorisContractScoring.score(
      bid: contractBid!,
      pointsTaken: pointsTaken,
      bidderTeamScore: bidderTeam == LorisTeam.teamOne ? matchScore.teamOneScore : matchScore.teamTwoScore,
    );
    lastContractScore = score;
    matchScore.applyContractScore(score: score, bidderIsTeamOne: bidderTeam == LorisTeam.teamOne);
    final currentDealerTeamScore = dealerTeamIsOne ? matchScore.teamOneScore : matchScore.teamTwoScore;
    _dealerSeat = DealerRotation.nextDealer(
      playerCount: playerCount,
      currentDealerSeat: _dealerSeat,
      previousDealerTeamScore: previousDealerTeamScore,
      currentDealerTeamScore: currentDealerTeamScore,
    );
    phase = isMatchOver ? RoundPhase.matchComplete : RoundPhase.roundComplete;
  }
}
