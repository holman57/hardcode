import 'dart:convert';
import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import 'database_service.dart';

enum TopicUnlockStatus {
  locked,
  unlocked,
  mastered,
}

class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D(this.x, this.y, this.z);

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'z': z};

  factory Vector3D.fromJson(Map<String, dynamic> json) => Vector3D(
        (json['x'] as num?)?.toDouble() ?? 0.0,
        (json['y'] as num?)?.toDouble() ?? 0.0,
        (json['z'] as num?)?.toDouble() ?? 0.0,
      );
}

class TopicProgressionNode {
  final String id;
  final String label;
  final String category;
  final String icon;
  final String description;
  final int pointsToUnlock;
  final int pointsToMaster;
  final List<String> prerequisiteIds;
  final List<String> similarNodeIds;
  final Vector3D position3D;
  final String colorHex;

  int points;
  TopicUnlockStatus status;

  TopicProgressionNode({
    required this.id,
    required this.label,
    required this.category,
    required this.icon,
    required this.description,
    required this.pointsToUnlock,
    required this.pointsToMaster,
    required this.prerequisiteIds,
    required this.similarNodeIds,
    required this.position3D,
    required this.colorHex,
    this.points = 0,
    this.status = TopicUnlockStatus.locked,
  });

  bool get isLocked => status == TopicUnlockStatus.locked;
  bool get isUnlocked => status == TopicUnlockStatus.unlocked || status == TopicUnlockStatus.mastered;
  bool get isMastered => status == TopicUnlockStatus.mastered;

  double get progressRatio {
    if (pointsToMaster <= 0) return 1.0;
    return (points / pointsToMaster).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'category': category,
        'icon': icon,
        'description': description,
        'pointsToUnlock': pointsToUnlock,
        'pointsToMaster': pointsToMaster,
        'prerequisiteIds': prerequisiteIds,
        'similarNodeIds': similarNodeIds,
        'position3D': position3D.toJson(),
        'colorHex': colorHex,
        'points': points,
        'status': status.name,
      };

  factory TopicProgressionNode.fromJson(Map<String, dynamic> json) {
    TopicUnlockStatus stat = TopicUnlockStatus.locked;
    final statusStr = json['status'] as String? ?? 'locked';
    if (statusStr == 'unlocked') {
      stat = TopicUnlockStatus.unlocked;
    } else if (statusStr == 'mastered') {
      stat = TopicUnlockStatus.mastered;
    }

    return TopicProgressionNode(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      icon: json['icon'] as String? ?? 'code',
      description: json['description'] as String? ?? '',
      pointsToUnlock: (json['pointsToUnlock'] as num?)?.toInt() ?? 0,
      pointsToMaster: (json['pointsToMaster'] as num?)?.toInt() ?? 100,
      prerequisiteIds: (json['prerequisiteIds'] as List? ?? []).map((e) => e.toString()).toList(),
      similarNodeIds: (json['similarNodeIds'] as List? ?? []).map((e) => e.toString()).toList(),
      position3D: Vector3D.fromJson(Map<String, dynamic>.from(json['position3D'] as Map? ?? {})),
      colorHex: json['colorHex'] as String? ?? '#3B82F6',
      points: (json['points'] as num?)?.toInt() ?? 0,
      status: stat,
    );
  }
}

class TopicProgressionService {
  TopicProgressionService._internal();
  static final TopicProgressionService instance = TopicProgressionService._internal();

  static const String _storageKey = 'topic_progression_v1';
  final Map<String, TopicProgressionNode> _nodes = {};
  bool _isInitialized = false;

  Map<String, TopicProgressionNode> get nodes => _nodes;
  bool get isInitialized => _isInitialized;

  int get totalPoints => _nodes.values.fold(0, (acc, n) => acc + n.points);
  int get unlockedCount => _nodes.values.where((n) => n.isUnlocked).length;
  int get masteredCount => _nodes.values.where((n) => n.isMastered).length;
  double get overallMasteryRatio {
    if (_nodes.isEmpty) return 0.0;
    final double sumRatio = _nodes.values.fold(0.0, (acc, n) => acc + n.progressRatio);
    return (sumRatio / _nodes.length).clamp(0.0, 1.0);
  }

