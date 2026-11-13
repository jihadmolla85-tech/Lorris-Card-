enum Suit { clubs, diamonds, hearts, spades }

enum SpecialCard { none, loris }

enum PlayerCount {
  four(4),
  six(6);

  const PlayerCount(this.value);
  final int value;
}

class Card {
  const Card({
    required this.suit,
    this.rank,
    this.special = SpecialCard.none,
    this.replacesRank,
  }) : assert(
          (special == SpecialCard.none && rank != null && replacesRank == null) ||
          (special == SpecialCard.loris && rank == null && replacesRank != null),
        );

  final Suit suit;
  final int? rank;
  final SpecialCard special;
  final int? replacesRank;
  bool get isLoris => special == SpecialCard.loris;

  String get displayName {
    if (isLoris) return 'LORIS';
    final names = <int, String>{11: 'J', 12: 'Q', 13: 'K', 14: 'A'};
    return names[rank] ?? '$rank';
  }

  @override
  bool operator ==(Object other) => other is Card && other.suit == suit &&
      other.rank == rank && other.special == special && other.replacesRank == replacesRank;
  @override
  int get hashCode => Object.hash(suit, rank, special, replacesRank);
  @override
  String toString() => isLoris ? 'LORIS (replaces ♠$replacesRank)' : '$suit $displayName';
}

class Deal {
  const Deal({
    required this.hands,
    required this.remainingCards,
    required this.dealBatches,
  });

  final Map<int, List<Card>> hands;
  final List<Card> remainingCards;

  /// Two batches: each player's first four cards, then each player's next four.
  final List<List<int>> dealBatches;

  bool get isComplete =>
      hands.values.every((hand) => hand.length == 8) &&
      dealBatches.length == 2;
}

class LorisDeck {
  static const List<Suit> suits = Suit.values;

  static List<int> ranksFor(PlayerCount playerCount) {
    switch (playerCount) {
      case PlayerCount.four:
        return List<int>.generate(8, (i) => i + 7); // 7..A
      case PlayerCount.six:
        return List<int>.generate(12, (i) => i + 3); // 3..A
    }
  }

  static List<Card> create(PlayerCount playerCount) {
    final ranks = ranksFor(playerCount);
    final lowestRank = ranks.first;
    final cards = <Card>[];
    for (final suit in suits) {
      for (final rank in ranks) {
        if (suit == Suit.spades && rank == lowestRank) {
          cards.add(Card(suit: Suit.spades, special: SpecialCard.loris, replacesRank: lowestRank));
        } else {
          cards.add(Card(suit: suit, rank: rank));
        }
      }
    }
    return cards;
  }

  static Deal deal(PlayerCount playerCount, {required int dealerSeat, required RandomSource random}) {
    if (dealerSeat < 0 || dealerSeat >= playerCount.value) {
      throw ArgumentError.value(dealerSeat, 'dealerSeat', 'Invalid seat');
    }
    final deck = create(playerCount);
    random.shuffle(deck);
    final hands = <int, List<Card>>{
      for (var seat = 0; seat < playerCount.value; seat++) seat: <Card>[],
    };
    // Seat numbers are clockwise. Rightward play moves to the previous seat index.
    // Deal four cards to each player, then repeat for the second batch of four.
    var cardIndex = 0;
    final batches = <List<int>>[];
    for (var batch = 0; batch < 2; batch++) {
      final batchSeats = <int>[];
      var seat = (dealerSeat - 1 + playerCount.value) % playerCount.value;
      for (var player = 0; player < playerCount.value; player++) {
        batchSeats.add(seat);
        for (var card = 0; card < 4; card++) {
          hands[seat]!.add(deck[cardIndex++]);
        }
        seat = (seat - 1 + playerCount.value) % playerCount.value;
      }
      batches.add(List<int>.unmodifiable(batchSeats));
    }
    return Deal(
      hands: hands,
      remainingCards: const <Card>[],
      dealBatches: List<List<int>>.unmodifiable(batches),
    );
  }
}

