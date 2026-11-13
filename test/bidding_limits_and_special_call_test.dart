import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

void main() {
  group('LORIS bid limits', () {
    test('accepts ordinary minimum bid 5', () {
      final round = _round();
      round.submit(seat: round.nextPlayerToBid!, bid: 5);
      expect(round.submissions.values.single, 5);
    });

    test('accepts ordinary maximum bid 7', () {
      final round = _round();
      round.submit(seat: round.nextPlayerToBid!, bid: 7);
      expect(round.submissions.values.single, 7);
    });

    test('accepts special bid 8', () {
      final round = _round();
      round.submit(seat: round.nextPlayerToBid!, bid: 8);
      expect(round.submissions.values.single, 8);
    });

    test('rejects bids below 5 and above 8', () {
      final roundLow = _round();
      expect(() => roundLow.submit(seat: roundLow.nextPlayerToBid!, bid: 4), throwsRangeError);

      final roundHigh = _round();
      expect(() => roundHigh.submit(seat: roundHigh.nextPlayerToBid!, bid: 9), throwsRangeError);
    });

    test('special 8-call earns 16 when all 8 points are taken', () {
      expect(
        LorisContractScoring.score(
          bid: 8, pointsTaken: 8, bidderTeamScore: 0,
        ).bidderTeamPoints,
        16,
      );
    });

    test('failed special 8-call gives opposing team 16 points', () {
      final score = LorisContractScoring.score(bid: 8, pointsTaken: 7);
      expect(score.bidderSucceeded, isFalse);
      expect(score.opposingTeamPoints, 16);
    });
  });
}

BiddingRound<int?> _round() {
  final cards = <Card>[
    for (final suit in Suit.values)
      for (var rank = 7; rank <= 14; rank++) Card(suit: suit, rank: rank),
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
