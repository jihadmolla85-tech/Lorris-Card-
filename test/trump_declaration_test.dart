import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

void main() {
  group('Trump declaration', () {
    test('winning bidder can choose a suit and show it', () {
      final declaration = TrumpDeclaration.declare(
        playerCount: PlayerCount.four,
        winningPlayerSeat: 2,
        suit: Suit.hearts,
        biddingComplete: true,
      );

      expect(declaration.winningPlayerSeat, 2);
      expect(declaration.suit, Suit.hearts);
      expect(declaration.isShown, isTrue);
    });

    test('cannot declare trump before bidding is complete', () {
      expect(
        () => TrumpDeclaration.declare(
          playerCount: PlayerCount.six,
          winningPlayerSeat: 4,
          suit: Suit.spades,
          biddingComplete: false,
        ),
        throwsStateError,
      );
    });

    test('rejects an invalid winning player seat', () {
      expect(
        () => TrumpDeclaration.declare(
          playerCount: PlayerCount.four,
          winningPlayerSeat: 4,
          suit: Suit.clubs,
          biddingComplete: true,
        ),
        throwsArgumentError,
      );
    });
  });
}
