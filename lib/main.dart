import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ads/ad_manager.dart';
import 'game/game_state.dart';
import 'l10n/strings.dart';
import 'screens/game_screen.dart';
import 'services/storage.dart';

/// 스크린샷 촬영용 언어 강제 (디버그 빌드에서만 동작).
/// 예: flutter build apk --debug --dart-define=LOCALE=ja
const _localeOverride = String.fromEnvironment('LOCALE');

/// 스크린샷 촬영용 중반 진행 상태 (디버그 빌드에서만 동작). 예: --dart-define=DEMO=true
const _demo = bool.fromEnvironment('DEMO');

/// 앱 시드색 (황금빛 주황). 시드에서 나온 primary 는 갈색이라 버튼색(primary)은 주황으로 고정한다.
const seedColor = Color(0xFFF5A623);

ColorScheme _scheme(Brightness b) => ColorScheme.fromSeed(
  seedColor: seedColor,
  brightness: b,
).copyWith(primary: const Color(0xFFF57C00), onPrimary: Colors.white);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 광고 SDK 초기화는 앱 표시를 막지 않도록 기다리지 않는다.
  AdManager.instance.init();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final storage = await Storage.create();
  final game = GameState(random: kDebugMode && _demo ? math.Random(3) : null);
  final saved = storage.loadGame();
  if (kDebugMode && _demo) {
    _seedDemo(game);
  } else if (saved != null) {
    game.loadJson(saved);
  }
  runApp(TycoonApp(storage: storage, game: game));
}

class TycoonApp extends StatefulWidget {
  final Storage storage;
  final GameState game;
  const TycoonApp({super.key, required this.storage, required this.game});

  @override
  State<TycoonApp> createState() => _TycoonAppState();
}

class _TycoonAppState extends State<TycoonApp> {
  late final LocaleController _locale;

  @override
  void initState() {
    super.initState();
    _locale = LocaleController(LocaleController.fromCode(widget.storage.localeCode));
    _locale.addListener(() => widget.storage.setLocaleCode(_locale.value?.languageCode));
  }

  @override
  void dispose() {
    _locale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      controller: _locale,
      child: ListenableBuilder(
        listenable: _locale,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => S.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorScheme: _scheme(Brightness.light), useMaterial3: true),
          darkTheme: ThemeData(colorScheme: _scheme(Brightness.dark), useMaterial3: true),
          localizationsDelegates: const [S.delegate, ...GlobalMaterialLocalizations.delegates],
          supportedLocales: S.supported,
          // 우선순위: 스크린샷용 강제 > 사용자 설정 > 시스템 언어
          locale: kDebugMode && _localeOverride.isNotEmpty ? Locale(_localeOverride) : _locale.value,
          home: GameScreen(game: widget.game, storage: widget.storage),
        ),
      ),
    );
  }
}

/// 스토어 스크린샷용: 사업장 여러 개, 명성, 부스트 진행 중, 2시간 부재(오프라인 보상 창).
void _seedDemo(GameState g) {
  final now = DateTime.now();
  g
    ..money = 4.83e7
    ..runEarned = 2.1e8
    ..lifetimeEarned = 9.6e8
    ..tapLevel = 17
    ..fame = 12
    ..retirements = 1
    ..totalTaps = 4210
    ..owned = [132, 104, 76, 51, 38, 25, 11, 2, 0, 0]
    ..boostUntil = now.add(const Duration(minutes: 23, seconds: 41))
    ..lastSeen = now.subtract(const Duration(hours: 2, minutes: 14));
}