/// Redeal condition: if any player's complete eight-card hand consists only
/// of ordinary cards ranked below 10 (3–9), the cards must be dealt again.
/// LORIS is not counted as a low card because it is the highest card in play.
class LorisRedealRule {
  static bool shouldRedeal(Deal deal) {
    return deal.hands.values.any((hand) =>
        hand.length == 8 &&
        hand.every((card) =>
            !card.isLoris && card.rank != null && card.rank! < 10));
  }
}

abstract interface class RandomSource {
  void shuffle<T>(List<T> values);
}

/// A single revealed card during the initial-dealer draw.
/// `seat` identifies the player who revealed/received this card.
class DealerReveal {
  const DealerReveal({required this.seat, required this.card});
  final int seat;
  final Card card;
}

/// Result of revealing cards one at a time to determine the first dealer.
class DealerSelection {
  const DealerSelection({required this.dealerSeat, required this.reveals});
  final int dealerSeat;
  final List<DealerReveal> reveals;
}

class InitialDealerSelector {
  /// The first player to reveal a Jack becomes the initial dealer.
  ///
  /// Reveals are supplied in the actual reveal order. This deliberately does
  /// not assume which seat reveals first or the direction of that order.
  static DealerSelection? select({
    required PlayerCount playerCount,
    required List<DealerReveal> reveals,
  }) {
    for (var i = 0; i < reveals.length; i++) {
      final reveal = reveals[i];
      if (reveal.seat < 0 || reveal.seat >= playerCount.value) {
        throw ArgumentError.value(reveal.seat, 'seat', 'Invalid player seat');
      }
      if (reveal.card.rank == 11) {
        return DealerSelection(
          dealerSeat: reveal.seat,
          reveals: List<DealerReveal>.unmodifiable(reveals.take(i + 1)),
        );
      }
    }
    return null;
  }
}


/// Applies the dealer-penalty rule after a score update. The current dealer
/// keeps dealing until their team's score crosses from zero/negative to
/// positive. At that crossing, the player to the right becomes the new dealer.
/// That dealer stays until their own team's score makes the same crossing.
class DealerRotation {
  static int nextDealer({
    required PlayerCount playerCount,
    required int currentDealerSeat,
    required int previousDealerTeamScore,
    required int currentDealerTeamScore,
  }) {
    if (currentDealerSeat < 0 || currentDealerSeat >= playerCount.value) {
      throw ArgumentError.value(
        currentDealerSeat,
        'currentDealerSeat',
        'Invalid seat',
      );
    }

    final crossedIntoPositive =
        previousDealerTeamScore <= 0 && currentDealerTeamScore > 0;
    if (!crossedIntoPositive) {
      return currentDealerSeat;
    }

    // Seat numbers follow the existing model: moving right decrements seat.
    return (currentDealerSeat - 1 + playerCount.value) % playerCount.value;
  }
}


/// One bidding phase after all players have received all eight cards.
/// Bids are 5–8; null represents Pass. Each player acts once, beginning
/// with the player to the dealer's right.
class BiddingRound<T> {
  BiddingRound({
    required this.playerCount,
    required Deal deal,
    required this.dealerSeat,
  }) : _deal = deal {
    if (!deal.isComplete) {
      throw StateError('Bidding cannot start before all eight cards are dealt.');
    }
    if (dealerSeat < 0 || dealerSeat >= playerCount.value) {
      throw ArgumentError.value(dealerSeat, 'dealerSeat', 'Invalid dealer seat');
    }
    // Right of dealer is the previous seat index in this project's seating model.
    _turnOrder = List<int>.unmodifiable(
      List<int>.generate(
        playerCount.value,
        (i) => (dealerSeat - 1 - i + playerCount.value * 2) % playerCount.value,
      ),
    );
  }

  final PlayerCount playerCount;
  final Deal _deal;
  final int dealerSeat;
  late final List<int> _turnOrder;
  final Map<int, T> _submissions = <int, T>{};

