# 부자 키우기 (idle_tycoon)

탭하고 방치해서 거지에서 우주 재벌까지 키우는 클리커 / 방치형 게임. AdMob 광고(배너 / 전면 / 보상형)로 수익화.
Flutter 로 작성, Android + iOS 대상. 한국어 · 영어 · 일본어 · 중국어(간체) 지원, 앱 안에서 언어 변경 가능.
앱 이름: 부자 키우기 / Tap Tycoon / お金持ち育成 / 富翁养成记. applicationId `com.jun5731.idle_tycoon`.

## 구조

```
lib/
  main.dart                     앱 진입, 저장 데이터 로드, 테마(세로 고정), 스크린샷용 LOCALE 강제
  l10n/strings.dart             문자열 en/ko/ja/zh (칭호·사업 이름 포함) + LocaleController
  ads/ad_ids.dart               AdMob 광고 단위 ID  ← 출시 전 교체
  ads/ad_manager.dart           전면·보상형 광고 로드/노출 싱글톤 (isShowingAd: 광고 중 앱 일시정지 무시)
  widgets/banner_ad_widget.dart 하단 적응형 배너
  game/economy.dart             밸런스 상수, 사업 10종, 비용/수익/명성/오프라인 계산, 큰 수 표시(만·억·조 / K·M·B)
  game/game_state.dart          게임 상태 ChangeNotifier: 100ms 틱, 구매, 부스트, 돈가방, 은퇴, JSON 저장
  services/storage.dart         SharedPreferences: 게임 저장(JSON), 언어
  widgets/tap_area.dart         탭 영역: 멀티터치 연타, 떠오르는 +금액, 캐릭터 바운스, 돈가방
  screens/game_screen.dart      단일 게임 화면: 상단(칭호·돈·초당 수익·2배 부스트), 탭 영역, 상점, 보상 다이얼로그, 메뉴
test/economy_test.dart          경제 수학·숫자 표시·게임 상태 유닛 테스트
tool/make_icon.py               앱 아이콘 원본 생성 (왕관 쓴 금화)
docs/privacy-policy.html        개인정보처리방침 (GitHub Pages 용)
```

## 게임 규칙 / 밸런스

| 항목 | 값 | 위치 |
|---|---|---|
| 사업 | 10종 (폐지 줍기 → 우주 항공사), 가격 ×1.15/개 | `Economy.businesses`, `costGrowth` |
| 마일스톤 | 25·50·100·150·200·300·400·500개마다 해당 사업 수익 ×2 | `Economy.milestones` |
| 탭 수익 | (레벨+1)·2^(레벨/10) × 명성배율 + 초당수익의 3% | `tapBase`, `tapIpsShare` |
| 탭 강화 비용 | 20 × 1.35^레벨 | `tapBaseCost`, `tapCostGrowth` |
| 오프라인 수익 | 초당 수익의 50%, 최대 3시간, 60초 미만 부재는 무시 | `offlineRate`, `offlineCapSeconds` |
| 은퇴(환생) | 명성 총량 = floor(√(누적 수익 / 100만)), 명성 1당 전체 수익 +10% | `fameUnit`, `fameBonus` |
| 칭호 | 누적 수익 기준 8단계 (거지 → 우주 재벌) | `rankThresholds` |
| 돈가방 | 90~180초마다 20초간 등장, 보상 = max(1분 수익, 탭 30회) | `bag*` |

구매 수량 ×1 / ×10 / ×100 / 최대. 저장은 10초마다 + 백그라운드 전환 시.
부스트 종료 시각은 벽시계 기준이라 앱을 꺼도 흐른다. 오프라인 수익은 부스트 없이 계산(악용 방지).

## 광고 노출 지점

| 위치 | 종류 | 동작 |
|---|---|---|
| 화면 하단 | 배너 | 항상 표시 |
| 상단 "2배 부스트" 버튼 | 보상형 | 끝까지 시청 시 모든 수익(탭 포함) 2배 5분, 누적 최대 60분 |
| 오프라인 보상 창 ("다시 오셨군요!") | 보상형 | "광고 보고 10배 받기". 광고를 중간에 닫으면 기본 1배 지급 |
| 돈가방 창 | 보상형 | "광고 보고 10배 받기" (동일) |
| 은퇴 확정 시 | 전면 | 매번 (드문 이벤트라 흐름을 덜 끊음). 로드 안 됐으면 광고 없이 진행 |

