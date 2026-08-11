import 'package:boombug/Screen/Menu.dart';
import 'package:boombug/widgets/custom_icon_button.dart';
import 'package:flutter/material.dart';

class Game extends StatelessWidget {
  Game({super.key});

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
              Positioned(
                top: 20,
                left: 20,
                child: CustomIconButton(
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
              ),
              Positioned(
                top: 20,
                right: 15,
                bottom: 120,
                left: 15,
                child: Center(
                  child: Container(
                    width: 400,
                    height: 500,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.cyan,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 50,
                right: 50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    CustomIconButton(
                      size: 30,
                      width: 40,
                      height: 40,
                      icon: Icons.arrow_back_ios,
                      onPressed: () {},
                    ),
                    CustomIconButton(
                      size: 30,
                      width: 40,
                      height: 40,
                      icon: Icons.arrow_back,
                      onPressed: () {},
                    ),
                    CustomIconButton(
                      size: 30,
                      width: 40,
                      height: 40,
                      icon: Icons.arrow_forward,
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
