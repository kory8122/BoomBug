import 'dart:async';

import 'package:flutter/material.dart';
import 'package:boombug/Screen/game_splashscreen.dart';
import 'package:boombug/widgets/animated_image_button.dart';
import 'package:boombug/widgets/custom_icon_button.dart';
import 'package:boombug/progress_store.dart';
import 'package:boombug/rewarded_ad_service.dart';
import 'package:boombug/widgets/refill_hearts_dialog.dart';
import 'package:boombug/widgets/ad_banner.dart';
import 'package:flutter/services.dart';

class BoomBugSettingsButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const BoomBugSettingsButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2D7CFF),
          border: Border.all(color: const Color(0xFFFFC700), width: 4),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFFF7A00),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Color(0xFF174A9C),
              offset: Offset(0, 2),
              blurRadius: 2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onPressed,
            child: const Center(
              child: Icon(Icons.settings, size: 30, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  static const int _totalLevels = 1000;
  late final AnimationController _controller;
  late final AnimationController _settingsController;
  late final AnimationController _logoController;
  late final AnimationController _bgController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _settingsScaleAnimation;
  late final Animation<double> _bgAnimation;
  Timer? _heartTimer;
  bool _isSettingsOpen = false;
  bool _isSoundMuted = false;
  bool _isMusicMuted = false;
  bool _isProgressLoaded = false;
  final ProgressStore _progress = ProgressStore.instance;
  final RewardedAdService _rewardedAds = RewardedAdService();

  @override
  void initState() {
    super.initState();
    _progress.addListener(_onProgressChanged);
    _loadProgress();
    _heartTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _progress.refreshRecharge().then((_) {
        if (mounted) setState(() {});
      });
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _settingsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _settingsScaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _settingsController, curve: Curves.easeInOut),
    );

    _bgAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));
  }

  Future<void> _loadProgress() async {
    await _progress.load();
    if (mounted) {
      setState(() => _isProgressLoaded = true);
    }
  }

  Future<void> _openGame() async {
    if (!_isProgressLoaded || !mounted) return;
    if (_progress.hearts == 0) {
      await _showHeartRefill();
      if (!mounted || _progress.hearts == 0) return;
    }
    _animateButton();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameSplashScreen()),
    );
  }

  void _onProgressChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _progress.removeListener(_onProgressChanged);
    _heartTimer?.cancel();
    _controller.dispose();
    _settingsController.dispose();
    _logoController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _animateButton() async {
    await _controller.forward();
    await _controller.reverse();
  }

  void _animateSettingsButton() async {
    await _settingsController.forward();
    await _settingsController.reverse();
  }

  void _toggleSettings() {
    _playClick();
    setState(() => _isSettingsOpen = !_isSettingsOpen);
  }

  void _playClick() {
    if (!_isSoundMuted) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _showHeartRefill() async {
    if (_progress.hearts != 0) return;
    final action = await showRefillHeartsDialog(context);
    if (action == null || !mounted) return;
    if (action == RefillHeartsAction.buyWithCoins) {
      if (_progress.coins < 250) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need 250 coins to refill hearts.')),
        );
        return;
      }
      _progress.coins -= 250;
      _progress.refillHearts();
      await _progress.save();
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading ad...'),
          ],
        ),
      ),
    );
    final completed = await _rewardedAds.watchAds(3);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (!completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The ad was not completed. No hearts added.'),
        ),
      );
      return;
    }
    _progress.refillHearts();
    await _progress.save();
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8CF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC700), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFFF7A00),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0xFF174A9C),
            offset: Offset(0, 2),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF3A2A5E),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelTracker() {
    final level = _progress.level.clamp(1, _totalLevels);
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF36B), Color(0xFFFFC928), Color(0xFFE5A900)],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFFFF5A1), width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA8B4B00),
            blurRadius: 0,
            offset: Offset(0, 9),
          ),
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF98A), Color(0xFFFFD83D)],
          ),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0xFFFFB914), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Level',
              style: TextStyle(
                color: Color(0xFF9A6200),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                shadows: [
                  Shadow(
                    color: Color(0x66FFFFFF),
                    offset: Offset(0, 1),
                    blurRadius: 0,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '$level',
              style: const TextStyle(
                color: Color(0xFFB45B00),
                fontSize: 42,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: [
                  Shadow(
                    color: Color(0x66FFFFFF),
                    offset: Offset(0, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color background = Color(0xFF4E2B78);

    return Scaffold(
      backgroundColor: background,
      body: AnimatedBuilder(
        animation: _bgAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        background.withValues(alpha: 0.95),
                        const Color(0xFF8A5DD8).withValues(alpha: 0.9),
                        background,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 80 + (_bgAnimation.value * 20),
                left: -40 + (_bgAnimation.value * 20),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: 120 - (_bgAnimation.value * 25),
                right: -20 + (_bgAnimation.value * 15),
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFC700).withValues(alpha: 0.10),
                  ),
                ),
              ),
              SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ScaleTransition(
                            scale: _settingsScaleAnimation,
                            child: AnimatedImageButton(
                              width: 45,
                              height: 45,
                              imagePath: 'assets/icons/Setting_icon.png',
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(30),
                              shadowColor: const Color(0xFFFFC700),
                              shadowBlurRadius: 20,
                              onPressed: () {
                                _animateSettingsButton();
                                _toggleSettings();
                              },
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _progress.hearts == 0
                                    ? _showHeartRefill
                                    : null,
                                child: _buildStatusChip(
                                  icon: Icons.favorite,
                                  value: _progress.hearts == 0
                                      ? '0  ${_progress.rechargeTimeLabel ?? '0:00'}'
                                      : '${_progress.hearts}',
                                  color: const Color(0xFFFF5D5D),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusChip(
                                icon: Icons.monetization_on,
                                value: '${_progress.coins}',
                                color: const Color(0xFFFFC700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 90),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 20,
                                right: 20,
                                bottom: 20,
                              ),
                              child: Image.asset(
                                'assets/logo.png',
                                width: 240,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 10),
                            AnimatedBuilder(
                              animation: _logoController,
                              child: _buildLevelTracker(),
                              builder: (context, child) {
                                final pulse = _logoController.value;
                                return Transform.scale(
                                  scale: 1 + pulse * 0.04,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFFC700)
                                              .withValues(
                                                alpha: 0.3 + pulse * 0.35,
                                              ),
                                          blurRadius: 8 + pulse * 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: child,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            GestureDetector(
                              onTap: _openGame,
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 70,
                                    right: 70,
                                  ),
                                  child: Image.asset(
                                    'assets/buttons.png',
                                    fit: BoxFit.contain,
                                    width: 210,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(top: false, child: Center(child: AdBanner())),
              ),
              if (_isSettingsOpen)
                Positioned.fill(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _toggleSettings,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.68),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: CustomIconButton(
                          size: 26,
                          width: 48,
                          height: 48,
                          icon: Icons.close,
                          onPressed: _toggleSettings,
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 28,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: _isSoundMuted
                                  ? 'Turn sound on'
                                  : 'Mute sound effects',
                              child: CustomIconButton(
                                size: 26,
                                width: 52,
                                height: 52,
                                icon: _isSoundMuted
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                onPressed: () {
                                  final wasMuted = _isSoundMuted;
                                  setState(
                                    () => _isSoundMuted = !_isSoundMuted,
                                  );
                                  if (wasMuted) _playClick();
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            Tooltip(
                              message: _isMusicMuted
                                  ? 'Turn music on'
                                  : 'Mute music',
                              child: CustomIconButton(
                                size: 26,
                                width: 52,
                                height: 52,
                                icon: _isMusicMuted
                                    ? Icons.music_off
                                    : Icons.music_note,
                                onPressed: () {
                                  _playClick();
                                  setState(
                                    () => _isMusicMuted = !_isMusicMuted,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
