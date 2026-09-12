import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/progression_service.dart';
import '../widgets/knowledge_graph_3d_view.dart';

class KnowledgeGraph3DScreen extends StatefulWidget {
  final ValueChanged<TopicProgressionNode>? onSelectTopicForGrind;

  const KnowledgeGraph3DScreen({
    super.key,
    this.onSelectTopicForGrind,
  });

  @override
  State<KnowledgeGraph3DScreen> createState() => _KnowledgeGraph3DScreenState();
}

class _KnowledgeGraph3DScreenState extends State<KnowledgeGraph3DScreen> {
  final GlobalKey<KnowledgeGraph3DViewState> _viewKey = GlobalKey<KnowledgeGraph3DViewState>();
  final TopicProgressionService _progressionService = TopicProgressionService.instance;

  TopicProgressionNode? _selectedNode;
  Graph3DViewMode _viewMode = Graph3DViewMode.orbital;
  bool _autoRotate = false;
  bool _isInspectorCollapsed = false;

  @override
  void initState() {
    super.initState();
    // Default selection to Computer Science root
    _selectedNode = _progressionService.getNode('domain:computer_science');
  }

  void _onNodeTapped(TopicProgressionNode node) {
    setState(() {
      _selectedNode = node;
    });
    _viewKey.currentState?.focusOnNode(node.id, animate: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodes = _progressionService.nodes;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Deep cosmic space
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 2,
        leading: IconButton(
          key: const Key('kg_btn_back'),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Return to Quiz',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hub_rounded, color: Colors.cyanAccent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Knowledge Graph',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Explore topic similarities & unlock nodes through mastery',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Progression Stats Capsule
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.indigo.shade900.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.shade400.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: Colors.amberAccent, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${_progressionService.totalPoints} XP',
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.amberAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 14, color: Colors.white24),
                const SizedBox(width: 8),
                const Icon(Icons.lock_open_rounded, color: Colors.cyanAccent, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${_progressionService.unlockedCount}/${nodes.length}',
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // View Mode Switcher
          IconButton(
            icon: Icon(
              _viewMode == Graph3DViewMode.orbital
                  ? Icons.grain_rounded
                  : Icons.grid_4x4_rounded,
              color: Colors.cyanAccent,
            ),
            tooltip: _viewMode == Graph3DViewMode.orbital
                ? 'Switch to Matrix Grid View'
                : 'Switch to 3D Orbital View',
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == Graph3DViewMode.orbital
                    ? Graph3DViewMode.matrixGrid
                    : Graph3DViewMode.orbital;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. 3D Spatial Canvas
          Positioned.fill(
            child: KnowledgeGraph3DView(
              key: _viewKey,
              nodes: nodes,
              selectedNodeId: _selectedNode?.id,
              onNodeSelected: _onNodeTapped,
              viewMode: _viewMode,
              autoRotate: _autoRotate,
            ),
          ),

          // 2. Interactive HUD Overlay - Navigation Controls (Floating Bar)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('kg_btn_reset_camera'),
                    icon: const Icon(Icons.restart_alt, color: Colors.white70, size: 20),
                    tooltip: 'Reset Camera View',
                    onPressed: () => _viewKey.currentState?.resetCamera(),
                  ),
                  IconButton(
                    key: const Key('kg_btn_zoom_in'),
                    icon: const Icon(Icons.add, color: Colors.white70, size: 20),
                    tooltip: 'Zoom In',
                    onPressed: () => _viewKey.currentState?.zoomIn(),
                  ),
                  IconButton(
                    key: const Key('kg_btn_zoom_out'),
                    icon: const Icon(Icons.remove, color: Colors.white70, size: 20),
                    tooltip: 'Zoom Out',
                    onPressed: () => _viewKey.currentState?.zoomOut(),
                  ),
                  IconButton(
                    key: const Key('kg_btn_autorotate'),
                    icon: Icon(
                      Icons.rotate_right_rounded,
                      color: _autoRotate ? Colors.cyanAccent : Colors.white70,
                      size: 20,
                    ),
                    tooltip: 'Toggle Ambient Auto-Rotate',
                    onPressed: () {
                      setState(() {
                        _autoRotate = !_autoRotate;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom Inspector Card (Selected Node Details & Topic Mission Launch)
          if (_selectedNode != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildTopicInspectorSheet(context, _selectedNode!),
            ),
        ],
      ),
    );
  }

  Widget _buildTopicInspectorSheet(BuildContext context, TopicProgressionNode node) {
    final theme = Theme.of(context);
    final isUnlocked = node.isUnlocked;
    final isMastered = node.isMastered;

    Color badgeColor = Colors.grey;
    String statusText = 'LOCKED';
    IconData statusIcon = Icons.lock_rounded;

    if (isMastered) {
      badgeColor = Colors.amber;
      statusText = 'MASTERED';
      statusIcon = Icons.stars_rounded;
    } else if (isUnlocked) {
      badgeColor = Colors.cyanAccent;
      statusText = 'UNLOCKED';
      statusIcon = Icons.bolt_rounded;
    }

    if (_isInspectorCollapsed) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked ? Colors.cyanAccent.withOpacity(0.4) : Colors.white12,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(statusIcon, color: badgeColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                node.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusText,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('kg_btn_expand_inspector'),
              icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.cyanAccent),
              tooltip: 'Expand Node Details',
              onPressed: () {
                setState(() {
                  _isInspectorCollapsed = false;
                });
              },
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked ? Colors.cyanAccent.withOpacity(0.35) : Colors.white12,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnlocked ? Colors.cyanAccent.withOpacity(0.12) : Colors.black54,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.indigo.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: badgeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          node.category,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.center_focus_strong_rounded, color: Colors.white70),
                tooltip: 'Focus Camera on Node',
                onPressed: () => _viewKey.currentState?.focusOnNode(node.id),
              ),
              IconButton(
                key: const Key('kg_btn_collapse_inspector'),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                tooltip: 'Minimize Details Panel',
                onPressed: () {
                  setState(() {
                    _isInspectorCollapsed = true;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            node.description,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade300, height: 1.3),
          ),
          const SizedBox(height: 12),

          // Mastery Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Topic Mastery',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
              ),
              Text(
                '${node.points} / ${node.pointsToMaster} XP (${(node.progressRatio * 100).toInt()}%)',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: node.progressRatio,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(isMastered ? Colors.amber : Colors.cyanAccent),
            ),
          ),
          const SizedBox(height: 12),

          // Prerequisite & Recurring Similarities Badges
          if (node.isLocked && node.prerequisiteIds.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Locked: Requires ${node.pointsToUnlock} XP in ${node.prerequisiteIds.map((id) => _progressionService.getNode(id)?.label ?? id).join(', ')} to unlock.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.redAccent.shade100),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (node.similarNodeIds.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Connected Topics:',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade400),
                ),
                ...node.similarNodeIds.map((simId) {
                  final target = _progressionService.getNode(simId);
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      if (target != null) {
                        _onNodeTapped(target);
                        _viewKey.currentState?.focusOnNode(target.id);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                      ),
                      child: Text(
                        target?.label ?? simId,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Action Button: Grind Questions
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('kg_btn_grind_topic'),
              icon: Icon(
                isUnlocked ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
                color: isUnlocked ? Colors.black : Colors.white54,
              ),
              label: Text(
                isUnlocked ? 'Grind Questions for ${node.label}' : 'Node Locked',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isUnlocked ? Colors.black : Colors.white54,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isUnlocked ? Colors.cyanAccent : Colors.grey.shade800,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isUnlocked
                  ? () {
                      Navigator.of(context).pop();
                      if (widget.onSelectTopicForGrind != null) {
                        widget.onSelectTopicForGrind!(node);
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
