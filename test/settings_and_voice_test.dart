import 'package:flutter_test/flutter_test.dart';
import 'package:multiprogramming/services/settings_service.dart';
import 'package:multiprogramming/services/voice_service.dart';

void main() {
  group('SettingsService Unit Tests', () {
    test('Default voice settings are properly calibrated for female mascot', () {
      final settings = SettingsService.instance;
      expect(settings.voiceEnabled, isTrue);
      expect(settings.voiceSpeed, equals(1.0));
      expect(settings.voicePitch, equals(1.15));
      expect(settings.voiceVolume, equals(1.0));
      expect(settings.selectedVoiceName, isNull);
    });

    test('Speed clamping and updates work correctly', () async {
      final settings = SettingsService.instance;
      await settings.setVoiceSpeed(1.5);
      expect(settings.voiceSpeed, equals(1.5));

      // Bounds clamping
      await settings.setVoiceSpeed(3.0);
      expect(settings.voiceSpeed, equals(2.0));
      await settings.setVoiceSpeed(0.2);
      expect(settings.voiceSpeed, equals(0.5));

      // Reset
      await settings.setVoiceSpeed(1.0);
      expect(settings.voiceSpeed, equals(1.0));
    });

    test('Pitch clamping and updates work correctly', () async {
      final settings = SettingsService.instance;
      await settings.setVoicePitch(1.3);
      expect(settings.voicePitch, equals(1.3));

      // Bounds clamping
      await settings.setVoicePitch(2.0);
      expect(settings.voicePitch, equals(1.5));
      await settings.setVoicePitch(0.1);
      expect(settings.voicePitch, equals(0.5));

      // Reset
      await settings.setVoicePitch(1.15);
      expect(settings.voicePitch, equals(1.15));
    });

    test('Volume clamping and updates work correctly', () async {
      final settings = SettingsService.instance;
      await settings.setVoiceVolume(0.8);
      expect(settings.voiceVolume, equals(0.8));

      // Bounds clamping
      await settings.setVoiceVolume(1.5);
      expect(settings.voiceVolume, equals(1.0));
      await settings.setVoiceVolume(-0.5);
      expect(settings.voiceVolume, equals(0.0));

      // Reset
      await settings.setVoiceVolume(1.0);
      expect(settings.voiceVolume, equals(1.0));
    });

    test('Reset to mascot defaults restores standard configuration', () async {
      final settings = SettingsService.instance;
      await settings.setVoiceSpeed(1.8);
      await settings.setVoicePitch(0.8);
      await settings.setVoiceVolume(0.4);
      await settings.setSelectedVoice('TestVoice');

      await settings.resetVoiceToMascotDefaults();
      expect(settings.voiceSpeed, equals(1.0));
      expect(settings.voicePitch, equals(1.15));
      expect(settings.voiceVolume, equals(1.0));
      expect(settings.selectedVoiceName, isNull);
      expect(settings.voiceEnabled, isTrue);
    });
  });

  group('VoiceService Dynamic Timing & Sanitization Tests', () {
    test('Dynamic duration scaling with speed rate', () {
      const sample = 'A linked list consists of nodes that point to subsequent nodes in memory.';
      final durSlow = VoiceService.estimateSpeechDurationSeconds(sample, 0.7);
      final durNormal = VoiceService.estimateSpeechDurationSeconds(sample, 1.0);
      final durFast = VoiceService.estimateSpeechDurationSeconds(sample, 1.5);

      expect(durSlow, greaterThan(durNormal));
      expect(durNormal, greaterThan(durFast));
    });

    test('Clean text for speech strips code and formatting', () {
      const text = 'Use `let mut count: i32 = 0;` inside the loop.';
      final cleaned = VoiceService.cleanTextForSpeech(text);
      expect(cleaned, isNot(contains('`')));
      expect(cleaned, contains('let mutable'));
    });

    test('Clean text strips list markers and markdown headers', () {
      const text = '# Overview\n1. First step\n2. Second step\n- Bullet item';
      final cleaned = VoiceService.cleanTextForSpeech(text);
      expect(cleaned, isNot(contains('#')));
      expect(cleaned, isNot(contains('1.')));
      expect(cleaned, isNot(contains('2.')));
      expect(cleaned, contains('First step'));
      expect(cleaned, contains('Bullet item'));
    });
  });
}
