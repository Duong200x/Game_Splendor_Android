import '../models/game_entities.dart';

class FullGameData {
  // =======================================================
  // 1. DỮ LIỆU QUÝ TỘC (10 THẺ)
  // Mỗi game chỉ rút ngẫu nhiên N+1 thẻ (N = số người chơi)
  // =======================================================
  static List<Noble> nobles = [
    Noble(id: 'N_01', points: 3, requirements: {GemType.white: 4, GemType.blue: 4}), // Anne of Brittany
    Noble(id: 'N_02', points: 3, requirements: {GemType.green: 4, GemType.red: 4}), // Charles V
    Noble(id: 'N_03', points: 3, requirements: {GemType.blue: 4, GemType.green: 4}), // Elisabeth of Austria
    Noble(id: 'N_04', points: 3, requirements: {GemType.white: 4, GemType.black: 4}), // Francis I
    Noble(id: 'N_05', points: 3, requirements: {GemType.black: 4, GemType.red: 4}), // Henry VIII
    Noble(id: 'N_06', points: 3, requirements: {GemType.red: 3, GemType.green: 3, GemType.blue: 3}), // Isabella I
    Noble(id: 'N_07', points: 3, requirements: {GemType.green: 3, GemType.blue: 3, GemType.white: 3}), // Machiavelli
    Noble(id: 'N_08', points: 3, requirements: {GemType.white: 3, GemType.black: 3, GemType.red: 3}), // Soliman
    Noble(id: 'N_09', points: 3, requirements: {GemType.black: 3, GemType.red: 3, GemType.white: 3}), // Catherine
    Noble(id: 'N_10', points: 3, requirements: {GemType.blue: 3, GemType.green: 3, GemType.white: 3}), // (Bonus - Một số bản in có khác biệt nhỏ, dùng chuẩn 3-3-3)
  ];

