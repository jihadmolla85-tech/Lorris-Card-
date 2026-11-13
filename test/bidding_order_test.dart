import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

class NoShuffle implements RandomSource {
  @override
  void shuffle<T>(List<T> values) {}
}

void main() {
  for (final count in PlayerCount.values) {
    test('${count.value}-player bidding starts right of dealer and moves right', () {
      final deal = LorisDeck.deal(
        count,
        dealerSeat: 0,
        random: NoShuffle(),
      );
      final round = BiddingRound<String>(
        playerCount: count,
        deal: deal,
        dealerSeat: 0,
      );

      final expected = List<int>.generate(
        count.value,
        (i) => (count.value - 1 - i) % count.value,
      );
      expect(round.turnOrder, expected);
      expect(round.nextPlayerToBid, expected.first);

      for (final seat in expected) {
        round.submit(seat: seat, bid: 'bid-$seat');
      }
      expect(round.isComplete, isTrue);
      expect(round.nextPlayerToBid, isNull);
    });
  }

  test('rejects a bid made out of turn', () {
    final deal = LorisDeck.deal(
      PlayerCount.four,
      dealerSeat: 2,
      random: NoShuffle(),
    );
    final round = BiddingRound<String>(
      playerCount: PlayerCount.four,
      deal: deal,
      dealerSeat: 2,
    );

    expect(round.nextPlayerToBid, 1);
    expect(() => round.submit(seat: 0, bid: 'too early'), throwsStateError);
    round.submit(seat: 1, bid: 'first');
    expect(round.nextPlayerToBid, 0);
  });

  test('each player still bids at most once', () {
    final deal = LorisDeck.deal(
      PlayerCount.four,
      dealerSeat: 0,
      random: NoShuffle(),
    );
    final round = BiddingRound<String>(
      playerCount: PlayerCount.four,
      deal: deal,
      dealerSeat: 0,
    );
    round.submit(seat: 3, bid: 'first');
    expect(() => round.submit(seat: 3, bid: 'second'), throwsStateError);
  });
}