  bool get isComplete => _submissions.length == playerCount.value;
  Map<int, T> get submissions => Map<int, T>.unmodifiable(_submissions);
  List<int> get turnOrder => _turnOrder;
  int? get nextPlayerToBid =>
      isComplete ? null : _turnOrder[_submissions.length];
  bool hasBid(int seat) => _submissions.containsKey(seat);

  /// Each player may submit at most once, in order starting right of dealer.
  void submit({required int seat, required T bid}) {
    if (seat < 0 || seat >= playerCount.value) {
      throw ArgumentError.value(seat, 'seat', 'Invalid player seat');
    }
    if (isComplete) {
      throw StateError('The bidding round is already complete.');
    }
    if (_submissions.containsKey(seat)) {
      throw StateError('This player has already bid in this round.');
    }
    if (seat != nextPlayerToBid) {
      throw StateError('It is not this player\'s turn to bid.');
    }
    // LORIS bid values: ordinary calls 5–7, special call 8.
    // A null submission is a pass.
    if (bid is int) {
      if (bid < 5 || bid > 8) {
        throw RangeError.range(bid, 5, 8, 'bid');
      }
      final previousNumericBids = _submissions.values.whereType<int>().toList();
      if (previousNumericBids.isNotEmpty &&
          bid <= previousNumericBids.reduce((a, b) => a > b ? a : b)) {
        throw StateError('A new bid must be higher than the current highest bid.');
      }
    }
    _submissions[seat] = bid;
  }
}


/// Outcome of a completed bidding round.
enum BiddingOutcome {
  pending,
  contractWon,
  redeal,
}

/// Tracks bids and passes. A null bid represents a pass.
/// When every player passes, the round ends with a redeal outcome.
class BiddingResolution<T> {
  static BiddingOutcome resolve({
    required PlayerCount playerCount,
    required Map<int, T?> submissions,
  }) {
    if (submissions.length < playerCount.value) {
      return BiddingOutcome.pending;
    }
    if (submissions.values.every((bid) => bid == null)) {
      return BiddingOutcome.redeal;
    }
    return BiddingOutcome.contractWon;
  }
}


/// Trump declaration made publicly by the player who wins the bidding.
/// The winning bidder chooses one suit and shows it to the table.
class TrumpDeclaration {
  const TrumpDeclaration({
    required this.winningPlayerSeat,
    required this.suit,
  });

  final int winningPlayerSeat;
  final Suit suit;

  /// The trump is shown as part of the declaration, not kept hidden.
  bool get isShown => true;

  static TrumpDeclaration declare({
    required PlayerCount playerCount,
    required int winningPlayerSeat,
    required Suit suit,
    required bool biddingComplete,
  }) {
    if (!biddingComplete) {
      throw StateError('Trump cannot be selected before bidding is complete.');
    }
    if (winningPlayerSeat < 0 || winningPlayerSeat >= playerCount.value) {
      throw ArgumentError.value(
        winningPlayerSeat,
        'winningPlayerSeat',
        'Invalid player seat',
      );
    }
    return TrumpDeclaration(winningPlayerSeat: winningPlayerSeat, suit: suit);
  }
}


/// Selects the player with the uniquely highest numeric bid.
///
/// A null bid means pass. All players must have submitted. Tied highest bids
/// are deliberately rejected until the game's tie-break rule is specified.
class BiddingWinner {
  static int selectHighestBidder({
    required PlayerCount playerCount,
    required Map<int, int?> submissions,
  }) {
    if (submissions.length != playerCount.value) {
      throw StateError('Bidding is not complete.');
    }
    if (submissions.keys.any((seat) => seat < 0 || seat >= playerCount.value)) {
      throw ArgumentError('A submission contains an invalid player seat.');
    }

    final activeBids = submissions.entries
        .where((entry) => entry.value != null)
        .toList(growable: false);
    if (activeBids.any((entry) => entry.value! < 5 || entry.value! > 8)) {
      throw RangeError('Every numeric bid must be between 5 and 8.');
    }
    if (activeBids.isEmpty) {
      throw StateError('All players passed; a redeal is required.');
    }

    final highest = activeBids
        .map((entry) => entry.value!)
        .reduce((a, b) => a > b ? a : b);
    final winners = activeBids
        .where((entry) => entry.value == highest)
        .toList(growable: false);

    if (winners.length != 1) {
      throw StateError('Highest bid is tied; tie-break rule is not defined.');
    }
    return winners.single.key;
  }
}


