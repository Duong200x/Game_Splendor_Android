import 'package:flutter/material.dart';
import 'dart:math' as math;

class GameCardBackWidget extends StatelessWidget {
  final int level; // Cấp 1, 2, hoặc 3
  final double width;

  const GameCardBackWidget({super.key, required this.level, this.width = 100});

  // --- 1. CONFIG MÀU SẮC THEO LEVEL ---
  LinearGradient _getGradient(int level) {
    switch (level) {
      case 1: // Level 1: Emerald (Xanh thẳm)
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF66BB6A), Color(0xFF1B5E20), Color(0xFF003300)],
        );
      case 2: // Level 2: Amber (Hổ phách/Vàng cam)
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFCA28), Color(0xFFE65100), Color(0xFFBF360C)],
        );
      case 3: // Level 3: Cosmic Sapphire (Xanh tím vũ trụ)
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF42A5F5), Color(0xFF1565C0), Color(0xFF311B92)],
        );
      default:
        return const LinearGradient(colors: [Colors.grey, Colors.black]);
    }
  }

  Color _getBorderColor(int level) {
    switch (level) {
      case 1: return const Color(0xFF69F0AE); // Xanh neon
      case 2: return const Color(0xFFFFD740); // Vàng sáng
      case 3: return const Color(0xFF82B1FF); // Xanh sáng
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    double height = width * 1.4;
    double fontSize = width * 0.35;

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.hardEdge, // Cắt bỏ phần họa tiết thừa
      decoration: BoxDecoration(
        gradient: _getGradient(level), // Màu nền theo cấp độ
        borderRadius: BorderRadius.circular(width * 0.1),
        border: Border.all(
            color: _getBorderColor(level).withValues(alpha: 0.6),
            width: width > 150 ? 4 : 2
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 6, offset: const Offset(2, 3))
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // --- LỚP 1: HỌA TIẾT HÌNH HỌC CHÌM ---
          // Hình thoi lớn mờ ảo xoay nghiêng
          Positioned(
            top: -width * 0.3,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: width,
                height: width,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: width * 0.1),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -width * 0.3,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: width * 0.8,
                height: width * 0.8,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),

          // --- LỚP 2: VÒNG TRÒN TRUNG TÂM (BADGE) ---
          Container(
            width: width * 0.6,
            height: width * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // --- LỚP 3: NỘI DUNG CHÍNH (SỐ LA MÃ) ---
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Chữ "LEVEL" nhỏ xíu bên trên
              Text(
                "LEVEL",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: width * 0.08,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),

              // Số La Mã to đùng
              Text(
                _getRomanLevel(level), // I, II, III
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'serif',
                  shadows: [
                    const Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
                    Shadow(color: _getBorderColor(level), blurRadius: 15, offset: const Offset(0, 0)), // Glow nhẹ
                  ],
                ),
              ),

              // Các chấm tròn biểu thị cấp độ
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(level, (index) =>
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        width: width * 0.06,
                        height: width * 0.06,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: _getBorderColor(level), blurRadius: 5, spreadRadius: 1)
                            ]
                        ),
                      ),
                    )
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  String _getRomanLevel(int level) {
    if (level == 1) return "I";
    if (level == 2) return "II";
    if (level == 3) return "III";
    return "";
  }
}