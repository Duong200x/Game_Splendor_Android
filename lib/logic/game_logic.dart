import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../models/game_entities.dart';
import '../full_game_data.dart';
import '../managers/sound_manager.dart';

class ReserveDeckResult {
  final DevCard? card;
  final String? error;
  const ReserveDeckResult({this.card, this.error});
}

class GameLogic {
  Function? onStateChanged;

  int currentPlayerCount = 4;
  int currentPlayerIndex = 0;
  int turnDuration = 30;

  int winningScore = 15;
  bool mustDiscardToken = false;
  Player? winner;

  Timer? _turnTimer;
  Timer? _botThinkingTimer;

  // NEW: timer delay chuyển lượt cho bot (để âm thanh/animation kịp chạy)
  Timer? _botEndTurnDelayTimer;

  // --- FIX QUAN TRỌNG: Khóa chặn loạn lượt ---
  bool _isProcessingTurn = false;

  // --- NEW: Pause flag (dùng khi mở dialog thoát / app lifecycle) ---
  bool _isPaused = false;

  // NEW: delay chuyển lượt cho bot (tùy chỉnh 200-400ms)
  static const Duration _botEndTurnDelay = Duration(milliseconds: 280);

  List<DevCard> deckLevel1 = [];
  List<DevCard> deckLevel2 = [];
  List<DevCard> deckLevel3 = [];

  List<GemType> currentTurnTokens = [];
  List<Noble> visibleNobles = [];
  List<DevCard> visibleLevel1 = [];
  List<DevCard> visibleLevel2 = [];
  List<DevCard> visibleLevel3 = [];

  List<Player> players = [];
  Map<GemType, int> bankTokens = {};

  void setupGame(int playerCount, int durationSeconds,
      {int targetScore = 15, Function? updateCallback}) {
    _cancelAllTimers();
    _isProcessingTurn = false; // Reset khóa
    _isPaused = false; // Reset pause

    currentPlayerCount = playerCount;
    turnDuration = durationSeconds;
    winningScore = targetScore;

    if (updateCallback != null) onStateChanged = updateCallback;

    winner = null;
    currentPlayerIndex = 0;
    currentTurnTokens.clear();
    mustDiscardToken = false;

    final random = Random();

    int tokensPerColor;
    int goldTokens;

    if (playerCount <= 4) {
      goldTokens = 5;
      tokensPerColor = (playerCount == 2)
          ? 4
          : (playerCount == 3)
              ? 5
              : 7;
    } else {
      goldTokens = 9;
      tokensPerColor = playerCount * 2;
    }

    bankTokens = {
      GemType.white: tokensPerColor,
      GemType.blue: tokensPerColor,
      GemType.green: tokensPerColor,
      GemType.red: tokensPerColor,
      GemType.black: tokensPerColor,
      GemType.gold: goldTokens,
    };

    players = List.generate(playerCount, (index) {
      bool isUser = index == 0;
      return Player(
        id: "p_$index",
        name: isUser ? "BẠN" : "Bot $index",
        color: isUser
            ? Colors.amber
            : Colors.primaries[index % Colors.primaries.length],
        isHuman: isUser,
        isTurn: isUser,
      );
    });

    deckLevel1 = List<DevCard>.from(FullGameData.level1Cards)..shuffle(random);
    deckLevel2 = List<DevCard>.from(FullGameData.level2Cards)..shuffle(random);
    deckLevel3 = List<DevCard>.from(FullGameData.level3Cards)..shuffle(random);

    visibleLevel1 = [];
    visibleLevel2 = [];
    visibleLevel3 = [];
    for (int i = 0; i < 4; i++) {
      _drawNewCard(1);
    }
    for (int i = 0; i < 4; i++) {
      _drawNewCard(2);
    }
    for (int i = 0; i < 4; i++) {
      _drawNewCard(3);
    }

    List<Noble> allNobles = List<Noble>.from(FullGameData.nobles)
      ..shuffle(random);
    visibleNobles = allNobles.take(playerCount + 1).toList();

    _notifyUpdate();
    _startTurnTimer();
  }

  void _cancelAllTimers() {
    _turnTimer?.cancel();
    _botThinkingTimer?.cancel();
    _botEndTurnDelayTimer?.cancel();
  }

  void dispose() {
    _cancelAllTimers();
  }

  // --- NEW: Pause/Resume ---
  void pause() {
    if (_isPaused) return;
    _isPaused = true;
    _cancelAllTimers();
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    if (winner != null) return;
    _startTurnTimer();
    _notifyUpdate();
  }

