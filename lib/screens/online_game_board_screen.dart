import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../full_game_data.dart';
import '../logic/online_game_manager.dart';
import '../managers/sound_manager.dart';
import '../models/game_entities.dart';
import '../models/online_models.dart';
import '../services/voice_service.dart';
import '../widgets/game_animations.dart';
import '../widgets/game_card_back_widget.dart';
import '../widgets/game_card_widget.dart';
import '../widgets/game_token_widget.dart';
import '../widgets/noble_widget.dart';

class OnlineGameBoardScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const OnlineGameBoardScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<OnlineGameBoardScreen> createState() => _OnlineGameBoardScreenState();
}

class _OnlineGameBoardScreenState extends State<OnlineGameBoardScreen> {
  static const Duration _presenceHeartbeatInterval = Duration(seconds: 15);

  final OnlineGameManager _gameManager = OnlineGameManager();
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  // Voice - dùng VoiceService (Platform-aware: Agora trên mobile, stub trên web)
  late final VoiceService _voiceService;
  bool _isMicOn = true;
  double _myVoiceLevel = 0.0; // 0.0 → 1.0

  // UI state
  bool isReserveMode = false;
  DevCard? _previewCard;
  bool _isShowingReservedDialog = false;
  String? _topMessage;
  Color _topMessageColor = Colors.redAccent;
  Timer? _messageTimer;
  Timer? _presenceTimer;

  // Cờ chặn thoát 2 lần gây màn hình đen
  bool _isExiting = false;
  bool _hasForcedEndTurn = false; // FIX 8
  int? _prevTurnEnd; // FIX: lưu turnEndTime cũ
  final List<Widget> _flyingAnimations = [];
  final GlobalKey _tokenBankKey = GlobalKey();
  final GlobalKey _userProfileKey = GlobalKey();
  final GlobalKey _nobleColumnKey = GlobalKey();

  // Online data
  StreamSubscription<DocumentSnapshot>? _roomSub;
  Map<String, dynamic>? _roomData;
  GameStateSnapshot? _state;

  int get _turnDurationSeconds => ((_roomData?['turnDuration']) as int?) ?? 45;

  // Map uid -> name/avatar lấy từ room.players[] để hiển thị chuẩn
  final Map<String, String> _nameById = {};
  final Map<String, String?> _avatarById = {};

  // Local selection tokens (optimistic UI)
  final List<GemType> _localSelectedTokens = [];

  // 60fps countdown (không rebuild cả StreamBuilder, chỉ rebuild UI timer)
  Timer? _clock;
  int _nowMs = DateTime.now().millisecondsSinceEpoch;
  int _serverTimeOffsetMs = 0; // serverTime - localTime

  // Card cache
  late final Map<String, DevCard> _cardById;

  @override
  void initState() {
    super.initState();
    _syncServerTime();

    _startPresenceHeartbeat();
    _cardById = {
      for (final c in [
        ...FullGameData.level1Cards,
        ...FullGameData.level2Cards,
        ...FullGameData.level3Cards
      ])
        c.id: c,
    };

    // Orientation lock chỉ áp dụng trên mobile, không áp dụng trên web
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    }

    // Khởi tạo VoiceService (Agora trên mobile, no-op trên web)
    _voiceService = createPlatformVoiceService();
    _voiceService.init(
      channelId: widget.roomId,
      myUid: myUid,
      onMessage: (msg, {bool isError = false}) {
        if (!mounted) return;
        _showTopToast(msg, color: isError ? Colors.red : Colors.green);
      },
      onVoiceLevel: (level) {
        if (!mounted) return;
        setState(() => _myVoiceLevel = level);
      },
      onJoinStatus: (joined) {
        if (!mounted) return;
        setState(() => _isMicOn = _voiceService.isMicOn);
      },
    );

    _roomSub = FirebaseFirestore.instance
        .collection('splendor_rooms')
        .doc(widget.roomId)
        .snapshots()
        .listen(_onRoomSnapshot);

