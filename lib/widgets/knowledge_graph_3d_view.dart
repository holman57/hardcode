import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/progression_service.dart';

enum Graph3DViewMode {
  orbital,
  matrixGrid,
}

class KnowledgeGraph3DView extends StatefulWidget {
  final Map<String, TopicProgressionNode> nodes;
  final String? selectedNodeId;
  final ValueChanged<TopicProgressionNode>? onNodeSelected;
  final Graph3DViewMode viewMode;
  final bool autoRotate;

  const KnowledgeGraph3DView({
    super.key,
    required this.nodes,
    this.selectedNodeId,
    this.onNodeSelected,
    this.viewMode = Graph3DViewMode.orbital,
    this.autoRotate = false,
  });

  @override
  State<KnowledgeGraph3DView> createState() => KnowledgeGraph3DViewState();
}

class KnowledgeGraph3DViewState extends State<KnowledgeGraph3DView>
    with TickerProviderStateMixin {
  double _yaw = 0.45;
  double _pitch = -0.25;
  double _zoom = 0.85;
  Offset _panOffset = Offset.zero;

  Offset? _lastDragPosition;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _flightController;
  late Animation<double> _flightCurve;

  double _startYaw = 0.45, _targetYaw = 0.45;
  double _startPitch = -0.25, _targetPitch = -0.25;
  double _startZoom = 0.85, _targetZoom = 0.85;
  Offset _startPan = Offset.zero, _targetPan = Offset.zero;

  // Stored projected positions for hit testing
  final Map<String, _ProjectedNode> _projectedNodes = {};

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..addListener(() {
        if (widget.autoRotate) {
          setState(() {
            _yaw += 0.003;
            if (_yaw > 2 * pi) _yaw -= 2 * pi;
          });
        }
      });
    _rotationController.repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..addListener(() {
        setState(() {}); // Repaint shockwaves & orbital satellites
      });
    _pulseController.repeat();

    _flightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(() {
        setState(() {
          final t = _flightCurve.value;
          _yaw = _startYaw + (_targetYaw - _startYaw) * t;
          _pitch = _startPitch + (_targetPitch - _startPitch) * t;
          _zoom = _startZoom + (_targetZoom - _startZoom) * t;
          _panOffset = Offset.lerp(_startPan, _targetPan, t)!;
        });
      });
    _flightCurve = CurvedAnimation(
      parent: _flightController,
      curve: Curves.easeOutCubic,
    );

    if (widget.selectedNodeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        focusOnNode(widget.selectedNodeId!, animate: false);
      });
    }
  }

  @override
  void didUpdateWidget(KnowledgeGraph3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedNodeId != oldWidget.selectedNodeId &&
        widget.selectedNodeId != null) {
      focusOnNode(widget.selectedNodeId!, animate: true);
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _flightController.dispose();
    super.dispose();
  }

  void resetCamera() {
    _startYaw = _yaw;
    _startPitch = _pitch;
    _startZoom = _zoom;
    _startPan = _panOffset;

    _targetYaw = 0.45;
    _targetPitch = -0.25;
    _targetZoom = 0.85;
    _targetPan = Offset.zero;

    _flightController.forward(from: 0.0);
  }

  void zoomIn() {
    setState(() {
      _zoom = (_zoom * 1.2).clamp(0.4, 3.0);
    });
  }

  void zoomOut() {
    setState(() {
      _zoom = (_zoom / 1.2).clamp(0.4, 3.0);
    });
  }

  void focusOnNode(String nodeId, {bool animate = true}) {
    final node = widget.nodes[nodeId];
    if (node == null) return;

    final pos = node.position3D;
    double tYaw = atan2(pos.x, pos.z) + pi;
    double tPitch = -atan2(pos.y, sqrt(pos.x * pos.x + pos.z * pos.z));
    tPitch = tPitch.clamp(-pi / 3, pi / 3);
    const double tZoom = 1.25;
    const Offset tPan = Offset.zero;

    if (!animate) {
      setState(() {
        _yaw = tYaw;
        _pitch = tPitch;
        _zoom = tZoom;
        _panOffset = tPan;
      });
      return;
    }

    _startYaw = _yaw;
    _startPitch = _pitch;
    _startZoom = _zoom;
    _startPan = _panOffset;

    // Normalize yaw delta to [-pi, pi] for shortest rotational flight path
    while (tYaw - _startYaw > pi) {
      tYaw -= 2 * pi;
    }
    while (tYaw - _startYaw < -pi) {
      tYaw += 2 * pi;
    }

    _targetYaw = tYaw;
    _targetPitch = tPitch;
    _targetZoom = tZoom;
    _targetPan = tPan;

    _flightController.forward(from: 0.0);
  }

  void _handleTapUp(TapUpDetails details) {
    final localPos = details.localPosition;
    TopicProgressionNode? bestMatch;
    double highestZ = -double.infinity;

    for (final entry in _projectedNodes.entries) {
      final pNode = entry.value;
      final dist = (localPos - pNode.screenPosition).distance;
      final touchRadius = max(pNode.projectedRadius + 14.0, 24.0);

      if (dist <= touchRadius) {
        if (pNode.depthZ > highestZ) {
          highestZ = pNode.depthZ;
          bestMatch = widget.nodes[entry.key];
        }
      }
    }

    if (bestMatch != null) {
      focusOnNode(bestMatch.id, animate: true);
      if (widget.onNodeSelected != null) {
        widget.onNodeSelected!(bestMatch);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        _lastDragPosition = details.localPosition;
      },
      onPanUpdate: (details) {
        if (_lastDragPosition == null) return;
        final delta = details.localPosition - _lastDragPosition!;
        _lastDragPosition = details.localPosition;

        setState(() {
          _yaw += delta.dx * 0.008;
          _pitch = (_pitch - delta.dy * 0.008).clamp(-pi / 2.3, pi / 2.3);
        });
      },
      onPanEnd: (_) {
        _lastDragPosition = null;
      },
      onTapUp: _handleTapUp,
      child: CustomPaint(
        painter: _KnowledgeGraph3DPainter(
          nodes: widget.nodes,
          selectedNodeId: widget.selectedNodeId,
          yaw: _yaw,
          pitch: _pitch,
          zoom: _zoom,
          panOffset: _panOffset,
          pulseValue: _pulseController.value,
          viewMode: widget.viewMode,
          onProjectsCalculated: (projected) {
            _projectedNodes.clear();
            _projectedNodes.addAll(projected);
          },
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ProjectedNode {
  final Offset screenPosition;
  final double depthZ;
  final double scale;
  final double projectedRadius;
  final TopicProgressionNode node;

  _ProjectedNode({
    required this.screenPosition,
    required this.depthZ,
    required this.scale,
    required this.projectedRadius,
    required this.node,
  });
}

class _KnowledgeGraph3DPainter extends CustomPainter {
  final Map<String, TopicProgressionNode> nodes;
  final String? selectedNodeId;
  final double yaw;
  final double pitch;
  final double zoom;
  final Offset panOffset;
  final double pulseValue;
  final Graph3DViewMode viewMode;
  final ValueChanged<Map<String, _ProjectedNode>> onProjectsCalculated;

  _KnowledgeGraph3DPainter({
    required this.nodes,
    required this.selectedNodeId,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.panOffset,
    required this.pulseValue,
    required this.viewMode,
    required this.onProjectsCalculated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2 + panOffset.dx, size.height * 0.38 + panOffset.dy);
    const double cameraDistance = 750.0;
    const double focalLength = 600.0;

    // 1. Draw Space Background & Star Dust Grid
    _drawSpatialGrid(canvas, size, center);

    // 2. Project all 3D nodes to 2D
    final Map<String, _ProjectedNode> projectedMap = {};

    for (final node in nodes.values) {
      Vector3D pos = node.position3D;
      if (viewMode == Graph3DViewMode.matrixGrid) {
        // Flatten into isometric grid plane
        pos = Vector3D(pos.x * 1.1, (node.isUnlocked ? -30.0 : 30.0), pos.z * 1.1);
      }

      // Rotate around Y (yaw)
      final cosY = cos(yaw);
      final sinY = sin(yaw);
      final x1 = pos.x * cosY + pos.z * sinY;
      final z1 = -pos.x * sinY + pos.z * cosY;

      // Rotate around X (pitch)
      final cosP = cos(pitch);
      final sinP = sin(pitch);
      final y2 = pos.y * cosP - z1 * sinP;
      final z2 = pos.y * sinP + z1 * cosP;

      final zEff = max(z2 + cameraDistance, 25.0);
      final scale = (focalLength * zoom) / zEff;

      final screenX = center.dx + x1 * scale;
      final screenY = center.dy + y2 * scale;

      double baseRadius = 24.0;
      if (node.id.startsWith('domain:')) {
        baseRadius = 34.0;
      } else if (node.id.startsWith('topic:')) {
        baseRadius = 26.0;
      }

      projectedMap[node.id] = _ProjectedNode(
        screenPosition: Offset(screenX, screenY),
        depthZ: z2,
        scale: scale,
        projectedRadius: baseRadius * scale,
        node: node,
      );
    }

    onProjectsCalculated(projectedMap);

    // 3. Draw Directed Edges (Prerequisites & Overlapping Similarities)
    _drawEdges(canvas, projectedMap);

    // 4. Sort Nodes by Depth (Painter's Algorithm: back to front)
    final sortedNodes = projectedMap.values.toList()
      ..sort((a, b) => a.depthZ.compareTo(b.depthZ));

    // 5. Render Nodes
    for (final pNode in sortedNodes) {
      _drawNode(canvas, pNode);
    }
  }

  void _drawSpatialGrid(Canvas canvas, Size size, Offset center) {
    final gridPaint = Paint()
      ..color = Colors.indigo.shade900.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Glowing coordinate concentric rings
    final ringRadii = [80.0, 180.0, 300.0, 420.0];
    for (final r in ringRadii) {
      final ringP = Paint()
        ..color = Colors.blueAccent.withOpacity(0.06 * zoom)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, r * zoom, ringP);
    }

    // Cross axes
    canvas.drawLine(
      Offset(center.dx - 450 * zoom, center.dy),
      Offset(center.dx + 450 * zoom, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 350 * zoom),
      Offset(center.dx, center.dy + 350 * zoom),
      gridPaint,
    );
  }

  void _drawEdges(Canvas canvas, Map<String, _ProjectedNode> projected) {
    for (final pNode in projected.values) {
      final node = pNode.node;

      // Draw Prerequisite Edges (Solid directional flow)
      for (final prereqId in node.prerequisiteIds) {
        final parent = projected[prereqId];
        if (parent == null) continue;

        final bool isPathActive = parent.node.isUnlocked;
        final edgeColor = isPathActive
            ? (node.isUnlocked ? Colors.cyanAccent : Colors.blueAccent.withOpacity(0.6))
            : Colors.grey.withOpacity(0.2);

        final edgePaint = Paint()
          ..color = edgeColor.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isPathActive ? (2.2 * pNode.scale).clamp(1.0, 3.5) : 1.0;

        canvas.drawLine(parent.screenPosition, pNode.screenPosition, edgePaint);

        // Midpoint energy beacon
        if (isPathActive) {
          final mid = Offset(
            (parent.screenPosition.dx + pNode.screenPosition.dx) / 2,
            (parent.screenPosition.dy + pNode.screenPosition.dy) / 2,
          );
          final dotP = Paint()..color = Colors.cyanAccent.withOpacity(0.8);
          canvas.drawCircle(mid, 2.5 * pNode.scale, dotP);
        }
      }

      // Draw Overlap / Similarity Edges (Faint dashed / dotted arcs)
      for (final simId in node.similarNodeIds) {
        final sibling = projected[simId];
        if (sibling == null) continue;
        // Avoid drawing twice
        if (node.id.compareTo(simId) > 0) continue;

        final simPaint = Paint()
          ..color = Colors.purpleAccent.withOpacity(0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

        canvas.drawLine(pNode.screenPosition, sibling.screenPosition, simPaint);
      }
    }
  }

  void _drawNode(Canvas canvas, _ProjectedNode pNode) {
    final pos = pNode.screenPosition;
    final r = max(pNode.projectedRadius, 8.0);
    final node = pNode.node;
    final isSelected = node.id == selectedNodeId;

    Color baseColor = Colors.grey;
    try {
      baseColor = Color(int.parse(node.colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {}

    // 1. Outer Aura Glow, Radiating Shockwaves & Spinning Orbital Satellites
    if (isSelected) {
      // 1a. Radiating Shockwave Ripples (expanding concentric energy waves)
      for (int ring = 0; ring < 3; ring++) {
        final double ringProgress = (pulseValue + ring * 0.33) % 1.0;
        final double ringRadius = r + 4.0 + ringProgress * 42.0;
        final double ringOpacity = ((1.0 - ringProgress) * 0.7).clamp(0.0, 1.0);
        final ringPaint = Paint()
          ..color = Colors.cyanAccent.withOpacity(ringOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.4 * (1.0 - ringProgress)).clamp(0.6, 2.8);
        canvas.drawCircle(pos, ringRadius, ringPaint);
      }

      // 1b. Spinning Orbital Satellites (beacons revolving on inclined 3D plane)
      final double orbitAngle = pulseValue * 2 * pi;
      const int satCount = 3;
      final double orbitRadiusX = r + 18.0;
      final double orbitRadiusY = (r + 18.0) * 0.45; // 3D tilted ellipse perspective

      for (int s = 0; s < satCount; s++) {
        final double angle = orbitAngle + s * (2 * pi / satCount);
        final double satX = pos.dx + orbitRadiusX * cos(angle);
        final double satY = pos.dy + orbitRadiusY * sin(angle);
        final Offset satPos = Offset(satX, satY);

        // Satellite glowing aura
        final satGlow = Paint()
          ..color = Colors.amberAccent.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(satPos, 5.0, satGlow);

        // Satellite core
        final satPaint = Paint()
          ..color = (s == 0) ? Colors.cyanAccent : Colors.amberAccent
          ..style = PaintingStyle.fill;
        canvas.drawCircle(satPos, 2.5, satPaint);
      }

      // 1c. Selected Central Aura Glow
      final auraPaint = Paint()
        ..color = Colors.amberAccent.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(pos, r + 14, auraPaint);
    } else if (node.isMastered) {
      final auraPaint = Paint()
        ..color = Colors.amber.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(pos, r + 8, auraPaint);
    } else if (node.isUnlocked) {
      final auraPaint = Paint()
        ..color = baseColor.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(pos, r + 5, auraPaint);
    }

    // 2. Node Body Circle
    final bodyPaint = Paint()
      ..color = node.isLocked
          ? const Color(0xFF1E293B) // Dark steel
          : (node.isMastered ? Colors.amber.shade700 : baseColor.withOpacity(0.85))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, r, bodyPaint);

    // 3. Node Border Ring
    final borderPaint = Paint()
      ..color = isSelected
          ? Colors.white
          : (node.isLocked ? Colors.grey.shade600 : Colors.white.withOpacity(0.85))
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 3.0 : 1.5;
    canvas.drawCircle(pos, r, borderPaint);

    // 4. Progress Arc (Points to Mastery)
    if (node.isUnlocked && !node.isMastered && node.progressRatio > 0) {
      final arcPaint = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.5;

      canvas.drawArc(
        Rect.fromCircle(center: pos, radius: r + 3),
        -pi / 2,
        2 * pi * node.progressRatio,
        false,
        arcPaint,
      );
    }

    // 5. Node Center Glyph / Lock Icon
    if (node.isLocked) {
      // Draw lock symbol
      final textPainter = TextPainter(
        text: TextSpan(
          text: '🔒',
          style: TextStyle(fontSize: max(r * 0.75, 10.0)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
      );
    } else if (node.isMastered) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '★',
          style: TextStyle(fontSize: max(r * 0.9, 12.0), color: Colors.white, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
      );
    }

    // 6. Label Text Below Node (Scaled by 3D depth)
    final fontSize = (11.0 * pNode.scale).clamp(8.0, 14.0);
    final textOpacity = (pNode.scale * 1.1).clamp(0.4, 1.0);

    final labelPainter = TextPainter(
      text: TextSpan(
        text: node.label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected
              ? Colors.amberAccent
              : (node.isLocked ? const Color(0xFFE2E8F0) : Colors.white).withOpacity(textOpacity),
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 140 * pNode.scale);

    final textOffset = Offset(pos.dx - labelPainter.width / 2, pos.dy + r + 5);
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        textOffset.dx - 6,
        textOffset.dy - 2,
        labelPainter.width + 12,
        labelPainter.height + 4,
      ),
      const Radius.circular(6),
    );
    final bgPaint = Paint()
      ..color = const Color(0xF20A0F1D)
      ..style = PaintingStyle.fill;
    final borderPillPaint = Paint()
      ..color = isSelected
          ? Colors.amberAccent.withOpacity(0.8)
          : (node.isLocked ? const Color(0x3394A3B8) : const Color(0x5538BDF8))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(bgRect, bgPaint);
    canvas.drawRRect(bgRect, borderPillPaint);

    labelPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _KnowledgeGraph3DPainter oldDelegate) {
    return true; // Continuously animated / interactive
  }
}
