import 'dart:math';

/// Representation of an explanation payload tailored to a learner's struggle level.
class ExplanationPayload {
  final String topic;
  final String subType;
  final String title;
  final int tier; // 1: Key Insight, 2: Deep Dive Mechanics, 3: Architectural Masterclass
  final String tierBadge;
  final String explanation;
  final String? codeSnippet;
  final String mentalModel;
  final int dwellSeconds;
  final int consecutiveMisses;

  const ExplanationPayload({
    required this.topic,
    required this.subType,
    required this.title,
    required this.tier,
    required this.tierBadge,
    required this.explanation,
    this.codeSnippet,
    required this.mentalModel,
    required this.dwellSeconds,
    required this.consecutiveMisses,
  });
}

/// Adaptive service that tracks user errors per topic, calibrates frequency,
/// escalates explanation depth, and calculates progressive dwell durations.
class AdaptiveExplanationService {
  AdaptiveExplanationService._internal();
  static final AdaptiveExplanationService instance =
      AdaptiveExplanationService._internal();

  // State tracking per topic
  final Map<String, int> _consecutiveMisses = {};
  final Map<String, int> _totalMisses = {};
  final Map<String, int> _totalAttempts = {};
  final Map<String, int> _explanationCount = {};
  final Map<String, int> _lastExplanationTurn = {};
  int _turnCounter = 0;

  int get turnCounter => _turnCounter;

  void recordTurn() {
    _turnCounter++;
  }

  void reset() {
    _consecutiveMisses.clear();
    _totalMisses.clear();
    _totalAttempts.clear();
    _explanationCount.clear();
    _lastExplanationTurn.clear();
    _turnCounter = 0;
  }

  /// Records an answer outcome for a given topic/subType.
  void recordOutcome({
    required String topic,
    required bool isCorrect,
  }) {
    recordTurn();
    final key = _normalizeTopic(topic);
    _totalAttempts[key] = (_totalAttempts[key] ?? 0) + 1;

    if (isCorrect) {
      _consecutiveMisses[key] = 0;
    } else {
      _consecutiveMisses[key] = (_consecutiveMisses[key] ?? 0) + 1;
      _totalMisses[key] = (_totalMisses[key] ?? 0) + 1;
    }
  }

  /// Determines whether an explanation overlay should trigger upon an incorrect answer.
  /// Uses pedagogical struggle detection and exponential backoff throttling so
  /// learners are helped when struggling without being irritated by excessive popups.
  bool shouldTriggerExplanation({
    required String topic,
    required String subType,
  }) {
    final key = _normalizeTopic(topic);
    final misses = _consecutiveMisses[key] ?? 1;
    final expCount = _explanationCount[key] ?? 0;
    final lastTurn = _lastExplanationTurn[key] ?? -999;

    // First miss on a topic: always trigger Key Insight (tier 1)
    if (expCount == 0 && misses == 1) {
      return true;
    }

    // Exponential backoff: min_interval = min(8, 2^(expCount - 1))
    final int minInterval = (expCount <= 1) ? 1 : min(8, 1 << (expCount - 1));
    final int turnsSinceLast = _turnCounter - lastTurn;

    // If user is consecutively missing (struggling repeatedly), lower threshold
    if (misses >= 2) {
      return turnsSinceLast >= max(1, minInterval ~/ 2);
    }

    return turnsSinceLast >= minInterval;
  }

