import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../game/economy.dart';
import '../game/game_state.dart';
import '../l10n/strings.dart';
import '../services/storage.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/tap_area.dart';

/// 게임 화면 하나로 구성된다: 상단 정보 · 탭 영역 · 구매 목록 · 배너.
class GameScreen extends StatefulWidget {
  final GameState game;
  final Storage storage;
  const GameScreen({super.key, required this.game, required this.storage});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  GameState get game => widget.game;
  S get s => S.of(context);

  Timer? _autosave;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autosave = Timer.periodic(const Duration(seconds: 10), (_) => _save());
    _resume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosave?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 광고 화면이 덮은 건 자리를 비운 게 아니다: 게임은 계속 돈다.
    if (AdManager.instance.isShowingAd) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (_running) {
          game.pause();
          _running = false;
          _save();
        }
      case AppLifecycleState.resumed:
        if (!_running) _resume();
      case AppLifecycleState.inactive:
        break;
    }
  }

  bool _running = false;

  void _resume() {
    _running = true;
    final offline = game.start();
    if (offline.amount > 0) {
      // 첫 프레임 뒤에 (initState 에서는 context 로 다이얼로그를 못 띄운다)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showReward(title: s.welcomeBack, body: s.offlineBody(s.duration(offline.away)), amount: offline.amount);
      });
    }
  }

  void _save() => widget.storage.saveGame(game.toJson());

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  // ---------------------------------------------------------------- 보상형 광고

  void _watchBoost() {
    final shown = AdManager.instance.showRewarded(
      onReward: () {
        game.addBoost();
        _save();
        if (mounted) _snack(s.boostStarted);
      },
    );
    if (!shown) _snack(s.adNotReady);
  }

  /// 오프라인 보상·돈가방 공용: "받기" 또는 "광고 보고 10배 받기".
  Future<void> _showReward({required String title, required String body, required double amount}) async {
    if (_dialogOpen) {
      game.grant(amount); // 다이얼로그가 겹치면 그냥 지급
      return;
    }
    _dialogOpen = true;
    const x = Economy.adRewardMultiplier;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(body),
            const SizedBox(height: 16),
            Text(
              '💰 ${s.n(amount)}',
              style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.ondemand_video_rounded),
                label: Text(
                  '${s.collectAd(x)}  💰 ${s.n(amount * x)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: () {
                  var rewarded = false;
                  final shown = AdManager.instance.showRewarded(
                    onReward: () => rewarded = true,
                    // 광고를 중간에 닫아도 기본 보상은 준다.
                    onClosed: () {
                      game.grant(rewarded ? amount * x : amount);
                      _save();
                    },
                  );
                  if (shown) {
                    Navigator.pop(ctx);
                  } else {
                    _snack(s.adNotReady);
                  }
                },
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  game.grant(amount);
                  Navigator.pop(ctx);
                },
                child: Text(s.collect),
              ),
            ],
          ),
        ],
      ),
    );
    _dialogOpen = false;
    _save();
  }

  void _onBag() {
    final amount = game.takeBag();
    _showReward(title: s.bagTitle, body: s.bagBody, amount: amount);
  }

  // ---------------------------------------------------------------- 은퇴 / 메뉴

  Future<void> _showRetire() async {
    final gain = game.fameOnRetire;
    final nextNeed = Economy.fameUnit * (game.fame + 1) * (game.fame + 1);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.retireTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.fameInfo(game.fame, (game.fame * Economy.fameBonus * 100).round()),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              gain > 0
                  ? s.retireBody(gain, ((game.fame + gain) * Economy.fameBonus * 100).round())
                  : s.retireNotYet(s.n(nextNeed)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          if (gain > 0) FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.retireGain(gain))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    AdManager.instance.showInterstitialThen(() {
      game.retire();
      _save();
    });
  }

  Future<void> _onMenu(String v) async {
    switch (v) {
      case 'lang':
        await _showLanguage();
      case 'help':
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.howToPlay),
            content: SingleChildScrollView(child: Text(s.helpBody)),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close))],
          ),
        );
      case 'stats':
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.stats),
            content: Text(
              s.statsBody(
                lifetime: s.n(game.lifetimeEarned),
                taps: game.totalTaps,
                retirements: game.retirements,
                fame: game.fame,
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close))],
          ),
        );
      case 'reset':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.resetGame),
            content: Text(s.resetConfirm),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.delete),
              ),
            ],
          ),
        );
        if (ok == true) {
          game.resetAll();
          _save();
        }
    }
  }

  Future<void> _showLanguage() async {
    final controller = LocaleController.of(context);
    final picked = await showDialog<Locale?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.language),
        children: [
          RadioGroup<Locale?>(
            groupValue: controller.value,
            onChanged: (v) => Navigator.pop(ctx, v ?? const Locale('und')),
            child: Column(
              children: [
                for (final l in <Locale?>[null, ...S.supported])
                  RadioListTile<Locale?>(value: l, title: Text(l == null ? s.systemLanguage : S.nativeName(l))),
              ],
            ),
          ),
        ],
      ),
    );
    if (!mounted || picked == null) return;
    controller.value = picked.languageCode == 'und' ? null : picked;
  }

  // ---------------------------------------------------------------- 화면

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: game,
        builder: (context, _) => Column(
          children: [
            _header(context),
            Expanded(
              flex: 4,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFB74D), Color(0xFFF57C00)],
                  ),
                ),
                child: TapArea(game: game, onBag: _onBag),
              ),
            ),
            Expanded(flex: 7, child: _shop(context)),
          ],
        ),
      ),
      bottomNavigationBar: const BannerAdWidget(),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final boost = game.boostRemaining;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${Economy.rankEmojis[game.rank]} ${s.ranks[game.rank]}',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (game.fame > 0) ...[
                    const SizedBox(width: 8),
                    Text('⭐ ${game.fame}', style: theme.textTheme.titleSmall),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: s.retire,
                    icon: Badge(isLabelVisible: game.fameOnRetire > 0, child: const Icon(Icons.stars_rounded)),
                    onPressed: _showRetire,
                  ),
                  PopupMenuButton<String>(
                    onSelected: _onMenu,
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'help', child: Text(s.howToPlay)),
                      PopupMenuItem(value: 'stats', child: Text(s.stats)),
                      PopupMenuItem(value: 'lang', child: Text(s.language)),
                      PopupMenuItem(value: 'reset', child: Text(s.resetGame)),
                    ],
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '💰 ${s.n(game.money)}',
                            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          s.perSec(game.incomePerSecond),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: game.boostActive ? Colors.deepOrange : theme.colorScheme.onSurfaceVariant,
                            fontWeight: game.boostActive ? FontWeight.w700 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _BoostButton(
                      label: game.boostActive ? '${s.boost2x} ${_mmss(boost)}' : s.boost2x,
                      sub: game.canAddBoost ? s.boostAd(Economy.boostPerAd.inMinutes) : s.boostMaxed,
                      active: game.boostActive,
                      onPressed: game.canAddBoost ? _watchBoost : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _mmss(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _shop(BuildContext context) {
    final visible = game.visibleBusinesses;
    final hasLocked = visible < Economy.businesses.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SegmentedButton<BuyAmount>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              const ButtonSegment(value: BuyAmount.one, label: Text('×1')),
              const ButtonSegment(value: BuyAmount.ten, label: Text('×10')),
              const ButtonSegment(value: BuyAmount.hundred, label: Text('×100')),
              ButtonSegment(value: BuyAmount.max, label: Text(s.buyMax)),
            ],
            selected: {game.buyAmount},
            onSelectionChanged: (v) => game.setBuyAmount(v.first),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            children: [
              _ShopRow(
                emoji: '👆',
                title: '${s.tapUpgrade}  ${s.level(game.tapLevel)}',
                subtitle: s.tapUpgradeDesc,
                cost: s.n(game.tapUpgradeCost),
                buyLabel: '+1',
                enabled: game.money >= game.tapUpgradeCost,
                onBuy: game.upgradeTap,
              ),
              for (var i = 0; i < visible; i++) _businessRow(i),
              if (hasLocked)
                _ShopRow(
                  emoji: '🔒',
                  title: s.locked,
                  subtitle: s.unlockAt(s.n(Economy.businesses[visible].baseCost)),
                  cost: null,
                  buyLabel: '',
                  enabled: false,
                  onBuy: null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _businessRow(int i) {
    final def = Economy.businesses[i];
    final owned = game.owned[i];
    final next = Economy.nextMilestone(owned);
    final income =
        Economy.businessIncome(i, owned) * game.fameMultiplier * (game.boostActive ? Economy.boostMultiplier : 1);
    final prevMilestone = Economy.milestones.lastWhere((m) => m <= owned, orElse: () => 0);
    return _ShopRow(
      emoji: def.emoji,
      title: s.businessNames[i],
      subtitle: owned == 0 ? s.perSec(def.baseIncome * game.fameMultiplier) : '${s.owned(owned)} · ${s.perSec(income)}',
      progress: next == null ? null : (owned - prevMilestone) / (next - prevMilestone),
      progressLabel: next == null ? null : s.milestone(next),
      cost: s.n(game.buyCost(i)),
      buyLabel: '×${game.buyCount(i)}',
      enabled: game.canBuy(i),
      onBuy: () => game.buy(i),
    );
  }
}

class _BoostButton extends StatelessWidget {
  final String label;
  final String sub;
  final bool active;
  final VoidCallback? onPressed;
  const _BoostButton({required this.label, required this.sub, required this.active, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: active ? Colors.deepOrange : const Color(0xFF7E57C2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 18),
              const SizedBox(width: 2),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          Text(sub, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

class _ShopRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final double? progress;
  final String? progressLabel;
  final String? cost;
  final String buyLabel;
  final bool enabled;
  final VoidCallback? onBuy;

  const _ShopRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.progress,
    this.progressLabel,
    required this.cost,
    required this.buyLabel,
    required this.enabled,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (progress != null) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: progress, minHeight: 5),
                    ),
                    Text(progressLabel!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ],
              ),
            ),
            if (cost != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: enabled ? onBuy : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(buyLabel, style: const TextStyle(fontSize: 11)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('💰 $cost', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
