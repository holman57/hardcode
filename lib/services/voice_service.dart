import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Cross-platform Voice Synthesis & Narration Service for HardCode.
/// Provides prioritized female voice synthesis on Web and Android,
/// intelligent speech duration approximation, code-to-speech sanitization,
/// and reactive state for synchronized pedagogical UI timers.
class VoiceService {
  VoiceService._internal();
  static final VoiceService instance = VoiceService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isMuted = false;

  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);
  VoidCallback? _activeCompletionCallback;
  Timer? _fallbackCompletionTimer;

  bool get isMuted => _isMuted;
  bool get isInitialized => _isInitialized;

  /// Initializes the TTS engine with female voice prioritization and pitch modulation.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _tts.setLanguage('en-US');

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
          ],
        );
      }

      await _configureFemaleVoice();

      _tts.setStartHandler(() {
        isSpeaking.value = true;
      });

      _tts.setCompletionHandler(() {
        _handleSpeechFinished();
      });

      _tts.setCancelHandler(() {
        _handleSpeechFinished();
      });

      _tts.setErrorHandler((dynamic msg) {
        debugPrint('VoiceService TTS error: $msg');
        _handleSpeechFinished();
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('VoiceService initialization error: $e');
    }
  }

  void _handleSpeechFinished() {
    _fallbackCompletionTimer?.cancel();
    _fallbackCompletionTimer = null;
    isSpeaking.value = false;
    final callback = _activeCompletionCallback;
    _activeCompletionCallback = null;
    callback?.call();
  }

  /// Automatically discovers and selects an English female voice, falling back to
  /// formant pitch modulation (1.18) so any system voice sounds feminine.
  Future<void> _configureFemaleVoice() async {
    try {
      final rawVoices = await _tts.getVoices;
      if (rawVoices is List && rawVoices.isNotEmpty) {
        dynamic selectedFemaleVoice;

        for (final v in rawVoices) {
          if (v is Map) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            final locale = (v['locale'] ?? v['lang'] ?? '').toString().toLowerCase();

            final isEnglish = locale.startsWith('en') ||
                name.contains('en-') ||
                name.contains('english') ||
                name.contains('us');
            if (!isEnglish) continue;

            final isFemale = name.contains('female') ||
                name.contains('zira') ||
                name.contains('samantha') ||
                name.contains('karen') ||
                name.contains('victoria') ||
                name.contains('jenny') ||
                name.contains('aria') ||
                name.contains('cora') ||
                name.contains('susan') ||
                name.contains('eva');

            if (isFemale) {
              selectedFemaleVoice = v;
              break;
            }
          }
        }

        if (selectedFemaleVoice != null) {
          final voiceMap = Map<String, String>.from(
            selectedFemaleVoice.map(
              (key, val) => MapEntry(key.toString(), val.toString()),
            ),
          );
          await _tts.setVoice(voiceMap);
          debugPrint('VoiceService: Selected female voice "${voiceMap['name']}"');
        }
      }
    } catch (e) {
      debugPrint('VoiceService: Female voice discovery notice: $e');
    }

    // Modulate formant pitch to 1.18 to ensure a crisp, pleasant female timbre
    // on Android, Web, and iOS even if the platform defaults to a generic voice.
    await _tts.setPitch(1.18);
    // 0.50 rate provides articulate ~140 words-per-minute educational cadence.
    await _tts.setSpeechRate(0.50);
  }

  /// Toggles global voice narration mute.
  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      stop();
    }
  }

  /// Sets explicit mute state.
  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted) {
      stop();
    }
  }

  /// Calculates estimated speech duration in seconds for a given text payload.
  /// Based on ~2.33 words per second (140 WPM at speech rate 0.50) + 3s buffer.
  static int estimateSpeechDurationSeconds(String text) {
    final cleaned = cleanTextForSpeech(text);
    if (cleaned.trim().isEmpty) return 4;

    final words = cleaned.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final int estimated = (words / 2.33).ceil() + 3;
    return estimated.clamp(4, 90);
  }

  /// Cleans markdown symbols, code syntax, and operators into natural spoken English.
  static String cleanTextForSpeech(String text) {
    var cleaned = text;

    // Remove markdown code blocks & inline backticks
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```'), ' code example omitted. ');
    cleaned = cleaned.replaceAll('`', '');

    // Translate common programming tokens to natural spoken English
    cleaned = cleaned.replaceAll('->', ' returns ');
    cleaned = cleaned.replaceAll('=>', ' maps to ');
    cleaned = cleaned.replaceAll('::', ' path ');
    cleaned = cleaned.replaceAll('&&', ' and ');
    cleaned = cleaned.replaceAll('||', ' or ');
    cleaned = cleaned.replaceAll('==', ' equals ');
    cleaned = cleaned.replaceAll('!=', ' not equals ');
    cleaned = cleaned.replaceAll('&mut', ' mutable reference to ');
    cleaned = cleaned.replaceAll('let mut', ' let mute ');
    cleaned = cleaned.replaceAll('fn', ' function ');
    cleaned = cleaned.replaceAll('println!', ' print line macro ');

    // Clean markdown headings, bold, bullet points
    cleaned = cleaned.replaceAll(RegExp(r'#+\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'^[-*•]\s+', multiLine: true), '');

    // Normalize excess whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Vocalizes a question prompt upon generation.
  Future<void> speakQuestion(String prompt) async {
    if (_isMuted || prompt.trim().isEmpty) return;
    if (!_isInitialized) await init();

    final cleaned = cleanTextForSpeech(prompt);
    if (cleaned.isEmpty) return;

    await stop();

    try {
      isSpeaking.value = true;
      final int estSeconds = estimateSpeechDurationSeconds(cleaned);
      // Fallback safety timer in case the browser fails to fire completion
      _fallbackCompletionTimer?.cancel();
      _fallbackCompletionTimer = Timer(Duration(seconds: estSeconds + 2), () {
        if (isSpeaking.value) {
          _handleSpeechFinished();
        }
      });

      await _tts.speak(cleaned);
    } catch (e) {
      debugPrint('VoiceService speakQuestion error: $e');
      _handleSpeechFinished();
    }
  }

  /// Vocalizes a tailored pedagogical explanation and calls [onComplete] when finished.
  Future<void> speakExplanation(
    String explanationText, {
    VoidCallback? onComplete,
  }) async {
    if (_isMuted || explanationText.trim().isEmpty) {
      onComplete?.call();
      return;
    }
    if (!_isInitialized) await init();

    final cleaned = cleanTextForSpeech(explanationText);
    if (cleaned.isEmpty) {
      onComplete?.call();
      return;
    }

    await stop();
    _activeCompletionCallback = onComplete;

    try {
      isSpeaking.value = true;
      final int estSeconds = estimateSpeechDurationSeconds(cleaned);
      // Fallback safety timer in case browser completion handler drops
      _fallbackCompletionTimer?.cancel();
      _fallbackCompletionTimer = Timer(Duration(seconds: estSeconds + 3), () {
        if (isSpeaking.value) {
          _handleSpeechFinished();
        }
      });

      await _tts.speak(cleaned);
    } catch (e) {
      debugPrint('VoiceService speakExplanation error: $e');
      _handleSpeechFinished();
    }
  }

  /// Immediately halts any ongoing speech.
  Future<void> stop() async {
    _fallbackCompletionTimer?.cancel();
    _fallbackCompletionTimer = null;
    isSpeaking.value = false;
    _activeCompletionCallback = null;

    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('VoiceService stop error: $e');
    }
  }
}