  void _drawNewCard(int level) {
    if (level == 1 && deckLevel1.isNotEmpty) {
      visibleLevel1.add(deckLevel1.removeAt(0));
    } else if (level == 2 && deckLevel2.isNotEmpty) {
      visibleLevel2.add(deckLevel2.removeAt(0));
    } else if (level == 3 && deckLevel3.isNotEmpty) {
      visibleLevel3.add(deckLevel3.removeAt(0));
    }
  }

  bool get _isBotTurn {
    if (players.isEmpty) return false;
    return !players[currentPlayerIndex].isHuman;
  }

  // NEW: bot kết thúc lượt có delay để âm thanh/animation không bị “cắt”
  void _scheduleEndTurnForBot() {
    // cancel timer để không bị timeout chen vào
    _turnTimer?.cancel();
    _botThinkingTimer?.cancel();
    _botEndTurnDelayTimer?.cancel();

    final int scheduledIndex = currentPlayerIndex;

    _botEndTurnDelayTimer = Timer(_botEndTurnDelay, () {
      if (_isPaused) return;
      if (winner != null) return;

      // Nếu trong lúc delay đã đổi lượt (do event khác), bỏ
      if (currentPlayerIndex != scheduledIndex) return;

      // Nếu đang chuyển lượt thì thôi
      if (_isProcessingTurn) return;

      // Nếu bot đang phải discard (hiếm vì bot có auto discard), xử lý rồi mới end
      if (mustDiscardToken) {
        _autoDiscardAndEndTurn();
        return;
      }

      _advanceTurn();
    });
  }

  // --- ACTIONS ---

  String? selectToken(GemType type) {
    if (_isProcessingTurn) return null; // Đang chuyển lượt thì ko cho bấm
    if (_isPaused) return null; // đang pause (vd: mở dialog thoát)

    if (mustDiscardToken) {
      SoundManager().playError();
      return "Bạn phải trả bớt token trước!";
    }
    if (type == GemType.gold) {
      SoundManager().playError();
      return "Không được lấy Vàng trực tiếp! Dùng nút Ổ khóa.";
    }
    if ((bankTokens[type] ?? 0) <= 0) {
      SoundManager().playError();
      return "Đã hết token loại này!";
    }

    if (currentTurnTokens.isNotEmpty) {
      if (currentTurnTokens.contains(type)) {
        if ((bankTokens[type] ?? 0) < 3) {
          SoundManager().playError();
          return "Chỉ được lấy 2 viên nếu kho còn từ 4 trở lên!";
        }
        if (currentTurnTokens.length > 1) {
          SoundManager().playError();
          return "Không được lấy 2 viên cùng màu nếu đã chọn màu khác!";
        }
      } else {
        if (currentTurnTokens.length == 2 &&
            currentTurnTokens[0] == currentTurnTokens[1]) {
          SoundManager().playError();
          return "Đã chọn 2 viên cùng màu!";
        }
        if (currentTurnTokens.length >= 3) {
          SoundManager().playError();
          return "Chỉ được lấy tối đa 3 viên!";
        }
      }
    }

    SoundManager().playClick();
    currentTurnTokens.add(type);
    bankTokens[type] = (bankTokens[type] ?? 0) - 1;
    _notifyUpdate();
    return null;
  }

  bool confirmSelection() {
    if (_isProcessingTurn) return false;
    if (_isPaused) return false;
    if (currentTurnTokens.isEmpty) return false;

    Player player = players[currentPlayerIndex];
    for (var type in currentTurnTokens) {
      player.tokens[type] = (player.tokens[type] ?? 0) + 1;
    }

    SoundManager().playToken();
    _tryEndTurn();
    return true;
  }

  void cancelSelection() {
    if (_isProcessingTurn) return;
    if (_isPaused) return;
    if (currentTurnTokens.isEmpty) return;
    for (var type in currentTurnTokens) {
      bankTokens[type] = (bankTokens[type] ?? 0) + 1;
    }
    currentTurnTokens.clear();
    SoundManager().playClick();
    _notifyUpdate();
  }

