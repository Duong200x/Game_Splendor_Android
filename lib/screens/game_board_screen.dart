import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';

import '../logic/game_logic.dart';
import '../models/game_entities.dart';

import '../widgets/game_card_widget.dart';
import '../widgets/game_card_back_widget.dart';
import '../widgets/noble_widget.dart';
import '../widgets/game_token_widget.dart';
import '../widgets/turn_timer_wrapper.dart';
import '../widgets/game_animations.dart';
import '../managers/sound_manager.dart';

class GameBoardScreen extends StatefulWidget {
  final int playerCount;
  final int turnDuration;
  final int winningScore;

  const GameBoardScreen({
    super.key,
    this.playerCount = 4,
    this.turnDuration = 30,
    this.winningScore = 15,
  });

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  final GameLogic _game = GameLogic();
  bool isReserveMode = false;

  String? _topMessage;
  Color _topMessageColor = Colors.redAccent;
  Timer? _messageTimer;

  final List<Widget> _flyingAnimations = [];
  final GlobalKey _tokenBankKey = GlobalKey();
  final GlobalKey _userProfileKey = GlobalKey();
  final GlobalKey _nobleColumnKey = GlobalKey();

  DevCard? _previewCard;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    _game.setupGame(
      widget.playerCount,
      widget.turnDuration,
      targetScore: widget.winningScore,
      updateCallback: () {
        if (!mounted) return;
        setState(() {
          if (!_game.mustDiscardToken) isReserveMode = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _game.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _messageTimer?.cancel();
    super.dispose();
  }

  // =========================
  // CONFIRM EXIT
  // =========================
  Future<void> _confirmExitGame() async {
    // Pause để bot/timer không chạy ngầm trong lúc mở dialog
    _game.pause();

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
            "Thoát ván chơi?",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "Ván hiện tại sẽ bị hủy.\nBạn có chắc muốn thoát không?",
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
                "Thoát",
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
      Navigator.of(context).pop(); // Thoát màn game
      return;
    }

    // Ở lại -> resume
    _game.resume();
  }

  // --- UI HELPERS ---

  bool _checkTurn() {
    if (!_game.players[0].isTurn) {
      _showTopToast("Chưa đến lượt của bạn!", color: Colors.redAccent);
      SoundManager().playError();
      return false;
    }
    return true;
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

  void _showCustomDialog({
    required String title,
    required Widget content,
    List<Widget>? actions,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Stack(
        children: [
          AlertDialog(
            backgroundColor: const Color(0xFF0D1117),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.amber),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: content,
            actions: actions,
          ),
          Positioned(
            right: 20,
            top: 20,
            child: GestureDetector(
              onTap: () {
                SoundManager().playClick();
                Navigator.pop(ctx);
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // RESERVE HIDDEN (FROM DECK BACK)
  // =========================
  void _confirmReserveHiddenFromDeck(int level) {
    if (!_checkTurn()) return;

    if (_game.players[0].reservedCards.length >= 3) {
      _showTopToast("Đã giam tối đa 3 thẻ!", color: Colors.redAccent);
      return;
    }

    _showCustomDialog(
      title: "Giam thẻ ẨN?",
      content: Text(
        "Bạn sẽ rút 1 thẻ ẨN từ ổ bài cấp $level.\nNếu ngân hàng còn Vàng, bạn sẽ nhận +1 Vàng.",
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
          onPressed: () {
            Navigator.pop(context);
            if (!_checkTurn()) return;

            final res = _game.reserveHiddenFromDeck(level);
            if (res.error != null) {
              _showTopToast(res.error!, color: Colors.redAccent);
              return;
            }

            _showTopToast("Đã giam thẻ ẨN!", color: Colors.amber);
            if (res.card != null) _playCardAnimation(res.card!);

            setState(() {
              isReserveMode = false;
            });
          },
          child: const Text(
            "Giam ẨN",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showReservedDialog(BuildContext context, Player player) {
    _showCustomDialog(
      title: "Thẻ đang giữ (${player.reservedCards.length}/3)",
      content: SizedBox(
        width: double.maxFinite,
        height: 180,
        child: player.reservedCards.isEmpty
            ? const Center(
                child: Text("Chưa có thẻ nào!",
                    style: TextStyle(color: Colors.white70)),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: player.reservedCards.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, index) {
                  final card = player.reservedCards[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _onCardTap(card);
                    },
                    child: DevCardWidget(card: card, width: 120),
                  );
                },
              ),
      ),
    );
  }

  void _onCardTap(DevCard card) {
    if (!_checkTurn()) return;
    SoundManager().playClick();
    setState(() => _previewCard = card);
  }

  void _confirmCardAction() {
    if (_previewCard == null) return;

    final card = _previewCard!;
    String? error;
    bool success = false;
    final oldNobles = List<Noble>.from(_game.visibleNobles);

    if (isReserveMode) {
      if (_game.players[0].reservedCards.length >= 3) {
        error = "Đã giam tối đa 3 thẻ!";
      } else {
        error = _game.reserveCard(card);
        if (error == null) success = true;
      }
    } else {
      error = _game.buyCard(card);
      if (error == null) {
        success = true;
        _checkAndAnimateNobles(oldNobles);
      }
    }

    if (success) {
      _playCardAnimation(card);
      if (isReserveMode) {
        _showTopToast("Đã giam thẻ thành công!", color: Colors.amber);
        isReserveMode = false;
      } else {
        _showTopToast("Đã mua thẻ cấp ${card.level}!", color: Colors.green);
      }
    } else {
      _showTopToast(error ?? "Lỗi không xác định", color: Colors.redAccent);
    }

    setState(() => _previewCard = null);
  }

  void _checkAndAnimateNobles(List<Noble> oldNobles) {
    final acquired =
        oldNobles.where((n) => !_game.visibleNobles.contains(n)).toList();
    for (final noble in acquired) {
      _playNobleAnimation(noble);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _showTopToast(
            "Quý tộc đã đến thăm bạn! (+${noble.prestigePoints} điểm)",
            color: Colors.amber);
      });
    }
  }

  void _playTokenAnimation(GemType type) {
    final bankBox =
        _tokenBankKey.currentContext?.findRenderObject() as RenderBox?;
    final profileBox =
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
    final screenSize = MediaQuery.of(context).size;
    final startPos = Offset(screenSize.width * 0.4, screenSize.height * 0.4);
    final profileBox =
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

  void _playNobleAnimation(Noble noble) {
    final nobleBox =
        _nobleColumnKey.currentContext?.findRenderObject() as RenderBox?;
    final profileBox =
        _userProfileKey.currentContext?.findRenderObject() as RenderBox?;
    final startOffset = nobleBox != null
        ? nobleBox.localToGlobal(Offset.zero)
        : const Offset(800, 100);
    final endOffset = profileBox != null
        ? profileBox.localToGlobal(Offset.zero)
        : const Offset(50, 50);

    setState(() {
      _flyingAnimations.add(
        FlyingCardAnimation(
          key: UniqueKey(),
          startPos: startOffset,
          endPos: endOffset,
          child: NobleWidget(noble: noble, size: 80),
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

  @override
  Widget build(BuildContext context) {
    if (_game.winner != null) return _buildVictoryScreen(_game.winner!);

    final allBots = _game.players.skip(1).toList();
    final botCount = allBots.length;
    Player? botLeft;
    Player? botRight;
    List<Player> topBots = [];

    if (botCount == 1) {
      topBots = [allBots[0]];
    } else if (botCount == 2) {
      botLeft = allBots[0];
      botRight = allBots[1];
    } else if (botCount == 3) {
      botLeft = allBots[0];
      topBots = [allBots[1]];
      botRight = allBots[2];
    } else if (botCount == 4) {
      botLeft = allBots[0];
      topBots = [allBots[1], allBots[2]];
      botRight = allBots[3];
    } else if (botCount >= 5) {
      botLeft = allBots[0];
      topBots = allBots.sublist(1, botCount - 1);
      botRight = allBots.last;
    }

    final user = _game.players[0];

    // Dùng PopScope (mới) thay WillPopScope (cũ).
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

                return Stack(
                  children: [
                    Column(
                      children: [
                        SizedBox(
                            height: screenHeight * 0.18,
                            child: _buildTopPlayers(topBots)),
                        SizedBox(
                            height: screenHeight * 0.67,
                            child: _buildGameBoard(
                                botLeft, botRight, screenHeight * 0.67)),
                        SizedBox(
                            height: screenHeight * 0.15,
                            child: _buildBottomBar(user, screenHeight * 0.15)),
                      ],
                    ),

                    // Nút Thoát góc phải trên
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: _confirmExitGame,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.exit_to_app,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text("Thoát",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (_topMessage != null || _game.mustDiscardToken)
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: _game.mustDiscardToken
                                  ? Colors.redAccent
                                  : _topMessageColor.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Text(
                              _game.mustDiscardToken
                                  ? "CẢNH BÁO: QUÁ 10 TOKEN! TRẢ BỚT ĐI."
                                  : _topMessage!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                              textAlign: TextAlign.center,
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
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "ĐANG CHỌN THẺ ĐỂ GIAM",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
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
                                          horizontal: 20, vertical: 15),
                                    ),
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
                                          horizontal: 20, vertical: 15),
                                    ),
                                    onPressed: _confirmCardAction,
                                    icon: const Icon(Icons.check),
                                    label: const Text("ĐỒNG Ý"),
                                  ),
                                ],
                              ),
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
    final isMe = winner.isHuman;
    SoundManager().stopBGM();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isMe ? "CHIẾN THẮNG!" : "THẤT BẠI!",
              style: TextStyle(
                fontSize: 40,
                color: isMe ? Colors.amber : Colors.red,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
                border: Border.all(color: winner.color, width: 4),
              ),
              child: Icon(Icons.emoji_events, size: 80, color: winner.color),
            ),
            const SizedBox(height: 20),
            Text(
              "${winner.name} đã giành chiến thắng!",
              style: const TextStyle(color: Colors.white, fontSize: 22),
            ),
            Text(
              "Điểm số: ${winner.score} - Thẻ đã mua: ${winner.purchasedCards.length}",
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                SoundManager().playClick();
                Navigator.pop(context);
                SoundManager().playBGM();
              },
              icon: const Icon(Icons.refresh, color: Colors.black),
              label: const Text(
                "QUAY VỀ MENU",
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // SUB WIDGETS
  // =========================

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
      Player? botLeft, Player? botRight, double boardHeight) {
    return Row(
      children: [
        SizedBox(
            width: 95,
            child: botLeft != null
                ? Center(child: _buildVerticalPlayerProfile(botLeft))
                : null),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Expanded(flex: 72, child: _buildCardMatrix(boardHeight)),
                const SizedBox(width: 4),
                Expanded(
                    flex: 28,
                    child: Container(
                        key: _nobleColumnKey,
                        child: _buildNobleColumn(boardHeight))),
              ],
            ),
          ),
        ),
        SizedBox(
            width: 95,
            child: botRight != null
                ? Center(child: _buildVerticalPlayerProfile(botRight))
                : null),
      ],
    );
  }

  Widget _buildBottomBar(Player user, double barHeight) {
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
                Expanded(child: _buildTokenBank(barHeight)),
                const SizedBox(width: 8),
                if (!_game.mustDiscardToken)
                  GestureDetector(
                    onTap: () {
                      if (!_checkTurn()) return;
                      SoundManager().playClick();
                      setState(() {
                        if (_game.currentTurnTokens.isNotEmpty) {
                          _game.cancelSelection();
                        }
                        isReserveMode = !isReserveMode;
                      });
                    },
                    onLongPress: () => _showReservedDialog(context, user),
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
                      child: Icon(
                        isReserveMode ? Icons.lock_open : Icons.lock,
                        color: isReserveMode ? Colors.black : Colors.amber,
                      ),
                    ),
                  ),
                if (_game.currentTurnTokens.isNotEmpty &&
                    !_game.mustDiscardToken) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _game.cancelSelection()),
                    child: Container(
                      width: barHeight * 0.7,
                      height: barHeight * 0.7,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (!_checkTurn()) return;
                      final tokensToAnimate =
                          List<GemType>.from(_game.currentTurnTokens);
                      final success = _game.confirmSelection();
                      if (success) {
                        _showTopToast("Đã lấy token!", color: Colors.green);
                        for (int i = 0; i < tokensToAnimate.length; i++) {
                          Future.delayed(Duration(milliseconds: i * 100), () {
                            if (!mounted) return;
                            _playTokenAnimation(tokensToAnimate[i]);
                          });
                        }
                      } else {
                        _showTopToast("Chọn thêm token!", color: Colors.orange);
                      }
                    },
                    child: Container(
                      width: barHeight * 0.7,
                      height: barHeight * 0.7,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
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

  Widget _buildTokenBank(double height) {
    final order = [
      GemType.gold,
      GemType.white,
      GemType.blue,
      GemType.green,
      GemType.red,
      GemType.black
    ];
    final tokenSize = height * 0.75;

    return ListView.builder(
      key: _tokenBankKey,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: order.length,
      itemBuilder: (context, index) {
        final type = order[index];
        final selectedCount =
            _game.currentTurnTokens.where((t) => t == type).length;
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
                    count: _game.bankTokens[type] ?? 0,
                    size: tokenSize,
                    onTap: () {
                      if (isGold) {
                        _showTopToast("Dùng nút ổ khóa để Giam thẻ & Lấy vàng!",
                            color: Colors.amber);
                        SoundManager().playError();
                        return;
                      }
                      if (!_checkTurn()) return;
                      if (isReserveMode) setState(() => isReserveMode = false);
                      final error = _game.selectToken(type);
                      if (error != null) {
                        _showTopToast(error, color: Colors.orange);
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
                      child: Text(
                        "x$selectedCount",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10),
                      ),
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

  Widget _buildCardMatrix(double availableHeight) {
    final rowHeight = availableHeight / 3;
    final cardWidth = rowHeight * 0.71;

    return FittedBox(
      fit: BoxFit.contain,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCardRow(3, _game.visibleLevel3, cardWidth, rowHeight * 0.9),
          _buildCardRow(2, _game.visibleLevel2, cardWidth, rowHeight * 0.9),
          _buildCardRow(1, _game.visibleLevel1, cardWidth, rowHeight * 0.9),
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
          GestureDetector(
            onTap: () {
              // User: giam thẻ ẩn bằng cách bấm vào mặt sau ổ bài khi đang ở chế độ giam.
              if (!isReserveMode) {
                _showTopToast("Bật chế độ Giam (nút ổ khóa) để giam thẻ ẨN.",
                    color: Colors.amber);
                SoundManager().playError();
                return;
              }
              _confirmReserveHiddenFromDeck(level);
            },
            child: GameCardBackWidget(level: level, width: width),
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
                      begin: const Offset(-1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeInOut));
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

  Widget _buildNobleColumn(double availableHeight) {
    final nobleSize = min(availableHeight / 3.5, 60.0);
    return Center(
      child: SingleChildScrollView(
        child: Wrap(
          direction: Axis.horizontal,
          alignment: WrapAlignment.center,
          runSpacing: 4,
          spacing: 4,
          children: _game.visibleNobles
              .map((n) => NobleWidget(noble: n, size: nobleSize))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCompactPlayerProfile(Player player) {
    return TurnTimerWrapper(
      isMyTurn: player.isTurn,
      durationSeconds: widget.turnDuration,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: player.color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                  radius: 12,
                  backgroundColor: player.color,
                  child:
                      const Icon(Icons.person, size: 14, color: Colors.white)),
              const SizedBox(width: 6),
              Column(
                children: [
                  Text(player.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  Text("⭐${player.score}",
                      style:
                          const TextStyle(color: Colors.amber, fontSize: 10)),
                ],
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  _buildMiniStatsRow(player.tokens, isChip: true),
                  const SizedBox(height: 2),
                  Container(height: 1, width: 30, color: Colors.white12),
                  const SizedBox(height: 2),
                  _buildMiniStatsRow(player.bonuses, isChip: false),
                ],
              ),
              _buildNobleIndicator(player.nobleCount, isVertical: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalPlayerProfile(Player player) {
    return TurnTimerWrapper(
      isMyTurn: player.isTurn,
      durationSeconds: widget.turnDuration,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          width: 95,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: player.color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              CircleAvatar(
                  radius: 16,
                  backgroundColor: player.color,
                  child:
                      const Icon(Icons.person, size: 18, color: Colors.white)),
              Text(player.name,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              Text("⭐${player.score}",
                  style: const TextStyle(color: Colors.amber, fontSize: 12)),
              const SizedBox(height: 6),
              _buildGridAssets(player.tokens, isChip: true),
              const SizedBox(height: 4),
              Container(width: 40, height: 1, color: Colors.white12),
              const SizedBox(height: 4),
              _buildGridAssets(player.bonuses, isChip: false),
              _buildNobleIndicator(player.nobleCount, isVertical: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridAssets(Map<GemType, int> data, {required bool isChip}) {
    final order = [
      GemType.white,
      GemType.blue,
      GemType.green,
      GemType.red,
      GemType.black,
      if (isChip) GemType.gold
    ];

    return Wrap(
      spacing: 2,
      runSpacing: 2,
      alignment: WrapAlignment.center,
      children: order.map((type) {
        final val = data[type] ?? 0;
        final item = Container(
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
    return TurnTimerWrapper(
      isMyTurn: user.isTurn,
      durationSeconds: widget.turnDuration,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            CircleAvatar(
              radius: height * 0.22,
              backgroundColor: Colors.amber,
              child:
                  Icon(Icons.person, size: height * 0.25, color: Colors.black),
            ),
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
            if (user.reservedCards.isNotEmpty)
              GestureDetector(
                onTap: () => _showReservedDialog(context, user),
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.yellowAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: Colors.yellowAccent.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock,
                          color: Colors.yellowAccent, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        "${user.reservedCards.length}",
                        style: const TextStyle(
                            color: Colors.yellowAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
    final order = [
      GemType.white,
      GemType.blue,
      GemType.green,
      GemType.red,
      GemType.black,
      if (isChip) GemType.gold
    ];
    return Wrap(
      spacing: 1,
      runSpacing: 1,
      children: order
          .map((type) => _buildStatItem(type, data[type] ?? 0, isChip))
          .toList(),
    );
  }

  Widget _buildStatItem(GemType type, int val, bool isChip) {
    if (val == 0) return const SizedBox.shrink();
    return Container(
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
    );
  }

  Widget _buildUserAssetRow(Player player, Map<GemType, int> data,
      {required bool isChip}) {
    final order = [
      GemType.white,
      GemType.blue,
      GemType.green,
      GemType.red,
      GemType.black,
      if (isChip) GemType.gold
    ];

    return Row(
      children: order.map((type) {
        final val = data[type] ?? 0;
        final canDiscard = _game.mustDiscardToken && val > 0 && isChip;

        final item = Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 16,
          height: isChip ? 16 : 20,
          decoration: BoxDecoration(
            color: _getGemColor(type),
            shape: isChip ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isChip ? null : BorderRadius.circular(2),
            border: canDiscard
                ? Border.all(color: Colors.redAccent, width: 2)
                : null,
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

        if (canDiscard) {
          return GestureDetector(
            onTap: () {
              _game.returnTokenToBank(type);
              setState(() {});
            },
            child: item,
          );
        }
        return Opacity(opacity: val > 0 ? 1 : 0.3, child: item);
      }).toList(),
    );
  }
}
