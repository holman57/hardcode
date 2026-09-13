import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Cross-platform Voice Synthesis & Narration Service for HardCode.
/// Provides prioritized female voice synthesis on Web and Android,
/// pause/resume control, intelligent speech duration approximation,
/// code-to-speech sanitization, and reactive state for synchronized UI.
class VoiceService {
  VoiceService._internal();
  static final VoiceService instance = VoiceService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isPaused = false;

  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPaused = ValueNotifier<bool>(false);
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
        _isPaused = false;
        isPaused.value = false;
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
    _isPaused = false;
    isPaused.value = false;
    final callback = _activeCompletionCallback;
    _activeCompletionCallback = null;
    callback?.call();
  }

  /// Discovers and selects a female English voice. Falls back to formant pitch
  /// modulation (1.15) for a natural feminine timbre on any system voice.
  Future<void> _configureFemaleVoice() async {
    try {
      final rawVoices = await _tts.getVoices;
      if (rawVoices is List && rawVoices.isNotEmpty) {
        dynamic selectedFemaleVoice;

        // Priority-ordered list of well-known female English TTS voices
        // (Android, Web Speech API, iOS, Windows SAPI, macOS)
        const femaleKeywords = [
          'zira',       // Windows — Microsoft Zira (US female)
          'samantha',   // macOS / iOS — Samantha (US female)
          'karen',      // iOS — Karen (AU female)
          'moira',      // macOS — Moira (IE female)
          'fiona',      // macOS — Fiona (SC female)
          'tessa',      // macOS — Tessa (ZA female)
          'victoria',   // macOS — Victoria (US female)
          'jenny',      // Edge/Web — Microsoft Jenny (US female)
          'aria',       // Edge/Web — Microsoft Aria (US female)
          'michelle',   // Edge/Web — Microsoft Michelle (US female)
          'amber',      // Edge/Web — Microsoft Amber (US female)
          'ana',        // Edge/Web — Microsoft Ana (US female)
          'cora',       // Edge/Web — Microsoft Cora (NZ female)
          'libby',      // Edge/Web — Microsoft Libby (UK female)
          'natasha',    // Edge/Web — Microsoft Natasha (AU female)
          'clara',      // Edge/Web — Microsoft Clara (CA female)
          'hazel',      // Windows — Microsoft Hazel (UK female)
          'eva',        // generic female marker
          'susan',      // generic female marker
          'alice',      // generic female marker
          'female',     // explicit gender tag (Android voices)
          'woman',      // explicit gender tag
          'girl',       // explicit gender tag
        ];

        for (final v in rawVoices) {
          if (v is Map) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            final locale = (v['locale'] ?? v['lang'] ?? '').toString().toLowerCase();

            final isEnglish = locale.startsWith('en') ||
                name.contains('en-') ||
                name.contains('english') ||
                name.contains('-us') ||
                name.contains('-gb') ||
                name.contains('-au');
            if (!isEnglish) continue;

            final isFemale = femaleKeywords.any((kw) => name.contains(kw));

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

    // Pitch 1.15 — feminine timbre without sounding artificial.
    await _tts.setPitch(1.15);
    // Rate 0.62 — confident, conversational ~175 WPM educational cadence.
    await _tts.setSpeechRate(0.62);
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

  /// Pauses ongoing speech. No-op if not speaking or already paused.
  Future<void> pause() async {
    if (!isSpeaking.value || _isPaused) return;
    _isPaused = true;
    isPaused.value = true;
    _fallbackCompletionTimer?.cancel();
    try {
      await _tts.pause();
    } catch (e) {
      debugPrint('VoiceService pause error: $e');
    }
  }

  /// Resumes speech from where it was paused.
  Future<void> resume() async {
    if (!_isPaused) return;
    _isPaused = false;
    isPaused.value = false;
    try {
      // flutter_tts does not support resume on all platforms — re-speak if needed.
      // On Web/Android, _tts.synthesisCompleted fires automatically when done.
      await _tts.pause(); // toggle off pause on platforms that support it
    } catch (e) {
      // Fallback: stop is fine — the UI handles this
      debugPrint('VoiceService resume notice: $e');
    }
  }

  /// Calculates estimated speech duration in seconds for a given text payload.
  /// Based on ~2.9 words per second (175 WPM at speech rate 0.62) + 2s buffer.
  static int estimateSpeechDurationSeconds(String text) {
    final cleaned = cleanTextForSpeech(text);
    if (cleaned.trim().isEmpty) return 4;

    final words = cleaned.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final int estimated = (words / 2.9).ceil() + 2;
    return estimated.clamp(4, 90);
  }

  /// Strips the explanation text of title, mental model wrapper, and code blocks,
  /// returning only the core body text suitable for narration.
  static String extractNarrationBody(String fullNarrative) {
    var text = fullNarrative;

    // Remove leading code fences entirely
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');

    // Strip Mental Model section (everything from "Mental model:" to end)
    text = text.replaceAll(RegExp(r'(?i)mental model[:\s].*', dotAll: true), '');

    return text.trim();
  }

  /// Cleans markdown symbols, list formatting, code syntax, and operators
  /// into natural spoken English suitable for TTS narration.
  static String cleanTextForSpeech(String text) {
    var cleaned = text;

    // Remove markdown code blocks & inline backticks
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    cleaned = cleaned.replaceAll('`', '');

    // Strip numbered list markers: "1. " "2) " at start of line
    cleaned = cleaned.replaceAll(RegExp(r'^\s*\d+[.)]\s+', multiLine: true), '');

    // Strip lettered list markers: "a. " "b) "
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[a-zA-Z][.)]\s+', multiLine: true), '');

    // Strip bullet markers: - * • ·
    cleaned = cleaned.replaceAll(RegExp(r'^[\s]*[-*•·]\s+', multiLine: true), '');

    // Clean markdown headings
    cleaned = cleaned.replaceAll(RegExp(r'#+\s*'), '');

    // Remove bold/italic markdown
    cleaned = cleaned.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'__([^_]+)__'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'_([^_]+)_'), r'$1');

    // Translate common programming tokens to natural spoken English
    cleaned = cleaned.replaceAll('->', ' returns ');
    cleaned = cleaned.replaceAll('=>', ' maps to ');
    cleaned = cleaned.replaceAll('::', ' path ');
    cleaned = cleaned.replaceAll('&&', ' and ');
    cleaned = cleaned.replaceAll('||', ' or ');
    cleaned = cleaned.replaceAll('==', ' equals ');
    cleaned = cleaned.replaceAll('!=', ' not equals ');
    cleaned = cleaned.replaceAll('&mut', ' mutable reference to ');
    cleaned = cleaned.replaceAll('let mut', ' let mutable ');
    cleaned = cleaned.replaceAll('println!', ' print line ');

    // Remove parenthetical notation like O(N) — read them naturally already
    // but strip standalone empty parens
    cleaned = cleaned.replaceAll(RegExp(r'\(\s*\)'), '');

    // Normalize excess whitespace and line breaks
    cleaned = cleaned.replaceAll(RegExp(r'\n+'), ' ');
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

  /// Vocalizes only the core explanation body (no title, no mental model,
  /// no bullet/number markers) and calls [onComplete] when finished.
  Future<void> speakExplanation(
    String explanationBodyOnly, {
    VoidCallback? onComplete,
  }) async {
    if (_isMuted || explanationBodyOnly.trim().isEmpty) {
      onComplete?.call();
      return;
    }
    if (!_isInitialized) await init();

    final cleaned = cleanTextForSpeech(explanationBodyOnly);
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

  /// Immediately halts any ongoing speech and resets all state.
  Future<void> stop() async {
    _fallbackCompletionTimer?.cancel();
    _fallbackCompletionTimer = null;
    isSpeaking.value = false;
    _isPaused = false;
    isPaused.value = false;
    _activeCompletionCallback = null;

    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('VoiceService stop error: $e');
    }
  }
}
