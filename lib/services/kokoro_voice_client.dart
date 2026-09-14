import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

/// Client service for Kokoro-82M Neural Voice Synthesis (af_heart mascot).
/// Handles server streaming from Callisto (https://hardcode.academy/api/voice),
/// persistent local audio caching via Hive, and audio playback via AudioPlayer.
class KokoroVoiceClient {
  KokoroVoiceClient._internal();
  static final KokoroVoiceClient instance = KokoroVoiceClient._internal();

  static const String defaultBaseUrl = 'https://hardcode.academy';
  static const String _audioCacheBoxName = 'kokoro_audio_cache';

  String _baseUrl = defaultBaseUrl;
  String get baseUrl => _baseUrl;
  set baseUrl(String url) => _baseUrl = url.replaceAll(RegExp(r'/+$'), '');

  AudioPlayer? _player;
  final Map<String, Uint8List> _memCache = {};
  Box? _cacheBox;
  bool _isInitialized = false;

  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPaused = ValueNotifier<bool>(false);
  VoidCallback? _onCompleteCallback;
  StreamSubscription? _playerCompleteSub;
  StreamSubscription? _playerStateSub;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (Hive.isBoxOpen(_audioCacheBoxName)) {
        _cacheBox = Hive.box(_audioCacheBoxName);
      } else {
        _cacheBox = await Hive.openBox(_audioCacheBoxName).timeout(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('KokoroVoiceClient Hive cache init notice: $e');
    }

    try {
      _player ??= AudioPlayer();
      _playerCompleteSub = _player!.onPlayerComplete.listen((_) {
        _handlePlaybackFinished();
      });

      _playerStateSub = _player!.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.playing) {
          isPlaying.value = true;
          isPaused.value = false;
        } else if (state == PlayerState.paused) {
          isPlaying.value = true;
          isPaused.value = true;
        } else if (state == PlayerState.stopped || state == PlayerState.completed) {
          isPlaying.value = false;
          isPaused.value = false;
        }
      });
    } catch (e) {
      debugPrint('KokoroVoiceClient AudioPlayer init notice: $e');
    }

    _isInitialized = true;
  }

  void _handlePlaybackFinished() {
    isPlaying.value = false;
    isPaused.value = false;
    final callback = _onCompleteCallback;
    _onCompleteCallback = null;
    callback?.call();
  }

  /// Computes a deterministic SHA-256 cache key for text, voice, and speed.
  static String computeCacheKey(String text, String voice, double speed) {
    final raw = '${voice}_${speed.toStringAsFixed(2)}_${text.trim()}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// Fetches neural audio from local cache or Callisto server.
  /// Returns null if network request fails or times out (enabling offline fallback).
  Future<Uint8List?> fetchAudioBytes(
    String text, {
    String voice = 'af_heart',
    double speed = 1.0,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return null;

    final key = computeCacheKey(clean, voice, speed);

    // 1. Check in-memory cache
    if (_memCache.containsKey(key)) {
      return _memCache[key];
    }

    // 2. Check persistent Hive cache
    if (_cacheBox != null) {
      try {
        final cached = _cacheBox!.get(key);
        if (cached is List<int>) {
          final bytes = Uint8List.fromList(cached);
          _memCache[key] = bytes;
          return bytes;
        } else if (cached is String) {
          final bytes = base64Decode(cached);
          _memCache[key] = bytes;
          return bytes;
        }
      } catch (e) {
        debugPrint('KokoroVoiceClient cache read notice: $e');
      }
    }

    // 3. Fetch from Callisto server
    try {
      final uri = Uri.parse('$_baseUrl/api/voice/synthesize').replace(
        queryParameters: {
          'text': clean,
          'voice': voice,
          'speed': speed.toStringAsFixed(2),
        },
      );

      final response = await http.get(uri).timeout(timeout);

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        _memCache[key] = bytes;

        // Persist to Hive cache
        if (_cacheBox != null) {
          try {
            await _cacheBox!.put(key, base64Encode(bytes));
          } catch (e) {
            debugPrint('KokoroVoiceClient cache write notice: $e');
          }
        }

        return bytes;
      }
    } catch (e) {
      debugPrint('KokoroVoiceClient fetch notice: $e (falling back to device TTS)');
    }

    return null;
  }

  /// Plays audio bytes through the cross-platform AudioPlayer.
  Future<bool> playAudioBytes(Uint8List bytes, {VoidCallback? onComplete}) async {
    try {
      await stop();
      _onCompleteCallback = onComplete;
      isPlaying.value = true;
      isPaused.value = false;

      _player ??= AudioPlayer();
      await _player!.play(BytesSource(bytes));
      return true;
    } catch (e) {
      debugPrint('KokoroVoiceClient playAudioBytes error: $e');
      _handlePlaybackFinished();
      return false;
    }
  }

  Future<void> pause() async {
    if (!isPlaying.value || isPaused.value) return;
    try {
      await _player?.pause();
      isPaused.value = true;
    } catch (e) {
      debugPrint('KokoroVoiceClient pause error: $e');
    }
  }

  Future<void> resume() async {
    if (!isPaused.value) return;
    try {
      await _player?.resume();
      isPaused.value = false;
    } catch (e) {
      debugPrint('KokoroVoiceClient resume error: $e');
    }
  }

  Future<void> stop() async {
    _onCompleteCallback = null;
    isPlaying.value = false;
    isPaused.value = false;
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('KokoroVoiceClient stop error: $e');
    }
  }

  void dispose() {
    _playerCompleteSub?.cancel();
    _playerStateSub?.cancel();
    _player?.dispose();
  }
}
