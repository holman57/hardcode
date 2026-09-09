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
      title: 'HardCode Academy',
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

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _graphController;
  List<double> _prevAccuracyHistory = [];
  bool _isAccuracyUp = false;
  double _trendDelta = 0.0;

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
    final double delta = (updatedStats.accuracyHistory.length >= 2)
        ? updatedStats.accuracyHistory.last -
            updatedStats.accuracyHistory[updatedStats.accuracyHistory.length - 2]
        : (updatedStats.recentAccuracy - _userStats.recentAccuracy);
    setState(() {
      _prevAccuracyHistory = List<double>.from(_userStats.accuracyHistory);
      _userStats = updatedStats;
      _isAccuracyUp = false;
      _trendDelta = delta;
    });
    _graphController.forward(from: 0.0);

    _showTopAlert(
      message: "Time's up! Correct answer is indicated below.",
      icon: Icons.timer_off_outlined,
      backgroundColor: Colors.red.shade800,
    );
  }

  Future<void> _loadData() async {
    final data = await DatabaseService.instance.getOrSeedCatalog();
    final stats = DatabaseService.instance.getUserStats();
    double initialTrend = 0.0;
    if (stats.accuracyHistory.length >= 2) {
      initialTrend = stats.accuracyHistory.last -
          stats.accuracyHistory[stats.accuracyHistory.length - 2];
    }
    if (!mounted) return;
    setState(() {
      _data = data;
      _prevAccuracyHistory = List<double>.from(stats.accuracyHistory);
      _userStats = stats;
      _trendDelta = initialTrend;
      _isAccuracyUp = initialTrend > 0.05;
      _isLoading = false;
      _data["Language"].forEach((item) {
        _languages[item] = 1;
      });
      _langList =
          (_data["Language"] as List).map((item) => item as String).toList();
      _languages.forEach((k, v) => _langPriorities.add(v));
    });
    _graphController.forward(from: 0.0);
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
      if (_choices[i][1] == 1) {
        _correctAnswer = _choices[i][0];
      }
    }

    for (var e in _choices) {
      _answerGroup.add(e[0]);
    }

    _startTimer();
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 65,
      ),
    ]).animate(_pulseController);
    _graphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _cancelTimer();
    _topAlertTimer?.cancel();
    _pulseController.dispose();
    _graphController.dispose();
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

  Widget _buildSparklineStatItem({
    required Widget sparkline,
    required String label,
    required double fontSize,
    required ThemeData theme,
    required double trendDelta,
  }) {
    String trendIndicator = '';
    Color trendColor = theme.colorScheme.onSurface.withOpacity(0.65);
    if (trendDelta > 0.05) {
      trendIndicator = '▲';
      trendColor = Colors.greenAccent.shade700;
    } else if (trendDelta < -0.05) {
      trendIndicator = '▼';
      trendColor = Colors.redAccent.shade700;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        sparkline,
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trendIndicator.isNotEmpty) ...[
              Text(
                trendIndicator,
                style: TextStyle(
                  fontSize: (fontSize * 0.65).clamp(8.0, 11.0),
                  color: trendColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: (fontSize * 0.75).clamp(9.0, 12.0),
                fontWeight: FontWeight.w600,
                color: trendIndicator.isNotEmpty
                    ? trendColor
                    : theme.colorScheme.onSurface.withOpacity(0.65),
              ),
            ),
          ],
        ),
      ],
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
            widget.title.isNotEmpty ? widget.title : 'HardCode Academy',
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
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 460;
            if (isNarrow) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title.isNotEmpty
                              ? widget.title
                              : 'HardCode Academy',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_language.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withOpacity(0.85),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.colorScheme.outline
                                    .withOpacity(0.18),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              _questionSubType.isNotEmpty
                                  ? '$_language • $_questionSubType'
                                  : _language,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Lvl ${_userStats.level}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Text(
                  widget.title.isNotEmpty ? widget.title : 'HardCode Academy',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (_language.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.18),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _questionSubType.isNotEmpty
                          ? '$_language • $_questionSubType'
                          : _language,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            );
          },
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
                    'HardCode Academy',
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
                  _prevAccuracyHistory = [];
                  _userStats = DatabaseService.instance.getUserStats();
                  _isAccuracyUp = false;
                  _trendDelta = 0.0;
                });
                _graphController.forward(from: 0.0);
                _pulseController.reset();
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
          final double buttonFontSize = (19.0 * scale).clamp(13.0, 22.0);
          final double buttonVerticalPadding =
              (16.0 * scale).clamp(9.0, 18.0);
          final double buttonHorizontalPadding =
              (20.0 * scale).clamp(12.0, 24.0);
          final double buttonVerticalMargin =
              (6.0 * scale).clamp(3.0, 7.0);
          final double contentSpacing =
              (20.0 * scale).clamp(10.0, 26.0);
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
                            _buildStatDivider(theme),
                            _buildSparklineStatItem(
                              sparkline: AccuracySparkline(
                                currentData: _userStats.accuracyHistory,
                                previousData: _prevAccuracyHistory,
                                graphAnimation: _graphController,
                                pulseAnimation: _pulseAnimation,
                                isAccuracyUp: _isAccuracyUp,
                                trendDelta: _trendDelta,
                                width: (60.0 * scale).clamp(46.0, 76.0),
                                height: (18.0 * scale).clamp(15.0, 22.0),
                                theme: theme,
                              ),
                              label: 'Recent',
                              fontSize: statFontSize,
                              theme: theme,
                              trendDelta: _trendDelta,
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
                        children: _answerGroup.asMap().entries.map((entry) {
                          final int idx = entry.key;
                          final String answerButton = entry.value;
                          final bool isActualCorrectChoice =
                              (idx < _choices.length && _choices[idx][1] == 1);
                          final isWrong = _incorrectSelections.contains(answerButton);
                          final isCorrectAnswer = (_correctAnswerSelected == answerButton) ||
                              (_isTimerExpired && isActualCorrectChoice);
                          final isTimeoutReveal = _isTimerExpired && isActualCorrectChoice;
                          final isDisabled = _isTimerExpired ||
                              (_correctAnswerSelected != null) ||
                              isWrong;

                          return AnswerButton(
                            key: ValueKey(
                                '${_questionNumber}_${answerButton}_${isWrong}_${isCorrectAnswer}_${isTimeoutReveal}_$_isTimerExpired'),
                            text: answerButton,
                            fontSize: buttonFontSize,
                            verticalPadding: buttonVerticalPadding,
                            horizontalPadding: buttonHorizontalPadding,
                            verticalMargin: buttonVerticalMargin,
                            isIncorrect: isWrong,
                            isCorrect: isCorrectAnswer,
                            isDisabled: isDisabled,
                            isTimeoutReveal: isTimeoutReveal,
                            onPressed: isDisabled
                                ? (isTimeoutReveal
                                    ? () {
                                        setState(() {
                                          generateQuestion();
                                        });
                                      }
                                    : null)
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
                                      final double delta = (updatedStats.accuracyHistory.length >= 2)
                                          ? updatedStats.accuracyHistory.last -
                                              updatedStats.accuracyHistory[updatedStats.accuracyHistory.length - 2]
                                          : (updatedStats.recentAccuracy - _userStats.recentAccuracy);
                                      final bool accuracyWentUp = (delta >= -0.001);
                                      setState(() {
                                        _prevAccuracyHistory = List<double>.from(
                                            _userStats.accuracyHistory);
                                        _topAlertMessage = null;
                                        _correctAnswerSelected = answerButton;
                                        _userStats = updatedStats;
                                        _isAccuracyUp = accuracyWentUp;
                                        _trendDelta = delta;
                                      });
                                      _graphController.forward(from: 0.0);
                                      if (accuracyWentUp) {
                                        _pulseController.forward(from: 0.0);
                                      }

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
                                      final double delta = (updatedStats.accuracyHistory.length >= 2)
                                          ? updatedStats.accuracyHistory.last -
                                              updatedStats.accuracyHistory[updatedStats.accuracyHistory.length - 2]
                                          : (updatedStats.recentAccuracy - _userStats.recentAccuracy);
                                      setState(() {
                                        _prevAccuracyHistory = List<double>.from(
                                            _userStats.accuracyHistory);
                                        _incorrectSelections.add(answerButton);
                                        _userStats = updatedStats;
                                        _isAccuracyUp = false;
                                        _trendDelta = delta;
                                      });
                                      _graphController.forward(from: 0.0);

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
                      if (_isTimerExpired) ...[
                        SizedBox(height: (16.0 * scale).clamp(12.0, 20.0)),
                        Center(
                          child: FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                generateQuestion();
                              });
                            },
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: const Text('Next Question'),
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: EdgeInsets.symmetric(
                                horizontal: (24.0 * scale).clamp(18.0, 32.0),
                                vertical: (12.0 * scale).clamp(10.0, 16.0),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: GoogleFonts.plusJakartaSans(
                                fontSize: (15.0 * scale).clamp(13.0, 17.0),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                ? (18.0 * scale).clamp(12.0, 24.0)
                : -120.0,
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
                      constraints: const BoxConstraints(maxWidth: 540),
                      padding: EdgeInsets.symmetric(
                        horizontal: (22.0 * scale).clamp(16.0, 30.0),
                        vertical: (13.0 * scale).clamp(10.0, 18.0),
                      ),
                      decoration: BoxDecoration(
                        color: _topAlertColor,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _topAlertIcon,
                            color: Colors.white,
                            size: (24.0 * scale).clamp(19.0, 28.0),
                          ),
                          SizedBox(width: (10.0 * scale).clamp(8.0, 14.0)),
                          Flexible(
                            child: Text(
                              _topAlertMessage ?? '',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize:
                                    (15.5 * scale).clamp(13.0, 18.0),
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
  final bool isTimeoutReveal;

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
    this.isTimeoutReveal = false,
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
    } else if (widget.isCorrect || widget.isTimeoutReveal) {
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
      bgColor = theme.colorScheme.surface.withOpacity(0.55);
      borderColor = theme.colorScheme.outline.withOpacity(0.14);
      textColor = theme.colorScheme.onSurface.withOpacity(0.35);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.verticalMargin),
      child: MouseRegion(
        onEnter: (_) {
          if (!widget.isDisabled || widget.isTimeoutReveal) {
            setState(() => _isHovered = true);
          }
        },
        onExit: (_) {
          if (!widget.isDisabled || widget.isTimeoutReveal) {
            setState(() => _isHovered = false);
          }
        },
        cursor: (widget.isDisabled && !widget.isTimeoutReveal)
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
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
            boxShadow: widget.isTimeoutReveal
                ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : (_isHovered && (!widget.isDisabled || widget.isTimeoutReveal))
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
              splashColor: (widget.isDisabled && !widget.isTimeoutReveal)
                  ? Colors.transparent
                  : primary.withOpacity(0.12),
              highlightColor: (widget.isDisabled && !widget.isTimeoutReveal)
                  ? Colors.transparent
                  : primary.withOpacity(0.05),
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
                              fontWeight: (_isHovered ||
                                      widget.isCorrect ||
                                      widget.isIncorrect ||
                                      widget.isTimeoutReveal)
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
                    ] else if (widget.isTimeoutReveal) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.35),
                              blurRadius: 5,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              'Correct',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
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

class AccuracySparkline extends StatelessWidget {
  final List<double> currentData;
  final List<double> previousData;
  final Animation<double> graphAnimation;
  final Animation<double> pulseAnimation;
  final bool isAccuracyUp;
  final double trendDelta;
  final double width;
  final double height;
  final ThemeData theme;

  const AccuracySparkline({
    super.key,
    required this.currentData,
    required this.previousData,
    required this.graphAnimation,
    required this.pulseAnimation,
    required this.isAccuracyUp,
    required this.trendDelta,
    required this.width,
    required this.height,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([graphAnimation, pulseAnimation]),
      builder: (context, child) {
        final double pulseVal = pulseAnimation.value;
        final Color baseThemeColor = theme.colorScheme.primary;

        // Effective base color determined by recent trend direction
        Color baseLineColor;
        if (trendDelta > 0.05) {
          baseLineColor = const Color(0xFF10B981); // Emerald green
        } else if (trendDelta < -0.05) {
          baseLineColor = const Color(0xFFEF4444); // Red/coral
        } else {
          baseLineColor = baseThemeColor;
        }

        const Color pulseLineColor = Color(0xFF00E676); // Radiant neon green
        final Color effectiveLineColor = isAccuracyUp
            ? Color.lerp(baseLineColor, pulseLineColor, pulseVal)!
            : baseLineColor;

        final bool isLightingUp = isAccuracyUp && (pulseVal > 0.01);

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: isLightingUp
                ? Color.lerp(
                    theme.colorScheme.surface.withOpacity(0.5),
                    const Color(0xFF10B981).withOpacity(0.25),
                    pulseVal,
                  )
                : theme.colorScheme.surface.withOpacity(0.4),
            border: Border.all(
              color: isLightingUp
                  ? Color.lerp(
                      theme.colorScheme.outline.withOpacity(0.18),
                      const Color(0xFF00E676),
                      pulseVal,
                    )!
                  : theme.colorScheme.outline.withOpacity(0.18),
              width: isLightingUp ? (1.0 + (1.0 * pulseVal)) : 1.0,
            ),
            boxShadow: isLightingUp
                ? [
                    BoxShadow(
                      color: const Color(0xFF00E676).withOpacity(0.55 * pulseVal),
                      blurRadius: 8 * pulseVal,
                      spreadRadius: 1.0 * pulseVal,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: CustomPaint(
              size: Size(width, height),
              painter: AccuracyChartPainter(
                currentData: currentData,
                previousData: previousData,
                progress: graphAnimation.value,
                lineColor: effectiveLineColor,
                pulseValue: isAccuracyUp ? pulseVal : 0.0,
              ),
            ),
          ),
        );
      },
    );
  }
}

class AccuracyChartPainter extends CustomPainter {
  final List<double> currentData;
  final List<double> previousData;
  final double progress;
  final Color lineColor;
  final double pulseValue;

  AccuracyChartPainter({
    required this.currentData,
    required this.previousData,
    required this.progress,
    required this.lineColor,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    List<double> points = [];
    final int maxLen = max(currentData.length, previousData.length);
    if (maxLen == 0) {
      points = [50.0, 50.0];
    } else {
      for (int i = 0; i < currentData.length; i++) {
        final double curr = currentData[i];
        double prev = curr;
        if (i < previousData.length) {
          prev = previousData[i];
        } else if (previousData.isNotEmpty) {
          prev = previousData.last;
        }
        points.add(prev + (curr - prev) * progress);
      }
    }

    if (points.length == 1) {
      points.insert(0, points[0]);
    }

    // Dynamic vertical scaling to clearly visualize change in accuracy over time
    double minVal = points.reduce(min);
    double maxVal = points.reduce(max);
    double range = maxVal - minVal;
    if (range < 25.0) {
      if (maxVal >= 80.0) {
        // High accuracy window: place top near 100%, show downward dips prominently
        maxVal = 100.0;
        minVal = max(0.0, maxVal - 30.0);
      } else if (minVal <= 20.0) {
        // Low accuracy window: place bottom near 0%, show upward climbs prominently
        minVal = 0.0;
        maxVal = min(100.0, minVal + 30.0);
      } else {
        final double mid = (maxVal + minVal) / 2.0;
        minVal = (mid - 15.0).clamp(0.0, 100.0);
        maxVal = (mid + 15.0).clamp(0.0, 100.0);
      }
      range = maxVal - minVal;
    } else {
      final double pad = range * 0.12;
      minVal = (minVal - pad).clamp(0.0, 100.0);
      maxVal = (maxVal + pad).clamp(0.0, 100.0);
      range = maxVal - minVal;
    }
    if (range <= 0.001) range = 1.0;

    const double paddingX = 4.0;
    const double paddingY = 3.0;
    final double drawWidth = size.width - (paddingX * 2);
    final double drawHeight = size.height - (paddingY * 2);
    final double stepX = drawWidth / (points.length - 1);

    final List<Offset> offsets = [];
    for (int i = 0; i < points.length; i++) {
      final double normalizedY = ((points[i] - minVal) / range).clamp(0.0, 1.0);
      final double x = paddingX + (i * stepX);
      final double y = paddingY + drawHeight * (1.0 - normalizedY);
      offsets.add(Offset(x, y));
    }

    final Path path = Path();
    path.moveTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    // Gradient fill under the curve
    final Path fillPath = Path.from(path);
    fillPath.lineTo(offsets.last.dx, size.height);
    fillPath.lineTo(offsets.first.dx, size.height);
    fillPath.close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withOpacity(0.35 + (0.35 * pulseValue)),
          lineColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final Paint linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 + (0.8 * pulseValue)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Glowing anchor dot on the latest data point
    final Offset lastPoint = offsets.last;
    final Paint dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    final double dotRadius = 2.8 + (1.4 * pulseValue);
    canvas.drawCircle(lastPoint, dotRadius, dotPaint);

    if (pulseValue > 0.05) {
      final Paint haloPaint = Paint()
        ..color = lineColor.withOpacity(0.45 * pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(lastPoint, dotRadius + (2.5 * pulseValue), haloPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AccuracyChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.currentData != currentData;
  }
}