  /// Initializes the progression graph from persistent memory or default hierarchy.
  Future<void> init() async {
    if (_isInitialized) return;

    // Build default hierarchy
    _buildDefaultHierarchy();

    // Load persisted progress from DatabaseService user memory box
    try {
      if (!DatabaseService.instance.isInitialized) {
        await DatabaseService.instance.init();
      }

      final box = Hive.isBoxOpen(DatabaseService.userMemoryBoxName)
          ? Hive.box(DatabaseService.userMemoryBoxName)
          : await Hive.openBox(DatabaseService.userMemoryBoxName);

      final dynamic raw = box.get(_storageKey);
      if (raw != null) {
        Map<String, dynamic> saved = {};
        if (raw is String) {
          saved = jsonDecode(raw) as Map<String, dynamic>;
        } else if (raw is Map) {
          saved = Map<String, dynamic>.from(raw);
        }

        saved.forEach((id, val) {
          if (_nodes.containsKey(id) && val is Map) {
            final node = _nodes[id]!;
            node.points = (val['points'] as num?)?.toInt() ?? node.points;
            final statusStr = val['status'] as String?;
            if (statusStr == 'mastered') {
              node.status = TopicUnlockStatus.mastered;
            } else if (statusStr == 'unlocked') {
              node.status = TopicUnlockStatus.unlocked;
            } else if (statusStr == 'locked') {
              node.status = TopicUnlockStatus.locked;
            }
          }
        });
      }
    } catch (e) {
      print('Notice: Failed loading saved topic progression: $e. Using default hierarchy.');
    }

    _evaluateAllUnlocks();
    _isInitialized = true;
  }