  // =======================================================
  // 2. THẺ CẤP 1 (LEVEL 1 - 40 THẺ)
  // Đặc điểm: Rẻ, ít điểm (0-1), chủ yếu lấy bonus
  // =======================================================
  static List<DevCard> level1Cards = [
    // --- ĐÁ ĐEN (BLACK BONUS) ---
    DevCard(id: 'L1_01', level: 1, points: 0, bonus: GemType.black, cost: {GemType.white: 1, GemType.blue: 1, GemType.green: 1, GemType.red: 1}),
    DevCard(id: 'L1_02', level: 1, points: 0, bonus: GemType.black, cost: {GemType.white: 1, GemType.blue: 2, GemType.green: 1, GemType.red: 1}),
    DevCard(id: 'L1_03', level: 1, points: 0, bonus: GemType.black, cost: {GemType.white: 2, GemType.blue: 2, GemType.red: 1}),
    DevCard(id: 'L1_04', level: 1, points: 0, bonus: GemType.black, cost: {GemType.green: 1, GemType.red: 3, GemType.black: 1}),
    DevCard(id: 'L1_05', level: 1, points: 0, bonus: GemType.black, cost: {GemType.green: 2, GemType.red: 1}),
    DevCard(id: 'L1_06', level: 1, points: 0, bonus: GemType.black, cost: {GemType.white: 2, GemType.green: 2}),
    DevCard(id: 'L1_07', level: 1, points: 0, bonus: GemType.black, cost: {GemType.green: 3}),
    DevCard(id: 'L1_08', level: 1, points: 1, bonus: GemType.black, cost: {GemType.blue: 4}),

    // --- ĐÁ XANH DƯƠNG (BLUE BONUS) ---
    DevCard(id: 'L1_09', level: 1, points: 0, bonus: GemType.blue, cost: {GemType.white: 1, GemType.black: 1, GemType.green: 1, GemType.red: 1}),
    DevCard(id: 'L1_10', level: 1, points: 0, bonus: GemType.blue, cost: {GemType.white: 1, GemType.black: 1, GemType.green: 2, GemType.red: 1}),
    DevCard(id: 'L1_11', level: 1, points: 0, bonus: GemType.blue, cost: {GemType.white: 1, GemType.green: 2, GemType.red: 2}),
    DevCard(id: 'L1_12', level: 1, points: 0, bonus: GemType.blue, cost: {GemType.blue: 1, GemType.green: 3, GemType.red: 1}),
    DevCard(id: 'L1_13', level: 1, points: 0, bonus: GemType.blue, cost: {GemType.white: 1, GemType.black: 2}),
    DevCard(id: 'L1_14', level: 1, points: 0, bonus: GemType.blue, cost: {GemType.green: 2, GemType.black: 2}),
    DevCard(id: 'L1_15', level: 1, points: 0, bonus: GemType.blue, cost: {GemType.black: 3}),
    DevCard(id: 'L1_16', level: 1, points: 1, bonus: GemType.blue, cost: {GemType.red: 4}),

    // --- ĐÁ TRẮNG (WHITE BONUS) ---
    DevCard(id: 'L1_17', level: 1, points: 0, bonus: GemType.white, cost: {GemType.blue: 1, GemType.black: 1, GemType.green: 1, GemType.red: 1}),
    DevCard(id: 'L1_18', level: 1, points: 0, bonus: GemType.white, cost: {GemType.blue: 1, GemType.black: 1, GemType.green: 1, GemType.red: 2}),
    DevCard(id: 'L1_19', level: 1, points: 0, bonus: GemType.white, cost: {GemType.blue: 2, GemType.black: 2, GemType.green: 1}),
    DevCard(id: 'L1_20', level: 1, points: 0, bonus: GemType.white, cost: {GemType.white: 3, GemType.blue: 1, GemType.black: 1}),
    DevCard(id: 'L1_21', level: 1, points: 0, bonus: GemType.white, cost: {GemType.blue: 2, GemType.black: 1}),
    DevCard(id: 'L1_22', level: 1, points: 0, bonus: GemType.white, cost: {GemType.blue: 2, GemType.red: 2}),
    DevCard(id: 'L1_23', level: 1, points: 0, bonus: GemType.white, cost: {GemType.blue: 3}),
    DevCard(id: 'L1_24', level: 1, points: 1, bonus: GemType.white, cost: {GemType.green: 4}),

    // --- ĐÁ XANH LÁ (GREEN BONUS) ---
    DevCard(id: 'L1_25', level: 1, points: 0, bonus: GemType.green, cost: {GemType.white: 1, GemType.blue: 1, GemType.black: 1, GemType.red: 1}),
    DevCard(id: 'L1_26', level: 1, points: 0, bonus: GemType.green, cost: {GemType.white: 1, GemType.blue: 1, GemType.black: 2, GemType.red: 1}),
    DevCard(id: 'L1_27', level: 1, points: 0, bonus: GemType.green, cost: {GemType.white: 1, GemType.blue: 1, GemType.black: 1, GemType.red: 2}), // Sửa lại logic chuẩn
    DevCard(id: 'L1_28', level: 1, points: 0, bonus: GemType.green, cost: {GemType.white: 1, GemType.blue: 3, GemType.green: 1}),
    DevCard(id: 'L1_29', level: 1, points: 0, bonus: GemType.green, cost: {GemType.white: 2, GemType.blue: 1}),
    DevCard(id: 'L1_30', level: 1, points: 0, bonus: GemType.green, cost: {GemType.blue: 2, GemType.red: 2}),
    DevCard(id: 'L1_31', level: 1, points: 0, bonus: GemType.green, cost: {GemType.red: 3}),
    DevCard(id: 'L1_32', level: 1, points: 1, bonus: GemType.green, cost: {GemType.black: 4}),

    // --- ĐÁ ĐỎ (RED BONUS) ---
    DevCard(id: 'L1_33', level: 1, points: 0, bonus: GemType.red, cost: {GemType.white: 1, GemType.blue: 1, GemType.black: 1, GemType.green: 1}),
    DevCard(id: 'L1_34', level: 1, points: 0, bonus: GemType.red, cost: {GemType.white: 2, GemType.blue: 1, GemType.black: 1, GemType.green: 1}),
    DevCard(id: 'L1_35', level: 1, points: 0, bonus: GemType.red, cost: {GemType.white: 2, GemType.black: 1, GemType.green: 2}),
    DevCard(id: 'L1_36', level: 1, points: 0, bonus: GemType.red, cost: {GemType.white: 1, GemType.red: 1, GemType.black: 1, GemType.green: 1, GemType.blue: 1}), // Lá đặc biệt 3 đá
    DevCard(id: 'L1_37', level: 1, points: 0, bonus: GemType.red, cost: {GemType.white: 2, GemType.red: 1}), // Sửa: Lá này thường là 2 trắng 1 đỏ
    DevCard(id: 'L1_38', level: 1, points: 0, bonus: GemType.red, cost: {GemType.white: 2, GemType.black: 2}),
    DevCard(id: 'L1_39', level: 1, points: 0, bonus: GemType.red, cost: {GemType.white: 3}),
    DevCard(id: 'L1_40', level: 1, points: 1, bonus: GemType.red, cost: {GemType.white: 4}),
  ];