  void returnTokenToBank(GemType type) {
    if (_isProcessingTurn) return; // Chặn khi đang xử lý
    if (_isPaused) return;

    Player player = players[currentPlayerIndex];
    if ((player.tokens[type] ?? 0) > 0) {
      player.tokens[type] = (player.tokens[type] ?? 0) - 1;
      bankTokens[type] = (bankTokens[type] ?? 0) + 1;
      SoundManager().playClick();

      if (player.totalTokenCount <= 10) {
        mustDiscardToken = false;

        // Nếu ai đó (bot) đang discard xong thì cũng delay cho bot
        if (_isBotTurn) {
          _scheduleEndTurnForBot();
        } else {
          _advanceTurn();
        }
      } else {
        _notifyUpdate();
      }
    }
  }

  String? buyCard(DevCard card) {
    if (_isProcessingTurn) return null;
    if (_isPaused) return null;

    if (mustDiscardToken) {
      SoundManager().playError();
      return "Bạn phải trả bớt token trước!";
    }
    if (currentTurnTokens.isNotEmpty) cancelSelection();

    Player player = players[currentPlayerIndex];
    if (!_canAfford(player, card)) {
      SoundManager().playError();
      return "Không đủ tài nguyên!";
    }

    _payForCard(player, card);

    if (player.reservedCards.contains(card)) {
      player.reservedCards.remove(card);
    } else {
      _removeAndRefill(card);
    }

    player.purchasedCards.add(card);
    player.score += card.prestigePoints;
    if (card.gemType != GemType.gold) {
      player.bonuses[card.gemType] = (player.bonuses[card.gemType] ?? 0) + 1;
    }

    SoundManager().playBuy();
    _checkNobles(player);

    _tryEndTurn();
    return null;
  }

  String? reserveCard(DevCard card) {
    if (_isProcessingTurn) return null;
    if (_isPaused) return null;

    if (mustDiscardToken) {
      SoundManager().playError();
      return "Bạn phải trả bớt token trước!";
    }
    if (currentTurnTokens.isNotEmpty) cancelSelection();

    Player player = players[currentPlayerIndex];
    if (player.reservedCards.length >= 3) {
      SoundManager().playError();
      return "Tối đa 3 thẻ giam!";
    }

    _removeAndRefill(card);
    player.reservedCards.add(card);

    if ((bankTokens[GemType.gold] ?? 0) > 0) {
      player.tokens[GemType.gold] = (player.tokens[GemType.gold] ?? 0) + 1;
      bankTokens[GemType.gold] = (bankTokens[GemType.gold] ?? 0) - 1;
    }

    SoundManager().playClick();

    _tryEndTurn();
    return null;
  }

  /// Reserve 1 hidden card from the deck back of [level] (1/2/3).
  /// This is mainly used for the human player in training mode.
  /// Returns (card, error). If success, card is the actual drawn card.
  ReserveDeckResult reserveHiddenFromDeck(int level) {
    if (_isProcessingTurn) {
      return const ReserveDeckResult(error: "Đang xử lý lượt...");
    }
    if (_isPaused) return const ReserveDeckResult(error: "Đang tạm dừng...");

    if (mustDiscardToken) {
      SoundManager().playError();
      return const ReserveDeckResult(error: "Bạn phải trả bớt token trước!");
    }
    if (currentTurnTokens.isNotEmpty) cancelSelection();

    final player = players[currentPlayerIndex];
    if (player.reservedCards.length >= 3) {
      SoundManager().playError();
      return const ReserveDeckResult(error: "Tối đa 3 thẻ giam!");
    }

    DevCard? drawn;
    if (level == 1) {
      if (deckLevel1.isEmpty) {
        return const ReserveDeckResult(error: "Hết bài cấp 1!");
      }
      drawn = deckLevel1.removeAt(0);
    } else if (level == 2) {
      if (deckLevel2.isEmpty) {
        return const ReserveDeckResult(error: "Hết bài cấp 2!");
      }
      drawn = deckLevel2.removeAt(0);
    } else if (level == 3) {
      if (deckLevel3.isEmpty) {
        return const ReserveDeckResult(error: "Hết bài cấp 3!");
      }
      drawn = deckLevel3.removeAt(0);
    } else {
      return const ReserveDeckResult(error: "Level không hợp lệ!");
    }

    player.reservedCards.add(drawn);

    // Give 1 gold if available
    if ((bankTokens[GemType.gold] ?? 0) > 0) {
      player.tokens[GemType.gold] = (player.tokens[GemType.gold] ?? 0) + 1;
      bankTokens[GemType.gold] = (bankTokens[GemType.gold] ?? 0) - 1;
    }

    SoundManager().playClick();
    _tryEndTurn();
    return ReserveDeckResult(card: drawn);
  }

