import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/settings_service.dart';
import '../services/voice_service.dart';

/// Interactive Settings Modal for HardCode Academy.
/// Provides voice customization (voice model, volume, speed, pitch, disable toggle),
/// live audio previewing, and extensible sections for gameplay and accessibility preferences.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final SettingsService _settings = SettingsService.instance;
  final VoiceService _voice = VoiceService.instance;
  List<Map<String, String>> _availableVoices = [];
  bool _isLoadingVoices = true;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final voices = await _voice.getAvailableVoices();
    if (mounted) {
      setState(() {
        _availableVoices = voices;
        _isLoadingVoices = false;
      });
    }
  }

  bool _isFemaleOrMascotVoice(String name) {
    final lower = name.toLowerCase();
    return VoiceService.femaleKeywords.any((kw) => lower.contains(kw));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: media.size.height * 0.88,
            maxWidth: 620,
          ),
          margin: EdgeInsets.only(
            bottom: media.viewInsets.bottom,
            left: media.size.width > 640 ? (media.size.width - 620) / 2 : 0,
            right: media.size.width > 640 ? (media.size.width - 620) / 2 : 0,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              // Title & Close Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preferences & Voice',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Customize voice narration, speed, and audio options',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable Settings Content
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  shrinkWrap: true,
                  children: [
                    // SECTION 1: VOICE & MASCOT
                    _buildSectionHeader(
                      context,
                      title: 'Mascot Voice Narration',
                      icon: Icons.record_voice_over_rounded,
                      badge: 'Mascot: Ada',
                    ),
                    const SizedBox(height: 10),

                    // Master Enable/Disable Card
                    _buildMasterVoiceToggle(theme),
                    const SizedBox(height: 14),

                    if (_settings.voiceEnabled) ...[
                      // Voice Engine Selector (Kokoro Neural vs System Device TTS)
                      _buildVoiceEngineSelectorCard(theme),
                      const SizedBox(height: 14),

                      // Voice Profile / Model Selector
                      if (_settings.isKokoroEngine)
                        _buildKokoroVoiceSelectorCard(theme)
                      else
                        _buildVoiceSelectorCard(theme),
                      const SizedBox(height: 14),

                      // Speed / Rate Slider
                      _buildSpeedSliderCard(theme),
                      const SizedBox(height: 14),

                      // Pitch Slider (for System TTS)
                      if (!_settings.isKokoroEngine) ...[
                        _buildPitchSliderCard(theme),
                        const SizedBox(height: 14),
                      ],

                      // Volume Slider
                      _buildVolumeSliderCard(theme),
                      const SizedBox(height: 14),

                      // Action Buttons: Preview Voice & Reset Defaults
                      _buildVoiceActionButtons(theme),
                      const SizedBox(height: 24),
                    ],

                    // SECTION 2: GAMEPLAY & STUDY (Extensibility)
                    _buildSectionHeader(
                      context,
                      title: 'Learning & Gameplay',
                      icon: Icons.sports_esports_outlined,
                    ),
                    const SizedBox(height: 10),
                    _buildGameplayCard(theme),
                    const SizedBox(height: 24),

                    // SECTION 3: ACCESSIBILITY & DISPLAY (Extensibility)
                    _buildSectionHeader(
                      context,
                      title: 'Display & Accessibility',
                      icon: Icons.visibility_outlined,
                    ),
                    const SizedBox(height: 10),
                    _buildAccessibilityCard(theme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    String? badge,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
                width: 0.8,
              ),
            ),
            child: Text(
              badge,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMasterVoiceToggle(ThemeData theme) {
    final isEnabled = _settings.voiceEnabled;
    return Container(
      decoration: BoxDecoration(
        color: isEnabled
            ? theme.colorScheme.primaryContainer.withOpacity(0.25)
            : theme.colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? theme.colorScheme.primary.withOpacity(0.35)
              : theme.colorScheme.outline.withOpacity(0.18),
          width: 1.2,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          'Enable Voice Narration',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          isEnabled
              ? 'Mascot reads questions and pedagogical explanations aloud'
              : 'Voice speech is disabled (silent mode)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isEnabled
                ? theme.colorScheme.primary.withOpacity(0.15)
                : Colors.grey.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            color: isEnabled ? theme.colorScheme.primary : Colors.grey,
            size: 20,
          ),
        ),
        value: isEnabled,
        activeColor: theme.colorScheme.primary,
        onChanged: (val) {
          _settings.setVoiceEnabled(val);
        },
      ),
    );
  }

  Widget _buildVoiceEngineSelectorCard(ThemeData theme) {
    final isKokoro = _settings.isKokoroEngine;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Voice Synthesis Engine',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isKokoro ? Colors.amber.withOpacity(0.18) : Colors.blue.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isKokoro ? Colors.amber.withOpacity(0.5) : Colors.blue.withOpacity(0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isKokoro ? '✨ NEURAL' : '📱 OFFLINE TTS',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isKokoro ? Colors.amber : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Kokoro Option Card
          InkWell(
            onTap: () => _settings.setVoiceEngine('kokoro'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isKokoro
                    ? theme.colorScheme.primaryContainer.withOpacity(0.4)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isKokoro
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.15),
                  width: isKokoro ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<String>(
                    value: 'kokoro',
                    groupValue: _settings.voiceEngine,
                    activeColor: theme.colorScheme.primary,
                    onChanged: (val) {
                      if (val != null) _settings.setVoiceEngine(val);
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Ada Mascot (Kokoro Neural)',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Recommended',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.greenAccent.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Warm, expressive human prosody powered by Kokoro-82M (af_heart) on Callisto. Audio is cached locally on device for instant offline replay.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // System Device TTS Card
          InkWell(
            onTap: () => _settings.setVoiceEngine('system'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: !isKokoro
                    ? theme.colorScheme.primaryContainer.withOpacity(0.4)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: !isKokoro
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.15),
                  width: !isKokoro ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<String>(
                    value: 'system',
                    groupValue: _settings.voiceEngine,
                    activeColor: theme.colorScheme.primary,
                    onChanged: (val) {
                      if (val != null) _settings.setVoiceEngine(val);
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System Device TTS (Offline)',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Uses the standard text-to-speech engine built into your operating system (iOS/Android/Web Speech API).',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKokoroVoiceSelectorCard(ThemeData theme) {
    const voices = [
      {
        'id': 'af_heart',
        'name': 'Ada Mascot (af_heart)',
        'desc': 'Warm & Expressive Female • Official Mascot',
        'badge': 'Mascot',
        'icon': Icons.star_rounded,
      },
      {
        'id': 'af_bella',
        'name': 'Bella (af_bella)',
        'desc': 'Cheerful & Dynamic Female Persona',
        'badge': 'Dynamic',
        'icon': Icons.auto_awesome_rounded,
      },
      {
        'id': 'af_nicole',
        'name': 'Nicole (af_nicole)',
        'desc': 'Smooth & Calm Female Guide',
        'badge': 'Calm',
        'icon': Icons.psychology_rounded,
      },
      {
        'id': 'af_sarah',
        'name': 'Sarah (af_sarah)',
        'desc': 'Clear & Professional Academic Female',
        'badge': 'Pro',
        'icon': Icons.school_rounded,
      },
      {
        'id': 'af_sky',
        'name': 'Sky (af_sky)',
        'desc': 'Bright & Fast-Paced Female Timbre',
        'badge': 'Fast',
        'icon': Icons.bolt_rounded,
      },
    ];

    final currentVoice = _settings.kokoroVoice;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.face_3_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Neural Voice Mascot Profile',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  currentVoice,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Click any voice to select it and immediately hear it speak:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 12),
          // 5 Distinct Interactive Persona Option Cards
          ...voices.map((v) {
            final id = v['id'] as String;
            final isSelected = id == currentVoice;
            final iconData = v['icon'] as IconData;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _settings.setKokoroVoice(id);
                    });
                    // Immediately interrupt previous speech and speak in the newly selected voice
                    _voice.stop();
                    _voice.speakSample(null, id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withOpacity(0.12)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withOpacity(0.2),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Radio / Checkmark indicator
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        // Persona Icon
                        Icon(
                          iconData,
                          size: 18,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (id == 'af_heart' ? Colors.amber : theme.colorScheme.onSurface.withOpacity(0.6)),
                        ),
                        const SizedBox(width: 10),
                        // Titles
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    v['name'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 13,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primary.withOpacity(0.2)
                                          : theme.colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      v['badge'] as String,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                v['desc'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Speaker / Preview Button
                        ValueListenableBuilder<bool>(
                          valueListenable: _voice.isSpeaking,
                          builder: (context, isSpeaking, _) {
                            final isThisSpeaking = isSelected && isSpeaking;
                            return IconButton(
                              tooltip: isThisSpeaking ? 'Stop Audition' : 'Audition Voice',
                              icon: Icon(
                                isThisSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                                color: isThisSpeaking
                                    ? Colors.redAccent
                                    : (isSelected ? theme.colorScheme.primary : theme.colorScheme.outline),
                                size: 22,
                              ),
                              onPressed: () {
                                if (isThisSpeaking) {
                                  _voice.stop();
                                } else {
                                  setState(() {
                                    _settings.setKokoroVoice(id);
                                  });
                                  _voice.stop();
                                  _voice.speakSample(null, id);
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVoiceSelectorCard(ThemeData theme) {
    final selectedName = _settings.selectedVoiceName;
    final currentDropdownValue = (selectedName != null && _availableVoices.any((v) => v['name'] == selectedName))
        ? selectedName
        : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Voice',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (_isLoadingVoices)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '${_availableVoices.length} voices found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_availableVoices.isEmpty && !_isLoadingVoices)
            Text(
              'Default system speech engine active',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.65),
              ),
            )
          else
            DropdownButtonFormField<String>(
              key: ValueKey('system_voice_dropdown_$currentDropdownValue'),
              isExpanded: true,
              value: currentDropdownValue,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: '',
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        '✨ Auto-Select Best Mascot Female Voice',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ..._availableVoices.map((v) {
                  final name = v['name'] ?? 'Unknown';
                  final locale = v['locale'] ?? '';
                  final isMascotRecommended = _isFemaleOrMascotVoice(name);

                  return DropdownMenuItem<String>(
                    value: name,
                    child: Row(
                      children: [
                        if (isMascotRecommended)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.star_rounded, size: 15, color: Colors.amber),
                          ),
                        Expanded(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: isMascotRecommended ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (locale.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            locale,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                final targetName = (value == null || value.isEmpty) ? null : value;
                final locale = targetName != null
                    ? _availableVoices.firstWhere(
                        (v) => v['name'] == targetName,
                        orElse: () => {},
                      )['locale']
                    : null;
                setState(() {
                  _settings.setSelectedVoice(targetName, locale);
                });
                _voice.stop();
                _voice.speakSample();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedSliderCard(ThemeData theme) {
    final speed = _settings.voiceSpeed;
    String speedLabel = 'Normal (~190 WPM)';
    if (speed <= 0.75) {
      speedLabel = 'Slow';
    } else if (speed >= 1.4) {
      speedLabel = 'Fast';
    } else if (speed >= 1.15) {
      speedLabel = 'Brisk';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Reading Speed',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${speed.toStringAsFixed(2)}x • $speedLabel',
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Slider(
            value: speed,
            min: 0.5,
            max: 2.0,
            divisions: 30,
            activeColor: theme.colorScheme.primary,
            label: '${speed.toStringAsFixed(2)}x',
            onChanged: (val) {
              _settings.setVoiceSpeed(val);
            },
          ),
          // Quick Preset Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPresetPill(theme, label: '0.8x Slow', targetSpeed: 0.8, currentSpeed: speed),
              _buildPresetPill(theme, label: '1.0x Normal', targetSpeed: 1.0, currentSpeed: speed),
              _buildPresetPill(theme, label: '1.25x Brisk', targetSpeed: 1.25, currentSpeed: speed),
              _buildPresetPill(theme, label: '1.5x Fast', targetSpeed: 1.5, currentSpeed: speed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetPill(
    ThemeData theme, {
    required String label,
    required double targetSpeed,
    required double currentSpeed,
  }) {
    final isSelected = (currentSpeed - targetSpeed).abs() < 0.05;
    return InkWell(
      onTap: () => _settings.setVoiceSpeed(targetSpeed),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildPitchSliderCard(ThemeData theme) {
    final pitch = _settings.voicePitch;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.graphic_eq_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Voice Pitch',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pitch == 1.15
                      ? '1.15 • Mascot Feminine Timbre'
                      : pitch.toStringAsFixed(2),
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: pitch,
            min: 0.5,
            max: 1.5,
            divisions: 20,
            activeColor: theme.colorScheme.primary,
            label: pitch.toStringAsFixed(2),
            onChanged: (val) {
              _settings.setVoicePitch(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeSliderCard(ThemeData theme) {
    final volume = _settings.voiceVolume;
    final pct = (volume * 100).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.volume_up_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Narration Volume',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$pct%',
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: volume,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            activeColor: theme.colorScheme.primary,
            label: '$pct%',
            onChanged: (val) {
              _settings.setVoiceVolume(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceActionButtons(ThemeData theme) {
    final isKokoro = _settings.isKokoroEngine;
    final activeVoiceName = isKokoro
        ? _settings.kokoroVoice
        : (_settings.selectedVoiceName ?? 'Auto System');

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ValueListenableBuilder<bool>(
            valueListenable: _voice.isSpeaking,
            builder: (context, speaking, _) {
              final buttonLabel = speaking
                  ? 'Stop Preview'
                  : 'Preview Voice ($activeVoiceName)';

              return FilledButton.icon(
                onPressed: () {
                  if (speaking) {
                    _voice.stop();
                  } else {
                    _voice.speakSample();
                  }
                },
                icon: Icon(speaking ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(buttonLabel, overflow: TextOverflow.ellipsis),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _settings.resetVoiceToMascotDefaults();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reset voice to Ada Mascot defaults (Kokoro af_heart, 1.0x Speed)'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Reset'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameplayCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            dense: true,
            title: const Text('Sound Effects (SFX)'),
            subtitle: const Text('Play subtle chimes for correct and wrong answers'),
            value: _settings.soundFxEnabled,
            onChanged: (val) => _settings.setSoundFxEnabled(val),
          ),
          const Divider(height: 1),
          SwitchListTile(
            dense: true,
            title: const Text('Haptic Vibration Feedback'),
            subtitle: const Text('Gentle pulse on mobile devices upon interaction'),
            value: _settings.hapticsEnabled,
            onChanged: (val) => _settings.setHapticsEnabled(val),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            title: const Text('Question Timer Duration'),
            subtitle: Text('${_settings.timerDurationSeconds} seconds per challenge'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_settings.timerDurationSeconds}s',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            dense: true,
            title: const Text('High Contrast Typography'),
            subtitle: const Text('Maximize text border definition and code readability'),
            value: _settings.highContrastMode,
            onChanged: (val) => _settings.setHighContrastMode(val),
          ),
        ],
      ),
    );
  }
}