방치형은 플레이 도중 전면 광고가 이탈을 키우므로 전면은 은퇴 때만. 수치는 `Economy` 상수와 `AdManager.interstitialEvery`.

## 개발 빌드

```bash
flutter pub get
flutter test
flutter build apk --debug
```

언어 확인: `flutter run --dart-define=LOCALE=ko` (디버그 전용, ko/en/ja/zh — 사용자 설정보다 우선).

### 이 PC 전용 메모
- Flutter 3.47 은 Gradle 8.14+ 를 요구해서 이 프로젝트는 템플릿 기본인 **AGP 9.1 / Gradle 9.3.1 / Kotlin 2.4** 를 쓴다
  (이전 앱들은 AGP 8.7 / Gradle 8.12). 그래서 `google_mobile_ads` 도 9.x (6.x 는 Gradle 9 와 비호환).
- `android/gradle.properties` 와 `android/gradlew.bat` 에 `-Djdk.net.unixdomain.tmpdir=C:/tmp` (Gradle loopback 오류 회피).
- `android/gradle.properties` 에 `kotlin.incremental=false`: pub 캐시(C:)와 프로젝트(D:)가 다른 드라이브라
  Kotlin 증분 캐시가 "Could not close incremental caches" 로 실패한다.
- 에뮬레이터(Small_Phone_API_35) 저장공간이 부족하면 `flutter build apk --debug --target-platform android-x64` 로 작게 빌드.

## 출시 체크리스트

### 1. AdMob
- [x] AdMob Android 앱 "Tap Tycoon" 등록 (2026-09-29, App ID `ca-app-pub-7493209423244427~7004391969`, 스토어 연결은 Play 게시 후)
- [x] 광고 단위 3개: banner_main `/3854561000`, interstitial_retire `/7761930708`, rewarded_boost `/6448849030`
- [x] `lib/ads/ad_ids.dart` `_androidReal`, `AndroidManifest.xml` `APPLICATION_ID` 실제 ID 로 교체
- [ ] `ios/Runner/Info.plist` 의 `GADApplicationIdentifier` 교체
- [ ] 개발 중 실제 ID로 광고 클릭 금지 (계정 정지 사유)

### 2. 개인정보 / 정책
- [x] 개인정보처리방침 https://junshiva5732.github.io/idle_tycoon/privacy-policy (GitHub Pages `main` / `/docs`)
- [ ] Play Console 데이터 보안: 광고 ID 수집(AdMob), 게임 데이터는 기기에만 저장

### 3. Google Play
- [x] 업로드 키 `android/upload-keystore.jks` (PKCS12, alias `upload`) + `android/key.properties` — git 제외, **따로 백업 필수**
- [x] `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` (targetSdk 36)
- [ ] 스토어 그래픽: 아이콘 512, 기능 그래픽, 스크린샷
- [x] Play Console 앱 생성 (2026-09-29, 앱 ID 4973586879462626733, "Tap Tycoon: Idle Clicker", 게임·무료, 기본 언어 en-US)
- [x] 내부 테스트 1 (1.0.0) 게시 (2026-09-29, 테스터 "Internal testers" + "오늘의 운세 테스터"), 참여 링크 https://play.google.com/apps/internaltest/4701467622018387148
- [x] 앱 콘텐츠 선언 전부 + 광고 ID 선언, 스토어 등록정보(en-US 기본, ko-KR), 카테고리 게임>시뮬레이션 (2026-09-29, `store/listing.md`)
- [x] 비공개 테스트 "Alpha" (177개국, 테스터 Internal testers + 오늘의 운세 테스터, 1.0.0) 검토 제출 (2026-09-29)
- [x] 1.0.1 (versionCode 2, 태블릿 배너 수정) 2026-09-30: 내부 테스트 게시 + 비공개 테스트 Alpha 검토 제출
- [ ] 비공개 테스트(12명 × 14일) → 프로덕션

### 4. 출시 후 확장 아이디어
- [ ] 효과음(동전) + 사운드/진동 토글
- [ ] 사업장 매니저·업그레이드 트리, 일일 출석 보상(보상형 2배)
- [ ] 업적, 캐릭터 꾸미기(보상형 광고로 해제)
- [ ] 클라우드 저장(Play Games)
