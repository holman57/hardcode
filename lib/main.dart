import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HardCode',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      ),
      home: const MyHomePage(title: ''),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class PriorityRandomGenerator {
  List _priorities = [];
  int _n = 0;

  PriorityRandomGenerator(nPatterns, priorities) {
    _priorities = (priorities as List).map((item) => item as int).toList();
    _n = priorities.length;
  }

  List prefixSums() {
    List<int> p = List.filled(_n, 0);
    for (var k = 1; k < _n; k++) {
      p[k] = (p[k - 1] + _priorities[k - 1] as int);
    }
    return p;
  }

  double doubleInRange(Random source, num start, num end) =>
      source.nextDouble() * (end - start) + start;

  int pickIndex() {
    Random random = Random.secure();
    List preS = prefixSums();
    int sumP = (_priorities as List<int>).reduce((a, b) => a + b);
    double pI = doubleInRange(random, 0, sumP);
    if (pI > preS[preS.length - 1]) return preS.length - 1;
    for (var i = 0; i < preS.length - 1; i++) {
      if (pI > preS[i] && pI < preS[i + 1]) {
        return i;
      }
    }
    return -1;
  }
}

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnPpQqRrSsTtUuVvWwXxYyZz';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

class _MyHomePageState extends State<MyHomePage> {
  final _languages = {};
  late Map _data;
  int _questionNumber = 0;
  List _langList = [];
  String _language = "";
  final List<int> _langPriorities = [];
  List _correctPatterns = [];
  final List _incorrectPatternGroups = [];
  final List _incorrectPatternPriorities = [];
  List _questions = [];
  String _questionSubType = "";
  String _currentCategory = "Integer Assignment";
  List _variablePermutations = [];
  List _variableBranching = [];
  int _questionRange = 0;
  String _question = "";
  String _correctAnswer = "";
  final List _choices = [];
  final List<String> _choiceSelections = [];
  final Set<String> _incorrectSelections = {};
  String? _correctAnswerSelected;
  List _intSmallVarSet = [];
  List _intVarNames = [];
  List _intRustVarTypes = [];
  List _stringVarNames = [];
  List _stringValues = [];
  List _boolVarNames = [];
  List _boolValues = [];
  final List<String> _answerGroup = [];

  UserStats _userStats = DatabaseService.instance.getUserStats();
  bool _isLoading = true;

  Timer? _questionTimer;
  int _remainingSeconds = 20;
  static const int _totalSeconds = 20;
  bool _isTimerExpired = false;

  String? _topAlertMessage;
  IconData _topAlertIcon = Icons.cancel;
  Color _topAlertColor = Colors.redAccent.shade700;
  Timer? _topAlertTimer;

