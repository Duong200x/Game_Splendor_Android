import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../managers/sound_manager.dart';
import '../logic/online_game_manager.dart';
import 'online_game_board_screen.dart';

class GameRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const GameRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen>
    with WidgetsBindingObserver {
  final OnlineGameManager _gameManager = OnlineGameManager();

  static const int _staleMs =
      30000; // 30s không heartbeat => coi như out (chỉ áp dụng khi status=waiting)
  static const Duration _heartbeatInterval = Duration(seconds: 15);
  static const int _cleanupThrottleMs = 5000;

  Timer? _heartbeatTimer;
  bool _cleanupInProgress = false;
  int _lastCleanupAtMs = 0;

  bool _navigatedToGame = false;

  Map<String, dynamic> _cachedRoomData = {};
  bool _cachedIsInRoom = false;
  String _cachedStatus = 'waiting';

  String get myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> get _roomRef =>
      FirebaseFirestore.instance
          .collection(AppConstants.collectionRooms)
          .doc(widget.roomId);

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  ImageProvider _avatarProvider(String? raw) {
    // fallback local avatar
    if ((raw == null) || raw.trim().isEmpty) {
      if (AvatarHelper.localAvatars.isNotEmpty) {
        return AssetImage(AvatarHelper.localAvatars[0]);
      }
      return const AssetImage('assets/avatars/meme_1.png');
    }

    var url = raw.trim();

    // normalize: NetworkImage không nhận asset path; và 'file:///assets/..' cần strip
    if (url.startsWith('file://')) {
      try {
        final uri = Uri.parse(url);
        final p = uri.path; // '/assets/...'
        if (p.isNotEmpty) {
          url = p.startsWith('/') ? p.substring(1) : p;
        }
      } catch (_) {
        // giữ nguyên url
      }
    }
    if (url.startsWith('/assets/')) {
      url = url.substring(1);
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    }
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }

    // không đủ dữ liệu để xác minh nguồn ảnh => fallback asset
    if (AvatarHelper.localAvatars.isNotEmpty) {
      return AssetImage(AvatarHelper.localAvatars[0]);
    }
    return const AssetImage('assets/avatars/meme_1.png');
  }

  List<Map<String, dynamic>> _playersFrom(dynamic raw) {
    return List<Map<String, dynamic>>.from((raw ?? []) as List);
  }

  bool _isPlayerStale(Map<String, dynamic> p, int nowMs) {
    final lastSeen = p['lastSeen'];
    if (lastSeen is int && lastSeen > 0) {
      return nowMs - lastSeen > _staleMs;
    }
    // fallback: nếu chưa có lastSeen, dùng joinAt (nếu có) để tránh xóa nhầm player cũ
    final joinAt = p['joinAt'];
    if (joinAt is int && joinAt > 0) {
      return nowMs - joinAt > _staleMs;
    }
    // không đủ dữ liệu để xác minh stale => giữ lại
    return false;
  }

  int _joinAtOf(Map<String, dynamic> p) {
    final v = p['joinAt'];
    return (v is int) ? v : 0;
  }

  String _uidOf(Map<String, dynamic> p) => (p['uid'] ?? '').toString();

  List<Map<String, dynamic>> _rebuildHostFlags(
      List<Map<String, dynamic>> players, String hostId) {
    return players.map((p) {
      final uid = _uidOf(p);
      return {...p, 'isHost': uid.isNotEmpty && uid == hostId};
    }).toList();
  }

  String _pickHostId(List<Map<String, dynamic>> players) {
    if (players.isEmpty) return '';
    final sorted = [...players]..sort((a, b) {
        final aj = _joinAtOf(a);
        final bj = _joinAtOf(b);
        if (aj != bj) return aj.compareTo(bj);
        return _uidOf(a).compareTo(_uidOf(b));
      });
    return _uidOf(sorted.first);
  }

  void _goToGameScreen() {
    if (_navigatedToGame) return;
    _navigatedToGame = true;

    // ép landscape ngay trước khi chuyển màn
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineGameBoardScreen(
            roomId: widget.roomId,
            roomName: widget.roomName,
          ),
        ),
      );
    });
  }

  void _autoGoToGameIfPlaying(String status, bool isInRoom) {
    if (status == 'playing' && isInRoom) {
      _goToGameScreen();
      return;
    }
    if (status != 'playing') {
      _navigatedToGame = false;
    }
  }

  void _syncHeartbeat(bool shouldRun) {
    if (shouldRun) {
      _heartbeatTimer ??=
          Timer.periodic(_heartbeatInterval, (_) => _heartbeatTick());
    } else {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  Future<void> _heartbeatTick() async {
    if (!mounted) return;
    if (myUid.isEmpty) return;
    if (_cachedStatus != 'waiting') return;
    if (!_cachedIsInRoom) return;

    // cập nhật lastSeen; đồng thời dọn stale + sửa host nếu cần
    await _upsertPresence(pruneStale: true);
  }

  Future<void> _upsertPresence({required bool pruneStale}) async {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Player';
    final photoURL = user?.photoURL ?? '';

    final now = _nowMs;
    bool rejoin = false;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(_roomRef);
      final data = snap.data() ?? <String, dynamic>{};

      final status = (data['status'] ?? 'waiting') as String;
      final maxPlayers = (data['maxPlayers'] ?? 4) as int;
      String hostId = (data['hostId'] ?? '') as String;

      final players = _playersFrom(data['players']);

      // chỉ cleanup tự động khi đang ở lobby (waiting)
      final effectivePlayers = (pruneStale && status == 'waiting')
          ? players.where((p) => !_isPlayerStale(p, now)).toList()
          : players;

      final idx = effectivePlayers.indexWhere((p) => _uidOf(p) == myUid);

      if (idx >= 0) {
        // rejoin/update profile + lastSeen
        rejoin = true;
        final old = effectivePlayers[idx];
        final joinAt = _joinAtOf(old);
        effectivePlayers[idx] = {
          ...old,
          'uid': myUid,
          'name': displayName,
          'avatarUrl': photoURL,
          'photoURL': photoURL,
          'avatar': photoURL,
          'lastSeen': now,
          'joinAt': joinAt == 0 ? now : joinAt,
        };
      } else {
        if (effectivePlayers.length >= maxPlayers) {
          throw Exception('ROOM_FULL');
        }

        effectivePlayers.add({
          'uid': myUid,
          'name': displayName,
          'avatarUrl': photoURL,
          'photoURL': photoURL,
          'avatar': photoURL,
          'isHost': false,
          'lastSeen': now,
          'joinAt': now,
        });
      }

      // host validation/assign
      final hostExists =
          hostId.isNotEmpty && effectivePlayers.any((p) => _uidOf(p) == hostId);
      if (!hostExists) {
        hostId = _pickHostId(effectivePlayers);
      }

      final rebuilt = _rebuildHostFlags(effectivePlayers, hostId);

      tx.update(_roomRef, {
        'hostId': hostId,
        'players': rebuilt,
      });
    });

    if (mounted) {
      _showSnack(rejoin ? "Đã vào lại phòng!" : "Đã vào phòng!");
    }
  }

  Future<void> _cleanupRoomIfNeeded({bool force = false}) async {
    if (!mounted) return;
    if (myUid.isEmpty) return;
    if (_cleanupInProgress) return;
    if (_cachedStatus != 'waiting') return;
    if (!_cachedIsInRoom) return;

    final now = _nowMs;
    if (!force && (now - _lastCleanupAtMs) < _cleanupThrottleMs) return;

    _cleanupInProgress = true;
    _lastCleanupAtMs = now;

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(_roomRef);
        final data = snap.data() ?? <String, dynamic>{};

        final status = (data['status'] ?? 'waiting') as String;
        if (status != 'waiting') return;

        final oldPlayers = _playersFrom(data['players']);
        final oldHostId = (data['hostId'] ?? '') as String;

        final kept = oldPlayers.where((p) => !_isPlayerStale(p, now)).toList();

        if (kept.isEmpty) {
          tx.update(_roomRef, {
            'hostId': '',
            'players': [],
            'status': 'waiting',
            'gameState': FieldValue.delete(),
            'decks': FieldValue.delete(),
          });
          return;
        }

        String hostId = oldHostId;
        final hostExists =
            hostId.isNotEmpty && kept.any((p) => _uidOf(p) == hostId);
        if (!hostExists) {
          hostId = _pickHostId(kept);
        }

        final rebuilt = _rebuildHostFlags(kept, hostId);

        // chỉ update khi có thay đổi thực sự
        final changed =
            rebuilt.length != oldPlayers.length || hostId != oldHostId;
        if (changed) {
          tx.update(_roomRef, {
            'hostId': hostId,
            'players': rebuilt,
          });
        }
      });
    } finally {
      _cleanupInProgress = false;
    }
  }

  // =========================
  // HOST SETTINGS DIALOG
  // =========================
  Future<void> _showHostSettingsDialog({
    required int currentMaxPlayers,
    required int currentTurnDuration,
    required int currentWinningScore,
    required int currentPlayerCount,
    required String status,
  }) async {
    if (status != 'waiting') {
      _showSnack("Không thể chỉnh khi phòng đang chơi!", isError: true);
      return;
    }

    int maxPlayers = currentMaxPlayers;
    int turnDuration = currentTurnDuration;
    int winningScore = currentWinningScore;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0D1117),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.amber),
              ),
              title: const Text(
                "Cài đặt phòng (Host)",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // MAX PLAYERS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Số người tối đa",
                            style: TextStyle(color: Colors.white70)),
                        Text("$maxPlayers",
                            style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: maxPlayers.toDouble(),
                      min: 2,
                      max: 6,
                      divisions: 4,
                      activeColor: Colors.amber,
                      onChanged: (v) {
                        final candidate = v.round();
                        // Không cho set thấp hơn số người đang trong phòng
                        if (candidate < currentPlayerCount) return;
                        setStateDialog(() => maxPlayers = candidate);
                      },
                    ),
                    const SizedBox(height: 12),

                    // TURN DURATION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Thời gian lượt (giây)",
                            style: TextStyle(color: Colors.white70)),
                        Text("$turnDuration",
                            style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: turnDuration.toDouble(),
                      min: 10,
                      max: 120,
                      divisions: 11,
                      activeColor: Colors.cyanAccent,
                      onChanged: (v) =>
                          setStateDialog(() => turnDuration = v.round()),
                    ),
                    const SizedBox(height: 12),

                    // WINNING SCORE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Điểm thắng",
                            style: TextStyle(color: Colors.white70)),
                        Text("$winningScore",
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: winningScore.toDouble(),
                      min: 10,
                      max: 30,
                      divisions: 20,
                      activeColor: Colors.greenAccent,
                      onChanged: (v) =>
                          setStateDialog(() => winningScore = v.round()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Huỷ",
                      style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  onPressed: () async {
                    try {
                      await _roomRef.update({
                        'maxPlayers': maxPlayers,
                        'turnDuration': turnDuration,
                        'winningScore': winningScore,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      _showSnack("Lỗi cập nhật: $e", isError: true);
                    }
                  },
                  child: const Text("Lưu",
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _joinRoom(Map<String, dynamic> roomData) async {
    if (myUid.isEmpty) return;

    try {
      // join/rejoin + update lastSeen (transaction)
      await _upsertPresence(pruneStale: true);
    } catch (e) {
      final msg = e.toString().contains('ROOM_FULL')
          ? "Phòng đã đầy!"
          : "Lỗi vào phòng: $e";
      _showSnack(msg, isError: true);
    }
  }

  Future<void> _leaveRoom(Map<String, dynamic> roomData,
      {bool popAfter = true}) async {
    if (myUid.isEmpty) {
      if (popAfter && mounted) Navigator.pop(context);
      return;
    }

    try {
      final isHost = (roomData['hostId'] ?? '') == myUid;

      // Sử dụng logic của Manager để đảm bảo nhất quán
      if (isHost) {
        await _gameManager.endGameHostLeft(widget.roomId);
      } else {
        await _gameManager.leaveGameAsNonHost(widget.roomId, myUid);
      }

      if (popAfter && mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack("Lỗi rời phòng: $e", isError: true);
    }
  }

  // =========================
  // HOST START GAME
  // =========================
  Future<void> _startGame(Map<String, dynamic> roomData) async {
    final status = (roomData['status'] ?? 'waiting') as String;
    if (status != 'waiting') {
      _showSnack("Phòng đang chơi rồi!", isError: true);
      return;
    }

    final hostId = (roomData['hostId'] ?? '') as String;
    if (hostId != myUid) {
      _showSnack("Chỉ host mới được bắt đầu!", isError: true);
      return;
    }

    // cleanup stale trước khi start
    await _cleanupRoomIfNeeded(force: true);

    final latestSnap = await _roomRef.get();
    final latest = latestSnap.data() ?? {};
    final latestPlayers = (latest['players'] ?? []) as List;

    if (latestPlayers.length < 2) {
      _showSnack("Cần ít nhất 2 người để bắt đầu!", isError: true);
      return;
    }

    final turnDuration = (latest['turnDuration'] ?? 30) as int;
    final winningScore = (latest['winningScore'] ?? 15) as int;

    try {
      await _gameManager.hostStartGame(
        widget.roomId,
        latestPlayers,
        targetScore: winningScore,
        turnDuration: turnDuration,
      );

      // ép landscape trước khi chuyển màn
      _goToGameScreen();
    } catch (e) {
      _showSnack("Lỗi bắt đầu game: $e", isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Firestore không có onDisconnect; dùng best-effort:
    // - background: dừng heartbeat (sau _staleMs sẽ bị cleanup nếu đang waiting)
    // - detached: cố gắng rời phòng ngay
    if (state == AppLifecycleState.paused) {
      _syncHeartbeat(false);
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_cachedStatus == 'waiting' && _cachedIsInRoom) {
        _syncHeartbeat(true);
        _upsertPresence(pruneStale: true);
      }
      return;
    }

    if (state == AppLifecycleState.detached) {
      if (_cachedStatus == 'waiting' && _cachedIsInRoom) {
        _leaveRoom(_cachedRoomData, popAfter: false);
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _roomRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final players = _playersFrom(data['players']);
        final hostId = (data['hostId'] ?? '') as String;
        final status = (data['status'] ?? 'waiting') as String;

        final maxPlayers = (data['maxPlayers'] ?? 4) as int;
        final turnDuration = (data['turnDuration'] ?? 30) as int;
        final winningScore = (data['winningScore'] ?? 15) as int;

        final isHost = hostId == myUid && myUid.isNotEmpty;
        final isInRoom = players.any((p) => _uidOf(p) == myUid);

        // cache cho lifecycle callbacks
        _cachedRoomData = data;
        _cachedIsInRoom = isInRoom;
        _cachedStatus = status;

        // auto nav cho non-host khi host start
        _autoGoToGameIfPlaying(status, isInRoom);

        // heartbeat + cleanup (chỉ khi đang waiting và đã vào phòng)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          final shouldRunHeartbeat = status == 'waiting' && isInRoom;
          _syncHeartbeat(shouldRunHeartbeat);

          if (status == 'waiting' && isInRoom) {
            final now = _nowMs;
            final hasStale = players.any((p) => _isPlayerStale(p, now));
            final hostMissing = hostId.isNotEmpty &&
                !players
                    .any((p) => _uidOf(p) == hostId && !_isPlayerStale(p, now));
            if (hasStale || hostMissing) {
              _cleanupRoomIfNeeded();
            }
          }
        });

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            // khi đang waiting, bấm back => rời phòng trước
            if (status == 'waiting' && isInRoom) {
              await _leaveRoom(data, popAfter: true);
            } else {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0D1117),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(widget.roomName,
                  style: const TextStyle(color: Colors.white)),
              actions: [
                if (isHost && status == 'waiting')
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.amber),
                    onPressed: () {
                      SoundManager().playClick();
                      _showHostSettingsDialog(
                        currentMaxPlayers: maxPlayers,
                        currentTurnDuration: turnDuration,
                        currentWinningScore: winningScore,
                        currentPlayerCount: players.length,
                        status: status,
                      );
                    },
                    tooltip: "Host chỉnh phòng",
                  ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ROOM INFO
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Trạng thái: ${status.toUpperCase()}",
                          style: TextStyle(
                            color: status == 'waiting'
                                ? Colors.cyanAccent
                                : Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${players.length} / $maxPlayers",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // PLAYER LIST
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Người chơi trong phòng",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.separated(
                              itemCount: players.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(color: Colors.white12),
                              itemBuilder: (ctx, i) {
                                final p = players[i];
                                final uid = _uidOf(p);
                                final name = (p['name'] ?? 'Player').toString();
                                final avatar = (p['avatarUrl'] ??
                                        p['avatar'] ??
                                        p['photoURL'] ??
                                        '')
                                    .toString();
                                final isHostPlayer =
                                    (p['isHost'] ?? false) == true;
                                final isMe = uid == myUid;

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.grey[800],
                                    backgroundImage: _avatarProvider(avatar),
                                    child: null,
                                  ),
                                  title: Text(
                                    name + (isMe ? " (Bạn)" : ""),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    isHostPlayer ? "HOST" : "",
                                    style: const TextStyle(color: Colors.amber),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // SETTINGS SUMMARY
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _smallInfo(
                            "Turn", "$turnDuration s", Colors.cyanAccent),
                        _smallInfo("Win", "$winningScore", Colors.greenAccent),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // JOIN / LEAVE
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey),
                          onPressed: () {
                            SoundManager().playClick();
                            _leaveRoom(data);
                          },
                          child: const Text("Rời phòng",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isInRoom ? Colors.grey[700] : Colors.cyanAccent,
                          ),
                          onPressed: isInRoom
                              ? null
                              : () {
                                  SoundManager().playClick();
                                  _joinRoom(data);
                                },
                          child: Text(
                            isInRoom ? "Đã vào" : "Vào phòng",
                            style: TextStyle(
                                color: isInRoom ? Colors.white54 : Colors.black,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // START (HOST)
                  if (isHost)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber),
                        onPressed: () {
                          SoundManager().playClick();
                          _startGame(data);
                        },
                        child: const Text(
                          "BẮT ĐẦU (HOST)",
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.bold),
                        ),
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

  Widget _smallInfo(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
