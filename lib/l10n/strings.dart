import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../game/economy.dart';

/// 앱 문자열 (en / ko / ja / zh). 기본은 시스템 언어를 따르고(미지원 언어는 영어),
/// 메뉴의 언어 설정으로 바꿀 수 있다 ([LocaleController]).
///
/// 새 언어를 추가하려면 [supported] 와 [nativeName] 에 로케일을 넣고 [_t] 에 인자를 추가한다.
class S {
  final Locale locale;
  const S(this.locale);

  static S of(BuildContext context) => Localizations.of<S>(context, S)!;
  static const LocalizationsDelegate<S> delegate = _SDelegate();
  static const supported = [Locale('en'), Locale('ko'), Locale('ja'), Locale('zh')];

  /// 시스템 언어를 지원 로케일로 맞춘다 (미지원이면 영어).
  static Locale resolve(Locale? l) =>
      supported.firstWhere((s) => s.languageCode == l?.languageCode, orElse: () => supported.first);

  /// 언어 선택 목록에 각 언어의 자기 이름으로 표시.
  static String nativeName(Locale l) => switch (l.languageCode) {
    'ko' => '한국어',
    'ja' => '日本語',
    'zh' => '简体中文',
    _ => 'English',
  };

  String _t(String en, String ko, String ja, String zh) => switch (locale.languageCode) {
    'ko' => ko,
    'ja' => ja,
    'zh' => zh,
    _ => en,
  };

  /// 큰 수 표시 (언어별 단위).
  String n(double v) => NumberFormatter.format(v, locale.languageCode);

  String get appTitle => _t('Tap Tycoon', '부자 키우기', 'お金持ち育成', '富翁养成记');

  // 상단
  String perSec(double v) => _t('+${n(v)} / sec', '초당 +${n(v)}', '毎秒 +${n(v)}', '每秒 +${n(v)}');
  String perTap(double v) => _t('+${n(v)} per tap', '탭당 +${n(v)}', 'タップ +${n(v)}', '每次点击 +${n(v)}');
  String get tapHint => _t('Tap to earn!', '탭해서 돈 벌기!', 'タップして稼ごう！', '点击赚钱！');

  List<String> get ranks => [
    _t('Broke', '거지', '無一文', '穷光蛋'),
    _t('Part-timer', '알바생', 'アルバイト', '打工仔'),
    _t('Street Vendor', '노점상', '露店商', '摊贩'),
    _t('Shop Owner', '사장님', '店長', '小老板'),
    _t('Landlord', '건물주', 'ビルオーナー', '包租公'),
    _t('CEO', 'CEO', '社長', '总裁'),
    _t('Tycoon', '재벌', '財閥', '财阀'),
    _t('Space Tycoon', '우주 재벌', '宇宙財閥', '宇宙大亨'),
  ];

  // 부스트 / 광고
  String get boost2x => _t('2× Boost', '2배 부스트', '2倍ブースト', '2倍加速');
  String boostAd(int minutes) =>
      _t('Watch ad: 2× for $minutes min', '광고 보고 $minutes분간 2배', '広告で$minutes分間2倍', '看广告 $minutes分钟2倍');
  String get boostMaxed => _t('Boost is full', '부스트 가득 참', 'ブースト満タン', '加速已满');
  String get adNotReady => _t(
    'No ad available right now. Please try again shortly.',
    '지금은 광고를 불러올 수 없어요. 잠시 후 다시 시도해 주세요.',
    '現在広告を読み込めません。しばらくしてからお試しください。',
    '暂时无法加载广告，请稍后再试。',
  );
  String get boostStarted => _t('2× income boost on!', '2배 부스트 발동!', '2倍ブースト発動！', '2倍加速已开启！');

  // 오프라인
  String get welcomeBack => _t('Welcome back!', '다시 오셨군요!', 'おかえりなさい！', '欢迎回来！');
  String offlineBody(String duration) => _t(
    'Your businesses earned money while you were away ($duration).',
    '자리를 비운 동안($duration) 사업장이 돈을 벌었어요.',
    '留守の間（$duration）もお店が稼いでくれました。',
    '你离开期间（$duration）店铺一直在赚钱。',
  );
  String get collect => _t('Collect', '받기', '受け取る', '领取');
  String collectAd(int x) => _t('Watch ad: ×$x', '광고 보고 $x배 받기', '広告で$x倍受け取る', '看广告领$x倍');
  String duration(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60;
    if (h > 0) return _t('${h}h ${m}m', '$h시간 $m분', '$h時間$m分', '$h小时$m分钟');
    return _t('${d.inMinutes}m', '${d.inMinutes}분', '${d.inMinutes}分', '${d.inMinutes}分钟');
  }

