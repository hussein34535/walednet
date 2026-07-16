import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdService {
  static const String gameId = '5862917';
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
    print('[AdService] Initializing Unity Ads (Game ID: $gameId)...');
    UnityAds.init(
      gameId: gameId,
      testMode: true, // Keep true for testing, change to false for production
      onComplete: () {
        print('[AdService] Unity Ads initialized successfully!');
        loadRewardedAd();
        loadInterstitialAd();
      },
      onFailed: (error, message) {
        print('[AdService] Unity Ads initialization failed: $error - $message');
        onAdFailed('Initialization failed: $message');
      },
    );
  }

  void loadRewardedAd() {
    print('[AdService] Loading Rewarded Ad...');
    UnityAds.load(
      placementId: rewardedPlacementId,
      onComplete: (placementId) {
        print('[AdService] Rewarded Ad loaded successfully: $placementId');
        isRewardedAdReady = true;
        onRewardedReadyChanged(true);
      },
      onFailed: (placementId, error, message) {
        print('[AdService] Rewarded Ad load failed ($placementId): $error - $message');
        isRewardedAdReady = false;
        onRewardedReadyChanged(false);
        onAdFailed('Load Rewarded failed: $message');
      },
    );
  }

  void loadInterstitialAd() {
    print('[AdService] Loading Interstitial Ad...');
    UnityAds.load(
      placementId: interstitialPlacementId,
      onComplete: (placementId) {
        print('[AdService] Interstitial Ad loaded successfully: $placementId');
        isInterstitialAdReady = true;
        onInterstitialReadyChanged(true);
      },
      onFailed: (placementId, error, message) {
        print('[AdService] Interstitial Ad load failed ($placementId): $error - $message');
        isInterstitialAdReady = false;
        onInterstitialReadyChanged(false);
        onAdFailed('Load Interstitial failed: $message');
      },
    );
  }

  void showRewardedAd() {
    if (!isRewardedAdReady) {
      print('[AdService] Rewarded Ad is not ready. Attempting to load...');
      loadRewardedAd();
      return;
    }
    UnityAds.showVideoAd(
      placementId: rewardedPlacementId,
      onStart: (placementId) {
        print('[AdService] Rewarded Ad started showing.');
      },
      onClick: (placementId) {
        print('[AdService] Rewarded Ad clicked.');
      },
      onSkipped: (placementId) {
        print('[AdService] Rewarded Ad skipped by user.');
        isRewardedAdReady = false;
        onRewardedReadyChanged(false);
        loadRewardedAd();
      },
      onComplete: (placementId) {
        print('[AdService] Rewarded Ad completed! Rewarding user.');
        isRewardedAdReady = false;
        onRewardedReadyChanged(false);
        onRewardedCompleted();
        loadRewardedAd();
      },
      onFailed: (placementId, error, message) {
        print('[AdService] Rewarded Ad show failed: $error - $message');
        isRewardedAdReady = false;
        onRewardedReadyChanged(false);
        onAdFailed('Show Rewarded failed: $message');
        loadRewardedAd();
      },
    );
  }

  void showInterstitialAd() {
    if (!isInterstitialAdReady) {
      print('[AdService] Interstitial Ad is not ready. Attempting to load...');
      loadInterstitialAd();
      return;
    }
    UnityAds.showVideoAd(
      placementId: interstitialPlacementId,
      onStart: (placementId) {
        print('[AdService] Interstitial Ad started showing.');
      },
      onClick: (placementId) {
        print('[AdService] Interstitial Ad clicked.');
      },
      onSkipped: (placementId) {
        print('[AdService] Interstitial Ad skipped by user.');
        isInterstitialAdReady = false;
        onInterstitialReadyChanged(false);
        loadInterstitialAd();
      },
      onComplete: (placementId) {
        print('[AdService] Interstitial Ad completed.');
        isInterstitialAdReady = false;
        onInterstitialReadyChanged(false);
        loadInterstitialAd();
      },
      onFailed: (placementId, error, message) {
        print('[AdService] Interstitial Ad show failed: $error - $message');
        isInterstitialAdReady = false;
        onInterstitialReadyChanged(false);
        onAdFailed('Show Interstitial failed: $message');
        loadInterstitialAd();
      },
    );
  }

  void showRewardedAdWithCallbacks({
    required void Function() onCompleted,
    required void Function() onCancelled,
  }) {
    if (!isRewardedAdReady) {
      print('[AdService] Rewarded Ad is not ready. Falling back.');
      loadRewardedAd();
      onCancelled();
      return;
    }
    UnityAds.showVideoAd(
      placementId: rewardedPlacementId,
      onStart: (placementId) {
        print('[AdService] Rewarded Ad started showing.');
      },
      onClick: (placementId) {
        print('[AdService] Rewarded Ad clicked.');
      },
      onSkipped: (placementId) {
        print('[AdService] Rewarded Ad skipped by user.');
        isRewardedAdReady = false;
        onRewardedReadyChanged(false);
        onCancelled();
        loadRewardedAd();
      },
      onComplete: (placementId) {
        print('[AdService] Rewarded Ad completed! Rewarding user.');
        isRewardedAdReady = false;
        onRewardedReadyChanged(false);
        onCompleted();
        loadRewardedAd();
      },
      onFailed: (placementId, error, message) {
        print('[AdService] Rewarded Ad show failed: $error - $message');
        isRewardedAdReady = false;
        onRewardedReadyChanged(false);
        onCancelled();
        loadRewardedAd();
      },
    );
  }
}
