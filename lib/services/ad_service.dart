import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdService {
  static const String gameId = '5833433';
  static const String rewardedPlacementId = 'Rewarded_Android';
  static const String interstitialPlacementId = 'Interstitial_Android';

  bool isRewardedAdReady = false;
  bool isInterstitialAdReady = false;

  final void Function(bool) onRewardedReadyChanged;
  final void Function(bool) onInterstitialReadyChanged;
  final void Function(String) onAdFailed;
  final void Function() onRewardedCompleted;

  AdService({
    required this.onRewardedReadyChanged,
    required this.onInterstitialReadyChanged,
    required this.onAdFailed,
    required this.onRewardedCompleted,
  });

  void initialize() {
    try {
      UnityAds.init(
        gameId: gameId,
        testMode: false,
        onComplete: () {
          print('Unity Ads initialization complete.');
          loadRewardedAd();
          loadInterstitialAd();
        },
        onFailed: (error, message) {
          print('Unity Ads initialization failed: $error $message');
        },
      );
    } catch (e) {
      print('Unity Ads initialization failed: $e');
    }
  }

  void loadRewardedAd() {
    isRewardedAdReady = false;
    onRewardedReadyChanged(false);
    UnityAds.load(
      placementId: rewardedPlacementId,
      onComplete: (placementId) {
        print('Load Complete: $placementId');
        isRewardedAdReady = true;
        onRewardedReadyChanged(true);
      },
      onFailed: (placementId, error, message) {
        print('Load Failed $placementId: $error $message');
        isRewardedAdReady = false;
        onRewardedReadyChanged(false);
        onAdFailed('فشل تحميل الإعلان، يرجى المحاولة مرة أخرى.');
      },
    );
  }

  void loadInterstitialAd() {
    isInterstitialAdReady = false;
    onInterstitialReadyChanged(false);
    UnityAds.load(
      placementId: interstitialPlacementId,
      onComplete: (placementId) {
        print('Load Complete: $placementId');
        isInterstitialAdReady = true;
        onInterstitialReadyChanged(true);
      },
      onFailed: (placementId, error, message) {
        print('Load Failed $placementId: $error $message');
        isInterstitialAdReady = false;
        onInterstitialReadyChanged(false);
      },
    );
  }

  void showInterstitialAd() {
    if (!isInterstitialAdReady) {
      print('Interstitial Ad not ready, skipping show.');
      return;
    }

    UnityAds.showVideoAd(
      placementId: interstitialPlacementId,
      onComplete: (placementId) {
        print('Video Ad ($placementId) completed');
      },
      onFailed: (placementId, error, message) {
        print('Video Ad ($placementId) failed: $error $message');
      },
      onStart: (placementId) => print('Video Ad ($placementId) start'),
      onClick: (placementId) => print('Video Ad ($placementId) click'),
      onSkipped: (placementId) {
        print('Video Ad ($placementId) skipped');
      },
    );
  }

  void showRewardedAd() {
    if (!isRewardedAdReady) {
      onAdFailed('الإعلان غير جاهز بعد، يرجى المحاولة مرة أخرى.');
      return;
    }

    UnityAds.showVideoAd(
      placementId: rewardedPlacementId,
      onComplete: (placementId) async {
        print('Video Ad ($placementId) completed');
        onRewardedCompleted();
      },
      onFailed: (placementId, error, message) {
        print('Video Ad ($placementId) failed: $error - $message');
        onAdFailed('فشل عرض الإعلان، يرجى المحاولة مرة أخرى');
      },
      onStart: (placementId) => print('Video Ad ($placementId) start'),
      onClick: (placementId) => print('Video Ad ($placementId) click'),
      onSkipped: (placementId) {
        print('Video Ad ($placementId) skipped');
        onAdFailed('يجب مشاهدة الإعلان بالكامل للاتصال');
      },
    );
  }
}