  /// Builds a customized explanation payload tailored to the current error streak.
  ExplanationPayload generateExplanation({
    required String topic,
    required String subType,
    String? questionSnippet,
    String? customExplanation,
  }) {
    final key = _normalizeTopic(topic);
    final misses = _consecutiveMisses[key] ?? 1;
    final expCount = (_explanationCount[key] ?? 0) + 1;
    _explanationCount[key] = expCount;
    _lastExplanationTurn[key] = _turnCounter;

    // Escalation tier:
    // Miss 1: Tier 1 (Key Insight)
    // Miss 2: Tier 2 (Deep Dive Mechanics)
    // Miss >= 3: Tier 3 (Architectural Masterclass)
    int tier = 1;
    if (misses >= 3) {
      tier = 3;
    } else if (misses >= 2) {
      tier = 2;
    }

    // Progressive dwell time calculation:
    // Base 4s + (tier - 1)*3s + min(misses * 1.5, 5s)
    // Tier 1: 4.0s - 5.5s
    // Tier 2: 7.0s - 9.0s
    // Tier 3: 10.0s - 13.0s
    final int dwellSeconds = (4.0 + (tier - 1) * 3.0 + min(misses * 1.5, 5.0)).round();

    final topicData = _curatedTopicKnowledge[key] ?? _getDefaultTopicData(topic);
    final tierData = topicData[tier] ?? topicData[1]!;

    return ExplanationPayload(
      topic: topic,
      subType: subType,
      title: tierData['title'] ?? '$topic Concept Breakdown',
      tier: tier,
      tierBadge: tier == 3
          ? 'ARCHITECTURAL MASTERCLASS (TIER 3)'
          : tier == 2
              ? 'DEEP DIVE MECHANICS (TIER 2)'
              : 'KEY INSIGHT (TIER 1)',
      explanation: customExplanation != null && customExplanation.isNotEmpty && tier == 1
          ? '$customExplanation\n\n${tierData['explanation'] ?? ''}'
          : (tierData['explanation'] ?? 'Review the core rules of this topic.'),
      codeSnippet: tierData['codeSnippet'],
      mentalModel: tierData['mentalModel'] ?? 'Focus on fundamental semantics.',
      dwellSeconds: dwellSeconds,
      consecutiveMisses: misses,
    );
  }

  String _normalizeTopic(String topic) {
    final lower = topic.toLowerCase().trim();
    if (lower.contains('rust')) return 'rust';
    if (lower.contains('tcp') || lower.contains('network')) return 'tcp';
    if (lower.contains('cloud') || lower.contains('distributed') || lower.contains('microservice')) return 'cloud';
    if (lower.contains('var') || lower.contains('assignment') || lower.contains('declaration')) return 'variables';
    if (lower.contains('algo') || lower.contains('complexity') || lower.contains('sorting') || lower.contains('search')) return 'algorithms';
    if (lower.contains('os') || lower.contains('system') || lower.contains('operating') || lower.contains('concurrency')) return 'operating_systems';
    if (lower.contains('data') || lower.contains('struct') || lower.contains('tree') || lower.contains('stack') || lower.contains('queue')) return 'data_structures';
    return lower;
  }

  Map<int, Map<String, String>> _getDefaultTopicData(String topic) {
    return {
      1: {
        'title': '$topic: Core Principle',
        'explanation':
            'Every programming subject is grounded in explicit operational trade-offs. '
            'Read error feedback carefully and inspect argument types before selecting a solution.',
        'mentalModel': 'Trace execution step-by-step from inputs to outputs.',
        'codeSnippet': '// Example context\nresult = evaluate(input);',
      },
      2: {
        'title': '$topic: Structural Mechanics',
        'explanation':
            'Consecutive mistakes on $topic signal a mismatch in mental modeling. '
            'Verify syntax delimiters, memory allocation semantics, and evaluation order.',
        'mentalModel': 'Identify invariant state properties vs mutable state transitions.',
        'codeSnippet': '// Diagnostic pattern\nassert(valid_state == true);',
      },
      3: {
        'title': '$topic: Architectural Deep Dive',
        'explanation':
            'Mastering $topic requires understanding underlying runtime behavior: '
            'stack versus heap boundaries, compiler translation phases, and time/space constraints.',
        'mentalModel': 'Design for fail-fast validation and zero-cost abstractions.',
        'codeSnippet': '// Production implementation\nif (!precondition) throw Error("Violation");',
      },
    };
  }

  // --- Curated Multi-Tier Knowledge Base ---

