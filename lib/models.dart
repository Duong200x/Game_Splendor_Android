import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppConstants {
  static const String collectionUsers = 'splendor_users';
  static const String collectionRooms = 'splendor_rooms';
}

class AvatarHelper {
  static List<String> localAvatars = [];

  // --- FIX: Dùng AssetManifest.loadFromAssetBundle thay vì loadString ---
  static Future<void> loadAvatarsFromAssets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      // Lấy danh sách file bắt đầu bằng assets/avatars/
      localAvatars = manifest
          .listAssets()
          .where((String key) => key.startsWith('assets/avatars/'))
          .toList();

      debugPrint("✅ Đã tìm thấy ${localAvatars.length} avatar trong máy.");
    } catch (e) {
      debugPrint("❌ Lỗi load avatar: $e");
      // Fallback thủ công nếu quét lỗi (đề phòng)
      localAvatars = [
        'assets/avatars/meme_1.png', // Đảm bảo bạn có ít nhất 1 file tên này hoặc sửa theo tên file thật
      ];
    }
  }

  static String getRandomAvatar() {
    if (localAvatars.isEmpty) return '';
    final random = Random();
    return localAvatars[random.nextInt(localAvatars.length)];
  }
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String avatarUrl;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.avatarUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      name: json['name'] ?? 'Unknown',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
    );
  }
}