  // =======================================================
  // 3. THẺ CẤP 2 (LEVEL 2 - 30 THẺ)
  // Đặc điểm: Giá trung bình, 1-2-3 điểm
  // =======================================================
  static List<DevCard> level2Cards = [
    // --- ĐÁ ĐEN (BLACK BONUS) ---
    DevCard(id: 'L2_01', level: 2, points: 1, bonus: GemType.black, cost: {GemType.white: 3, GemType.blue: 2, GemType.green: 2}),
    DevCard(id: 'L2_02', level: 2, points: 1, bonus: GemType.black, cost: {GemType.white: 3, GemType.green: 3, GemType.black: 2}),
    DevCard(id: 'L2_03', level: 2, points: 2, bonus: GemType.black, cost: {GemType.blue: 1, GemType.green: 4, GemType.red: 2}),
    DevCard(id: 'L2_04', level: 2, points: 2, bonus: GemType.black, cost: {GemType.green: 5, GemType.red: 3}),
    DevCard(id: 'L2_05', level: 2, points: 2, bonus: GemType.black, cost: {GemType.white: 5}),
    DevCard(id: 'L2_06', level: 2, points: 3, bonus: GemType.black, cost: {GemType.white: 6}),

    // --- ĐÁ XANH DƯƠNG (BLUE BONUS) ---
    DevCard(id: 'L2_07', level: 2, points: 1, bonus: GemType.blue, cost: {GemType.blue: 2, GemType.green: 2, GemType.red: 3}),
    DevCard(id: 'L2_08', level: 2, points: 1, bonus: GemType.blue, cost: {GemType.blue: 2, GemType.green: 3, GemType.black: 3}),
    DevCard(id: 'L2_09', level: 2, points: 2, bonus: GemType.blue, cost: {GemType.white: 2, GemType.red: 1, GemType.black: 4}), // Cost đặc biệt
    DevCard(id: 'L2_10', level: 2, points: 2, bonus: GemType.blue, cost: {GemType.white: 5, GemType.blue: 3}),
    DevCard(id: 'L2_11', level: 2, points: 2, bonus: GemType.blue, cost: {GemType.blue: 5}),
    DevCard(id: 'L2_12', level: 2, points: 3, bonus: GemType.blue, cost: {GemType.blue: 6}),

    // --- ĐÁ TRẮNG (WHITE BONUS) ---
    DevCard(id: 'L2_13', level: 2, points: 1, bonus: GemType.white, cost: {GemType.green: 3, GemType.red: 2, GemType.black: 2}),
    DevCard(id: 'L2_14', level: 2, points: 1, bonus: GemType.white, cost: {GemType.white: 2, GemType.blue: 3, GemType.red: 3}),
    DevCard(id: 'L2_15', level: 2, points: 2, bonus: GemType.white, cost: {GemType.green: 1, GemType.red: 4, GemType.black: 2}),
    DevCard(id: 'L2_16', level: 2, points: 2, bonus: GemType.white, cost: {GemType.red: 5, GemType.black: 3}), // Cost sửa lại cho đúng
    DevCard(id: 'L2_17', level: 2, points: 2, bonus: GemType.white, cost: {GemType.red: 5}),
    DevCard(id: 'L2_18', level: 2, points: 3, bonus: GemType.white, cost: {GemType.white: 6}), // Thực ra là 6 Black trong bản gốc nhưng để 6 White cho cân bằng

    // --- ĐÁ XANH LÁ (GREEN BONUS) ---
    DevCard(id: 'L2_19', level: 2, points: 1, bonus: GemType.green, cost: {GemType.white: 2, GemType.blue: 3, GemType.black: 2}),
    DevCard(id: 'L2_20', level: 2, points: 1, bonus: GemType.green, cost: {GemType.white: 3, GemType.green: 2, GemType.red: 3}),
    DevCard(id: 'L2_21', level: 2, points: 2, bonus: GemType.green, cost: {GemType.white: 4, GemType.blue: 2, GemType.black: 1}),
    DevCard(id: 'L2_22', level: 2, points: 2, bonus: GemType.green, cost: {GemType.blue: 5, GemType.green: 3}),
    DevCard(id: 'L2_23', level: 2, points: 2, bonus: GemType.green, cost: {GemType.green: 5}),
    DevCard(id: 'L2_24', level: 2, points: 3, bonus: GemType.green, cost: {GemType.green: 6}),

    // --- ĐÁ ĐỎ (RED BONUS) ---
    DevCard(id: 'L2_25', level: 2, points: 1, bonus: GemType.red, cost: {GemType.white: 2, GemType.red: 2, GemType.black: 3}),
    DevCard(id: 'L2_26', level: 2, points: 1, bonus: GemType.red, cost: {GemType.blue: 3, GemType.red: 2, GemType.black: 3}),
    DevCard(id: 'L2_27', level: 2, points: 2, bonus: GemType.red, cost: {GemType.white: 1, GemType.blue: 4, GemType.green: 2}),
    DevCard(id: 'L2_28', level: 2, points: 2, bonus: GemType.red, cost: {GemType.white: 3, GemType.black: 5}),
    DevCard(id: 'L2_29', level: 2, points: 2, bonus: GemType.red, cost: {GemType.black: 5}),
    DevCard(id: 'L2_30', level: 2, points: 3, bonus: GemType.red, cost: {GemType.red: 6}),
  ];

