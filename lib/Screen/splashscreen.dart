import 'package:flutter/material.dart';
import 'package:boombug/Screen/Game.dart';
import 'package:boombug/Screen/Menu.dart';
import 'package:boombug/progress_store.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ).drive(Tween<double>(begin: 0, end: 1));

    _logoScale = Tween<double>(begin: 0.65, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.35, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.2, curve: Curves.easeOut),
      ),
    );

    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _openNextScreen();
      }
    });

    _controller.forward();
  }

  Future<void> _openNextScreen() async {
    final progress = ProgressStore.instance;
    await progress.load();
    if (!mounted) return;
    final nextScreen = progress.tutorialCompleted
        ? const MenuScreen()
        : const Game(isTutorial: true);
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1F4D), Color(0xFF7B4BB3), Color(0xFF0F1021)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _logoOpacity,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Image(
                            image: AssetImage('assets/logo.png'),
                            width: 260,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'STARTING GAME',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _progress,
                      builder: (context, child) => SizedBox(
                        width: 260,
                        height: 16,
                        child: LinearProgressIndicator(
                          value: _progress.value,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFC107),
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'BY CAPH',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              const Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '© 2026 BoomBug. All rights reserved.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
