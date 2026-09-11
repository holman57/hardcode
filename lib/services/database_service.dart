import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Utility class for dynamically parsing and resolving regex/bracketed pattern options.
class PatternResolver {
  /// Dynamically resolves all bracketed choice patterns (e.g. `[a|b|None]`, `[$|@|None]`, `[String|str|string|None]`)
  /// by selecting one option at random and replacing "None" with empty string.
  static String resolveChoicePatterns(String input, [Random? rng]) {
    final Random random = rng ?? Random.secure();
    String result = input;
    bool foundAny;

    do {
      foundAny = false;
      int startIdx = -1;
      int depth = 0;
      int pipeCount = 0;

      for (int i = 0; i < result.length; i++) {
        final String ch = result[i];
        if (ch == '[') {
          if (depth == 0) {
            startIdx = i;
            pipeCount = 0;
          }
          depth++;
        } else if (ch == ']' && depth > 0) {
          depth--;
          if (depth == 0 && startIdx != -1) {
            if (pipeCount > 0) {
              final String inner = result.substring(startIdx + 1, i);

              // Split top-level alternatives (respecting any nested brackets)
              final List<String> options = [];
              int optStart = 0;
              int innerDepth = 0;
              for (int j = 0; j < inner.length; j++) {
                final String c = inner[j];
                if (c == '[') {
                  innerDepth++;
                } else if (c == ']') {
                  if (innerDepth > 0) innerDepth--;
                } else if (c == '|' && innerDepth == 0) {
                  options.add(inner.substring(optStart, j));
                  optStart = j + 1;
                }
              }
              options.add(inner.substring(optStart));

              if (options.isNotEmpty) {
                final String chosen = options[random.nextInt(options.length)];
                final String replacement = (chosen == "None") ? "" : chosen;
                result = result.replaceRange(startIdx, i + 1, replacement);
                foundAny = true;
                break;
              }
            }
            startIdx = -1;
            pipeCount = 0;
          }
        } else if (ch == '|' && depth == 1) {
          pipeCount++;
        }
      }
    } while (foundAny);

    return result;
  }
}

/// Styling and layout metadata for graph visualization renderers
class GraphNodeVisualization {
  final String group;
  final String color;
  final double size;
  final int level;
  final String icon;

  GraphNodeVisualization({
    required this.group,
    required this.color,
    required this.size,
    required this.level,
    required this.icon,
  });

  factory GraphNodeVisualization.fromJson(Map<String, dynamic> json) {
    return GraphNodeVisualization(
      group: json['group'] as String? ?? 'default',
      color: json['color'] as String? ?? '#64748B',
      size: (json['size'] as num?)?.toDouble() ?? 20.0,
      level: (json['level'] as num?)?.toInt() ?? 2,
      icon: json['icon'] as String? ?? 'circle',
    );
  }

  Map<String, dynamic> toJson() => {
        'group': group,
        'color': color,
        'size': size,
        'level': level,
        'icon': icon,
      };
}

/// A vertex representing an entity (Language, Domain, Question, Concept, Database) in the Knowledge Graph
class GraphNode {
  final String id;
  final String label;
  final String type;
  final String category;
  final Map<String, dynamic> properties;
  final GraphNodeVisualization visualization;

  GraphNode({
    required this.id,
    required this.label,
    required this.type,
    required this.category,
    required this.properties,
    required this.visualization,
  });

