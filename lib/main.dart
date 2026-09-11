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

enum HardCodeQuestionType {
  multiChoiceSyntax,
  multiChoiceConceptual,
  trueFalse,
  matching,
  sequencing,
  sorting,
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _graphController;
  List<double> _prevAccuracyHistory = [];
  bool _isAccuracyUp = false;
  double _trendDelta = 0.0;

  final _languages = {};
  KnowledgeGraph? _knowledgeGraph;
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

  // Active question type tracking
  HardCodeQuestionType _currentQuestionType = HardCodeQuestionType.multiChoiceSyntax;
  HardCodeQuestionType? _lastQuestionType;
  int _questionTypeRotationIndex = 0;

  // Conceptual Multi-Choice
  String? _conceptualExplanation;

  // True-False State
  String _tfStatement = "";
  bool _tfExpected = true;
  String _tfExplanation = "";
  bool? _tfUserAnswer;
  bool _tfAnswered = false;

  // Matching State
  String _matchingPrompt = "";
  Map<String, String> _matchingPairs = {};
  List<String> _matchingLeftTerms = [];
  List<String> _matchingRightDefs = [];
  String? _selectedLeftTerm;
  String? _selectedRightDef;
  final Map<String, String> _userPairs = {};
  bool _matchingSubmitted = false;
  Map<String, bool> _matchingPairResults = {};

  // Sequencing State
  String _sequencingPrompt = "";
  List<String> _expectedSequence = [];
  List<String> _currentSequence = [];
  bool _sequencingSubmitted = false;
  List<bool> _sequenceStepResults = [];
  bool _sequenceOrderAdjusted = false;

  // Sorting-Classification State
  String _sortingPrompt = "";
  List<String> _sortingCategories = [];
  Map<String, List<String>> _sortingExpected = {};
  List<String> _sortingItems = [];
  final Map<String, String> _userClassification = {};
  bool _sortingSubmitted = false;
  Map<String, bool> _sortingResults = {};

  UserStats _userStats = DatabaseService.instance.getUserStats();
  bool _isLoading = true;

  Timer? _questionTimer;
  Timer? _advanceTimer;
  int _questionSessionId = 0;
  bool _isAnswerSubmitted = false;
  DateTime? _lastQuestionGenerationTime;
  int? _activeDraggingIndex;
  int _remainingSeconds = 20;
  static const int _totalSeconds = 20;
  static const int _maxTimerCap = 20;
  static const int _bonusSeconds = 3;
  int _currentTimerCap = 20;
  bool _isTimerExpired = false;

  bool _showBonusBadge = false;
  int _lastBonusSeconds = 3;
  final Map<String, int> _optionMoveCounts = {};
  Timer? _bonusBadgeTimer;

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

