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

  // Firebase khởi tạo với options đúng theo platform
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