  factory GraphNode.fromJson(Map<String, dynamic> json) {
    return GraphNode(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? 'Node',
      category: json['category'] as String? ?? '',
      properties: Map<String, dynamic>.from(json['properties'] as Map? ?? {}),
      visualization: GraphNodeVisualization.fromJson(
        Map<String, dynamic>.from(json['visualization'] as Map? ?? {}),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type,
        'category': category,
        'properties': properties,
        'visualization': visualization.toJson(),
      };
}

/// A directed relationship linking two nodes in the Knowledge Graph
class GraphEdge {
  final String id;
  final String source;
  final String target;
  final String relation;
  final String label;
  final double weight;
  final bool directed;
  final Map<String, dynamic> properties;

  GraphEdge({
    required this.id,
    required this.source,
    required this.target,
    required this.relation,
    required this.label,
    this.weight = 1.0,
    this.directed = true,
    this.properties = const {},
  });

  factory GraphEdge.fromJson(Map<String, dynamic> json) {
    return GraphEdge(
      id: json['id'] as String? ?? '',
      source: json['source'] as String? ?? '',
      target: json['target'] as String? ?? '',
      relation: json['relation'] as String? ?? 'RELATED_TO',
      label: json['label'] as String? ?? 'Related',
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      directed: json['directed'] as bool? ?? true,
      properties: Map<String, dynamic>.from(json['properties'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'target': target,
        'relation': relation,
        'label': label,
        'weight': weight,
        'directed': directed,
        'properties': properties,
      };
}

/// Core Knowledge Graph datastructure powering syntax navigation, graph queries, and visual layout
class KnowledgeGraph with MapMixin<String, dynamic> {
  final String version;
  final Map<String, dynamic> metadata;
  final Map<String, GraphNode> nodes;
  final Map<String, GraphEdge> edges;
  final Map<String, List<String>> outgoing;
  final Map<String, List<String>> incoming;
  final Map<String, List<String>> byType;
  final Map<String, List<String>> byGroup;
  final Map<String, List<String>> byCategory;
  final Map<String, dynamic> _legacyBridge;

  KnowledgeGraph({
    required this.version,
    required this.metadata,
    required this.nodes,
    required this.edges,
    required this.outgoing,
    required this.incoming,
    required this.byType,
    required this.byGroup,
    required this.byCategory,
    required Map<String, dynamic> legacyBridge,
  }) : _legacyBridge = legacyBridge;

  factory KnowledgeGraph.fromJson(Map<String, dynamic> json) {
    final version = json['version']?.toString() ?? '1.0.0-graph';
    final metadata = Map<String, dynamic>.from(json['metadata'] as Map? ?? {});

    final nodesList = (json['nodes'] as List? ?? []);
    final Map<String, GraphNode> nodes = {};
    for (final item in nodesList) {
      if (item is Map) {
        final node = GraphNode.fromJson(Map<String, dynamic>.from(item));
        nodes[node.id] = node;
      }
    }

    final edgesList = (json['edges'] as List? ?? []);
    final Map<String, GraphEdge> edges = {};
    for (final item in edgesList) {
      if (item is Map) {
        final edge = GraphEdge.fromJson(Map<String, dynamic>.from(item));
        edges[edge.id] = edge;
      }
    }

    final rawAdj = (json['adjacency'] as Map? ?? {});
    final Map<String, List<String>> outgoing = {};
    final rawOut = (rawAdj['outgoing'] as Map? ?? {});
    rawOut.forEach((k, v) {
      if (v is List) {
        outgoing[k.toString()] = v.map((e) => e.toString()).toList();
      }
    });

    final Map<String, List<String>> incoming = {};
    final rawIn = (rawAdj['incoming'] as Map? ?? {});
    rawIn.forEach((k, v) {
      if (v is List) {
        incoming[k.toString()] = v.map((e) => e.toString()).toList();
      }
    });

    final rawIndices = (json['indices'] as Map? ?? {});
    final Map<String, List<String>> byType = {};
    (rawIndices['by_type'] as Map? ?? {}).forEach((k, v) {
      if (v is List) byType[k.toString()] = v.map((e) => e.toString()).toList();
    });

    final Map<String, List<String>> byGroup = {};
    (rawIndices['by_group'] as Map? ?? {}).forEach((k, v) {
      if (v is List) byGroup[k.toString()] = v.map((e) => e.toString()).toList();
    });

    final Map<String, List<String>> byCategory = {};
    (rawIndices['by_category'] as Map? ?? {}).forEach((k, v) {
      if (v is List) byCategory[k.toString()] = v.map((e) => e.toString()).toList();
    });

    final legacyBridge = Map<String, dynamic>.from(json['legacy_bridge'] as Map? ?? {});

    return KnowledgeGraph(
      version: version,
      metadata: metadata,
      nodes: nodes,
      edges: edges,
      outgoing: outgoing,
      incoming: incoming,
      byType: byType,
      byGroup: byGroup,
      byCategory: byCategory,
      legacyBridge: legacyBridge,
    );
  }

  factory KnowledgeGraph.fromLegacyCatalog(Map<String, dynamic> catalog) {
    final Map<String, GraphNode> nodes = {};
    final Map<String, GraphEdge> edges = {};
    final Map<String, List<String>> outgoing = {};
    final Map<String, List<String>> incoming = {};
    final Map<String, List<String>> byType = {};
    final Map<String, List<String>> byGroup = {};
    final Map<String, List<String>> byCategory = {};

    final langs = (catalog['Language'] as List? ?? []).map((e) => e.toString()).toList();
    byType['Language'] = [];
    byGroup['language'] = [];
    for (final l in langs) {
      final id = 'lang:${l.toLowerCase()}';
      nodes[id] = GraphNode(
        id: id,
        label: l,
        type: 'Language',
        category: 'General',
        properties: {'name': l},
        visualization: GraphNodeVisualization(group: 'language', color: '#3B82F6', size: 26, level: 2, icon: 'code'),
      );
      byType['Language']!.add(id);
      byGroup['language']!.add(id);
    }

    final curriculum = (catalog['Curriculum'] as Map? ?? {});
    byType['CurriculumDomain'] = [];
    byGroup['domain'] = [];
    curriculum.forEach((k, v) {
      final id = 'domain:${k.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_')}';
      nodes[id] = GraphNode(
        id: id,
        label: k.toString(),
        type: 'CurriculumDomain',
        category: 'Computer Science',
        properties: v is Map ? Map<String, dynamic>.from(v) : {},
        visualization: GraphNodeVisualization(group: 'domain', color: '#6366F1', size: 32, level: 1, icon: 'hub'),
      );
      byType['CurriculumDomain']!.add(id);
      byGroup['domain']!.add(id);
    });

    return KnowledgeGraph(
      version: '1.0.0-legacy-migrated',
      metadata: {'name': 'HardCode Knowledge Graph (Migrated)'},
      nodes: nodes,
      edges: edges,
      outgoing: outgoing,
      incoming: incoming,
      byType: byType,
      byGroup: byGroup,
      byCategory: byCategory,
      legacyBridge: catalog,
    );
  }

  factory KnowledgeGraph.fallback() {
    return KnowledgeGraph.fromLegacyCatalog({
      "version": 7,
      "Language": ["Python", "JavaScript", "C++", "Rust", "Go", "Dart", "Java", "C#", "TypeScript", "Bash"],
      "Curriculum": {
        "Computer Science": {
          "Introduction": "Foundational computer science principles.",
          "Remediation": "Review core concepts.",
          "Deep Dive": "Advanced CS theory.",
          "questions": {
            "True-False": [
              {
                "statement": "A stack is a Last-In, First-Out (LIFO) data structure.",
                "is_true": true,
                "explanation": "Elements added to a stack are placed on top and popped in reverse order."
              },
              {
                "statement": "Binary search has an asymptotic time complexity of O(N) in the worst case.",
                "is_true": false,
                "explanation": "Binary search divides the search space in half at each step, running in O(log N) time."
              }
            ],
            "Matching": [
              {
                "prompt": "Match each data structure with its access characteristics:",
                "pairs": {
                  "Queue": "First-In, First-Out (FIFO)",
                  "Stack": "Last-In, First-Out (LIFO)",
                  "Hash Table": "Average O(1) key-value lookup"
                }
              }
            ],
            "Sequencing": [
              {
                "prompt": "Order the lifecycle of a web HTTP GET request:",
                "steps": [
                  "Client performs DNS resolution for the domain name",
                  "TCP 3-way handshake establishes a transport connection",
                  "TLS handshake establishes secure cryptographic session",
                  "Browser transmits HTTP GET request headers",
                  "Server processes request and returns HTTP response"
                ]
              }
            ],
            "Sorting": [
              {
                "prompt": "Classify each algorithm by its worst-case time complexity:",
                "categories": ["O(log N)", "O(N)", "O(N log N)", "O(N^2)"],
                "items": {
                  "Binary Search": "O(log N)",
                  "Linear Search": "O(N)",
                  "Merge Sort": "O(N log N)",
                  "Bubble Sort": "O(N^2)"
                }
              }
            ]
          }
        }
      },
      "Variables": {
        "Int Variable Names": ["x", "count", "total", "index"],
        "Integer Small Variable Sets": ["x", "y", "z"],
        "Rust Int Variable Types": ["i32", "i64", "u32"],
        "String Variable Names": ["message", "name", "title"],
        "String Values": ["Hello", "World", "HardCode"],
        "Bool Variable Names": ["isActive", "isValid", "flag"],
        "Bool Values": ["true", "false"]
      }
    });
  }

  // --- Graph Traversal & Query Methods ---

  GraphNode? getNode(String id) => nodes[id];

  List<GraphEdge> getOutgoingEdges(String nodeId) {
    final edgeIds = outgoing[nodeId] ?? [];
    return edgeIds.map((id) => edges[id]).whereType<GraphEdge>().toList();
  }

  List<GraphEdge> getIncomingEdges(String nodeId) {
    final edgeIds = incoming[nodeId] ?? [];
    return edgeIds.map((id) => edges[id]).whereType<GraphEdge>().toList();
  }

  List<GraphNode> getNeighbors(String nodeId, {String? relation}) {
    final outEdges = getOutgoingEdges(nodeId);
    return outEdges
        .where((e) => relation == null || e.relation == relation)
        .map((e) => nodes[e.target])
        .whereType<GraphNode>()
        .toList();
  }

  List<GraphNode> getNodesByType(String type) {
    final ids = byType[type] ?? [];
    return ids.map((id) => nodes[id]).whereType<GraphNode>().toList();
  }

  List<GraphNode> getNodesByGroup(String group) {
    final ids = byGroup[group] ?? [];
    return ids.map((id) => nodes[id]).whereType<GraphNode>().toList();
  }

  List<GraphNode> getQuestions({String? domain, String? subType}) {
    final questionNodes = getNodesByType('Question');
    return questionNodes.where((q) {
      if (domain != null && q.properties['domain'] != domain) return false;
      if (subType != null && q.properties['sub_type'] != subType) return false;
      return true;
    }).toList();
  }

  List<String> getLanguages() {
    return (_legacyBridge['Language'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
  }

  List<String> getCurriculumDomains() {
    return getNodesByType('CurriculumDomain').map((n) => n.label).toList();
  }

  /// Exports a filtered or focused subgraph formatted for visualization engines (e.g. D3, force-directed, canvas).
  Map<String, dynamic> exportVisualizationData({String? focusNodeId, int depth = 2}) {
    final Set<String> includedNodeIds = {};
    if (focusNodeId != null && nodes.containsKey(focusNodeId)) {
      includedNodeIds.add(focusNodeId);
      Set<String> currentLayer = {focusNodeId};
      for (int d = 0; d < depth; d++) {
        final Set<String> nextLayer = {};
        for (final nid in currentLayer) {
          for (final edge in getOutgoingEdges(nid)) {
            nextLayer.add(edge.target);
          }
          for (final edge in getIncomingEdges(nid)) {
            nextLayer.add(edge.source);
          }
        }
        includedNodeIds.addAll(nextLayer);
        currentLayer = nextLayer;
      }
    } else {
      includedNodeIds.addAll(nodes.keys);
    }

    final visNodes = includedNodeIds
        .map((id) => nodes[id])
        .whereType<GraphNode>()
        .map((n) => n.toJson())
        .toList();

    final visEdges = edges.values
        .where((e) => includedNodeIds.contains(e.source) && includedNodeIds.contains(e.target))
        .map((e) => e.toJson())
        .toList();

    return {
      'nodes': visNodes,
      'links': visEdges,
      'metadata': {
        'focus': focusNodeId,
        'depth': depth,
        'node_count': visNodes.length,
        'edge_count': visEdges.length,
      }
    };
  }

  // --- MapMixin Implementation for Backward Compatibility ---
  @override
  dynamic operator [](Object? key) {
    if (key == 'nodes') return nodes.values.map((n) => n.toJson()).toList();
    if (key == 'edges') return edges.values.map((e) => e.toJson()).toList();
    if (key == 'version') return version;
    if (key == 'metadata') return metadata;
    return _legacyBridge[key];
  }

  @override
  void operator []=(String key, dynamic value) {
    _legacyBridge[key] = value;
  }

  @override
  void clear() => _legacyBridge.clear();

  @override
  Iterable<String> get keys => {'version', 'metadata', 'nodes', 'edges', ..._legacyBridge.keys};

  @override
  dynamic remove(Object? key) => _legacyBridge.remove(key);
}

class UserStats {
  final int currentStreak;
  final int bestStreak;
  final int totalAnswered;
  final int totalCorrect;
  final int xp;
  final Map<String, dynamic> languageStats;
  final List<double> accuracyHistory;
  final List<bool> recentAnswerResults;

  UserStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalAnswered,
    required this.totalCorrect,
    required this.xp,
    required this.languageStats,
    this.accuracyHistory = const [],
    this.recentAnswerResults = const [],
  });

  /// All-time cumulative accuracy percentage.
  double get accuracy =>
      totalAnswered == 0 ? 0.0 : (totalCorrect / totalAnswered) * 100;

  /// Rolling accuracy percentage over the recent question window (last 10 questions).
  double get recentAccuracy {
    if (recentAnswerResults.isEmpty) {
      return accuracyHistory.isNotEmpty ? accuracyHistory.last : accuracy;
    }
    final int correct = recentAnswerResults.where((r) => r).length;
    return (correct / recentAnswerResults.length) * 100.0;
  }

  int get level => (xp / 150).floor() + 1;
  int get currentLevelXp => xp % 150;
  double get levelProgress => (xp % 150) / 150.0;

  String get rankTitle {
    if (level <= 1) return 'Novice Coder';
    if (level == 2) return 'Syntax Apprentice';
    if (level == 3) return 'Logic Specialist';
    if (level == 4) return 'Full-Stack Hacker';
    if (level == 5) return 'Systems Architect';
    return 'Code Grandmaster';
  }
}

class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const String catalogBoxName = 'hardcode_knowledge_graph_box';
  static const String userMemoryBoxName = 'hardcode_user_memory_box';

  Box? _catalogBox;
  Box? _userMemoryBox;
  bool _isInitialized = false;
  KnowledgeGraph? _knowledgeGraph;

  bool get isInitialized => _isInitialized;
  KnowledgeGraph? get knowledgeGraph => _knowledgeGraph;

  /// Initializes Hive for Flutter and opens both the catalog and memory boxes.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await Hive.initFlutter().timeout(const Duration(seconds: 2));
      _catalogBox = await Hive.openBox(catalogBoxName).timeout(const Duration(seconds: 2));
      _userMemoryBox = await Hive.openBox(userMemoryBoxName).timeout(const Duration(seconds: 2));
      _isInitialized = true;
    } catch (e) {
      print('Notice: Hive initialization failed or timed out ($e). Proceeding with in-memory graph.');
    }
  }

