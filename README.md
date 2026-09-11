# HardCode

> **First Stable Version Proof of Concept (v1.0.0-PoC)**  
> *A high-velocity flashcard and syntax memorization engine for polyglot developers.*

[![Live Demo](https://img.shields.io/badge/Live%20Demo-GitHub%20Pages-success?style=for-the-badge&logo=github)](https://holman57.github.io/hardcode/)
[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Version](https://img.shields.io/badge/Version-v1.0.0--PoC-blue?style=for-the-badge)](https://github.com/holman57/hardcode)
[![Deploy Status](https://img.shields.io/badge/Deployment-Callisto%20VM%20%2B%20GH%20Pages-orange?style=for-the-badge)](https://holman57.github.io/hardcode/)

---

## 🚀 Overview

**HardCode** is an interactive, speed-oriented question-and-answer training engine engineered to build muscle memory and instant syntax recognition across **18 distinct programming languages** and core computer science fundamentals.

Whether switching between systems programming in Rust and C++, scripting in Python or PowerShell, or building frontend apps in TypeScript and Dart, HardCode trains developers to eliminate syntax hesitation under simulated time pressure.

🔗 **Try the live web app:** [https://holman57.github.io/hardcode/](https://holman57.github.io/hardcode/)

---

## 🎯 Supported Languages (18 Languages)

HardCode covers syntax, type declarations, control flow, scoping, and idiomatic conventions across 18 major languages:

| Systems & Performance | Modern General-Purpose | Scripting & Shell | Web & Mobile |
| :--- | :--- | :--- | :--- |
| **C** | **Python 3** | **Bash** | **JavaScript** |
| **C++** | **Go** | **PowerShell** | **TypeScript** |
| **Rust** | **Java** | **Ruby** | **Dart** |
| **C#** | **Kotlin** | **Lua** | **Swift** |
| | **Scala** | **PHP** | **R** |

---

## 🕹️ Interactive Question Modalities

HardCode moves beyond standard multiple-choice quizzes by incorporating diverse question formats designed to test different cognitive layers of programming knowledge:

### 1. Multiple Choice (Syntax & Conceptual)
- **Syntax Recognition**: Identifies correct syntax variations against realistic distractors generated dynamically.
- **Deep Explanations**: Features in-depth conceptual breakdown boxes (lightbulb tips) explaining language-specific semantics.
- **Persistent Flow**: Answers lock instantly, and completion buttons remain permanently visible to let developers read at their own pace.

### 2. True / False Evaluation
- Rapid statement evaluation testing edge cases, operator precedence, keyword rules, and language quirks.
- Instant color-coded feedback and canonical explanations.

### 3. Term & Definition Matching
- Two-column interactive pairing system linking language concepts, memory models, and execution semantics to definitions.
- Visual pairing badges and reset controls.

### 4. Sequencing & Canonical Execution Order
- **Real-Time Hover-Swap Drag & Drop**: Drag steps up or down; slots dynamically swap positions under the cursor in real-time.
- **Precision Arrow Controls**: Move steps incrementally with dedicated ▲ / ▼ controls.
- **Dynamic Order Verification**: Visual cues indicate steps in order or out of sequence, with canonical execution revealed upon submission.

### 5. Classification & Sorting
- Multi-item category sorting (e.g., Value Types vs. Reference Types, Compile-Time vs. Runtime).
- Interactive category chips with immediate lock-in, bonus time incentives, and side-by-side correct category reveals.

---

## ⚡ Gamified Speed & Accuracy Mechanics

- **20-Second Dynamic Countdown Timer**: Capped timer creates pressure while rewarding proactive moves (+3s, +2s, +1s bonus time per interaction).
- **Persistent Header Navigation**: The timer and accuracy trend graph remain sticky at the top of the viewport, ensuring uninterrupted visibility when scrolling long questions.
- **Live Sparkline Accuracy Graph**: Renders real-time performance trends right in the header bar.
- **Streak & XP Counter**: Tracks active streaks, personal best streaks, and total session XP.
- **Interaction-Aware Halting**: Clicking anywhere in the question area immediately halts auto-advance timers so you never get skipped while reading or reviewing code.
- **500ms Click Debouncing**: Prevents accidental double-clicks from skipping questions.

---

## 🏗️ Architecture & Technology Stack

- **Framework**: [Flutter Web](https://flutter.dev/multi-platform/web) with Material 3 styling and fluid responsive scaling.
- **Typography**: [Google Fonts](https://pub.dev/packages/google_fonts) (`Plus Jakarta Sans`).
- **Client-Side Persistence**: [Hive](https://pub.dev/packages/hive) & `hive_flutter` for lightweight, offline-first storage of user accuracy, streaks, and question records.
- **Question Database**: Structured JSON engine (`assets/db.json`) containing syntax trees, question banks, and pattern match templates.
- **Automated CI/CD**: Dual deployment workflow via GitHub Actions:
  - Production deployment to **Callisto VM** via SSH key authentication, Rsync synchronization, and Nginx reloads.
  - Public static deployment to **GitHub Pages**.

---

## 💻 Local Development Setup

To run HardCode locally on your machine:

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.1.5 or higher)
- [Google Chrome](https://www.google.com/chrome/) (for Flutter Web debugging)
- [Git](https://git-scm.com/)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/holman57/hardcode.git
   cd hardcode
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on Chrome (Debug mode):**
   ```bash
   flutter run -d chrome
   ```

4. **Build for production (Web release):**
   ```bash
   flutter build web --release --base-href=/
   ```

---

## 📂 Repository Structure

```
hardcode/
├── .github/
│   └── workflows/
│       └── deploy_flutter.yml    # Dual deployment to Callisto VM & GitHub Pages
├── assets/
│   └── db.json                   # Question database & syntax templates
├── lib/
│   └── main.dart                 # Primary application entry point & UI engine
├── pubspec.yaml                  # Project configuration & package dependencies
└── README.md                     # Documentation & project overview
```

---

## 🗺️ Roadmap & Next Steps

- [ ] **Custom Language Filtering**: Select specific language subsets (e.g. only Rust + Go, or only Frontend).
- [ ] **Offline PWA Support**: Installable Progressive Web App with service worker caching.
- [ ] **Audio & Haptic Feedback**: Optional sound cues for streaks, timeouts, and correct answers.
- [ ] **Community Decks**: Support for user-submitted custom question sets via JSON schema.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE) - feel free to use, modify, and build upon it.