  // 돈가방
  String get bagTitle => _t('Money bag!', '돈가방 발견!', 'お金の袋を発見！', '发现钱袋！');
  String get bagBody => _t('What a lucky find!', '운 좋게 돈가방을 주웠어요!', 'ラッキーな拾い物！', '真是意外之财！');

  // 구매
  String get buyMax => _t('MAX', '최대', '最大', '最大');
  String get tapUpgrade => _t('Faster Fingers', '손놀림 강화', '指さばき強化', '手速强化');
  String get tapUpgradeDesc => _t('More money per tap', '탭당 수익 증가', 'タップ収入アップ', '提高每次点击收入');
  String level(int l) => _t('Lv.$l', 'Lv.$l', 'Lv.$l', 'Lv.$l');
  String owned(int n) => _t('Owned $n', '보유 $n', '所有 $n', '拥有 $n');
  String milestone(int next) => _t('At $next: income ×2', '$next개 달성 시 수익 2배', '$next個で収入2倍', '达到$next个收入×2');
  String get locked => '???';
  String unlockAt(String cost) => _t('Unlocks at $cost', '$cost 모으면 공개', '$costで解放', '攒够$cost解锁');

  List<String> get businessNames => [
    _t('Can Collecting', '폐지 줍기', '空き缶拾い', '捡废品'),
    _t('Fish-bread Stall', '붕어빵 노점', 'たい焼き屋台', '鲷鱼烧小摊'),
    _t('Convenience Store', '편의점', 'コンビニ', '便利店'),
    _t('Fried Chicken Shop', '치킨집', '唐揚げ屋', '炸鸡店'),
    _t('Café', '카페', 'カフェ', '咖啡店'),
    _t('Internet Café', 'PC방', 'ネットカフェ', '网吧'),
    _t('Office Building', '빌딩 임대업', '貸しビル業', '写字楼出租'),
    _t('Tech Startup', 'IT 스타트업', 'ITスタートアップ', '科技创业公司'),
    _t('Talent Agency', '연예 기획사', '芸能事務所', '娱乐经纪公司'),
    _t('Space Company', '우주 항공사', '宇宙企業', '航天公司'),
  ];

  // 은퇴(환생)
  String get retire => _t('Retire', '은퇴', '引退', '退休');
  String get fameLabel => _t('Fame', '명성', '名声', '声望');
  String fameInfo(int fame, int pct) =>
      _t('Fame $fame (income +$pct%)', '명성 $fame (수익 +$pct%)', '名声 $fame（収入 +$pct%）', '声望 $fame（收入 +$pct%）');
  String get retireTitle => _t('Retire and start over?', '은퇴하고 새로 시작할까요?', '引退してやり直しますか？', '退休并重新开始？');
  String retireBody(int gain, int pctAfter) => _t(
    'Your money, businesses and tap level reset to zero.\n'
        'You gain $gain Fame — every Fame point adds +10% to all income forever '
        '(total +$pctAfter% after retiring).',
    '돈·사업장·손놀림 레벨이 모두 초기화됩니다.\n'
        '대신 명성 $gain 을(를) 얻어요. 명성 1개당 모든 수익이 영구히 +10% '
        '(은퇴 후 총 +$pctAfter%).',
    'お金・お店・タップレベルがリセットされます。\n'
        '代わりに名声を$gain獲得。名声1つにつき全収入が永久に+10%'
        '（引退後 合計+$pctAfter%）。',
    '金钱、店铺和手速等级将全部重置。\n'
        '你将获得 $gain 声望，每点声望永久提高全部收入 10%'
        '（退休后共 +$pctAfter%）。',
  );
  String retireNotYet(String need) => _t(
    'Earn more to gain Fame. Next Fame at a lifetime total of $need.',
    '더 벌어야 명성을 얻을 수 있어요. 누적 수익 $need 에서 다음 명성.',
    'もっと稼ぐと名声がもらえます。累計 $need で次の名声。',
    '再多赚些才能获得声望。累计收入达到 $need 时获得下一点声望。',
  );
  String retireGain(int gain) => _t('Retire (+$gain Fame)', '은퇴하기 (명성 +$gain)', '引退する（名声+$gain）', '退休（声望+$gain）');

