import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

/// 전면 광고 / 보상형 광고를 미리 로드해 두고 필요할 때 보여주는 싱글톤.
///
/// 배너는 화면마다 붙어야 하므로 [BannerAdWidget] 에서 개별 관리한다.
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  /// 전면·보상형 광고가 화면을 덮고 있는 동안 true. 이때의 앱 일시정지는 게임에서 무시한다
  /// (광고 보고 돌아왔는데 "오프라인 보상" 창이 뜨지 않도록).
  bool isShowingAd = false;

  /// 전면 광고 노출 빈도: [interstitialEvery] 번째 요청마다 한 번.
  /// 방치형 게임은 플레이 흐름을 끊으면 이탈이 크므로 '은퇴(환생)' 때만 요청하고, 매번 보여준다.
  int _interstitialRequests = 0;
  static const interstitialEvery = 1;

  Future<void> init() async {
    await MobileAds.instance.initialize();
    loadInterstitial();
    loadRewarded();
  }

  // ---------------------------------------------------------------- 전면 광고

  void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial load failed: $err');
          _interstitial = null;
        },
      ),
    );
  }

  /// 로드된 전면 광고가 있고 노출 차례이면 보여준다. 없으면 그냥 넘어간다.
  /// 광고 유무와 무관하게 [onDone] 은 반드시 호출된다.
  void showInterstitialThen(VoidCallback onDone) {
    _interstitialRequests++;
    final ad = _interstitial;
    if (ad == null || _interstitialRequests % interstitialEvery != 0) {
      onDone();
      return;
    }
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        isShowingAd = false;
        ad.dispose();
        loadInterstitial();
        onDone();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        isShowingAd = false;
        ad.dispose();
        loadInterstitial();
        onDone();
      },
    );
    isShowingAd = true;
    ad.show();
  }

  // -------------------------------------------------------------- 보상형 광고

  bool get isRewardedReady => _rewarded != null;

  void loadRewarded() {
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (err) {
          debugPrint('Rewarded load failed: $err');
          _rewarded = null;
        },
      ),
    );
  }

  /// 보상형 광고를 보여주고, 사용자가 끝까지 봤을 때만 [onReward] 를 호출한다.
  /// 광고가 닫히면(보상 여부와 무관하게) [onClosed] 를 호출한다.
  /// 광고가 준비 안 됐으면 false 를 반환하고 아무것도 하지 않는다.
  bool showRewarded({required VoidCallback onReward, VoidCallback? onClosed}) {
    final ad = _rewarded;
    if (ad == null) return false;
    _rewarded = null;
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        isShowingAd = false;
        ad.dispose();
        loadRewarded();
        if (earned) onReward();
        onClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        isShowingAd = false;
        ad.dispose();
        loadRewarded();
        onClosed?.call();
      },
    );
    isShowingAd = true;
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return true;
  }
}
