import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/game_entities.dart';
import '../gem_helper.dart';

class DevCardWidget extends StatefulWidget {
  final DevCard card;
  final double width;
  final bool enableZoom;

  const DevCardWidget({
    super.key,
    required this.card,
    this.width = 100,
    this.enableZoom = true,
  });

  @override
  State<DevCardWidget> createState() => _DevCardWidgetState();
}

class _DevCardWidgetState extends State<DevCardWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
          // Zoom lên 300, tắt enableZoom để không bấm được nữa, nhưng hiệu ứng vẫn chạy
          child:
              DevCardWidget(card: widget.card, width: 300, enableZoom: false),
        ),
      ),
    );
  }

  List<Color> _getBorderColors(int level) {
    switch (level) {
      case 1:
        return [
          const Color(0xFF00FFFF),
          const Color(0xFF008B8B),
          const Color(0xFF00FFFF)
        ];
      case 2:
        return [Colors.red, Colors.yellow, Colors.green, Colors.red];
      case 3:
        return [
          Colors.red,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.purple,
          Colors.white,
          Colors.red
        ];
      default:
        return [Colors.white, Colors.grey];
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = width * 1.4;
    DevCard card = widget.card;
    Color baseColor = GameAssets.getGemColor(card.bonus);

    double fontSizePoints = width * 0.26;
    double iconSize = width * 0.22;

    // --- CẬP NHẬT KÍCH THƯỚC ---
    // Phóng to ô tròn chứa giá tiền (0.18 -> 0.25)
    double costCircleSize = width * 0.25;
    // Tăng cỡ chữ số tiền (0.1 -> 0.15)
    double costFontSize = width * 0.15;

    double padding = width * 0.05;

    // Viền dày hơn khi zoom
    double borderWidth = widget.enableZoom ? (width > 150 ? 5 : 2.5) : 0;

    List<Color> borderColors = _getBorderColors(card.level);

    Widget cardContent = Stack(
      children: [
        // --- LỚP 0: VIỀN ANIMATION ---
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width * 0.12),
                  gradient: SweepGradient(
                    colors: borderColors,
                    transform:
                        GradientRotation(_controller.value * 2 * math.pi),
                  ),
                ),
              );
            },
          ),
        ),

        // --- LỚP 1: NỘI DUNG ---
        Container(
          width: width,
          height: height,
          margin: EdgeInsets.all(borderWidth),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(width * 0.1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 6,
                  offset: const Offset(2, 2))
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor.withValues(alpha: 0.95),
                baseColor.withValues(alpha: 0.6)
              ],
            ),
          ),
          child: Stack(
            children: [
              // WATERMARK
              Positioned(
                right: -width * 0.2,
                bottom: -width * 0.1,
                child: Transform.rotate(
                  angle: -math.pi / 5,
                  child: Opacity(
                    opacity: 0.2,
                    child: Image.asset(
                      GameAssets.getGemPath(card.bonus),
                      width: width * 1.2,
                      height: width * 1.2,
                      fit: BoxFit.cover,
                      color: Colors.white,
                      colorBlendMode: BlendMode.modulate,
                    ),
                  ),
                ),
              ),

              // POINTS (ĐIỂM)
              if (card.points > 0)
                Positioned(
                  top: padding,
                  left: padding,
                  child: Text(
                    "${card.points}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSizePoints,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'serif',
                      shadows: const [
                        Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                            offset: Offset(2, 2))
                      ],
                    ),
                  ),
                ),

              // BONUS ICON (ĐÁ THƯỞNG)
              Positioned(
                top: padding,
                right: padding,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.white.withValues(alpha: 0.6),
                          blurRadius: 12,
                          spreadRadius: 2)
                    ],
                  ),
                  child: Image.asset(GameAssets.getGemPath(card.bonus),
                      width: iconSize, height: iconSize),
                ),
              ),

              // COST (GIÁ TIỀN) - ĐÃ SỬA
              Positioned(
                bottom: padding,
                left: padding,
                child: SizedBox(
                  width: width *
                      0.55, // Mở rộng vùng chứa để không bị cắt vì ô tròn to ra
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: card.cost.entries.map((entry) {
                      // Logic màu chữ: Chữ đen cho dễ nhìn, TRỪ đá đen phải dùng chữ trắng
                      Color textColor = (entry.key == GemType.black)
                          ? Colors.white
                          : Colors.black;

                      return Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Container(
                          width: costCircleSize,
                          height: costCircleSize,
                          decoration: BoxDecoration(
                              color: GameAssets.getGemColor(entry.key),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
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
                                color: textColor,
                                fontWeight: FontWeight.w900, // Chữ đậm hơn
                                fontSize: costFontSize,
                                // Chỉ đổ bóng nếu là chữ trắng
                                shadows: textColor == Colors.white
                                    ? [
                                        const Shadow(
                                            color: Colors.black, blurRadius: 2)
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // LEVEL INDICATOR
              Positioned(
                top: padding,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      card.level,
                      (index) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Container(
                              width: width * 0.06,
                              height: width * 0.06,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      blurRadius: 4,
                                      spreadRadius: 1)
                                ],
                              ),
                            ),
                          )),
                ),
              )
            ],
          ),
        ),
      ],
    );

    if (widget.enableZoom) {
      return GestureDetector(
        onLongPress: () => _showZoomDialog(context),
        child: cardContent,
      );
    } else {
      return cardContent;
    }
  }
}