  void _addBonusTime([int seconds = _bonusSeconds]) {
    if (_isTimerExpired || _questionTimer == null) return;
    setState(() {
      _remainingSeconds = min(_remainingSeconds + seconds, _maxTimerCap);
      _currentTimerCap = _totalSeconds;
      _lastBonusSeconds = seconds;
      _showBonusBadge = true;
    });
    _bonusBadgeTimer?.cancel();
    _bonusBadgeTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showBonusBadge = false;
        });
      }
    });
  }

  void _addBonusTimeForOption(String optionKey) {
    if (_isTimerExpired || _questionTimer == null) return;
    final int count = _optionMoveCounts[optionKey] ?? 0;
    _optionMoveCounts[optionKey] = count + 1;

    int bonus = 0;
    if (count == 0) {
      bonus = 3;
    } else if (count == 1) {
      bonus = 2;
    } else if (count == 2) {
      bonus = 1;
    } else {
      bonus = 0;
    }

    if (bonus > 0) {
      setState(() {
        _remainingSeconds = min(_remainingSeconds + bonus, _maxTimerCap);
        _currentTimerCap = _totalSeconds;
        _lastBonusSeconds = bonus;
        _showBonusBadge = true;
      });
      _bonusBadgeTimer?.cancel();
      _bonusBadgeTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            _showBonusBadge = false;
          });
        }
      });
    }
  }

  void _startTimer() {
    _questionTimer?.cancel();
    _bonusBadgeTimer?.cancel();
    _showBonusBadge = false;
    _remainingSeconds = _totalSeconds;
    _currentTimerCap = _totalSeconds;
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
    _bonusBadgeTimer?.cancel();
    _bonusBadgeTimer = null;
    _cancelAdvance();
  }

  void _scheduleAdvance(int delayMs, int session) {
    if (session != _questionSessionId) return;
    _cancelAdvance();
    _advanceTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      if (session == _questionSessionId) {
        setState(() {
          generateQuestion();
        });
      }
    });
  }

  void _cancelAdvance() {
    _advanceTimer?.cancel();
    _advanceTimer = null;
  }

  void _handleTimeout() async {
    _cancelTimer();
    final int session = _questionSessionId;
    setState(() {
      _remainingSeconds = 0;
      _isTimerExpired = true;
      _isAnswerSubmitted = true;
      if (_currentQuestionType == HardCodeQuestionType.trueFalse) {
        _tfAnswered = true;
      } else if (_currentQuestionType == HardCodeQuestionType.matching) {
        _matchingSubmitted = true;
      } else if (_currentQuestionType == HardCodeQuestionType.sequencing) {
        _sequencingSubmitted = true;
      } else if (_currentQuestionType == HardCodeQuestionType.sorting) {
        _sortingSubmitted = true;
      }
    });

    final updatedStats = await DatabaseService.instance.recordAnswer(
      language: _language,
      isCorrect: false,
      timeRemainingSeconds: 0,
    );

    if (!mounted || session != _questionSessionId) return;
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
      message: "Time's up! Correct solution revealed below.",
      icon: Icons.timer_off_outlined,
      backgroundColor: Colors.red.shade800,
    );
  }

  Future<void> _recordAnswerResult({
    required bool isCorrect,
    String? successMsg,
    String? errorMsg,
    int? session,
  }) async {
    _cancelTimer();
    _topAlertTimer?.cancel();

    final updatedStats = await DatabaseService.instance.recordAnswer(
      language: _language,
      isCorrect: isCorrect,
      timeRemainingSeconds: _remainingSeconds,
    );

    if (!mounted) return;
    if (session != null && session != _questionSessionId) return;
    final double delta = (updatedStats.accuracyHistory.length >= 2)
        ? updatedStats.accuracyHistory.last -
            updatedStats.accuracyHistory[updatedStats.accuracyHistory.length - 2]
        : (updatedStats.recentAccuracy - _userStats.recentAccuracy);
    final bool accuracyWentUp = (delta >= -0.001);

    setState(() {
      _prevAccuracyHistory = List<double>.from(_userStats.accuracyHistory);
      _userStats = updatedStats;
      _isAccuracyUp = accuracyWentUp;
      _trendDelta = delta;
    });

    _graphController.forward(from: 0.0);
    if (accuracyWentUp) {
      _pulseController.forward(from: 0.0);
    }

    if (isCorrect) {
      _showTopAlert(
        message: successMsg ?? 'Correct! +15 XP',
        icon: Icons.check_circle_outline,
        backgroundColor: Colors.green.shade800,
      );
    } else {
      _showTopAlert(
        message: errorMsg ?? 'Incorrect choice. Review the feedback below!',
        icon: Icons.cancel,
        backgroundColor: Colors.redAccent.shade700,
      );
    }
  }

  Future<void> _loadData() async {
    final graph = await DatabaseService.instance.getOrSeedGraph();
    final data = graph;
    final stats = DatabaseService.instance.getUserStats();
    double initialTrend = 0.0;
    if (stats.accuracyHistory.length >= 2) {
      initialTrend = stats.accuracyHistory.last -
          stats.accuracyHistory[stats.accuracyHistory.length - 2];
    }
    if (!mounted) return;
    setState(() {
      _knowledgeGraph = graph;
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

  /// Dynamically resolves all bracketed choice patterns (e.g. `[a|b|None]`, `[$|@|None]`, `[String|str|string|None]`)
  /// by selecting one option at random and replacing "None" with empty string.
  static String resolveChoicePatterns(String input, [Random? rng]) =>
      PatternResolver.resolveChoicePatterns(input, rng);

  String renderPatternOptions(answer, pattern) {
    String render = (answer as String);
    final Random random = Random.secure();

    if (pattern is List) {
      for (final p in pattern) {
        if (p is String && render.contains(p)) {
          final List<String> options = p.substring(1, p.length - 1).split("|");
          final String option = options[random.nextInt(options.length)];
          if (option == "None") {
            render = render.replaceAll(p, "");
          } else {
            render = render.replaceAll(p, option);
          }
        }
      }
    }

    // Dynamically resolve any remaining bracketed choice expressions (e.g. [$|@|None], [String|str|string|None])
    render = resolveChoicePatterns(render, random);
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

    // Resolve any remaining choice patterns dynamically
    render = resolveChoicePatterns(render, random);
    return render.trim();
  }

  void generateQuestion({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastQuestionGenerationTime != null &&
        now.difference(_lastQuestionGenerationTime!).inMilliseconds < 500) {
      return;
    }
    _lastQuestionGenerationTime = now;

    _questionSessionId++;
    _cancelAdvance();
    _cancelTimer();
    _isAnswerSubmitted = false;
    _activeDraggingIndex = null;
    _topAlertTimer?.cancel();
    _topAlertMessage = null;
    _isTimerExpired = false;

    // Reset all question-specific states
    _answerGroup.clear();
    _choices.clear();
    _incorrectPatternGroups.clear();
    _incorrectPatternPriorities.clear();
    _choiceSelections.clear();
    _incorrectSelections.clear();
    _correctAnswerSelected = null;
    _conceptualExplanation = null;

    _tfUserAnswer = null;
    _tfAnswered = false;

    _selectedLeftTerm = null;
    _selectedRightDef = null;
    _userPairs.clear();
    _matchingSubmitted = false;
    _matchingPairs.clear();
    _matchingLeftTerms.clear();
    _matchingRightDefs.clear();
    _matchingPairResults.clear();

    _sequencingSubmitted = false;
    _sequenceStepResults.clear();
    _expectedSequence.clear();
    _currentSequence.clear();
    _sequenceOrderAdjusted = false;

    _sortingSubmitted = false;
    _sortingResults.clear();
    _userClassification.clear();
    _sortingCategories.clear();
    _sortingExpected.clear();
    _sortingItems.clear();
    _optionMoveCounts.clear();

    final Random random = Random.secure();

    // Guaranteed round-robin rotation across all question types:
    // 0: Multi-Choice Syntax (covering 9 programming subjects)
    // 1: True-False (covering 25 curriculum & programming domains)
    // 2: Matching (covering 25 curriculum & programming domains)
    // 3: Sequencing (covering 25 curriculum & programming domains)
    // 4: Sorting-Classification (covering 25 curriculum & programming domains)
    // 5: Multi-Choice Conceptual (covering 25 curriculum & programming domains)
    final List<HardCodeQuestionType> rotation = [
      HardCodeQuestionType.multiChoiceSyntax,
      HardCodeQuestionType.trueFalse,
      HardCodeQuestionType.matching,
      HardCodeQuestionType.sequencing,
      HardCodeQuestionType.sorting,
      HardCodeQuestionType.multiChoiceConceptual,
    ];

    _currentQuestionType = rotation[_questionTypeRotationIndex % rotation.length];
    _questionTypeRotationIndex++;
    _lastQuestionType = _currentQuestionType;

    final curriculum = (_data["Curriculum"] as Map?) ?? {};
    final List<String> domains = curriculum.keys.cast<String>().toList();

    switch (_currentQuestionType) {
      case HardCodeQuestionType.trueFalse:
        _generateTrueFalseQuestion(curriculum, domains, random);
        break;
      case HardCodeQuestionType.matching:
        _generateMatchingQuestion(curriculum, domains, random);
        break;
      case HardCodeQuestionType.sequencing:
        _generateSequencingQuestion(curriculum, domains, random);
        break;
      case HardCodeQuestionType.sorting:
        _generateSortingQuestion(curriculum, domains, random);
        break;
      case HardCodeQuestionType.multiChoiceConceptual:
        _generateConceptualMultiChoiceQuestion(curriculum, domains, random);
        break;
      case HardCodeQuestionType.multiChoiceSyntax:
        _generateSyntaxMultiChoiceQuestion(random);
        break;
    }

    _startTimer();
  }

  void _generateTrueFalseQuestion(Map curriculum, List<String> domains, Random random) {
    final validDomains = domains.where((d) {
      final qs = (curriculum[d] as Map?)?["questions"] as Map?;
      return (qs?["True-False"] as List?)?.isNotEmpty ?? false;
    }).toList();

    if (validDomains.isEmpty) {
      _language = "Computer Science";
      _questionSubType = "True / False";
      _tfStatement =
          "A pure function will always return the exact same result given the same arguments without observable side effects.";
      _tfExpected = true;
      _tfExplanation =
          "Pure functions have referential transparency, making them deterministic and thread-safe.";
      _question = _tfStatement;
      return;
    }

    final domain = validDomains[random.nextInt(validDomains.length)];
    final tfList = curriculum[domain]["questions"]["True-False"] as List;
    final item = tfList[random.nextInt(tfList.length)] as Map;

    _language = domain;
    _questionSubType = "True / False";
    _tfStatement = (item["statement"] as String?) ?? "";
    _tfExpected = (item["is_true"] as bool?) ?? true;
    _tfExplanation = (item["explanation"] as String?) ?? "";
    _question = _tfStatement;
  }

  void _generateMatchingQuestion(Map curriculum, List<String> domains, Random random) {
    final validDomains = domains.where((d) {
      final qs = (curriculum[d] as Map?)?["questions"] as Map?;
      return (qs?["Matching"] as List?)?.isNotEmpty ?? false;
    }).toList();

    if (validDomains.isEmpty) {
      _language = "Data Structures";
      _questionSubType = "Matching";
      _matchingPrompt = "Match each data structure with its defining operational behavior:";
      _question = _matchingPrompt;
      _matchingPairs = {
        "Stack": "LIFO (Last-In First-Out) with push and pop at top",
        "Queue": "FIFO (First-In First-Out) with enqueue back, dequeue front",
        "HashMap": "O(1) average key-value lookup via hashing",
        "Set": "Collection of unique elements preventing duplicate values",
      };
      _matchingLeftTerms = _matchingPairs.keys.toList()..shuffle(random);
      _matchingRightDefs = _matchingPairs.values.toList()..shuffle(random);
      return;
    }

    final domain = validDomains[random.nextInt(validDomains.length)];
    final mList = curriculum[domain]["questions"]["Matching"] as List;
    final item = mList[random.nextInt(mList.length)] as Map;

    _language = domain;
    _questionSubType = "Matching";
    _matchingPrompt = (item["prompt"] as String?) ?? "Match corresponding pairs:";
    _question = _matchingPrompt;

    final rawPairs = (item["pairs"] as Map?) ?? {};
    rawPairs.forEach((k, v) {
      _matchingPairs[k.toString()] = v.toString();
    });

    _matchingLeftTerms = _matchingPairs.keys.toList()..shuffle(random);
    _matchingRightDefs = _matchingPairs.values.toList()..shuffle(random);
  }

  void _generateSequencingQuestion(Map curriculum, List<String> domains, Random random) {
    final validDomains = domains.where((d) {
      final qs = (curriculum[d] as Map?)?["questions"] as Map?;
      return (qs?["Sequencing"] as List?)?.isNotEmpty ?? false;
    }).toList();

    if (validDomains.isEmpty) {
      _language = "Compilers";
      _questionSubType = "Sequencing";
      _sequencingPrompt = "Order the standard phases of code compilation from source to machine binary:";
      _question = _sequencingPrompt;
      _expectedSequence = [
        "Lexical Analysis (Tokenization)",
        "Syntactic Analysis (Parsing into AST)",
        "Semantic Analysis (Type Checking)",
        "Intermediate Code Generation (IR)",
        "Target Machine Code Generation",
      ];
      _currentSequence = List<String>.from(_expectedSequence)..shuffle(random);
      _sequenceOrderAdjusted = false;
      return;
    }

    final domain = validDomains[random.nextInt(validDomains.length)];
    final sList = curriculum[domain]["questions"]["Sequencing"] as List;
    final item = sList[random.nextInt(sList.length)] as Map;

    _language = domain;
    _questionSubType = "Sequencing";
    _sequencingPrompt = (item["prompt"] as String?) ?? "Arrange in correct order:";
    _question = _sequencingPrompt;

    final rawSeq = (item["ordered_sequence"] as List?) ?? [];
    _expectedSequence = rawSeq.map((e) => e.toString()).toList();
    _currentSequence = List<String>.from(_expectedSequence);

    int attempts = 0;
    while (_expectedSequence.length > 1 &&
        _currentSequence.join(';;') == _expectedSequence.join(';;') &&
        attempts < 20) {
      _currentSequence.shuffle(random);
      attempts++;
    }
    _sequenceOrderAdjusted = false;
  }

  void _generateSortingQuestion(Map curriculum, List<String> domains, Random random) {
    final validDomains = domains.where((d) {
      final qs = (curriculum[d] as Map?)?["questions"] as Map?;
      return (qs?["Sorting-Classification"] as List?)?.isNotEmpty ?? false;
    }).toList();

    if (validDomains.isEmpty) {
      _language = "Algorithms";
      _questionSubType = "Classification";
      _sortingPrompt = "Classify each algorithm by its average-case time complexity:";
      _question = _sortingPrompt;
      _sortingCategories = ["O(N log N)", "O(N^2)", "O(N)"];
      _sortingExpected = {
        "O(N log N)": ["Merge Sort", "Quick Sort", "Heap Sort"],
        "O(N^2)": ["Bubble Sort", "Insertion Sort"],
        "O(N)": ["Counting Sort"],
      };
      _sortingItems = [
        "Merge Sort",
        "Quick Sort",
        "Heap Sort",
        "Bubble Sort",
        "Insertion Sort",
        "Counting Sort",
      ]..shuffle(random);
      return;
    }

    final domain = validDomains[random.nextInt(validDomains.length)];
    final scList = curriculum[domain]["questions"]["Sorting-Classification"] as List;
    final item = scList[random.nextInt(scList.length)] as Map;

    _language = domain;
    _questionSubType = "Classification";
    _sortingPrompt = (item["prompt"] as String?) ?? "Classify the items:";
    _question = _sortingPrompt;

    _sortingCategories = ((item["categories"] as List?) ?? [])
        .map((e) => e.toString())
        .toList();

    _sortingExpected.clear();
    final rawItems = (item["items"] as Map?) ?? {};
    rawItems.forEach((k, v) {
      _sortingExpected[k.toString()] =
          ((v as List?) ?? []).map((e) => e.toString()).toList();
    });

    _sortingItems.clear();
    for (var list in _sortingExpected.values) {
      _sortingItems.addAll(list);
    }
    _sortingItems.shuffle(random);
  }

  void _generateConceptualMultiChoiceQuestion(Map curriculum, List<String> domains, Random random) {
    final validDomains = domains.where((d) {
      final qs = (curriculum[d] as Map?)?["questions"] as Map?;
      return (qs?["Multi-Choice"] as List?)?.isNotEmpty ?? false;
    }).toList();

    if (validDomains.isEmpty) {
      _language = "Computer Science";
      _questionSubType = "Multi-Choice";
      _question =
          "Which computational complexity class contains decision problems solvable by a deterministic Turing machine in polynomial time?";
      _conceptualExplanation =
          "Class P represents problems solvable in O(N^k) polynomial time on a deterministic machine.";
      _correctAnswer = "P";
      _choices.clear();
      _choices.add(["P", 1]);
      _choices.add(["NP", 0]);
      _choices.add(["NP-Complete", 0]);
      _choices.add(["PSPACE", 0]);
      _choices.shuffle(random);
      _answerGroup.clear();
      for (final c in _choices) {
        _answerGroup.add(c[0] as String);
      }
      return;
    }

    final domain = validDomains[random.nextInt(validDomains.length)];
    final mcList = curriculum[domain]["questions"]["Multi-Choice"] as List;
    final item = mcList[random.nextInt(mcList.length)] as Map;

    _language = domain;
    _questionSubType = "Multi-Choice";
    _question = (item["question"] as String?) ?? "";
    _conceptualExplanation = (item["explanation"] as String?) ?? "";

    final rawChoices = ((item["choices"] as List?) ?? []).map((e) => e.toString()).toList();
    final int correctIdx = (item["correct_index"] as int?) ?? 0;
    final String correctChoice = (correctIdx >= 0 && correctIdx < rawChoices.length)
        ? rawChoices[correctIdx]
        : (rawChoices.isNotEmpty ? rawChoices.first : "");
    _correctAnswer = correctChoice;

    _choices.clear();
    for (final ch in rawChoices) {
      _choices.add([ch, ch == correctChoice ? 1 : 0]);
    }
    _choices.shuffle(random);

    _answerGroup.clear();
    for (final c in _choices) {
      _answerGroup.add(c[0] as String);
    }
  }

  static final List<Map<String, dynamic>> _diverseSyntaxQuestions = [
    // Functions
    {
      "language": "Python",
      "subType": "Function Definition",
      "question": "How do you define a function 'compute' with parameters x and y in Python?",
      "correct": "def compute(x, y):",
      "distractors": [
        "func compute(x int, y int) int {",
        "function compute(x, y) {",
        "fn compute(x: i32, y: i32) -> i32 {",
        "int compute(int x, int y) {",
      ],
    },
    {
      "language": "Go",
      "subType": "Function Definition",
      "question": "How do you declare a function returning (int, error) in Go?",
      "correct": "func calculate(val int) (int, error) {",
      "distractors": [
        "def calculate(val: int) -> (int, Exception):",
        "function calculate(val: number): [number, Error] {",
        "fn calculate(val: i32) -> Result<i32, Error> {",
        "int calculate(int val) throws Exception {",
      ],
    },
    {
      "language": "Rust",
      "subType": "Function Definition",
      "question": "How do you declare a public function taking an i32 and returning a bool in Rust?",
      "correct": "pub fn is_valid(num: i32) -> bool {",
      "distractors": [
        "public boolean isValid(int num) {",
        "def is_valid(num: int) -> bool:",
        "func isValid(num int) bool {",
        "export function isValid(num: number): boolean {",
      ],
    },
    {
      "language": "TypeScript",
      "subType": "Arrow Function",
      "question": "How do you declare an arrow function with typed parameters in TypeScript?",
      "correct": "const add = (a: number, b: number): number => a + b;",
      "distractors": [
        "def add = lambda a: int, b: int: a + b",
        "func add = (a int, b int) int => a + b",
        "fn add = (a: i32, b: i32) => a + b;",
        "int add = (int a, int b) -> a + b;",
      ],
    },

    // Loops & Iteration
    {
      "language": "Python",
      "subType": "For Loop",
      "question": "How do you write a for loop iterating through numbers 0 to 9 in Python?",
      "correct": "for i in range(10):",
      "distractors": [
        "for (let i = 0; i < 10; i++) {",
        "for i := 0; i < 10; i++ {",
        "for i in 0..10 {",
        "10.times do |i|",
      ],
    },
    {
      "language": "Go",
      "subType": "Iteration",
      "question": "How do you iterate over index and value of a slice in Go?",
      "correct": "for idx, val := range items {",
      "distractors": [
        "for (const [idx, val] of items.entries()) {",
        "for idx, val in enumerate(items):",
        "for (int idx = 0; idx < items.length; idx++) {",
        "items.forEach((val, idx) => {",
      ],
    },
    {
      "language": "Rust",
      "subType": "Loop",
      "question": "How do you write an infinite loop in Rust?",
      "correct": "loop { ... }",
      "distractors": [
        "while true { ... }",
        "for (;;) { ... }",
        "while (1) { ... }",
        "repeat { ... } until false",
      ],
    },

    // Control Flow
    {
      "language": "Python",
      "subType": "Conditionals",
      "question": "How do you write an If-Else conditional ladder in Python?",
      "correct": "if score >= 90:\n    grade = 'A'\nelif score >= 80:\n    grade = 'B'\nelse:\n    grade = 'C'",
      "distractors": [
        "if (score >= 90) { grade = 'A'; } else if (score >= 80) { grade = 'B'; } else { grade = 'C'; }",
        "if score >= 90 then grade = 'A' elsif score >= 80 grade = 'B' else grade = 'C' end",
        "if [ \$score -ge 90 ]; then grade='A'; elif [ \$score -ge 80 ]; then grade='B'; else grade='C'; fi",
        "switch (score) { case >= 90: grade = 'A'; break; }",
      ],
    },
    {
      "language": "Rust",
      "subType": "Pattern Matching",
      "question": "How do you match an Option<T> enum variant in Rust?",
      "correct": "match opt {\n    Some(val) => println!(\"{}\", val),\n    None => println!(\"empty\"),\n}",
      "distractors": [
        "switch (opt) { case Some(val): ...; case None: ...; }",
        "if opt != null { println(opt.val); } else { ... }",
        "select { case val := <-opt: ... }",
        "guard let val = opt else { ... }",
      ],
    },
    {
      "language": "Dart",
      "subType": "Null Coalescing",
      "question": "How do you provide a fallback default value for a nullable variable in Dart?",
      "correct": "final name = inputName ?? 'Guest';",
      "distractors": [
        "final name = inputName || 'Guest';",
        "final name = inputName ?: 'Guest';",
        "final name = if inputName != null then inputName else 'Guest';",
        "final name = inputName.unwrap_or('Guest');",
      ],
    },

    // Classes & OOP
    {
      "language": "Java",
      "subType": "Class Inheritance",
      "question": "How do you declare class 'Student' inheriting from 'Person' and implementing 'Learner' in Java?",
      "correct": "public class Student extends Person implements Learner {",
      "distractors": [
        "public class Student : Person, Learner {",
        "class Student(Person, Learner):",
        "class Student < Person; include Learner; end",
        "struct Student : public Person, public Learner {",
      ],
    },
    {
      "language": "Python",
      "subType": "Constructor",
      "question": "How do you define the constructor initializer in a Python class?",
      "correct": "def __init__(self, name: str, age: int):",
      "distractors": [
        "def constructor(name, age):",
        "def Person(self, name, age):",
        "def new(cls, name, age):",
        "init(name: String, age: Int)",
      ],
    },
    {
      "language": "TypeScript",
      "subType": "Class Declaration",
      "question": "How do you declare a class with a private property in modern TypeScript?",
      "correct": "class Account {\n  private balance: number;\n}",
      "distractors": [
        "class Account {\n  var balance: number = private;\n}",
        "class Account {\n  def __init__(self): self.__balance = 0\n}",
        "class Account {\n  private: int balance;\n}",
        "type Account struct {\n  balance int\n}",
      ],
    },

    // Collections
    {
      "language": "Python",
      "subType": "List Comprehension",
      "question": "How do you filter and square odd numbers from a list in Python?",
      "correct": "[x**2 for x in nums if x % 2 != 0]",
      "distractors": [
        "nums.filter(x => x % 2 !== 0).map(x => x ** 2)",
        "nums.select { |x| x**2 if x.odd? }",
        "from x in nums where x % 2 != 0 select x * x",
        "filter(lambda x: x % 2 != 0, nums).map(x**2)",
      ],
    },
    {
      "language": "Go",
      "subType": "Map Creation",
      "question": "How do you initialize a map with string keys and int values in Go?",
      "correct": "scores := make(map[string]int)",
      "distractors": [
        "scores = new Map<string, int>()",
        "scores = dict()",
        "var scores: Map[String, Int] = Map()",
        "let scores: HashMap<String, i32> = HashMap::new();",
      ],
    },
    {
      "language": "Rust",
      "subType": "Vectors",
      "question": "How do you create a mutable vector with initial elements in Rust?",
      "correct": "let mut items: Vec<i32> = vec![10, 20, 30];",
      "distractors": [
        "let items = new Vector<i32>(10, 20, 30);",
        "var items = [10, 20, 30];",
        "let mut items: [i32; 3] = [10, 20, 30];",
        "items := []int{10, 20, 30}",
      ],
    },

    // Error Handling
    {
      "language": "Python",
      "subType": "Exception Handling",
      "question": "How do you handle a ValueError and ensure cleanup in Python?",
      "correct": "try:\n    parse(data)\nexcept ValueError as e:\n    handle(e)\nfinally:\n    cleanup()",
      "distractors": [
        "try { parse(data); } catch (ValueError e) { handle(e); } finally { cleanup(); }",
        "try { parse(data); } catch (e) { handle(e); } ensure { cleanup(); }",
        "begin parse(data) rescue ValueError => e handle(e) ensure cleanup() end",
        "parse(data).catch(e => handle(e)).finally(() => cleanup());",
      ],
    },
    {
      "language": "Go",
      "subType": "Error Handling",
      "question": "How do you return a custom formatted error in Go?",
      "correct": "return fmt.Errorf(\"operation failed for id %d: %w\", id, err)",
      "distractors": [
        "throw new Error(`operation failed for id \${id}`)",
        "raise Exception(f\"operation failed for id {id}\")",
        "return Err(format!(\"operation failed for id {}\", id))",
        "panic(\"operation failed\")",
      ],
    },
    {
      "language": "Rust",
      "subType": "Error Propagation",
      "question": "How do you propagate a Result error using the standard operator in Rust?",
      "correct": "let bytes = file.read_to_end(&mut buffer)?;",
      "distractors": [
        "let bytes = try!(file.read_to_end(&mut buffer));",
        "let bytes = file.read_to_end(&mut buffer).unwrap();",
        "let bytes = file.read_to_end(&mut buffer).throw();",
        "let bytes = await file.read_to_end(&mut buffer);",
      ],
    },

    // Async / Concurrency
    {
      "language": "JavaScript",
      "subType": "Async / Await",
      "question": "How do you declare an async function and await an API call in JavaScript?",
      "correct": "async function getData() {\n  const res = await fetch(url);\n  return res.json();\n}",
      "distractors": [
        "function async getData() {\n  const res = wait fetch(url);\n  return res.json();\n}",
        "def async getData():\n  res = await fetch(url)\n  return res.json()",
        "task getData() {\n  const res = await fetch(url);\n  return res.json();\n}",
        "function getData() async {\n  const res = await fetch(url);\n  return res.json();\n}",
      ],
    },
    {
      "language": "Go",
      "subType": "Goroutines",
      "question": "How do you spawn an anonymous function concurrently in Go?",
      "correct": "go func() {\n    processItem(item)\n}()",
      "distractors": [
        "spawn async () => {\n    processItem(item)\n}",
        "new Thread(() -> processItem(item)).start();",
        "asyncio.create_task(processItem(item))",
        "thread::spawn(move || processItem(item));",
      ],
    },
    {
      "language": "Dart",
      "subType": "Async Functions",
      "question": "How do you declare a function returning a Future in Dart?",
      "correct": "Future<String> fetchUser() async {\n  return await api.getUser();\n}",
      "distractors": [
        "async String fetchUser() {\n  return await api.getUser();\n}",
        "Promise<String> fetchUser() async {\n  return await api.getUser();\n}",
        "async Task<string> fetchUser() {\n  return await api.getUser();\n}",
        "String async fetchUser() {\n  return await api.getUser();\n}",
      ],
    },

    // Strings
    {
      "language": "Python",
      "subType": "String Formatting",
      "question": "How do you format an f-string expression with uppercase conversion in Python?",
      "correct": "f\"Welcome, {username.upper()}!\"",
      "distractors": [
        "`Welcome, \${username.upper()}!`",
        "\"Welcome, %{username.upper()}!\"",
        "\$\"Welcome, {username.ToUpper()}!\"",
        "'Welcome, \${username.upper()}!'",
      ],
    },
    {
      "language": "C#",
      "subType": "String Interpolation",
      "question": "How do you format an interpolated string with date formatting in C#?",
      "correct": "\$\"Current Date: {DateTime.Now:yyyy-MM-dd}\"",
      "distractors": [
        "@\"Current Date: {DateTime.Now:yyyy-MM-dd}\"",
        "f\"Current Date: {DateTime.Now:yyyy-MM-dd}\"",
        "`Current Date: \${DateTime.Now:yyyy-MM-dd}`",
        "\"Current Date: \" + DateTime.Now.Format(\"yyyy-MM-dd\")",
      ],
    },
    {
      "language": "Dart",
      "subType": "String Interpolation",
      "question": "How do you evaluate an expression inside a string literal in Dart?",
      "correct": "'Total items: \${items.length}'",
      "distractors": [
        "'Total items: \$items.length'",
        "'Total items: {items.length}'",
        "'Total items: #{items.length}'",
        "'Total items: %items.length%'",
      ],
    },
  ];

  void _generateDiverseSyntaxQuestion(Random random) {
    final item = _diverseSyntaxQuestions[random.nextInt(_diverseSyntaxQuestions.length)];
    _language = item["language"] as String;
    _questionSubType = item["subType"] as String;
    _question = item["question"] as String;
    _correctAnswer = item["correct"] as String;
    _conceptualExplanation = null;

    _choices.clear();
    _choices.add([_correctAnswer, 1]);

    final List<String> distractors = List<String>.from(item["distractors"] as List);
    distractors.shuffle(random);
    for (final d in distractors.take(3)) {
      _choices.add([d, 0]);
    }
    _choices.shuffle(random);

    _answerGroup.clear();
    for (final c in _choices) {
      _answerGroup.add(c[0] as String);
    }
  }

  void _generateVariableSyntaxQuestion(Random random) {
    final categories = DatabaseService.instance
        .getAvailableCategoriesForLevel(_userStats.level);
    _currentCategory = categories[random.nextInt(categories.length)];

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
      while (_choices.length < 4 && attempts < 50) {
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
  }

  void _generateSyntaxMultiChoiceQuestion(Random random) {
    final bool hasVarData = _data.containsKey("Variables") &&
        _data["Variables"] is Map &&
        _data["Variables"]["Declaration"] is Map &&
        _langList.isNotEmpty;

    // 25% chance for variable assignment pattern engine if available, 75% for diverse programming subjects
    if (hasVarData && random.nextInt(4) == 0) {
      _generateVariableSyntaxQuestion(random);
    } else {
      _generateDiverseSyntaxQuestion(random);
    }
  }

  void _handleTrueFalseAnswer(bool answer) async {
    if (_tfAnswered || _isTimerExpired || _isAnswerSubmitted) return;

    final int session = _questionSessionId;
    setState(() {
      _tfUserAnswer = answer;
      _tfAnswered = true;
      _isAnswerSubmitted = true;
    });
    _cancelTimer();

    final bool isCorrect = (answer == _tfExpected);
    await _recordAnswerResult(
      isCorrect: isCorrect,
      successMsg: 'Correct statement evaluation! +15 XP',
      errorMsg: 'Incorrect statement evaluation. Review explanation below!',
      session: session,
    );

    if (!mounted || session != _questionSessionId) return;

    if (isCorrect) {
      _scheduleAdvance(5000, session);
    }
  }

  void _pairTermWithDef(String targetTerm, String def) {
    if (_matchingSubmitted || _isTimerExpired) return;
    if (def.isEmpty) {
      setState(() {
        _userPairs.remove(targetTerm);
        _selectedLeftTerm = null;
        _selectedRightDef = null;
      });
      return;
    }

    final String? previousTargetDef = _userPairs[targetTerm];
    if (previousTargetDef == def) return;

    // Check if `def` was currently assigned to another term
    String? sourceTerm;
    for (final entry in _userPairs.entries) {
      if (entry.value == def && entry.key != targetTerm) {
        sourceTerm = entry.key;
        break;
      }
    }

    setState(() {
      if (sourceTerm != null) {
        // def was dragged from another answer!
        if (previousTargetDef != null) {
          // SWAP: sourceTerm gets targetTerm's previous definition
          _userPairs[sourceTerm] = previousTargetDef;
        } else {
          // sourceTerm loses def and becomes unassigned
          _userPairs.remove(sourceTerm);
        }
      }

      _userPairs[targetTerm] = def;
      _selectedLeftTerm = null;
      _selectedRightDef = null;
    });

    _addBonusTimeForOption(def);
  }

  void _handleMatchingSubmit() async {
    if (_matchingSubmitted || _isTimerExpired || _isAnswerSubmitted) return;

    final int session = _questionSessionId;
    final bool allPairsMapped = _userPairs.length == _matchingPairs.length;
    bool allCorrect = allPairsMapped;
    final Map<String, bool> results = {};

    for (final entry in _matchingPairs.entries) {
      final userMatch = _userPairs[entry.key];
      final bool isMatch = (userMatch != null && userMatch == entry.value);
      results[entry.key] = isMatch;
      if (!isMatch) {
        allCorrect = false;
      }
    }

    setState(() {
      _matchingSubmitted = true;
      _isAnswerSubmitted = true;
      _matchingPairResults = results;
    });
    _cancelTimer();

    await _recordAnswerResult(
      isCorrect: allCorrect,
      successMsg: 'All concepts matched correctly! +20 XP',
      errorMsg: 'Some pairings were incorrect. Review canonical pairs below.',
      session: session,
    );

    if (!mounted || session != _questionSessionId) return;

    if (allCorrect) {
      _scheduleAdvance(5000, session);
    }
  }

  void _handleSequencingSubmit() async {
    if (_sequencingSubmitted || _isTimerExpired || _isAnswerSubmitted) return;

    final int session = _questionSessionId;
    bool allCorrect = true;
    final List<bool> results = [];

    for (int i = 0; i < _currentSequence.length; i++) {
      final bool isStepCorrect = (i < _expectedSequence.length &&
          _currentSequence[i] == _expectedSequence[i]);
      results.add(isStepCorrect);
      if (!isStepCorrect) {
        allCorrect = false;
      }
    }

    setState(() {
      _sequencingSubmitted = true;
      _isAnswerSubmitted = true;
      _sequenceStepResults = results;
    });
    _cancelTimer();

    await _recordAnswerResult(
      isCorrect: allCorrect,
      successMsg: 'Sequence verified in correct order! +20 XP',
      errorMsg: 'Sequence was out of order. See canonical order below.',
      session: session,
    );

    if (!mounted || session != _questionSessionId) return;

    if (allCorrect) {
      _scheduleAdvance(5000, session);
    }
  }

  void _handleSortingSubmit() async {
    if (_sortingSubmitted || _isTimerExpired || _isAnswerSubmitted) return;

    final int session = _questionSessionId;
    bool allCorrect = true;
    final Map<String, bool> results = {};

    for (final item in _sortingItems) {
      final assigned = _userClassification[item];
      final bool isMatch = (assigned != null &&
          (_sortingExpected[assigned]?.contains(item) ?? false));
      results[item] = isMatch;
      if (!isMatch) {
        allCorrect = false;
      }
    }

    setState(() {
      _sortingSubmitted = true;
      _isAnswerSubmitted = true;
      _sortingResults = results;
    });
    _cancelTimer();

    await _recordAnswerResult(
      isCorrect: allCorrect,
      successMsg: 'All items classified correctly! +20 XP',
      errorMsg: 'Some classifications were incorrect.',
      session: session,
    );

    if (!mounted || session != _questionSessionId) return;

    _scheduleAdvance(5000, session);
  }

  String _getExpectedCategoryForItem(String item) {
    for (final entry in _sortingExpected.entries) {
      if (entry.value.contains(item)) {
        return entry.key;
      }
    }
    return '';
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

  Widget _buildHeaderTimer({
    required Color timerColor,
    required ThemeData theme,
    double maxWidth = 300,
  }) {
    return Container(
      constraints: BoxConstraints(minWidth: 170, maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: timerColor.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: timerColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isTimerExpired ? "Time's up!" : 'Time Remaining',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: timerColor,
                    ),
                  ),
                  if (_showBonusBadge) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+${_lastBonusSeconds}s',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Text(
                '${_remainingSeconds}s',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: timerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (_remainingSeconds / _currentTimerCap.toDouble())
                  .clamp(0.0, 1.0),
              minHeight: 3.5,
              backgroundColor: timerColor.withOpacity(0.16),
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSparkline(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AccuracySparkline(
            currentData: _userStats.accuracyHistory,
            previousData: _prevAccuracyHistory,
            graphAnimation: _graphController,
            pulseAnimation: _pulseAnimation,
            isAccuracyUp: _isAccuracyUp,
            trendDelta: _trendDelta,
            width: 50,
            height: 16,
            theme: theme,
          ),
          const SizedBox(height: 2),
          Text(
            'Recent',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderLevelBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.15),
          width: 0.8,
        ),
      ),
      child: Text(
        'Lvl ${_userStats.level}',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Timer color shift
    Color timerColor = Colors.green.shade600;
    if (_remainingSeconds <= 5) {
      timerColor = Colors.redAccent.shade700;
    } else if (_remainingSeconds <= 10) {
      timerColor = Colors.orange.shade700;
    }

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
        toolbarHeight: 64,
        backgroundColor: theme.colorScheme.inversePrimary,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Open Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;

            // Compact layout for narrow mobile screens (< 560px)
            if (availableWidth < 560) {
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Row(
                  children: [
                    Text(
                      'HardCode',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHeaderTimer(
                        timerColor: timerColor,
                        theme: theme,
                        maxWidth: 220,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderLevelBadge(theme),
                  ],
                ),
              );
            }

            // Medium layout for tablets / medium windows (560px - 800px)
            if (availableWidth < 800) {
              return Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: Row(
                  children: [
                    Text(
                      widget.title.isNotEmpty
                          ? widget.title
                          : 'HardCode Academy',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.5,
                      ),
                    ),
                    if (_language.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline
                                .withOpacity(0.18),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _language,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    _buildHeaderTimer(
                      timerColor: timerColor,
                      theme: theme,
                      maxWidth: 240,
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderLevelBadge(theme),
                  ],
                ),
              );
            }

            // Full desktop layout matching the mockup screenshot
            return Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
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
                        color: theme.colorScheme.primaryContainer
                            .withOpacity(0.85),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.outline
                              .withOpacity(0.18),
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
                  _buildHeaderTimer(
                    timerColor: timerColor,
                    theme: theme,
                    maxWidth: 320,
                  ),
                  const SizedBox(width: 10),
                  _buildHeaderSparkline(theme),
                  const SizedBox(width: 10),
                  _buildHeaderLevelBadge(theme),
                ],
              ),
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
            // Quick Stats Card (Streak, Best, Accuracy)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.16),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 3),
                            Text(
                              '${_userStats.currentStreak}',
                              style: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Streak',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 22,
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 3),
                            Text(
                              '${_userStats.bestStreak}',
                              style: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Best',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 22,
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🎯', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 3),
                            Text(
                              '${_userStats.accuracy.toStringAsFixed(0)}%',
                              style: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Accuracy',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
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
            ListTile(
              leading: const Icon(Icons.hub_outlined, color: Colors.indigo),
              title: const Text('Knowledge Graph Explorer'),
              subtitle: Text(
                _knowledgeGraph != null
                    ? '${_knowledgeGraph!.nodes.length} Vertices • ${_knowledgeGraph!.edges.length} Edges'
                    : 'Interactive Graph Data Structure',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.of(context).pop();
                _showKnowledgeGraphModal();
              },
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
          final double hScale = (availableWidth / 720.0).clamp(0.70, 1.25);
          final double vScale = (availableHeight / 750.0).clamp(0.70, 1.20);
          final double scale = min(hScale, vScale);

          // Responsive card width calculation that smoothly scales across:
          // - Mobile (< 600px): 94% width (280px - 540px)
          // - Tablet / Small Desktop (600px - 960px): 540px - 760px
          // - Standard Desktop (960px - 1600px): 760px - 1100px
          // - Ultrawide / 4K (> 1600px): 1100px - 1250px max
          final double cardWidth;
          if (availableWidth < 600) {
            cardWidth = (availableWidth * 0.94).clamp(280.0, 540.0);
          } else if (availableWidth < 960) {
            final double t = (availableWidth - 600) / (960 - 600);
            cardWidth = 540.0 + t * (760.0 - 540.0);
          } else if (availableWidth < 1600) {
            final double t = (availableWidth - 960) / (1600 - 960);
            cardWidth = 760.0 + t * (1100.0 - 760.0);
          } else {
            final double t = ((availableWidth - 1600) / 1200).clamp(0.0, 1.0);
            cardWidth = 1100.0 + t * (1250.0 - 1100.0);
          }

          final double questionFontSize = (22.0 * scale).clamp(15.0, 26.0);
          final double buttonFontSize = (18.5 * scale).clamp(13.5, 22.0);
          final double buttonVerticalPadding =
              (16.0 * scale).clamp(10.0, 20.0);
          final double buttonHorizontalPadding =
              (22.0 * scale).clamp(14.0, 28.0);
          final double buttonVerticalMargin =
              (6.0 * scale).clamp(3.0, 8.0);
          final double contentSpacing =
              (20.0 * scale).clamp(12.0, 28.0);
          final double statFontSize = (13.0 * scale).clamp(10.5, 15.5);

          return Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) {
                    if (_advanceTimer != null) {
                      _cancelAdvance();
                    }
                  },
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: (20.0 * scale).clamp(10.0, 32.0),
                        vertical: (24.0 * scale).clamp(16.0, 40.0),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: cardWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Dynamic Question Type UI Rendering
                      if (_currentQuestionType == HardCodeQuestionType.multiChoiceSyntax ||
                          _currentQuestionType == HardCodeQuestionType.multiChoiceConceptual) ...[
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
                              onPressed: (isDisabled || _isAnswerSubmitted)
                                  ? null
                                  : () async {
                                      final int session = _questionSessionId;
                                      int answer = _choices[
                                          _answerGroup.indexOf(answerButton)][1];
                                      final isCorrect = (answer == 1);

                                      setState(() {
                                        _isAnswerSubmitted = true;
                                        if (isCorrect) {
                                          _correctAnswerSelected = answerButton;
                                        } else {
                                          _incorrectSelections.add(answerButton);
                                        }
                                      });

                                      await _recordAnswerResult(
                                        isCorrect: isCorrect,
                                        successMsg: isCorrect ? 'Correct choice! +15 XP' : null,
                                        errorMsg: isCorrect ? null : 'Incorrect choice. Try another option!',
                                        session: session,
                                      );

                                      if (!mounted || session != _questionSessionId) return;

                                      if (isCorrect) {
                                        _scheduleAdvance(5000, session);
                                      } else {
                                        setState(() {
                                          _isAnswerSubmitted = false;
                                        });
                                      }
                                    },
                            );
                          }).toList(),
                        ),
                        if (_conceptualExplanation != null &&
                            (_correctAnswerSelected != null || _isTimerExpired)) ...[
                          SizedBox(height: (16.0 * scale).clamp(10.0, 20.0)),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_outline_rounded,
                                    size: 18, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _conceptualExplanation!,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: (statFontSize * 0.9).clamp(11.0, 13.5),
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_isTimerExpired || _correctAnswerSelected != null) ...[
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
                      ] else if (_currentQuestionType == HardCodeQuestionType.trueFalse) ...[
                        _buildTrueFalseUI(scale, theme, buttonFontSize, statFontSize),
                      ] else if (_currentQuestionType == HardCodeQuestionType.matching) ...[
                        _buildMatchingUI(scale, theme, buttonFontSize, statFontSize, cardWidth),
                      ] else if (_currentQuestionType == HardCodeQuestionType.sequencing) ...[
                        _buildSequencingUI(scale, theme, buttonFontSize, statFontSize, cardWidth),
                      ] else if (_currentQuestionType == HardCodeQuestionType.sorting) ...[
                        _buildSortingUI(scale, theme, buttonFontSize, statFontSize),
                      ],
                    ],
                  ),
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
                      constraints: BoxConstraints(
                        maxWidth: (cardWidth * 0.85).clamp(420.0, 720.0),
                      ),
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

  Widget _buildTrueFalseUI(
    double scale,
    ThemeData theme,
    double buttonFontSize,
    double statFontSize,
  ) {
    final bool isCompleted = _tfAnswered || _isTimerExpired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all((16.0 * scale).clamp(12.0, 20.0)),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.18),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    size: (18.0 * scale).clamp(14.0, 20.0),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Is the following statement True or False?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: (statFontSize * 0.95).clamp(11.0, 14.0),
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: (12.0 * scale).clamp(8.0, 16.0)),
              Text(
                _tfStatement,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: (20.0 * scale).clamp(14.0, 23.0),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: (20.0 * scale).clamp(14.0, 24.0)),
        Row(
          children: [
            Expanded(
              child: _buildTrueFalseOptionButton(
                isTrueOption: true,
                scale: scale,
                theme: theme,
                fontSize: buttonFontSize,
              ),
            ),
            SizedBox(width: (12.0 * scale).clamp(8.0, 16.0)),
            Expanded(
              child: _buildTrueFalseOptionButton(
                isTrueOption: false,
                scale: scale,
                theme: theme,
                fontSize: buttonFontSize,
              ),
            ),
          ],
        ),
        if (isCompleted && _tfExplanation.isNotEmpty) ...[
          SizedBox(height: (18.0 * scale).clamp(12.0, 22.0)),
          Container(
            padding: EdgeInsets.all((14.0 * scale).clamp(10.0, 16.0)),
            decoration: BoxDecoration(
              color: (_tfUserAnswer == _tfExpected)
                  ? Colors.green.withOpacity(0.08)
                  : Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (_tfUserAnswer == _tfExpected)
                    ? Colors.green.withOpacity(0.35)
                    : Colors.red.withOpacity(0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  (_tfUserAnswer == _tfExpected)
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 20,
                  color: (_tfUserAnswer == _tfExpected)
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statement is ${_tfExpected ? "TRUE" : "FALSE"}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: (statFontSize * 0.95).clamp(11.0, 14.0),
                          fontWeight: FontWeight.w800,
                          color: (_tfUserAnswer == _tfExpected)
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tfExplanation,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: (statFontSize * 0.9).clamp(11.0, 13.5),
                          height: 1.35,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (isCompleted) ...[
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
    );
  }

  Widget _buildTrueFalseOptionButton({
    required bool isTrueOption,
    required double scale,
    required ThemeData theme,
    required double fontSize,
  }) {
    final bool isSelected = (_tfUserAnswer == isTrueOption);
    final bool isTargetCorrect = (_tfExpected == isTrueOption);
    final bool isRevealed = _isTimerExpired && isTargetCorrect;
    final bool isCompleted = _tfAnswered || _isTimerExpired;

    Color bgColor = theme.colorScheme.surface;
    Color borderColor = theme.colorScheme.outline.withOpacity(0.35);
    Color textColor = theme.colorScheme.onSurface;
    double borderWidth = 1.4;

    if (isSelected) {
      if (isTargetCorrect) {
        bgColor = Colors.green.withOpacity(0.12);
        borderColor = Colors.green.shade600;
        textColor = Colors.green.shade800;
        borderWidth = 2.4;
      } else {
        bgColor = Colors.red.withOpacity(0.10);
        borderColor = Colors.red.shade500;
        textColor = Colors.red.shade800;
        borderWidth = 2.4;
      }
    } else if (isRevealed) {
      bgColor = Colors.green.withOpacity(0.12);
      borderColor = Colors.green.shade600;
      textColor = Colors.green.shade800;
      borderWidth = 2.4;
    } else if (isCompleted) {
      bgColor = theme.colorScheme.surface.withOpacity(0.5);
      borderColor = theme.colorScheme.outline.withOpacity(0.15);
      textColor = theme.colorScheme.onSurface.withOpacity(0.35);
    }

    final String label = isTrueOption ? 'TRUE' : 'FALSE';
    final IconData icon =
        isTrueOption ? Icons.check_circle_outline : Icons.cancel_outlined;

    return OutlinedButton(
      onPressed: (isCompleted || _isAnswerSubmitted)
          ? null
          : () => _handleTrueFalseAnswer(isTrueOption),
      style: OutlinedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        side: BorderSide(color: borderColor, width: borderWidth),
        padding: EdgeInsets.symmetric(
          vertical: (16.0 * scale).clamp(12.0, 20.0),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: (20.0 * scale).clamp(16.0, 24.0), color: textColor),
          SizedBox(width: (8.0 * scale).clamp(6.0, 10.0)),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchingUI(
    double scale,
    ThemeData theme,
    double buttonFontSize,
    double statFontSize,
    double cardWidth,
  ) {
    final bool isCompleted = _matchingSubmitted || _isTimerExpired;
    final int matchedCount = _userPairs.length;
    final int totalCount = _matchingPairs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all((14.0 * scale).clamp(10.0, 18.0)),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.18),
            ),
          ),
          child: Column(
            children: [
              Text(
                _matchingPrompt.isNotEmpty
                    ? _matchingPrompt
                    : 'Match each concept on the left with its definition on the right:',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: (17.0 * scale).clamp(13.0, 20.0),
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isCompleted
                    ? 'Review matches below'
                    : 'Click or drag definitions onto concepts to pair them ($matchedCount of $totalCount paired • +3s, +2s, +1s per option, max 20s)',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: (statFontSize * 0.85).clamp(10.0, 12.5),
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: (16.0 * scale).clamp(12.0, 20.0)),

        Column(
          children: _matchingLeftTerms.map((term) {
            final String? currentMatch = _userPairs[term];
            final String canonicalDef = _matchingPairs[term] ?? '';
            final bool isSelected = (_selectedLeftTerm == term);
            final bool? isPairCorrect =
                isCompleted ? (_matchingPairResults[term]) : null;

            return DragTarget<String>(
              onWillAcceptWithDetails: (details) =>
                  !isCompleted && _matchingRightDefs.contains(details.data),
              onAcceptWithDetails: (details) {
                _pairTermWithDef(term, details.data);
              },
              builder: (context, candidateData, rejectedData) {
                final bool isHovered =
                    candidateData.isNotEmpty && !isCompleted;

                Color borderColor = theme.colorScheme.outline.withOpacity(0.3);
                Color bgColor = theme.colorScheme.surface;
                if (isCompleted) {
                  if (isPairCorrect == true) {
                    borderColor = Colors.green.shade600;
                    bgColor = Colors.green.withOpacity(0.08);
                  } else {
                    borderColor = Colors.red.shade400;
                    bgColor = Colors.red.withOpacity(0.08);
                  }
                } else if (isHovered) {
                  borderColor = theme.colorScheme.primary;
                  bgColor = theme.colorScheme.primary.withOpacity(0.18);
                } else if (isSelected) {
                  borderColor = theme.colorScheme.primary;
                  bgColor = theme.colorScheme.primary.withOpacity(0.08);
                } else if (currentMatch != null) {
                  borderColor = theme.colorScheme.secondary.withOpacity(0.7);
                  bgColor =
                      theme.colorScheme.secondaryContainer.withOpacity(0.3);
                }

                final Widget termCardContent = Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor,
                      width: (isSelected || isHovered) ? 2.2 : 1.2,
                    ),
                    boxShadow: isHovered
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: isCompleted
                                  ? null
                                  : () {
                                      if (_selectedRightDef != null) {
                                        _pairTermWithDef(term, _selectedRightDef!);
                                      } else {
                                        setState(() {
                                          _selectedLeftTerm =
                                              (_selectedLeftTerm == term)
                                                  ? null
                                                  : term;
                                        });
                                      }
                                    },
                              child: Row(
                                children: [
                                  Icon(
                                    isCompleted
                                        ? (isPairCorrect == true
                                            ? Icons.check_circle_outline
                                            : Icons.cancel_outlined)
                                        : (isHovered
                                            ? Icons.add_circle_outline
                                            : (currentMatch != null
                                                ? Icons.link
                                                : Icons.radio_button_unchecked)),
                                    size: 18,
                                    color: isCompleted
                                        ? (isPairCorrect == true
                                            ? Colors.green.shade700
                                            : Colors.red.shade700)
                                        : (isHovered
                                            ? theme.colorScheme.primary
                                            : (isSelected
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface
                                                    .withOpacity(0.7))),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      term,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: (statFontSize * 1.05)
                                            .clamp(12.0, 15.0),
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (!isCompleted && currentMatch == null) ...[
                                    Icon(
                                      Icons.drag_indicator,
                                      size: 16,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.35),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (currentMatch != null) ...[
                        const SizedBox(height: 8),
                        if (!isCompleted)
                          Draggable<String>(
                            data: currentMatch,
                            feedback: Material(
                              elevation: 8.0,
                              borderRadius: BorderRadius.circular(10),
                              color: theme.colorScheme.secondary,
                              shadowColor: Colors.black45,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: (cardWidth * 0.85).clamp(240.0, 750.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.drag_indicator,
                                        size: 18, color: Colors.white70),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        currentMatch,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: (statFontSize * 0.9)
                                              .clamp(11.0, 13.5),
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.25,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant
                                      .withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.drag_indicator,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Moving: $currentMatch',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: (statFontSize * 0.88)
                                              .clamp(11.0, 13.0),
                                          fontStyle: FontStyle.italic,
                                          color: theme
                                              .colorScheme.onSurfaceVariant
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer
                                    .withOpacity(0.45),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.secondary
                                      .withOpacity(0.5),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.drag_indicator,
                                    size: 16,
                                    color: theme.colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      currentMatch,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: (statFontSize * 0.88)
                                            .clamp(11.0, 13.0),
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme
                                            .onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    tooltip: 'Unpair (returns to pool)',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () =>
                                        _pairTermWithDef(term, ''),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant
                                  .withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '→ $currentMatch',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize:
                                    (statFontSize * 0.88).clamp(11.0, 13.0),
                                fontStyle: FontStyle.italic,
                                color: (isPairCorrect == true
                                    ? Colors.green.shade800
                                    : Colors.red.shade800),
                              ),
                            ),
                          ),
                      ],
                      if (isCompleted && isPairCorrect != true) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Correct: $canonicalDef',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize:
                                (statFontSize * 0.85).clamp(10.0, 12.5),
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                );

                if (isCompleted || currentMatch != null) {
                  return termCardContent;
                }

                return Draggable<String>(
                  data: term,
                  feedback: Material(
                    elevation: 8.0,
                    borderRadius: BorderRadius.circular(10),
                    color: theme.colorScheme.primary,
                    child: Container(
                      constraints:
                          BoxConstraints(maxWidth: (cardWidth * 0.85).clamp(240.0, 750.0)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.drag_indicator,
                              size: 18, color: Colors.white70),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              term,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize:
                                    (statFontSize * 1.05).clamp(12.0, 15.0),
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child: termCardContent,
                  ),
                  child: termCardContent,
                );
              },
            );
          }).toList(),
        ),

        if (!isCompleted) ...[
          SizedBox(height: (12.0 * scale).clamp(8.0, 16.0)),
          DragTarget<String>(
            onWillAcceptWithDetails: (details) =>
                !isCompleted && _userPairs.values.contains(details.data),
            onAcceptWithDetails: (details) {
              setState(() {
                _userPairs.removeWhere((k, v) => v == details.data);
              });
            },
            builder: (context, poolCandidateData, poolRejectedData) {
              final bool isPoolHovered =
                  poolCandidateData.isNotEmpty && !isCompleted;
              final unassignedDefs = _matchingRightDefs
                  .where((def) => !_userPairs.values.contains(def))
                  .toList();

              return Container(
                padding: isPoolHovered ? const EdgeInsets.all(8) : EdgeInsets.zero,
                decoration: isPoolHovered
                    ? BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 1.8,
                        ),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      unassignedDefs.isNotEmpty
                          ? 'Definitions Pool (Drag onto concepts or tap to pair):'
                          : 'Definitions Pool (All paired! Drag definitions to reorder or drop here to unpair):',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: (statFontSize * 0.88).clamp(11.0, 13.0),
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (unassignedDefs.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 18, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'All definitions paired! You can drag definitions between answers to adjust them, or tap Submit.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize:
                                      (statFontSize * 0.85).clamp(10.5, 13.0),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Column(
                        children: unassignedDefs.map((def) {
                          final bool isDefSelected = (_selectedRightDef == def);

                          return DragTarget<String>(
                            onWillAcceptWithDetails: (details) =>
                                !isCompleted &&
                                _matchingLeftTerms.contains(details.data),
                            onAcceptWithDetails: (details) {
                              _pairTermWithDef(details.data, def);
                            },
                            builder: (context, candidateData, rejectedData) {
                              final bool isHovered =
                                  candidateData.isNotEmpty && !isCompleted;

                              Color itemBg = isDefSelected
                                  ? theme.colorScheme.primary.withOpacity(0.12)
                                  : (isHovered
                                      ? theme.colorScheme.primary.withOpacity(0.18)
                                      : theme.colorScheme.surface);

                              Color itemBorder = isDefSelected || isHovered
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withOpacity(0.4);

                              final Widget defCardContent = Container(
                                margin: const EdgeInsets.only(bottom: 6.0),
                                decoration: BoxDecoration(
                                  color: itemBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: itemBorder,
                                    width:
                                        (isDefSelected || isHovered) ? 1.8 : 1.0,
                                  ),
                                  boxShadow: isHovered
                                      ? [
                                          BoxShadow(
                                            color: theme.colorScheme.primary
                                                .withOpacity(0.2),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: InkWell(
                                  onTap: () {
                                    if (_selectedLeftTerm != null) {
                                      _pairTermWithDef(_selectedLeftTerm!, def);
                                    } else {
                                      setState(() {
                                        _selectedRightDef =
                                            (isDefSelected ? null : def);
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.drag_indicator,
                                          size: 16,
                                          color: isDefSelected
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface
                                                  .withOpacity(0.4),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            def,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: (statFontSize * 0.9)
                                                  .clamp(11.0, 13.5),
                                              color: isDefSelected
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              return Draggable<String>(
                                data: def,
                                feedback: Material(
                                  elevation: 8.0,
                                  borderRadius: BorderRadius.circular(10),
                                  color: theme.colorScheme.secondary,
                                  child: Container(
                                    constraints: BoxConstraints(
                                        maxWidth: (cardWidth * 0.85)
                                            .clamp(240.0, 750.0)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.drag_indicator,
                                            size: 18, color: Colors.white70),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            def,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: (statFontSize * 0.9)
                                                  .clamp(11.0, 13.5),
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.35,
                                  child: defCardContent,
                                ),
                                child: defCardContent,
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          SizedBox(height: (16.0 * scale).clamp(12.0, 20.0)),
          FilledButton.icon(
            onPressed: (_userPairs.isNotEmpty && !_matchingSubmitted && !_isTimerExpired && !_isAnswerSubmitted)
                ? _handleMatchingSubmit
                : null,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: Text('Submit Matches (${_userPairs.length}/$totalCount)'),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(
                vertical: (13.0 * scale).clamp(10.0, 16.0),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: (15.0 * scale).clamp(13.0, 16.5),
              ),
            ),
          ),
        ],

        if (isCompleted) ...[
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
    );
  }

  Widget _buildSequencingUI(
    double scale,
    ThemeData theme,
    double buttonFontSize,
    double statFontSize,
    double cardWidth,
  ) {
    final bool isCompleted =
        _sequencingSubmitted || _isTimerExpired || _isAnswerSubmitted;
    final int correctPositionsCount = _currentSequence
        .asMap()
        .entries
        .where((e) =>
            e.key < _expectedSequence.length &&
            e.value == _expectedSequence[e.key])
        .length;
    final int totalPositionsCount = _currentSequence.length;
    final bool isEntireSequenceCorrect =
        (correctPositionsCount == totalPositionsCount && totalPositionsCount > 0);
    final bool isFeedbackVisible = isCompleted ||
        isEntireSequenceCorrect ||
        _sequenceOrderAdjusted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all((14.0 * scale).clamp(10.0, 18.0)),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.18),
            ),
          ),
          child: Column(
            children: [
              Text(
                _sequencingPrompt.isNotEmpty
                    ? _sequencingPrompt
                    : 'Arrange the following steps in the correct order:',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: (17.0 * scale).clamp(13.0, 20.0),
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isCompleted
                    ? 'Review execution order below'
                    : (isFeedbackVisible
                        ? (isEntireSequenceCorrect
                            ? 'All $totalPositionsCount steps in correct order! • Ready to submit'
                            : '$correctPositionsCount of $totalPositionsCount steps in correct order • Use ▲ / ▼ or drag to arrange')
                        : 'Use ▲ / ▼ or drag steps to arrange from first to last (+3s, +2s, +1s per option, max 20s)'),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: (statFontSize * 0.85).clamp(10.0, 12.5),
                  fontWeight: FontWeight.w600,
                  color: (isFeedbackVisible && isEntireSequenceCorrect)
                      ? Colors.green.shade800
                      : theme.colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: (16.0 * scale).clamp(12.0, 20.0)),

        Column(
          children: _currentSequence.asMap().entries.map((entry) {
            final int index = entry.key;
            final String item = entry.value;
            final bool isPositionCorrect = (index < _expectedSequence.length &&
                _currentSequence[index] == _expectedSequence[index]);
            final bool isStepCorrect = isCompleted
                ? (index < _sequenceStepResults.length &&
                    _sequenceStepResults[index])
                : isPositionCorrect;

            return DragTarget<int>(
              key: ValueKey('seq_target_${item}'),
              onWillAcceptWithDetails: (details) => !isCompleted,
              onMove: (details) {
                if (!isCompleted &&
                    _activeDraggingIndex != null &&
                    _activeDraggingIndex != index &&
                    _activeDraggingIndex! >= 0 &&
                    _activeDraggingIndex! < _currentSequence.length &&
                    index >= 0 &&
                    index < _currentSequence.length) {
                  _cancelAdvance();
                  setState(() {
                    _sequenceOrderAdjusted = true;
                    final movedItem =
                        _currentSequence.removeAt(_activeDraggingIndex!);
                    _currentSequence.insert(index, movedItem);
                    _activeDraggingIndex = index;
                  });
                }
              },
              onAcceptWithDetails: (details) {
                _cancelAdvance();
                if (_activeDraggingIndex != null &&
                    _activeDraggingIndex! >= 0 &&
                    _activeDraggingIndex! < _currentSequence.length) {
                  final movedItem = _currentSequence[_activeDraggingIndex!];
                  _addBonusTimeForOption(movedItem);
                }
                setState(() {
                  _activeDraggingIndex = null;
                });
              },
              builder: (context, candidateData, rejectedData) {
                final bool isHovered =
                    candidateData.isNotEmpty && !isCompleted;

                Color borderColor = theme.colorScheme.outline.withOpacity(0.3);
                Color bgColor = theme.colorScheme.surface;
                if (isCompleted) {
                  if (isStepCorrect) {
                    borderColor = Colors.green.shade600;
                    bgColor = Colors.green.withOpacity(0.08);
                  } else {
                    borderColor = Colors.red.shade400;
                    bgColor = Colors.red.withOpacity(0.08);
                  }
                } else if (isFeedbackVisible) {
                  if (isPositionCorrect) {
                    borderColor = Colors.green.shade600;
                    bgColor = Colors.green.withOpacity(0.08);
                  } else {
                    borderColor = Colors.red.shade400.withOpacity(0.65);
                    bgColor = Colors.red.withOpacity(0.04);
                  }
                } else if (isHovered) {
                  borderColor = theme.colorScheme.primary;
                  bgColor = theme.colorScheme.primary.withOpacity(0.18);
                }

                final Widget stepCardContent = Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor,
                      width: isHovered ? 2.0 : 1.2,
                    ),
                    boxShadow: isHovered
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: (isCompleted || isFeedbackVisible)
                              ? ((isCompleted ? isStepCorrect : isPositionCorrect)
                                  ? Colors.green.shade600
                                  : Colors.red.shade600)
                              : theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: (isCompleted || isFeedbackVisible)
                                ? Colors.white
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      if (isCompleted || isFeedbackVisible) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isCompleted ? isStepCorrect : isPositionCorrect)
                                ? Colors.green.withOpacity(0.15)
                                : Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (isCompleted ? isStepCorrect : isPositionCorrect)
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (isCompleted ? isStepCorrect : isPositionCorrect)
                                    ? Icons.check_circle_rounded
                                    : Icons.close_rounded,
                                size: 13,
                                color: (isCompleted ? isStepCorrect : isPositionCorrect)
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                (isCompleted ? isStepCorrect : isPositionCorrect)
                                    ? 'Correct'
                                    : 'Out of Order',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: (isCompleted ? isStepCorrect : isPositionCorrect)
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize:
                                (statFontSize * 0.95).clamp(11.5, 14.0),
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (!isCompleted) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          tooltip: 'Move Up',
                          onPressed: index > 0
                              ? () {
                                  _cancelAdvance();
                                  final temp = _currentSequence[index];
                                  setState(() {
                                    _sequenceOrderAdjusted = true;
                                    _currentSequence[index] =
                                        _currentSequence[index - 1];
                                    _currentSequence[index - 1] = temp;
                                  });
                                  _addBonusTimeForOption(temp);
                                }
                              : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 18),
                          tooltip: 'Move Down',
                          onPressed: index < _currentSequence.length - 1
                              ? () {
                                  _cancelAdvance();
                                  final temp = _currentSequence[index];
                                  setState(() {
                                    _sequenceOrderAdjusted = true;
                                    _currentSequence[index] =
                                        _currentSequence[index + 1];
                                    _currentSequence[index + 1] = temp;
                                  });
                                  _addBonusTimeForOption(temp);
                                }
                              : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.drag_indicator,
                          size: 18,
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.35),
                        ),
                      ],
                    ],
                  ),
                );

                if (isCompleted) {
                  return stepCardContent;
                }

                return Draggable<int>(
                  key: ValueKey('seq_drag_${item}'),
                  data: index,
                  onDragStarted: () {
                    _cancelAdvance();
                    setState(() {
                      _activeDraggingIndex = index;
                    });
                  },
                  onDragEnd: (details) {
                    _cancelAdvance();
                    if (_activeDraggingIndex != null &&
                        _activeDraggingIndex! >= 0 &&
                        _activeDraggingIndex! < _currentSequence.length) {
                      final movedItem = _currentSequence[_activeDraggingIndex!];
                      _addBonusTimeForOption(movedItem);
                    }
                    setState(() {
                      _activeDraggingIndex = null;
                    });
                  },
                  onDraggableCanceled: (velocity, offset) {
                    _cancelAdvance();
                    setState(() {
                      _activeDraggingIndex = null;
                    });
                  },
                  feedback: Material(
                    elevation: 8.0,
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.primary,
                    child: Container(
                      constraints:
                          BoxConstraints(maxWidth: (cardWidth * 0.85).clamp(240.0, 750.0)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.drag_indicator,
                              size: 18, color: Colors.white70),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              item,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize:
                                    (statFontSize * 0.95).clamp(11.5, 14.0),
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child: stepCardContent,
                  ),
                  child: stepCardContent,
                );
              },
            );
          }).toList(),
        ),

        if (isCompleted) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Canonical Execution Order:',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: (statFontSize * 0.9).clamp(11.0, 13.5),
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ..._expectedSequence.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        '${e.key + 1}. ${e.value}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: (statFontSize * 0.85).clamp(10.5, 13.0),
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ],

        SizedBox(height: (16.0 * scale).clamp(12.0, 20.0)),
        if (!isCompleted) ...[
          FilledButton.icon(
            onPressed: _handleSequencingSubmit,
            icon: Icon(
              (isFeedbackVisible && isEntireSequenceCorrect)
                  ? Icons.check_circle_rounded
                  : Icons.done_all_rounded,
              size: 18,
            ),
            label: Text(
              (isFeedbackVisible && isEntireSequenceCorrect)
                  ? 'Submit Sequence (All $totalPositionsCount Steps Correct!)'
                  : (isFeedbackVisible
                      ? 'Submit Sequence Order ($correctPositionsCount/$totalPositionsCount Correct)'
                      : 'Submit Sequence Order'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: (isFeedbackVisible && isEntireSequenceCorrect)
                  ? Colors.green.shade700
                  : null,
              foregroundColor: (isFeedbackVisible && isEntireSequenceCorrect)
                  ? Colors.white
                  : null,
              padding: EdgeInsets.symmetric(
                vertical: (13.0 * scale).clamp(10.0, 16.0),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: (15.0 * scale).clamp(13.0, 16.5),
              ),
            ),
          ),
        ] else ...[
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
    );
  }

  Widget _buildSortingUI(
    double scale,
    ThemeData theme,
    double buttonFontSize,
    double statFontSize,
  ) {
    final bool isCompleted = _sortingSubmitted || _isTimerExpired;
    final int classifiedCount = _userClassification.length;
    final int totalCount = _sortingItems.length;
    final int correctCount = _sortingItems
        .where((item) =>
            _userClassification[item] != null &&
            _userClassification[item] == _getExpectedCategoryForItem(item))
        .length;
    final bool allItemsCorrect = (correctCount == totalCount && totalCount > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all((14.0 * scale).clamp(10.0, 18.0)),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.18),
            ),
          ),
          child: Column(
            children: [
              Text(
                _sortingPrompt.isNotEmpty
                    ? _sortingPrompt
                    : 'Classify each item into the correct category:',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: (17.0 * scale).clamp(13.0, 20.0),
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isCompleted
                    ? (allItemsCorrect
                        ? 'All $totalCount items classified correctly!'
                        : '$correctCount of $totalCount items correct')
                    : 'Select a category for each item ($classifiedCount of $totalCount classified • $correctCount correct)',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: (statFontSize * 0.85).clamp(10.0, 12.5),
                  fontWeight: FontWeight.w600,
                  color: (isCompleted && allItemsCorrect)
                      ? Colors.green.shade800
                      : theme.colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: (16.0 * scale).clamp(12.0, 20.0)),

        Column(
          children: _sortingItems.map((item) {
            final String? selectedCategory = _userClassification[item];
            final String expectedCat = _getExpectedCategoryForItem(item);
            final bool hasSelected = (selectedCategory != null);
            final bool isCorrectCategory =
                hasSelected && (selectedCategory == expectedCat);
            final bool? isItemCorrect = isCompleted
                ? (_sortingResults[item] ?? isCorrectCategory)
                : (hasSelected ? isCorrectCategory : null);

            Color borderColor = theme.colorScheme.outline.withOpacity(0.3);
            Color bgColor = theme.colorScheme.surface;
            if (isItemCorrect == true) {
              borderColor = Colors.green.shade600;
              bgColor = Colors.green.withOpacity(0.08);
            } else if (isItemCorrect == false) {
              borderColor = Colors.red.shade400;
              bgColor = Colors.red.withOpacity(0.08);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isItemCorrect != null) ...[
                        Icon(
                          isItemCorrect == true
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          size: 20,
                          color: isItemCorrect == true
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: (statFontSize * 1.05).clamp(12.0, 15.0),
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (isItemCorrect != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isItemCorrect == true
                                ? Colors.green.withOpacity(0.15)
                                : Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isItemCorrect == true
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 11,
                                color: isItemCorrect == true
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                              const SizedBox(width: 3.5),
                              Text(
                                isItemCorrect == true ? 'Correct' : 'Incorrect',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isItemCorrect == true
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _sortingCategories.map((category) {
                      final bool isChipSelected = (selectedCategory == category);
                      final bool isTargetCategory = (expectedCat == category);
                      final bool isLocked = (isCompleted ||
                          hasSelected ||
                          _isAnswerSubmitted ||
                          _sortingSubmitted);

                      Color chipBg = theme.colorScheme.surface;
                      Color chipBorder = theme.colorScheme.outline.withOpacity(0.4);
                      Color chipText = theme.colorScheme.onSurface;

                      if (isChipSelected) {
                        if (isItemCorrect == true) {
                          chipBg = Colors.green.shade600;
                          chipBorder = Colors.green.shade700;
                          chipText = Colors.white;
                        } else if (isItemCorrect == false) {
                          chipBg = Colors.red.shade600;
                          chipBorder = Colors.red.shade700;
                          chipText = Colors.white;
                        } else {
                          chipBg = theme.colorScheme.primary;
                          chipBorder = theme.colorScheme.primary;
                          chipText = theme.colorScheme.onPrimary;
                        }
                      } else if (isCompleted && isTargetCategory) {
                        chipBg = Colors.green.withOpacity(0.15);
                        chipBorder = Colors.green.shade600;
                        chipText = Colors.green.shade900;
                      } else if (isLocked) {
                        chipBg = theme.colorScheme.surface.withOpacity(0.35);
                        chipBorder = theme.colorScheme.outline.withOpacity(0.15);
                        chipText = theme.colorScheme.onSurface.withOpacity(0.35);
                      }

                      return Opacity(
                        opacity: (hasSelected && !isChipSelected && !(isCompleted && isTargetCategory))
                            ? 0.45
                            : 1.0,
                        child: InkWell(
                          onTap: isLocked
                              ? null
                              : () {
                                  _cancelAdvance();
                                  setState(() {
                                    _userClassification[item] = category;
                                  });
                                  _addBonusTimeForOption(item);
                                  if (_userClassification.length == _sortingItems.length) {
                                    _handleSortingSubmit();
                                  }
                                },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: chipBorder, width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isChipSelected && isItemCorrect != null) ...[
                                  Icon(
                                    isItemCorrect == true
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  category,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: (statFontSize * 0.85).clamp(10.5, 12.5),
                                    fontWeight: isChipSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: chipText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (isCompleted && isItemCorrect != true) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Correct category: $expectedCat',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: (statFontSize * 0.85).clamp(10.0, 12.5),
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
        if (isCompleted) ...[
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
    );
  }

  void _showKnowledgeGraphModal() {
    if (_knowledgeGraph == null) return;
    final graph = _knowledgeGraph!;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        String selectedGroup = 'All';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allNodes = graph.nodes.values.toList();
            final filteredNodes = selectedGroup == 'All'
                ? allNodes
                : allNodes.where((n) => n.visualization.group == selectedGroup).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 960, maxHeight: 780),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.hub_rounded, color: Colors.indigo, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HardCode Knowledge Graph',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Visualized Node-Link Structure • ${graph.nodes.length} Vertices • ${graph.edges.length} Directed Edges',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Summary Metrics Row
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _buildGraphStatBadge('Nodes', '${graph.nodes.length}', Colors.indigo),
                        _buildGraphStatBadge('Edges', '${graph.edges.length}', Colors.purple),
                        _buildGraphStatBadge('Languages', '18', Colors.blue),
                        _buildGraphStatBadge('Domains', '25', Colors.deepPurple),
                        _buildGraphStatBadge('Questions', '310', Colors.teal),
                        _buildGraphStatBadge('Databases', '32', Colors.pink),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Group Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          'All',
                          'domain',
                          'language',
                          'database',
                          'paradigm',
                          'concept',
                          'syntax',
                          'question_tf',
                          'question_matching',
                          'question_sequencing',
                          'question_sorting',
                          'question_mc',
                        ].map((grp) {
                          final isSelected = selectedGroup == grp;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(grp == 'All' ? 'All Groups' : grp),
                              selected: isSelected,
                              onSelected: (_) {
                                setModalState(() {
                                  selectedGroup = grp;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Node Browser List
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredNodes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final node = filteredNodes[idx];
                          final outCount = graph.getOutgoingEdges(node.id).length;
                          final inCount = graph.getIncomingEdges(node.id).length;
                          final colorHex = node.visualization.color;
                          Color dotColor = Colors.grey;
                          try {
                            dotColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                          } catch (_) {}

                          return ListTile(
                            dense: true,
                            leading: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              node.label,
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${node.type} • ${node.category} • ID: ${node.id}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Out: $outCount • In: $inCount',
                                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGraphStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
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
