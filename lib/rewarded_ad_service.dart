import 'dart:async';
import 'dart:io' show Platform;

import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  static const _androidAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const _iosAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

  String get _adUnitId => Platform.isAndroid ? _androidAdUnitId : _iosAdUnitId;

  Future<bool> watchAds(int count) async {
    var completedAds = 0;
    for (var index = 0; index < count; index++) {
      final completed = await _watchOneAd();
      if (!completed) return false;
      completedAds++;
    }
    return completedAds == count;
  }

  Future<bool> _watchOneAd() async {
    final loadedAd = await _loadAd();
    if (loadedAd == null) return false;

    final result = Completer<bool>();
    loadedAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!result.isCompleted) result.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!result.isCompleted) result.complete(false);
      },
    );
    loadedAd.show(
      onUserEarnedReward: (ad, reward) {
        if (!result.isCompleted) result.complete(true);
      },
    );
    return result.future;
  }

  Future<RewardedAd?> _loadAd() {
    final result = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => result.complete(ad),
        onAdFailedToLoad: (error) => result.complete(null),
      ),
    );
    return result.future;
  }
}
