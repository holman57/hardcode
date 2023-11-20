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
  int _prev_question_number = 0;
  int _question_number = 0;
  var _langList;
  var _language;
  List<int> _langPriorities = [];
  var _correctAnswer;
  List _correctPatterns = [];
  List _incorrectPatternGroups = [];
  var _questions;
  var _questionType;
  var _questionSubType;
  var _variablePermutations;
  var _randomVariableNames;

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

  void generateQuestion() {
    PriorityRandomGenerator prgLanguage =
        PriorityRandomGenerator(_langList.length, _langPriorities);
    _language = _langList[prgLanguage.pickIndex()];
    _correctAnswer = _data["Variables"]["Declaration"]["Multi-Choice"]
        ["Answers"]["Preferred"][_language];
    _correctPatterns = _data["Variables"]["Declaration"]["Multi-Choice"]
        ["Answers"]["Correct"][_language];
    _incorrectPatternGroups.clear();
    _data['Variables']['Declaration']['Multi-Choice']['Answers']['Incorrect']
        .forEach((item) {
      _incorrectPatternGroups.add([item['Pattern'], item['Priority']]);
    });
    _questions = _data['Variables']['Declaration']['Multi-Choice']['Question'];
    _questionType = _data['Variables']['Declaration']['Multi-Choice']['Type'];
    _questionSubType =
        _data['Variables']['Declaration']['Multi-Choice']['Sub-Type'];
    _variablePermutations = _data['Variables']['Variable Permutations'];
    _randomVariableNames = _data['Variables']['Random Variables'];
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
              '$_language',
            ),
            Text('$_correctPatterns'),
            Text(
              '$_correctAnswer',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('$_incorrectPatternGroups'),
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