    // Timer cập nhật UI mượt mà (dùng cho thanh thời gian)
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _nowMs = DateTime.now().millisecondsSinceEpoch + _serverTimeOffsetMs;
      });
    });
  }

  void _toggleMic() {
    final newMicState = !_isMicOn;
    setState(() => _isMicOn = newMicState);
    _voiceService.toggleMic(newMicState);
    if (newMicState) {
      SoundManager().duckBGM();
    } else {
      SoundManager().restoreBGM();
    }
  }

  Future<void> _syncServerTime() async {
    final ref =
        FirebaseFirestore.instance.collection('splendor_time').doc('now');

    await ref.set({
      'ts': FieldValue.serverTimestamp(),
    });

    final snap = await ref.get();
    final serverTs = (snap['ts'] as Timestamp).millisecondsSinceEpoch;
    final localTs = DateTime.now().millisecondsSinceEpoch;

    _serverTimeOffsetMs = serverTs - localTs;
  }

  void _onRoomSnapshot(DocumentSnapshot snap) {
    if (!mounted || _isExiting) return;
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;

    if (data['status'] == 'waiting') {
      _isExiting = true;
      Navigator.of(context).pop();
      return;
    }

    _roomData = data;

    _nameById.clear();
    _avatarById.clear();
    final players = (data['players'] as List?) ?? [];
    for (final p in players) {
      if (p is Map) {
        final uid = (p['uid'] ?? '').toString();
        if (uid.isEmpty) continue;
        _nameById[uid] = (p['name'] ?? 'Player').toString();
        final av = (p['avatarUrl'] ?? p['photoURL'])?.toString();
        _avatarById[uid] = (av == null || av.isEmpty) ? null : av;
      }
    }

    final gs = data['gameState'];
    if (gs == null) return;

    final nextState = GameStateSnapshot.fromJson(gs);

    if (nextState.players.indexWhere((p) => p.id == myUid) == -1) {
      _isExiting = true;
      Navigator.of(context).pop();
      return;
    }
    if (_isShowingReservedDialog && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _isShowingReservedDialog = false;
    }
    setState(() {
      _state = nextState;
      // FIX 8: reset cờ khi sang lượt mới
      if (_prevTurnEnd != nextState.turnEndTime) {
        _hasForcedEndTurn = false;
        _prevTurnEnd = nextState.turnEndTime;
      }
      // FIX 7: không reset UI khi đang mở dialog thẻ giam
      if (!_isShowingReservedDialog) {
        final isMyTurn = _isMyTurn(nextState);
        if (!isMyTurn) {
          _localSelectedTokens.clear();
          isReserveMode = false;
          _previewCard = null;
        }
      }
    });
  }

  bool _isMyTurn(GameStateSnapshot st) {
    final myIndex = st.players.indexWhere((p) => p.id == myUid);
    return myIndex != -1 && st.currentPlayerIndex == myIndex;
  }

  int _timeLeftSeconds(GameStateSnapshot st) {
    final diff = st.turnEndTime - _nowMs;
    if (diff <= 0) return 0;
    return (diff / 1000).ceil();
  }

  // Tính toán % thời gian còn lại (0.0 -> 1.0) để vẽ vòng tròn đồng bộ
  double _calculateTurnProgress(GameStateSnapshot st) {
    if (_turnDurationSeconds <= 0) return 0.0;
    final remainingMs = st.turnEndTime - _nowMs;
    final totalMs = _turnDurationSeconds * 1000;
    final progress = remainingMs / totalMs;
    return progress.clamp(0.0, 1.0);
  }

  Future<void> _confirmExitGame() async {
    final bool? shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D1117),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.amber),
          ),
          title: const Text(
            "Rời bàn chơi?",
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Bạn sẽ rời khỏi phòng.\nVán chơi vẫn tiếp tục nếu còn người.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                SoundManager().playClick();
                Navigator.pop(ctx, false);
              },
              child:
                  const Text("Ở lại", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                SoundManager().playClick();
                Navigator.pop(ctx, true);
              },
              child: const Text(
                "Rời phòng",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (shouldExit == true) {
      setState(() => _isExiting = true);
      await _gameManager.leaveGameAsNonHost(widget.roomId, myUid);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _showTopToast(String msg, {Color color = Colors.redAccent}) {
    _messageTimer?.cancel();
    setState(() {
      _topMessage = msg;
      _topMessageColor = color;
    });
    _messageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _topMessage = null);
    });
  }

  bool _checkMyTurn() {
    final st = _state;
    if (st == null) return false;
    if (!_isMyTurn(st)) {
      _showTopToast("Chưa đến lượt của bạn!", color: Colors.redAccent);
      SoundManager().playError();
      return false;
    }
    return true;
  }

  // --- Actions ---

  Map<GemType, int> _bankTokensForUI(GameStateSnapshot st) {
    return Map<GemType, int>.from(st.bankTokens);
  }

  void _selectToken(GemType type) {
    final st = _state;
    if (st == null) return;
    if (!_checkMyTurn()) return;

    if (type == GemType.gold) {
      _showTopToast("Không lấy Vàng trực tiếp! Dùng Giam thẻ.",
          color: Colors.amber);
      SoundManager().playError();
      return;
    }

    final bank = _bankTokensForUI(st);
    if ((bank[type] ?? 0) <= 0) {
      _showTopToast("Đã hết token loại này!", color: Colors.orange);
      SoundManager().playError();
      return;
    }

    if (_localSelectedTokens.isNotEmpty) {
      if (_localSelectedTokens.contains(type)) {
        if ((st.bankTokens[type] ?? 0) < 4) {
          _showTopToast("Chỉ được lấy 2 viên nếu kho còn từ 4 trở lên!",
              color: Colors.orange);
          SoundManager().playError();
          return;
        }
        if (_localSelectedTokens.length > 1) {
          _showTopToast("Không được lấy 2 viên cùng màu nếu đã chọn màu khác!",
              color: Colors.orange);
          SoundManager().playError();
          return;
        }
      } else {
        if (_localSelectedTokens.length == 2 &&
            _localSelectedTokens[0] == _localSelectedTokens[1]) {
          _showTopToast("Đã chọn 2 viên cùng màu!", color: Colors.orange);
          SoundManager().playError();
          return;
        }
        if (_localSelectedTokens.length >= 3) {
          _showTopToast("Chỉ được lấy tối đa 3 viên!", color: Colors.orange);
          SoundManager().playError();
          return;
        }
      }
    }

    SoundManager().playClick();
    setState(() {
      _localSelectedTokens.add(type);
    });
  }

  void _cancelSelection() {
    if (_localSelectedTokens.isEmpty) return;
    SoundManager().playClick();
    setState(() => _localSelectedTokens.clear());
  }

  Future<void> _confirmSelection() async {
    if (_localSelectedTokens.isEmpty) {
      _showTopToast("Chọn token trước!", color: Colors.orange);
      return;
    }
    if (!_checkMyTurn()) return;

    final tokens = List<GemType>.from(_localSelectedTokens);
    setState(() => _localSelectedTokens.clear());

    final ok = await _gameManager.playerTakeTokens(
      widget.roomId,
      myUid,
      tokens,
    );

    if (!ok) {
      _showTopToast("Không thể lấy token!", color: Colors.redAccent);
      SoundManager().playError();
      return;
    }

    _showTopToast("Đã lấy token!", color: Colors.green);

    for (int i = 0; i < tokens.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) _playTokenAnimation(tokens[i]);
      });
    }
  }

  void _onCardTap(DevCard card) {
    if (!_checkMyTurn()) return;
    SoundManager().playClick();
    setState(() => _previewCard = card);
  }

  Future<void> _confirmCardAction() async {
    final st = _state;
    if (st == null) return;
    if (_previewCard == null) return;
    if (!_checkMyTurn()) return;

    final card = _previewCard!;
    setState(() => _previewCard = null);

    if (_localSelectedTokens.isNotEmpty) {
      _cancelSelection();
    }

    if (isReserveMode) {
      final ok =
          await _gameManager.playerReserveCard(widget.roomId, myUid, card);
      if (!ok) {
        _showTopToast("Không thể giam (tối đa 3 thẻ)", color: Colors.redAccent);
      } else {
        _showTopToast("Đã giam thẻ!", color: Colors.amber);
        _playCardAnimation(card);
      }
      setState(() => isReserveMode = false);
    } else {
      final ok = await _gameManager.playerBuyCard(
        widget.roomId,
        myUid,
        card,
      );

      if (!ok) {
        _showTopToast("Không đủ tài nguyên để mua thẻ!",
            color: Colors.redAccent);
        SoundManager().playError();
        return;
      }

      _showTopToast("Đã mua thẻ cấp ${card.level}!", color: Colors.green);
      _playCardAnimation(card);
    }
  }

  // --- LOGIC GIAM TỪ CHỒNG BÀI (DECK) ---
  Future<void> _confirmReserveFromDeck(int level) async {
    if (!_checkMyTurn()) return;
    if (!isReserveMode) {
      _showTopToast("Bật chế độ Giam thẻ (ổ khóa) trước!", color: Colors.amber);
      return;
    }

    final me = _state?.players.firstWhere((p) => p.id == myUid);
    if (me != null && me.reservedCardIds.length >= 3) {
      _showTopToast("Đã giam tối đa 3 thẻ!", color: Colors.redAccent);
      SoundManager().playError();
      return;
    }

    if (_localSelectedTokens.isNotEmpty) _cancelSelection();

    final ok = await _gameManager.playerReserveFromDeck(
      widget.roomId,
      myUid,
      level,
    );

    if (!ok) {
      _showTopToast("Không thể giam thẻ!", color: Colors.redAccent);
      SoundManager().playError();
      return;
    }

    _showTopToast("Đã giam 1 thẻ từ chồng bài!", color: Colors.amber);
    setState(() => isReserveMode = false);
  }

  // --- LOGIC HIỂN THỊ THẺ ĐÃ GIAM (FIXED) ---
  String _cleanId(String id) {
    if (id.endsWith('_v')) return id.substring(0, id.length - 2);
    return id;
  }

  bool _isPublic(String id) {
    return id.endsWith('_v');
  }

  Future<void> _showReservedCardsDialog(
      BuildContext context, Player player) async {
    final bool isMe = player.id == myUid;
    final GameStateSnapshot? stateSnapshot = _state;

    SoundManager().playClick();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1117),
              borderRadius: BorderRadius.all(Radius.circular(16)),
              border: Border.fromBorderSide(
                BorderSide(color: Colors.amber, width: 2),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ===== TITLE =====
                Text(
                  isMe ? "Thẻ đã giam của BẠN" : "Thẻ đã giam: ${player.name}",
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // ===== CONTENT =====
                if (player.reservedCards.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      "Chưa có thẻ nào.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: player.reservedCards.map((card) {
                        final rawList = stateSnapshot == null
                            ? const <String>[]
                            : stateSnapshot.players
                                .firstWhere(
                                  (p) => p.id == player.id,
                                  orElse: () => stateSnapshot.players.first,
                                )
                                .reservedCardIds;

                        final String rawId = rawList.firstWhere(
                          (rid) => _cleanId(rid) == card.id,
                          orElse: () => card.id,
                        );

                        final bool isVisibleToOpponent = _isPublic(rawId);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: GestureDetector(
                            onTap: (isMe && _isMyTurn(stateSnapshot!))
                                ? () {
                                    Navigator.pop(ctx);

                                    // 🔥 FIX CHÍNH: KHÔNG setState trong build
                                    Future.microtask(() {
                                      if (!mounted) return;
                                      _onCardTap(card);
                                    });
                                  }
                                : null,
                            child: (isMe || isVisibleToOpponent)
                                ? DevCardWidget(card: card, width: 120)
                                : GameCardBackWidget(
                                    level: card.level,
                                    width: 120,
                                  ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                if (!isMe)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      "(Thẻ lấy từ chồng bài sẽ bị ẩn)",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // ===== BUTTON BAR =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // NÚT ĐÓNG (AI CŨNG CÓ)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        SoundManager().playClick();
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text(
                        "ĐÓNG",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // NÚT ĐỔI (CHỈ HIỆN VỚI CHÍNH MÌNH)
                    if (isMe) ...[
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _isMyTurn(stateSnapshot!)
                            ? null // đổi bằng tap thẻ, nút chỉ mang tính hướng dẫn
                            : null,
                        icon: const Icon(Icons.swap_horiz, color: Colors.white),
                        label: const Text(
                          "ĐỔI (chọn thẻ)",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Animations ---

  void _playTokenAnimation(GemType type) {
    final RenderBox? bankBox =
        _tokenBankKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? profileBox =
        _userProfileKey.currentContext?.findRenderObject() as RenderBox?;

    final startOffset = bankBox != null
        ? bankBox.localToGlobal(Offset.zero)
        : const Offset(100, 500);
    final endOffset = profileBox != null
        ? profileBox.localToGlobal(Offset.zero)
        : const Offset(50, 50);

    setState(() {
      _flyingAnimations.add(
        FlyingTokenAnimation(
          key: UniqueKey(),
          type: type,
          startPos: Offset(startOffset.dx + 50, startOffset.dy + 20),
          endPos: Offset(endOffset.dx + 50, endOffset.dy + 20),
          onComplete: () {
            if (!mounted) return;
            setState(() {
              if (_flyingAnimations.isNotEmpty) _flyingAnimations.removeAt(0);
            });
          },
        ),
      );
    });
  }

  void _playCardAnimation(DevCard card) {
    final Size screenSize = MediaQuery.of(context).size;
    final startPos = Offset(screenSize.width * 0.4, screenSize.height * 0.4);

    final RenderBox? profileBox =
        _userProfileKey.currentContext?.findRenderObject() as RenderBox?;
    final endPos = profileBox != null
        ? profileBox.localToGlobal(Offset.zero)
        : const Offset(50, 50);

    setState(() {
      _flyingAnimations.add(
        FlyingCardAnimation(
          key: UniqueKey(),
          startPos: startPos,
          endPos: endPos,
          child: DevCardWidget(card: card, width: 100),
          onComplete: () {
            if (!mounted) return;
            setState(() {
              if (_flyingAnimations.isNotEmpty) _flyingAnimations.removeAt(0);
            });
          },
        ),
      );
    });
  }

  // --- Helpers ---

  DevCard _card(String id) {
    final cleanId = _cleanId(id);
    return _cardById[cleanId] ?? FullGameData.level1Cards.first;
  }

  Noble _noble(String id) {
    return FullGameData.nobles
        .firstWhere((n) => n.id == id, orElse: () => FullGameData.nobles.first);
  }

  Player _toPlayerUI(OnlinePlayerState p, {required bool isTurn}) {
    final isMe = p.id == myUid;
    return Player(
      id: p.id,
      name: isMe ? "BẠN" : (_nameById[p.id] ?? p.name),
      color: isMe ? Colors.amber : Colors.blueGrey,
      isHuman: isMe,
      isTurn: isTurn,
      score: p.score,
      tokens: p.tokens,
      bonuses: p.bonuses,
      nobles: p.nobleIds.map(_noble).toList(),
      reservedCards: p.reservedCardIds.map(_card).toList(),
      purchasedCards: p.purchasedCardIds.map(_card).toList(),
    );
  }

  ImageProvider _avatarOf(String uid) {
    final url = _avatarById[uid];
    if (url == null || url.isEmpty) {
      return const AssetImage('assets/avatars/meme_1.png');
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return AssetImage(url);
  }

  void _startPresenceHeartbeat() {
    _presenceTimer ??= Timer.periodic(
        _presenceHeartbeatInterval, (_) => _presenceHeartbeatTick());
  }

  Future<void> _presenceHeartbeatTick() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    await _gameManager.heartbeatAndMaintainPlayingRoom(
      widget.roomId,
      uid: uid,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _clock?.cancel();
    _presenceTimer?.cancel();
    _roomSub?.cancel();
    _voiceService.dispose(); // fire and forget — dispose() can't be async
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  // --- Widget Nút Xem Thẻ Giam (Thẻ Vàng) ---
  // [FIX] Đưa hàm này vào trong class State để truy cập context
  Widget _buildReservedDeckButton(Player player, {bool isVertical = false}) {
    return GestureDetector(
      onTap: () {
        if (_isShowingReservedDialog) return;

        _isShowingReservedDialog = true;
        SoundManager().playClick();

        _showReservedCardsDialog(context, player).whenComplete(() {
          if (mounted) {
            _isShowingReservedDialog = false;
          }
        });
      },
      child: Container(
        margin: isVertical
            ? const EdgeInsets.only(top: 4)
            : const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.yellowAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: Colors.yellowAccent.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.yellowAccent.withValues(alpha: 0.2),
              blurRadius: 4,
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, color: Colors.yellowAccent, size: 10),
            const SizedBox(width: 2),
            Text(
              "${player.reservedCards.length}/3",
              style: const TextStyle(
                  color: Colors.yellowAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widget: Avatar có viền timer đồng bộ ---
  Widget _buildAvatarWithTimer({
    required Player player,
    required double radius,
    required ImageProvider avatar,
  }) {
    final progress =
        player.isTurn && _state != null ? _calculateTurnProgress(_state!) : 0.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Avatar
        CircleAvatar(
          radius: radius,
          backgroundColor: player.color,
          backgroundImage: avatar,
        ),
        // Timer ring (chỉ hiện khi đến lượt)
        if (player.isTurn)
          SizedBox(
            width: radius * 2 + 6,
            height: radius * 2 + 6,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress < 0.2
                    ? Colors.red
                    : (progress < 0.5 ? Colors.amber : Colors.green),
              ),
            ),
          ),
      ],
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final st = _state;
    if (st == null || _roomData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    // Winner
    if (st.winnerId != null) {
      final winnerOnline = st.players.firstWhere((p) => p.id == st.winnerId,
          orElse: () => st.players.first);
      return _buildVictoryScreen(_toPlayerUI(winnerOnline, isTurn: false));
    }

    // My turn / timer
    final myIndex = st.players.indexWhere((p) => p.id == myUid);
    final isMyTurn = myIndex != -1 && st.currentPlayerIndex == myIndex;
    final timeLeft = _timeLeftSeconds(st);

    // Timeout handling (FIX 8)
    if (timeLeft <= 0 && !_hasForcedEndTurn) {
      _hasForcedEndTurn = true;
      _gameManager.forceEndTurn(widget.roomId);
    }

    // Display order
    final others = <OnlinePlayerState>[];
    for (int i = 1; i < st.players.length; i++) {
      final idx = (myIndex + i) % st.players.length;
      if (idx >= 0 && idx < st.players.length) others.add(st.players[idx]);
    }

    // Map layout
    Player? botLeft;
    Player? botRight;
    List<Player> topBots = [];

    if (others.length == 1) {
      topBots = [
        _toPlayerUI(others[0],
            isTurn: st.currentPlayerIndex == (myIndex + 1) % st.players.length)
      ];
    } else if (others.length == 2) {
      botLeft = _toPlayerUI(others[0],
          isTurn: st.currentPlayerIndex == (myIndex + 1) % st.players.length);
      botRight = _toPlayerUI(others[1],
          isTurn: st.currentPlayerIndex == (myIndex + 2) % st.players.length);
    } else if (others.length == 3) {
      botLeft = _toPlayerUI(others[0],
          isTurn: st.currentPlayerIndex == (myIndex + 1) % st.players.length);
      topBots = [
        _toPlayerUI(others[1],
            isTurn: st.currentPlayerIndex == (myIndex + 2) % st.players.length)
      ];
      botRight = _toPlayerUI(others[2],
          isTurn: st.currentPlayerIndex == (myIndex + 3) % st.players.length);
    } else if (others.length == 4) {
      botLeft = _toPlayerUI(others[0],
          isTurn: st.currentPlayerIndex == (myIndex + 1) % st.players.length);
      topBots = [
        _toPlayerUI(others[1],
            isTurn: st.currentPlayerIndex == (myIndex + 2) % st.players.length),
        _toPlayerUI(others[2],
            isTurn: st.currentPlayerIndex == (myIndex + 3) % st.players.length),
      ];
      botRight = _toPlayerUI(others[3],
          isTurn: st.currentPlayerIndex == (myIndex + 4) % st.players.length);
    } else if (others.length >= 5) {
      botLeft = _toPlayerUI(others[0],
          isTurn: st.currentPlayerIndex == (myIndex + 1) % st.players.length);
      topBots = List.generate(
        max(0, others.length - 2),
        (i) {
          final online = others[i + 1];
          final idx = (myIndex + i + 2) % st.players.length;
          return _toPlayerUI(online, isTurn: st.currentPlayerIndex == idx);
        },
      );
      botRight = _toPlayerUI(others.last,
          isTurn: st.currentPlayerIndex ==
              (myIndex + others.length) % st.players.length);
    }

    final meUI = _toPlayerUI(st.players[myIndex], isTurn: isMyTurn);

    final bankForUI = _bankTokensForUI(st);

    final v1 = st.visibleLevel1.map(_card).toList();
    final v2 = st.visibleLevel2.map(_card).toList();
    final v3 = st.visibleLevel3.map(_card).toList();
    final nobles = st.visibleNobles.map(_noble).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confirmExitGame();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 0),
              radius: 1.2,
              colors: [Color(0xFF16213E), Color(0xFF000000)],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenHeight = constraints.maxHeight;

                // V1 FIX: adaptive height cho TopPlayers
                // 0 người: 0px, 1-2 người: 18%, 3-4 người: 22%
                final double topRatio =
                    topBots.isEmpty ? 0.0 : (topBots.length <= 2 ? 0.18 : 0.22);
                final double topH = screenHeight * topRatio;
                // V7 FIX: bottom bar tối thiểu 60px
                final double botH = max(screenHeight * 0.15, 60.0);
                // Board lấy phần còn lại
                final double boardH = screenHeight - topH - botH;

                return Stack(
                  children: [
                    Column(
                      children: [
                        if (topBots.isNotEmpty)
                          SizedBox(
                              height: topH, child: _buildTopPlayers(topBots)),
                        Expanded(
                            child: _buildGameBoard(
                                botLeft, botRight, boardH, v1, v2, v3, nobles)),
                        SizedBox(
                            height: botH,
                            child: _buildBottomBar(
                                meUI, botH, bankForUI, isMyTurn, timeLeft)),
                      ],
                    ),
                    // V5/V6 FIX: Overlay top - Timer trái, Mic+Thoát phải, Toast ở giữa row thứ hai
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _toggleMic,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !_isMicOn
                                      ? Colors.white24
                                      : Color.lerp(
                                          Colors.white24,
                                          Colors.greenAccent,
                                          _myVoiceLevel,
                                        )!,
                                  width: 1 + _myVoiceLevel * 2,
                                ),
                                boxShadow: _isMicOn && _myVoiceLevel > 0.1
                                    ? [
                                        BoxShadow(
                                          color: Colors.greenAccent.withValues(
                                              alpha:
                                                  (0.3 + _myVoiceLevel * 0.4)),
                                          blurRadius: 4 + _myVoiceLevel * 8,
                                          spreadRadius: _myVoiceLevel * 4,
                                        )
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isMicOn ? Icons.mic : Icons.mic_off,
                                    size: 14,
                                    color: !_isMicOn
                                        ? Colors.grey
                                        : Color.lerp(
                                            Colors.white,
                                            Colors.greenAccent,
                                            _myVoiceLevel,
                                          ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isMicOn ? "Mic" : "Mute",
                                    style: TextStyle(
                                      color: !_isMicOn
                                          ? Colors.grey
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _confirmExitGame,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.exit_to_app,
                                      color: Colors.redAccent, size: 14),
                                  SizedBox(width: 4),
                                  Text("Thoát",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Timer — góc trái, cùng hàng với Mic/Thoát
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: timeLeft <= 5
                                ? Colors.redAccent
                                : Colors.white24,
                            width: timeLeft <= 5 ? 1.5 : 1.0,
                          ),
                        ),
                        child: Text(
                          "⏳ $timeLeft s",
                          style: TextStyle(
                            color:
                                timeLeft <= 5 ? Colors.redAccent : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    // Toast message — hàng thứ 2 (top: 42) để không đè lên timer/mic
                    if (_topMessage != null)
                      Positioned(
                        top: 42,
                        left: 60,
                        right: 60,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: _topMessageColor.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Text(
                              _topMessage!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    if (isReserveMode && _previewCard == null)
                      Positioned(
                        top: 60,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text("ĐANG CHỌN THẺ ĐỂ GIAM",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                          ),
                        ),
                      ),
                    ..._flyingAnimations,
                    if (_previewCard != null)
                      Container(
                        color: Colors.black.withValues(alpha: 0.85),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isReserveMode
                                    ? "XÁC NHẬN GIAM?"
                                    : "XÁC NHẬN MUA?",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold),
                              ),
                              if (isReserveMode)
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text("(Nhận +1 Vàng)",
                                      style: TextStyle(color: Colors.amber)),
                                ),
                              const SizedBox(height: 30),
                              Transform.scale(
                                  scale: 1.5,
                                  child: DevCardWidget(
                                      card: _previewCard!, width: 100)),
                              const SizedBox(height: 60),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 15)),
                                    onPressed: () {
                                      SoundManager().playClick();
                                      setState(() => _previewCard = null);
                                    },
                                    icon: const Icon(Icons.close),
                                    label: const Text("HỦY"),
                                  ),
                                  const SizedBox(width: 40),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 15)),
                                    onPressed: _confirmCardAction,
                                    icon: const Icon(Icons.check),
                                    label: const Text("ĐỒNG Ý"),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVictoryScreen(Player winner) {
    final bool isHost = (_roomData?['hostId'] ?? '') == myUid;

    SoundManager().stopBGM();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // ⛔ ÉP BACK → THOÁT GAME + GIẢI PHÓNG MIC
        try {
          await _voiceService.dispose();
        } catch (_) {}
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "CHIẾN THẮNG",
                style: TextStyle(
                  fontSize: 36,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              CircleAvatar(
                radius: 48,
                backgroundImage: _avatarOf(winner.id),
              ),
              const SizedBox(height: 16),

              Text(
                winner.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "⭐ ${winner.score} điểm",
                style: const TextStyle(color: Colors.amber, fontSize: 18),
              ),

              const SizedBox(height: 40),

              // ===== BUTTONS =====
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // TRỞ LẠI PHÒNG
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                    onPressed: () async {
                      SoundManager().playClick();
                      setState(() => _isExiting = true);

                      // Giải phóng Voice Chat
                      await _voiceService.dispose();

                      if (isHost) {
                        await _gameManager.endGameNormally(widget.roomId);
                      } else {
                        await _gameManager.leaveGameAsNonHost(
                            widget.roomId, myUid);
                      }

                      if (mounted) Navigator.pop(context);
                      SoundManager().playBGM();
                    },
                    child: const Text(
                      "TRỞ LẠI PHÒNG",
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // THOÁT
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                    onPressed: () async {
                      SoundManager().playClick();

                      // Giải phóng Voice Chat
                      await _voiceService.dispose();

                      SystemNavigator.pop();
                    },
                    child: const Text(
                      "THOÁT",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Board pieces (copy from training) ---

  Widget _buildTopPlayers(List<Player> topBots) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: topBots
            .map((bot) =>
                Expanded(child: Center(child: _buildCompactPlayerProfile(bot))))
            .toList(),
      ),
    );
  }

  Widget _buildGameBoard(
      Player? botLeft,
      Player? botRight,
      double boardHeight,
      List<DevCard> v1,
      List<DevCard> v2,
      List<DevCard> v3,
      List<Noble> nobles) {
    // V2 FIX: tăng rộng cột side khi có ít nhất 1 người 2 cạnh
    final bool hasBothSides = botLeft != null && botRight != null;
    final double sideW = hasBothSides ? 100.0 : 95.0;
    return Row(
      children: [
        SizedBox(
            width: sideW,
            child: botLeft != null
                ? Center(child: _buildVerticalPlayerProfile(botLeft))
                : null),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Expanded(
                    flex: 72, child: _buildCardMatrix(boardHeight, v1, v2, v3)),
                const SizedBox(width: 4),
                Expanded(
                    flex: 28,
                    child: Container(
                        key: _nobleColumnKey,
                        child: _buildNobleColumn(boardHeight, nobles))),
              ],
            ),
          ),
        ),
        SizedBox(
            width: sideW,
            child: botRight != null
                ? Center(child: _buildVerticalPlayerProfile(botRight))
                : null),
      ],
    );
  }

  Widget _buildBottomBar(Player user, double barHeight,
      Map<GemType, int> bankTokens, bool isMyTurn, int timeLeft) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          Expanded(
              flex: 40,
              child: Container(
                  key: _userProfileKey,
                  child: _buildUserProfile(user, barHeight))),
          Container(
              width: 1,
              color: Colors.white24,
              margin: const EdgeInsets.symmetric(vertical: 4)),
          const SizedBox(width: 4),
          Expanded(
            flex: 60,
            child: Row(
              children: [
                Expanded(child: _buildTokenBank(barHeight, bankTokens)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (!_checkMyTurn()) return;
                    if (user.reservedCards.length >= 3) {
                      _showTopToast("Đã giam tối đa 3 thẻ!",
                          color: Colors.redAccent);
                      SoundManager().playError();
                      return;
                    }
                    SoundManager().playClick();
                    setState(() {
                      if (_localSelectedTokens.isNotEmpty) _cancelSelection();
                      isReserveMode = !isReserveMode;
                    });
                  },
                  child: Container(
                    width: barHeight * 0.7,
                    height: barHeight * 0.7,
                    decoration: BoxDecoration(
                      color: isReserveMode ? Colors.amber : Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber, width: 2),
                      boxShadow: isReserveMode
                          ? [
                              const BoxShadow(
                                  color: Colors.amber, blurRadius: 10)
                            ]
                          : null,
                    ),
                    child: Icon(isReserveMode ? Icons.lock_open : Icons.lock,
                        color: isReserveMode ? Colors.black : Colors.amber),
                  ),
                ),
                if (_localSelectedTokens.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _cancelSelection,
                    child: Container(
                      width: barHeight * 0.7,
                      height: barHeight * 0.7,
                      decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5)),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _confirmSelection,
                    child: Container(
                      width: barHeight * 0.7,
                      height: barHeight * 0.7,
                      decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5)),
                      child: const Icon(Icons.check, color: Colors.white),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenBank(double height, Map<GemType, int> bankTokens) {
    List<GemType> order = [
      GemType.gold,
      GemType.white,
      GemType.blue,
      GemType.green,
      GemType.red,
      GemType.black
    ];
    double tokenSize = height * 0.75;

    return ListView.builder(
      key: _tokenBankKey,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: order.length,
      itemBuilder: (context, index) {
        final type = order[index];
        final selectedCount =
            _localSelectedTokens.where((t) => t == type).length;
        final isSelected = selectedCount > 0;
        final isGold = type == GemType.gold;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: isSelected
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 10,
                                spreadRadius: 1)
                          ],
                          border: Border.all(color: Colors.white, width: 2),
                        )
                      : null,
                  child: GameTokenWidget(
                    type: type,
                    count: bankTokens[type] ?? 0,
                    size: tokenSize,
                    onTap: () {
                      if (isGold) {
                        _showTopToast("Dùng nút ổ khóa để Giam thẻ & Lấy vàng!",
                            color: Colors.amber);
                        SoundManager().playError();
                      } else {
                        if (isReserveMode) {
                          setState(() => isReserveMode = false);
                        }
                        _selectToken(type);
                      }
                    },
                  ),
                ),
                if (selectedCount > 1)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: Text("x$selectedCount",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10)),
                    ),
                  ),
                if (selectedCount == 1)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Colors.green, shape: BoxShape.circle),
                      child: const Icon(Icons.check,
                          size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardMatrix(double availableHeight, List<DevCard> v1,
      List<DevCard> v2, List<DevCard> v3) {
    double rowHeight = availableHeight / 3;
    double cardWidth = rowHeight * 0.71;

    return FittedBox(
      fit: BoxFit.contain,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCardRow(3, v3, cardWidth, rowHeight * 0.9),
          _buildCardRow(2, v2, cardWidth, rowHeight * 0.9),
          _buildCardRow(1, v1, cardWidth, rowHeight * 0.9),
        ],
      ),
    );
  }

  Widget _buildCardRow(
      int level, List<DevCard> cards, double width, double height) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thêm GestureDetector cho phép giam từ chồng bài
          GestureDetector(
            onTap: () => _confirmReserveFromDeck(level),
            child: isReserveMode
                ? Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: 1)
                      ],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber, width: 2),
                    ),
                    child: GameCardBackWidget(level: level, width: width))
                : GameCardBackWidget(level: level, width: width),
          ),
          const SizedBox(width: 8),
          ...cards.map((card) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => _onCardTap(card),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  transitionBuilder: (child, animation) {
                    final offsetAnimation = Tween<Offset>(
                            begin: const Offset(-1.0, 0.0), end: Offset.zero)
                        .animate(
                      CurvedAnimation(
                          parent: animation, curve: Curves.easeInOut),
                    );
                    return SlideTransition(
                        position: offsetAnimation, child: child);
                  },
                  child: Container(
                    key: ValueKey(card.id),
                    decoration: isReserveMode
                        ? BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  spreadRadius: 1)
                            ],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber, width: 2),
                          )
                        : null,
                    child: DevCardWidget(card: card, width: width),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNobleColumn(double availableHeight, List<Noble> nobles) {
    // V4 FIX: thu nhỏ noble size khi có nhiều noble (6 người = 7 nobles)
    final int count = nobles.length;
    double nobleSize;
    if (count <= 4) {
      nobleSize = min(availableHeight / 3.5, 60.0);
    } else if (count <= 6) {
      nobleSize = min(availableHeight / 4.5, 52.0);
    } else {
      nobleSize = min(availableHeight / 5.5, 46.0);
    }
    return Center(
      child: SingleChildScrollView(
        child: Wrap(
          direction: Axis.horizontal,
          alignment: WrapAlignment.center,
          runSpacing: 3,
          spacing: 3,
          children: nobles
              .map((n) => NobleWidget(noble: n, size: nobleSize))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCompactPlayerProfile(Player player) {
    final avatar = _avatarOf(player.id);
    // Rút gọn tên cho hàng top (tối đa 8 ký tự)
    final displayName = player.name.length > 8
        ? '${player.name.substring(0, 7)}…'
        : player.name;

    return GestureDetector(
      onLongPress: () {
        // Hint: long press mở tooltip to hiển thị thông tin đầy đủ
        showDialog(
          context: context,
          barrierColor: Colors.black54,
          builder: (ctx) => Dialog(
            backgroundColor: const Color(0xFF0D1117),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: player.color, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 32, backgroundImage: avatar),
                  const SizedBox(height: 8),
                  Text(player.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text("${player.score} VP",
                      style:
                          const TextStyle(color: Colors.amber, fontSize: 14)),
                  const SizedBox(height: 12),
                  const Text("Token",
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  _buildGridAssets(player.tokens, isChip: true),
                  const SizedBox(height: 8),
                  const Text("Đá thưởng (Bonus)",
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  _buildGridAssets(player.bonuses, isChip: false),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Đóng",
                        style: TextStyle(color: Colors.amber)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: player.isTurn
                ? player.color.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: player.isTurn
                  ? player.color.withValues(alpha: 0.8)
                  : player.color.withValues(alpha: 0.25),
              width: player.isTurn ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAvatarWithTimer(player: player, radius: 11, avatar: avatar),
              const SizedBox(width: 5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  Text("⭐${player.score}",
                      style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 5),
              Column(
                children: [
                  _buildMiniStatsRow(player.tokens, isChip: true),
                  const SizedBox(height: 2),
                  Container(height: 1, width: 28, color: Colors.white12),
                  const SizedBox(height: 2),
                  _buildMiniStatsRow(player.bonuses, isChip: false),
                ],
              ),
              if (player.nobleCount > 0) ...[
                const SizedBox(width: 3),
                _buildNobleIndicator(player.nobleCount, isVertical: false)
              ],
              const SizedBox(width: 3),
              _buildReservedDeckButton(player, isVertical: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalPlayerProfile(Player player) {
    final avatar = _avatarOf(player.id);
    // Rút gọn tên cho cột dọc (tối đa 9 ký tự)
    final displayName = player.name.length > 9
        ? '${player.name.substring(0, 8)}…'
        : player.name;

    return GestureDetector(
      onLongPress: () {
        // Long press hiển thị popup đầy đủ
        showDialog(
          context: context,
          barrierColor: Colors.black54,
          builder: (ctx) => Dialog(
            backgroundColor: const Color(0xFF0D1117),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: player.color, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 32, backgroundImage: avatar),
                  const SizedBox(height: 8),
                  Text(player.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text("${player.score} VP",
                      style:
                          const TextStyle(color: Colors.amber, fontSize: 14)),
                  const SizedBox(height: 12),
                  const Text("Token",
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  _buildGridAssets(player.tokens, isChip: true),
                  const SizedBox(height: 8),
                  const Text("Đá thưởng (Bonus)",
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  _buildGridAssets(player.bonuses, isChip: false),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Đóng",
                        style: TextStyle(color: Colors.amber)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          width: 100,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: player.isTurn
                ? player.color.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: player.isTurn
                  ? player.color.withValues(alpha: 0.8)
                  : player.color.withValues(alpha: 0.25),
              width: player.isTurn ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              _buildAvatarWithTimer(player: player, radius: 16, avatar: avatar),
              const SizedBox(height: 2),
              Text(displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: player.isTurn ? Colors.amber : Colors.white,
                    fontSize: 11,
                    fontWeight:
                        player.isTurn ? FontWeight.bold : FontWeight.normal,
                  )),
              Text("⭐ ${player.score} VP",
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight:
                        player.isTurn ? FontWeight.bold : FontWeight.normal,
                  )),
              const SizedBox(height: 4),
              const Text("Token",
                  style: TextStyle(color: Colors.white38, fontSize: 8)),
              _buildGridAssets(player.tokens, isChip: true),
              const SizedBox(height: 3),
              Container(width: 40, height: 1, color: Colors.white12),
              const SizedBox(height: 3),
              const Text("Bonus",
                  style: TextStyle(color: Colors.white38, fontSize: 8)),
              _buildGridAssets(player.bonuses, isChip: false),
              _buildNobleIndicator(player.nobleCount, isVertical: true),
              const SizedBox(height: 3),
              _buildReservedDeckButton(player, isVertical: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridAssets(Map<GemType, int> data, {required bool isChip}) {
    List<GemType> order = [
      GemType.white,
      GemType.blue,
      GemType.green,
      GemType.red,
      GemType.black
    ];
    if (isChip) order.add(GemType.gold);

    return Wrap(
      spacing: 2,
      runSpacing: 2,
      alignment: WrapAlignment.center,
      children: order.map((type) {
        int val = data[type] ?? 0;
        Widget item = Container(
          width: 22,
          height: isChip ? 22 : 26,
          decoration: BoxDecoration(
            color: _getGemColor(type),
            shape: isChip ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isChip ? null : BorderRadius.circular(3),
          ),
          child: Center(
            child: Text(
              "$val",
              style: TextStyle(
                  fontSize: 10,
                  color: _getTextColor(type),
                  fontWeight: FontWeight.bold),
            ),
          ),
        );
        return Opacity(opacity: val > 0 ? 1 : 0.3, child: item);
      }).toList(),
    );
  }

  Widget _buildUserProfile(Player user, double height) {
    final avatar = _avatarOf(user.id);

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          _buildAvatarWithTimer(
              player: user, radius: height * 0.22, avatar: avatar),
          const SizedBox(width: 8),
          Column(
            children: [
              const Text("BẠN",
                  style: TextStyle(
                      color: Colors.amber, fontWeight: FontWeight.bold)),
              Text("${user.score} VP",
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(width: 15),
          _buildUserAssetRow(user, user.bonuses, isChip: false),
          Container(
              width: 1,
              height: height * 0.6,
              color: Colors.white24,
              margin: const EdgeInsets.symmetric(horizontal: 8)),
          _buildUserAssetRow(user, user.tokens, isChip: true),
          _buildNobleIndicator(user.nobleCount, isVertical: false),

          // THAY THẾ KHU VỰC LOCK CŨ BẰNG NÚT THẺ VÀNG MỚI
          const SizedBox(width: 8),
          _buildReservedDeckButton(user, isVertical: false),
        ],
      ),
    );
  }

  Widget _buildNobleIndicator(int count, {bool isVertical = false}) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      margin: isVertical
          ? const EdgeInsets.only(top: 4)
          : const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.amber),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 1)
            Text("x$count",
                style: const TextStyle(
                    fontSize: 9,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold)),
          if (count > 1) const SizedBox(width: 2),
          const Text("👑", style: TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMiniStatsRow(Map<GemType, int> data, {required bool isChip}) {
    List<GemType> order = [
      GemType.white,
      GemType.blue,
      GemType.green,
      GemType.red,
      GemType.black,
      GemType.gold
    ];
    if (!isChip) order.removeLast();
    return Wrap(
      spacing: 1,
      runSpacing: 1,
      children: order
          .map((type) => _buildStatItem(type, data[type] ?? 0, isChip))
          .toList(),
    );
  }

  Widget _buildStatItem(GemType type, int val, bool isChip) {
    // V3 FIX: Luôn hiển thị placeholder để layout không bị nhảy khi val=0
    return Opacity(
      opacity: val > 0 ? 1.0 : 0.18,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _getGemColor(type),
          shape: isChip ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isChip ? null : BorderRadius.circular(2),
        ),
        child: Center(
          child: Text(
            "$val",
            style: TextStyle(
                fontSize: 7,
                color: _getTextColor(type),
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildUserAssetRow(Player player, Map<GemType, int> data,
      {required bool isChip}) {
    List<GemType> order = [
      GemType.white,
      GemType.blue,
      GemType.green,
      GemType.red,
      GemType.black
    ];
    if (isChip) order.add(GemType.gold);

    return Row(
      children: order.map((type) {
        int val = data[type] ?? 0;
        Widget item = Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 16,
          height: isChip ? 16 : 20,
          decoration: BoxDecoration(
            color: _getGemColor(type),
            shape: isChip ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isChip ? null : BorderRadius.circular(2),
          ),
          child: Center(
            child: Text(
              "$val",
              style: TextStyle(
                  fontSize: 9,
                  color: _getTextColor(type),
                  fontWeight: FontWeight.bold),
            ),
          ),
        );
        return Opacity(opacity: val > 0 ? 1 : 0.3, child: item);
      }).toList(),
    );
  }

  Color _getGemColor(GemType type) {
    switch (type) {
      case GemType.red:
        return Colors.redAccent;
      case GemType.blue:
        return Colors.lightBlueAccent;
      case GemType.green:
        return Colors.greenAccent;
      case GemType.black:
        return const Color(0xFF424242);
      case GemType.white:
        return Colors.white;
      case GemType.gold:
        return Colors.amberAccent;
    }
  }

  Color _getTextColor(GemType type) {
    return (type == GemType.white ||
            type == GemType.gold ||
            type == GemType.green ||
            type == GemType.blue)
        ? Colors.black
        : Colors.white;
  }
}
