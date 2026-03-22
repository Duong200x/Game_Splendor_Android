import 'package:flutter/material.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hướng dẫn tập chơi")),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 60, color: Colors.orange),
            SizedBox(height: 20),
            Text("Tính năng đang phát triển...",
                style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
