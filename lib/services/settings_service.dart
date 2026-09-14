import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Central configuration & preferences service for HardCode Academy.
/// Persists voice synthesis options, audio levels, and future gameplay/accessibility
/// preferences to the local Hive database with reactive ChangeNotifier state updates.
class SettingsService extends ChangeNotifier {
  SettingsService._internal();
  static final SettingsService instance = SettingsService._internal();

  static const String _settingsKey = 'app_settings';
  static const String _userMemoryBoxName = 'user_memory';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // --- Voice & Narration Preferences ---
  bool _voiceEnabled = true;
  String _voiceEngine = 'kokoro'; // 'kokoro' (Neural Mascot) or 'system' (Local Device TTS)
  String _kokoroVoice = 'af_heart'; // Flagship Kokoro-82M female mascot voice
  double _voiceSpeed = 1.0; // 1.0x normal conversational pace (~190 WPM)
  double _voicePitch = 1.15; // 1.15 feminine mascot timbre
  double _voiceVolume = 1.0; // 100% volume
  String? _selectedVoiceName;
  String? _selectedVoiceLocale;

  // --- Extensible Gameplay & Learning Preferences (for future updates) ---
  int _timerDurationSeconds = 20;
  bool _soundFxEnabled = true;
  bool _hapticsEnabled = true;
  bool _highContrastMode = false;

  // Getters
  bool get voiceEnabled => _voiceEnabled;
  String get voiceEngine => _voiceEngine;
  String get kokoroVoice => _kokoroVoice;
  bool get isKokoroEngine => _voiceEngine == 'kokoro';
  double get voiceSpeed => _voiceSpeed;
  double get voicePitch => _voicePitch;
  double get voiceVolume => _voiceVolume;
  String? get selectedVoiceName => _selectedVoiceName;
  String? get selectedVoiceLocale => _selectedVoiceLocale;

  int get timerDurationSeconds => _timerDurationSeconds;
  bool get soundFxEnabled => _soundFxEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get highContrastMode => _highContrastMode;

  /// Initializes the settings service from the local Hive box if available.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (Hive.isBoxOpen(_userMemoryBoxName)) {
        final box = Hive.box(_userMemoryBoxName);
        final raw = box.get(_settingsKey);
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          _voiceEnabled = data['voiceEnabled'] as bool? ?? true;
          _voiceEngine = data['voiceEngine'] as String? ?? 'kokoro';
          _kokoroVoice = data['kokoroVoice'] as String? ?? 'af_heart';
          _voiceSpeed = ((data['voiceSpeed'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 2.0);
          _voicePitch = ((data['voicePitch'] as num?)?.toDouble() ?? 1.15).clamp(0.5, 1.5);
          _voiceVolume = ((data['voiceVolume'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0);
          _selectedVoiceName = data['selectedVoiceName'] as String?;
          _selectedVoiceLocale = data['selectedVoiceLocale'] as String?;

          _timerDurationSeconds = (data['timerDurationSeconds'] as num?)?.toInt() ?? 20;
          _soundFxEnabled = data['soundFxEnabled'] as bool? ?? true;
          _hapticsEnabled = data['hapticsEnabled'] as bool? ?? true;
          _highContrastMode = data['highContrastMode'] as bool? ?? false;
        }
      }
    } catch (e) {
      debugPrint('SettingsService init notice: $e');
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Persists the current configuration to Hive.
  Future<void> _persist() async {
    try {
      if (Hive.isBoxOpen(_userMemoryBoxName)) {
        final box = Hive.box(_userMemoryBoxName);
        await box.put(_settingsKey, {
          'voiceEnabled': _voiceEnabled,
          'voiceEngine': _voiceEngine,
          'kokoroVoice': _kokoroVoice,
          'voiceSpeed': _voiceSpeed,
          'voicePitch': _voicePitch,
          'voiceVolume': _voiceVolume,
          'selectedVoiceName': _selectedVoiceName,
          'selectedVoiceLocale': _selectedVoiceLocale,
          'timerDurationSeconds': _timerDurationSeconds,
          'soundFxEnabled': _soundFxEnabled,
          'hapticsEnabled': _hapticsEnabled,
          'highContrastMode': _highContrastMode,
        });
      }
    } catch (e) {
      debugPrint('SettingsService persist notice: $e');
    }
  }

  // --- Setters with Reactive Notification and Persistence ---

  Future<void> setVoiceEnabled(bool enabled) async {
    if (_voiceEnabled == enabled) return;
    _voiceEnabled = enabled;
    notifyListeners();
    await _persist();
  }

  Future<void> toggleVoiceEnabled() async {
    await setVoiceEnabled(!_voiceEnabled);
  }

  Future<void> setVoiceEngine(String engine) async {
    if (_voiceEngine == engine) return;
    _voiceEngine = engine;
    notifyListeners();
    await _persist();
  }

  Future<void> setKokoroVoice(String voice) async {
    if (_kokoroVoice == voice) return;
    _kokoroVoice = voice;
    notifyListeners();
    await _persist();
  }

  Future<void> setVoiceSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0);
    if ((_voiceSpeed - clamped).abs() < 0.01) return;
    _voiceSpeed = clamped;
    notifyListeners();
    await _persist();
  }

  Future<void> setVoicePitch(double pitch) async {
    final clamped = pitch.clamp(0.5, 1.5);
    if ((_voicePitch - clamped).abs() < 0.01) return;
    _voicePitch = clamped;
    notifyListeners();
    await _persist();
  }

  Future<void> setVoiceVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    if ((_voiceVolume - clamped).abs() < 0.01) return;
    _voiceVolume = clamped;
    notifyListeners();
    await _persist();
  }

  Future<void> setSelectedVoice(String? name, [String? locale]) async {
    if (_selectedVoiceName == name && _selectedVoiceLocale == locale) return;
    _selectedVoiceName = name;
    _selectedVoiceLocale = locale;
    notifyListeners();
    await _persist();
  }

  /// Resets voice options back to optimal female mascot defaults.
  Future<void> resetVoiceToMascotDefaults() async {
    _voiceEnabled = true;
    _voiceEngine = 'kokoro';
    _kokoroVoice = 'af_heart';
    _voiceSpeed = 1.0;
    _voicePitch = 1.15;
    _voiceVolume = 1.0;
    _selectedVoiceName = null;
    _selectedVoiceLocale = null;
    notifyListeners();
    await _persist();
  }

  // Future Extensibility Setters
  Future<void> setTimerDuration(int seconds) async {
    if (_timerDurationSeconds == seconds) return;
    _timerDurationSeconds = seconds;
    notifyListeners();
    await _persist();
  }

  Future<void> setSoundFxEnabled(bool enabled) async {
    if (_soundFxEnabled == enabled) return;
    _soundFxEnabled = enabled;
    notifyListeners();
    await _persist();
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    if (_hapticsEnabled == enabled) return;
    _hapticsEnabled = enabled;
    notifyListeners();
    await _persist();
  }

  Future<void> setHighContrastMode(bool enabled) async {
    if (_highContrastMode == enabled) return;
    _highContrastMode = enabled;
    notifyListeners();
    await _persist();
  }
}
