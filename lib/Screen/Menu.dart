import 'package:flutter/material.dart';

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
  late final AnimationController _controller;
  late final AnimationController _settingsController;
  late final AnimationController _logoController;
  late final AnimationController _bgController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _settingsScaleAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
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

    _settingsScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(
      parent: _settingsController,
      curve: Curves.easeInOut,
    ));

    _logoScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));

    _bgAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
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
                        background.withOpacity(0.95),
                        const Color(0xFF8A5DD8).withOpacity(0.9),
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
                    color: Colors.white.withOpacity(0.08),
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
                    color: const Color(0xFFFFC700).withOpacity(0.10),
                  ),
                ),
              ),
              SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      left: 8,
                      child: GestureDetector(
                        onTap: () {
                          _animateSettingsButton();
                          print('Settings button');
                        },
                        child: ScaleTransition(
                          scale: _settingsScaleAnimation,
                          child: BoomBugSettingsButton(),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 100),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ScaleTransition(
                              scale: _logoScaleAnimation,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                  bottom: 20,
                                ),
                                child: Image.asset('assets/logo3.png'),
                              ),
                            ),
                            const SizedBox(height: 5),
                            GestureDetector(
                              onTap: () {
                                _animateButton();
                              },
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 60,
                                    right: 60,
                                  ),
                                  child: Image.asset(
                                    'assets/buttons.png',
                                    fit: BoxFit.contain,
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
            ],
          );
        },
      ),
    );
  }
}
