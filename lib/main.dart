import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HardCode',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
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

  Future<void> readJson() async {
    final String response = await rootBundle.loadString('assets/db.json');
    final data = await json.decode(response);
    setState(() {
      _data = data;
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
        List options = p.replaceAll("[", "").replaceAll("]", "").split("|");
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
    _correctAnswer = (_data["Variables"]["Declaration"]["Multi-Choice"]
        ["Answers"]["Preferred"][_language] as String);
    _correctPatterns = (_data["Variables"]["Declaration"]["Multi-Choice"]
        ["Answers"]["Correct"][_language] as List);
    _incorrectPatternGroups.clear();
    _data['Variables']['Declaration']['Multi-Choice']['Answers']['Incorrect']
        .forEach((item) {
      _incorrectPatternGroups.add([item['Pattern'], item['Priority']]);
      _incorrectPatternPriorities.add(item['Priority']);
    });
    _questions =
        (_data['Variables']['Declaration']['Multi-Choice']['Question'] as List);
    _questionSubType = (_data['Variables']['Declaration']['Multi-Choice']
        ['Sub-Type'] as String);
    _variablePermutations =
        (_data['Variables']['Variable Permutations'] as List);
    _variableBranching = (_data['Variables']['Random Variables'] as List);
    _questionRange = _questions.length;
    while (_questionNumber == _prevQuestionNumber) {
      Random random = Random.secure();
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
    WidgetsBinding.instance.addPostFrameCallback((_) => readJson());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        drawer: const Drawer(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '$_language - $_questionSubType',
              ),
              Text(
                _question,
              ),
              //
              // Text('$_correctPatterns'),
              // Text(
              //   _correctAnswer,
              //   style: Theme.of(context).textTheme.titleLarge,
              // ),
              // Text('$_choices'),
              //
              Column(
                children: _answerGroup.map((String answerButton) {
                  return OutlinedButton(
                      onPressed: () {
                        int answer =
                            _choices[_answerGroup.indexOf(answerButton)][1];
                        if (answer == 1) {
                          generateQuestion();
                          setState(() {});
                        }
                      },
                      child: Text(answerButton));
                }).toList(),
              ),
              //
              // OutlinedButton(
              //   style: OutlinedButton.styleFrom(
              //     foregroundColor: Colors.black,
              //     side: const BorderSide(
              //       color: Colors.blue,
              //     ),
              //   ),
              //   onPressed: () {},
              //   child: const Text("OutlinedButton Example"),
              // ),
              //
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              generateQuestion();
            });
          },
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
