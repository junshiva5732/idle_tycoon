import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'economy.dart';

/// 구매 수량 선택: ×1 / ×10 / ×100 / 최대.
enum BuyAmount { one, ten, hundred, max }

/// 게임 진행 상태. 100ms 마다 수익을 더하고, 변경이 생기면 리스너에 알린다.
///
/// 시간 계산은 [clock] 으로 주입해 테스트에서 고정할 수 있다.
class GameState extends ChangeNotifier {
  GameState({DateTime Function()? clock, math.Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? math.Random();

  final DateTime Function() _clock;
  final math.Random _random;

  // ── 저장되는 값 ─────────────────────────────────────────────────────
  double money = 0;

  /// 이번 회차(은퇴 전까지) 번 돈.
  double runEarned = 0;

  /// 전체 누적 수익. 은퇴해도 유지되며 명성·칭호 계산에 쓴다.
  double lifetimeEarned = 0;
  int tapLevel = 0;
  int fame = 0;
  List<int> owned = List.filled(Economy.businesses.length, 0);
  int totalTaps = 0;
  int retirements = 0;

  /// 2배 부스트가 끝나는 시각 (null = 없음). 벽시계 기준이라 앱을 꺼도 흐른다.
  DateTime? boostUntil;

  /// 마지막으로 저장/틱한 시각. 오프라인 수익 계산용.
  DateTime? lastSeen;

  // ── 세션 값 ─────────────────────────────────────────────────────────
  BuyAmount buyAmount = BuyAmount.one;

  /// 화면에 떠 있는 돈가방 (화면 비율 좌표 0~1). null 이면 없음.
  BagSpot? bagPosition;
  DateTime? _bagExpires;
  DateTime? _nextBagAt;

  Timer? _timer;
  DateTime? _lastTick;

  // ---------------------------------------------------------------- 파생 값

  double get fameMultiplier => Economy.fameMultiplier(fame);

  bool get boostActive => boostUntil != null && _clock().isBefore(boostUntil!);

  Duration get boostRemaining => boostActive ? boostUntil!.difference(_clock()) : Duration.zero;

  double get _boost => boostActive ? Economy.boostMultiplier : 1;

  /// 부스트를 뺀 초당 수익 (오프라인 계산용).
  double get baseIncomePerSecond {
    var sum = 0.0;
    for (var i = 0; i < owned.length; i++) {
      sum += Economy.businessIncome(i, owned[i]);
    }
    return sum * fameMultiplier;
  }

  double get incomePerSecond => baseIncomePerSecond * _boost;

  double get tapValue =>
      (Economy.tapBase(tapLevel) * fameMultiplier + baseIncomePerSecond * Economy.tapIpsShare) * _boost;

  int get rank => Economy.rankFor(lifetimeEarned);

  /// 지금 은퇴하면 얻는 명성.
  int get fameOnRetire => math.max(0, Economy.fameTotalFor(lifetimeEarned) - fame);

  /// 가장 비싼 보유 사업 다음 한 칸까지 보여준다 (나머지는 ???).
  int get visibleBusinesses {
    var last = -1;
    for (var i = 0; i < owned.length; i++) {
      if (owned[i] > 0) last = i;
    }
    return math.min(owned.length, last + 3);
  }

  /// 현재 구매 수량 설정으로 [index] 사업을 몇 개 사게 되는지. 최대 모드에서 0 이면 1개로 보여준다.
  int buyCount(int index) {
    final def = Economy.businesses[index];
    return switch (buyAmount) {
      BuyAmount.one => 1,
      BuyAmount.ten => 10,
      BuyAmount.hundred => 100,
      BuyAmount.max => math.max(1, Economy.maxAffordable(def.baseCost, owned[index], money)),
    };
  }

  double buyCost(int index) => Economy.bulkCost(Economy.businesses[index].baseCost, owned[index], buyCount(index));

  bool canBuy(int index) => money >= buyCost(index);

  double get tapUpgradeCost => Economy.tapUpgradeCost(tapLevel);

  // ---------------------------------------------------------------- 행동

  void tap() {
    _earn(tapValue);
    totalTaps++;
    notifyListeners();
  }

  bool buy(int index) {
    final cost = buyCost(index);
    if (money < cost) return false;
    money -= cost;
    owned[index] += buyCount(index);
    notifyListeners();
    return true;
  }

  bool upgradeTap() {
    final cost = tapUpgradeCost;
    if (money < cost) return false;
    money -= cost;
    tapLevel++;
    notifyListeners();
    return true;
  }

  void setBuyAmount(BuyAmount a) {
    buyAmount = a;
    notifyListeners();
  }

  /// 보상형 광고 시청 → 2배 부스트 연장 (최대 [Economy.boostMax]).
  void addBoost() {
    final now = _clock();
    final start = boostActive ? boostUntil! : now;
    var until = start.add(Economy.boostPerAd);
    final cap = now.add(Economy.boostMax);
    if (until.isAfter(cap)) until = cap;
    boostUntil = until;
    notifyListeners();
  }

  /// 광고 한 번으로 늘릴 수 있는 여유가 있는지.
  bool get canAddBoost => boostRemaining < Economy.boostMax - const Duration(seconds: 30);

  /// 보상(오프라인·돈가방)을 받는다.
  void grant(double amount) {
    _earn(amount);
    notifyListeners();
  }

  /// 은퇴: 돈·사업·탭 레벨 초기화, 명성 획득.
  bool retire() {
    final gain = fameOnRetire;
    if (gain <= 0) return false;
    fame += gain;
    retirements++;
    money = 0;
    runEarned = 0;
    tapLevel = 0;
    owned = List.filled(Economy.businesses.length, 0);
    bagPosition = null;
    notifyListeners();
    return true;
  }

  /// 처음부터 다시 (명성 포함 전부 삭제). 언어 설정은 따로 저장되므로 유지된다.
  void resetAll() {
    money = 0;
    runEarned = 0;
    lifetimeEarned = 0;
    tapLevel = 0;
    fame = 0;
    owned = List.filled(Economy.businesses.length, 0);
    totalTaps = 0;
    retirements = 0;
    boostUntil = null;
    bagPosition = null;
    _scheduleBag();
    notifyListeners();
  }

  /// 돈가방을 집었다: 가방을 치우고 기본 보상액을 돌려준다 (실제 지급은 [grant]).
  double takeBag() {
    bagPosition = null;
    _scheduleBag();
    notifyListeners();
    return Economy.bagReward(baseIncomePerSecond, Economy.tapBase(tapLevel) * fameMultiplier);
  }

  void _earn(double amount) {
    money += amount;
    runEarned += amount;
    lifetimeEarned += amount;
  }

  // ---------------------------------------------------------------- 시간

  /// 게임 루프 시작. 오프라인 동안 번 돈(보여줄 게 없으면 0)과 떠나 있던 시간을 돌려준다 — 아직 지급 전이다.
  ({double amount, Duration away}) start() {
    final now = _clock();
    var offline = 0.0;
    var away = Duration.zero;
    final last = lastSeen;
    if (last != null) {
      away = now.difference(last);
      if (away.inSeconds >= Economy.offlineMinSeconds) {
        offline = Economy.offlineEarnings(baseIncomePerSecond, away.inSeconds);
      }
    }
    lastSeen = now;
    _lastTick = now;
    _nextBagAt ??= now.add(const Duration(seconds: 30)); // 첫 가방은 빨리
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
    return (amount: offline, away: away);
  }

  /// 백그라운드로 갈 때. 타이머를 멈춰 오프라인 수익과 이중 계산되지 않게 한다.
  void pause() {
    _timer?.cancel();
    _timer = null;
    lastSeen = _clock();
  }

  @visibleForTesting
  void tick() {
    final now = _clock();
    final last = _lastTick ?? now;
    // 한 틱이 너무 길면 (기기 절전 등) 1초로 자른다. 긴 공백은 오프라인 보상으로 처리.
    final dt = (now.difference(last).inMicroseconds / 1e6).clamp(0.0, 1.0);
    _lastTick = now;
    lastSeen = now;
    _earn(incomePerSecond * dt);
    _updateBag(now);
    notifyListeners();
  }

  void _updateBag(DateTime now) {
    if (bagPosition != null) {
      if (now.isAfter(_bagExpires!)) {
        bagPosition = null;
        _scheduleBag();
      }
      return;
    }
    // 수익이 전혀 없을 때(첫 사업 구매 전)는 가방을 띄우지 않는다.
    if (runEarned <= 0 || _nextBagAt == null || now.isBefore(_nextBagAt!)) return;
    bagPosition = BagSpot(0.12 + _random.nextDouble() * 0.76, 0.15 + _random.nextDouble() * 0.6);
    _bagExpires = now.add(Economy.bagLifetime);
  }

  void _scheduleBag() {
    final secs = Economy.bagMinInterval + _random.nextInt(Economy.bagMaxInterval - Economy.bagMinInterval + 1);
    _nextBagAt = _clock().add(Duration(seconds: secs));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- 저장

  Map<String, dynamic> toJson() => {
    'v': 1,
    'money': money,
    'runEarned': runEarned,
    'lifetimeEarned': lifetimeEarned,
    'tapLevel': tapLevel,
    'fame': fame,
    'owned': owned,
    'totalTaps': totalTaps,
    'retirements': retirements,
    'boostUntil': boostUntil?.millisecondsSinceEpoch,
    'lastSeen': (lastSeen ?? _clock()).millisecondsSinceEpoch,
    'buyAmount': buyAmount.index,
  };

  void loadJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    money = d('money');
    runEarned = d('runEarned');
    lifetimeEarned = d('lifetimeEarned');
    tapLevel = (j['tapLevel'] as num?)?.toInt() ?? 0;
    fame = (j['fame'] as num?)?.toInt() ?? 0;
    totalTaps = (j['totalTaps'] as num?)?.toInt() ?? 0;
    retirements = (j['retirements'] as num?)?.toInt() ?? 0;
    final o = (j['owned'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
    // 사업이 추가된 새 버전에서도 옛 저장을 읽을 수 있게 길이를 맞춘다.
    owned = List.generate(Economy.businesses.length, (i) => i < o.length ? o[i] : 0);
    final b = j['boostUntil'] as int?;
    boostUntil = b == null ? null : DateTime.fromMillisecondsSinceEpoch(b);
    final l = j['lastSeen'] as int?;
    lastSeen = l == null ? null : DateTime.fromMillisecondsSinceEpoch(l);
    final ba = (j['buyAmount'] as num?)?.toInt() ?? 0;
    buyAmount = BuyAmount.values[ba.clamp(0, BuyAmount.values.length - 1)];
  }
}

/// 돈가방 위치 (탭 영역 대비 비율 좌표 0~1).
class BagSpot {
  final double dx;
  final double dy;
  const BagSpot(this.dx, this.dy);
}
