import 'package:flutter/material.dart';
import '../models/game_entities.dart';
import '../gem_helper.dart';
class GameTokenWidget extends StatefulWidget {
  final GemType type;
  final int count;
  final VoidCallback? onTap;
  final double size;

  const GameTokenWidget({
    super.key,
    required this.type,
    required this.count,
    this.onTap,
    this.size = 80,
  });

  @override
  State<GameTokenWidget> createState() => _GameTokenWidgetState();
}

class _GameTokenWidgetState extends State<GameTokenWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.1,
    )..addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    if (widget.count <= 0 || widget.onTap == null) return;
    await _controller.forward();
    await _controller.reverse();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    double size = widget.size;
    GemType type = widget.type;
    Color gemColor = GameAssets.getGemColor(type);
    bool isEmpty = widget.count <= 0;
    bool isBlackToken = type == GemType.black; // Kiểm tra xem có phải token đen không

    // Scale button when pressed
    double scale = 1.0 - _controller.value;

    // --- CẤU HÌNH MÀU SẮC RIÊNG CHO TOKEN ĐEN ---
    // Nếu là đá đen: Viền thành màu trắng xám, Vạch kẻ thành màu đen
    List<Color> rimColors = isBlackToken
        ? [Colors.grey.shade300, Colors.grey.shade400, Colors.grey.shade600] // Gradient trắng xám
        : [gemColor, gemColor.withValues(alpha: 0.8), Colors.black.withValues(alpha: 0.6)]; // Gradient màu đá thường

    Color stripeColor = isBlackToken ? Colors.black87 : Colors.white.withValues(alpha: 0.9);

    return GestureDetector(
      onTap: _handleTap,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: isEmpty ? 0.4 : 1.0,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // --- LỚP 1: VIỀN NGOÀI (BODY) ---
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: rimColors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 6,
                        offset: const Offset(2, 4),
                      ),
                      // Viền sáng nhẹ (Rim Light)
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.4),
                        blurRadius: 2,
                        offset: const Offset(-1, -1),
                        spreadRadius: 0,
                      )
                    ],
                  ),
                ),

                // --- LỚP 2: CÁC KHÍA (STRIPES) ---
                ...List.generate(6, (index) {
                  return Transform.rotate(
                    angle: (index * 60) * 3.14159 / 180,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: size * 0.12,
                        height: size * 0.15, // Vạch ngắn thôi vì viền mỏng
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: stripeColor, // Đen đậm nếu là token đen, trắng nếu là token khác
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              if (isBlackToken) // Nếu vạch đen thì thêm viền trắng mỏng cho nổi
                                BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 1)
                            ]
                        ),
                      ),
                    ),
                  );
                }),

                // --- LỚP 3: LÕI TRUNG TÂM (STICKER) ---
                // Tăng kích thước lõi lên (0.8) -> Viền sẽ mỏng đi
                Container(
                  width: size * 0.78, // <--- TĂNG KÍCH THƯỚC LÕI (Cũ là 0.65)
                  height: size * 0.78,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      // Viền của lõi
                      border: Border.all(
                          color: isBlackToken ? Colors.black54 : gemColor.withValues(alpha: 0.5),
                          width: 1
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2, spreadRadius: 0, offset: const Offset(1,1))
                      ],
                      gradient: const RadialGradient(
                        colors: [Colors.white, Color(0xFFE0E0E0)],
                      )
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(size * 0.05), // <--- GIẢM PADDING (Cũ là 0.1) -> ĐÁ TO LÊN
                    child: Image.asset(
                      GameAssets.getGemPath(widget.type),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // --- LỚP 4: SỐ LƯỢNG (BADGE) ---
                if (!isEmpty)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: EdgeInsets.all(size * 0.08),
                      decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2, offset: Offset(1,1))]
                      ),
                      child: Text(
                        "${widget.count}",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: size * 0.24, // Số to hơn chút cho dễ nhìn
                            shadows: const [Shadow(color: Colors.black, blurRadius: 2)]
                        ),
                      ),
                    ),
                  ),

                // --- LỚP 5: DẤU HIỆU HẾT HÀNG ---
                if (isEmpty)
                  Container(
                    width: size, height: size,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline, color: Colors.white70, size: 28),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}