import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart'; // Import màn hình Setup

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      // 1. Kích hoạt Popup Google
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // Người dùng hủy đăng nhập
      }

      // 2. Lấy xác thực
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. Đăng nhập vào Firebase
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // 4. Kiểm tra xem user đã tồn tại trong DB chưa
        final userDocRef = FirebaseFirestore.instance
            .collection(AppConstants.collectionUsers)
            .doc(user.uid);

        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          // --- USER MỚI TINH ---
          // B1: Vẫn lưu thông tin cơ bản trước (Giữ logic cũ của bạn)
          String photoUrl = user.photoURL ?? AvatarHelper.getRandomAvatar();
          final newUser = UserModel(
            uid: user.uid,
            name: user.displayName ?? "Người chơi mới",
            email: user.email ?? "",
            avatarUrl: photoUrl,
          );
          // Lưu vào DB nhưng chưa có field 'isSetup'
          await userDocRef.set(newUser.toJson());

          // B2: Điều hướng sang trang Setup Hồ Sơ
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const ProfileSetupScreen(isEditMode: false)),
            );
          }
        } else {
          // --- USER ĐÃ CÓ DATA ---
          // Kiểm tra xem đã hoàn tất setup (chọn tên/avatar) chưa
          final userData = userDoc.data() as Map<String, dynamic>;
          bool isSetup = userData['isSetup'] ?? false;

          if (mounted) {
            if (isSetup) {
              // Đã setup xong -> Vào thẳng Home (Sảnh)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            } else {
              // Có data nhưng chưa đánh dấu xong -> Bắt buộc vào Setup lại
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const ProfileSetupScreen(isEditMode: false)),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi đăng nhập: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C), // Màu nền tối sang trọng
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.diamond_outlined, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              "SPLENDOR FAKE",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 50),
            if (_isLoading)
              const CircularProgressIndicator(color: Colors.amber)
            else
              ElevatedButton.icon(
                onPressed: _handleGoogleSignIn,
                icon: const Icon(Icons.login, color: Colors.black),
                label: const Text(
                  "Đăng nhập bằng Google",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}