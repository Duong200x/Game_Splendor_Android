import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../full_game_data.dart';
import '../managers/sound_manager.dart';
import '../models.dart';
import '../models/game_entities.dart';
import '../models/online_models.dart';

class OnlineGameManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================
  // ROOM LIFECYCLE HELPERS
  // =========================

  int _getSessionId(Map<String, dynamic> roomData) {
    final v = roomData['sessionId'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  int _lastSeenOf(Map<String, dynamic> p) {
    final v = p['lastSeen'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  int _joinAtOf(Map<String, dynamic> p) {
    final v = p['joinAt'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  String _uidOf(Map<String, dynamic> p) => (p['uid'] ?? '').toString();

  List<Map<String, dynamic>> _playersFrom(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from((e as Map))).toList();
    }
    return <Map<String, dynamic>>[];
  }

  bool _isStale(Map<String, dynamic> p, int nowMs, int staleMs) {
    final last = _lastSeenOf(p);
    if (last <= 0) return false; // thiếu lastSeen => không tự kick
    return (nowMs - last) > staleMs;
  }

  String _pickHostId(List<Map<String, dynamic>> players) {
    if (players.isEmpty) return '';
    players.sort((a, b) {
      final ja = _joinAtOf(a);
      final jb = _joinAtOf(b);
      if (ja != jb) return ja.compareTo(jb);
      return _uidOf(a).compareTo(_uidOf(b));
    });
    return _uidOf(players.first);
  }

  List<Map<String, dynamic>> _rebuildHostFlags(
      List<Map<String, dynamic>> players, String hostId) {
    return players
        .map((p) => {
              ...p,
              'isHost': _uidOf(p) == hostId,
            })
        .toList();
  }

  Future<void> _resetRoomToWaiting(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> roomRef,
    Map<String, dynamic> roomData, {
    required bool clearPlayers,
    String endedReason = '',
    bool keepHostPresence = false,
    Map<String, dynamic>? hostPresence,
  }) async {
    final int sessionId = _getSessionId(roomData) + 1;

    final update = <String, dynamic>{
      'status': 'waiting',
      'sessionId': sessionId,
      'endedReason': endedReason,
      'endedAt': endedReason.isEmpty
          ? FieldValue.delete()
          : FieldValue.serverTimestamp(),
      'gameState': FieldValue.delete(),
      'decks': FieldValue.delete(),
      'winnerId': FieldValue.delete(),
    };

    if (clearPlayers) {
      update['hostId'] = '';
      update['players'] = [];
    } else if (keepHostPresence && hostPresence != null) {
      final hostId = _uidOf(hostPresence);
      update['hostId'] = hostId;
      update['players'] = [
        {
          ...hostPresence,
          'score': 0,
          'tokens': {for (var g in GemType.values) gemToString(g): 0},
          'bonuses': {for (var g in GemType.values) gemToString(g): 0},
          'purchasedCardIds': [],
          'reservedCardIds': [],
          'nobleIds': [],
        }
      ];
    } else {
      final players = _playersFrom(roomData['players']);
      final hostId = roomData['hostId']?.toString() ?? _pickHostId(players);

      update['hostId'] = hostId;
      update['players'] = _rebuildHostFlags(players, hostId);
    }
    tx.update(roomRef, update);
  }

  // Kết thúc ván do host rời / host stale: đá toàn bộ client khỏi phòng.
  Future<void> endGameHostLeft(String roomId) async {
    final roomRef =
        _firestore.collection(AppConstants.collectionRooms).doc(roomId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(roomRef);
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};
      await _resetRoomToWaiting(
        tx,
        roomRef,
        data,
        clearPlayers: true,
        endedReason: 'host_left',
      );
    });
  }

  Future<void> endGameNormally(String roomId) async {
    final roomRef =
        _firestore.collection(AppConstants.collectionRooms).doc(roomId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(roomRef);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;

      // giữ host, reset toàn bộ game
      final players = _playersFrom(data['players']);
      if (players.isEmpty) {
        await _resetRoomToWaiting(
          tx,
          roomRef,
          data,
          clearPlayers: true,
          endedReason: 'finished',
        );
        return;
      }

      final hostId = (data['hostId'] ?? '').toString();
      final hostPresence = players.firstWhere(
        (p) => _uidOf(p) == hostId,
        orElse: () => players.first,
      );

      await _resetRoomToWaiting(
        tx,
        roomRef,
        data,
        clearPlayers: false,
        endedReason: 'finished',
        keepHostPresence: true,
        hostPresence: hostPresence,
      );
    });
  }

  // Non-host rời khi đang chơi: xoá presence + loại khỏi gameState để ván không kẹt lượt.
  Future<void> leaveGameAsNonHost(String roomId, String uid) async {
    final roomRef =
        _firestore.collection(AppConstants.collectionRooms).doc(roomId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(roomRef);
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};
      final status = (data['status'] ?? 'waiting').toString();
      final hostId = (data['hostId'] ?? '').toString();

      // host leave -> end game
      if (uid.isNotEmpty && uid == hostId) {
        await _resetRoomToWaiting(tx, roomRef, data,
            clearPlayers: true, endedReason: 'host_left');
        return;
      }

      // waiting: remove presence + host inheritance
      if (status != 'playing') {
        final players = _playersFrom(data['players'])
            .where((p) => _uidOf(p) != uid)
            .toList();
        if (players.isEmpty) {
          await _resetRoomToWaiting(tx, roomRef, data,
              clearPlayers: true, endedReason: '');
          return;
        }
        String newHostId = hostId;
        if (newHostId.isEmpty || !players.any((p) => _uidOf(p) == newHostId)) {
          newHostId = _pickHostId(players);
        }
        tx.update(roomRef, {
          'hostId': newHostId,
          'players': _rebuildHostFlags(players, newHostId),
        });
        return;
      }

      // playing
      final List<Map<String, dynamic>> playersPresence =
          _playersFrom(data['players']).where((p) => _uidOf(p) != uid).toList();

      final gameStateRaw = data['gameState'];
      if (gameStateRaw is! Map<String, dynamic>) {
        await _resetRoomToWaiting(tx, roomRef, data,
            clearPlayers: true, endedReason: '');
        return;
      }

      final st = GameStateSnapshot.fromJson(gameStateRaw);
      final removedIdx = st.players.indexWhere((p) => p.id == uid);
      if (removedIdx >= 0) {
        st.players.removeAt(removedIdx);
        if (st.players.isEmpty) {
          await _resetRoomToWaiting(tx, roomRef, data,
              clearPlayers: true, endedReason: '');
          return;
        }

        if (removedIdx < st.currentPlayerIndex) {
          st.currentPlayerIndex -= 1;
        } else if (removedIdx == st.currentPlayerIndex) {
          if (st.currentPlayerIndex >= st.players.length) {
            st.currentPlayerIndex = 0;
          }
        }

        // chỉ còn host => end ván, host về waiting (giữ host presence)
        if (st.players.length == 1 && st.players.first.id == hostId) {
          final hostPresence = playersPresence.firstWhere(
            (p) => _uidOf(p) == hostId,
            orElse: () => <String, dynamic>{
              'uid': hostId,
              'name': st.players.first.name,
              'avatarUrl': st.players.first.avatarUrl,
              'joinAt': _nowMs(),
              'lastSeen': _nowMs(),
              'isHost': true,
            },
          );
          await _resetRoomToWaiting(
            tx,
            roomRef,
            data,
            clearPlayers: false,
            endedReason: 'all_left',
            keepHostPresence: true,
            hostPresence: hostPresence,
          );
          return;
        }

        final int turnDuration = (data['turnDuration'] ?? 45) is num
            ? (data['turnDuration'] as num).toInt()
            : 45;
        st.turnEndTime =
            DateTime.now().millisecondsSinceEpoch + (turnDuration * 1000);
      }

      tx.update(roomRef, {
        'players': _rebuildHostFlags(playersPresence, hostId),
        'gameState': st.toJson(),
      });
    });
  }

  // Dùng trong OnlineGameBoardScreen: heartbeat + kick stale + host stale => end game.
  Future<void> heartbeatAndMaintainPlayingRoom(
    String roomId, {
    required String uid,
    required int nowMs,
    int staleMs = 45000,
  }) async {
    if (uid.isEmpty) return;

    final roomRef =
        _firestore.collection(AppConstants.collectionRooms).doc(roomId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(roomRef);
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};
      final status = (data['status'] ?? 'waiting').toString();
      if (status != 'playing') return;

      final hostId = (data['hostId'] ?? '').toString();

      final players = _playersFrom(data['players']);
      final myIdx = players.indexWhere((p) => _uidOf(p) == uid);
      if (myIdx >= 0) {
        players[myIdx] = {
          ...players[myIdx],
          'lastSeen': nowMs,
        };
      }

      final stalePlayers =
          players.where((p) => _isStale(p, nowMs, staleMs)).toList();

      final hostPresence = players.where((p) => _uidOf(p) == hostId).toList();
      final bool hostMissing = hostId.isEmpty || hostPresence.isEmpty;
      final bool hostStale =
          !hostMissing && _isStale(hostPresence.first, nowMs, staleMs);

      if (hostMissing || hostStale) {
        await _resetRoomToWaiting(tx, roomRef, data,
            clearPlayers: true, endedReason: 'host_left');
        return;
      }

      final staleNonHostUids = stalePlayers
          .map(_uidOf)
          .where((id) => id.isNotEmpty && id != hostId)
          .toSet();

      final keptPresence =
          players.where((p) => !staleNonHostUids.contains(_uidOf(p))).toList();

      final gameStateRaw = data['gameState'];
      if (gameStateRaw is! Map<String, dynamic>) {
        final hp = keptPresence.firstWhere((p) => _uidOf(p) == hostId);
        await _resetRoomToWaiting(
          tx,
          roomRef,
          data,
          clearPlayers: false,
          endedReason: 'all_left',
          keepHostPresence: true,
          hostPresence: hp,
        );
        return;
      }

      final st = GameStateSnapshot.fromJson(gameStateRaw);

      if (staleNonHostUids.isNotEmpty) {
        final removedIndices = <int>[];
        for (int i = 0; i < st.players.length; i++) {
          if (staleNonHostUids.contains(st.players[i].id)) {
            removedIndices.add(i);
          }
        }

        if (removedIndices.isNotEmpty) {
          for (final idx in removedIndices.reversed) {
            st.players.removeAt(idx);
            if (idx < st.currentPlayerIndex) {
              st.currentPlayerIndex -= 1;
            }
          }

          if (st.players.isEmpty) {
            await _resetRoomToWaiting(tx, roomRef, data,
                clearPlayers: true, endedReason: '');
            return;
          }

          if (st.currentPlayerIndex >= st.players.length) {
            st.currentPlayerIndex = 0;
          }

          if (st.players.length == 1 && st.players.first.id == hostId) {
            final hp = keptPresence.firstWhere((p) => _uidOf(p) == hostId);
            await _resetRoomToWaiting(
              tx,
              roomRef,
              data,
              clearPlayers: false,
              endedReason: 'all_left',
              keepHostPresence: true,
              hostPresence: hp,
            );
            return;
          }

          final int turnDuration = (data['turnDuration'] ?? 45) is num
              ? (data['turnDuration'] as num).toInt()
              : 45;
          st.turnEndTime =
              DateTime.now().millisecondsSinceEpoch + (turnDuration * 1000);
        }
      }

      tx.update(roomRef, {
        'players': _rebuildHostFlags(keptPresence, hostId),
        'gameState': st.toJson(),
      });
    });
  }

  // =========================
  // SETUP GAME
  // =========================

  Future<void> hostStartGame(
    String roomId,
    List<dynamic> playersList, {
    required int targetScore,
    required int turnDuration,
  }) async {
    final random = Random();
    final int playerCount = playersList.length;

    int tokensPerColor;
    int goldTokens = 5;
    if (playerCount <= 4) {
      tokensPerColor = (playerCount == 2)
          ? 4
          : (playerCount == 3)
              ? 5
              : 7;
    } else {
      goldTokens = 9;
      tokensPerColor = playerCount * 2;
    }

    final Map<GemType, int> bankTokens = {
      GemType.white: tokensPerColor,
      GemType.blue: tokensPerColor,
      GemType.green: tokensPerColor,
      GemType.red: tokensPerColor,
      GemType.black: tokensPerColor,
      GemType.gold: goldTokens,
    };

    final List<DevCard> d1 = List.from(FullGameData.level1Cards)
      ..shuffle(random);
    final List<DevCard> d2 = List.from(FullGameData.level2Cards)
      ..shuffle(random);
    final List<DevCard> d3 = List.from(FullGameData.level3Cards)
      ..shuffle(random);

    final List<String> vis1 = [];
    final List<String> vis2 = [];
    final List<String> vis3 = [];

    void draw(List<DevCard> d, List<String> v) {
      if (d.isNotEmpty) v.add(d.removeAt(0).id);
    }

    for (int i = 0; i < 4; i++) {
      draw(d1, vis1);
      draw(d2, vis2);
      draw(d3, vis3);
    }

    final List<Noble> allNobles = List.from(FullGameData.nobles)
      ..shuffle(random);
    final List<String> visNobles =
        allNobles.take(playerCount + 1).map((n) => n.id).toList();

    final List<OnlinePlayerState> onlinePlayers = playersList
        .map((pData) => OnlinePlayerState(
              id: (pData['uid'] ?? '').toString(),
              name: (pData['name'] ?? 'Player').toString(),
              avatarUrl:
                  (pData['avatarUrl'] ?? pData['photoURL'] ?? pData['avatar'])
                      ?.toString(),
              score: 0,
              tokens: {for (var g in GemType.values) g: 0},
              bonuses: {for (var g in GemType.values) g: 0},
              purchasedCardIds: [],
              reservedCardIds: [],
              nobleIds: [],
              lastActionTurnId: -1,
            ))
        .toList()
      ..shuffle(random);

    final int endTime =
        DateTime.now().millisecondsSinceEpoch + (turnDuration * 1000);

    final roomRef =
        _firestore.collection(AppConstants.collectionRooms).doc(roomId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(roomRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};
      final int sessionId = _getSessionId(data) + 1;

      tx.update(roomRef, {
        'status': 'playing',
        'winningScore': targetScore,
        'turnDuration': turnDuration,
        'endedReason': '',
        'endedAt': FieldValue.delete(),
        'sessionId': sessionId,
        'gameState': GameStateSnapshot(
          turnId: 0,
          currentPlayerIndex: 0,
          bankTokens: bankTokens,
          visibleLevel1: vis1,
          visibleLevel2: vis2,
          visibleLevel3: vis3,
          visibleNobles: visNobles,
          players: onlinePlayers,
          turnEndTime: endTime,
        ).toJson(),
        'decks': {
          'level1': d1.map((c) => c.id).toList(),
          'level2': d2.map((c) => c.id).toList(),
          'level3': d3.map((c) => c.id).toList(),
        },
      });
    });
  }

  // =========================
  // ACTIONS
  // =========================
  int _totalTokensOf(OnlinePlayerState player) {
    return player.tokens.values.fold(0, (a, b) => a + b);
  }

  void _forceReturnExcessTokens(
    OnlinePlayerState player,
    GameStateSnapshot state,
  ) {
    int excess = _totalTokensOf(player) - 10;
    if (excess <= 0) return;

    // Thứ tự trả: ưu tiên token thường, vàng trả cuối
    final order = [
      GemType.white,
      GemType.blue,
      GemType.green,
      GemType.red,
      GemType.black,
      GemType.gold,
    ];

    for (final type in order) {
      if (excess <= 0) break;
      final have = player.tokens[type] ?? 0;
      if (have <= 0) continue;

      final giveBack = have >= excess ? excess : have;
      player.tokens[type] = have - giveBack;
      state.bankTokens[type] = (state.bankTokens[type] ?? 0) + giveBack;
      excess -= giveBack;
    }
  }

  Future<bool> playerTakeTokens(
    String roomId,
    String uid,
    List<GemType> selectedTokens,
  ) async {
    return await _runGameTransaction(roomId, uid,
        (gameState, roomData, transaction) {
      final player = gameState.players[gameState.currentPlayerIndex];

      // ===== VALIDATE COUNT =====
      if (selectedTokens.isEmpty) return false;
      if (selectedTokens.length > 3) return false;

      // Đếm số lượng theo màu
      final Map<GemType, int> counts = {};
      for (final t in selectedTokens) {
        if (t == GemType.gold) return false; // không lấy vàng trực tiếp
        counts[t] = (counts[t] ?? 0) + 1;
      }
      // ===== LUẬT LẤY 2 CÙNG MÀU =====
      if (counts.length == 1 && selectedTokens.length == 2) {
        final GemType type = counts.keys.first;
        final int bankCount = gameState.bankTokens[type] ?? 0;
        if (bankCount < 4) return false;
      }
      // ===== LUẬT LẤY 3 KHÁC MÀU =====
      if (counts.length != selectedTokens.length) {
        // ví dụ: 2 đỏ + 1 xanh → cấm
        return false;
      }
      // ===== CHECK BANK =====
      for (final entry in counts.entries) {
        final bankCount = gameState.bankTokens[entry.key] ?? 0;
        if (bankCount < entry.value) return false;
      }
      // ===== CHECK GIỚI HẠN 10 TOKEN =====
      final currentTotal = _totalTokensOf(player);
      if (currentTotal + selectedTokens.length > 10) return false;
      // ===== APPLY =====
      for (final entry in counts.entries) {
        final type = entry.key;
        final amount = entry.value;
        gameState.bankTokens[type] = (gameState.bankTokens[type] ?? 0) - amount;
        player.tokens[type] = (player.tokens[type] ?? 0) + amount;
      }
      // Ép trả nếu vượt 10 (an toàn)
      _forceReturnExcessTokens(player, gameState);
      SoundManager().playToken();
      return true;
    });
  }

  Future<bool> playerBuyCard(String roomId, String uid, DevCard card) async {
    return await _runGameTransaction(roomId, uid,
        (gameState, roomData, transaction) {
      final player = gameState.players[gameState.currentPlayerIndex];

      final Map<GemType, int> costToPay = {};
      int goldNeeded = 0;

      for (final entry in card.cost.entries) {
        final GemType type = entry.key;
        final int discount = player.bonuses[type] ?? 0;
        final int actualCost = max(0, entry.value - discount);

        final int playerHas = player.tokens[type] ?? 0;
        if (playerHas >= actualCost) {
          costToPay[type] = actualCost;
        } else {
          costToPay[type] = playerHas;
          goldNeeded += (actualCost - playerHas);
        }
      }

      if ((player.tokens[GemType.gold] ?? 0) < goldNeeded) return false;

      costToPay.forEach((t, amount) {
        if (amount > 0) {
          player.tokens[t] = (player.tokens[t] ?? 0) - amount;
          gameState.bankTokens[t] = (gameState.bankTokens[t] ?? 0) + amount;
        }
      });

      if (goldNeeded > 0) {
        player.tokens[GemType.gold] =
            (player.tokens[GemType.gold] ?? 0) - goldNeeded;
        gameState.bankTokens[GemType.gold] =
            (gameState.bankTokens[GemType.gold] ?? 0) + goldNeeded;
      }

      // Logic xóa thẻ giam: Cần xử lý cả ID thường và ID có suffix _v (visible)
      // Tìm xem người chơi có đang giữ thẻ này không (dù ở dạng ẩn hay hiện)
      final String rawId = card.id;
      final String visibleId = "${card.id}_v";

      if (player.reservedCardIds.contains(rawId)) {
        player.reservedCardIds.remove(rawId);
      } else if (player.reservedCardIds.contains(visibleId)) {
        player.reservedCardIds.remove(visibleId);
      } else {
        // Mua trực tiếp từ bàn
        _removeCardFromBoard(gameState, card.id, roomData, transaction, roomId);
      }

      player.purchasedCardIds.add(card.id);
      player.score += card.points;
      player.bonuses[card.bonus] = (player.bonuses[card.bonus] ?? 0) + 1;

      SoundManager().playBuy();
      _checkNobles(player, gameState);
      return true;
    });
  }

  // Giam từ BÀN -> Công khai (Thêm đuôi _v vào ID)
  Future<bool> playerReserveCard(
      String roomId, String uid, DevCard card) async {
    return await _runGameTransaction(roomId, uid,
        (gameState, roomData, transaction) {
      final player = gameState.players[gameState.currentPlayerIndex];
      if (player.reservedCardIds.length >= 3) return false;

      _removeCardFromBoard(gameState, card.id, roomData, transaction, roomId);

      // Đánh dấu là visible
      player.reservedCardIds.add("${card.id}_v");

      final totalTokens = _totalTokensOf(player);
      final bankGold = gameState.bankTokens[GemType.gold] ?? 0;

      if (bankGold > 0 && totalTokens < 10) {
        gameState.bankTokens[GemType.gold] = bankGold - 1;
        player.tokens[GemType.gold] = (player.tokens[GemType.gold] ?? 0) + 1;
      }
      _forceReturnExcessTokens(player, gameState);
      SoundManager().playClick();
      return true;
    });
  }

  // Giam từ CHỒNG BÀI -> Bí mật (Giữ nguyên ID, không thêm _v)
  Future<bool> playerReserveFromDeck(
      String roomId, String uid, int level) async {
    return await _runGameTransaction(roomId, uid,
        (gameState, roomData, transaction) {
      final player = gameState.players[gameState.currentPlayerIndex];
      if (player.reservedCardIds.length >= 3) return false;

      // Lấy danh sách thẻ trong deck từ Firestore
      final decks = (roomData['decks'] ?? {}) as Map<String, dynamic>;
      final key = 'level$level';
      final deckList = List.from(decks[key] ?? []);

      if (deckList.isEmpty) return false; // Hết bài để bốc

      // Rút thẻ đầu tiên
      final String newId = deckList.removeAt(0);

      // Cập nhật lại deck trong DB
      transaction.update(
        _firestore.collection(AppConstants.collectionRooms).doc(roomId),
        {'decks.$key': deckList},
      );

      // Thêm vào danh sách giam (KHÔNG thêm đuôi _v -> Bí mật)
      player.reservedCardIds.add(newId);

      // Nhận vàng nếu có
      final totalTokens = _totalTokensOf(player);
      final bankGold = gameState.bankTokens[GemType.gold] ?? 0;

      if (bankGold > 0 && totalTokens < 10) {
        gameState.bankTokens[GemType.gold] = bankGold - 1;
        player.tokens[GemType.gold] = (player.tokens[GemType.gold] ?? 0) + 1;
      }
      _forceReturnExcessTokens(player, gameState);
      SoundManager().playClick();
      return true;
    });
  }

  Future<bool> _runGameTransaction(
    String roomId,
    String uid,
    bool Function(GameStateSnapshot, Map<String, dynamic>, Transaction) action,
  ) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final roomRef =
            _firestore.collection(AppConstants.collectionRooms).doc(roomId);
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return false;

        final roomData = snapshot.data() as Map<String, dynamic>;
        final rawState = roomData['gameState'];
        if (rawState is! Map<String, dynamic>) return false;

        final gameState = GameStateSnapshot.fromJson(rawState);
        // ===== FIX 1: KHÓA ACTION KHI KHÔNG TỚI LƯỢT =====
        if (gameState.players.isEmpty) return false;

        final currentPlayer = gameState.players[gameState.currentPlayerIndex];
        if (currentPlayer.id != uid) {
          return false; // không phải lượt → cấm action
        }
        // ===== FIX MULTI ACTION / 1 TURN =====
        if (currentPlayer.lastActionTurnId == gameState.turnId) {
          return false;
        }