  /// Populates the initial topic progression network with 3D coordinates and prerequisite links.
  void _buildDefaultHierarchy() {
    _nodes.clear();

    final defaults = [
      // Root: Grand Domain (Unlocked by default)
      TopicProgressionNode(
        id: 'domain:computer_science',
        label: 'Computer Science',
        category: 'Core Domain',
        icon: 'hub',
        description: 'Foundational computation theory, discrete mathematics, and software primitives.',
        pointsToUnlock: 0,
        pointsToMaster: 100,
        prerequisiteIds: [],
        similarNodeIds: ['topic:algorithms', 'topic:system_architecture'],
        position3D: const Vector3D(0, 0, 0),
        colorHex: '#6366F1', // Indigo
        status: TopicUnlockStatus.unlocked,
      ),

      // Tier 1 Sub-Topics (Unlock via Computer Science mastery)
      TopicProgressionNode(
        id: 'topic:programming_languages',
        label: 'Programming Languages',
        category: 'Sub-Topic',
        icon: 'terminal',
        description: 'Syntax paradigms, semantics, type systems, and compiler design.',
        pointsToUnlock: 30, // Requires 30 CS Points
        pointsToMaster: 100,
        prerequisiteIds: ['domain:computer_science'],
        similarNodeIds: ['topic:algorithms', 'lang:python', 'lang:rust'],
        position3D: const Vector3D(170, 45, 60),
        colorHex: '#3B82F6', // Blue
      ),
      TopicProgressionNode(
        id: 'topic:algorithms',
        label: 'Algorithms & Complexity',
        category: 'Sub-Topic',
        icon: 'psychology',
        description: 'Sorting, searching, graph traversals, dynamic programming, and asymptotic Big-O.',
        pointsToUnlock: 20, // Requires 20 CS Points
        pointsToMaster: 100,
        prerequisiteIds: ['domain:computer_science'],
        similarNodeIds: ['topic:data_structures', 'topic:programming_languages'],
        position3D: const Vector3D(-130, 110, -50),
        colorHex: '#8B5CF6', // Purple
      ),
      TopicProgressionNode(
        id: 'topic:data_structures',
        label: 'Data Structures',
        category: 'Sub-Topic',
        icon: 'account_tree',
        description: 'Arrays, linked lists, trees, hash tables, heaps, and trie structures.',
        pointsToUnlock: 20, // Requires 20 CS Points
        pointsToMaster: 100,
        prerequisiteIds: ['domain:computer_science'],
        similarNodeIds: ['topic:algorithms', 'topic:system_architecture'],
        position3D: const Vector3D(-150, -100, 40),
        colorHex: '#EC4899', // Pink
      ),
      TopicProgressionNode(
        id: 'topic:system_architecture',
        label: 'System Architecture',
        category: 'Sub-Topic',
        icon: 'memory',
        description: 'Computer hardware, CPU scheduling, caching hierarchies, and concurrency.',
        pointsToUnlock: 40,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:computer_science'],
        similarNodeIds: ['topic:databases', 'lang:rust', 'lang:cpp'],
        position3D: const Vector3D(70, -160, -80),
        colorHex: '#F59E0B', // Amber
      ),
      TopicProgressionNode(
        id: 'topic:databases',
        label: 'Database Systems',
        category: 'Sub-Topic',
        icon: 'storage',
        description: 'Relational schemas, ACID properties, NoSQL stores, and B-tree indexing.',
        pointsToUnlock: 35,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:computer_science'],
        similarNodeIds: ['topic:system_architecture', 'lang:sql'],
        position3D: const Vector3D(90, 150, -70),
        colorHex: '#10B981', // Emerald
      ),

      // Tier 2 Specific Languages (Unlock via Programming Languages mastery)
      TopicProgressionNode(
        id: 'lang:python',
        label: 'Python',
        category: 'Language',
        icon: 'code',
        description: 'High-level dynamic language focusing on readable syntax, data science, and scripting.',
        pointsToUnlock: 25, // Requires 25 Programming Language Points
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages'],
        similarNodeIds: ['lang:javascript', 'topic:algorithms'],
        position3D: const Vector3D(290, 110, 120),
        colorHex: '#38BDF8', // Cyan
      ),
      TopicProgressionNode(
        id: 'lang:javascript',
        label: 'JavaScript',
        category: 'Language',
        icon: 'javascript',
        description: 'Event-driven, asynchronous language powering web applications and runtimes.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages'],
        similarNodeIds: ['lang:python'],
        position3D: const Vector3D(320, -30, 90),
        colorHex: '#FBBF24', // Yellow
      ),
      TopicProgressionNode(
        id: 'lang:rust',
        label: 'Rust',
        category: 'Language',
        icon: 'security',
        description: 'Systems programming language guaranteeing memory safety without a garbage collector.',
        pointsToUnlock: 45,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages', 'topic:system_architecture'],
        similarNodeIds: ['lang:cpp', 'topic:system_architecture'],
        position3D: const Vector3D(270, 200, -40),
        colorHex: '#F97316', // Orange
      ),
      TopicProgressionNode(
        id: 'lang:cpp',
        label: 'C++',
        category: 'Language',
        icon: 'developer_board',
        description: 'High-performance compiled language with manual memory management and OOP.',
        pointsToUnlock: 40,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages', 'topic:system_architecture'],
        similarNodeIds: ['lang:rust', 'topic:system_architecture'],
        position3D: const Vector3D(230, -170, 140),
        colorHex: '#0284C7', // Sky Blue
      ),
      TopicProgressionNode(
        id: 'lang:go',
        label: 'Go',
        category: 'Language',
        icon: 'rocket_launch',
        description: 'Statically typed compiled language designed for concurrency and scalable backends.',
        pointsToUnlock: 35,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages'],
        similarNodeIds: ['lang:rust', 'topic:system_architecture'],
        position3D: const Vector3D(350, 70, -90),
        colorHex: '#06B6D4', // Teal
      ),
      TopicProgressionNode(
        id: 'lang:sql',
        label: 'SQL',
        category: 'Language',
        icon: 'table_chart',
        description: 'Declarative query language for managing and analyzing relational data tables.',
        pointsToUnlock: 30,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages', 'topic:databases'],
        similarNodeIds: ['topic:databases'],
        position3D: const Vector3D(200, 270, -110),
        colorHex: '#14B8A6', // Mint
      ),
    ];

