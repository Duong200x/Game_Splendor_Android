/// Abstract interface cho Voice Chat — dùng chung cho cả web và mobile
abstract class VoiceService {
  /// Khởi tạo và join channel voice
  Future<void> init({
    required String channelId,
    required String myUid,
    required Function(String msg, {bool isError}) onMessage,
    required Function(double level) onVoiceLevel,
    required Function(bool joined) onJoinStatus,
  });

  /// Bật/tắt mic
  void toggleMic(bool isMicOn);

  /// Giải phóng tài nguyên
  Future<void> dispose();

  bool get isJoined;
  bool get isMicOn;
}

/// Factory — được override bởi file cụ thể (stub/mobile)
VoiceService createPlatformVoiceService() =>
    throw UnimplementedError('No VoiceService implementation found');