/// LORIS 8-call is always available, regardless of the bidding team's score.
/// The team's current score affects only the reward after a successful 8-call.
class LorisContractScoring {
  static const int specialCall = 8;

  static ContractScore score({
    required int bid,
    required int pointsTaken,
    int? bidderTeamScore,
  }) {
    if (bid < 5 || bid > 8) {
      throw RangeError.range(bid, 5, 8, 'bid');
    }
    if (pointsTaken < 0 || pointsTaken > 8) {
      throw RangeError.range(pointsTaken, 0, 8, 'pointsTaken');
    }

    if (pointsTaken < bid) {
      return ContractScore(
        bidderSucceeded: false,
        bidderTeamPoints: 0,
        opposingTeamPoints: bid * 2,
      );
    }

    if (bid == specialCall) {
      if (bidderTeamScore == null) {
        throw ArgumentError(
          'The bidding team score is required to score a successful 8-call.',
        );
      }
      return ContractScore(
        bidderSucceeded: true,
        bidderTeamPoints: bidderTeamScore < 16 ? 16 : 8,
        opposingTeamPoints: 0,
      );
    }

    return ContractScore(
      bidderSucceeded: true,
      bidderTeamPoints: bid,
      opposingTeamPoints: 0,
    );
  }
}

class ContractScore {
  const ContractScore({
    required this.bidderSucceeded,
    required this.bidderTeamPoints,
    required this.opposingTeamPoints,
  });

  final bool bidderSucceeded;
  final int bidderTeamPoints;
  final int opposingTeamPoints;
}


/// A card played by a player during a trick.
class PlayedCard {
  const PlayedCard({required this.seat, required this.card});

  final int seat;
  final Card card;
}

enum LorisTeam { teamOne, teamTwo }

/// Counts the eight tricks in one round for the two teams. The caller supplies
/// the seat-to-team assignment; this core does not assume a seating pattern.
class TrickScoreTracker {
  TrickScoreTracker({
    required this.playerCount,
    required Map<int, LorisTeam> teamBySeat,
  }) : _teamBySeat = Map<int, LorisTeam>.unmodifiable(teamBySeat) {
    if (_teamBySeat.length != playerCount.value ||
        List<int>.generate(playerCount.value, (seat) => seat)
            .any((seat) => !_teamBySeat.containsKey(seat))) {
      throw ArgumentError('Every player seat must have exactly one team.');
    }
    final teamOneSeats =
        _teamBySeat.values.where((team) => team == LorisTeam.teamOne).length;
    final teamTwoSeats =
        _teamBySeat.values.where((team) => team == LorisTeam.teamTwo).length;
    if (teamOneSeats != playerCount.value ~/ 2 ||
        teamTwoSeats != playerCount.value ~/ 2) {
      throw ArgumentError('Teams must have equal numbers of players.');
    }
  }

  static const int tricksPerRound = 8;
  final PlayerCount playerCount;
  final Map<int, LorisTeam> _teamBySeat;
  final Map<LorisTeam, int> _points = <LorisTeam, int>{
    LorisTeam.teamOne: 0,
    LorisTeam.teamTwo: 0,
  };

  int get completedTricks => _points.values.fold(0, (sum, value) => sum + value);
  bool get isComplete => completedTricks == tricksPerRound;
  int pointsFor(LorisTeam team) => _points[team]!;

  void recordTrickWinner(int winnerSeat) {
    if (isComplete) {
      throw StateError('All eight tricks in this round have been recorded.');
    }
    final winningTeam = _teamBySeat[winnerSeat];
    if (winningTeam == null) {
      throw ArgumentError.value(winnerSeat, 'winnerSeat', 'Invalid player seat');
    }
    _points[winningTeam] = _points[winningTeam]! + 1;
  }
}

