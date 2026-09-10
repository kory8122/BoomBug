import 'dart:io' show Platform;

import 'package:flutter/material.dart';

enum RefillHeartsAction { watchAds, buyWithCoins }

Future<RefillHeartsAction?> showRefillHeartsDialog(BuildContext context) {
  final isIos = Platform.isIOS;
  return showGeneralDialog<RefillHeartsAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Refill Hearts',
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _RefillHeartsDialog(isIos: isIos);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: curved, child: child),
      );
    },
  );
}

class _RefillHeartsDialog extends StatelessWidget {
  const _RefillHeartsDialog({required this.isIos});

  final bool isIos;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF8E5BC7), Color(0xFF5B348F)],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFFFD83D), width: 4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 25,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'REFILL YOUR HEARTS!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        offset: Offset(0, 3),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isIos
                      ? 'Buy all 5 hearts for 250 coins'
                      : 'Watch 3 ads to get all 5 hearts back',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE9DFFF),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _Heart(size: index == 2 ? 44 : 36),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _WatchButton(
                  label: isIos ? 'BUY HEARTS  •  250 COINS' : 'WATCH AD',
                  onPressed: () => Navigator.pop(
                    context,
                    isIos
                        ? RefillHeartsAction.buyWithCoins
                        : RefillHeartsAction.watchAds,
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'MAYBE LATER',
                    style: TextStyle(
                      color: Color(0xFFDCCCF0),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: -7,
            top: -12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF06A), Color(0xFFE0AF00)],
                  ),
                  border: Border.all(color: const Color(0xFF9D7200), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF573400),
                  size: 23,
                ),
              ),
            ),
          ),
          const Positioned(left: -15, top: 45, child: _Coin()),
          const Positioned(right: -13, bottom: 100, child: _Coin()),
        ],
      ),
    );
  }
}

class _Heart extends StatelessWidget {
  const _Heart({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5C7A), Color(0xFFE51D4F)],
        ),
        border: Border.all(color: const Color(0xFFFFD7DE), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '❤',
          style: TextStyle(
            fontSize: size * 0.52,
            color: Colors.white,
            shadows: const [
              Shadow(
                color: Color(0x55000000),
                offset: Offset(0, 2),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchButton extends StatelessWidget {
  const _WatchButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF06A),
                  Color(0xFFFFC928),
                  Color(0xFFE5A900),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFE979), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 6,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF553178),
                  size: 26,
                ),
                SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF4D2C70),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Coin extends StatelessWidget {
  const _Coin();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.15,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF16A), Color(0xFFFFC21F), Color(0xFFE09A00)],
          ),
          border: Border.all(color: const Color(0xFFB77900), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '\$',
            style: TextStyle(
              color: Color(0xFF9A6200),
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
