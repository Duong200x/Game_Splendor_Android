// Conditional import: web dùng stub, mobile dùng Agora implementation
import 'voice_service_stub.dart'
    if (dart.library.io) 'voice_service_mobile.dart';

export 'voice_service_stub.dart'
    if (dart.library.io) 'voice_service_mobile.dart';

/// Factory để tạo VoiceService đúng platform
VoiceService createVoiceService() => createPlatformVoiceService();
