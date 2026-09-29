import 'dart:math' as math;

/// 게임 밸런스 상수와 순수 계산 함수. 상태를 갖지 않으므로 유닛 테스트 대상.
///
/// 숫자는 전부 double (최대 ~1e308). 후반부 수치가 커져도 정수 오버플로가 없다.
class Economy {
  Economy._();

  /// 사업 구매 비용 증가율: n 번째 구매 가격 = baseCost × costGrowth^n.
  static const costGrowth = 1.15;

  /// 보유 수가 이 값들에 도달할 때마다 그 사업 수익 ×2.
  static const milestones = [25, 50, 100, 150, 200, 300, 400, 500];

  /// 탭 강화 비용: tapBaseCost × tapCostGrowth^level.
  static const tapBaseCost = 20.0;
  static const tapCostGrowth = 1.35;

  /// 탭 1회에 초당 수익의 이 비율이 추가로 붙는다 (후반에도 탭이 의미 있도록).
  static const tapIpsShare = 0.03;

  /// 명성 1개당 전체 수익 +10%.
  static const fameBonus = 0.10;

  /// 누적 수익이 이 값일 때 명성 1개. 명성 총량 = floor(sqrt(누적/fameUnit)).
  static const fameUnit = 1e6;

  /// 오프라인 수익: 초당 수익 × offlineRate, 최대 offlineCapSeconds.
  static const offlineRate = 0.5;
  static const offlineCapSeconds = 3 * 3600;

  /// 이보다 짧게 나갔다 오면 오프라인 보상 창을 띄우지 않는다.
  static const offlineMinSeconds = 60;

  /// 보상형 광고 1회당 2배 부스트 시간, 누적 최대치.
  static const boostPerAd = Duration(minutes: 5);
  static const boostMax = Duration(minutes: 60);
  static const boostMultiplier = 2.0;

  /// 보상형 광고로 받는 배율 (오프라인 보상, 돈가방).
  static const adRewardMultiplier = 10;

  /// 돈가방 등장 간격(초)과 화면에 머무는 시간.
  static const bagMinInterval = 90;
  static const bagMaxInterval = 180;
  static const bagLifetime = Duration(seconds: 20);

  static const businesses = <BusinessDef>[
    BusinessDef(baseCost: 15, baseIncome: 0.5, emoji: '🥫'),
    BusinessDef(baseCost: 150, baseIncome: 4, emoji: '🐟'),
    BusinessDef(baseCost: 1.6e3, baseIncome: 30, emoji: '🏪'),
    BusinessDef(baseCost: 2e4, baseIncome: 250, emoji: '🍗'),
    BusinessDef(baseCost: 2.6e5, baseIncome: 2e3, emoji: '☕'),
    BusinessDef(baseCost: 3.5e6, baseIncome: 1.6e4, emoji: '🖥️'),
    BusinessDef(baseCost: 5e7, baseIncome: 1.4e5, emoji: '🏢'),
    BusinessDef(baseCost: 8e8, baseIncome: 1.2e6, emoji: '💻'),
    BusinessDef(baseCost: 1.3e10, baseIncome: 1.1e7, emoji: '🎤'),
    BusinessDef(baseCost: 2.2e11, baseIncome: 1e8, emoji: '🚀'),
  ];

  /// 칭호 기준 (누적 수익). 인덱스가 [ranks] 이모지와 문자열 목록에 대응한다.
  static const rankThresholds = [0.0, 1e3, 1e5, 1e7, 1e9, 1e11, 1e13, 1e16];
  static const rankEmojis = ['🥺', '🙂', '😀', '😎', '🤑', '🤵', '👑', '🪐'];

  static int rankFor(double lifetimeEarned) {
    var r = 0;
    for (var i = 0; i < rankThresholds.length; i++) {
      if (lifetimeEarned >= rankThresholds[i]) r = i;
    }
    return r;
  }

  // ---------------------------------------------------------------- 사업

  /// 보유 [owned] 개에서 [n] 개를 더 살 때 총비용 (등비수열 합).
  static double bulkCost(double baseCost, int owned, int n) {
    if (n <= 0) return 0;
    final r = costGrowth;
    return baseCost * math.pow(r, owned) * (math.pow(r, n) - 1) / (r - 1);
  }