    for (final node in defaults) {
      _nodes[node.id] = node;
    }
  }

  /// Adds mastery points to a specific topic node and triggers cascading unlock checks.
  Future<List<TopicProgressionNode>> addTopicPoints(String topicId, int pointsEarned) async {
    final List<TopicProgressionNode> newlyUnlocked = [];
    if (!_nodes.containsKey(topicId)) {
      // If node id is not prefixed, attempt matching by label or alias
      final matched = _findNodeByAlias(topicId);
      if (matched == null) return newlyUnlocked;
      topicId = matched.id;
    }

    final targetNode = _nodes[topicId]!;
    targetNode.points += pointsEarned;

    // Check if target node reached mastery
    if (targetNode.points >= targetNode.pointsToMaster && targetNode.status != TopicUnlockStatus.mastered) {
      targetNode.status = TopicUnlockStatus.mastered;
    } else if (targetNode.points > 0 && targetNode.status == TopicUnlockStatus.locked) {
      targetNode.status = TopicUnlockStatus.unlocked;
    }

    // Cascade unlock checks to all downstream dependent nodes
    final unlockedNodes = _evaluateAllUnlocks();
    newlyUnlocked.addAll(unlockedNodes);

    // Save changes to persistent storage
    await save();

    return newlyUnlocked;
  }

  /// Evaluates prerequisites for all locked nodes and unlocks any that satisfy their requirements.
  List<TopicProgressionNode> _evaluateAllUnlocks() {
    final List<TopicProgressionNode> unlockedList = [];
    bool changed = true;

    while (changed) {
      changed = false;
      for (final node in _nodes.values) {
        if (node.isUnlocked) continue;

        // Check prerequisites
        bool canUnlock = true;
        for (final prereqId in node.prerequisiteIds) {
          final parent = _nodes[prereqId];
          if (parent == null || !parent.isUnlocked || parent.points < node.pointsToUnlock) {
            canUnlock = false;
            break;
          }
        }

        if (canUnlock) {
          node.status = TopicUnlockStatus.unlocked;
          unlockedList.add(node);
          changed = true;
        }
      }
    }

    return unlockedList;
  }

  /// Finds a node by raw title, subject, or language string.
  TopicProgressionNode? _findNodeByAlias(String alias) {
    final clean = alias.trim().toLowerCase();
    for (final n in _nodes.values) {
      if (n.id.toLowerCase() == clean ||
          n.label.toLowerCase() == clean ||
          n.id.endsWith(':$clean')) {
        return n;
      }
    }
    // Partial substring fallback
    for (final n in _nodes.values) {
      if (clean.contains(n.label.toLowerCase()) || n.label.toLowerCase().contains(clean)) {
        return n;
      }
    }
    return null;
  }

  TopicProgressionNode? getNode(String id) => _nodes[id] ?? _findNodeByAlias(id);

  /// Saves the current progression state into local Hive storage.
  Future<void> save() async {
    try {
      final box = Hive.isBoxOpen(DatabaseService.userMemoryBoxName)
          ? Hive.box(DatabaseService.userMemoryBoxName)
          : await Hive.openBox(DatabaseService.userMemoryBoxName);

      final Map<String, dynamic> exportData = {};
      _nodes.forEach((k, v) {
        exportData[k] = {
          'points': v.points,
          'status': v.status.name,
        };
      });

      await box.put(_storageKey, jsonEncode(exportData));
    } catch (e) {
      print('Notice: Could not persist topic progression to Hive: $e');
    }
  }

  /// Resets all progression to default (useful for testing or full reset).
  Future<void> resetProgress() async {
    _buildDefaultHierarchy();
    await save();
  }
}
