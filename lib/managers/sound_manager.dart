import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal() {
    _initPool();
  }

  // ======================
  // VOLUME (HomeScreen cần)
  // ======================
  double _bgmVolume = 0.6;
  double _sfxVolume = 1.0;

  double get bgmVolume => _bgmVolume;
  double get sfxVolume => _sfxVolume;

  void setBGMVolume(double value) {
    _bgmVolume = value.clamp(0.0, 1.0);
    _bgmPlayer.setVolume(_bgmVolume);
  }

  void setSFXVolume(double value) {
    _sfxVolume = value.clamp(0.0, 1.0);
    // pool sẽ set volume mỗi lần play
  }

  // ======================
  // PLAYERS
  // ======================
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final List<AudioPlayer> _sfxPool = [];
  int _poolIndex = 0;

  // tăng lên để hạn chế stop/cắt tiếng khi spam
  static const int _poolSize = 8;

  // ======================
  // THROTTLE (giảm spam SFX)
  // ======================
  final Map<String, int> _minIntervalMsByKey = {
    'click': 60,
    'token': 80,
    'buy': 120,
    'error': 140,
    'win': 250,
  };

  final Map<String, int> _lastPlayMsByKey = {};
  int _lastAnySfxMs = 0;
  static const int _minAnySfxGapMs = 30;

  // ======================
  // INIT
  // ======================
  void _initPool() {
    _sfxPool.clear();
    for (int i = 0; i < _poolSize; i++) {
      final p = AudioPlayer();
      p.setReleaseMode(ReleaseMode.stop);
      _sfxPool.add(p);
    }
    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    _bgmPlayer.setVolume(_bgmVolume);
  }

  // ======================
  // PUBLIC API (cũ + mới)
  // ======================
  Future<void> playBGM() async {
    try {
      // nếu đang chạy rồi thì thôi
      if (_bgmPlayer.state == PlayerState.playing) return;
      await _bgmPlayer.setVolume(_bgmVolume);
      await _bgmPlayer.play(AssetSource('audio/bmg.mp3'));
    } catch (_) {}
  }

  Future<void> stopBGM() async {
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  void playClick() => _playSfxGuard('click', 'audio/tap.mp3');
  void playToken() => _playSfxGuard('token', 'audio/token.mp3');
  void playBuy() => _playSfxGuard('buy', 'audio/buy.mp3');
  void playError() => _playSfxGuard('error', 'audio/error.mp3');
  void playWin() => _playSfxGuard('win', 'audio/win.mp3');
  void duckBGM() {
    _bgmPlayer.setVolume(0.25);
  }

  void restoreBGM() {
    _bgmPlayer.setVolume(1.0);
  }

  // ======================
  // CORE SFX
  // ======================
  void _playSfxGuard(String key, String assetPath) {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Global gap để tránh crackle khi bắn nhiều sound khác nhau cùng lúc
    if (now - _lastAnySfxMs < _minAnySfxGapMs) return;

    // Throttle theo key
    final lastKey = _lastPlayMsByKey[key] ?? 0;
    final minGap = _minIntervalMsByKey[key] ?? 80;
    if (now - lastKey < minGap) return;

    _lastAnySfxMs = now;
    _lastPlayMsByKey[key] = now;

    _playSfx(assetPath);
  }

  Future<void> _playSfx(String assetPath) async {
    try {
      final player = _pickPlayerPreferIdle();

      // set volume trước khi play
      await player.setVolume(_sfxVolume);

      // Nếu player đang play mà bị chọn (hiếm) thì stop nhẹ
      if (player.state == PlayerState.playing) {
        await player.stop();
      }

      await player.play(AssetSource(assetPath));
    } catch (_) {}
  }

  AudioPlayer _pickPlayerPreferIdle() {
    // 1) ưu tiên player đang idle
    for (int i = 0; i < _sfxPool.length; i++) {
      final idx = (_poolIndex + i) % _sfxPool.length;
      final p = _sfxPool[idx];
      if (p.state != PlayerState.playing) {
        _poolIndex = (idx + 1) % _sfxPool.length;
        return p;
      }
    }

    // 2) nếu tất cả đang play -> round-robin (phải stop 1 cái)
    final p = _sfxPool[_poolIndex];
    _poolIndex = (_poolIndex + 1) % _sfxPool.length;
    return p;
  }

  // ======================
  // CLEANUP (optional)
  // ======================
  Future<void> dispose() async {
    try {
      await _bgmPlayer.dispose();
    } catch (_) {}
    for (final p in _sfxPool) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }
}
