import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'voice_service_stub.dart';

/// Agora implementation cho Android/iOS
class MobileVoiceService extends VoiceService {
  late RtcEngine _engine;
  bool _joined = false;
  bool _micOn = true;

  Function(String msg, {bool isError})? _onMessage;
  Function(double level)? _onVoiceLevel;
  Function(bool joined)? _onJoinStatus;

  @override
  bool get isJoined => _joined;

  @override
  bool get isMicOn => _micOn;

  @override
  Future<void> init({
    required String channelId,
    required String myUid,
    required Function(String msg, {bool isError}) onMessage,
    required Function(double level) onVoiceLevel,
    required Function(bool joined) onJoinStatus,
  }) async {
    _onMessage = onMessage;
    _onVoiceLevel = onVoiceLevel;
    _onJoinStatus = onJoinStatus;

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      onMessage('Cần cấp quyền Microphone!', isError: true);
      return;
    }

    const vercelApiUrl =
        'https://agora-token-server-omega.vercel.app/api/token';
    final agoraUid = myUid.hashCode.abs() % 100000000;

    String token;
    String appId;
    try {
      final response = await http.post(
        Uri.parse(vercelApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'channelName': channelId, 'uid': agoraUid}),
      );
      if (response.statusCode != 200) {
        throw Exception('API ${response.statusCode}');
      }
      final data = jsonDecode(response.body);
      token = data['token'] as String;
      appId = data['appId'] as String;
    } catch (e) {
      onMessage('Không thể kết nối Voice Chat!', isError: true);
      return;
    }

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (_, __) {
        _joined = true;
        _onJoinStatus?.call(true);
        _onMessage?.call('🎤 Voice Chat đã kết nối!');
      },
      onUserJoined: (_, __, ___) => _onMessage?.call('🔊 Có người vào voice!'),
      onError: (err, msg) => _onMessage?.call('Lỗi Voice: $msg', isError: true),
      onAudioVolumeIndication: (_, speakers, __, ___) {
        for (final s in speakers) {
          if (s.uid == 0) {
            _onVoiceLevel?.call(((s.volume ?? 0) / 255).clamp(0.0, 1.0));
            break;
          }
        }
      },
    ));

    await _engine.enableAudio();
    await _engine.enableLocalAudio(true);
    await _engine.muteAllRemoteAudioStreams(false);
    try {
      await _engine.setEnableSpeakerphone(true);
    } catch (_) {}
    await _engine.adjustPlaybackSignalVolume(400);
    await _engine.adjustRecordingSignalVolume(200);
    await _engine.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioGameStreaming,
    );
    await _engine.enableAudioVolumeIndication(
        interval: 200, smooth: 3, reportVad: true);
    await _engine.joinChannel(
      token: token,
      channelId: channelId,
      uid: agoraUid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
  }

  @override
  void toggleMic(bool isMicOn) {
    _micOn = isMicOn;
    try {
      _engine.muteLocalAudioStream(!isMicOn);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    try {
      await _engine.leaveChannel();
      await _engine.release();
    } catch (_) {}
    _joined = false;
  }
}

/// Factory cho mobile
VoiceService createPlatformVoiceService() => MobileVoiceService();