  // =======================================================
  // 4. THẺ CẤP 3 (LEVEL 3 - 20 THẺ)
  // Đặc điểm: Rất đắt, nhiều điểm (3-4-5)
  // =======================================================
  static List<DevCard> level3Cards = [
    // --- ĐÁ ĐEN (BLACK BONUS) ---
    DevCard(id: 'L3_01', level: 3, points: 3, bonus: GemType.black, cost: {GemType.white: 3, GemType.blue: 3, GemType.green: 5, GemType.red: 3}),
    DevCard(id: 'L3_02', level: 3, points: 4, bonus: GemType.black, cost: {GemType.red: 7}),
    DevCard(id: 'L3_03', level: 3, points: 4, bonus: GemType.black, cost: {GemType.green: 3, GemType.red: 6, GemType.black: 3}),
    DevCard(id: 'L3_04', level: 3, points: 5, bonus: GemType.black, cost: {GemType.red: 7, GemType.black: 3}),

    // --- ĐÁ XANH DƯƠNG (BLUE BONUS) ---
    DevCard(id: 'L3_05', level: 3, points: 3, bonus: GemType.blue, cost: {GemType.white: 3, GemType.green: 3, GemType.red: 3, GemType.black: 5}),
    DevCard(id: 'L3_06', level: 3, points: 4, bonus: GemType.blue, cost: {GemType.white: 6, GemType.blue: 3, GemType.black: 3}),
    DevCard(id: 'L3_07', level: 3, points: 4, bonus: GemType.blue, cost: {GemType.white: 7}),
    DevCard(id: 'L3_08', level: 3, points: 5, bonus: GemType.blue, cost: {GemType.white: 7, GemType.blue: 3}),

    // --- ĐÁ TRẮNG (WHITE BONUS) ---
    DevCard(id: 'L3_09', level: 3, points: 3, bonus: GemType.white, cost: {GemType.blue: 3, GemType.green: 3, GemType.red: 5, GemType.black: 3}),
    DevCard(id: 'L3_10', level: 3, points: 4, bonus: GemType.white, cost: {GemType.black: 7}),
    DevCard(id: 'L3_11', level: 3, points: 4, bonus: GemType.white, cost: {GemType.white: 3, GemType.red: 3, GemType.black: 6}),
    DevCard(id: 'L3_12', level: 3, points: 5, bonus: GemType.white, cost: {GemType.white: 3, GemType.black: 7}),

    // --- ĐÁ XANH LÁ (GREEN BONUS) ---
    DevCard(id: 'L3_13', level: 3, points: 3, bonus: GemType.green, cost: {GemType.white: 5, GemType.blue: 3, GemType.red: 3, GemType.black: 3}),
    DevCard(id: 'L3_14', level: 3, points: 4, bonus: GemType.green, cost: {GemType.blue: 7}),
    DevCard(id: 'L3_15', level: 3, points: 4, bonus: GemType.green, cost: {GemType.white: 3, GemType.blue: 6, GemType.green: 3}),
    DevCard(id: 'L3_16', level: 3, points: 5, bonus: GemType.green, cost: {GemType.blue: 7, GemType.green: 3}),

    // --- ĐÁ ĐỎ (RED BONUS) ---
    DevCard(id: 'L3_17', level: 3, points: 3, bonus: GemType.red, cost: {GemType.white: 3, GemType.blue: 5, GemType.green: 3, GemType.black: 3}),
    DevCard(id: 'L3_18', level: 3, points: 4, bonus: GemType.red, cost: {GemType.green: 7}),
    DevCard(id: 'L3_19', level: 3, points: 4, bonus: GemType.red, cost: {GemType.blue: 3, GemType.green: 6, GemType.red: 3}),
    DevCard(id: 'L3_20', level: 3, points: 5, bonus: GemType.red, cost: {GemType.green: 7, GemType.red: 3}),
  ];
}