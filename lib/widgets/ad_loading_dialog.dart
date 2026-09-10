import 'package:flutter/material.dart';

class AdLoadingDialog extends StatelessWidget {
  const AdLoadingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8E5BC7), Color(0xFF5B348F)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFFD83D), width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: Color(0xFFFFD83D),
              ),
            ),
            SizedBox(width: 16),
            Text(
              'LOADING AD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
