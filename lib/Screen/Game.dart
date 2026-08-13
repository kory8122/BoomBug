import 'dart:async';

import 'package:boombug/Screen/Menu.dart';
import 'package:boombug/widgets/animated_image_button.dart';
import 'package:boombug/widgets/custom_icon_button.dart';
import 'package:flutter/material.dart';

class Game extends StatefulWidget {
  const Game({super.key});

  @override
  State<Game> createState() => _GameState();
}

class _GameState extends State<Game> {
  int currentLevel = 1;
  final int totalLevels = 5;
  Timer? _levelTimer;

  @override
  void initState() {
    super.initState();
    _levelTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        currentLevel = currentLevel < totalLevels ? currentLevel + 1 : 1;
      });
    });
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/GamePLayBG.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomIconButton(
                      size: 30,
                      width: 40,
                      height: 40,
                      icon: Icons.arrow_back,
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const MenuScreen()),
                        );
                      },
                    ),
                    Text(
                      'Level: $currentLevel',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                    AnimatedImageButton(
                      width: 45,
                      height: 45,
                      imagePath: 'assets/icons/menu_icon.png',
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 0,
                right: 15,
                left: 15,
                bottom: 300,
                child: Center(
                  child: Container(
                    width: 400,
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.cyan,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 300,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(totalLevels, (index) {
                        final isActive = index < currentLevel;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 50,
                          height: 50,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white
                                : Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.8),
                              width: 1.2,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 210,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(totalLevels, (index) {
                        final isActive = index < currentLevel;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 50,
                          height: 50,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white
                                : Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.8),
                              width: 1.2,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 40,
                left: 50,
                right: 50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    AnimatedImageButton(
                      width: 50,
                      height: 50,

                      imagePath: 'assets/icons/boom_icon.png',
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {},
                    ),
                    AnimatedImageButton(
                      width: 50,
                      height: 50,

                      imagePath: 'assets/icons/plus_icon.png',
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {},
                    ),
                    AnimatedImageButton(
                      width: 50,
                      height: 50,

                      imagePath: 'assets/icons/strick_icon.png',
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
