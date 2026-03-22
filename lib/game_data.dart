// lib/game_data.dart
import '../models/game_entities.dart';

class GameData {
  // Dữ liệu mẫu Level 1
  static List<DevCard> level1Cards = [
    DevCard(
      id: 'L1_01',
      level: 1,
      points: 0,
      bonus: GemType.blue,
      cost: {
        GemType.white: 1,
        GemType.black: 2,
        GemType.green: 2
      }, // Giá: 1 trắng, 2 đen, 2 lục
    ),
    DevCard(
      id: 'L1_02',
      level: 1,
      points: 1,
      bonus: GemType.black,
      cost: {GemType.blue: 4}, // Giá: 4 lam
    ),
  ];

  // --- THÊM ĐOẠN NÀY: DỮ LIỆU LEVEL 2 ---
  static List<DevCard> level2Cards = [
    DevCard(
      id: 'L2_01',
      level: 2,
      points: 2,
      // Cấp 2 thường có 1-3 điểm
      bonus: GemType.green,
      cost: {GemType.white: 3, GemType.blue: 2, GemType.red: 2},
    ),
    DevCard(
      id: 'L2_02',
      level: 2,
      points: 3,
      bonus: GemType.white,
      cost: {GemType.black: 6}, // Thẻ đắt đỏ
    ),
  ];

  // --------------------------------------
  // Dữ liệu mẫu Level 3 (Thẻ xịn)
  static List<DevCard> level3Cards = [
    DevCard(
      id: 'L3_01',
      level: 3,
      points: 5,
      bonus: GemType.red,
      cost: {GemType.white: 7, GemType.blue: 3},
    ),
  ];

// Dữ liệu mẫu Quý Tộc
  static List<Noble> nobles = [
    Noble(
      id: 'N_01',
      points: 3,
      requirements: {
        GemType.red: 4,
        GemType.green: 4
      }, // Cần 4 thẻ đỏ, 4 thẻ lục
    ),
    Noble(
      id: 'N_02',
      points: 3,
      requirements: {
        GemType.blue: 3,
        GemType.white: 3,
        GemType.black: 3
      }, // Cần 3 lam, 3 trắng, 3 đen
    ),
  ];
}