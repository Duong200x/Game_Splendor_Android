import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'dart:async';

import '../models.dart';
import '../managers/sound_manager.dart'; // Import Sound Manager
import 'login_screen.dart';
import 'rules_screen.dart';
import 'profile_setup_screen.dart';
import 'game_room_screen.dart';
import 'test_card_screen.dart';
import 'game_board_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _staleMs = 30000;
  static const Duration _roomsCleanupInterval = Duration(seconds: 20);

  Timer? _roomsCleanupTimer;

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  bool _isPlayerStale(Map<String, dynamic> p, int nowMs) {
    final lastSeen = p['lastSeen'];
    if (lastSeen is int && lastSeen > 0) {
      return nowMs - lastSeen > _staleMs;
    }
    final joinAt = p['joinAt'];
    if (joinAt is int && joinAt > 0) {
      return nowMs - joinAt > _staleMs;
    }
    return false;
  }

  List<Map<String, dynamic>> _playersFrom(dynamic raw) {
    return List<Map<String, dynamic>>.from((raw ?? []) as List);
  }

  List<Map<String, dynamic>> _activePlayers(dynamic rawPlayers) {
    final now = _nowMs;
    final players = _playersFrom(rawPlayers);
    return players.where((p) => !_isPlayerStale(p, now)).toList();
  }

  Future<void> _cleanupStalePlayersInRoom(String roomId) async {
    final roomRef = FirebaseFirestore.instance
        .collection(AppConstants.collectionRooms)
        .doc(roomId);
    final now = _nowMs;

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(roomRef);
        if (!snap.exists) return;

        final data = snap.data() as Map<String, dynamic>;
        final status = (data['status'] ?? 'waiting').toString();
        if (status != 'waiting') return;

        final oldPlayers = _playersFrom(data['players']);
        final kept = oldPlayers.where((p) => !_isPlayerStale(p, now)).toList();
        if (kept.length == oldPlayers.length) return;

        if (kept.isEmpty) {
          tx.update(roomRef, {'players': [], 'hostId': ''});
          return;
        }

        String hostId = (data['hostId'] ?? '').toString();
        final hostExists = hostId.isNotEmpty &&
            kept.any((p) => (p['uid'] ?? '').toString() == hostId);
        if (!hostExists) {
          hostId = (kept.first['uid'] ?? '').toString();
        }

        final rebuilt = kept
            .map((p) => {
                  ...p,
                  'isHost': (p['uid'] ?? '').toString() == hostId,
                })
            .toList();

        tx.update(roomRef, {'players': rebuilt, 'hostId': hostId});
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _cleanupAllRoomsStale() async {
    // dự án có 5 phòng cố định room_1..room_5
    for (int i = 1; i <= 5; i++) {
      await _cleanupStalePlayersInRoom('room_$i');
    }
  }

  ImageProvider _getAvatarImage(String? url) {
    if (url == null || url.isEmpty) {
      if (AvatarHelper.localAvatars.isNotEmpty) {
        return AssetImage(AvatarHelper.localAvatars[0]);
      }
      return const AssetImage('assets/avatars/meme_1.png');
    }
    var normalized = url;
    if (normalized.startsWith('file://')) {
      try {
        final uri = Uri.parse(normalized);
        final p = uri.path;
        if (p.isNotEmpty) {
          normalized = p.startsWith('/') ? p.substring(1) : p;
        }
      } catch (_) {}
    }
    if (normalized.startsWith('/assets/')) {
      normalized = normalized.substring(1);
    }
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return NetworkImage(normalized);
    }
    if (normalized.startsWith('assets/')) {
      return AssetImage(normalized);
    }
    if (AvatarHelper.localAvatars.isNotEmpty) {
      return AssetImage(AvatarHelper.localAvatars[0]);
    }
    return const AssetImage('assets/avatars/meme_1.png');
  }

  Future<void> _signOut() async {
    SoundManager().playClick();
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  // --- HÀM HIỂN THỊ CÀI ĐẶT ÂM THANH ---
  void _showSettingsDialog() {
    SoundManager().playClick();
    showDialog(
      context: context,
      builder: (context) {
        // Dùng StatefulBuilder để Slider có thể vẽ lại khi kéo
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.amber, width: 2)),
              title: const Text("CÀI ĐẶT",
                  style: TextStyle(
                      color: Colors.amber, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. THANH NHẠC NỀN
                  const Row(
                    children: [
                      Icon(Icons.music_note, color: Colors.white70),
                      SizedBox(width: 10),
                      Text("Nhạc nền", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  Slider(
                    value: SoundManager().bgmVolume,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Colors.amber,
                    onChanged: (val) {
                      setState(() {
                        SoundManager().setBGMVolume(val);
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // 2. THANH HIỆU ỨNG
                  const Row(
                    children: [
                      Icon(Icons.volume_up, color: Colors.white70),
                      SizedBox(width: 10),
                      Text("Hiệu ứng", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  Slider(
                    value: SoundManager().sfxVolume,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) {
                      setState(() {
                        SoundManager().setSFXVolume(val);
                      });
                    },
                    // Phát thử tiếng click khi thả tay ra (tùy chọn)
                    onChangeEnd: (_) => SoundManager().playToken(),
                  ),
                ],
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey),
                    onPressed: () {
                      SoundManager().playClick();
                      Navigator.pop(context);
                    },
                    child: const Text("ĐÓNG",
                        style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            );
          },
        );
      },
    );
  }

// Thay thế hàm cũ bằng hàm này trong home_screen.dart
  Future<void> _initRoomsIfNeeded() async {
    final roomsRef =
        FirebaseFirestore.instance.collection(AppConstants.collectionRooms);

    // Duyệt qua 5 phòng
    for (int i = 1; i <= 5; i++) {
      final docRef = roomsRef.doc('room_$i');
      final docSnapshot = await docRef.get();

      // Nếu phòng này chưa tồn tại (hoặc đã bị xóa) -> Tạo lại
      if (!docSnapshot.exists) {
        await docRef.set({
          'id': 'room_$i',
          'name': 'Bàn Chơi $i',
          'status': 'waiting',
          'hostId': '',
          'maxPlayers': 4, // Mặc định 4 người
          'players': [],
          'turnDuration': 30,
          'winningScore': 15,
        });
        debugPrint("Đã khôi phục room_$i");
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initRoomsIfNeeded();
    SoundManager().playBGM();
    _roomsCleanupTimer ??=
        Timer.periodic(_roomsCleanupInterval, (_) => _cleanupAllRoomsStale());
  }

  @override
  void dispose() {
    _roomsCleanupTimer?.cancel();
    _roomsCleanupTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, userSnapshot) {
        final currentUser = userSnapshot.data;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            // --- NÚT SETTINGS (BÁNH RĂNG) Ở BÊN TRÁI ---
            leading: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70, size: 28),
              onPressed: _showSettingsDialog,
            ),
            title: const Text(
              "Sảnh Đá Quý",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
                letterSpacing: 1.5,
                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
              ),
            ),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GestureDetector(
                  onTap: () {
                    SoundManager().playClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const ProfileSetupScreen(isEditMode: true)),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber, width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.5),
                            blurRadius: 10)
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[900],
                      backgroundImage: _getAvatarImage(currentUser?.photoURL),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                onPressed: _signOut,
              ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [Color(0xFF2E3B55), Color(0xFF1A1A2E), Colors.black],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildGlassMenuCard(
                            icon: Icons.auto_stories,
                            title: "Luật",
                            color: Colors.cyanAccent,
                            onTap: () {
                              SoundManager().playClick();
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const RulesScreen()));
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildGlassMenuCard(
                            icon: Icons.sports_esports,
                            title: "Tập Luyện",
                            color: Colors.greenAccent,
                            onTap: () {
                              SoundManager().playClick();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const GameBoardScreen(
                                    playerCount: 4,
                                    turnDuration: 30,
                                    winningScore: 15,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildGlassMenuCard(
                            icon: Icons.style,
                            title: "Kho Thẻ",
                            color: Colors.purpleAccent,
                            onTap: () {
                              SoundManager().playClick();
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const TestCardScreen()));
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .slideY(begin: -0.5, end: 0, duration: 600.ms)
                      .fadeIn(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Divider(color: Colors.white10),
                  ),
                  const Text(
                    "CHỌN BÀN CHƠI (ONLINE)",
                    style: TextStyle(
                      color: Colors.white60,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 12,
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(AppConstants.collectionRooms)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.amber));
                        }

                        var rooms = snapshot.data!.docs;
                        rooms.sort((a, b) => a['id'].compareTo(b['id']));

                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.1,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: rooms.length,
                          itemBuilder: (context, index) {
                            var room =
                                rooms[index].data() as Map<String, dynamic>;
                            final active = _activePlayers(room['players']);
                            final maxPlayers = (room['maxPlayers'] ?? 4) as int;
                            final isFull = active.length >= maxPlayers;

                            return _buildNeonRoomCard(
                                    room, active.length, isFull)
                                .animate(delay: (100 * index).ms)
                                .scale(
                                    duration: 400.ms, curve: Curves.easeOutBack)
                                .fadeIn();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassMenuCard(
      {required IconData icon,
      required String title,
      required Color color,
      required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.05)
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28)
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(delay: 2000.ms, duration: 1000.ms),
                const SizedBox(height: 8),
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeonRoomCard(
      Map<String, dynamic> room, int playerCount, bool isFull) {
    Color borderColor = isFull ? Colors.redAccent : Colors.cyanAccent;
    Color glowColor = isFull
        ? Colors.red.withValues(alpha: 0.4)
        : Colors.cyanAccent.withValues(alpha: 0.4);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252535),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isFull ? 1 : 2),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 12,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            SoundManager().playClick();
            if (isFull) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Phòng này đã đầy!"),
                  backgroundColor: Colors.red));
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GameRoomScreen(
                  roomId: room['id'],
                  roomName: room['name'],
                ),
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                room['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people,
                        size: 16,
                        color: isFull ? Colors.redAccent : Colors.cyanAccent),
                    const SizedBox(width: 6),
                    Text(
                      "$playerCount / ${room['maxPlayers']}",
                      style: TextStyle(
                          color: isFull ? Colors.redAccent : Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isFull
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isFull ? "FULL" : "JOIN",
                  style: TextStyle(
                    color: isFull ? Colors.redAccent : Colors.cyanAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