/// Enforces the confirmed follow-suit and mandatory-overtrump rules, and
/// resolves a trick winner. The LORIS card is always legal and always wins.
class TrickRules {
  static bool isLegalPlay({
    required List<Card> hand,
    required Card card,
    required Suit ledSuit,
    required Suit trumpSuit,
    required List<PlayedCard> cardsAlreadyPlayed,
  }) {
    if (!hand.contains(card)) return false;

    // The special card may be played at any time, even when the player can
    // follow suit or is required to overtrump.
    if (card.isLoris) return true;

    final hasLedSuit = hand.any(
      (held) => !held.isLoris && held.suit == ledSuit,
    );
    if (hasLedSuit) {
      return card.suit == ledSuit;
    }

    final playedTrumpRanks = cardsAlreadyPlayed
        .map((play) => play.card)
        .where((played) =>
            !played.isLoris &&
            played.suit == trumpSuit &&
            played.rank != null)
        .map((played) => played.rank!)
        .toList(growable: false);

    if (playedTrumpRanks.isEmpty) return true;

    final highestTrumpAlreadyPlayed =
        playedTrumpRanks.reduce((a, b) => a > b ? a : b);
    final hasHigherTrump = hand.any(
      (held) =>
          !held.isLoris &&
          held.suit == trumpSuit &&
          held.rank != null &&
          held.rank! > highestTrumpAlreadyPlayed,
    );

    if (!hasHigherTrump) return true;
    return card.suit == trumpSuit &&
        card.rank != null &&
        card.rank! > highestTrumpAlreadyPlayed;
  }

  static int winnerSeat({
    required List<PlayedCard> plays,
    required Suit ledSuit,
    required Suit trumpSuit,
  }) {
    if (plays.isEmpty) {
      throw ArgumentError('A trick must contain at least one played card.');
    }

    final lorisPlays = plays.where((play) => play.card.isLoris);
    if (lorisPlays.isNotEmpty) return lorisPlays.first.seat;

    final trumpPlays = plays
        .where((play) => play.card.suit == trumpSuit)
        .toList(growable: false);
    final candidates = trumpPlays.isNotEmpty
        ? trumpPlays
        : plays.where((play) => play.card.suit == ledSuit).toList();

    if (candidates.isEmpty) {
      throw StateError('No card of the led suit or trump can win this trick.');
    }

    var winner = candidates.first;
    for (final candidate in candidates.skip(1)) {
      final candidateRank = candidate.card.rank ?? -1;
      final winnerRank = winner.card.rank ?? -1;
      if (candidateRank > winnerRank) winner = candidate;
    }
    return winner.seat;
  }
}

enum LorisMatchWinner { teamOne, teamTwo }

/// Signed zero-sum match score. Team two's score is always the negative of
/// team one's score. The match ends as soon as either team reaches +32.
class LorisMatchScore {
  LorisMatchScore({int initialTeamOneScore = 0})
      : _teamOneScore = initialTeamOneScore {
    if (initialTeamOneScore <= -32 || initialTeamOneScore >= 32) {
      throw RangeError.value(
        initialTeamOneScore,
        'initialTeamOneScore',
        'A new match must start below the winning threshold.',
      );
    }
  }

  int _teamOneScore;
  int get teamOneScore => _teamOneScore;
  int get teamTwoScore => -_teamOneScore;

  LorisMatchWinner? get winner {
    if (_teamOneScore >= 32) return LorisMatchWinner.teamOne;
    if (_teamOneScore <= -32) return LorisMatchWinner.teamTwo;
    return null;
  }

  void applyContractScore({
    required ContractScore score,
    required bool bidderIsTeamOne,
  }) {
    if (winner != null) {
      throw StateError('The match has ended; no more points can be added.');
    }
    final bidderDelta = score.bidderTeamPoints - score.opposingTeamPoints;
    _teamOneScore += bidderIsTeamOne ? bidderDelta : -bidderDelta;
  }
}