  void _removeAndRefill(DevCard card) {
    if (visibleLevel1.contains(card)) {
      int idx = visibleLevel1.indexOf(card);
      visibleLevel1.removeAt(idx);
      if (deckLevel1.isNotEmpty) {
        visibleLevel1.insert(idx, deckLevel1.removeAt(0));
      }
    } else if (visibleLevel2.contains(card)) {
      int idx = visibleLevel2.indexOf(card);
      visibleLevel2.removeAt(idx);
      if (deckLevel2.isNotEmpty) {
        visibleLevel2.insert(idx, deckLevel2.removeAt(0));
      }
    } else if (visibleLevel3.contains(card)) {
      int idx = visibleLevel3.indexOf(card);
      visibleLevel3.removeAt(idx);
      if (deckLevel3.isNotEmpty) {
        visibleLevel3.insert(idx, deckLevel3.removeAt(0));
      }
    }
  }

  void _tryEndTurn() {
    Player player = players[currentPlayerIndex];
    currentTurnTokens.clear();

    if (player.totalTokenCount > 10) {
      mustDiscardToken = true;
      _notifyUpdate();

      // Nếu là bot mà vẫn >10, đợi 1 nhịp rồi auto discard + end
      if (_isBotTurn) {
        _botEndTurnDelayTimer?.cancel();
        _botEndTurnDelayTimer = Timer(_botEndTurnDelay, () {
          if (_isPaused) return;
          if (winner != null) return;
          if (!_isBotTurn) return;
          _autoDiscardAndEndTurn();
        });
      }
      return;
    }

    mustDiscardToken = false;

    // ✅ FIX CHÍNH: BOT end turn có delay
    if (_isBotTurn) {
      _scheduleEndTurnForBot();
    } else {
      _advanceTurn();
    }
  }

  // --- CORE LOGIC: CHUYỂN LƯỢT AN TOÀN ---
  void _advanceTurn() {
    if (_isPaused) return;
    if (_isProcessingTurn) return; // Nếu đang xử lý thì chặn ngay
    _isProcessingTurn = true; // Bắt đầu khóa

    _cancelAllTimers();

    players[currentPlayerIndex].isTurn = false;
    int nextIndex = (currentPlayerIndex + 1) % currentPlayerCount;

    if (nextIndex == 0) {
      bool isEndGame = players.any((p) => p.score >= winningScore);
      if (isEndGame) {
        _endGame();
        return;
      }
    }

    currentPlayerIndex = nextIndex;
    players[currentPlayerIndex].isTurn = true;

    _notifyUpdate();

    // Mở khóa sau khi đã cập nhật xong
    _isProcessingTurn = false;
    _startTurnTimer();
  }

  void _endGame() {
    players.sort((a, b) {
      int scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.purchasedCards.length.compareTo(b.purchasedCards.length);
    });

    winner = players.first;
    if (winner != null && winner!.isHuman) {
      SoundManager().playWin();
    }
    _notifyUpdate();
  }

  void _startTurnTimer() {
    if (_isPaused) return;

    _turnTimer?.cancel();
    _botThinkingTimer?.cancel();
    _botEndTurnDelayTimer?.cancel();

    _turnTimer = Timer(Duration(seconds: turnDuration), () {
      if (_isPaused) return;
      if (mustDiscardToken) {
        _autoDiscardAndEndTurn();
      } else {
        _advanceTurn();
      }
    });

    if (!players[currentPlayerIndex].isHuman) {
      _botThinkingTimer?.cancel();
      // Bot suy nghĩ 2 giây rồi mới đi
      _botThinkingTimer = Timer(const Duration(seconds: 2), _runBotTurn);
    }
  }

  void _autoDiscardAndEndTurn() {
    Player p = players[currentPlayerIndex];
    while (p.totalTokenCount > 10) {
      for (var key in p.tokens.keys) {
        if ((p.tokens[key] ?? 0) > 0) {
          p.tokens[key] = (p.tokens[key] ?? 0) - 1;
          bankTokens[key] = (bankTokens[key] ?? 0) + 1;
          break;
        }
      }
    }
    mustDiscardToken = false;

    // Nếu bot discard xong thì cũng delay chút
    if (_isBotTurn) {
      _scheduleEndTurnForBot();
    } else {
      _advanceTurn();
    }
  }