  /// Retrieves the complete KnowledgeGraph from the local database or seeds from assets/knowledge_graph.json or assets/db.json.
  Future<KnowledgeGraph> getOrSeedGraph() async {
    try {
      if (!_isInitialized) {
        await init().timeout(const Duration(seconds: 2));
      }
    } catch (e) {
      print('Warning: Hive init failed in getOrSeedGraph: $e');
    }

    if (_catalogBox != null) {
      try {
        final int cachedVersion =
            _catalogBox!.get('graph_version', defaultValue: 0) as int;
        final String? cachedJson = _catalogBox!.get('knowledge_graph_json') as String?;

        if (cachedVersion >= 1 && cachedJson != null && cachedJson.isNotEmpty) {
          final Map<String, dynamic> decoded =
              jsonDecode(cachedJson) as Map<String, dynamic>;
          if (decoded.containsKey('nodes') && decoded.containsKey('edges')) {
            _knowledgeGraph = KnowledgeGraph.fromJson(decoded);
            return _knowledgeGraph!;
          }
        }
      } catch (e) {
        print('Notice: Hive cache read skipped: $e');
      }
    }

    // Seed from assets: try knowledge_graph.json first, then db.json fallback
    String? rawAsset;
    try {
      rawAsset = await rootBundle
          .loadString('assets/knowledge_graph.json')
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      print('Notice: could not load assets/knowledge_graph.json ($e), trying assets/db.json');
      try {
        rawAsset = await rootBundle
            .loadString('assets/db.json')
            .timeout(const Duration(seconds: 2));
      } catch (e2) {
        print('Notice: could not load assets/db.json either ($e2)');
      }
    }

    if (rawAsset != null && rawAsset.isNotEmpty) {
      try {
        final Map<String, dynamic> parsed =
            jsonDecode(rawAsset) as Map<String, dynamic>;
        if (parsed.containsKey('nodes') && parsed.containsKey('edges')) {
          if (_catalogBox != null) {
            try {
              await _catalogBox!.put('knowledge_graph_json', rawAsset).timeout(const Duration(seconds: 1));
              await _catalogBox!.put('graph_version', 1).timeout(const Duration(seconds: 1));
              await _catalogBox!.put('last_updated', DateTime.now().toIso8601String()).timeout(const Duration(seconds: 1));
            } catch (_) {}
          }
          _knowledgeGraph = KnowledgeGraph.fromJson(parsed);
          return _knowledgeGraph!;
        } else if (parsed.containsKey('Language') || parsed.containsKey('Curriculum')) {
          final kg = KnowledgeGraph.fromLegacyCatalog(parsed);
          _knowledgeGraph = kg;
          return _knowledgeGraph!;
        }
      } catch (e) {
        print('Error parsing loaded asset: $e');
      }
    }

    // Final safety fallback to ensure the app never hangs on a loading spinner
    _knowledgeGraph = KnowledgeGraph.fallback();
    return _knowledgeGraph!;
  }

