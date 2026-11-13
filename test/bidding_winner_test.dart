import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

void main() {
  group('Highest bid wins', () {
    test('player with the highest bid is selected', () {
      expect(
        BiddingWinner.selectHighestBidder(
          playerCount: PlayerCount.four,
          submissions: const {0: 5, 1: null, 2: 7, 3: 6},
        ),
        2,
      );
    });

    test('works for six players', () {
      expect(
        BiddingWinner.selectHighestBidder(
          playerCount: PlayerCount.six,
          submissions: const {0: 5, 1: 6, 2: null, 3: 7, 4: 8, 5: null},
        ),
        4,
      );
    });

    test('rejects incomplete bidding', () {
      expect(
        () => BiddingWinner.selectHighestBidder(
          playerCount: PlayerCount.four,
          submissions: const {0: 2, 1: null, 2: 5},
        ),
        throwsStateError,
      );
    });

    test('rejects all-pass round because it must be redealt', () {
      expect(
        () => BiddingWinner.selectHighestBidder(
          playerCount: PlayerCount.four,
          submissions: const {0: null, 1: null, 2: null, 3: null},
        ),
        throwsStateError,
      );
    });

    test('does not invent a tie-break rule for equal highest bids', () {
      expect(
        () => BiddingWinner.selectHighestBidder(
          playerCount: PlayerCount.four,
          submissions: const {0: 7, 1: 6, 2: 7, 3: null},
        ),
        throwsStateError,
      );
    });
  });
}
