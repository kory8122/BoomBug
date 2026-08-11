import 'package:flutter/material.dart';

class CustomIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final double size;
  final double width;
  final double height;

  const CustomIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color = Colors.white,
    this.size = 30,
    this.width = 52,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
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
          child: Center(
            child: Icon(icon, size: size, color: color),
          ),
        ),
      ),
    );
  }
}
