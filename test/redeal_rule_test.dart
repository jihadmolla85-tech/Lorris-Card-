import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

void main() {
  group('Low-card redeal rule', () {
    test('redeals when any complete hand contains only cards below 10', () {
      final lowHand = <Card>[
        const Card(suit: Suit.clubs, rank: 3),
        const Card(suit: Suit.clubs, rank: 4),
        const Card(suit: Suit.clubs, rank: 5),
        const Card(suit: Suit.diamonds, rank: 6),
        const Card(suit: Suit.diamonds, rank: 7),
        const Card(suit: Suit.hearts, rank: 8),
        const Card(suit: Suit.hearts, rank: 9),
        const Card(suit: Suit.spades, rank: 4),
      ];
      final deal = Deal(
        hands: {0: lowHand, 1: const [], 2: const [], 3: const []},
        remainingCards: const [],
        dealBatches: const [],
      );
      expect(LorisRedealRule.shouldRedeal(deal), isTrue);
    });

    test('does not redeal when the hand contains a 10 or higher', () {
      final hand = <Card>[
        for (var rank = 3; rank <= 9; rank++)
          Card(suit: Suit.clubs, rank: rank),
        const Card(suit: Suit.diamonds, rank: 10),
      ];
      final deal = Deal(
        hands: {0: hand},
        remainingCards: const [],
        dealBatches: const [],
      );
      expect(LorisRedealRule.shouldRedeal(deal), isFalse);
    });

    test('does not treat LORIS as a low card', () {
      final hand = <Card>[
        const Card(suit: Suit.clubs, rank: 3),
        const Card(suit: Suit.clubs, rank: 4),
        const Card(suit: Suit.clubs, rank: 5),
        const Card(suit: Suit.diamonds, rank: 6),
        const Card(suit: Suit.diamonds, rank: 7),
        const Card(suit: Suit.hearts, rank: 8),
        const Card(suit: Suit.hearts, rank: 9),
        const Card(suit: Suit.spades, special: SpecialCard.loris, replacesRank: 7),
      ];
      final deal = Deal(
        hands: {0: hand},
        remainingCards: const [],
        dealBatches: const [],
      );
      expect(LorisRedealRule.shouldRedeal(deal), isFalse);
    });

    test('does not trigger for an incomplete hand', () {
      final deal = Deal(
        hands: {
          0: const [
            Card(suit: Suit.clubs, rank: 3),
            Card(suit: Suit.clubs, rank: 4),
          ],
        },
        remainingCards: const [],
        dealBatches: const [],
      );
      expect(LorisRedealRule.shouldRedeal(deal), isFalse);
    });
  });
}