  /// Retrieves the question and language catalog as a KnowledgeGraph (which also implements Map for legacy compatibility).
  Future<Map<String, dynamic>> getOrSeedCatalog() async {
    return await getOrSeedGraph();
  }

  /// Gets current user statistics and progress from local memory.
  UserStats getUserStats() {
    if (!_isInitialized || _userMemoryBox == null) {
      return UserStats(
        currentStreak: 0,
        bestStreak: 0,
        totalAnswered: 0,
        totalCorrect: 0,
        xp: 0,
        languageStats: {},
      );
    }

    final int currentStreak =
        _userMemoryBox!.get('currentStreak', defaultValue: 0) as int;
    final int bestStreak =
        _userMemoryBox!.get('bestStreak', defaultValue: 0) as int;
    final int totalAnswered =
        _userMemoryBox!.get('totalAnswered', defaultValue: 0) as int;
    final int totalCorrect =
        _userMemoryBox!.get('totalCorrect', defaultValue: 0) as int;
    final int xp = _userMemoryBox!.get('xp', defaultValue: 0) as int;

    final dynamic rawLang = _userMemoryBox!.get('languageStats');
    Map<String, dynamic> languageStats = {};
    if (rawLang is Map) {
      languageStats = Map<String, dynamic>.from(rawLang);
    }

    final dynamic rawHistory = _userMemoryBox!.get('accuracyHistory');
    List<double> accuracyHistory = [];
    if (rawHistory is List) {
      accuracyHistory = rawHistory.map((e) => (e as num).toDouble()).toList();
    }

    final dynamic rawRecent = _userMemoryBox!.get('recentAnswerResults');
    List<bool> recentAnswerResults = [];
    if (rawRecent is List) {
      recentAnswerResults = rawRecent.map((e) => e == true).toList();
    }

    return UserStats(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalAnswered: totalAnswered,
      totalCorrect: totalCorrect,
      xp: xp,
      languageStats: languageStats,
      accuracyHistory: accuracyHistory,
      recentAnswerResults: recentAnswerResults,
    );
  }