  void _showTopAlert({
    required String message,
    IconData icon = Icons.cancel,
    Color? backgroundColor,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    _topAlertTimer?.cancel();
    setState(() {
      _topAlertMessage = message;
      _topAlertIcon = icon;
      _topAlertColor = backgroundColor ?? Colors.redAccent.shade700;
    });
    _topAlertTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _topAlertMessage = null;
        });
      }
    });
  }

  void _startTimer() {
    _questionTimer?.cancel();
    _remainingSeconds = _totalSeconds;
    _isTimerExpired = false;
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _handleTimeout();
      }
    });
  }

  void _cancelTimer() {
    _questionTimer?.cancel();
    _questionTimer = null;
  }

  void _handleTimeout() async {
    _cancelTimer();
    setState(() {
      _remainingSeconds = 0;
      _isTimerExpired = true;
    });

    final updatedStats = await DatabaseService.instance.recordAnswer(
      language: _language,
      isCorrect: false,
      timeRemainingSeconds: 0,
    );

    if (!mounted) return;
    setState(() {
      _userStats = updatedStats;
    });

    _showTopAlert(
      message: "Time's up! Streak reset.",
      icon: Icons.timer_off_outlined,
      backgroundColor: Colors.red.shade800,
    );
  }

  Future<void> _loadData() async {
    final data = await DatabaseService.instance.getOrSeedCatalog();
    final stats = DatabaseService.instance.getUserStats();
    if (!mounted) return;
    setState(() {
      _data = data;
      _userStats = stats;
      _isLoading = false;
      _data["Language"].forEach((item) {
        _languages[item] = 1;
      });
      _langList =
          (_data["Language"] as List).map((item) => item as String).toList();
      _languages.forEach((k, v) => _langPriorities.add(v));
    });
    _intVarNames = (_data['Variables']['Int Variable Names'] as List? ?? ['x', 'count']);
    _intSmallVarSet =
        (_data['Variables']['Integer Small Variable Sets'] as List? ?? ['x', 'y']);
    _intRustVarTypes = (_data['Variables']['Rust Int Variable Types'] as List? ?? ['i32']);
    _stringVarNames = (_data['Variables']['String Variable Names'] as List? ?? ['message', 'title']);
    _stringValues = (_data['Variables']['String Values'] as List? ?? ['Hello', 'World']);
    _boolVarNames = (_data['Variables']['Bool Variable Names'] as List? ?? ['isActive', 'isValid']);
    _boolValues = (_data['Variables']['Bool Values'] as List? ?? ['true', 'false']);
    generateQuestion();
  }

  String renderPatternOptions(answer, pattern) {
    String render = (answer as String);
    pattern.forEach((p) {
      if (answer.contains(p)) {
        List options = p.substring(1, p.length - 1).split("|");
        Random random = Random.secure();
        String option = options[random.nextInt(options.length)];
        if (option == "None") {
          render = render.replaceAll(p, "");
        } else {
          render = render.replaceAll(p, option);
        }
      }
    });
    return render.trim();
  }

  renderPatternBranching(answer, pattern) {
    String render = answer;
    Random random = Random.secure();
    pattern.forEach((p) {
      if (p.contains("[extensible whitespace]")) {
        int r = random.nextInt(2);
        if (r == 0) {
          render = render.replaceAll(p, " ");
        } else {
          render = render.replaceAll(p, "");
        }
      }
      if (p.contains("[optional semicolon]")) {
        int r = random.nextInt(2);
        if (r == 0) {
          render = render.replaceAll(p, ";");
        } else {
          render = render.replaceAll(p, "");
        }
      }
      if (p.contains("[random int variable]")) {
        int r = random.nextInt(3);
        if (r == 0) {
          render = render.replaceAll(p, getRandomString(1));
        } else if (r == 1) {
          render = render.replaceAll(
              p, _intVarNames[random.nextInt(_intVarNames.length)]);
        } else if (r == 2) {
          render = render.replaceAll(
              p, _intSmallVarSet[random.nextInt(_intSmallVarSet.length)]);
        }
      }
      if (p.contains("[random integer]")) {
        int r = random.nextInt(4);
        if (r == 0) {
          render = render.replaceAll(p, random.nextInt(10).toString());
        } else if (r == 1) {
          render = render.replaceAll(p, random.nextInt(100).toString());
        } else if (r == 2) {
          render = render.replaceAll(p, random.nextInt(10000).toString());
        } else if (r == 3) {
          render = render.replaceAll(p, random.nextInt(1000000).toString());
        }
      }
      if (p.contains("[random rust data type]")) {
        render = render.replaceAll(
            p, _intRustVarTypes[random.nextInt(_intRustVarTypes.length)]);
      }
      if (p.contains("[random string variable]")) {
        render = render.replaceAll(
            p, _stringVarNames[random.nextInt(_stringVarNames.length)]);
      }
      if (p.contains("[random string]")) {
        render = render.replaceAll(
            p, _stringValues[random.nextInt(_stringValues.length)]);
      }
      if (p.contains("[random bool variable]")) {
        render = render.replaceAll(
            p, _boolVarNames[random.nextInt(_boolVarNames.length)]);
      }
      if (p.contains("[random bool]")) {
        render = render.replaceAll(
            p, _boolValues[random.nextInt(_boolValues.length)]);
      }
      if (p.contains("[random float variable]")) {
        render = render.replaceAll(p, "rate");
      }
      if (p.contains("[random float]")) {
        render = render.replaceAll(p, "3.14");
      }
    });
    return render.trim();
  }

  void generateQuestion() {
    _cancelTimer();
    _topAlertTimer?.cancel();
    _topAlertMessage = null;
    _answerGroup.clear();
    _choices.clear();
    _incorrectPatternGroups.clear();
    _incorrectPatternPriorities.clear();
    _choiceSelections.clear();
    _incorrectSelections.clear();
    _correctAnswerSelected = null;
    _isTimerExpired = false;

    // 1. Adaptive Skill-Level: Pick Category based on user Level
    final categories = DatabaseService.instance
        .getAvailableCategoriesForLevel(_userStats.level);
    Random random = Random.secure();
    _currentCategory = categories[random.nextInt(categories.length)];

    // 2. Adaptive Spaced Repetition: Sample language based on weak areas
    final adaptivePriorities = DatabaseService.instance
        .getAdaptiveLanguagePriorities(_langList.cast<String>());
    PriorityRandomGenerator prgLanguage =
        PriorityRandomGenerator(_langList.length, adaptivePriorities);
    _language = (_langList[prgLanguage.pickIndex()] as String);

    final categoryData =
        _data["Variables"]["Declaration"][_currentCategory] as Map? ??
            _data["Variables"]["Declaration"]["Integer Assignment"] as Map;

    _correctAnswer = (categoryData["Answers"]["Preferred"][_language] as String? ?? "");
    final correctList = (categoryData["Answers"]["Correct"][_language] as List? ?? []);
    if (correctList.isNotEmpty && random.nextInt(2) == 1) {
      final answerSelection = random.nextInt(correctList.length);
      _correctAnswer = (correctList[answerSelection] as String);
      if (random.nextInt(4) == 1) {
        _correctAnswer =
            _correctAnswer.replaceAll("[extensible whitespace]", "");
      } else {
        _correctAnswer =
            _correctAnswer.replaceAll("[extensible whitespace]", " ");
      }
      if (random.nextInt(2) == 1) {
        _correctAnswer = _correctAnswer.replaceAll("[optional semicolon]", "");
      } else {
        _correctAnswer = _correctAnswer.replaceAll("[optional semicolon]", ";");
      }
    }

    _correctPatterns = correctList;
    _incorrectPatternGroups.clear();
    final incorrectList = (categoryData['Answers']['Incorrect'] as List? ?? []);
    for (var item in incorrectList) {
      _incorrectPatternGroups.add([item['Pattern'], item['Priority']]);
      _incorrectPatternPriorities.add(item['Priority']);
    }

    _questions = (categoryData['Question'] as List? ?? ["Select the correct syntax for [language]:"]);
    _questionSubType = (categoryData['Sub-Type'] as String? ?? _currentCategory);
    _variablePermutations =
        (_data['Variables']['Variable Permutations'] as List);
    _variableBranching = (_data['Variables']['Random Variables'] as List);
    _questionRange = _questions.length;
    _questionNumber = random.nextInt(_questionRange);
    _question = _questions[_questionNumber].replaceAll("[language]", _language);

    _choices.add([_correctAnswer, 1]);
    _choiceSelections.add(_correctAnswer);

    if (_incorrectPatternGroups.isNotEmpty) {
      PriorityRandomGenerator prgChoice = PriorityRandomGenerator(
          _incorrectPatternGroups.length, _incorrectPatternPriorities);
      int attempts = 0;
      while (_choices.length < 5 && attempts < 50) {
        attempts++;
        String incorrectAnswer = renderPatternOptions(
            _incorrectPatternGroups[prgChoice.pickIndex()][0],
            _variablePermutations);
        if (_choiceSelections.contains(incorrectAnswer)) continue;
        if (_correctPatterns.contains(incorrectAnswer)) continue;
        _choices.add([incorrectAnswer, 0]);
        _choiceSelections.add(incorrectAnswer);
      }
    }

    _choices.shuffle();

    for (int i = 0; i < _choices.length; i++) {
      _choices[i][0] =
          renderPatternBranching(_choices[i][0], _variableBranching);
    }

    for (var e in _choices) {
      _answerGroup.add(e[0]);
    }

    _startTimer();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _cancelTimer();
    _topAlertTimer?.cancel();
    super.dispose();
  }

  Widget _buildStatItem({
    required String icon,
    required String value,
    required String label,
    required double fontSize,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: TextStyle(fontSize: fontSize + 2)),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: (fontSize * 0.75).clamp(9.0, 12.0),
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.65),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatDivider(ThemeData theme) {
    return Container(
      width: 1,
      height: 24,
      color: theme.colorScheme.outline.withOpacity(0.2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: theme.colorScheme.inversePrimary,
          title: Text(
            widget.title.isNotEmpty ? widget.title : 'HardCode',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: Row(
          children: [
            Text(
              widget.title.isNotEmpty ? widget.title : 'HardCode',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Lvl ${_userStats.level}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'HardCode',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '⚡ Level ${_userStats.level} • ${_userStats.rankTitle}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimary.withOpacity(0.95),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _userStats.levelProgress,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_userStats.currentLevelXp} / 150 XP to Next Level',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: theme.colorScheme.onPrimary.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bolt, color: Colors.amber),
              title: const Text('Total XP'),
              trailing: Text(
                '${_userStats.xp} XP',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.local_fire_department, color: Colors.orange),
              title: const Text('Current Streak'),
              trailing: Text(
                '${_userStats.currentStreak}',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.amber),
              title: const Text('Best Streak'),
              trailing: Text(
                '${_userStats.bestStreak}',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.track_changes, color: Colors.green),
              title: const Text('Accuracy'),
              trailing: Text(
                '${_userStats.accuracy.toStringAsFixed(1)}%',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.quiz_outlined, color: Colors.blue),
              title: const Text('Total Solved'),
              trailing: Text(
                '${_userStats.totalAnswered} (${_userStats.totalCorrect} correct)',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Text(
                'Adaptive Learning Engine',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'HardCode tracks question patterns and error frequencies to prioritize topics and languages where you need practice.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
              ),
            ),
            const Divider(),
            if (_userStats.languageStats.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Text(
                  'Per-Language Mastery',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              ..._userStats.languageStats.entries.map((entry) {
                final lang = entry.key;
                final stats = Map<String, dynamic>.from(entry.value as Map);
                final total = stats['total'] ?? 0;
                final correct = stats['correct'] ?? 0;
                final pct = total == 0 ? 0 : (correct / total * 100).round();
                return ListTile(
                  dense: true,
                  title: Text(lang, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  subtitle: Text('$correct of $total correct'),
                  trailing: Text(
                    '$pct%',
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
                  ),
                );
              }),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Reset Stats', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                await DatabaseService.instance.resetStats();
                if (!mounted) return;
                setState(() {
                  _userStats = DatabaseService.instance.getUserStats();
                });
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;

          // Continuous fluid scaling factors based on window width and height
          final double hScale = (availableWidth / 680.0).clamp(0.65, 1.15);
          final double vScale = (availableHeight / 750.0).clamp(0.65, 1.10);
          final double scale = min(hScale, vScale);

          final double cardWidth =
              (availableWidth * 0.88).clamp(280.0, 560.0);
          final double questionFontSize = (22.0 * scale).clamp(14.0, 25.0);
          final double badgeFontSize = (14.0 * scale).clamp(11.0, 16.0);
          final double buttonFontSize = (19.0 * scale).clamp(13.0, 22.0);
          final double buttonVerticalPadding =
              (16.0 * scale).clamp(9.0, 18.0);
          final double buttonHorizontalPadding =
              (20.0 * scale).clamp(12.0, 24.0);
          final double buttonVerticalMargin =
              (6.0 * scale).clamp(3.0, 7.0);
          final double contentSpacing =
              (20.0 * scale).clamp(10.0, 26.0);
          final double titleSpacing =
              (12.0 * scale).clamp(8.0, 16.0);
          final double statFontSize = (13.0 * scale).clamp(10.0, 15.0);

          // Timer color shift
          Color timerColor = Colors.green.shade600;
          if (_remainingSeconds <= 5) {
            timerColor = Colors.redAccent.shade700;
          } else if (_remainingSeconds <= 10) {
            timerColor = Colors.orange.shade700;
          }

          return Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: (20.0 * scale).clamp(10.0, 24.0),
                      vertical: (20.0 * scale).clamp(10.0, 28.0),
                    ),
                    child: Center(
                child: SizedBox(
                  width: cardWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Gamification Header (Rank, Level, XP)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: (14.0 * scale).clamp(10.0, 16.0),
                          vertical: (8.0 * scale).clamp(6.0, 10.0),
                        ),
                        margin: EdgeInsets.only(
                          bottom: (10.0 * scale).clamp(6.0, 14.0),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primaryContainer.withOpacity(0.5),
                              theme.colorScheme.surfaceVariant.withOpacity(0.4),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '⚡ Level ${_userStats.level} • ${_userStats.rankTitle}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: (statFontSize * 0.95).clamp(10.0, 14.0),
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  '${_userStats.currentLevelXp} / 150 XP',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: (statFontSize * 0.9).clamp(10.0, 13.0),
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: (6.0 * scale).clamp(4.0, 8.0)),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _userStats.levelProgress,
                                minHeight: (5.0 * scale).clamp(4.0, 7.0),
                                backgroundColor: theme.colorScheme.outline.withOpacity(0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Persistent Stats Banner
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: (14.0 * scale).clamp(8.0, 18.0),
                          vertical: (8.0 * scale).clamp(5.0, 10.0),
                        ),
                        margin: EdgeInsets.only(
                          bottom: (12.0 * scale).clamp(8.0, 16.0),
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem(
                              icon: '🔥',
                              value: '${_userStats.currentStreak}',
                              label: 'Streak',
                              fontSize: statFontSize,
                              theme: theme,
                            ),
                            _buildStatDivider(theme),
                            _buildStatItem(
                              icon: '🏆',
                              value: '${_userStats.bestStreak}',
                              label: 'Best',
                              fontSize: statFontSize,
                              theme: theme,
                            ),
                            _buildStatDivider(theme),
                            _buildStatItem(
                              icon: '🎯',
                              value: '${_userStats.accuracy.toStringAsFixed(0)}%',
                              label: 'Accuracy',
                              fontSize: statFontSize,
                              theme: theme,
                            ),
                          ],
                        ),
                      ),

                      // Countdown Timer Bar
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: (12.0 * scale).clamp(8.0, 16.0),
                          vertical: (6.0 * scale).clamp(4.0, 8.0),
                        ),
                        margin: EdgeInsets.only(
                          bottom: (14.0 * scale).clamp(8.0, 18.0),
                        ),
                        decoration: BoxDecoration(
                          color: timerColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: timerColor.withOpacity(0.3),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: (16.0 * scale).clamp(13.0, 18.0),
                                      color: timerColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isTimerExpired ? "Time's up!" : 'Time Remaining',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: (statFontSize * 0.9).clamp(10.0, 13.0),
                                        fontWeight: FontWeight.w600,
                                        color: timerColor,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${_remainingSeconds}s',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: (statFontSize * 1.05).clamp(11.0, 15.0),
                                    fontWeight: FontWeight.bold,
                                    color: timerColor,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: (4.0 * scale).clamp(3.0, 6.0)),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: _remainingSeconds / _totalSeconds.toDouble(),
                                minHeight: (4.0 * scale).clamp(3.0, 6.0),
                                backgroundColor: timerColor.withOpacity(0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_language.isNotEmpty) ...[
                        Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: (16.0 * scale).clamp(10.0, 18.0),
                              vertical: (7.0 * scale).clamp(4.0, 8.0),
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$_language • $_questionSubType',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: badgeFontSize,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: titleSpacing),
                        Text(
                          _question,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: questionFontSize,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: contentSpacing),
                      ],

                      Column(
                        children: _answerGroup.map((String answerButton) {
                          final isWrong = _incorrectSelections.contains(answerButton);
                          final isCorrectAnswer = (_correctAnswerSelected == answerButton) ||
                              (_isTimerExpired && _correctAnswer == answerButton);
                          final isDisabled = _isTimerExpired ||
                              (_correctAnswerSelected != null) ||
                              isWrong;

                          return AnswerButton(
                            key: ValueKey('${_questionNumber}_${answerButton}_${isWrong}_$isCorrectAnswer'),
                            text: answerButton,
                            fontSize: buttonFontSize,
                            verticalPadding: buttonVerticalPadding,
                            horizontalPadding: buttonHorizontalPadding,
                            verticalMargin: buttonVerticalMargin,
                            isIncorrect: isWrong,
                            isCorrect: isCorrectAnswer,
                            isDisabled: isDisabled,
                            onPressed: isDisabled
                                ? null
                                : () async {
                                    int answer = _choices[
                                        _answerGroup.indexOf(answerButton)][1];
                                    final isCorrect = (answer == 1);

                                    if (isCorrect) {
                                      _cancelTimer();
                                      _topAlertTimer?.cancel();
                                      final updatedStats =
                                          await DatabaseService.instance.recordAnswer(
                                        language: _language,
                                        isCorrect: true,
                                        timeRemainingSeconds: _remainingSeconds,
                                      );
                                      if (!mounted) return;
                                      setState(() {
                                        _topAlertMessage = null;
                                        _correctAnswerSelected = answerButton;
                                        _userStats = updatedStats;
                                      });

                                      // Brief celebratory delay before advancing
                                      Future.delayed(
                                          const Duration(milliseconds: 700), () {
                                        if (!mounted) return;
                                        setState(() {
                                          generateQuestion();
                                        });
                                      });
                                    } else {
                                      final updatedStats =
                                          await DatabaseService.instance.recordAnswer(
                                        language: _language,
                                        isCorrect: false,
                                        timeRemainingSeconds: _remainingSeconds,
                                      );
                                      if (!mounted) return;
                                      setState(() {
                                        _incorrectSelections.add(answerButton);
                                        _userStats = updatedStats;
                                      });

                                      _showTopAlert(
                                        message:
                                            'Incorrect choice. Try another option!',
                                        icon: Icons.cancel,
                                        backgroundColor:
                                            Colors.redAccent.shade700,
                                      );
                                    }
                                  },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Floating Notification Bubble at the Top of the Page
        AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            top: _topAlertMessage != null
                ? (16.0 * scale).clamp(10.0, 20.0)
                : -80.0,
            left: 16,
            right: 16,
            child: IgnorePointer(
              ignoring: _topAlertMessage == null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _topAlertMessage != null ? 1.0 : 0.0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _topAlertMessage = null;
                      });
                    },
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 480),
                      padding: EdgeInsets.symmetric(
                        horizontal: (16.0 * scale).clamp(12.0, 20.0),
                        vertical: (10.0 * scale).clamp(8.0, 12.0),
                      ),
                      decoration: BoxDecoration(
                        color: _topAlertColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _topAlertIcon,
                            color: Colors.white,
                            size: (18.0 * scale).clamp(15.0, 20.0),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _topAlertMessage ?? '',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize:
                                    (13.5 * scale).clamp(11.5, 15.0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            generateQuestion();
          });
        },
        tooltip: 'Next Question',
        child: const Icon(Icons.skip_next),
      ),
    );
  }
}

class AnswerButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final double fontSize;
  final double verticalPadding;
  final double horizontalPadding;
  final double verticalMargin;
  final bool isIncorrect;
  final bool isCorrect;
  final bool isDisabled;

  const AnswerButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.fontSize = 18.0,
    this.verticalPadding = 14.0,
    this.horizontalPadding = 20.0,
    this.verticalMargin = 5.0,
    this.isIncorrect = false,
    this.isCorrect = false,
    this.isDisabled = false,
  });

  @override
  State<AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<AnswerButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    Color bgColor = theme.colorScheme.surface;
    Color borderColor = theme.colorScheme.outline.withOpacity(0.35);
    Color textColor = theme.colorScheme.onSurface;
    double borderWidth = 1.4;

    if (widget.isIncorrect) {
      bgColor = Colors.red.withOpacity(0.08);
      borderColor = Colors.red.shade400;
      textColor = Colors.red.shade800;
      borderWidth = 2.0;
    } else if (widget.isCorrect) {
      bgColor = Colors.green.withOpacity(0.12);
      borderColor = Colors.green.shade600;
      textColor = Colors.green.shade800;
      borderWidth = 2.2;
    } else if (_isHovered && !widget.isDisabled) {
      bgColor = primary.withOpacity(0.08);
      borderColor = primary;
      textColor = primary;
      borderWidth = 2.2;
    } else if (widget.isDisabled) {
      bgColor = theme.colorScheme.surface.withOpacity(0.6);
      borderColor = theme.colorScheme.outline.withOpacity(0.15);
      textColor = theme.colorScheme.onSurface.withOpacity(0.4);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.verticalMargin),
      child: MouseRegion(
        onEnter: (_) {
          if (!widget.isDisabled) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (!widget.isDisabled) setState(() => _isHovered = false);
        },
        cursor: widget.isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: (_isHovered && !widget.isDisabled)
                ? [
                    BoxShadow(
                      color: primary.withOpacity(0.20),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              splashColor: widget.isDisabled ? Colors.transparent : primary.withOpacity(0.12),
              highlightColor: widget.isDisabled ? Colors.transparent : primary.withOpacity(0.05),
              onTap: widget.onPressed,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: widget.verticalPadding,
                  horizontal: widget.horizontalPadding,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.text,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: widget.fontSize,
                              fontWeight: (_isHovered || widget.isCorrect || widget.isIncorrect)
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: textColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.isIncorrect) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ] else if (widget.isCorrect) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
