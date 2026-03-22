import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models.dart';
import 'rules_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEditMode;
  const ProfileSetupScreen({super.key, this.isEditMode = false});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  String _selectedAvatar = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  void _loadCurrentData() async {
    if (currentUser == null) return;
    String initialName = currentUser!.displayName ?? "Người chơi mới";
    String initialAvatar = currentUser!.photoURL ?? "";

    // Nếu chưa có avatar hoặc avatar là link hỏng, lấy cái đầu tiên trong assets
    if (initialAvatar.isEmpty && AvatarHelper.localAvatars.isNotEmpty) {
      initialAvatar = AvatarHelper.localAvatars[0];
    }

    final userDoc = await FirebaseFirestore.instance
        .collection(AppConstants.collectionUsers)
        .doc(currentUser!.uid)
        .get();

    if (userDoc.exists) {
      final data = userDoc.data()!;
      initialName = data['name'] ?? initialName;
      initialAvatar = data['avatarUrl'] ?? initialAvatar;
    }

    setState(() {
      _nameController.text = initialName;
      _selectedAvatar = initialAvatar;
    });
  }

  ImageProvider _getAvatarImage(String url) {
    if (url.isEmpty) {
      if (AvatarHelper.localAvatars.isNotEmpty) {
        return AssetImage(AvatarHelper.localAvatars[0]);
      }
      return const AssetImage('assets/images/black.png'); // Ảnh an toàn
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return AssetImage(url);
  }

  Future<void> _saveAndContinue() async {
    if (_nameController.text.trim().isEmpty) return;

    try {
      // 1. Cập nhật Auth Profile (Cái này quan trọng để Home tự update)
      await currentUser!.updateDisplayName(_nameController.text.trim());
      await currentUser!.updatePhotoURL(_selectedAvatar);

      // Force reload user để đảm bảo data mới nhất
      await currentUser!.reload();

      // 2. Cập nhật Firestore
      await FirebaseFirestore.instance
          .collection(AppConstants.collectionUsers)
          .doc(currentUser!.uid)
          .set({
        'uid': currentUser!.uid,
        'name': _nameController.text.trim(),
        'email': currentUser!.email,
        'avatarUrl': _selectedAvatar,
        'isSetup': true,
      }, SetOptions(merge: true));

      if (mounted) {
        if (widget.isEditMode) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Đã cập nhật hồ sơ!")));
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const RulesScreen(showEnterGameButton: true)),
          );
        }
      }
    } catch (e) {
      debugPrint("Lỗi lưu: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.isEditMode ? "Sửa Hồ Sơ" : "Thiết Lập Nhân Vật"),
        centerTitle: true,
        automaticallyImplyLeading: widget.isEditMode,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.amber,
              backgroundImage: _getAvatarImage(_selectedAvatar),
            ).animate().scale(),
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Biệt danh",
                labelStyle: const TextStyle(color: Colors.amber),
                enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.amber),
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.edit, color: Colors.amber),
              ),
            ),
            const SizedBox(height: 30),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text("Chọn Gương Mặt Đại Diện:",
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            if (AvatarHelper.localAvatars.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("Đang tải danh sách ảnh...",
                    style: TextStyle(color: Colors.grey)),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10),
                itemCount: AvatarHelper.localAvatars.length,
                itemBuilder: (context, index) {
                  final path = AvatarHelper.localAvatars[index];
                  final isSelected = _selectedAvatar == path;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAvatar = path),
                    child: Container(
                      decoration: BoxDecoration(
                        border: isSelected
                            ? Border.all(color: Colors.amber, width: 3)
                            : null,
                        shape: BoxShape.circle,
                        image: DecorationImage(
                            image: AssetImage(path), fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveAndContinue,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                child: Text(widget.isEditMode ? "LƯU THAY ĐỔI" : "TIẾP TỤC >>",
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
