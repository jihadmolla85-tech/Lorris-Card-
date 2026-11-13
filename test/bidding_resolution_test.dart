import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

void main() {
  group('Bidding resolution', () {
    test('all players pass: redeal is required (4 players)', () {
      expect(
        BiddingResolution<String>.resolve(
          playerCount: PlayerCount.four,
          submissions: const {0: null, 1: null, 2: null, 3: null},
        ),
        BiddingOutcome.redeal,
      );
    });

    test('all players pass: redeal is required (6 players)', () {
      expect(
        BiddingResolution<String>.resolve(
          playerCount: PlayerCount.six,
          submissions: const {
            0: null, 1: null, 2: null, 3: null, 4: null, 5: null,
          },
        ),
        BiddingOutcome.redeal,
      );
    });

    test('incomplete bidding remains pending', () {
      expect(
        BiddingResolution<String>.resolve(
          playerCount: PlayerCount.four,
          submissions: const {0: null, 1: null, 2: null},
        ),
        BiddingOutcome.pending,
      );
    });

    test('any non-pass bid means a contract was bid', () {
      expect(
        BiddingResolution<String>.resolve(
          playerCount: PlayerCount.four,
          submissions: const {
            0: null, 1: 'bid', 2: null, 3: null,
          },
        ),
        BiddingOutcome.contractWon,
      );
    });
  });
}