  static final Map<String, Map<int, Map<String, String>>> _curatedTopicKnowledge = {
    // 1. Variable Declaration & Scope
    'variables': {
      1: {
        'title': 'Variable Declaration & Immutability',
        'explanation':
            'Variables bind human-readable identifiers to memory locations. '
            'Modern languages prioritize immutability by default to prevent unexpected side effects across concurrent routines.',
        'codeSnippet': '''// Python (Dynamic)       // Rust (Static & Immutable)
count = 42                let count: i32 = 42;

// JavaScript (Block)      // Go (Inferred)
const count = 42;          count := 42''',
        'mentalModel':
            'Think of a variable as a labeled container. Immutable variables cannot be relabeled or refilled after creation.',
      },
      2: {
        'title': 'Scoping Rules, Hoisting & Type Systems',
        'explanation':
            'Static typing verifies types at compile time (Rust, Go, C++, Java), catching bugs before deployment. '
            'Dynamic typing checks types at runtime (Python, JS). In JavaScript, `var` is function-scoped and hoisted to top, '
            'while `let` and `const` provide temporal dead zones with block scoping.',
        'codeSnippet': '''// JavaScript Temporal Dead Zone (TDZ):
console.log(a); // undefined (hoisted var)
var a = 1;

console.log(b); // ReferenceError! Cannot access before initialization
let b = 2;''',
        'mentalModel':
            'Block scope `{ ... }` creates a temporary lexical universe. Variables declared inside die when execution exits the closing brace.',
      },
      3: {
        'title': 'Memory Layout: Stack Frames vs Heap Allocations',
        'explanation':
            'Stack memory stores fixed-size, local primitive variables with O(1) allocation/deallocation as CPU stack pointers move. '
            'Heap memory stores dynamically-sized structures (vectors, objects, strings) requiring pointers and garbage collection or ownership tracking. '
            'Stack variables are destroyed automatically upon function return, whereas heap allocations persist until freed.',
        'codeSnippet': '''// C++ Memory Allocation Breakdown:
void compute() {
    int stackVal = 10;                // Stack: Fast, automated cleanup
    int* heapVal = new int(20);       // Heap: Requires explicit delete / unique_ptr
    delete heapVal;                   // Prevent memory leaks!
}''',
        'mentalModel':
            'Stack is like a tray dispenser (LIFO order, blisteringly fast). Heap is a warehouse (flexible space, requires addresses & cleanup).',
      },
    },

    // 2. Rust (Ownership, Borrowing, Lifetimes)
    'rust': {
      1: {
        'title': 'Rust: The Three Rules of Ownership',
        'explanation':
            'Rust guarantees memory safety without a garbage collector through ownership: '
            '1. Each value in Rust has an owner variable.\n'
            '2. There can only be ONE owner at any given time.\n'
            '3. When the owner goes out of scope, the value is automatically dropped (RAII).',
        'codeSnippet': '''let s1 = String::from("HardCode");
let s2 = s1; // Ownership MOVES to s2!

// println!("{}", s1); // COMPILE ERROR: value borrowed here after move
println!("{}", s2);   // VALID''',
        'mentalModel':
            'Ownership is a physical baton. If you hand it to another function or variable, you no longer hold it.',
      },
      2: {
        'title': 'Rust: References & The Borrow Checker',
        'explanation':
            'Borrowing lets you access data without taking ownership using references (`&`). '
            'The Golden Rule of Rust Concurrency: At any given scope, you may have EITHER:\n'
            '• Any number of immutable references (`&T`), OR\n'
            '• Exactly ONE mutable reference (`&mut T`). Never both simultaneously!',
        'codeSnippet': '''let mut data = vec![1, 2, 3];
let r1 = &data;     // Immutable borrow
let r2 = &data;     // Another immutable borrow (OK)

// let m = &mut data; // ERROR: cannot borrow as mutable while immutably borrowed!
println!("{}, {}", r1[0], r2[0]); // r1 & r2 scope ends here

let m = &mut data;  // NOW VALID! Exclusive mutable access
m.push(4);''',
        'mentalModel':
            'Aliasing XOR Mutability: You can share freely for reading, or lock exclusively for writing. Never write while others read.',
      },
      3: {
        'title': 'Rust: Lifetimes & Zero-Cost Abstractions',
        'explanation':
            'Lifetimes (`\'a`) ensure every reference is valid for as long as it is accessed, eliminating dangling pointers at compile time. '
            'Rust compiles abstractions (iterators, closures, pattern matching) down to bare-metal assembly matching hand-tuned C, '
            'and uses `Send` and `Sync` traits to prevent multithreaded data races at compile time.',
        'codeSnippet': '''// Explicit lifetime annotation: return reference lives as long as shortest input
fn longest<\'a>(x: &\'a str, y: &\'a str) -> &\'a str {
    if x.len() > y.len() { x } else { y }
}

// Zero-cost iterator chaining compiles directly into SIMD CPU instructions
let total: i32 = (0..1000).filter(|x| x % 2 == 0).map(|x| x * 2).sum();''',
        'mentalModel':
            'Lifetimes are compile-time provenance tags. They add zero runtime CPU cycles or memory overhead.',
      },
    },

    // 3. TCP & Networking
    'tcp': {
      1: {
        'title': 'TCP vs UDP: Reliability vs Latency',
        'explanation':
            'TCP (Transmission Control Protocol) is connection-oriented, reliable, and ordered. It guarantees no lost packets via acknowledgments. '
            'UDP (User Datagram Protocol) is connectionless and fire-and-forget, trading delivery guarantees for minimal latency (ideal for video streaming and gaming).',
        'codeSnippet': '''// TCP: Reliable stream           // UDP: Fast datagrams
SYN -> SYN-ACK -> ACK             Send packet -> (no ack)
Guaranteed in-order delivery      Fast, low overhead, packet loss possible''',
        'mentalModel':
            'TCP is a certified courier requiring signatures. UDP is a postcard dropped in the wind.',
      },
      2: {
        'title': 'TCP 3-Way Handshake & Flow Control',
        'explanation':
            'Before exchanging data, client and server establish synchronization via 3 packets: '
            '1. Client sends `SYN` (Synchronize Sequence Number).\n'
            '2. Server replies `SYN-ACK`.\n'
            '3. Client acknowledges with `ACK`.\n'
            'Flow control uses a Sliding Window to ensure a fast sender never overwhelms a slow receiver buffer.',
        'codeSnippet': '''Client                    Server
  |                         |
  |--- SYN (seq=x) -------->|  (Initiate connection)
  |<-- SYN-ACK (seq=y,ack=x+1) (Acknowledge + syn)
  |--- ACK (ack=y+1) ------>|  (Connection ESTABLISHED)
  |                         |''',
        'mentalModel':
            'The 3-way handshake is two people on radio: "Can you hear me?", "Yes I hear you, can you hear me?", "Yes loud and clear!"',
      },
      3: {
        'title': 'TCP Congestion Control & Head-of-Line Blocking',
        'explanation':
            'TCP implements AIMD (Additive Increase, Multiplicative Decrease) and Slow Start to regulate internet traffic. '
            'However, because TCP enforces strict in-order stream delivery, a single dropped packet causes all subsequent packets '
            'to wait in queue—this is Head-of-Line (HoL) blocking. Modern protocols like QUIC (HTTP/3) run over UDP with independent streams to eliminate HoL blocking.',
        'codeSnippet': '''// TCP Congestion Window (cwnd) mechanics:
Slow Start:         cwnd doubles every RTT (exponential growth: 1 -> 2 -> 4 -> 8)
Congestion Avoid:   cwnd increases by 1 MSS per RTT (linear growth)
Packet Loss Event:  ssthresh = cwnd / 2; cwnd cuts sharply (multiplicative decrease)''',
        'mentalModel':
            'HoL blocking is a single customer fumbling their wallet at the grocery checkout, halting everyone behind them.',
      },
    },

    // 4. Cloud Computing & Distributed Architecture
    'cloud': {
      1: {
        'title': 'Cloud Scalability: Horizontal vs Vertical',
        'explanation':
            'Vertical scaling (Scale Up) adds more RAM/CPU cores to a single machine; it has a hard hardware ceiling and single point of failure. '
            'Horizontal scaling (Scale Out) adds more commodity instances behind a load balancer, providing virtually unlimited elasticity and fault tolerance.',
        'codeSnippet': '''// Vertical Scaling:                // Horizontal Scaling:
[ 4-Core CPU ] -> [ 64-Core CPU ]   [ App Instance ]   [ App Instance ]
(Hardware limit reached!)                    \\       /
                                           [ Load Balancer ]''',
        'mentalModel':
            'Vertical scaling is buying a bigger truck. Horizontal scaling is building a fleet of vans.',
      },
      2: {
        'title': 'The CAP Theorem & Load Balancing',
        'explanation':
            'Eric Brewer\'s CAP Theorem proves that a distributed data store can satisfy at most TWO of three guarantees during network failures: '
            '• Consistency (C): Every read receives the most recent write.\n'
            '• Availability (A): Every non-failing node returns a non-error response.\n'
            '• Partition Tolerance (P): The system functions despite dropped network packets.\n'
            'Because network partitions are inevitable on the cloud, systems must choose CP (e.g. Spanner, Redis) or AP (e.g. Cassandra, DynamoDB).',
        'codeSnippet': '''// Load Balancing Layers:
Layer 4 (Transport):   Routes raw TCP/UDP packets by IP + Port (high throughput).
Layer 7 (Application): Inspects HTTP headers, cookies, and URLs for smart routing.''',
        'mentalModel':
            'When the network splits into two islands, you either refuse answers to stay consistent (CP), or give best-guess answers to stay available (AP).',
      },
      3: {
        'title': 'Eventual Consistency, Microservices & Circuit Breakers',
        'explanation':
            'Microservice architectures isolate failures into independent deployable units. '
            'To prevent cascading outages when a downstream service fails, Circuit Breakers trip into an OPEN state, '
            'returning fallback cached responses without waiting on timeouts. '
            'Distributed storage achieves eventual consistency through vector clocks, gossip protocols, and CRDTs.',
        'codeSnippet': '''// Circuit Breaker State Machine:
CLOSED   --[Failure rate > 50%]---> OPEN (Fail fast, zero wait)
  ^                                   |
  |---[Success probe passes]--- HALF-OPEN <--[Sleep window expires]''',
        'mentalModel':
            'A circuit breaker in software is identical to the electrical breaker in your home: it shuts off a smoking circuit to keep the whole house from burning down.',
      },
    },

    // 5. Data Structures & Algorithms
    'algorithms': {
      1: {
        'title': 'Asymptotic Complexity: The Big-O Scale',
        'explanation':
            'Big-O notation describes how execution time or memory space scales as input size N grows to infinity. '
            'Hierarchy from fastest to slowest:\n'
            'O(1) Constant < O(log N) Logarithmic < O(N) Linear < O(N log N) Linearithmic < O(N^2) Quadratic < O(2^N) Exponential.',
        'codeSnippet': '''O(1):       Array lookup by index
O(log N):   Binary search in sorted array
O(N):       Linear scan through unsorted list
O(N log N): Merge sort / Quick sort average
O(N^2):     Nested loops (Bubble sort)''',
        'mentalModel':
            'If N doubles: O(N) doubles work, O(N^2) quadruples work, O(log N) only adds a single extra step!',
      },
      2: {
        'title': 'Hash Tables & Collision Resolution',
        'explanation':
            'Hash tables achieve average O(1) lookups by hashing keys into bucket indices. '
            'When two distinct keys hash to the same bucket (collision), systems resolve via: '
            '1. Separate Chaining (linked lists or red-black trees at each bucket).\n'
            '2. Open Addressing (linear or quadratic probing for the next empty bucket).\n'
            'Maintaining a load factor below 0.75 ensures O(1) performance.',
        'codeSnippet': '''// Separate Chaining:
Bucket 4 -> [ "keyA": 10 ] -> [ "keyB": 42 ] -> null

// Open Addressing (Linear Probing):
index = hash(key) % size;
while (table[index] is occupied) index = (index + 1) % size;''',
        'mentalModel':
            'Hash tables are mailboxes. If two letters arrive for box #7, chaining hangs a bag beneath it; probing places it in box #8.',
      },
      3: {
        'title': 'Tree Balancing & Cache Locality',
        'explanation':
            'Unbalanced Binary Search Trees degenerate into O(N) linked lists. Self-balancing trees (AVL, Red-Black) '
            'perform tree rotations to guarantee O(log N) worst-case lookups. '
            'However, modern CPU architecture heavily favors Cache Locality: contiguous arrays (Vectors) often outperform '
            'pointer-chasing node trees even with asymptotically worse insertions due to CPU L1/L2 prefetching.',
        'codeSnippet': '''// AVL Tree Rotation (Left-Left violation -> Right Rotate):
      z                               y
     / \\                            /   \\
    y   T4   --- Right Rotate ---> x     z
   / \\                            / \\   / \\
  x   T3                         T1 T2 T3 T4''',
        'mentalModel':
            'CPUs read memory in 64-byte cache lines. A continuous flat array rides the bullet train; chasing pointers walks from door to door.',
      },
    },

    // 6. Operating Systems & Concurrency
    'operating_systems': {
      1: {
        'title': 'Processes vs Threads',
        'explanation':
            'A Process is an isolated execution environment with its own private virtual memory space and file descriptors. '
            'A Thread is a lightweight execution unit inside a process that shares the address space and heap with other threads in the same process.',
        'codeSnippet': '''Process A (Memory: 0x0000 - 0x7FFF)
  ├── Thread 1 (Own stack, shared heap)
  └── Thread 2 (Own stack, shared heap)

Process B (Isolated Memory: 0x0000 - 0x7FFF)
  └── Thread 3 (Cannot read Process A directly)''',
        'mentalModel':
            'Processes are separate office buildings. Threads are coworkers sharing the same open office floor.',
      },
      2: {
        'title': 'Synchronization: Mutexes, Semaphores & Race Conditions',
        'explanation':
            'When multiple threads read and write shared data without synchronization, a Race Condition occurs. '
            'A Mutex (Mutual Exclusion) provides an exclusive binary lock (only the lock owner can unlock). '
            'A Counting Semaphore manages access to a pool of N identical resources.',
        'codeSnippet': '''// Race condition avoidance:
pthread_mutex_lock(&lock);
shared_counter++; // Critical section (guaranteed mutual exclusion)
pthread_mutex_unlock(&lock);''',
        'mentalModel':
            'A Mutex is a bathroom key: only one person holds it at a time. A Semaphore is a parking garage display showing spaces left.',
      },
      3: {
        'title': 'Virtual Memory, Paging & The 4 Coffman Deadlock Conditions',
        'explanation':
            'CPUs use the MMU (Memory Management Unit) and Page Tables to translate virtual addresses into physical DRAM frames. '
            'A Page Fault pauses the process while the kernel loads the requested page from disk swap space. '
            'Deadlocks freeze systems forever when all 4 Coffman conditions hold simultaneously:\n'
            '1. Mutual Exclusion, 2. Hold and Wait, 3. No Preemption, 4. Circular Wait.',
        'codeSnippet': '''// Eliminating Deadlock via Lock Ordering:
// Thread 1 and Thread 2 both acquire Lock A before Lock B!
// This breaks Coffman Condition #4 (Circular Wait).''',
        'mentalModel':
            'To prevent deadlock in a four-way street intersection, all drivers must yield by the exact same priority rule.',
      },
    },
  };
}