  /// Computes adaptive sampling priorities for languages based on user error patterns.
  List<int> getAdaptiveLanguagePriorities(List<String> languages) {
    final stats = getUserStats();
    final List<int> priorities = [];

    for (final lang in languages) {
      final langRecord = stats.languageStats[lang];
      if (langRecord is Map) {
        final total = (langRecord['total'] as int?) ?? 0;
        final correct = (langRecord['correct'] as int?) ?? 0;
        final misses = (langRecord['misses'] as int?) ?? 0;

        if (total == 0) {
          priorities.add(3); // Unexplored language
        } else {
          final accuracy = (correct / total) * 100.0;
          if (misses > 0 || accuracy < 50.0) {
            priorities.add(6); // Needs immediate reinforcement
          } else if (accuracy < 75.0) {
            priorities.add(4); // In progress
          } else {
            priorities.add(2); // Mastered, review periodically
          }
        }
      } else {
        priorities.add(3);
      }
    }

    return priorities;
  }

  /// Returns question categories unlocked for the user's current level.
  List<String> getAvailableCategoriesForLevel(int level) {
    if (level <= 1) {
      return ['Integer Assignment', 'Constant Declaration'];
    } else if (level == 2) {
      return ['Integer Assignment', 'Constant Declaration', 'Boolean Assignment'];
    } else {
      return [
        'Integer Assignment',
        'Constant Declaration',
        'Boolean Assignment',
        'String Assignment'
      ];
    }
  }

