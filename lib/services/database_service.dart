import 'dart:convert';
import 'dart:math';
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

  static const String catalogBoxName = 'hardcode_catalog_box';
  static const String userMemoryBoxName = 'hardcode_user_memory_box';

  Box? _catalogBox;
  Box? _userMemoryBox;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initializes Hive for Flutter and opens both the catalog and memory boxes.
  Future<void> init() async {
    if (_isInitialized) return;
    await Hive.initFlutter();
    _catalogBox = await Hive.openBox(catalogBoxName);
    _userMemoryBox = await Hive.openBox(userMemoryBoxName);
    _isInitialized = true;
  }

  /// Retrieves the question and language catalog from the local database.
  /// If the local database is empty or version is outdated, seeds from assets/db.json.
  Future<Map<String, dynamic>> getOrSeedCatalog() async {
    if (!_isInitialized) {
      await init();
    }

    final int cachedVersion =
        _catalogBox!.get('catalog_version', defaultValue: 0) as int;
    final String? cachedJson = _catalogBox!.get('catalog_json') as String?;

    // If cached version is up to date, valid, and contains Curriculum, use cached catalog
    if (cachedVersion >= 7 && cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(cachedJson) as Map<String, dynamic>;
        if (decoded.containsKey('Curriculum') &&
            decoded['Curriculum'] is Map &&
            (decoded['Curriculum'] as Map).isNotEmpty) {
          return decoded;
        }
      } catch (_) {
        // Fallback to re-seed if parsing fails
      }
    }

    // Seed from assets/db.json into local Hive database
    final String rawAsset = await rootBundle.loadString('assets/db.json');
    final Map<String, dynamic> parsed =
        jsonDecode(rawAsset) as Map<String, dynamic>;
    final int assetVersion = (parsed['version'] as int?) ?? 4;

    await _catalogBox!.put('catalog_json', rawAsset);
    await _catalogBox!.put('catalog_version', assetVersion);
    await _catalogBox!.put('last_updated', DateTime.now().toIso8601String());

    return parsed;
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
  /// Weak languages or recently missed items receive higher priority.
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
