import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

class NoOpRandom implements RandomSource {
  @override
  void shuffle<T>(List<T> values) {}
}

void main() {
  group('LORIS deck model', () {
    test('4-player deck has 32 cards and LORIS replaces spades 7', () {
      final deck = LorisDeck.create(PlayerCount.four);
      expect(deck.length, 32);
      expect(deck.where((card) => card.isLoris).length, 1);
      expect(deck.where((card) => card.suit == Suit.spades && card.rank == 7), isEmpty);
      expect(deck.where((card) => card.isLoris).single.replacesRank, 7);
    });
    test('6-player deck has 48 cards and LORIS replaces spades 3', () {
      final deck = LorisDeck.create(PlayerCount.six);
      expect(deck.length, 48);
      expect(deck.where((card) => card.isLoris).length, 1);
      expect(deck.where((card) => card.suit == Suit.spades && card.rank == 3), isEmpty);
      expect(deck.where((card) => card.isLoris).single.replacesRank, 3);
    });
    test('deal gives every player exactly 8 unique cards', () {
      for (final count in PlayerCount.values) {
        final deal = LorisDeck.deal(count, dealerSeat: 0, random: NoOpRandom());
        expect(deal.hands.length, count.value);
        expect(deal.hands.values.every((hand) => hand.length == 8), isTrue);
        final dealt = deal.hands.values.expand((hand) => hand).toList();
        expect(dealt.toSet().length, dealt.length);
        expect(dealt.length, count.value * 8);
        expect(deal.remainingCards, isEmpty);
      }
    });
    test('invalid dealer seat is rejected', () {
      expect(() => LorisDeck.deal(PlayerCount.four, dealerSeat: 4, random: NoOpRandom()), throwsArgumentError);
    });
  });
}
