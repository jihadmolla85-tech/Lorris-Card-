import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

class NoShuffle implements RandomSource {
  @override
  void shuffle<T>(List<T> values) {}
}

void main() {
  group('Two-batch dealing', () {
    for (final count in PlayerCount.values) {
      test('${count.value} players receive four cards twice (eight total)', () {
        final deal = LorisDeck.deal(
          count,
          dealerSeat: 0,
          random: NoShuffle(),
        );

        expect(deal.isComplete, isTrue);
        expect(deal.dealBatches.length, 2);
        expect(deal.hands.length, count.value);
        for (final hand in deal.hands.values) {
          expect(hand.length, 8);
        }
        expect(deal.dealBatches[0].length, count.value);
        expect(deal.dealBatches[1].length, count.value);
      });
    }
  });

  group('Bidding round', () {
    late Deal deal;

    setUp(() {
      deal = LorisDeck.deal(
        PlayerCount.four,
        dealerSeat: 0,
        random: NoShuffle(),
      );
    });

    test('bidding starts only after all eight cards are dealt', () {
      expect(
        () => BiddingRound<String>(
          playerCount: PlayerCount.four,
          deal: Deal(
            hands: {0: [], 1: [], 2: [], 3: []},
            remainingCards: const [],
            dealBatches: const [],
          ),
          dealerSeat: 0,
        ),
        throwsStateError,
      );
    });

    test('each player can submit once in the round', () {
      final round = BiddingRound<String>(
        playerCount: PlayerCount.four,
        deal: deal,
        dealerSeat: 0,
      );

      final firstSeat = round.nextPlayerToBid!;
      round.submit(seat: firstSeat, bid: 'bid-a');
      expect(round.hasBid(firstSeat), isTrue);
      expect(
        () => round.submit(seat: firstSeat, bid: 'bid-b'),
        throwsStateError,
      );
    });

    test('round completes after every player has submitted once', () {
      final round = BiddingRound<String>(
        playerCount: PlayerCount.four,
        deal: deal,
        dealerSeat: 0,
      );

      for (final seat in round.turnOrder) {
        round.submit(seat: seat, bid: 'bid-$seat');
      }
      expect(round.isComplete, isTrue);
      expect(round.submissions.length, 4);
      expect(
        () => round.submit(seat: 0, bid: 'extra'),
        throwsStateError,
      );
    });

    test('invalid seat is rejected', () {
      final round = BiddingRound<String>(
        playerCount: PlayerCount.four,
        deal: deal,
        dealerSeat: 0,
      );
      expect(
        () => round.submit(seat: 4, bid: 'bid'),
        throwsArgumentError,
      );
    });
  });
}
