import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

void main() {
  group('Team trick scoring', () {
    test('4-player round awards one point to the winning team per trick', () {
      final tracker = TrickScoreTracker(
        playerCount: PlayerCount.four,
        teamBySeat: const {
          0: LorisTeam.teamOne,
          1: LorisTeam.teamTwo,
          2: LorisTeam.teamOne,
          3: LorisTeam.teamTwo,
        },
      );
      tracker.recordTrickWinner(0);
      tracker.recordTrickWinner(1);
      tracker.recordTrickWinner(2);
      expect(tracker.pointsFor(LorisTeam.teamOne), 2);
      expect(tracker.pointsFor(LorisTeam.teamTwo), 1);
      expect(tracker.completedTricks, 3);
    });

    test('6-player round supports three players on each team', () {
      final tracker = TrickScoreTracker(
        playerCount: PlayerCount.six,
        teamBySeat: const {
          0: LorisTeam.teamOne,
          1: LorisTeam.teamTwo,
          2: LorisTeam.teamOne,
          3: LorisTeam.teamTwo,
          4: LorisTeam.teamOne,
          5: LorisTeam.teamTwo,
        },
      );
      tracker.recordTrickWinner(5);
      expect(tracker.pointsFor(LorisTeam.teamTwo), 1);
      expect(tracker.pointsFor(LorisTeam.teamOne), 0);
    });

    test('round is complete after eight tricks and rejects a ninth', () {
      final tracker = TrickScoreTracker(
        playerCount: PlayerCount.four,
        teamBySeat: const {
          0: LorisTeam.teamOne,
          1: LorisTeam.teamTwo,
          2: LorisTeam.teamOne,
          3: LorisTeam.teamTwo,
        },
      );
      for (var i = 0; i < 8; i++) {
        tracker.recordTrickWinner(i % 2);
      }
      expect(tracker.isComplete, isTrue);
      expect(tracker.completedTricks, 8);
      expect(tracker.pointsFor(LorisTeam.teamOne), 4);
      expect(tracker.pointsFor(LorisTeam.teamTwo), 4);
      expect(() => tracker.recordTrickWinner(0), throwsStateError);
    });

    test('rejects unbalanced team assignments', () {
      expect(
        () => TrickScoreTracker(
          playerCount: PlayerCount.four,
          teamBySeat: const {
            0: LorisTeam.teamOne,
            1: LorisTeam.teamOne,
            2: LorisTeam.teamOne,
            3: LorisTeam.teamTwo,
          },
        ),
        throwsArgumentError,
      );
    });

    test('rejects an unknown winner seat', () {
      final tracker = TrickScoreTracker(
        playerCount: PlayerCount.four,
        teamBySeat: const {
          0: LorisTeam.teamOne,
          1: LorisTeam.teamTwo,
          2: LorisTeam.teamOne,
          3: LorisTeam.teamTwo,
        },
      );
      expect(() => tracker.recordTrickWinner(4), throwsArgumentError);
    });
  });
}
