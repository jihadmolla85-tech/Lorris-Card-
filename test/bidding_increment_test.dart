import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

void main() {
  group('Strictly increasing bidding', () {
    test('rejects equal bids', () {
      final round = _round();
      final first = round.nextPlayerToBid!;
      round.submit(seat: first, bid: 5);
      final second = round.nextPlayerToBid!;
      expect(() => round.submit(seat: second, bid: 5), throwsStateError);
    });

    test('rejects lower bids', () {
      final round = _round();
      final first = round.nextPlayerToBid!;
      round.submit(seat: first, bid: 6);
      final second = round.nextPlayerToBid!;
      expect(() => round.submit(seat: second, bid: 5), throwsStateError);
    });

    test('allows a higher bid after another player passes', () {
      final round = _round();
      final first = round.nextPlayerToBid!;
      round.submit(seat: first, bid: 5);
      final second = round.nextPlayerToBid!;
      round.submit(seat: second, bid: null);
      final third = round.nextPlayerToBid!;
      expect(() => round.submit(seat: third, bid: 6), returnsNormally);
    });

    test('a player cannot submit twice', () {
      final round = _round();
      final first = round.nextPlayerToBid!;
      round.submit(seat: first, bid: 5);
      expect(() => round.submit(seat: first, bid: 5), throwsStateError);
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