  /// [money] 로 살 수 있는 최대 개수.
  static int maxAffordable(double baseCost, int owned, double money) {
    final r = costGrowth;
    final first = baseCost * math.pow(r, owned);
    if (money < first) return 0;
    var n = (math.log(money * (r - 1) / first + 1) / math.log(r)).floor();
    // 부동소수 오차 보정
    while (n > 0 && bulkCost(baseCost, owned, n) > money) {
      n--;
    }
    while (bulkCost(baseCost, owned, n + 1) <= money) {
      n++;
    }
    return n;
  }

  /// 보유 수에 따른 마일스톤 배율 (2^도달 개수).
  static double milestoneMultiplier(int owned) {
    var m = 1.0;
    for (final t in milestones) {
      if (owned >= t) m *= 2;
    }
    return m;
  }

  /// 다음 마일스톤 (없으면 null).
  static int? nextMilestone(int owned) {
    for (final t in milestones) {
      if (owned < t) return t;
    }
    return null;
  }

  /// 사업 하나의 초당 수익 (전역 배율 제외).
  static double businessIncome(int index, int owned) =>
      owned == 0 ? 0 : businesses[index].baseIncome * owned * milestoneMultiplier(owned);

  // ---------------------------------------------------------------- 탭

  static double tapUpgradeCost(int level) => tapBaseCost * math.pow(tapCostGrowth, level);

  /// 탭 기본값: 레벨+1, 10레벨마다 ×2.
  static double tapBase(int level) => (level + 1) * math.pow(2, level ~/ 10).toDouble();

  // ---------------------------------------------------------------- 명성

  static double fameMultiplier(int fame) => 1 + fame * fameBonus;

  /// 누적 수익으로 얻을 수 있는 명성 총량.
  static int fameTotalFor(double lifetimeEarned) =>
      lifetimeEarned <= 0 ? 0 : math.sqrt(lifetimeEarned / fameUnit).floor();

  // ---------------------------------------------------------------- 오프라인

  static double offlineEarnings(double ips, int seconds) {
    final s = seconds.clamp(0, offlineCapSeconds);
    return ips * s * offlineRate;
  }

  /// 돈가방 기본 보상: 1분치 수익과 탭 30회 중 큰 쪽.
  static double bagReward(double ips, double tapValue) => math.max(ips * 60, tapValue * 30);
}

class BusinessDef {
  final double baseCost;
  final double baseIncome;
  final String emoji;
  const BusinessDef({required this.baseCost, required this.baseIncome, required this.emoji});
}

/// 큰 수 표시. 한·중·일은 4자리 단위(만/억/조…), 그 외는 3자리 단위(K/M/B…).
class NumberFormatter {
  NumberFormatter._();

  static const _western = ['', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No', 'Dc'];
  static const _ko = ['', '만', '억', '조', '경', '해', '자', '양', '구', '간', '정', '재', '극'];
  static const _ja = ['', '万', '億', '兆', '京', '垓', '秭', '穣', '溝', '澗', '正', '載', '極'];
  static const _zh = ['', '万', '亿', '兆', '京', '垓', '秭', '穰', '沟', '涧', '正', '载', '极'];

  static String format(double v, String lang) {
    if (v.isNaN || v.isInfinite) return '∞';
    if (v < 0) return '-${format(-v, lang)}';
    final units = switch (lang) {
      'ko' => _ko,
      'ja' => _ja,
      'zh' => _zh,
      _ => _western,
    };
    final step = units == _western ? 3 : 4;
    if (v < 1000) {
      // 작은 수는 소수 한 자리까지 (초당 0.5 같은 초반 값). 1.0 → 1
      if (v >= 10) return v.floor().toString();
      final s = v.toStringAsFixed(1);
      return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    }
    if (v < math.pow(10, step)) return _commas(v.floor());
    var exp = (math.log(v) / math.ln10 + 1e-9).floor();
    var group = exp ~/ step;
    if (group >= units.length) {
      final mant = v / math.pow(10, exp);
      return '${mant.toStringAsFixed(2)}e$exp';
    }
    var scaled = v / math.pow(10, group * step);
    // 반올림으로 다음 단위가 되는 경우 (9999.9만 → 1.00억)
    if (double.parse(_sig(scaled)) >= math.pow(10, step) && group + 1 < units.length) {
      group++;
      scaled = v / math.pow(10, group * step);
    }
    return '${_sig(scaled)}${units[group]}';
  }

  /// 유효숫자 3~4자리: 1.23 / 12.3 / 123 / 1234.
  static String _sig(double x) {
    if (x < 10) return x.toStringAsFixed(2);
    if (x < 100) return x.toStringAsFixed(1);
    return x.toStringAsFixed(0);
  }

  static String _commas(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}
