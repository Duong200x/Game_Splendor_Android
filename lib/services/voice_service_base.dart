abstract class VoiceService {
  Future<void> init({
    required String channelId,
    required String myUid,
    required Function(String msg, {bool isError}) onMessage,
    required Function(double level) onVoiceLevel,
    required Function(bool joined) onJoinStatus,
  });

  void toggleMic(bool isMicOn);

  Future<void> dispose();

  bool get isJoined;
  bool get isMicOn;
}
