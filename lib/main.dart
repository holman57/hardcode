import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
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
  int _prevQuestionNumber = 0;
  int _questionNumber = 0;
  List _langList = [];
  String _language = "";
  final List<int> _langPriorities = [];
  List _correctPatterns = [];
  final List _incorrectPatternGroups = [];
  final List _incorrectPatternPriorities = [];
  List _questions = [];
  String _questionSubType = "";
  List _variablePermutations = [];
  List _variableBranching = [];
  int _questionRange = 0;
  String _question = "";
  String _correctAnswer = "";
  final List _choices = [];
  final List<String> _choiceSelections = [];
  List _intSmallVarSet = [];
  List _intVarNames = [];
  List _intRustVarTypes = [];
  final List<String> _answerGroup = [];

  UserStats _userStats = DatabaseService.instance.getUserStats();
  bool _isLoading = true;

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
    _intVarNames = (_data['Variables']['Int Variable Names'] as List);
    _intSmallVarSet =
        (_data['Variables']['Integer Small Variable Sets'] as List);
    _intRustVarTypes = (_data['Variables']['Rust Int Variable Types'] as List);
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
    });
    return render.trim();
  }

  void generateQuestion() {
    _answerGroup.clear();
    _choices.clear();
    _incorrectPatternGroups.clear();
    _incorrectPatternPriorities.clear();
    PriorityRandomGenerator prgLanguage =
        PriorityRandomGenerator(_langList.length, _langPriorities);
    _language = (_langList[prgLanguage.pickIndex()] as String);
    _correctAnswer = (_data["Variables"]["Declaration"]["Integer Assignment"]
        ["Answers"]["Preferred"][_language] as String);
    Random random = Random.secure();
    int answerSelection = 0;
    if (random.nextInt(2) == 1) {
      answerSelection = random.nextInt(_data["Variables"]["Declaration"]
              ["Integer Assignment"]["Answers"]["Correct"][_language]
          .length);
      _correctAnswer = (_data["Variables"]["Declaration"]["Integer Assignment"]
          ["Answers"]["Correct"][_language][answerSelection] as String);
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
    if (kDebugMode) {
      print('\n');
      print(_correctAnswer);
      print('\n');
    }
    _correctPatterns = (_data["Variables"]["Declaration"]["Integer Assignment"]
        ["Answers"]["Correct"][_language] as List);
    _incorrectPatternGroups.clear();
    _data['Variables']['Declaration']['Integer Assignment']['Answers']
            ['Incorrect']
        .forEach((item) {
      _incorrectPatternGroups.add([item['Pattern'], item['Priority']]);
      _incorrectPatternPriorities.add(item['Priority']);
    });
    _questions = (_data['Variables']['Declaration']['Integer Assignment']
        ['Question'] as List);
    _questionSubType = (_data['Variables']['Declaration']['Integer Assignment']
        ['Sub-Type'] as String);
    _variablePermutations =
        (_data['Variables']['Variable Permutations'] as List);
    _variableBranching = (_data['Variables']['Random Variables'] as List);
    _questionRange = _questions.length;
    while (_questionNumber == _prevQuestionNumber) {
      random = Random.secure();
      _questionNumber = random.nextInt(_questionRange);
    }
    _prevQuestionNumber = _questionNumber;
    _question = _questions[_questionNumber].replaceAll("[language]", _language);
    _choices.add([_correctAnswer, 1]);
    _choiceSelections.add(_correctAnswer);
    PriorityRandomGenerator prgChoice = PriorityRandomGenerator(
        _incorrectPatternGroups.length, _incorrectPatternPriorities);
    while (_choices.length < 5) {
      String incorrectAnswer = renderPatternOptions(
          _incorrectPatternGroups[prgChoice.pickIndex()][0],
          _variablePermutations);
      if (_choiceSelections.contains(incorrectAnswer)) continue;
      if (_correctPatterns.contains(incorrectAnswer)) continue;
      _choices.add([incorrectAnswer, 0]);
    }
    _choices.shuffle();
    for (var item in _choices) {
      if (kDebugMode) {
        print(item);
      }
    }
    if (kDebugMode) {
      print('--------------');
    }
    for (int i = 0; i < _choices.length; i++) {
      _choices[i][0] =
          renderPatternBranching(_choices[i][0], _variableBranching);
    }
    for (var item in _choices) {
      if (kDebugMode) {
        print(item);
      }
    }
    if (kDebugMode) {
      print('--------------');
    }
    for (var e in _choices) {
      _answerGroup.add(e[0]);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
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
        title: Text(
          widget.title.isNotEmpty ? widget.title : 'HardCode',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
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
                  const SizedBox(height: 4),
                  Text(
                    'Cross-Platform Hive Database',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: theme.colorScheme.onPrimary.withOpacity(0.85),
                    ),
                  ),
                ],
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
              title: const Text('Total Answered'),
              trailing: Text(
                '${_userStats.totalAnswered} (${_userStats.totalCorrect} correct)',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const Divider(),
            if (_userStats.languageStats.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Per-Language Stats',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
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
      body: Center(
        child: LayoutBuilder(
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
                (24.0 * scale).clamp(10.0, 28.0);
            final double titleSpacing =
                (14.0 * scale).clamp(8.0, 18.0);
            final double statFontSize = (13.0 * scale).clamp(10.0, 15.0);

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: (20.0 * scale).clamp(10.0, 24.0),
                vertical: (24.0 * scale).clamp(12.0, 32.0),
              ),
              child: Center(
                child: SizedBox(
                  width: cardWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Persistent Stats Banner
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: (14.0 * scale).clamp(8.0, 18.0),
                          vertical: (8.0 * scale).clamp(5.0, 10.0),
                        ),
                        margin: EdgeInsets.only(
                          bottom: (16.0 * scale).clamp(8.0, 20.0),
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
                              '$_language - $_questionSubType',
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
                          return AnswerButton(
                            key: ValueKey('${_questionNumber}_$answerButton'),
                            text: answerButton,
                            fontSize: buttonFontSize,
                            verticalPadding: buttonVerticalPadding,
                            horizontalPadding: buttonHorizontalPadding,
                            verticalMargin: buttonVerticalMargin,
                            onPressed: () async {
                              int answer = _choices[
                                  _answerGroup.indexOf(answerButton)][1];
                              final isCorrect = (answer == 1);
                              final updatedStats =
                                  await DatabaseService.instance.recordAnswer(
                                language: _language,
                                isCorrect: isCorrect,
                              );
                              if (!mounted) return;
                              setState(() {
                                _userStats = updatedStats;
                                if (isCorrect) {
                                  generateQuestion();
                                }
                              });
                              if (!isCorrect) {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Incorrect choice. Try again!',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    backgroundColor: Colors.redAccent.shade700,
                                    duration: const Duration(milliseconds: 1200),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 16),
                                  ),
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
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            generateQuestion();
          });
        },
        tooltip: 'Next Question',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AnswerButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final double fontSize;
  final double verticalPadding;
  final double horizontalPadding;
  final double verticalMargin;

  const AnswerButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.fontSize = 18.0,
    this.verticalPadding = 14.0,
    this.horizontalPadding = 20.0,
    this.verticalMargin = 5.0,
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

    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.verticalMargin),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: _isHovered
                ? primary.withOpacity(0.08)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? primary
                  : theme.colorScheme.outline.withOpacity(0.35),
              width: _isHovered ? 2.2 : 1.4,
            ),
            boxShadow: _isHovered
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
              splashColor: primary.withOpacity(0.12),
              highlightColor: primary.withOpacity(0.05),
              onTap: widget.onPressed,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: widget.verticalPadding,
                  horizontal: widget.horizontalPadding,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.text,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: widget.fontSize,
                        fontWeight:
                            _isHovered ? FontWeight.bold : FontWeight.w600,
                        color: _isHovered ? primary : theme.colorScheme.onSurface,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