  /// Records an answer submission, calculating XP, multipliers, and adaptive stats.
  Future<UserStats> recordAnswer({
    required String language,
    required bool isCorrect,
    int timeRemainingSeconds = 0,
  }) async {
    if (!_isInitialized) {
      await init();
    }

    int currentStreak =
        _userMemoryBox!.get('currentStreak', defaultValue: 0) as int;
    int bestStreak = _userMemoryBox!.get('bestStreak', defaultValue: 0) as int;
    int totalAnswered =
        _userMemoryBox!.get('totalAnswered', defaultValue: 0) as int;
    int totalCorrect =
        _userMemoryBox!.get('totalCorrect', defaultValue: 0) as int;
    int xp = _userMemoryBox!.get('xp', defaultValue: 0) as int;

    totalAnswered += 1;
    if (isCorrect) {
      totalCorrect += 1;
      currentStreak += 1;
      if (currentStreak > bestStreak) {
        bestStreak = currentStreak;
      }

      // Streak multiplier: 1.0x -> 1.25x -> 1.5x -> 2.0x
      double streakMultiplier = 1.0;
      if (currentStreak >= 10) {
        streakMultiplier = 2.0;
      } else if (currentStreak >= 5) {
        streakMultiplier = 1.5;
      } else if (currentStreak >= 3) {
        streakMultiplier = 1.25;
      }

      int speedBonus = 0;
      if (timeRemainingSeconds > 15) {
        speedBonus = 5;
      } else if (timeRemainingSeconds > 10) {
        speedBonus = 3;
      } else if (timeRemainingSeconds > 5) {
        speedBonus = 1;
      }

      final int earnedXp = (10 * streakMultiplier).round() + speedBonus;
      xp += earnedXp;
    } else {
      currentStreak = 0;
    }

    // Update per-language performance
    final dynamic rawLang = _userMemoryBox!.get('languageStats');
    Map<String, dynamic> languageStats = {};
    if (rawLang is Map) {
      languageStats = Map<String, dynamic>.from(rawLang);
    }

    Map<String, dynamic> langRecord =
        Map<String, dynamic>.from((languageStats[language] as Map?) ?? {});
    final int langAnswered = (langRecord['total'] as int? ?? 0) + 1;
    final int langCorrect =
        (langRecord['correct'] as int? ?? 0) + (isCorrect ? 1 : 0);
    final int consecutiveMisses =
        isCorrect ? 0 : ((langRecord['misses'] as int? ?? 0) + 1);

    langRecord['total'] = langAnswered;
    langRecord['correct'] = langCorrect;
    langRecord['misses'] = consecutiveMisses;
    languageStats[language] = langRecord;

    // Rolling recent window of last 10 questions for responsive accuracy tracking
    final dynamic rawRecent = _userMemoryBox!.get('recentAnswerResults');
    List<bool> recentAnswerResults = [];
    if (rawRecent is List) {
      recentAnswerResults = rawRecent.map((e) => e == true).toList();
    }
    recentAnswerResults.add(isCorrect);
    if (recentAnswerResults.length > 10) {
      recentAnswerResults =
          recentAnswerResults.sublist(recentAnswerResults.length - 10);
    }
    final int recentCorrect = recentAnswerResults.where((r) => r).length;
    final double rollingAccuracy =
        (recentCorrect / recentAnswerResults.length) * 100.0;

    final dynamic rawHistory = _userMemoryBox!.get('accuracyHistory');
    List<double> accuracyHistory = [];
    if (rawHistory is List) {
      accuracyHistory = rawHistory.map((e) => (e as num).toDouble()).toList();
    }
    accuracyHistory.add(rollingAccuracy);
    if (accuracyHistory.length > 15) {
      accuracyHistory = accuracyHistory.sublist(accuracyHistory.length - 15);
    }

    await _userMemoryBox!.put('currentStreak', currentStreak);
    await _userMemoryBox!.put('bestStreak', bestStreak);
    await _userMemoryBox!.put('totalAnswered', totalAnswered);
    await _userMemoryBox!.put('totalCorrect', totalCorrect);
    await _userMemoryBox!.put('xp', xp);
    await _userMemoryBox!.put('languageStats', languageStats);
    await _userMemoryBox!.put('accuracyHistory', accuracyHistory);
    await _userMemoryBox!.put('recentAnswerResults', recentAnswerResults);

    return UserStats(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalAnswered: totalAnswered,
      totalCorrect: totalCorrect,
      xp: xp,
      languageStats: languageStats,
      accuracyHistory: accuracyHistory,
      recentAnswerResults: recentAnswerResults,
    );
  }

  /// Clears local memory and resets progress.
  Future<void> resetStats() async {
    if (!_isInitialized) return;
    await _userMemoryBox!.clear();
  }
}
