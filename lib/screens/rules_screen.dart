import 'package:flutter/material.dart';
import 'home_screen.dart';

class RulesScreen extends StatelessWidget {
  final bool showEnterGameButton; // Biến kiểm soát hiển thị nút
  const RulesScreen({super.key, this.showEnterGameButton = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Luật Chơi Splendor"),
        automaticallyImplyLeading:
            !showEnterGameButton, // Ẩn nút back nếu là người mới
      ),
      body: Column(
        children: [
          const Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Text(
                "1. MỤC TIÊU:\nĐạt 15 điểm uy tín đầu tiên để chiến thắng.\n\n"
                "2. HÀNH ĐỘNG MỖI LƯỢT:\n"
                "   - Lấy 3 viên ngọc khác màu.\n"
                "   - Lấy 2 viên ngọc cùng màu (nếu chồng đó còn >= 4 viên).\n"
                "   - Mua 1 lá bài phát triển (trả bằng ngọc).\n"
                "   - Giữ 1 lá bài vào tay (và lấy 1 Vàng).\n\n"
                "3. THẺ BÀI & QUÝ TỘC:\n"
                "   - Thẻ bài cung cấp điểm và ngọc vĩnh cửu (bonus).\n"
                "   - Khi đủ bonus, Quý tộc sẽ tự động đến thăm (+3 điểm).",
                style:
                    TextStyle(fontSize: 16, height: 1.6, color: Colors.white70),
              ),
            ),
          ),

          // --- FIX: Nút vào game ---
          if (showEnterGameButton)
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()));
                },
                icon: const Icon(Icons.play_arrow, color: Colors.black),
                label: const Text("ĐÃ HIỂU - VÀO SẢNH",
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(vertical: 15)),
              ),
            )
        ],
      ),
    );
  }
}
