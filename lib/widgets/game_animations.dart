import 'package:flutter/material.dart';
import '../models/game_entities.dart';

// --- HIỆU ỨNG 1: TOKEN TUNG HỨNG & BAY ---
class FlyingTokenAnimation extends StatefulWidget {
  final GemType type;
  final Offset startPos;
  final Offset endPos;
  final VoidCallback onComplete;

  const FlyingTokenAnimation({
    super.key,
    required this.type,
    required this.startPos,
    required this.endPos,
    required this.onComplete,
  });

  @override
  State<FlyingTokenAnimation> createState() => _FlyingTokenAnimationState();
}

class _FlyingTokenAnimationState extends State<FlyingTokenAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _xAnimation;
  late Animation<double> _yAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    // Hiệu ứng di chuyển (Bay)
    _xAnimation = Tween(begin: widget.startPos.dx, end: widget.endPos.dx)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));

    _yAnimation = Tween(begin: widget.startPos.dy, end: widget.endPos.dy)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));

    // Hiệu ứng xoay (Tung đồng xu)
    _rotateAnimation = Tween(begin: 0.0, end: 4 * 3.14) // Xoay 2 vòng
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Hiệu ứng nhỏ dần khi về đích
    _scaleAnimation = Tween(begin: 1.0, end: 0.5).animate(
        CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)));

    _controller.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColor(GemType type) {
    switch (type) {
      case GemType.red:
        return Colors.redAccent;
      case GemType.blue:
        return Colors.lightBlueAccent;
      case GemType.green:
        return Colors.greenAccent;
      case GemType.black:
        return const Color(0xFF424242);
      case GemType.white:
        return Colors.white;
      case GemType.gold:
        return Colors.amberAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _xAnimation.value,
          top: _yAnimation.value,
          child: Transform.rotate(
            angle: _rotateAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: _getColor(widget.type),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 5)
                    ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- HIỆU ỨNG 2: THẺ BÀI BAY ---
class FlyingCardAnimation extends StatefulWidget {
  final Widget child; // Widget thẻ bài (hình ảnh)
  final Offset startPos;
  final Offset endPos;
  final VoidCallback onComplete;

  const FlyingCardAnimation({
    super.key,
    required this.child,
    required this.startPos,
    required this.endPos,
    required this.onComplete,
  });

  @override
  State<FlyingCardAnimation> createState() => _FlyingCardAnimationState();
}

class _FlyingCardAnimationState extends State<FlyingCardAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    _positionAnimation =
        Tween<Offset>(begin: widget.startPos, end: widget.endPos).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack));

    _scaleAnimation = Tween<double>(
            begin: 1.0, end: 0.2) // Thu nhỏ lại khi vào kho
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child, // Render lại thẻ bài
          ),
        );
      },
    );
  }
}