  // 메뉴
  String get language => _t('Language', '언어', '言語', '语言');
  String get systemLanguage => _t('System default', '시스템 기본', 'システムの設定', '跟随系统');
  String get howToPlay => _t('How to play', '게임 방법', '遊び方', '玩法说明');
  String get stats => _t('Stats', '기록', '記録', '统计');
  String get resetGame => _t('Reset game', '처음부터 다시', 'データを初期化', '重置游戏');
  String get resetConfirm => _t(
    'All progress including Fame will be deleted. This cannot be undone.',
    '명성을 포함한 모든 진행 상황이 삭제됩니다. 되돌릴 수 없어요.',
    '名声を含むすべての進行状況が削除されます。元に戻せません。',
    '包括声望在内的所有进度都将被删除，无法撤销。',
  );
  String get cancel => _t('Cancel', '취소', 'キャンセル', '取消');
  String get close => _t('Close', '닫기', '閉じる', '关闭');
  String get delete => _t('Delete', '삭제', '削除', '删除');
  String statsBody({required String lifetime, required int taps, required int retirements, required int fame}) => _t(
    'Lifetime earnings: $lifetime\nTotal taps: $taps\nRetirements: $retirements\nFame: $fame',
    '누적 수익: $lifetime\n총 탭 수: $taps\n은퇴 횟수: $retirements\n명성: $fame',
    '累計収入: $lifetime\n総タップ数: $taps\n引退回数: $retirements\n名声: $fame',
    '累计收入：$lifetime\n总点击次数：$taps\n退休次数：$retirements\n声望：$fame',
  );
  String get helpBody => _t(
    'Tap the character to earn money. Buy businesses to earn money automatically — even while the app is closed '
        '(50% rate, up to 3 hours).\n\n'
        'Each business doubles its income at 25, 50, 100… owned. Upgrade "Faster Fingers" for bigger taps.\n\n'
        'Watch a short ad for a 2× income boost (5 minutes each, up to 60). Grab the money bag when it appears, '
        'and collect ×10 rewards by watching an ad.\n\n'
        'When you have earned enough, Retire: start over with Fame, which permanently boosts all income.',
    '캐릭터를 탭하면 돈을 벌어요. 사업장을 사면 자동으로 돈이 들어오고, 앱을 꺼 둔 동안에도 벌어요 '
        '(50%, 최대 3시간).\n\n'
        '사업장은 25·50·100개… 를 모을 때마다 수익이 2배. "손놀림 강화"로 탭 수익을 올리세요.\n\n'
        '짧은 광고를 보면 2배 부스트(1회 5분, 최대 60분). 가끔 나타나는 돈가방을 잡고, '
        '광고를 보면 보상을 10배로 받을 수 있어요.\n\n'
        '충분히 벌었다면 은퇴! 명성을 얻고 처음부터 다시 시작하면 모든 수익이 영구히 올라갑니다.',
    'キャラをタップしてお金を稼ごう。お店を買うと自動で稼ぎ、アプリを閉じている間も稼ぎます'
        '（50%、最大3時間）。\n\n'
        'お店は25・50・100個…ごとに収入2倍。「指さばき強化」でタップ収入アップ。\n\n'
        '短い広告で2倍ブースト（1回5分、最大60分）。ときどき現れるお金の袋を拾い、'
        '広告を見ると報酬が10倍に。\n\n'
        '十分稼いだら引退！名声を得て最初からやり直すと、全収入が永久にアップします。',
    '点击角色赚钱。购买店铺即可自动赚钱，关闭应用时也会继续赚（50%，最多3小时）。\n\n'
        '店铺每达到25、50、100……个，收入翻倍。升级“手速强化”提高点击收入。\n\n'
        '观看短广告可获得2倍加速（每次5分钟，最多60分钟）。偶尔出现的钱袋要抓住，'
        '看广告可领取10倍奖励。\n\n'
        '赚够了就退休！获得声望后重新开始，所有收入永久提升。',
  );
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  bool isSupported(Locale locale) => S.supported.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<S> load(Locale locale) => SynchronousFuture(S(locale));

  @override
  bool shouldReload(_SDelegate old) => false;
}

/// 사용자가 고른 언어. null 이면 시스템 언어를 따른다. 값이 바뀌면 [MaterialApp] 이 다시 빌드된다.
class LocaleController extends ValueNotifier<Locale?> {
  LocaleController(super.value);

  static LocaleController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LocaleScope>()!.controller;

  /// 저장된 언어 코드 → 로케일. 지원하지 않는 코드는 무시(null).
  static Locale? fromCode(String? code) =>
      code == null ? null : S.supported.cast<Locale?>().firstWhere((l) => l!.languageCode == code, orElse: () => null);
}

/// [LocaleController] 를 위젯 트리에 내려보낸다.
class LocaleScope extends StatelessWidget {
  final LocaleController controller;
  final Widget child;
  const LocaleScope({super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) => _LocaleScope(controller: controller, child: child);
}

class _LocaleScope extends InheritedWidget {
  final LocaleController controller;
  const _LocaleScope({required this.controller, required super.child});

  @override
  bool updateShouldNotify(_LocaleScope old) => old.controller != controller;
}