// ==============================================

        final success = action(gameState, roomData, transaction);
        if (!success) return false;
        currentPlayer.lastActionTurnId = gameState.turnId;
        _advanceTurn(gameState, roomData);
        transaction.update(roomRef, {'gameState': gameState.toJson()});
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  void _advanceTurn(GameStateSnapshot state, Map<String, dynamic> roomData) {
    if (state.winnerId != null) return;
    final int nextIndex = (state.currentPlayerIndex + 1) % state.players.length;

    final int winningScore = (roomData['winningScore'] ?? 15) as int;
    final int turnDuration = (roomData['turnDuration'] ?? 45) is num
        ? (roomData['turnDuration'] as num).toInt()
        : 45;

    if (nextIndex == 0) {
      final potentialWinner = state.players.reduce((a, b) {
        if (a.score != b.score) return a.score > b.score ? a : b;
        return a.purchasedCardIds.length < b.purchasedCardIds.length ? a : b;
      });

      if (potentialWinner.score >= winningScore) {
        state.winnerId = potentialWinner.id;
        return;
      }
    }

    // ✅ FIX: ĐÁNH DẤU SANG LƯỢT MỚI
    state.turnId += 1;

    state.currentPlayerIndex = nextIndex;
    state.turnEndTime =
        DateTime.now().millisecondsSinceEpoch + (turnDuration * 1000);
  }

  void _removeCardFromBoard(
    GameStateSnapshot state,
    String cardId,
    Map<String, dynamic> roomData,
    Transaction t,
    String roomId,
  ) {
    int lvl = 0;
    if (state.visibleLevel1.remove(cardId)) {
      lvl = 1;
    } else if (state.visibleLevel2.remove(cardId)) {
      lvl = 2;
    } else if (state.visibleLevel3.remove(cardId)) {
      lvl = 3;
    }

    if (lvl <= 0) return;

    final decks = (roomData['decks'] ?? {}) as Map<String, dynamic>;
    final key = 'level$lvl';
    final deckList = List.from(decks[key] ?? []);

    if (deckList.isEmpty) return;

    final String newId = deckList.removeAt(0);
    if (lvl == 1) state.visibleLevel1.add(newId);
    if (lvl == 2) state.visibleLevel2.add(newId);
    if (lvl == 3) state.visibleLevel3.add(newId);

    t.update(
      _firestore.collection(AppConstants.collectionRooms).doc(roomId),
      {'decks.$key': deckList},
    );
  }

  void _checkNobles(OnlinePlayerState player, GameStateSnapshot state) {
    for (final String nId in List<String>.from(state.visibleNobles)) {
      final Noble n = FullGameData.nobles.firstWhere(
        (x) => x.id == nId,
        orElse: () => FullGameData.nobles[0],
      );

      bool eligible = true;
      n.requirements.forEach((type, reqCount) {
        if ((player.bonuses[type] ?? 0) < reqCount) {
          eligible = false;
        }
      });

      if (eligible) {
        // ✅ CHỈ LẤY 1 NOBLE
        player.score += n.points;
        player.nobleIds.add(nId);
        state.visibleNobles.remove(nId);
        SoundManager().playBuy();
        return; // ⛔ DỪNG NGAY
      }
    }
  }

  // =========================
  // FORCE END TURN (TIMEOUT)
  // =========================

  Future<void> forceEndTurn(String roomId) async {
    final roomRef =
        _firestore.collection(AppConstants.collectionRooms).doc(roomId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;

      final roomData = snapshot.data() as Map<String, dynamic>;
      final raw = roomData['gameState'];
      if (raw is! Map<String, dynamic>) return;
      final gameState = GameStateSnapshot.fromJson(raw);

      _advanceTurn(gameState, roomData);
      transaction.update(roomRef, {'gameState': gameState.toJson()});
    });
  }
}
