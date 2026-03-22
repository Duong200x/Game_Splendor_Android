import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/game_entities.dart';
import '../gem_helper.dart';

class NobleWidget extends StatefulWidget {
  final Noble noble;
  final double size;
  final bool enableZoom;

  const NobleWidget({
    super.key,
    required this.noble,
    this.size = 80,
    this.enableZoom = true,
  });

  @override
  State<NobleWidget> createState() => _NobleWidgetState();
}

class _NobleWidgetState extends State<NobleWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showZoomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: NobleWidget(noble: widget.noble, size: 300, enableZoom: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double size = widget.size;
    // --- SỬA Ở ĐÂY: Luôn hiện viền ---
    double borderSize = size > 150 ? 6 : 3;

    double reqBoxSize = size * 0.3;
    double reqFontSize = size * 0.15;

    List<Color> royalColors = [
      const Color(0xFFFFD700),
      const Color(0xFF9C27B0),
      const Color(0xFFD50000),
      const Color(0xFFFFD700),
    ];

    Widget nobleContent = Stack(
      children: [
        // --- LỚP 0: VIỀN XOAY ---
        // BỎ điều kiện if (widget.enableZoom)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(size * 0.1),
                    gradient: SweepGradient(
                      colors: royalColors,
                      transform:
                          GradientRotation(_controller.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.4),
                          blurRadius: 15,
                          spreadRadius: 2)
                    ]),
              );
            },
          ),
        ),

        // --- LỚP 1: NỘI DUNG ---
        Container(
          width: size,
          height: size,
          margin: EdgeInsets.all(borderSize),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: const Color(0xFF3E2723),
            borderRadius: BorderRadius.circular(size * 0.08),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.9),
                  blurRadius: 4,
                  offset: const Offset(2, 2))
            ],
            gradient: const RadialGradient(
              center: Alignment.center,
              radius: 0.9,
              colors: [Color(0xFF5D4037), Color(0xFF210B08)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.2,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Image.asset('assets/images/yellow.png',
                        fit: BoxFit.cover),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(size * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          "${widget.noble.points}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size * 0.35,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'serif',
                            shadows: const [
                              Shadow(
                                  color: Colors.black,
                                  blurRadius: 4,
                                  offset: Offset(2, 2)),
                              Shadow(
                                  color: Colors.amber,
                                  blurRadius: 15,
                                  offset: Offset(0, 0)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                              vertical: size * 0.02, horizontal: size * 0.02),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(size * 0.04),
                              border: Border.all(
                                  color: Colors.white24, width: 0.5)),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: size * 0.02,
                              children: widget.noble.requirements.entries
                                  .map((entry) {
                                return Container(
                                  width: reqBoxSize,
                                  height: reqBoxSize * 1.3,
                                  decoration: BoxDecoration(
                                      color: GameAssets.getGemColor(entry.key),
                                      border: Border.all(
                                          color: Colors.white,
                                          width: size > 150 ? 2 : 1.2),
                                      borderRadius:
                                          BorderRadius.circular(size * 0.02),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Colors.black54,
                                            blurRadius: 2,
                                            offset: Offset(1, 1))
                                      ]),
                                  child: Center(
                                    child: Text(
                                      "${entry.value}",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: reqFontSize,
                                          fontWeight: FontWeight.bold,
                                          shadows: const [
                                            Shadow(
                                                color: Colors.black,
                                                blurRadius: 2)
                                          ]),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: size * 0.02,
                right: size * 0.02,
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                    BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.6),
                        blurRadius: 15,
                        spreadRadius: 2)
                  ]),
                  child: Text("👑",
                      style: TextStyle(fontSize: size * 0.25, shadows: const [
                        Shadow(
                            color: Colors.black54,
                            blurRadius: 5,
                            offset: Offset(2, 2))
                      ])),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.enableZoom) {
      return GestureDetector(
        onLongPress: () => _showZoomDialog(context),
        child: nobleContent,
      );
    } else {
      return nobleContent;
    }
  }
}
