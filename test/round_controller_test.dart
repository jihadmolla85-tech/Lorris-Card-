import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

class FixedRandom implements RandomSource {
  @override
  void shuffle<T>(List<T> values) {
    // Keep the deck order deterministic for controller tests.
  }
}

void main() {
  group('LorisRoundController', () {
    test('starts with bidding to the right of dealer and accepts ordered bids', () {
      final game = LorisRoundController(
        playerCount: PlayerCount.four,
        teamBySeat: const {0: LorisTeam.teamOne, 1: LorisTeam.teamTwo, 2: LorisTeam.teamOne, 3: LorisTeam.teamTwo},
        dealerSeat: 0,
        matchScore: LorisMatchScore(),
        random: FixedRandom(),
      );
      game.startRound();
      expect(game.phase, RoundPhase.bidding);
      expect(game.currentPlayerSeat, 3);
      game.submitBid(seat: 3, bid: 5);
      expect(game.currentPlayerSeat, 2);
      game.submitBid(seat: 2, bid: 6);
      game.submitBid(seat: 1, bid: null);
      game.submitBid(seat: 0, bid: null);
      expect(game.phase, RoundPhase.trumpSelection);
      expect(game.winningBidderSeat, 2);
      expect(game.contractBid, 6);
    });

    test('only winning bidder can declare trump', () {
      final game = LorisRoundController(
        playerCount: PlayerCount.four,
        teamBySeat: const {0: LorisTeam.teamOne, 1: LorisTeam.teamTwo, 2: LorisTeam.teamOne, 3: LorisTeam.teamTwo},
        dealerSeat: 0,
        matchScore: LorisMatchScore(),
        random: FixedRandom(),
      );
      game.startRound();
      game.submitBid(seat: 3, bid: 5);
      game.submitBid(seat: 2, bid: null);
      game.submitBid(seat: 1, bid: null);
      game.submitBid(seat: 0, bid: null);
      expect(() => game.declareTrump(seat: 0, suit: Suit.hearts), throwsStateError);
      game.declareTrump(seat: 3, suit: Suit.hearts);
      expect(game.phase, RoundPhase.playing);
      expect(game.currentPlayerSeat, 3);
    });
  });
}
