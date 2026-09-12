import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/adaptive_explanation_service.dart';
import '../services/voice_service.dart';

/// Full-screen fade-to-white overlay presenting a tailored pedagogical explanation.
/// Includes an animated countdown dwell bar, syntax-styled code examples, mental models,
/// and instant click/keyboard dismissal with single-invocation guards.
class ExplanationOverlay extends StatefulWidget {
  final ExplanationPayload payload;
  final VoidCallback onDismiss;

  const ExplanationOverlay({
    super.key,
    required this.payload,
    required this.onDismiss,
  });

  @override
  State<ExplanationOverlay> createState() => _ExplanationOverlayState();
}

class _ExplanationOverlayState extends State<ExplanationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  Timer? _dwellTimer;
  Timer? _tickTimer;
  late int _remainingSeconds;
  bool _isDismissed = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.payload.dwellSeconds;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();

    // Start voice narration of explanation
    final narrative =
        '${widget.payload.title}. ${widget.payload.tierBadge}. ${widget.payload.explanation}. Mental model: ${widget.payload.mentalModel}';
    VoiceService.instance.speakExplanation(
      narrative,
      onComplete: () {
        if (mounted && !_isDismissed && _remainingSeconds <= 1) {
          _dismiss();
        }
      },
    );

    // Ticking timer for countdown bar
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        // Hold countdown and do NOT advance to next question while voice is speaking:
        if (VoiceService.instance.isSpeaking.value) {
          return;
        }
        _dismiss();
      }
    });

    // Request keyboard focus for Space / Enter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    VoiceService.instance.stop();
    _dwellTimer?.cancel();
    _tickTimer?.cancel();
    _animationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_isDismissed) return;
    _isDismissed = true;
    VoiceService.instance.stop();
    _dwellTimer?.cancel();
    _tickTimer?.cancel();

    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        _dismiss();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Color _getTierColor() {
    switch (widget.payload.tier) {
      case 3:
        return const Color(0xFF9333EA); // Purple / Crimson for Masterclass
      case 2:
        return const Color(0xFFD97706); // Amber / Orange for Deep Dive
      case 1:
      default:
        return const Color(0xFF2563EB); // Blue for Key Insight
    }
  }

  IconData _getTopicIcon() {
    final lower = widget.payload.topic.toLowerCase();
    if (lower.contains('rust')) return Icons.memory_rounded;
    if (lower.contains('tcp') || lower.contains('network')) return Icons.lan_rounded;
    if (lower.contains('cloud') || lower.contains('distributed')) return Icons.cloud_done_rounded;
    if (lower.contains('var') || lower.contains('syntax')) return Icons.code_rounded;
    if (lower.contains('algo') || lower.contains('complexity')) return Icons.auto_graph_rounded;
    if (lower.contains('os') || lower.contains('system')) return Icons.settings_suggest_rounded;
    return Icons.lightbulb_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _getTierColor();
    final totalDwell = widget.payload.dwellSeconds;
    final progress = (_remainingSeconds / totalDwell).clamp(0.0, 1.0);
    final size = MediaQuery.of(context).size;
    final double cardMaxWidth = (size.width * 0.88).clamp(320.0, 780.0);

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.white.withOpacity(0.96),
          child: Stack(
            children: [
              // Top countdown dwell bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.linear,
                  tween: Tween<double>(begin: 1.0, end: progress),
                  builder: (context, val, _) {
                    return LinearProgressIndicator(
                      value: val,
                      minHeight: 4.5,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                    );
                  },
                ),
              ),

              // Centered Explanation Card
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: cardMaxWidth,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: tierColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tierColor.withOpacity(0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Tier Badge & Dwell Remaining
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tierColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: tierColor.withOpacity(0.35),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_getTopicIcon(), size: 14, color: tierColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.payload.tierBadge,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: tierColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ValueListenableBuilder<bool>(
                                valueListenable: VoiceService.instance.isSpeaking,
                                builder: (context, isSpeaking, _) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSpeaking) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0284C7).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFF0284C7).withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.graphic_eq_rounded,
                                                size: 14,
                                                color: Color(0xFF0284C7),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'VOICE NARRATING',
                                                style: GoogleFonts.jetBrainsMono(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.6,
                                                  color: const Color(0xFF0284C7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Icon(Icons.timer_outlined,
                                          size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        isSpeaking && _remainingSeconds <= 1
                                            ? 'NARRATING...'
                                            : '${_remainingSeconds}s',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isSpeaking && _remainingSeconds <= 1
                                              ? const Color(0xFF0284C7)
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Title
                          Text(
                            widget.payload.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Core Explanation Body
                          Text(
                            widget.payload.explanation,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              height: 1.55,
                              color: const Color(0xFF334155),
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          // Code Snippet Box (if available)
                          if (widget.payload.codeSnippet != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                widget.payload.codeSnippet!,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: const Color(0xFF38BDF8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],

                          // Mental Model Callout
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blueGrey.shade200,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.psychology_rounded,
                                  size: 18,
                                  color: Color(0xFF475569),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Mental Model: ${widget.payload.mentalModel}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Interactive Dismiss Button & Keyboard hint
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Press Space or Enter to continue',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _dismiss,
                                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                label: const Text('Got It, Continue'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tierColor,
                                  foregroundColor: Colors.white,
                                  elevation: 1,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
