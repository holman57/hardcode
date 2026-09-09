import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

class UserStats {
  final int currentStreak;
  final int bestStreak;
  final int totalAnswered;
  final int totalCorrect;
  final Map<String, dynamic> languageStats;

  UserStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalAnswered,
    required this.totalCorrect,
    required this.languageStats,
  });

  double get accuracy =>
      totalAnswered == 0 ? 0.0 : (totalCorrect / totalAnswered) * 100;
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
  /// If the local database is empty, seeds it from assets/db.json first.
  Future<Map<String, dynamic>> getOrSeedCatalog() async {
    if (!_isInitialized) {
      await init();
    }

    // Check if catalog already exists in local database
    final String? cachedJson = _catalogBox!.get('catalog_json') as String?;
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(cachedJson) as Map<String, dynamic>;
        return decoded;
      } catch (_) {
        // Fallback to re-seed if parsing fails
      }
    }

    // Seed from assets/db.json into local Hive database
    final String rawAsset = await rootBundle.loadString('assets/db.json');
    final Map<String, dynamic> parsed =
        jsonDecode(rawAsset) as Map<String, dynamic>;

    // Persist seeded catalog to local database
    await _catalogBox!.put('catalog_json', rawAsset);
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

    final dynamic rawLang = _userMemoryBox!.get('languageStats');
    Map<String, dynamic> languageStats = {};
    if (rawLang is Map) {
      languageStats = Map<String, dynamic>.from(rawLang);
    }

    return UserStats(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalAnswered: totalAnswered,
      totalCorrect: totalCorrect,
      languageStats: languageStats,
    );
  }

  /// Records an answer submission, updating streaks, totals, and per-language tracking.
  Future<UserStats> recordAnswer({
    required String language,
    required bool isCorrect,
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

    totalAnswered += 1;
    if (isCorrect) {
      totalCorrect += 1;
      currentStreak += 1;
      if (currentStreak > bestStreak) {
        bestStreak = currentStreak;
      }
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
    langRecord['total'] = langAnswered;
    langRecord['correct'] = langCorrect;
    languageStats[language] = langRecord;

    await _userMemoryBox!.put('currentStreak', currentStreak);
    await _userMemoryBox!.put('bestStreak', bestStreak);
    await _userMemoryBox!.put('totalAnswered', totalAnswered);
    await _userMemoryBox!.put('totalCorrect', totalCorrect);
    await _userMemoryBox!.put('languageStats', languageStats);

    return UserStats(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalAnswered: totalAnswered,
      totalCorrect: totalCorrect,
      languageStats: languageStats,
    );
  }

  /// Clears local memory and resets progress.
  Future<void> resetStats() async {
    if (!_isInitialized) return;
    await _userMemoryBox!.clear();
  }
}
