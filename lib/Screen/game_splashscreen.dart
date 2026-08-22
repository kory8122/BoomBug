import 'package:flutter/material.dart';

import 'package:boombug/Screen/Game.dart';

class GameSplashScreen extends StatefulWidget {
  const GameSplashScreen({super.key});

  @override
  State<GameSplashScreen> createState() => _GameSplashScreenState();
}

class _GameSplashScreenState extends State<GameSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const Game()));
      }
    });
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
          image: DecorationImage(
            image: AssetImage('assets/splashG.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 55),
                  child: AnimatedBuilder(
                    animation: _controller,
                    child: Image.asset(
                      'assets/logo.png',
                      width: 270,
                      fit: BoxFit.contain,
                    ),
                    builder: (context, child) {
                      final popProgress = Curves.easeOutBack
                          .transform((_controller.value * 1.35).clamp(0.0, 1.0))
                          .clamp(0.0, 1.0);
                      return Transform.scale(
                        scale: 0.35 + popProgress * 0.65,
                        child: Opacity(opacity: popProgress, child: child),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 70,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        value: _controller.value,
                        strokeWidth: 4,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFC700),
                        ),
                      ),
                    ),
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
