import 'package:flutter/material.dart';
import '../full_game_data.dart'; // <--- ĐÃ SỬA: Import file dữ liệu đầy đủ
import '../widgets/game_card_widget.dart';
import '../widgets/game_card_back_widget.dart';
import '../widgets/noble_widget.dart';
import '../widgets/game_token_widget.dart';
import '../models/game_entities.dart';

class TestCardScreen extends StatelessWidget {
  const TestCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A), // Nền tối
      appBar: AppBar(
        title: const Text("Thư Viện Thẻ Bài (Full)",
            style: TextStyle(color: Colors.amber)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- QUÝ TỘC ---
            const Text("QUÝ TỘC (Nobles - 3 Điểm)",
                style: TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 15,
              runSpacing: 15,
              // ĐÃ SỬA: Dùng FullGameData
              children: FullGameData.nobles
                  .map((n) => NobleWidget(noble: n))
                  .toList(),
            ),
            const SizedBox(height: 30), const Divider(color: Colors.white24),
            const SizedBox(height: 10),

            // --- MẶT SAU ---
            const Text("MẶT SAU (CÁC CHỒNG BÀI ÚP)",
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GameCardBackWidget(level: 1),
                GameCardBackWidget(level: 2),
                GameCardBackWidget(level: 3),
              ],
            ),
            const SizedBox(height: 30), const Divider(color: Colors.white24),
            const SizedBox(height: 10),
            // --- KHU VỰC TEST TOKEN ---
            const Text("KHO ĐÁ QUÝ (TOKENS)",
                style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                GameTokenWidget(type: GemType.white, count: 7, onTap: () {}),
                GameTokenWidget(type: GemType.blue, count: 5, onTap: () {}),
                GameTokenWidget(type: GemType.green, count: 4, onTap: () {}),
                GameTokenWidget(type: GemType.red, count: 2, onTap: () {}),
                GameTokenWidget(
                    type: GemType.black,
                    count: 7,
                    onTap: () {}), // Test hết hàng
                GameTokenWidget(
                    type: GemType.gold, count: 5, onTap: () {}), // Joker vàng
              ],
            ),
            const SizedBox(height: 30), const Divider(color: Colors.white24),
            const SizedBox(height: 10),
            // --- CẤP 1 ---
            // ĐÃ SỬA: Dùng FullGameData.level1Cards
            _buildLevelSection("CẤP 1 (Level 1 - 40 Thẻ)", Colors.greenAccent,
                FullGameData.level1Cards),
            const SizedBox(height: 20),

            // --- CẤP 2 ---
            // ĐÃ SỬA: Dùng FullGameData.level2Cards
            _buildLevelSection("CẤP 2 (Level 2 - 30 Thẻ)", Colors.amber,
                FullGameData.level2Cards),
            const SizedBox(height: 20),

            // --- CẤP 3 ---
            // ĐÃ SỬA: Dùng FullGameData.level3Cards
            _buildLevelSection("CẤP 3 (Level 3 - 20 Thẻ)", Colors.purpleAccent,
                FullGameData.level3Cards),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Hàm phụ trợ để vẽ từng cấp độ cho gọn code
  Widget _buildLevelSection(String title, Color color, List<dynamic> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 15),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: cards.map((card) => DevCardWidget(card: card)).toList(),
        ),
      ],
    );
  }
}
