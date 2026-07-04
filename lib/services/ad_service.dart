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
    print('Unity Ads disabled (removed for Android 8 compatibility)');
  }

  void loadRewardedAd() {}

  void loadInterstitialAd() {}

  void showInterstitialAd() {}

  void showRewardedAd() {}
}
