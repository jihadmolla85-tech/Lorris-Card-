import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

void main() {
  group('Zero-sum match score', () {
    test('the opposing team always has the negative of team one score', () {
      final match = LorisMatchScore();
      match.applyContractScore(
        score: const ContractScore(
          bidderSucceeded: true,
          bidderTeamPoints: 5,
          opposingTeamPoints: 0,
        ),
        bidderIsTeamOne: true,
      );
      expect(match.teamOneScore, 5);
      expect(match.teamTwoScore, -5);
    });

    test('team one wins immediately at +32', () {
      final match = LorisMatchScore(initialTeamOneScore: 16);
      match.applyContractScore(
        score: const ContractScore(
          bidderSucceeded: true,
          bidderTeamPoints: 16,
          opposingTeamPoints: 0,
        ),
        bidderIsTeamOne: true,
      );
      expect(match.teamOneScore, 32);
      expect(match.teamTwoScore, -32);
      expect(match.winner, LorisMatchWinner.teamOne);
      expect(
        () => match.applyContractScore(
          score: const ContractScore(
            bidderSucceeded: true,
            bidderTeamPoints: 5,
            opposingTeamPoints: 0,
          ),
          bidderIsTeamOne: false,
        ),
        throwsStateError,
      );
    });

    test('team two wins when its score reaches +32', () {
      final match = LorisMatchScore(initialTeamOneScore: -16);
      match.applyContractScore(
        score: const ContractScore(
          bidderSucceeded: true,
          bidderTeamPoints: 16,
          opposingTeamPoints: 0,
        ),
        bidderIsTeamOne: false,
      );
      expect(match.teamOneScore, -32);
      expect(match.teamTwoScore, 32);
      expect(match.winner, LorisMatchWinner.teamTwo);
    });
  });
}
