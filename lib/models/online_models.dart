import 'game_entities.dart';

String gemToString(GemType type) => type.toString().split('.').last;
GemType stringToGem(String str) =>
    GemType.values.firstWhere((e) => e.toString().split('.').last == str,
        orElse: () => GemType.white);

class OnlinePlayerState {
  final String id;
  final String name;
  final String? avatarUrl;
  int lastActionTurnId;

  // Cho phép update (bỏ final)
  int score;
  Map<GemType, int> tokens;
  Map<GemType, int> bonuses;
  List<String> purchasedCardIds;
  List<String> reservedCardIds;
  List<String> nobleIds;

  OnlinePlayerState({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.score,
    required this.tokens,
    required this.bonuses,
    required this.purchasedCardIds,
    required this.reservedCardIds,
    required this.nobleIds,
    required this.lastActionTurnId,
  });

  static Map<String, dynamic> fromPlayer(Player player) {
    return {
      'id': player.id,
      'name': player.name,
      'score': player.score,
      'tokens': player.tokens.map((k, v) => MapEntry(gemToString(k), v)),
      'bonuses': player.bonuses.map((k, v) => MapEntry(gemToString(k), v)),
      'purchasedCardIds': player.purchasedCards.map((c) => c.id).toList(),
      'reservedCardIds': player.reservedCards.map((c) => c.id).toList(),
      'nobleIds': player.nobles.map((n) => n.id).toList(),
    };
  }

  factory OnlinePlayerState.fromJson(Map<String, dynamic> json) {
    return OnlinePlayerState(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      avatarUrl: json['avatarUrl'],
      score: json['score'] ?? 0,
      tokens: (json['tokens'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(stringToGem(k), (v as num).toInt()),
          ) ??
          {},
      bonuses: (json['bonuses'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(stringToGem(k), (v as num).toInt()),
          ) ??
          {},
      purchasedCardIds: List<String>.from(json['purchasedCardIds'] ?? []),
      reservedCardIds: List<String>.from(json['reservedCardIds'] ?? []),
      nobleIds: List<String>.from(json['nobleIds'] ?? []),
      lastActionTurnId: json['lastActionTurnId'] ?? -1,
    );
  }
}

class GameStateSnapshot {
  int currentPlayerIndex;
  Map<GemType, int> bankTokens;
  int turnId;
  List<String> visibleLevel1;
  List<String> visibleLevel2;
  List<String> visibleLevel3;
  List<String> visibleNobles;
  List<OnlinePlayerState> players;
  int turnEndTime;
  String? winnerId;

  GameStateSnapshot({
    required this.currentPlayerIndex,
    required this.turnId,
    required this.bankTokens,
    required this.visibleLevel1,
    required this.visibleLevel2,
    required this.visibleLevel3,
    required this.visibleNobles,
    required this.players,
    required this.turnEndTime,
    this.winnerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'currentPlayerIndex': currentPlayerIndex,
      'turnId': turnId,
      'bankTokens': bankTokens.map((k, v) => MapEntry(gemToString(k), v)),
      'visibleLevel1': visibleLevel1,
      'visibleLevel2': visibleLevel2,
      'visibleLevel3': visibleLevel3,
      'visibleNobles': visibleNobles,
      'players': players
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'avatarUrl': p.avatarUrl,
                'score': p.score,
                'tokens': p.tokens.map((k, v) => MapEntry(gemToString(k), v)),
                'bonuses': p.bonuses.map((k, v) => MapEntry(gemToString(k), v)),
                'purchasedCardIds': p.purchasedCardIds,
                'reservedCardIds': p.reservedCardIds,
                'nobleIds': p.nobleIds,
                'lastActionTurnId': p.lastActionTurnId,
              })
          .toList(),
      'turnEndTime': turnEndTime,
      'winnerId': winnerId,
    };
  }

  factory GameStateSnapshot.fromJson(Map<String, dynamic> json) {
    var playersList = (json['players'] as List<dynamic>?) ?? [];
    return GameStateSnapshot(
      currentPlayerIndex: json['currentPlayerIndex'] ?? 0,
      turnId: json['turnId'] ?? 0,
      bankTokens: (json['bankTokens'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(stringToGem(k), (v as num).toInt()),
          ) ??
          {},
      visibleLevel1: List<String>.from(json['visibleLevel1'] ?? []),
      visibleLevel2: List<String>.from(json['visibleLevel2'] ?? []),
      visibleLevel3: List<String>.from(json['visibleLevel3'] ?? []),
      visibleNobles: List<String>.from(json['visibleNobles'] ?? []),
      players: playersList.map((p) => OnlinePlayerState.fromJson(p)).toList(),
      turnEndTime: json['turnEndTime'] ?? 0,
      winnerId: json['winnerId'],
    );
  }
}
