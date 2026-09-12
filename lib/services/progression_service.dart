import 'dart:convert';
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
      // --- CORE MASTER DOMAINS (Galaxy Sectors spread at R ≈ 380 - 450) ---
      TopicProgressionNode(
        id: 'domain:computer_science',
        label: 'Computer Science',
        category: 'Core Domain',
        icon: 'hub',
        description: 'Foundational computation theory, discrete mathematics, and software primitives.',
        pointsToUnlock: 0,
        pointsToMaster: 100,
        prerequisiteIds: [],
        similarNodeIds: ['topic:algorithms', 'topic:data_structures', 'topic:programming_languages'],
        position3D: const Vector3D(0, 0, 0), // Galactic Core
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
        similarNodeIds: ['topic:tcp_ip', 'domain:cloud_computing', 'domain:security_engineering'],
        position3D: const Vector3D(-380, 160, 220), // Sector Alpha
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
        similarNodeIds: ['topic:neural_networks', 'lang:python', 'topic:algorithms'],
        position3D: const Vector3D(350, -220, 250), // Sector Beta
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
        similarNodeIds: ['topic:concurrency', 'topic:virtual_memory', 'domain:system_architecture', 'lang:rust'],
        position3D: const Vector3D(-260, -320, -180), // Sector Gamma
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
        similarNodeIds: ['topic:distributed_systems', 'domain:networking', 'lang:go'],
        position3D: const Vector3D(360, 240, -250), // Sector Delta
        colorHex: '#0284C7', // Sky Blue
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'domain:security_engineering',
        label: 'Cybersecurity, Cryptography & Security Engineering',
        category: 'Core Domain',
        icon: 'security',
        description: 'Threat modeling (STRIDE), SSDLC (SAST/DAST), binary mitigations (ASLR/DEP/canaries, ROP), Zero Trust IAM, and applied cryptography (AES-GCM, RSA, ECC, Argon2id, TLS 1.3).',
        pointsToUnlock: 0,
        pointsToMaster: 100,
        prerequisiteIds: [],
        similarNodeIds: ['topic:binary_exploitation', 'topic:cryptography', 'leaf:rust:ownership_borrowing'],
        position3D: const Vector3D(-400, 40, -250), // Sector Epsilon
        colorHex: '#E11D48', // Crimson/Rose
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
        similarNodeIds: ['domain:operating_systems', 'lang:cpp', 'topic:cache_hierarchy'],
        position3D: const Vector3D(160, -350, -170), // Sector Zeta
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
        similarNodeIds: ['lang:sql', 'topic:database_acid', 'domain:cloud_computing'],
        position3D: const Vector3D(220, 360, -140), // Sector Eta
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
        similarNodeIds: ['topic:design_patterns', 'topic:programming_languages', 'domain:cloud_computing'],
        position3D: const Vector3D(-160, 360, 160), // Sector Theta
        colorHex: '#3B82F6', // Blue
        status: TopicUnlockStatus.unlocked,
      ),

      // --- SUBTOPICS CLUSTERED AROUND GALACTIC CORE (Computer Science) ---
      TopicProgressionNode(
        id: 'topic:programming_languages',
        label: 'Programming Languages',
        category: 'Sub-Topic',
        icon: 'terminal',
        description: 'Type systems, polymorphism, memory safety, functional vs OOP paradigms.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:computer_science'],
        similarNodeIds: ['lang:rust', 'lang:python', 'lang:go', 'lang:javascript'],
        position3D: const Vector3D(70, 40, 25), // Local cluster ~84 from CS Hub
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
        position3D: const Vector3D(-75, 50, -35), // Local cluster ~96 from CS Hub
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
        position3D: const Vector3D(-80, -55, 40), // Local cluster ~105 from CS Hub
        colorHex: '#EC4899',
        status: TopicUnlockStatus.unlocked,
      ),

      // --- RUST & GRANULAR LEAF NODES (Clustered around Programming Languages) ---
      TopicProgressionNode(
        id: 'lang:rust',
        label: 'Rust',
        category: 'Language',
        icon: 'security',
        description: 'Compile-time borrow checker, zero-cost abstractions, fearless concurrency.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages'],
        similarNodeIds: ['domain:security_engineering', 'domain:operating_systems', 'lang:cpp'],
        position3D: const Vector3D(125, 75, 45), // ~67 from PL topic
        colorHex: '#EA580C',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'leaf:rust:variable_declaration',
        label: 'Rust: Variable Declaration & Mutability',
        category: 'Leaf Concept',
        icon: 'edit_note',
        description: 'Immutable by default bindings via let, explicit mutable bindings with mut, compile-time constants, and lexical variable shadowing.',
        pointsToUnlock: 15,
        pointsToMaster: 100,
        prerequisiteIds: ['lang:rust'],
        similarNodeIds: ['topic:programming_languages', 'leaf:python:variable_declaration', 'leaf:go:variable_declaration'],
        position3D: const Vector3D(155, 95, 55), // Tightly clustered r=38 from Rust
        colorHex: '#F97316',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'leaf:rust:ownership_borrowing',
        label: 'Rust: Borrow Checker & Ownership',
        category: 'Leaf Concept',
        icon: 'lock_outline',
        description: 'Single owner rule, move semantics for non-Copy types, and exclusive mutable borrow XOR multiple shared immutable borrows.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['lang:rust'],
        similarNodeIds: ['domain:security_engineering', 'topic:concurrency', 'topic:binary_exploitation'],
        position3D: const Vector3D(165, 55, 75), // Tightly clustered r=53 from Rust
        colorHex: '#FB923C',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'leaf:rust:lifetimes',
        label: 'Rust: Lifetimes & References',
        category: 'Leaf Concept',
        icon: 'timelapse',
        description: 'Generic lifetime annotations (\'a, \'static) proving to the compiler references never outlive underlying allocated memory.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['leaf:rust:ownership_borrowing'],
        similarNodeIds: ['domain:operating_systems', 'leaf:cpp:raii_memory'],
        position3D: const Vector3D(145, 110, 20), // Tightly clustered r=47 from Rust
        colorHex: '#F59E0B',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'leaf:rust:pattern_matching',
        label: 'Rust: Pattern Matching & Enums',
        category: 'Leaf Concept',
        icon: 'call_split',
        description: 'Exhaustive pattern matching with match, if let expressions, destructuring algebraic enums, and pattern guards.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['lang:rust'],
        similarNodeIds: ['topic:algorithms'],
        position3D: const Vector3D(105, 105, 70), // Tightly clustered r=44 from Rust
        colorHex: '#FBBF24',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'leaf:rust:error_handling',
        label: 'Rust: Error Handling (Result & Option)',
        category: 'Leaf Concept',
        icon: 'verified',
        description: 'Type-safe error propagation via Result<T, E> and Option<T> with the ? early-return operator.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['lang:rust'],
        similarNodeIds: ['domain:software_engineering', 'topic:programming_languages'],
        position3D: const Vector3D(160, 80, 10), // Tightly clustered r=49 from Rust
        colorHex: '#10B981',
        status: TopicUnlockStatus.unlocked,
      ),

      // --- OTHER CORE LANGUAGES & LEAF NODES (Clustered around PL Core) ---
      TopicProgressionNode(
        id: 'lang:python',
        label: 'Python',
        category: 'Language',
        icon: 'code',
        description: 'Dynamic scripting, list comprehensions, generators, and data science tooling.',
        pointsToUnlock: 15,
        pointsToMaster: 100,
        prerequisiteIds: ['topic:programming_languages'],
        similarNodeIds: ['domain:ai_ml', 'leaf:python:variable_declaration'],
        position3D: const Vector3D(120, -60, 40),
        colorHex: '#38BDF8',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'leaf:python:variable_declaration',
        label: 'Python: Dynamic Typing & Binding',
        category: 'Leaf Concept',
        icon: 'notes',
        description: 'Dynamic typing, reference assignment, and scope bindings (global, nonlocal).',
        pointsToUnlock: 10,
        pointsToMaster: 100,
        prerequisiteIds: ['lang:python'],
        similarNodeIds: ['leaf:rust:variable_declaration', 'leaf:javascript:variable_declaration'],
        position3D: const Vector3D(145, -80, 50),
        colorHex: '#60A5FA',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'leaf:python:memory_model',
        label: 'Python: Memory Model & GIL',
        category: 'Leaf Concept',
        icon: 'memory',
        description: 'CPython reference counting, cyclic garbage collection, and Global Interpreter Lock.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['lang:python'],
        similarNodeIds: ['topic:concurrency', 'leaf:rust:ownership_borrowing'],
        position3D: const Vector3D(140, -40, 70),
        colorHex: '#818CF8',
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
        position3D: const Vector3D(70, 110, -50),
        colorHex: '#0D9488',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'leaf:go:goroutines_channels',
        label: 'Go: Goroutines & CSP Channels',
        category: 'Leaf Concept',
        icon: 'alt_route',
        description: 'M:N cooperative green threads and typed CSP communication channels.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['lang:go'],
        similarNodeIds: ['topic:concurrency', 'domain:cloud_computing'],
        position3D: const Vector3D(60, 130, -80),
        colorHex: '#14B8A6',
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
        similarNodeIds: ['lang:typescript', 'leaf:javascript:event_loop'],
        position3D: const Vector3D(110, -20, -60),
        colorHex: '#FBBF24',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'leaf:javascript:event_loop',
        label: 'JavaScript: Event Loop & Microtasks',
        category: 'Leaf Concept',
        icon: 'sync',
        description: 'Single-threaded event loop, call stack, microtask queue, and asynchronous execution.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['lang:javascript'],
        similarNodeIds: ['topic:concurrency', 'lang:typescript'],
        position3D: const Vector3D(125, 0, -90),
        colorHex: '#F59E0B',
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
        position3D: const Vector3D(135, -45, -30),
        colorHex: '#2563EB',
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
        position3D: const Vector3D(80, -90, -40),
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
        position3D: const Vector3D(50, -110, 30),
        colorHex: '#7C3AED',
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
        position3D: const Vector3D(100, 80, 70),
        colorHex: '#38BDF8',
        status: TopicUnlockStatus.unlocked,
      ),

      // --- NETWORKING SECTOR CLUSTER (-380, 160, 220) ---
      TopicProgressionNode(
        id: 'topic:tcp_ip',
        label: 'TCP/IP & Transport Protocols',
        category: 'Sub-Topic',
        icon: 'lan',
        description: 'Three-way handshakes, congestion control algorithms, flow control windows.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:networking'],
        similarNodeIds: ['domain:networking', 'topic:tls_encryption'],
        position3D: const Vector3D(-350, 195, 200), // r=51 from Networking
        colorHex: '#14B8A6',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:dns_routing',
        label: 'DNS & BGP Routing',
        category: 'Sub-Topic',
        icon: 'alt_route',
        description: 'Hierarchical DNS resolution, authoritative servers, Anycast, and BGP routing.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:networking'],
        similarNodeIds: ['domain:networking', 'domain:cloud_computing'],
        position3D: const Vector3D(-410, 130, 245), // r=50 from Networking
        colorHex: '#06B6D4',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:tls_encryption',
        label: 'TLS 1.3 Cryptographic Transport',
        category: 'Sub-Topic',
        icon: 'enhanced_encryption',
        description: 'Diffie-Hellman ephemeral key exchanges, forward secrecy, and AEAD ciphers.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:networking'],
        similarNodeIds: ['domain:security_engineering', 'topic:cryptography'],
        position3D: const Vector3D(-360, 130, 250), // r=47 from Networking
        colorHex: '#38BDF8',
        status: TopicUnlockStatus.unlocked,
      ),

      // --- SECURITY ENGINEERING SECTOR CLUSTER (-400, 40, -250) ---
      TopicProgressionNode(
        id: 'topic:binary_exploitation',
        label: 'Binary Exploitation & Mitigations',
        category: 'Sub-Topic',
        icon: 'gavel',
        description: 'Stack/heap overflows, ROP gadget chains, and defenses (ASLR, DEP, stack canaries).',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:security_engineering'],
        similarNodeIds: ['domain:operating_systems', 'leaf:rust:ownership_borrowing'],
        position3D: const Vector3D(-370, 65, -225), // r=46 from Security
        colorHex: '#F43F5E',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:cryptography',
        label: 'Applied Cryptography',
        category: 'Sub-Topic',
        icon: 'key',
        description: 'Symmetric encryption (AES-256-GCM), asymmetric cryptosystems (RSA, ECC), hashing.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:security_engineering'],
        similarNodeIds: ['topic:tls_encryption', 'domain:networking'],
        position3D: const Vector3D(-430, 15, -275), // r=46 from Security
        colorHex: '#E11D48',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:threat_modeling',
        label: 'Threat Modeling & Zero Trust',
        category: 'Sub-Topic',
        icon: 'policy',
        description: 'STRIDE taxonomy, Attack Trees, least privilege, and Zero Trust architectures.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:security_engineering'],
        similarNodeIds: ['domain:software_engineering', 'domain:cloud_computing'],
        position3D: const Vector3D(-380, 15, -280), // r=46 from Security
        colorHex: '#FB7185',
        status: TopicUnlockStatus.unlocked,
      ),

      // --- OPERATING SYSTEMS SECTOR CLUSTER (-260, -320, -180) ---
      TopicProgressionNode(
        id: 'topic:concurrency',
        label: 'Concurrency & Deadlocks',
        category: 'Sub-Topic',
        icon: 'alt_route',
        description: 'Mutexes, deadlocks, race conditions, atomic operations, and async runtimes.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:operating_systems'],
        similarNodeIds: ['leaf:rust:ownership_borrowing', 'leaf:go:goroutines_channels'],
        position3D: const Vector3D(-230, -295, -160), // r=44 from OS
        colorHex: '#FB923C',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:virtual_memory',
        label: 'Virtual Memory & Paging',
        category: 'Sub-Topic',
        icon: 'memory',
        description: 'Page tables, Translation Lookaside Buffers (TLB), page faults, and demand paging.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:operating_systems'],
        similarNodeIds: ['domain:system_architecture', 'topic:cache_hierarchy'],
        position3D: const Vector3D(-285, -345, -155), // r=43 from OS
        colorHex: '#F97316',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:kernel_scheduling',
        label: 'Kernel Architecture & Scheduling',
        category: 'Sub-Topic',
        icon: 'schedule',
        description: 'Preemptive CPU scheduling, context switching, syscall traps, and interrupt handling.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:operating_systems'],
        similarNodeIds: ['domain:system_architecture', 'topic:concurrency'],
        position3D: const Vector3D(-240, -345, -210), // r=45 from OS
        colorHex: '#EA580C',
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
        position3D: const Vector3D(-220, -350, -140),
        colorHex: '#10B981',
        status: TopicUnlockStatus.unlocked,
      ),

      // --- CLOUD COMPUTING SECTOR CLUSTER (360, 240, -250) ---
      TopicProgressionNode(
        id: 'topic:distributed_systems',
        label: 'Distributed Systems & CAP',
        category: 'Sub-Topic',
        icon: 'dns',
        description: 'Leader election, distributed consensus, gossip protocols, and CAP theorem trade-offs.',
        pointsToUnlock: 30,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:cloud_computing'],
        similarNodeIds: ['domain:cloud_computing', 'domain:databases'],
        position3D: const Vector3D(335, 265, -225), // r=43 from Cloud
        colorHex: '#60A5FA',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:consensus_raft',
        label: 'Consensus & Raft Protocol',
        category: 'Sub-Topic',
        icon: 'how_to_vote',
        description: 'Raft leader election, log replication, safety invariants, and Paxos consensus.',
        pointsToUnlock: 30,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:cloud_computing'],
        similarNodeIds: ['topic:distributed_systems', 'domain:databases'],
        position3D: const Vector3D(385, 215, -270), // r=41 from Cloud
        colorHex: '#38BDF8',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:container_orchestration',
        label: 'Container Orchestration & K8s',
        category: 'Sub-Topic',
        icon: 'widgets',
        description: 'Cgroups, namespaces, OCI container images, Kubernetes pods, and ingress routing.',
        pointsToUnlock: 30,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:cloud_computing'],
        similarNodeIds: ['domain:software_engineering', 'topic:ci_cd_pipelines'],
        position3D: const Vector3D(340, 215, -280), // r=44 from Cloud
        colorHex: '#0284C7',
        status: TopicUnlockStatus.unlocked,
      ),

      // --- AI & ML SECTOR CLUSTER (350, -220, 250) ---
      TopicProgressionNode(
        id: 'topic:neural_networks',
        label: 'Neural Networks & Deep Learning',
        category: 'Sub-Topic',
        icon: 'psychology',
        description: 'Multilayer perceptrons, backpropagation, activation functions, and gradient descent.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:ai_ml'],
        similarNodeIds: ['domain:ai_ml', 'topic:transformer_attention'],
        position3D: const Vector3D(375, -245, 275), // r=43 from AI
        colorHex: '#C084FC',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:transformer_attention',
        label: 'Transformer & Attention Mechanisms',
        category: 'Sub-Topic',
        icon: 'auto_awesome',
        description: 'Self-attention, multi-head scaled dot-product attention, positional embeddings, LLMs.',
        pointsToUnlock: 30,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:ai_ml'],
        similarNodeIds: ['topic:neural_networks', 'lang:python'],
        position3D: const Vector3D(325, -195, 270), // r=41 from AI
        colorHex: '#A855F7',
        status: TopicUnlockStatus.unlocked,
      ),

      // --- DATABASES SECTOR CLUSTER (220, 360, -140) ---
      TopicProgressionNode(
        id: 'lang:sql',
        label: 'SQL & Query Optimization',
        category: 'Language',
        icon: 'table_chart',
        description: 'Declarative queries, relational algebra, window functions, and index execution plans.',
        pointsToUnlock: 20,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:databases'],
        similarNodeIds: ['domain:databases', 'topic:database_acid'],
        position3D: const Vector3D(245, 385, -120), // r=41 from DB
        colorHex: '#059669',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:database_acid',
        label: 'ACID Guarantees & Storage Engines',
        category: 'Sub-Topic',
        icon: 'storage',
        description: 'Write-ahead logs (WAL), B+ Trees vs LSM Trees, isolation levels (MVCC), and recovery.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:databases'],
        similarNodeIds: ['domain:databases', 'lang:sql'],
        position3D: const Vector3D(195, 335, -160), // r=41 from DB
        colorHex: '#10B981',
        status: TopicUnlockStatus.unlocked,
      ),

      // --- SYSTEM ARCHITECTURE SECTOR CLUSTER (160, -350, -170) ---
      TopicProgressionNode(
        id: 'lang:cpp',
        label: 'C++',
        category: 'Language',
        icon: 'developer_board',
        description: 'Manual memory management, RAII, pointers, template metaprogramming.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:system_architecture'],
        similarNodeIds: ['lang:rust', 'domain:system_architecture', 'leaf:cpp:raii_memory'],
        position3D: const Vector3D(185, -325, -145), // r=43 from SysArch
        colorHex: '#0284C7',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'leaf:cpp:raii_memory',
        label: 'C++: RAII & Smart Pointers',
        category: 'Leaf Concept',
        icon: 'recycling',
        description: 'Resource Acquisition Is Initialization, unique_ptr, shared_ptr, and deterministic destructors.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['lang:cpp'],
        similarNodeIds: ['domain:system_architecture', 'leaf:rust:ownership_borrowing'],
        position3D: const Vector3D(170, -305, -175),
        colorHex: '#38BDF8',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:cache_hierarchy',
        label: 'CPU Cache & Microarchitecture',
        category: 'Sub-Topic',
        icon: 'memory',
        description: 'L1/L2/L3 caches, cache line invalidation (MESI), out-of-order execution, and branch prediction.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:system_architecture'],
        similarNodeIds: ['domain:system_architecture', 'domain:operating_systems'],
        position3D: const Vector3D(135, -375, -190), // r=41 from SysArch
        colorHex: '#F59E0B',
        status: TopicUnlockStatus.unlocked,
      ),

      // --- SOFTWARE ENGINEERING SECTOR CLUSTER (-160, 360, 160) ---
      TopicProgressionNode(
        id: 'topic:design_patterns',
        label: 'Design Patterns & Architecture',
        category: 'Sub-Topic',
        icon: 'architecture',
        description: 'GoF creational, structural, and behavioral patterns, SOLID principles, clean code.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:software_engineering'],
        similarNodeIds: ['domain:software_engineering', 'topic:programming_languages'],
        position3D: const Vector3D(-135, 385, 140),
        colorHex: '#3B82F6',
        status: TopicUnlockStatus.unlocked,
      ),
      TopicProgressionNode(
        id: 'topic:ci_cd_pipelines',
        label: 'CI/CD & DevOps Automation',
        category: 'Sub-Topic',
        icon: 'precision_manufacturing',
        description: 'Continuous integration runners, automated testing matrix, blue-green deployment, and canary rollouts.',
        pointsToUnlock: 25,
        pointsToMaster: 100,
        prerequisiteIds: ['domain:software_engineering'],
        similarNodeIds: ['domain:cloud_computing', 'topic:container_orchestration'],
        position3D: const Vector3D(-185, 335, 185),
        colorHex: '#60A5FA',
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
    if (clean == 'domain:cybersecurity' ||
        clean == 'domain:cybersecurity_cryptography' ||
        clean == 'domain:cybersecurity_cryptography_security_engineering' ||
        clean == 'cybersecurity' ||
        clean == 'cryptography' ||
        clean == 'cybersecurity & cryptography' ||
        clean == 'security' ||
        clean == 'security engineering' ||
        clean == 'domain:security_engineering') {
      if (_nodes.containsKey('domain:security_engineering')) {
        return _nodes['domain:security_engineering'];
      }
    }
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
