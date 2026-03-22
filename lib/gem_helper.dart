import 'package:flutter/material.dart';
import 'models/game_entities.dart';

class GameAssets {
  // 1. Lấy màu sắc (Giữ nguyên)
  static Color getGemColor(GemType type) {
    switch (type) {
      case GemType.white: return Colors.white;
      case GemType.blue: return Colors.lightBlueAccent;
      case GemType.green: return Colors.greenAccent;
      case GemType.red: return Colors.redAccent;
      case GemType.black: return const Color(0xFF424242);
      case GemType.gold: return Colors.amberAccent;
    }
  }

  // 2. Lấy đường dẫn ảnh (SỬA LẠI CHO KHỚP VỚI TÊN FILE CỦA BẠN)
  static String getGemPath(GemType type) {
    switch (type) {
    // Tên file trong máy bạn là white.png, blue.png...
      case GemType.white: return 'assets/images/white.png';
      case GemType.blue:  return 'assets/images/blue.png';
      case GemType.green: return 'assets/images/green.png';
      case GemType.red:   return 'assets/images/red.png';
      case GemType.black: return 'assets/images/black.png';
      case GemType.gold:  return 'assets/images/yellow.png'; // Bạn đặt tên là yellow.png
    }
  }
}