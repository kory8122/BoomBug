import 'package:flutter/material.dart';

class AnimatedImageButton extends StatefulWidget {
  final String imagePath;
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final double? imageWidth;
  final double? imageHeight;
  final double scaleDownValue;
  final Duration duration;
  final BoxFit fit;
  final BorderRadiusGeometry? borderRadius;
  final Color? shadowColor;
  final double shadowBlurRadius;
  final double shadowSpreadRadius;

  const AnimatedImageButton({
    super.key,
    required this.imagePath,
    this.onPressed,
    this.width = 72,
    this.height = 72,
    this.imageWidth,
    this.imageHeight,
    this.scaleDownValue = 0.92,
    this.duration = const Duration(milliseconds: 120),
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.shadowColor,
    this.shadowBlurRadius = 20,
    this.shadowSpreadRadius = 0,
  });

  @override
  State<AnimatedImageButton> createState() => _AnimatedImageButtonState();
}

class _AnimatedImageButtonState extends State<AnimatedImageButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDownValue,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant AnimatedImageButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed != null) {
      _controller.reverse();
      widget.onPressed!();
    }
  }

  void _onTapCancel() {
    if (widget.onPressed != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(20);
    final imageWidth = widget.imageWidth ?? widget.width;
    final imageHeight = widget.imageHeight ?? widget.height;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: (widget.shadowColor ?? Colors.black26).withOpacity(
                      0.3,
                    ),
                    blurRadius: widget.shadowBlurRadius,
                    spreadRadius: widget.shadowSpreadRadius,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: Image.asset(
                    widget.imagePath,
                    width: imageWidth,
                    height: imageHeight,
                    fit: widget.fit,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
