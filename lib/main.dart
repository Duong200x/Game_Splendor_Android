import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'models.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web cần options sinh từ FlutterFire.
  // Android/iOS đã có cấu hình native nên dùng default app để tránh duplicate-app.
  try {
    if (kIsWeb) {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        Firebase.app();
      }
    } else {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      } else {
        Firebase.app();
      }
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
    Firebase.app();
  }

  // Quét ảnh avatar — chỉ trên mobile
  if (!kIsWeb) {
    await AvatarHelper.loadAvatarsFromAssets();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Splendor Online',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: FirebaseAuth.instance.currentUser == null
          ? const LoginScreen()
          : const HomeScreen(),
    );
  }
}
