# HardCode

> **Security Engineering & Automated Versioning Edition (v1.3.0)**  
> *A high-velocity flashcard, syntax memorization, and interactive 3D Knowledge Graph engine for polyglot developers.*

[![Live Demo](https://img.shields.io/badge/Live%20Demo-GitHub%20Pages-success?style=for-the-badge&logo=github)](https://holman57.github.io/hardcode/)
[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Version](https://img.shields.io/badge/Version-v1.3.0-blue?style=for-the-badge)](https://github.com/holman57/hardcode)
[![Deploy Status](https://img.shields.io/badge/Deployment-Callisto%20VM%20%2B%20GH%20Pages-orange?style=for-the-badge)](https://holman57.github.io/hardcode/)

---

## 🚀 Overview

**HardCode** is an interactive, speed-oriented question-and-answer training engine engineered to build muscle memory and instant syntax recognition across **18 distinct programming languages** and the entire spectrum of **Computer Science fundamentals**.

Powered by an interactive **3D Knowledge Graph** containing **600+ vertices**, **690+ directed relations**, and **400+ interactive questions**, HardCode dynamically challenges learners, tracks struggle patterns with **adaptive multi-tier explanations**, and celebrates learning milestones with **high-impact particle motion graphics**.

🔗 **Try the live web app:** [https://holman57.github.io/hardcode/](https://holman57.github.io/hardcode/)

---

## 🌌 3D Knowledge Graph & Progression System

The **Knowledge Graph** visualizes your entire computer science journey as an interactive spatial network:

- **Orbital Spatial 3D Projection**: Mathematical 3D camera projection with real-time yaw/pitch rotation, inertial panning, and optical depth scaling.
- **Unobstructed Viewport Centering**: Centered vertically at 38% viewport height, ensuring floating graph nodes orbit cleanly above the inspection controls.
- **High-Contrast Typography**: Text labels feature dark slate backdrop pills (`#0F172A`) with glowing cyan/amber borders and high-contrast typography, guaranteeing 100% legibility against spatial starfields.
- **Interactive Inspection Sheet**: Collapsible/expandable bottom inspector displaying topic description, mastery progress bar, prerequisite unlock chains, and connected topics.
- **Topic Mission Grinding**: Tap any unlocked node and click **"Grind Questions"** to filter questions dynamically and earn mastery points toward cascading node unlocks.

---

## 📚 Master Curriculum Hierarchy

HardCode covers 26 master domains and languages arranged in spherical orbits:

| Core Master Domain | Key Topics & Concepts Covered | Question Variety |
| :--- | :--- | :--- |
| **Computer Science** | Turing machines, decidability, Halting Problem, Chomsky hierarchy, two's complement, P vs NP | Multi-Choice, True-False, Matching, Sequencing, Sorting |
| **Computer Networking** | OSI 7-layer stack, TCP 3-way handshake, BBR vs Reno, DNS records (A/AAAA), QUIC / HTTP/3, BGP | Multi-Choice, True-False, Matching, Sequencing, Sorting |
| **Artificial Intelligence & ML** | Neural network backpropagation, ReLU vanishing gradients, self-attention \(O(N^2)\), Transformers, RLHF | Multi-Choice, True-False, Matching, Sequencing, Sorting |
| **Operating Systems & Concurrency** | Virtual memory paging, MMU, CPU scheduling, Mutexes vs Semaphores, Coffman deadlock conditions | Multi-Choice, True-False, Matching, Sequencing, Sorting |
| **Cloud Computing & Distributed Systems** | CAP theorem, Raft / Paxos consensus, Kubernetes controllers, Service Mesh (mTLS), Object vs Block storage | Multi-Choice, True-False, Matching, Sequencing, Sorting |
| **Cybersecurity & Cryptography** | Symmetric AES vs Asymmetric RSA/ECC, Argon2id password hashing, Zero Trust, TLS 1.3, OWASP Top 10 | Multi-Choice, True-False, Matching, Sequencing, Sorting |
| **Security Engineering** | Threat modeling (STRIDE/DREAD), SSDLC, SAST vs DAST, memory mitigations (ASLR, DEP/NX, Stack Canaries, ROP), Zero Trust IAM, HSM/KMS | Multi-Choice, True-False, Matching, Sequencing, Sorting |
| **System Architecture** | Von Neumann memory wall, L1/L2/L3 SRAM cache latencies, instruction pipelining hazards, TLB | Multi-Choice, True-False, Matching, Sequencing, Sorting |
| **Database Systems & Storage Engines** | ACID guarantees, Write-Ahead Logs (WAL), B+ Trees vs LSM Trees, ANSI SQL isolation levels, MVCC | Multi-Choice, True-False, Matching, Sequencing, Sorting |
| **Software Engineering & Architecture** | SOLID principles, GoF design patterns (Adapter, Strategy, Builder), CQRS, Event Sourcing, TDD | Multi-Choice, True-False, Matching, Sequencing, Sorting |
| **DevOps & Site Reliability Engineering** | SLIs, SLOs, Error Budgets, Blue-Green / Canary releases, Chaos Engineering, Metrics / Logs / Traces | Multi-Choice, True-False, Matching, Sequencing, Sorting |
| **Programming Languages & Compilers** | Lexing, AST generation, Hindley-Milner type inference, SSA intermediate representations, JIT runtimes | Multi-Choice, True-False, Matching, Sequencing, Sorting |

### Supported Programming Languages (18 Languages)
- **Systems & Performance**: Rust, C, C++, C#
- **General-Purpose & Backends**: Go, Python 3, Java, Kotlin, Scala
- **Web, Scripting & Mobile**: TypeScript, JavaScript, Dart, Swift, PHP, Ruby, Bash, PowerShell, Lua, R

---

## 🕹️ 5 Interactive Question Modalities

1. **Multiple Choice (Syntax & Conceptual)**:
   - Evaluates syntax variations against realistic distractors with four option cards and detailed conceptual breakdown explanations.
2. **True / False Rapid Evaluation**:
   - Rapid statement verification testing language edge cases, operator precedence, keyword rules, and algorithmic complexities.
3. **Term & Definition Matching**:
   - Two-column pairing linking language concepts, memory models, and execution semantics to definitions with visual pairing badges.
4. **Sequencing & Execution Order**:
   - Real-time hover-swap drag & drop sequencing and precision ▲ / ▼ incremental arrow controls to arrange execution pipelines.
5. **Sorting & Classification**:
   - Multi-item category sorting (e.g., RISC vs CISC, Symmetric vs Asymmetric, Creational vs Behavioral) with immediate visual lock-in.

---

## 🧠 Adaptive Pedagogical Explanation System

HardCode monitors learner struggle patterns per topic and automatically adapts remediation depth:
- **Tier 1 — Key Insight (1st miss)**: Concise concept refresh and essential mental models (Dwell time: 4-5.5s).
- **Tier 2 — Deep Dive Mechanics (2nd consecutive miss)**: Structural diagnostics, memory allocation semantics, and concrete code snippets (Dwell time: 7-9s).
- **Tier 3 — Architectural Masterclass (3+ consecutive misses)**: Low-level runtime deep dive, compiler translation phases, and fail-fast invariants (Dwell time: 10-13s).
- **Pedagogical Throttling**: Exponential backoff prevents annoying popups during rapid review while preserving intervention when truly needed.

---

## 🎆 Motion Graphics Milestone System

HardCode rewards focus and flow state with dynamic, hardware-accelerated particle overlays:
- **Level Start**: Expanding cosmic starburst with glowing speed rays.
- **Level Complete**: Golden particle vortex with celestial achievement banner.
- **Streak 3 (Spark)**: Amber flame particles and pulse waves.
- **Streak 5 (Inferno)**: Double-layered blazing trail with kinetic velocity sparks.
- **Streak 10 (Hyperdrive)**: Radiant shockwave ring with warp-speed light streaks.
- **Streak 20 (Singularity)**: Cosmic galaxy spiral with chromatic aberration glow.

---

## 🔄 Automated Version Management System

HardCode includes an automated semantic versioning and synchronization engine:
- **Canonical Single Source of Truth**: [`version.json`](version.json) tracks current version, incremental build numbers, and timestamped release editions.
- **Atomic Multi-Target Synchronization**: Running `python scripts/bump_version.py` atomically synchronizes:
  1. `version.json` (version, build number, updated timestamp)
  2. `pubspec.yaml` (`version: X.Y.Z+build`)
  3. `README.md` (badges and header edition subtitle)
  4. `assets/knowledge_graph.json` (`graph_version` and metadata)
  5. `assets/db.json` (`version` and metadata)
- **Automated Git Hook Integrations**:
  - **Branch Merges (`.git/hooks/post-merge`)**: Automatically increments minor version and commits the version bump whenever branches are merged.
  - **Commit Pushing (`.git/hooks/pre-push`)**: Verifies full automated test suites pass and synchronizes version tags before pushing commits to remote branches.
  - **Manual / CI Trigger**:
    ```bash
    python scripts/bump_version.py --type patch   # 1.3.0 -> 1.3.1
    python scripts/bump_version.py --type minor   # 1.3.0 -> 1.4.0
    python scripts/bump_version.py --type major   # 1.3.0 -> 2.0.0
    ```

---

## 🏗️ Architecture & Technology Stack

- **Framework**: [Flutter Web](https://flutter.dev/multi-platform/web) with Material 3 styling and responsive desktop viewport adaptation.
- **Typography**: [Google Fonts](https://pub.dev/packages/google_fonts) (`Plus Jakarta Sans` & `JetBrains Mono`).
- **Client-Side Persistence**: [Hive](https://pub.dev/packages/hive) & `hive_flutter` for lightweight, offline-first storage of progression XP, unlocked nodes, and user stats.
- **Knowledge Graph Database**: Formal graph schema (`assets/knowledge_graph.json`) with adjacency lists, type indices, and unified legacy bridging.
- **Automated Validation**: Automated Python test suite (`python -m unittest discover -s test`) running 33 automated tests in < 0.6s.

---

## 💻 Local Development Setup

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.1.5 or higher)
- [Python 3.10+](https://www.python.org/)
- [Google Chrome](https://www.google.com/chrome/)

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/holman57/hardcode.git
   cd hardcode
   ```

2. **Run automated test suite:**
   ```bash
   python -m unittest discover -s test
   ```

3. **Validate and rebuild Knowledge Graph:**
   ```bash
   python scripts/build_knowledge_graph.py --validate
   ```

4. **Launch Flutter Web:**
   ```bash
   flutter run -d chrome
   ```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE) - feel free to use, modify, and build upon it.
