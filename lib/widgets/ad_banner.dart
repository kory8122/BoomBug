import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _banner;
  bool _isLoaded = false;
  Timer? _retryTimer;

  String get _adUnitId => Platform.isAndroid
      ? 'ca-app-pub-8052023419164715/9451060129'
      : 'ca-app-pub-3940256099942544/2934735716';

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) return;
    _loadBanner();
  }

  void _loadBanner() {
    if (!mounted) return;
    _banner = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
          _banner = null;
          if (mounted) {
            _retryTimer = Timer(const Duration(seconds: 10), _loadBanner);
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (!Platform.isAndroid || !_isLoaded || banner == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: banner.size.width.toDouble(),
      height: banner.size.height.toDouble(),
      child: AdWidget(ad: banner),
    );
  }
}
