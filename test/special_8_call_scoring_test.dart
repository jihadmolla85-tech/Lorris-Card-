import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

void main() {
  group('Special 8-call scoring', () {
    test('8-call is accepted regardless of team score', () {
      final round = _round();
      expect(
        () => round.submit(seat: round.nextPlayerToBid!, bid: 8),
        returnsNormally,
      );
    });

    test('successful 8-call awards 16 when bidder team score is below 16', () {
      final score = LorisContractScoring.score(
        bid: 8, pointsTaken: 8, bidderTeamScore: 15,
      );
      expect(score.bidderTeamPoints, 16);
      expect(score.opposingTeamPoints, 0);
    });

    test('successful 8-call awards 8 when bidder team score is 16', () {
      final score = LorisContractScoring.score(
        bid: 8, pointsTaken: 8, bidderTeamScore: 16,
      );
      expect(score.bidderTeamPoints, 8);
    });

    test('successful 8-call awards 8 when bidder team score exceeds 16', () {
      final score = LorisContractScoring.score(
        bid: 8, pointsTaken: 8, bidderTeamScore: 20,
      );
      expect(score.bidderTeamPoints, 8);
    });

    test('successful 8-call awards 16 for a negative bidder team score', () {
      final score = LorisContractScoring.score(
        bid: 8, pointsTaken: 8, bidderTeamScore: -5,
      );
      expect(score.bidderTeamPoints, 16);
    });

    test('failed 8-call gives opposing team 16 regardless of score', () {
      final score = LorisContractScoring.score(bid: 8, pointsTaken: 7);
      expect(score.bidderSucceeded, isFalse);
      expect(score.opposingTeamPoints, 16);
    });
  });
}

BiddingRound<int?> _round() {
  final cards = <Card>[
    for (final suit in Suit.values)
      for (var rank = 7; rank <= 14; rank++)
        if (!(suit == Suit.spades && rank == 7)) Card(suit: suit, rank: rank),
    const Card(suit: Suit.spades, special: SpecialCard.loris, replacesRank: 7),
  ];
  final hands = <int, List<Card>>{
    for (var seat = 0; seat < 4; seat++)
      seat: cards.sublist(seat * 8, seat * 8 + 8),
  };
  final deal = Deal(
    hands: hands,
    remainingCards: const [],
    dealBatches: const [[3, 2, 1, 0], [3, 2, 1, 0]],
  );
  return BiddingRound<int?>(
    playerCount: PlayerCount.four,
    deal: deal,
    dealerSeat: 0,
  );
}
