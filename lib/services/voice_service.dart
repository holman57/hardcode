import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'kokoro_voice_client.dart';
import 'settings_service.dart';

/// Cross-platform Voice Synthesis & Narration Service for HardCode.
/// Provides prioritized female mascot voice synthesis on Web, iOS, and Android,
/// dynamic speed/pitch/volume customization via SettingsService,
/// pause/resume control, intelligent speech duration approximation,
/// code-to-speech sanitization, and reactive state for synchronized UI.
class VoiceService {
  VoiceService._internal();
  static final VoiceService instance = VoiceService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isPaused = false;
  List<Map<String, String>> _cachedVoices = [];

  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPaused = ValueNotifier<bool>(false);
  VoidCallback? _activeCompletionCallback;
  Timer? _fallbackCompletionTimer;

  bool get isMuted => _isMuted;
  bool get isInitialized => _isInitialized;
  List<Map<String, String>> get availableVoices => List.unmodifiable(_cachedVoices);

  /// Priority-ordered list of well-known female English TTS voices
  /// (Android, Web Speech API, iOS, Windows SAPI, macOS)
  static const List<String> femaleKeywords = [
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

  /// Initializes the TTS engine with female voice prioritization and pitch modulation.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize settings service first
      await SettingsService.instance.init();
      _isMuted = !SettingsService.instance.voiceEnabled;

      // Initialize Kokoro neural client
      await KokoroVoiceClient.instance.init();

      KokoroVoiceClient.instance.isPlaying.addListener(() {
        if (SettingsService.instance.isKokoroEngine) {
          isSpeaking.value = KokoroVoiceClient.instance.isPlaying.value;
        }
      });
      KokoroVoiceClient.instance.isPaused.addListener(() {
        if (SettingsService.instance.isKokoroEngine) {
          _isPaused = KokoroVoiceClient.instance.isPaused.value;
          isPaused.value = _isPaused;
        }
      });

      await _tts.setLanguage('en-US').timeout(const Duration(milliseconds: 600)).catchError((e) {
        debugPrint('VoiceService setLanguage notice: $e');
        return null;
      });

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
          ],
        ).catchError((_) {});
      }

      await _refreshAvailableVoices().timeout(const Duration(milliseconds: 800)).catchError((_) => <Map<String, String>>[]);
      await _applySettings(SettingsService.instance);

      // Listen for settings changes
      SettingsService.instance.addListener(() {
        _applySettings(SettingsService.instance);
      });

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

  /// Refreshes the cached list of available voices from the system.
  Future<List<Map<String, String>>> _refreshAvailableVoices() async {
    try {
      final rawVoices = await _tts.getVoices.timeout(const Duration(milliseconds: 800));
      if (rawVoices is List && rawVoices.isNotEmpty) {
        final List<Map<String, String>> parsed = [];
        for (final v in rawVoices) {
          if (v is Map) {
            final name = (v['name'] ?? '').toString();
            final locale = (v['locale'] ?? v['lang'] ?? '').toString();
            if (name.isNotEmpty) {
              parsed.add({'name': name, 'locale': locale});
            }
          }
        }
        _cachedVoices = parsed;
      }
    } catch (e) {
      debugPrint('VoiceService getVoices notice: $e');
    }
    return _cachedVoices;
  }

  /// Returns available voices, querying the TTS engine if cache is empty.
  Future<List<Map<String, String>>> getAvailableVoices() async {
    if (_cachedVoices.isEmpty) {
      await _refreshAvailableVoices();
    }
    return _cachedVoices;
  }

  /// Applies active configuration from SettingsService to the TTS engine.
  Future<void> _applySettings(SettingsService settings) async {
    _isMuted = !settings.voiceEnabled;
    if (_isMuted) {
      await stop();
    }

    try {
      // Speed (Speech Rate) - 1.0 is normal conversational rate (~190 WPM)
      await _tts.setSpeechRate(settings.voiceSpeed);
      // Pitch - 1.15 is pleasant feminine mascot timbre
      await _tts.setPitch(settings.voicePitch);
      // Volume - 0.0 to 1.0
      await _tts.setVolume(settings.voiceVolume);

      // Selected Voice
      if (settings.selectedVoiceName != null && settings.selectedVoiceName!.isNotEmpty) {
        await setVoiceByName(settings.selectedVoiceName!, settings.selectedVoiceLocale);
      } else {
        await _configureFemaleVoice();
      }
    } catch (e) {
      debugPrint('VoiceService _applySettings error: $e');
    }
  }

  /// Discovers and selects a female English voice. Falls back to formant pitch
  /// modulation (1.15) for a natural feminine timbre on any system voice.
  Future<void> _configureFemaleVoice() async {
    try {
      if (_cachedVoices.isEmpty) {
        await _refreshAvailableVoices();
      }

      if (_cachedVoices.isNotEmpty) {
        Map<String, String>? selectedFemaleVoice;

        for (final v in _cachedVoices) {
          final name = (v['name'] ?? '').toLowerCase();
          final locale = (v['locale'] ?? '').toLowerCase();

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

        if (selectedFemaleVoice != null) {
          await _tts.setVoice(selectedFemaleVoice);
          debugPrint('VoiceService: Auto-selected female mascot voice "${selectedFemaleVoice['name']}"');
        }
      }
    } catch (e) {
      debugPrint('VoiceService: Female voice discovery notice: $e');
    }
  }

  /// Explicitly selects a voice by name and optional locale.
  Future<void> setVoiceByName(String name, [String? locale]) async {
    try {
      if (_cachedVoices.isEmpty) {
        await _refreshAvailableVoices();
      }

      Map<String, String>? match;
      for (final v in _cachedVoices) {
        if (v['name'] == name) {
          match = v;
          break;
        }
      }

      match ??= {'name': name, 'locale': locale ?? 'en-US'};
      await _tts.setVoice(match);
      debugPrint('VoiceService: Explicitly set voice to "${match['name']}"');
    } catch (e) {
      debugPrint('VoiceService setVoiceByName notice: $e');
    }
  }

  /// Sets speech rate multiplier (e.g. 0.5 to 2.0).
  Future<void> setSpeechRate(double rate) async {
    await SettingsService.instance.setVoiceSpeed(rate);
  }

  /// Sets pitch multiplier (e.g. 0.5 to 1.5).
  Future<void> setPitch(double pitch) async {
    await SettingsService.instance.setVoicePitch(pitch);
  }

  /// Sets volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    await SettingsService.instance.setVoiceVolume(volume);
  }

  /// Toggles global voice narration mute.
  void toggleMute() {
    SettingsService.instance.toggleVoiceEnabled();
  }

  /// Sets explicit mute state.
  void setMuted(bool muted) {
    SettingsService.instance.setVoiceEnabled(!muted);
  }

  /// Pauses ongoing speech. No-op if not speaking or already paused.
  Future<void> pause() async {
    if (!isSpeaking.value || _isPaused) return;
    _isPaused = true;
    isPaused.value = true;
    _fallbackCompletionTimer?.cancel();
    try {
      if (SettingsService.instance.isKokoroEngine && KokoroVoiceClient.instance.isPlaying.value) {
        await KokoroVoiceClient.instance.pause();
      }
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
      if (SettingsService.instance.isKokoroEngine && KokoroVoiceClient.instance.isPaused.value) {
        await KokoroVoiceClient.instance.resume();
      }
      await _tts.pause(); // toggle off pause on platforms that support it
    } catch (e) {
      debugPrint('VoiceService resume notice: $e');
    }
  }

  /// Calculates estimated speech duration in seconds for a given text payload.
  /// Dynamically adjusts based on speech speed (1.0 = ~2.9 words/sec, 1.25x = ~3.6 words/sec).
  static int estimateSpeechDurationSeconds(String text, [double? speed]) {
    final cleaned = cleanTextForSpeech(text);
    if (cleaned.trim().isEmpty) return 4;

    final double effectiveSpeed = (speed ?? SettingsService.instance.voiceSpeed).clamp(0.5, 2.0);
    final words = cleaned.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final double wordsPerSecond = 2.9 * effectiveSpeed;
    final int estimated = (words / wordsPerSecond).ceil() + 2;
    return estimated.clamp(3, 90);
  }

  /// Strips the explanation text of title, mental model wrapper, and code blocks,
  /// returning only the core body text suitable for narration.
  static String extractNarrationBody(String fullNarrative) {
    var text = fullNarrative;

    // Remove leading code fences entirely
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');

    // Strip Mental Model section (case-insensitive in Dart using caseSensitive: false)
    text = text.replaceAll(RegExp(r'mental model[:\s].*', caseSensitive: false, dotAll: true), '');

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

  /// Optional background pre-fetch to warm cache for question explanations.
  Future<void> preheatSpeech(String text) async {
    if (_isMuted || !SettingsService.instance.isKokoroEngine) return;
    try {
      final cleaned = cleanTextForSpeech(text);
      if (cleaned.isNotEmpty) {
        unawaited(KokoroVoiceClient.instance.fetchAudioBytes(
          cleaned,
          voice: SettingsService.instance.kokoroVoice,
          speed: SettingsService.instance.voiceSpeed,
        ));
      }
    } catch (_) {}
  }

  /// Vocalizes a question prompt upon generation.
  Future<void> speakQuestion(String prompt) async {
    if (_isMuted || prompt.trim().isEmpty) return;
    if (!_isInitialized) await init();

    final cleaned = cleanTextForSpeech(prompt);
    if (cleaned.isEmpty) return;

    await stop();

    // 1. Try Kokoro Neural TTS (af_heart) if enabled
    if (SettingsService.instance.isKokoroEngine) {
      try {
        final audioBytes = await KokoroVoiceClient.instance.fetchAudioBytes(
          cleaned,
          voice: SettingsService.instance.kokoroVoice,
          speed: SettingsService.instance.voiceSpeed,
        );

        if (audioBytes != null && audioBytes.isNotEmpty) {
          isSpeaking.value = true;
          _isPaused = false;
          isPaused.value = false;

          final int estSeconds = estimateSpeechDurationSeconds(cleaned);
          _fallbackCompletionTimer?.cancel();
          _fallbackCompletionTimer = Timer(Duration(seconds: estSeconds + 4), () {
            if (isSpeaking.value) {
              _handleSpeechFinished();
            }
          });

          final played = await KokoroVoiceClient.instance.playAudioBytes(
            audioBytes,
            onComplete: () {
              _handleSpeechFinished();
            },
          );

          if (played) return;
        }
      } catch (e) {
        debugPrint('VoiceService Kokoro speakQuestion fallback notice: $e');
      }
    }

    // 2. Seamless Fallback: Native Device TTS (works 100% offline)
    try {
      isSpeaking.value = true;
      final int estSeconds = estimateSpeechDurationSeconds(cleaned);
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

    // 1. Try Kokoro Neural TTS (af_heart) if enabled
    if (SettingsService.instance.isKokoroEngine) {
      try {
        final audioBytes = await KokoroVoiceClient.instance.fetchAudioBytes(
          cleaned,
          voice: SettingsService.instance.kokoroVoice,
          speed: SettingsService.instance.voiceSpeed,
        );

        if (audioBytes != null && audioBytes.isNotEmpty) {
          isSpeaking.value = true;
          _isPaused = false;
          isPaused.value = false;

          final int estSeconds = estimateSpeechDurationSeconds(cleaned);
          _fallbackCompletionTimer?.cancel();
          _fallbackCompletionTimer = Timer(Duration(seconds: estSeconds + 4), () {
            if (isSpeaking.value) {
              _handleSpeechFinished();
            }
          });

          final played = await KokoroVoiceClient.instance.playAudioBytes(
            audioBytes,
            onComplete: () {
              _handleSpeechFinished();
            },
          );

          if (played) return;
        }
      } catch (e) {
        debugPrint('VoiceService Kokoro speakExplanation fallback notice: $e');
      }
    }

    // 2. Seamless Fallback: Native Device TTS
    try {
      isSpeaking.value = true;
      final int estSeconds = estimateSpeechDurationSeconds(cleaned);
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

  /// Vocalizes sample text for live preview in the Settings modal.
  Future<void> speakSample([String? sampleText]) async {
    final currentKokoro = SettingsService.instance.kokoroVoice;
    final String defaultSample;
    if (SettingsService.instance.isKokoroEngine) {
      switch (currentKokoro) {
        case 'af_bella':
          defaultSample = "Hi! I'm Bella. I bring a cheerful, dynamic energy to your HardCode drills!";
          break;
        case 'af_nicole':
          defaultSample = "Greetings. I'm Nicole, your smooth and focused guide to mastering algorithms.";
          break;
        case 'af_sarah':
          defaultSample = "Hello. I'm Sarah, providing clear and professional computer science narration.";
          break;
        case 'af_sky':
          defaultSample = "Hey there! I'm Sky, ready for bright, fast-paced coding challenges!";
          break;
        case 'af_heart':
        default:
          defaultSample = "Hello! I'm Ada, your HardCode Academy mascot. Let's master computer science together!";
          break;
      }
    } else {
      defaultSample = "Hello! I'm Ada, your HardCode Academy mascot. Let's master computer science together!";
    }

    final text = sampleText ?? defaultSample;
    if (!_isInitialized) await init();
    await stop();

    // 1. Try Kokoro Neural TTS if enabled
    if (SettingsService.instance.isKokoroEngine) {
      try {
        final audioBytes = await KokoroVoiceClient.instance.fetchAudioBytes(
          text,
          voice: SettingsService.instance.kokoroVoice,
          speed: SettingsService.instance.voiceSpeed,
        );

        if (audioBytes != null && audioBytes.isNotEmpty) {
          isSpeaking.value = true;
          _isPaused = false;
          isPaused.value = false;

          final int estSeconds = estimateSpeechDurationSeconds(text);
          _fallbackCompletionTimer?.cancel();
          _fallbackCompletionTimer = Timer(Duration(seconds: estSeconds + 4), () {
            if (isSpeaking.value) {
              _handleSpeechFinished();
            }
          });

          final played = await KokoroVoiceClient.instance.playAudioBytes(
            audioBytes,
            onComplete: () {
              _handleSpeechFinished();
            },
          );

          if (played) return;
        }
      } catch (e) {
        debugPrint('VoiceService Kokoro speakSample fallback notice: $e');
      }
    }

    // 2. Fallback to System Device TTS
    try {
      await _applySettings(SettingsService.instance);
      isSpeaking.value = true;
      final int estSeconds = estimateSpeechDurationSeconds(text);
      _fallbackCompletionTimer?.cancel();
      _fallbackCompletionTimer = Timer(Duration(seconds: estSeconds + 2), () {
        if (isSpeaking.value) {
          _handleSpeechFinished();
        }
      });

      await _tts.speak(cleanTextForSpeech(text));
    } catch (e) {
      debugPrint('VoiceService speakSample error: $e');
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
      await KokoroVoiceClient.instance.stop();
      await _tts.stop();
    } catch (e) {
      debugPrint('VoiceService stop error: $e');
    }
  }
}
