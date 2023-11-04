# Multiprogramming

A flashcard style Question-and-Answer system for memorizing the syntax of common programming languages.

## Target Languages x 19

|        |            |      |
| ------ | ---------- | ---- |
| C      | Python3    | Go   |
| C++    | PowerShell | PHP  |
| C#     | Bash       | Rust |
| Java   | JavaScript | Ruby |
| Kotlin | TypeScript | Lua  |
| Scala  | Dart       | SQL  |
| R      | Swift      |      |

## Structure

### Question Hierarchy

1. Language
2. Variables
   1. Declaration
      1. Multi-Choice
         1. Primitive Types
            1. Integer Assignment
   2. Mutability
      1. Multi-Choice
   3. Multiple Declaration
      1. Multi-Choice
3. Control Flow
   1. Decision-Making
      1. if-then, if-then-else, switch
   2. Looping
      1. for, while, do-while
   3. Branching
      1. break, continue, return

### `questions.json` Format

```
{
  "Language": ["C", "Python", "Go", ... ],
  "Variables": {
      "Rust Int Variable Types": [string],
      "Int Variable Names": [string],
      "Random Variables": [string],
      "Variable Permutations": [string],
      "Declaration": {
          "Multi-Choice": {
              "Type": string,
              "Sub-Type": string,
              "Question": [string],
              "True-False": [string],
              "Answers": {
                "Correct": {
                    "C": [string] ,
                    "Python": [string] ,
                    "Go": [string] ,
                    ...
                },
                "Incorrect": [
                  {
                    "Name": string,
                    "Pattern": string,
                    "Priority": int
                  },
                  ...
                ]
      "Mutability": [],
      "Multiple Declaration": []
    }
  },
  "Control Flow": []
}

```

### String Interpolation Pattern Match

#### First Parse

- `[language]` : The programming language that corresponds to the question.

#### Second Parse

- `[$|@|None]`
- `[var|val|int|Int|let|None]`
- `[local|var|val|int|Int|let|None]`
- `[: Integer|: Int|: number| int|None]`
- `[:=|=]`
- `[;|None]`
- `[mut |None]`
- `[DECLARE |None]`
- `[ INT|None]`
- `[SET |None]`

#### Third Parse

- `[random int variable]`
  - [a-z]
    - Priority: 1
  - (myVar|myvariable|myNum|num|amount|total|quantity|count|rate|limit)
    - Priority 1
  - [xynij]
    - Priority: 1
- `[random integer]`
  - [0-9]{1}
    - Priority: 1
  - [0-9]{1,2}
    - Priority: 1
  - [0-9]{1,4}
    - Priority: 1
  - [0-9]{1,6}
    - Priority: 1
- `[random rust data type]`
  - (i8|i16|i32|i64|i128|isize|u8|u16|u32|u64|u128|usuze)
