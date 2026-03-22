import 'package:flutter/material.dart';

// 1. Enum
enum GemType { white, blue, green, red, black, gold }

// 2. Class Thẻ bài
class DevCard {
  final String id;
  final int level;
  final int points;
  final GemType bonus;
  final Map<GemType, int> cost;
  final String assetPath;

  DevCard({
    required this.id,
    required this.level,
    required this.points,
    required this.bonus,
    required this.cost,
    this.assetPath = '',
  });

  // Alias cho logic cũ
  int get prestigePoints => points;
  GemType get gemType => bonus;
  GemType get bonusGem => bonus;
}

// 3. Class Quý tộc
class Noble {
  final String id;
  final int points;
  final Map<GemType, int> requirements;
  final String assetPath;

  Noble({
    required this.id,
    required this.points,
    required this.requirements,
    this.assetPath = '',
  });

  int get prestigePoints => points;
}

// 4. Class Người chơi
class Player {
  final String id;
  final String name;
  final Color color;
  final bool isHuman;

  bool isTurn;
  int score;
  Map<GemType, int> tokens;
  Map<GemType, int> bonuses;
  List<DevCard> purchasedCards;
  List<Noble> nobles;
  List<DevCard> reservedCards;

  // ✅ NEW: đánh dấu thẻ giam ẩn (theo id)
  final Set<String> _hiddenReservedCardIds;

  Player({
    required this.id,
    required this.name,
    required this.color,
    this.isHuman = false,
    this.isTurn = false,
    this.score = 0,
    Map<GemType, int>? tokens,
    Map<GemType, int>? bonuses,
    List<DevCard>? purchasedCards,
    List<Noble>? nobles,
    List<DevCard>? reservedCards,
    Set<String>? hiddenReservedCardIds,
  })  : tokens = tokens ?? {for (var g in GemType.values) g: 0},
        bonuses = bonuses ?? {for (var g in GemType.values) g: 0},
        purchasedCards = purchasedCards ?? [],
        nobles = nobles ?? [],
        reservedCards = reservedCards ?? [],
        _hiddenReservedCardIds = hiddenReservedCardIds ?? <String>{};

  int get nobleCount => nobles.length;

  int get totalTokenCount {
    int count = 0;
    tokens.forEach((_, v) => count += v);
    return count;
  }

  // ✅ NEW API cho UI: bot dùng để hiển thị lock hay thẻ thường
  bool isReservedHidden(DevCard card) => _hiddenReservedCardIds.contains(card.id);

  void markReservedHidden(DevCard card, bool hidden) {
    if (hidden) {
      _hiddenReservedCardIds.add(card.id);
    } else {
      _hiddenReservedCardIds.remove(card.id);
    }
  }

  void clearReservedHidden(DevCard card) {
    _hiddenReservedCardIds.remove(card.id);
  }
}