  void _runBotTurn() {
    if (_isPaused) return;

    // Kiểm tra lại lần nữa xem còn đúng lượt Bot không (an toàn)
    if (players[currentPlayerIndex].isHuman) return;

    Player bot = players[currentPlayerIndex];
    bool actionDone = false;

    // 1. Cố gắng mua thẻ
    for (var card in visibleLevel1) {
      // buyCard() sẽ tự _tryEndTurn(), giờ sẽ delay chuyển lượt cho bot (đã fix)
      if (buyCard(card) == null) {
        actionDone = true;
        break;
      }
    }

    // 2. Nếu không mua được, lấy token
    if (!actionDone) {
      List<GemType> available = bankTokens.entries
          .where((e) => e.value > 0 && e.key != GemType.gold)
          .map((e) => e.key)
          .toList();

      if (available.isNotEmpty) {
        Set<GemType> picked = {};
        for (int i = 0; i < 3; i++) {
          if (available.isEmpty) break;
          var type = available[Random().nextInt(available.length)];
          if (!picked.contains(type)) {
            bankTokens[type] = (bankTokens[type] ?? 0) - 1;
            bot.tokens[type] = (bot.tokens[type] ?? 0) + 1;
            picked.add(type);
            available.remove(type);
          }
        }
      } else {
        if (visibleLevel1.isNotEmpty) {
          // reserveCard() cũng sẽ tự _tryEndTurn() -> có delay cho bot
          reserveCard(visibleLevel1[0]);
          actionDone = true;
        }
      }
    }

    // 3. Trả token nếu thừa
    while (bot.totalTokenCount > 10) {
      GemType? typeToDiscard;
      int maxVal = 0;
      bot.tokens.forEach((k, v) {
        if (v > maxVal) {
          maxVal = v;
          typeToDiscard = k;
        }
      });
      if (typeToDiscard != null) {
        bot.tokens[typeToDiscard!] = (bot.tokens[typeToDiscard!] ?? 0) - 1;
        bankTokens[typeToDiscard!] = (bankTokens[typeToDiscard!] ?? 0) + 1;
      } else {
        break;
      }
    }

    // Nếu bot chỉ lấy token thủ công (không gọi reserveCard/buyCard)
    if (!actionDone) {
      _tryEndTurn(); // -> sẽ delay chuyển lượt cho bot
    }
  }

  bool _canAfford(Player player, DevCard card) {
    int gold = player.tokens[GemType.gold] ?? 0;
    int missing = 0;
    card.cost.forEach((type, cost) {
      int discount = player.bonuses[type] ?? 0;
      int finalCost = max(0, cost - discount);
      int have = player.tokens[type] ?? 0;
      if (have < finalCost) missing += (finalCost - have);
    });
    return gold >= missing;
  }

  void _payForCard(Player player, DevCard card) {
    card.cost.forEach((type, cost) {
      int discount = player.bonuses[type] ?? 0;
      int toPay = max(0, cost - discount);
      int have = player.tokens[type] ?? 0;
      if (have >= toPay) {
        player.tokens[type] = have - toPay;
        bankTokens[type] = (bankTokens[type] ?? 0) + toPay;
      } else {
        int missing = toPay - have;
        player.tokens[type] = 0;
        bankTokens[type] = (bankTokens[type] ?? 0) + have;
        player.tokens[GemType.gold] =
            (player.tokens[GemType.gold] ?? 0) - missing;
        bankTokens[GemType.gold] = (bankTokens[GemType.gold] ?? 0) + missing;
      }
    });
  }

  void _checkNobles(Player player) {
    List<Noble> acquired = [];
    for (var noble in visibleNobles) {
      bool eligible = true;
      noble.requirements.forEach((type, count) {
        if ((player.bonuses[type] ?? 0) < count) eligible = false;
      });
      if (eligible) {
        acquired.add(noble);
        player.score += noble.prestigePoints;
        player.nobles.add(noble);

        // Noble sound cũng dễ bị dồn -> delay chuyển lượt đã giúp giảm
        SoundManager().playBuy();
      }
    }
    for (var n in acquired) {
      visibleNobles.remove(n);
    }
  }

  void endTurn() {
    if (_isPaused) return;

    // Nếu ai đó gọi endTurn khi đang bot thì vẫn delay cho bot
    if (_isBotTurn) {
      _scheduleEndTurnForBot();
    } else {
      _advanceTurn();
    }
  }

  void _notifyUpdate() {
    if (onStateChanged != null) onStateChanged!();
  }
}
