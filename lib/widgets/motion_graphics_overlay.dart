import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// The distinct category of motion graphic event to display.
enum MotionGraphicType {
  levelStart,
  levelComplete,
  streak3,
  streak5,
  streak10,
  streak20,
  idleReengagement,
  rustTheme,
  tcpTheme,
  cloudTheme,
  syntaxTheme,
}

/// Dynamic motion graphics overlay rendered via procedural vector CustomPainter.
/// Provides cinematic animations for milestones, streak escalations, subject themes,
/// and re-engagement prompts. Supports instant tap-to-skip.
class MotionGraphicsOverlay extends StatefulWidget {
  final MotionGraphicType type;
  final String title;
  final String subtitle;
  final String? topicTag;
  final int? value;
  final VoidCallback onDismiss;
  final Duration autoDismissDuration;

  const MotionGraphicsOverlay({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    this.topicTag,
    this.value,
    required this.onDismiss,
    this.autoDismissDuration = const Duration(milliseconds: 2400),
  });

  @override
  State<MotionGraphicsOverlay> createState() => _MotionGraphicsOverlayState();
}

class _MotionGraphicsOverlayState extends State<MotionGraphicsOverlay>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  Timer? _autoDismissTimer;
  bool _isDismissed = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _autoDismissTimer = Timer(widget.autoDismissDuration, () {
      _dismiss();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _mainController.dispose();
    _particleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_isDismissed) return;
    _isDismissed = true;
    _autoDismissTimer?.cancel();

    _mainController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      _dismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Color _getPrimaryColor() {
    switch (widget.type) {
      case MotionGraphicType.streak3:
        return const Color(0xFFF59E0B); // Amber
      case MotionGraphicType.streak5:
        return const Color(0xFFEF4444); // Red / Orange Flame
      case MotionGraphicType.streak10:
        return const Color(0xFF06B6D4); // Electric Cyan
      case MotionGraphicType.streak20:
        return const Color(0xFF8B5CF6); // Celestial Purple / Gold
      case MotionGraphicType.levelComplete:
        return const Color(0xFF10B981); // Emerald / Gold
      case MotionGraphicType.levelStart:
        return const Color(0xFF3B82F6); // Royal Blue
      case MotionGraphicType.rustTheme:
        return const Color(0xFFEA580C); // Rust Amber-Orange
      case MotionGraphicType.tcpTheme:
        return const Color(0xFF0284C7); // Deep Sky Blue
      case MotionGraphicType.cloudTheme:
        return const Color(0xFF6366F1); // Indigo Cloud
      case MotionGraphicType.syntaxTheme:
        return const Color(0xFF14B8A6); // Teal
      case MotionGraphicType.idleReengagement:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _getPrimaryColor();

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: GestureDetector(
        onTap: _dismiss,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _mainController,
          builder: (context, child) {
            final double entranceOpacity =
                Curves.easeOutCubic.transform(_mainController.value);
            final double scale =
                0.85 + 0.15 * Curves.easeOutBack.transform(_mainController.value);

            return Material(
              color: Colors.black.withOpacity(0.65 * entranceOpacity),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Animated Vector Canvas
                  AnimatedBuilder(
                    animation: _particleController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _VectorMotionPainter(
                          type: widget.type,
                          progress: _mainController.value,
                          particleTick: _particleController.value,
                          primaryColor: primaryColor,
                        ),
                      );
                    },
                  ),

                  // Center Banner / Title Content
                  Center(
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 480),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 24),
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.6),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.35),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.topicTag != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: primaryColor.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  widget.topicTag!.toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: primaryColor,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Main Title
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Subtitle
                            Text(
                              widget.subtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                color: const Color(0xFFCBD5E1),
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Quick dismiss hint
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Tap anywhere or press any key to continue',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// CustomPainter rendering procedural vector animations for each motion graphic type.
class _VectorMotionPainter extends CustomPainter {
  final MotionGraphicType type;
  final double progress;
  final double particleTick;
  final Color primaryColor;

  _VectorMotionPainter({
    required this.type,
    required this.progress,
    required this.particleTick,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    switch (type) {
      case MotionGraphicType.streak3:
      case MotionGraphicType.streak5:
      case MotionGraphicType.streak10:
      case MotionGraphicType.streak20:
        _paintStreakGraphic(canvas, size, center);
        break;
      case MotionGraphicType.levelComplete:
        _paintLevelCompleteGraphic(canvas, size, center);
        break;
      case MotionGraphicType.levelStart:
        _paintLevelStartGraphic(canvas, size, center);
        break;
      case MotionGraphicType.rustTheme:
        _paintRustGears(canvas, size, center);
        break;
      case MotionGraphicType.tcpTheme:
        _paintTcpNetwork(canvas, size, center);
        break;
      case MotionGraphicType.cloudTheme:
        _paintCloudCluster(canvas, size, center);
        break;
      case MotionGraphicType.syntaxTheme:
      case MotionGraphicType.idleReengagement:
        _paintSyntaxConstellation(canvas, size, center);
        break;
    }
  }

  void _paintStreakGraphic(Canvas canvas, Size size, Offset center) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = primaryColor.withOpacity((1.0 - progress * 0.7).clamp(0.0, 1.0));

    // Multiple expanding shockwave rings
    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.25) % 1.0;
      final radius = 90.0 + ringProgress * 180.0;
      final ringColor = primaryColor.withOpacity(
          ((1.0 - ringProgress) * 0.6).clamp(0.0, 1.0));
      canvas.drawCircle(center, radius, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.0..color = ringColor);
    }

    // Radiating kinetic particle embers
    final int particleCount = (type == MotionGraphicType.streak20) ? 48 : 28;
    final Random rng = Random(42);
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * pi + particleTick * 2 * pi;
      final distance = 110.0 + (rng.nextDouble() * 150.0 * progress);
      final pOffset = center + Offset(cos(angle) * distance, sin(angle) * distance);
      final pRadius = 2.0 + rng.nextDouble() * 4.0;
      final pColor = (i % 2 == 0) ? primaryColor : Colors.amberAccent;

      canvas.drawCircle(
        pOffset,
        pRadius,
        Paint()..color = pColor.withOpacity((1.0 - progress * 0.5).clamp(0.0, 0.9)),
      );
    }
  }

  void _paintLevelCompleteGraphic(Canvas canvas, Size size, Offset center) {
    // Radiating sunburst rays
    final rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const int numRays = 24;
    for (int i = 0; i < numRays; i++) {
      final angle = (i / numRays) * 2 * pi + particleTick * pi;
      final rayLength = 140.0 + sin(particleTick * 2 * pi + i) * 30.0;
      final p1 = center + Offset(cos(angle) * 100.0, sin(angle) * 100.0);
      final p2 = center + Offset(cos(angle) * (100.0 + rayLength), sin(angle) * (100.0 + rayLength));

      rayPaint.color = Colors.amberAccent.withOpacity(0.35);
      canvas.drawLine(p1, p2, rayPaint);
    }

    // Sparkle star particles
    final starPaint = Paint()..color = Colors.white.withOpacity(0.85);
    for (int i = 0; i < 18; i++) {
      final angle = (i / 18.0) * 2 * pi - particleTick * 2 * pi;
      final dist = 160.0 + cos(particleTick * pi + i) * 40.0;
      final pos = center + Offset(cos(angle) * dist, sin(angle) * dist);
      canvas.drawCircle(pos, 3.5, starPaint);
    }
  }

  void _paintLevelStartGraphic(Canvas canvas, Size size, Offset center) {
    // Dynamic entry speed lines
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 16; i++) {
      final y = size.height * (i / 16.0);
      final xStart = size.width * ((particleTick + i * 0.1) % 1.0);
      linePaint.color = primaryColor.withOpacity(0.3);
      canvas.drawLine(Offset(xStart, y), Offset(xStart + 60, y), linePaint);
    }
  }

  void _paintRustGears(Canvas canvas, Size size, Offset center) {
    final gearPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = const Color(0xFFEA580C).withOpacity(0.7);

    // Large main gear
    _drawCogWheel(canvas, center, 110, 14, particleTick * 2 * pi, gearPaint);

    // Small interlocking gear
    final smallCenter = center + const Offset(135, -50);
    _drawCogWheel(canvas, smallCenter, 55, 8, -particleTick * 4 * pi, gearPaint);
  }

  void _drawCogWheel(Canvas canvas, Offset center, double radius, int teeth, double rotation, Paint paint) {
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.35, paint);

    for (int i = 0; i < teeth; i++) {
      final angle = rotation + (i / teeth) * 2 * pi;
      final p1 = center + Offset(cos(angle) * (radius - 5), sin(angle) * (radius - 5));
      final p2 = center + Offset(cos(angle) * (radius + 12), sin(angle) * (radius + 12));
      canvas.drawLine(p1, p2, paint..strokeWidth = 4.0);
    }
  }

  void _paintTcpNetwork(Canvas canvas, Size size, Offset center) {
    final nodePaint = Paint()..color = const Color(0xFF38BDF8);
    final linkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF0284C7).withOpacity(0.4);

    // 4 network nodes in topology
    final nodes = [
      center + const Offset(-140, -60),
      center + const Offset(140, -60),
      center + const Offset(-100, 90),
      center + const Offset(100, 90),
    ];

    // Connect nodes
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        canvas.drawLine(nodes[i], nodes[j], linkPaint);
      }
    }

    // Animate data packet pulses travelling along links
    for (int i = 0; i < nodes.length - 1; i++) {
      final p1 = nodes[i];
      final p2 = nodes[i + 1];
      final packetPos = Offset.lerp(p1, p2, (particleTick + i * 0.25) % 1.0)!;
      canvas.drawCircle(packetPos, 5.0, Paint()..color = Colors.cyanAccent);
    }

    // Draw node vertices
    for (final node in nodes) {
      canvas.drawCircle(node, 10, nodePaint);
      canvas.drawCircle(node, 16, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFF38BDF8).withOpacity(0.5));
    }
  }

  void _paintCloudCluster(Canvas canvas, Size size, Offset center) {
    final cloudPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF818CF8).withOpacity(0.6);

    // Layered floating isometric cloud server rectangles
    for (int i = 0; i < 3; i++) {
      final yOffset = -50.0 + i * 55.0 + sin(particleTick * 2 * pi + i) * 6.0;
      final cRect = Rect.fromCenter(center: center + Offset(0, yOffset), width: 220 - i * 20, height: 35);
      canvas.drawRRect(RRect.fromRectAndRadius(cRect, const Radius.circular(10)), cloudPaint);

      // Uplink data beam
      canvas.drawLine(
        center + Offset(0, yOffset - 15),
        center + Offset(0, yOffset + 15),
        Paint()..color = Colors.cyanAccent.withOpacity(0.6)..strokeWidth = 2,
      );
    }
  }

  void _paintSyntaxConstellation(Canvas canvas, Size size, Offset center) {
    final Random rng = Random(88);
    final dotPaint = Paint()..color = primaryColor.withOpacity(0.7);

    for (int i = 0; i < 30; i++) {
      final angle = (i / 30.0) * 2 * pi + particleTick * pi * 0.5;
      final dist = 120.0 + rng.nextDouble() * 90.0;
      final pos = center + Offset(cos(angle) * dist, sin(angle) * dist);
      canvas.drawCircle(pos, 2.5 + rng.nextDouble() * 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VectorMotionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particleTick != particleTick ||
        oldDelegate.type != type;
  }
}
