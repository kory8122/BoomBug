import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  static const _androidAdUnitId = 'ca-app-pub-8052023419164715/8767322397';
  static const _androidTestAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const _iosAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

  String _adUnitId({required bool useTestAd}) {
    if (Platform.isAndroid) {
      return useTestAd ? _androidTestAdUnitId : _androidAdUnitId;
    }
    return _iosAdUnitId;
  }

  Future<bool> watchAds(int count, {bool useTestAd = false}) async {
    var completedAds = 0;
    for (var index = 0; index < count; index++) {
      final completed = await _watchOneAd(useTestAd: useTestAd);
      if (!completed) return false;
      completedAds++;
    }
    return completedAds == count;
  }

  Future<bool> _watchOneAd({required bool useTestAd}) async {
    final loadedAd = await _loadAd(useTestAd: useTestAd);
    if (loadedAd == null) return false;

    final result = Completer<bool>();
    loadedAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!result.isCompleted) result.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded ad failed to show: $error');
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

  Future<RewardedAd?> _loadAd({required bool useTestAd}) async {
    final result = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: _adUnitId(useTestAd: useTestAd),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => result.complete(ad),
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          result.complete(null);
        },
      ),
    );
    return result.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => null,
    );
  }
}
