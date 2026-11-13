import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

void main() {
  group('Follow-suit and overtrump rules', () {
    const ledCard = Card(suit: Suit.hearts, rank: 10);
    const trumpSeven = Card(suit: Suit.spades, rank: 7);
    const trumpKing = Card(suit: Suit.spades, rank: 13);
    const offSuit = Card(suit: Suit.clubs, rank: 9);

    test('must follow the led suit when the player has it', () {
      final hand = [
        const Card(suit: Suit.hearts, rank: 3),
        trumpKing,
      ];
      expect(
        TrickRules.isLegalPlay(
          hand: hand,
          card: trumpKing,
          ledSuit: Suit.hearts,
          trumpSuit: Suit.spades,
          cardsAlreadyPlayed: const [],
        ),
        isFalse,
      );
      expect(
        TrickRules.isLegalPlay(
          hand: hand,
          card: hand.first,
          ledSuit: Suit.hearts,
          trumpSuit: Suit.spades,
          cardsAlreadyPlayed: const [],
        ),
        isTrue,
      );
    });

    test('may play any ordinary card when the led suit is absent and no trump was played', () {
      expect(
        TrickRules.isLegalPlay(
          hand: const [trumpKing, offSuit],
          card: offSuit,
          ledSuit: Suit.hearts,
          trumpSuit: Suit.spades,
          cardsAlreadyPlayed: const [PlayedCard(seat: 0, card: ledCard)],
        ),
        isTrue,
      );
    });

    test('must overtrump when void in led suit and holding a higher trump', () {
      expect(
        TrickRules.isLegalPlay(
          hand: const [trumpKing, offSuit],
          card: offSuit,
          ledSuit: Suit.hearts,
          trumpSuit: Suit.spades,
          cardsAlreadyPlayed: const [
            PlayedCard(seat: 0, card: ledCard),
            PlayedCard(seat: 1, card: trumpSeven),
          ],
        ),
        isFalse,
      );
      expect(
        TrickRules.isLegalPlay(
          hand: const [trumpKing, offSuit],
          card: trumpKing,
          ledSuit: Suit.hearts,
          trumpSuit: Suit.spades,
          cardsAlreadyPlayed: const [
            PlayedCard(seat: 0, card: ledCard),
            PlayedCard(seat: 1, card: trumpSeven),
          ],
        ),
        isTrue,
      );
    });

    test('may play any card if no higher trump is held', () {
      expect(
        TrickRules.isLegalPlay(
          hand: const [trumpSeven, offSuit],
          card: offSuit,
          ledSuit: Suit.hearts,
          trumpSuit: Suit.spades,
          cardsAlreadyPlayed: const [
            PlayedCard(seat: 0, card: ledCard),
            PlayedCard(seat: 1, card: trumpKing),
          ],
        ),
        isTrue,
      );
    });

    test('LORIS can be played even when following suit is possible', () {
      const loris = Card(
        suit: Suit.spades,
        special: SpecialCard.loris,
        replacesRank: 7,
      );
      expect(
        TrickRules.isLegalPlay(
          hand: const [ledCard, loris],
          card: loris,
          ledSuit: Suit.hearts,
          trumpSuit: Suit.spades,
          cardsAlreadyPlayed: const [],
        ),
        isTrue,
      );
    });
  });

  group('Trick winner', () {
    test('highest trump wins over a higher led-suit card', () {
      expect(
        TrickRules.winnerSeat(
          plays: const [
            PlayedCard(seat: 0, card: Card(suit: Suit.hearts, rank: 14)),
            PlayedCard(seat: 1, card: Card(suit: Suit.spades, rank: 9)),
            PlayedCard(seat: 2, card: Card(suit: Suit.spades, rank: 13)),
            PlayedCard(seat: 3, card: Card(suit: Suit.clubs, rank: 14)),
          ],
          ledSuit: Suit.hearts,
          trumpSuit: Suit.spades,
        ),
        2,
      );
    });

    test('highest led-suit card wins when no trump is played', () {
      expect(
        TrickRules.winnerSeat(
          plays: const [
            PlayedCard(seat: 0, card: Card(suit: Suit.hearts, rank: 10)),
            PlayedCard(seat: 1, card: Card(suit: Suit.hearts, rank: 14)),
            PlayedCard(seat: 2, card: Card(suit: Suit.clubs, rank: 14)),
          ],
          ledSuit: Suit.hearts,
          trumpSuit: Suit.spades,
        ),
        1,
      );
    });

    test('LORIS always wins the trick', () {
      const loris = Card(
        suit: Suit.spades,
        special: SpecialCard.loris,
        replacesRank: 7,
      );
      expect(
        TrickRules.winnerSeat(
          plays: const [
            PlayedCard(seat: 0, card: Card(suit: Suit.hearts, rank: 14)),
            PlayedCard(seat: 1, card: Card(suit: Suit.spades, rank: 14)),
            PlayedCard(seat: 2, card: loris),
            PlayedCard(seat: 3, card: Card(suit: Suit.clubs, rank: 14)),
          ],
          ledSuit: Suit.hearts,
          trumpSuit: Suit.spades,
        ),
        2,
      );
    });
  });
}
