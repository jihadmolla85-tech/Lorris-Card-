import 'package:flutter_test/flutter_test.dart';
import 'package:loris/loris.dart';

void main() {
  group('Dealer penalty rotation', () {
    test('moves right when dealer team crosses from negative to positive', () {
      expect(
        DealerRotation.nextDealer(
          playerCount: PlayerCount.four,
          currentDealerSeat: 2,
          previousDealerTeamScore: -1,
          currentDealerTeamScore: 1,
        ),
        1,
      );
    });

    test('moves right when dealer team crosses from zero to positive', () {
      expect(
        DealerRotation.nextDealer(
          playerCount: PlayerCount.four,
          currentDealerSeat: 2,
          previousDealerTeamScore: 0,
          currentDealerTeamScore: 1,
        ),
        1,
      );
    });

    test('does not move when score remains positive', () {
      expect(
        DealerRotation.nextDealer(
          playerCount: PlayerCount.four,
          currentDealerSeat: 2,
          previousDealerTeamScore: 2,
          currentDealerTeamScore: 4,
        ),
        2,
      );
    });

    test('does not move when score only reaches zero', () {
      expect(
        DealerRotation.nextDealer(
          playerCount: PlayerCount.six,
          currentDealerSeat: 4,
          previousDealerTeamScore: -3,
          currentDealerTeamScore: 0,
        ),
        4,
      );
    });

    test('does not move when dealer team remains negative', () {
      expect(
        DealerRotation.nextDealer(
          playerCount: PlayerCount.six,
          currentDealerSeat: 4,
          previousDealerTeamScore: -5,
          currentDealerTeamScore: -3,
        ),
        4,
      );
    });

    test('wraps around from seat zero to the last seat when moving right', () {
      expect(
        DealerRotation.nextDealer(
          playerCount: PlayerCount.six,
          currentDealerSeat: 0,
          previousDealerTeamScore: 0,
          currentDealerTeamScore: 5,
        ),
        5,
      );
    });

    test('rejects an invalid dealer seat', () {
      expect(
        () => DealerRotation.nextDealer(
          playerCount: PlayerCount.four,
          currentDealerSeat: 4,
          previousDealerTeamScore: -1,
          currentDealerTeamScore: 1,
        ),
        throwsArgumentError,
      );
    });
  });
}
