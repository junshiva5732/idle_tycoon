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
  final game = GameState();
  final saved = storage.loadGame();
  if (saved != null) game.loadJson(saved);
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
