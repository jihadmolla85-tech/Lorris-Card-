import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

void main() {
  group('Initial dealer selection', () {
    test('first revealed Jack holder becomes initial dealer', () {
      final reveals = [
        DealerReveal(seat: 0, card: const Card(suit: Suit.hearts, rank: 9)),
        DealerReveal(seat: 1, card: const Card(suit: Suit.clubs, rank: 11)),
        DealerReveal(seat: 2, card: const Card(suit: Suit.spades, rank: 14)),
      ];
      final result = InitialDealerSelector.select(
        playerCount: PlayerCount.four, reveals: reveals,
      );
      expect(result, isNotNull);
      expect(result!.dealerSeat, 1);
      expect(result.reveals.length, 2);
    });

    test('later Jack does not replace the first Jack', () {
      final result = InitialDealerSelector.select(
        playerCount: PlayerCount.six,
        reveals: [
          DealerReveal(seat: 3, card: const Card(suit: Suit.diamonds, rank: 11)),
          DealerReveal(seat: 0, card: const Card(suit: Suit.hearts, rank: 11)),
        ],
      );
      expect(result!.dealerSeat, 3);
      expect(result.reveals.length, 1);
    });

    test('returns null if no Jack has been revealed yet', () {
      final result = InitialDealerSelector.select(
        playerCount: PlayerCount.four,
        reveals: [
          DealerReveal(seat: 0, card: const Card(suit: Suit.hearts, rank: 9)),
          DealerReveal(seat: 1, card: const Card(suit: Suit.clubs, rank: 10)),
        ],
      );
      expect(result, isNull);
    });

    test('rejects a seat outside the selected player count', () {
      expect(
        () => InitialDealerSelector.select(
          playerCount: PlayerCount.four,
          reveals: [
            DealerReveal(seat: 4, card: const Card(suit: Suit.hearts, rank: 11)),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
