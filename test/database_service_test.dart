import 'package:flutter_test/flutter_test.dart';
import 'package:multiprogramming/services/database_service.dart';

void main() {
  group('UserStats Tests', () {
    test('UserStats accuracy calculation with valid data', () {
      final stats = UserStats(
        currentStreak: 3,
        bestStreak: 5,
        totalAnswered: 10,
        totalCorrect: 8,
        xp: 120,
        languageStats: {},
      );
      expect(stats.accuracy, 80.0);
      expect(stats.currentStreak, 3);
      expect(stats.bestStreak, 5);
      expect(stats.totalAnswered, 10);
      expect(stats.totalCorrect, 8);
      expect(stats.xp, 120);
      expect(stats.accuracyHistory, isEmpty);
    });

    test('UserStats accuracyHistory retains provided values', () {
      final stats = UserStats(
        currentStreak: 4,
        bestStreak: 4,
        totalAnswered: 4,
        totalCorrect: 3,
        xp: 60,
        accuracyHistory: [100.0, 50.0, 66.7, 75.0],
        languageStats: {},
      );
      expect(stats.accuracyHistory, [100.0, 50.0, 66.7, 75.0]);
      expect(stats.accuracy, 75.0);
    });

    test('UserStats recentAccuracy reflects rolling window of recent answers', () {
      // 50 total questions answered (45 correct => 90% cumulative accuracy)
      // but user struggled recently: only 6 of the last 10 correct => 60% recent accuracy
      final recentAnswers = [
        true, true, false, true, false, true, false, true, true, false
      ];
      final stats = UserStats(
        currentStreak: 0,
        bestStreak: 20,
        totalAnswered: 50,
        totalCorrect: 45,
        xp: 650,
        recentAnswerResults: recentAnswers,
        accuracyHistory: [80.0, 70.0, 60.0],
        languageStats: {},
      );
      expect(stats.accuracy, 90.0);
      expect(stats.recentAccuracy, 60.0);
      expect(stats.recentAnswerResults.length, 10);
    });

    test('UserStats recentAccuracy falls back safely when recentAnswerResults is empty', () {
      final statsWithHistory = UserStats(
        currentStreak: 2,
        bestStreak: 2,
        totalAnswered: 10,
        totalCorrect: 8,
        xp: 100,
        accuracyHistory: [70.0, 80.0],
        languageStats: {},
      );
      expect(statsWithHistory.recentAccuracy, 80.0);

      final statsEmpty = UserStats(
        currentStreak: 0,
        bestStreak: 0,
        totalAnswered: 0,
        totalCorrect: 0,
        xp: 0,
        languageStats: {},
      );
      expect(statsEmpty.recentAccuracy, 0.0);
    });

    test('UserStats handles zero total answered without dividing by zero', () {
      final stats = UserStats(
        currentStreak: 0,
        bestStreak: 0,
        totalAnswered: 0,
        totalCorrect: 0,
        xp: 0,
        languageStats: {},
      );
      expect(stats.accuracy, 0.0);
      expect(stats.accuracyHistory, isEmpty);
    });

    test('UserStats level, currentLevelXp, and levelProgress calculations', () {
      final stats0 = UserStats(
        currentStreak: 0,
        bestStreak: 0,
        totalAnswered: 0,
        totalCorrect: 0,
        xp: 0,
        languageStats: {},
      );
      expect(stats0.level, 1);
      expect(stats0.currentLevelXp, 0);
      expect(stats0.levelProgress, 0.0);
      expect(stats0.rankTitle, 'Novice Coder');

      final statsLevel2 = UserStats(
        currentStreak: 2,
        bestStreak: 2,
        totalAnswered: 5,
        totalCorrect: 5,
        xp: 150,
        languageStats: {},
      );
      expect(statsLevel2.level, 2);
      expect(statsLevel2.currentLevelXp, 0);
      expect(statsLevel2.levelProgress, 0.0);
      expect(statsLevel2.rankTitle, 'Syntax Apprentice');

      final statsMidLevel2 = UserStats(
        currentStreak: 4,
        bestStreak: 4,
        totalAnswered: 10,
        totalCorrect: 9,
        xp: 225,
        languageStats: {},
      );
      expect(statsMidLevel2.level, 2);
      expect(statsMidLevel2.currentLevelXp, 75);
      expect(statsMidLevel2.levelProgress, 0.5);

      final statsLevel3 = UserStats(
        currentStreak: 5,
        bestStreak: 5,
        totalAnswered: 20,
        totalCorrect: 18,
        xp: 300,
        languageStats: {},
      );
      expect(statsLevel3.level, 3);
      expect(statsLevel3.rankTitle, 'Logic Specialist');

      final statsLevel4 = UserStats(
        currentStreak: 5,
        bestStreak: 5,
        totalAnswered: 30,
        totalCorrect: 28,
        xp: 450,
        languageStats: {},
      );
      expect(statsLevel4.level, 4);
      expect(statsLevel4.rankTitle, 'Full-Stack Hacker');

      final statsLevel5 = UserStats(
        currentStreak: 5,
        bestStreak: 5,
        totalAnswered: 40,
        totalCorrect: 38,
        xp: 600,
        languageStats: {},
      );
      expect(statsLevel5.level, 5);
      expect(statsLevel5.rankTitle, 'Systems Architect');

      final statsLevel6 = UserStats(
        currentStreak: 10,
        bestStreak: 10,
        totalAnswered: 50,
        totalCorrect: 48,
        xp: 750,
        languageStats: {},
      );
      expect(statsLevel6.level, 6);
      expect(statsLevel6.rankTitle, 'Code Grandmaster');
    });
  });

  group('DatabaseService Logic Tests', () {
    test('getAvailableCategoriesForLevel scales with level', () {
      final categoriesL1 =
          DatabaseService.instance.getAvailableCategoriesForLevel(1);
      expect(categoriesL1, contains('Integer Assignment'));
      expect(categoriesL1, contains('Constant Declaration'));
      expect(categoriesL1.contains('Boolean Assignment'), isFalse);
      expect(categoriesL1.contains('String Assignment'), isFalse);

      final categoriesL2 =
          DatabaseService.instance.getAvailableCategoriesForLevel(2);
      expect(categoriesL2, contains('Boolean Assignment'));
      expect(categoriesL2.contains('String Assignment'), isFalse);

      final categoriesL3 =
          DatabaseService.instance.getAvailableCategoriesForLevel(3);
      expect(categoriesL3, contains('String Assignment'));
      expect(categoriesL3.length, 4);
    });

    test(
        'getAdaptiveLanguagePriorities returns default priority for unexplored languages',
        () {
      final priorities = DatabaseService.instance
          .getAdaptiveLanguagePriorities(['C', 'Rust', 'Go']);
      expect(priorities.length, 3);
      for (final p in priorities) {
        expect(p, 3);
      }
    });
  });

  group('PatternResolver Tests', () {
    test('resolves prefix choice patterns like [\$|@|None]title', () {
      const input = r'[$|@|None]title = "developer";';
      final allowed = {
        r'$title = "developer";',
        r'@title = "developer";',
        r'title = "developer";',
      };
      for (int i = 0; i < 50; i++) {
        final resolved = PatternResolver.resolveChoicePatterns(input);
        expect(allowed, contains(resolved));
        expect(resolved, isNot(contains('[')));
        expect(resolved, isNot(contains('|')));
      }
    });

    test('resolves type choice patterns like [String|str|string|None]', () {
      const input = '[String|str|string|None] title := "success"';
      final allowed = {
        'String title := "success"',
        'str title := "success"',
        'string title := "success"',
        ' title := "success"',
      };
      for (int i = 0; i < 50; i++) {
        final resolved = PatternResolver.resolveChoicePatterns(input);
        expect(allowed, contains(resolved));
        expect(resolved, isNot(contains('[')));
        expect(resolved, isNot(contains('|')));
      }
    });

    test('resolves complex nested choice groups and multiple patterns', () {
      const input = r'[$|@|None|[int]|_]x = 42[;|None]';
      for (int i = 0; i < 50; i++) {
        final resolved = PatternResolver.resolveChoicePatterns(input);
        expect(resolved, isNot(contains('|')));
        expect(
          resolved.startsWith(r'$x') ||
              resolved.startsWith(r'@x') ||
              resolved.startsWith('x') ||
              resolved.startsWith('[int]x') ||
              resolved.startsWith('_x'),
          isTrue,
        );
        expect(resolved.endsWith('42;') || resolved.endsWith('42'), isTrue);
      }
    });

    test('leaves strings without choice patterns unchanged', () {
      expect(PatternResolver.resolveChoicePatterns('int x = 42;'), 'int x = 42;');
      expect(PatternResolver.resolveChoicePatterns('[random int variable]'),
          '[random int variable]');
    });
  });
}
