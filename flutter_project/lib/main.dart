import 'dart:convert';
import 'dart:async';
import 'dart:math';

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
  var _priorities;
  var _n;

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
    double p_i = doubleInRange(random, 0, sumP);
    if (p_i > preS[preS.length - 1]) return preS.length - 1;
    for (var i = 0; i < preS.length - 1; i++) {
      if (p_i > preS[i] && p_i < preS[i + 1]) {
        return i;
      }
    }
    return -1;
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final _languages = {};
  var _data;
  int _prevQuestionNumber = 0;
  int _questionNumber = 0;
  List _langList = [];
  String _language = "";
  List<int> _langPriorities = [];
  List _correctPatterns = [];
  List _incorrectPatternGroups = [];
  List _incorrectPatternPriorities = [];
  List _questions = [];
  String _questionType = "";
  String _questionSubType = "";
  List _variablePermutations = [];
  List _randomVariableNames = [];
  int _questionRange = 0;
  String _question = "";
  String _correctAnswer = "";
  List _choices = [];

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
  }

  String renderPatternOptions(answer, pattern) {
    String render = answer;
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

  void generateQuestion() {
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
    _questionType =
        (_data['Variables']['Declaration']['Multi-Choice']['Type'] as String);
    _questionSubType = (_data['Variables']['Declaration']['Multi-Choice']
        ['Sub-Type'] as String);
    _variablePermutations =
        (_data['Variables']['Variable Permutations'] as List);
    _randomVariableNames = (_data['Variables']['Random Variables'] as List);
    _questionRange = _questions.length;
    while (_questionNumber == _prevQuestionNumber) {
      Random random = Random.secure();
      _questionNumber = random.nextInt(_questionRange);
    }
    _prevQuestionNumber = _questionNumber;
    _question = _questions[_questionNumber].replaceAll("[language]", _language);
    _choices.add([_correctAnswer, 1]);
    PriorityRandomGenerator prgChoice = PriorityRandomGenerator(
        _correctPatterns.length, _incorrectPatternPriorities);

    // var incorrectAnswer = renderPatternOptions()
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => readJson());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            Text('$_correctPatterns'),
            Text(
              '$_correctAnswer',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('$_choices'),
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
    );
  }
}
