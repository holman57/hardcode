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
      // --- CORE MASTER DOMAINS (Unlocked on launch for full galaxy exploration) ---
      TopicProgressionNode(
        id: 'domain:computer_science',
        label: 'Computer Science',
        category: 'Core Domain',
        icon: 'hub',
        description: 'Foundational computation theory, discrete mathematics, and software primitives.',
        pointsToUnlock: 0,
        pointsToMaster: 100,
        prerequisiteIds: [],
        similarNodeIds: ['topic:algorithms', 'topic:data_structures', 'domain:system_architecture'],
        position3D: const Vector3D(0, 0, 0),
        colorHex: '#6366F1', // Indigo
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'domain:networking',
        label: 'Computer Networking',
        category: 'Core Domain',
        icon: 'wifi_tethering',
        description: 'OSI 7-layer stack, TCP/IP handshakes, routing protocols, DNS, TLS, and HTTP/3.',
        pointsToUnlock: 0,
        pointsToMaster: 100,
        prerequisiteIds: [],
        similarNodeIds: ['topic:tcp_ip', 'domain:cloud_computing', 'domain:cybersecurity'],
        position3D: const Vector3D(-190, 80, 130),
        colorHex: '#06B6D4', // Cyan
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'domain:ai_ml',
        label: 'Artificial Intelligence & ML',
        category: 'Core Domain',
        icon: 'psychology',
        description: 'Neural networks, transformer attention mechanisms, backpropagation, and RL.',
        pointsToUnlock: 0,
        pointsToMaster: 100,
        prerequisiteIds: [],
        similarNodeIds: ['topic:algorithms', 'lang:python', 'domain:data_science'],
        position3D: const Vector3D(180, -90, 140),
        colorHex: '#A855F7', // Purple
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'domain:operating_systems',
        label: 'Operating Systems',
        category: 'Core Domain',
        icon: 'terminal',
        description: 'Kernel architectures, virtual memory paging, CPU scheduling, and syscalls.',
        pointsToUnlock: 0,
        pointsToMaster: 100,
        prerequisiteIds: [],
        similarNodeIds: ['domain:system_architecture', 'topic:concurrency', 'lang:rust', 'lang:bash'],
        position3D: const Vector3D(-140, -160, -90),
        colorHex: '#F97316', // Orange
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'domain:cloud_computing',
        label: 'Cloud & Distributed Systems',
        category: 'Core Domain',
        icon: 'cloud_queue',
        description: 'CAP theorem, distributed consensus (Raft/Paxos), Kubernetes, serverless, and IAM.',
        pointsToUnlock: 0,
        pointsToMaster: 100,
        prerequisiteIds: [],
        similarNodeIds: ['domain:networking', 'topic:distributed_systems', 'lang:go'],
        position3D: const Vector3D(190, 130, -120),
        colorHex: '#0284C7', // Sky Blue
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'domain:cybersecurity',
        label: 'Cybersecurity & Cryptography',
        category: 'Core Domain',
        icon: 'security',
        description: 'Public-key RSA/ECC cryptography, zero-trust architectures, OWASP vulnerabilities.',
        pointsToUnlock: 0,
        pointsToMaster: 100,
        prerequisiteIds: [],
        similarNodeIds: ['domain:networking', 'domain:operating_systems', 'lang:rust'],
        position3D: const Vector3D(-210, 40, -140),
        colorHex: '#F43F5E', // Rose
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'domain:system_architecture',
        label: 'System Architecture',
        category: 'Core Domain',
        icon: 'memory',
        description: 'CPU microarchitecture, Von Neumann vs Harvard, L1/L2/L3 cache hierarchies, TLB.',
        pointsToUnlock: 0,
        pointsToMaster: 100,
        prerequisiteIds: [],
        similarNodeIds: ['domain:operating_systems', 'domain:databases', 'lang:cpp', 'lang:rust'],
        position3D: const Vector3D(80, -170, -80),
        colorHex: '#F59E0B', // Amber
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'domain:databases',
        label: 'Database Systems',
        category: 'Core Domain',
        icon: 'storage',
        description: 'Relational ACID guarantees, write-ahead logs, B+ trees, LSM trees, and NoSQL.',
        pointsToUnlock: 0,
        pointsToMaster: 100,
        prerequisiteIds: [],
        similarNodeIds: ['domain:system_architecture', 'lang:sql', 'domain:cloud_computing'],
        position3D: const Vector3D(100, 180, -70),
        colorHex: '#10B981', // Emerald
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'domain:software_engineering',
        label: 'Software Engineering',
        category: 'Core Domain',
        icon: 'architecture',
        description: 'Design patterns (GoF), SOLID principles, event-driven CQRS, and CI/CD pipelines.',
        pointsToUnlock: 0,
        pointsToMaster: 100,
        prerequisiteIds: [],
        similarNodeIds: ['topic:programming_languages', 'domain:cloud_computing'],
        position3D: const Vector3D(-90, 190, 80),
        colorHex: '#3B82F6', // Blue
        status: TopicUnlockStatus.unlocked,
      ),

      // --- SUB-TOPICS ---
      TopicProgressionNode(
        id: 'topic:programming_languages',
        label: 'Programming Languages',
        category: 'Sub-Topic',
        icon: 'terminal',
        description: 'Type systems, polymorphism, memory safety, functional vs OOP paradigms.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:computer_science'],
        similarNodeIds: ['lang:python', 'lang:rust', 'lang:javascript', 'lang:go'],
        position3D: const Vector3D(130, 45, 50),
        colorHex: '#3B82F6',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:algorithms',
        label: 'Algorithms & Complexity',
        category: 'Sub-Topic',
        icon: 'psychology',
        description: 'Sorting, graph traversals (Dijkstra, A*), dynamic programming, Big-O.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:computer_science'],
        similarNodeIds: ['topic:data_structures', 'domain:ai_ml'],
        position3D: const Vector3D(-110, 90, -40),
        colorHex: '#8B5CF6',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:data_structures',
        label: 'Data Structures',
        category: 'Sub-Topic',
        icon: 'account_tree',
        description: 'Trees, Hash Tables, Heaps, Disjoint Sets, Tries, and Bloom Filters.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:computer_science'],
        similarNodeIds: ['topic:algorithms', 'domain:databases'],
        position3D: const Vector3D(-130, -90, 50),
        colorHex: '#EC4899',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:concurrency',
        label: 'Concurrency & Threads',
        category: 'Sub-Topic',
        icon: 'alt_route',
        description: 'Mutexes, deadlocks, race conditions, atomic operations, and async runtimes.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:operating_systems'],
        similarNodeIds: ['domain:operating_systems', 'lang:go', 'lang:rust'],
        position3D: const Vector3D(-50, -200, 40),
        colorHex: '#FB923C',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:tcp_ip',
        label: 'TCP/IP & Protocols',
        category: 'Sub-Topic',
        icon: 'lan',
        description: 'Three-way handshakes, congestion control algorithms, flow control windows.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:networking'],
        similarNodeIds: ['domain:networking', 'domain:cybersecurity'],
        position3D: const Vector3D(-240, 130, 90),
        colorHex: '#14B8A6',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:distributed_systems',
        label: 'Distributed Consensus',
        category: 'Sub-Topic',
        icon: 'dns',
        description: 'Leader election, Raft log replication, gossip protocols, and Byzantine fault tolerance.',
        pointsToUnlock: 30,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:cloud_computing'],
        similarNodeIds: ['domain:cloud_computing', 'domain:databases'],
        position3D: const Vector3D(230, 170, -90),
        colorHex: '#60A5FA',
        status: TopicUnlockStatus.unlocked,
      ),

      // --- LANGUAGES (Orbital Shell) ---
      TopicProgressionNode(
        id: 'lang:python',
        label: 'Python',
        category: 'Language',
        icon: 'code',
        description: 'Dynamic scripting, list comprehensions, generators, and data science tooling.',
        pointsToUnlock: 15,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages'],
        similarNodeIds: ['domain:ai_ml', 'lang:javascript'],
        position3D: const Vector3D(270, 100, 110),
        colorHex: '#38BDF8',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'lang:javascript',
        label: 'JavaScript',
        category: 'Language',
        icon: 'javascript',
        description: 'Event-driven, asynchronous event loop, prototype inheritance, and Web APIs.',
        pointsToUnlock: 15,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages'],
        similarNodeIds: ['lang:typescript', 'lang:python'],
        position3D: const Vector3D(300, -30, 90),
        colorHex: '#FBBF24',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'lang:typescript',
        label: 'TypeScript',
        category: 'Language',
        icon: 'integration_instructions',
        description: 'Static type checking, generics, conditional types, and ECMAScript superset.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['lang:javascript'],
        similarNodeIds: ['lang:javascript', 'topic:programming_languages'],
        position3D: const Vector3D(320, -80, 40),
        colorHex: '#2563EB',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'lang:rust',
        label: 'Rust',
        category: 'Language',
        icon: 'security',
        description: 'Compile-time borrow checker, zero-cost abstractions, fearless concurrency.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages', 'domain:system_architecture'],
        similarNodeIds: ['lang:cpp', 'domain:operating_systems'],
        position3D: const Vector3D(260, 200, -40),
        colorHex: '#EA580C',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'lang:cpp',
        label: 'C++',
        category: 'Language',
        icon: 'developer_board',
        description: 'Manual memory management, RAII, pointers, template metaprogramming.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages', 'domain:system_architecture'],
        similarNodeIds: ['lang:rust', 'domain:system_architecture'],
        position3D: const Vector3D(220, -160, 140),
        colorHex: '#0284C7',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'lang:go',
        label: 'Go',
        category: 'Language',
        icon: 'rocket_launch',
        description: 'Lightweight goroutines, CSP channels, fast compilation, cloud microservices.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages'],
        similarNodeIds: ['domain:cloud_computing', 'topic:concurrency'],
        position3D: const Vector3D(330, 70, -90),
        colorHex: '#0D9488',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'lang:sql',
        label: 'SQL',
        category: 'Language',
        icon: 'table_chart',
        description: 'Declarative queries, relational algebra, window functions, indexing plans.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:databases'],
        similarNodeIds: ['domain:databases'],
        position3D: const Vector3D(190, 260, -100),
        colorHex: '#059669',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'lang:java',
        label: 'Java',
        category: 'Language',
        icon: 'coffee',
        description: 'JVM bytecode, garbage collection, strong static typing, enterprise frameworks.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages'],
        similarNodeIds: ['lang:csharp', 'domain:software_engineering'],
        position3D: const Vector3D(250, -130, -70),
        colorHex: '#DC2626',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'lang:csharp',
        label: 'C#',
        category: 'Language',
        icon: 'grid_view',
        description: '.NET CLR runtime, LINQ, pattern matching, asynchronous task programming.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages'],
        similarNodeIds: ['lang:java', 'domain:software_engineering'],
        position3D: const Vector3D(230, -190, -30),
        colorHex: '#7C3AED',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'lang:bash',
        label: 'Bash & Shell',
        category: 'Language',
        icon: 'terminal',
        description: 'UNIX pipelines, streams (stdin/stdout/stderr), POSIX scripts, CLI automation.',
        pointsToUnlock: 15,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:operating_systems'],
        similarNodeIds: ['domain:operating_systems', 'domain:cloud_computing'],
        position3D: const Vector3D(-250, -80, -110),
        colorHex: '#10B981',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'lang:dart',
        label: 'Dart & Flutter',
        category: 'Language',
        icon: 'flutter_dash',
        description: 'Ahead-of-time (AOT) and JIT compilation, reactive UI trees, Flutter widgets.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages'],
        similarNodeIds: ['lang:javascript', 'lang:typescript'],
        position3D: const Vector3D(160, 220, 80),
        colorHex: '#38BDF8',
        status: TopicUnlockStatus.unlocked,
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
