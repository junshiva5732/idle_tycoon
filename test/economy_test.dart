import 'package:flutter_test/flutter_test.dart';
import 'package:idle_tycoon/game/economy.dart';
import 'package:idle_tycoon/game/game_state.dart';

void main() {
  group('Economy', () {
    test('bulkCost equals sum of single purchases', () {
      const base = 15.0;
      var sum = 0.0;
      for (var i = 0; i < 10; i++) {
        sum += Economy.bulkCost(base, 5 + i, 1);
      }
      expect(Economy.bulkCost(base, 5, 10), closeTo(sum, 1e-6));
    });

    test('maxAffordable is the largest n that fits', () {
      for (final money in [0.0, 14.0, 15.0, 100.0, 1e6, 1e12]) {
        final n = Economy.maxAffordable(15, 3, money);
        expect(Economy.bulkCost(15, 3, n), lessThanOrEqualTo(money));
        expect(Economy.bulkCost(15, 3, n + 1), greaterThan(money));
      }
    });

    test('milestones double income', () {
      expect(Economy.milestoneMultiplier(24), 1);
      expect(Economy.milestoneMultiplier(25), 2);
      expect(Economy.milestoneMultiplier(100), 8);
      expect(Economy.nextMilestone(0), 25);
      expect(Economy.nextMilestone(500), isNull);
    });

    test('fame grows with sqrt of lifetime earnings', () {
      expect(Economy.fameTotalFor(0), 0);
      expect(Economy.fameTotalFor(999999), 0);
      expect(Economy.fameTotalFor(1e6), 1);
      expect(Economy.fameTotalFor(1e8), 10);
    });

    test('offline earnings are capped', () {
      expect(Economy.offlineEarnings(10, 100), 10 * 100 * Economy.offlineRate);
      expect(Economy.offlineEarnings(10, 999999), 10 * Economy.offlineCapSeconds * Economy.offlineRate);
    });

    test('ranks', () {
      expect(Economy.rankFor(0), 0);
      expect(Economy.rankFor(1e3), 1);
      expect(Economy.rankFor(1e20), Economy.rankThresholds.length - 1);
    });
  });

  group('NumberFormatter', () {
    test('western units', () {
      expect(NumberFormatter.format(0.5, 'en'), '0.5');
      expect(NumberFormatter.format(1.01, 'en'), '1');
      expect(NumberFormatter.format(999, 'en'), '999');
      expect(NumberFormatter.format(1234, 'en'), '1.23K');
      expect(NumberFormatter.format(12345678, 'en'), '12.3M');
      expect(NumberFormatter.format(999999, 'en'), '1.00M');
    });

    test('east asian 4-digit units', () {
      expect(NumberFormatter.format(9999, 'ko'), '9,999');
      expect(NumberFormatter.format(12345, 'ko'), '1.23만');
      expect(NumberFormatter.format(123456789, 'ko'), '1.23억');
      expect(NumberFormatter.format(99999999, 'ko'), '1.00억');
      expect(NumberFormatter.format(1e12, 'ja'), '1.00兆');
      expect(NumberFormatter.format(1e8, 'zh'), '1.00亿');
    });

    test('huge numbers fall back to exponent', () {
      expect(NumberFormatter.format(1e300, 'en'), contains('e300'));
    });
  });

  group('GameState', () {
    late DateTime now;
    late GameState g;
    setUp(() {
      now = DateTime(2026, 1, 1);
      g = GameState(clock: () => now);
    });
    tearDown(() => g.dispose());

    test('tap earns and buying spends', () {
      for (var i = 0; i < 15; i++) {
        g.tap();
      }
      expect(g.money, 15);
      expect(g.buy(0), isTrue);
      expect(g.money, 0);
      expect(g.owned[0], 1);
      expect(g.baseIncomePerSecond, 0.5);
    });

    test('tick adds income, boost doubles it', () {
      g.owned[0] = 10; // 5/s
      g.start();
      now = now.add(const Duration(seconds: 1));
      g.tick();
      expect(g.money, closeTo(5, 1e-9));
      g.addBoost();
      now = now.add(const Duration(seconds: 1));
      g.tick();
      expect(g.money, closeTo(15, 1e-9));
      expect(g.boostRemaining, const Duration(minutes: 4, seconds: 59));
      g.pause();
    });

    test('boost stacks up to the cap', () {
      for (var i = 0; i < 20; i++) {
        g.addBoost();
      }
      expect(g.boostRemaining, Economy.boostMax);
      expect(g.canAddBoost, isFalse);
    });

    test('offline earnings reported on start, not granted', () {
      g.owned[0] = 10; // 5/s
      g.lastSeen = now;
      now = now.add(const Duration(minutes: 10));
      final r = g.start();
      expect(r.away, const Duration(minutes: 10));
      expect(r.amount, 5 * 600 * Economy.offlineRate);
      expect(g.money, 0);
      g.pause();
    });

    test('retire resets run and grants fame', () {
      expect(g.retire(), isFalse);
      g.grant(4e6);
      g.owned[0] = 50;
      g.tapLevel = 3;
      expect(g.fameOnRetire, 2);
      expect(g.retire(), isTrue);
      expect(g.fame, 2);
      expect(g.money, 0);
      expect(g.owned.every((o) => o == 0), isTrue);
      expect(g.tapLevel, 0);
      expect(g.fameMultiplier, closeTo(1.2, 1e-9));
      expect(g.fameOnRetire, 0);
    });

    test('json round trip', () {
      g.grant(1234);
      g.owned[2] = 7;
      g.fame = 3;
      g.addBoost();
      g.setBuyAmount(BuyAmount.max);
      final copy = GameState(clock: () => now)..loadJson(g.toJson());
      expect(copy.money, 1234);
      expect(copy.owned[2], 7);
      expect(copy.fame, 3);
      expect(copy.boostUntil, g.boostUntil);
      expect(copy.buyAmount, BuyAmount.max);
      copy.dispose();
    });

    test('bag appears only after earning, reward uses income', () {
      g.start();
      now = now.add(const Duration(minutes: 5));
      g.tick();
      expect(g.bagPosition, isNull); // 아직 번 돈이 없음
      g.owned[0] = 10;
      now = now.add(const Duration(milliseconds: 500));
      g.tick();
      expect(g.bagPosition, isNotNull);
      expect(g.takeBag(), 5 * 60);
      expect(g.bagPosition, isNull);
      g.pause();
    });
  });
}
