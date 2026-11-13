import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

void main() {
  group('Contract scoring', () {
    test('failed 5-call gives 10 points to opposing team', () {
      final score = LorisContractScoring.score(bid: 5, pointsTaken: 4);
      expect(score.bidderSucceeded, isFalse);
      expect(score.bidderTeamPoints, 0);
      expect(score.opposingTeamPoints, 10);
    });

    test('failed 7-call gives 14 points to opposing team', () {
      final score = LorisContractScoring.score(bid: 7, pointsTaken: 6);
      expect(score.opposingTeamPoints, 14);
    });

    test('failed special 8-call gives 16 points to opposing team', () {
      final score = LorisContractScoring.score(bid: 8, pointsTaken: 7);
      expect(score.opposingTeamPoints, 16);
    });

    test('successful special 8-call gives bidder team 16 points', () {
      final score = LorisContractScoring.score(bid: 8, pointsTaken: 8, bidderTeamScore: 0);
      expect(score.bidderSucceeded, isTrue);
      expect(score.bidderTeamPoints, 16);
      expect(score.opposingTeamPoints, 0);
    });

    test('successful ordinary call awards the called points', () {
      final score = LorisContractScoring.score(bid: 6, pointsTaken: 6);
      expect(score.bidderTeamPoints, 6);
      expect(score.opposingTeamPoints, 0);
    });

    test('rejects out-of-range bid and points', () {
      expect(
        () => LorisContractScoring.score(bid: 4, pointsTaken: 4),
        throwsRangeError,
      );
      expect(
        () => LorisContractScoring.score(bid: 5, pointsTaken: 9),
        throwsRangeError,
      );
    });
  });
}
