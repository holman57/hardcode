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
        languageStats: {},
      );
      expect(stats.accuracy, 80.0);
      expect(stats.currentStreak, 3);
      expect(stats.bestStreak, 5);
      expect(stats.totalAnswered, 10);
      expect(stats.totalCorrect, 8);
    });

    test('UserStats handles zero total answered without dividing by zero', () {
      final stats = UserStats(
        currentStreak: 0,
        bestStreak: 0,
        totalAnswered: 0,
        totalCorrect: 0,
        languageStats: {},
      );
      expect(stats.accuracy, 0.0);
    });
  });
}
