#!/usr/bin/env python3
"""
Batch 2 Curriculum & Question Expansion.
Expands:
- DevOps & Site Reliability Engineering (New Domain)
- Software Engineering
- Programming Languages & Compilers
- Computer Science (Foundations)
- Operating Systems & Concurrency
- Algorithms & Complexity
- Data Structures
"""

import json
from pathlib import Path

def get_batch2_data():
    return {
        # --- NEW MASTER DOMAIN 2: DevOps & Site Reliability Engineering ---
        "DevOps & Site Reliability Engineering": {
            "introduction": "Site Reliability Engineering (SRE) applies software engineering principles to operations, infrastructure automation, observability, and incident lifecycle management.",
            "remediation": "Focus on Service Level Indicators (SLIs), Service Level Objectives (SLOs), error budgets, container orchestration primitives, and immutable infrastructure.",
            "deep_dive": "SRE targets the trade-off between deployment velocity and system reliability using Error Budgets: 100% - SLO. When the error budget is exhausted, deployments freeze in favor of stability. Infrastructure as Code (Terraform, Kubernetes Operator pattern) enables declarative convergence toward desired state via reconciliation control loops.",
            "questions": {
                "True-False": [
                    {
                        "statement": "An Error Budget is calculated directly from a Service Level Objective (SLO), representing the allowed amount of downtime or bad requests.",
                        "is_true": True,
                        "explanation": "If the SLO is 99.9% availability, the monthly Error Budget is 0.1% (approx. 43 minutes of allowed failure)."
                    },
                    {
                        "statement": "In Continuous Delivery (CD), every code commit that passes automated testing must be deployed to production immediately without human gates.",
                        "is_true": False,
                        "explanation": "Continuous Deployment deploys automatically; Continuous Delivery ensures code is ALWAYS in a deployable state, but deployment to production may require manual authorization."
                    },
                    {
                        "statement": "A Canary deployment routes a small percentage of real production traffic to a new service version before gradually rolling it out to all users.",
                        "is_true": True,
                        "explanation": "Canary releases validate performance and error rates on a tiny cohort to minimize the blast radius of unforeseen bugs."
                    },
                    {
                        "statement": "In Kubernetes, a ReplicaSet ensures that a specified number of identical pod replicas are running at all times.",
                        "is_true": True,
                        "explanation": "The ReplicaSet controller continuously monitors the current running count and reconciles against the desired pod count."
                    },
                    {
                        "statement": "Immutable Infrastructure updates production servers by logging in via SSH and running package upgrade scripts in place.",
                        "is_true": False,
                        "explanation": "Immutable infrastructure never mutates running servers; updates replace existing instances with newly built, versioned virtual machine or container images."
                    },
                    {
                        "statement": "The three pillars of observability in distributed cloud systems are Metrics, Logs, and Distributed Traces.",
                        "is_true": True,
                        "explanation": "Metrics track aggregated counters/gauges, logs record discrete events, and distributed traces track request context across microservices."
                    }
                ],
                "Multi-Choice": [
                    {
                        "question": "What is the primary difference between a Service Level Indicator (SLI) and a Service Level Objective (SLO)?",
                        "choices": [
                            "An SLI is a quantifiable metric of actual performance (e.g. latency); an SLO is the target goal agreed upon (e.g. 99% of requests < 200ms)",
                            "An SLI is a legal financial contract with customers; an SLO is an internal debugging tool",
                            "An SLI only applies to hardware; an SLO applies to databases",
                            "An SLO is recorded by Prometheus; an SLI cannot be measured"
                        ],
                        "correct_index": 0,
                        "explanation": "SLI is 'what is measured right now', SLO is 'the target reliability boundary we aim to maintain'."
                    },
                    {
                        "question": "Which deployment strategy maintains two identical production environments, switching active router traffic instantly from the old version to the new version?",
                        "choices": [
                            "Blue-Green Deployment",
                            "Rolling Update",
                            "Canary Deployment",
                            "Shadow Deployment"
                        ],
                        "correct_index": 0,
                        "explanation": "Blue-Green keeps one idle environment (Green) and one active (Blue). Switching load balancer target enables instantaneous rollback."
                    },
                    {
                        "question": "In the Kubernetes control plane, which component is responsible for assigning newly created pods to optimal worker nodes based on resource constraints?",
                        "choices": [
                            "kube-scheduler",
                            "kube-apiserver",
                            "kube-controller-manager",
                            "kubelet"
                        ],
                        "correct_index": 0,
                        "explanation": "kube-scheduler filters and scores nodes to decide the best node placement for unscheduled pods."
                    },
                    {
                        "question": "What is the primary objective of Chaos Engineering practices (e.g. Chaos Monkey)?",
                        "choices": [
                            "Proactively inject turbulent failures in production to build resilience before catastrophic outages occur",
                            "Randomly corrupt database tables to verify backup restore speeds",
                            "Disable firewall ports during peak business hours",
                            "Delete git branches to test developer memory"
                        ],
                        "correct_index": 0,
                        "explanation": "Chaos engineering systematically tests hypothesis about system fault tolerance by simulating instance, network, or disk failures."
                    }
                ],
                "Matching": [
                    {
                        "prompt": "Match each DevOps / SRE tool with its primary function",
                        "pairs": {
                            "Terraform": "Declarative multi-cloud Infrastructure as Code (IaC) provisioning",
                            "Prometheus": "Time-series monitoring, alerting, and metric scraping system",
                            "Docker": "OS-level virtualization packaging apps into portable container images",
                            "ArgoCD": "Declarative GitOps continuous delivery tool for Kubernetes",
                            "Jaeger / OpenTelemetry": "Distributed tracing framework across microservice call graphs"
                        }
                    },
                    {
                        "prompt": "Match each SRE reliability term with its core concept",
                        "pairs": {
                            "MTTR (Mean Time to Recover)": "Average duration required to restore service after an outage",
                            "MTTD (Mean Time to Detect)": "Average time from issue inception until monitoring alerts fire",
                            "Toil": "Manual, repetitive, operational work that could be automated by software",
                            "Blast Radius": "The maximum scope of impact or affected users if a failure occurs",
                            "Error Budget": "The threshold of permissible unreliability during a given time window"
                        }
                    }
                ],
                "Sequencing": [
                    {
                        "prompt": "Order the lifecycle phases of an automated CI/CD deployment pipeline",
                        "ordered_sequence": [
                            "Developer pushes code commit and opens pull request",
                            "CI server checks out code, runs linter, and builds executable artifacts",
                            "Unit, integration, and security static analysis (SAST) test suites execute",
                            "Container image is built, tagged with git commit SHA, and pushed to registry",
                            "CD engine deploys image to staging, runs smoke tests, and promotes to production"
                        ]
                    },
                    {
                        "prompt": "Order the incident response steps when a critical production alert fires",
                        "ordered_sequence": [
                            "On-call engineer acknowledges alert and establishes incident communication channel",
                            "Initial triage determines severity, blast radius, and triggers rollback or mitigation",
                            "Service health is stabilized (traffic rerouted, canary halted, or caches flushed)",
                            "Detailed root cause investigation inspects logs, traces, and metrics",
                            "Blameless post-mortem document is drafted to identify systemic preventative action items"
                        ]
                    }
                ],
                "Sorting-Classification": [
                    {
                        "prompt": "Classify the following telemetry data into Metrics, Logs, or Traces",
                        "categories": [
                            "Metrics",
                            "Logs",
                            "Traces"
                        ],
                        "items": {
                            "Metrics": [
                                "http_requests_total (Counter)",
                                "cpu_utilization_percent (Gauge)",
                                "request_duration_seconds (Histogram)"
                            ],
                            "Logs": [
                                "{\"level\":\"ERROR\",\"msg\":\"database connection refused\"}",
                                "[INFO] User 1042 successfully authenticated via OAuth"
                            ],
                            "Traces": [
                                "Span: checkout-service -> payment-gateway (142ms)",
                                "TraceParent HTTP Header W3C propagation context"
                            ]
                        }
                    }
                ]
            }
        },

        # --- EXPANSION FOR Software Engineering ---
        "Software Engineering": {
            "new_tf": [
                {
                    "statement": "The Single Responsibility Principle (SRP) states that a class or module should have one, and only one, reason to change.",
                    "is_true": True,
                    "explanation": "SRP minimizes coupling and isolates the impact of requirement changes."
                },
                {
                    "statement": "In Test-Driven Development (TDD), production code is written first, and unit tests are written afterwards during QA staging.",
                    "is_true": False,
                    "explanation": "TDD follows Red-Green-Refactor: write a failing test first, write minimal code to pass, then refactor."
                },
                {
                    "statement": "The Open/Closed Principle (OCP) states that software entities should be open for extension, but closed for modification.",
                    "is_true": True,
                    "explanation": "New functionality should be added via inheritance, interfaces, or composition without editing existing tested source code."
                },
                {
                    "statement": "Event-driven architecture with CQRS decouples write operations (commands) from read operations (queries), allowing independent scaling.",
                    "is_true": True,
                    "explanation": "CQRS enables optimized read models (e.g. Elasticsearch or Redis) distinct from transactional write schemas."
                }
            ],
            "new_mc": [
                {
                    "question": "Which Gang of Four (GoF) structural design pattern provides an alternative interface to an existing class to make incompatible interfaces work together?",
                    "choices": [
                        "Adapter Pattern",
                        "Singleton Pattern",
                        "Observer Pattern",
                        "Factory Method Pattern"
                    ],
                    "correct_index": 0,
                    "explanation": "The Adapter pattern converts the interface of a class into another interface clients expect."
                },
                {
                    "question": "What is the primary hazard of using the Singleton design pattern across multi-threaded applications?",
                    "choices": [
                        "Global mutable state that introduces concurrency race conditions and hinders isolated unit testing",
                        "Increases CPU clock cycle duration by 50%",
                        "Prevents compile-time type checking in C++ and Java",
                        "Forces the OS kernel into single-user recovery mode"
                    ],
                    "correct_index": 0,
                    "explanation": "Singletons introduce tightly coupled global state that makes mocking and parallel test execution difficult and error-prone."
                }
            ],
            "new_matching": [
                {
                    "prompt": "Match each SOLID principle with its core motto",
                    "pairs": {
                        "Single Responsibility (S)": "A module should have only one reason to change",
                        "Open/Closed (O)": "Open for extension, closed for modification",
                        "Liskov Substitution (L)": "Subtypes must be substitutable for their base types without altering correctness",
                        "Interface Segregation (I)": "Clients should not be forced to depend on interfaces they do not use",
                        "Dependency Inversion (D)": "High-level modules should depend on abstractions, not concrete details"
                    }
                }
            ],
            "new_sequencing": [
                {
                    "prompt": "Order the phases of the Red-Green-Refactor TDD cycle",
                    "ordered_sequence": [
                        "Write a small, focused unit test asserting a specific new behavior",
                        "Run test runner and verify the test fails for the expected reason (Red)",
                        "Write the minimal possible production code necessary to make the test pass (Green)",
                        "Refactor code to improve readability and remove duplication while tests remain green",
                        "Commit changes and proceed to the next requirement increment"
                    ]
                }
            ],
            "new_sorting": [
                {
                    "prompt": "Classify the following GoF design patterns into Creational or Behavioral",
                    "categories": [
                        "Creational",
                        "Behavioral"
                    ],
                    "items": {
                        "Creational": [
                            "Builder Pattern",
                            "Abstract Factory Pattern",
                            "Prototype Pattern"
                        ],
                        "Behavioral": [
                            "Observer Pattern",
                            "Strategy Pattern",
                            "Chain of Responsibility Pattern"
                        ]
                    }
                }
            ]
        },

        # --- EXPANSION FOR Programming Languages & Compilers ---
        "Programming Languages & Compilers": {
            "new_tf": [
                {
                    "statement": "An Abstract Syntax Tree (AST) retains all original source code whitespace, indentation, and comments from the raw token stream.",
                    "is_true": False,
                    "explanation": "ASTs discard syntactic trivia like whitespace, parentheses, and comments, preserving only structural semantic hierarchy."
                },
                {
                    "statement": "Just-In-Time (JIT) compilers profile running bytecode and compile hot code paths directly into native machine code at runtime.",
                    "is_true": True,
                    "explanation": "JIT runtimes (V8, JVM HotSpot) achieve near-C speeds by optimizing frequently executed loops using runtime profiling data."
                },
                {
                    "statement": "In statically typed languages with Hindley-Milner type inference (e.g. Haskell, OCaml, Rust), compilers can infer types without explicit type annotations.",
                    "is_true": True,
                    "explanation": "Hindley-Milner type systems mathematically deduce the most general principal type for every expression."
                }
            ],
            "new_mc": [
                {
                    "question": "Which compiler phase converts a linear stream of characters into a structured sequence of lexical tokens (e.g. keywords, identifiers, operators)?",
                    "choices": [
                        "Lexical Analysis (Scanner / Tokenizer)",
                        "Semantic Analysis (Type Checker)",
                        "Intermediate Code Generation",
                        "Register Allocation"
                    ],
                    "correct_index": 0,
                    "explanation": "Lexing splits the raw text file into tokens according to regular expression definitions."
                },
                {
                    "question": "What is the primary advantage of Static Single Assignment (SSA) form in modern compiler intermediate representations (like LLVM IR)?",
                    "choices": [
                        "Every variable is assigned exactly once, simplifying dead code elimination, constant propagation, and register allocation",
                        "Eliminates the need for CPU instruction caches",
                        "Automatically parallelizes sequential for-loops onto GPU threads",
                        "Prevents stack overflow exceptions at compile time"
                    ],
                    "correct_index": 0,
                    "explanation": "In SSA form, variables are renamed per assignment (e.g. x1, x2), turning data flow analysis into clean graph algorithms."
                }
            ],
            "new_matching": [
                {
                    "prompt": "Match each compiler compilation stage with its output artifact",
                    "pairs": {
                        "Lexer": "Token stream (Keywords, Identifiers, Literals)",
                        "Parser": "Abstract Syntax Tree (AST)",
                        "Type Checker": "Decorated / Typed Abstract Syntax Tree",
                        "Intermediate Representation Generator": "LLVM IR / 3-Address Code",
                        "Code Generator": "Target machine assembly or native machine code"
                    }
                }
            ],
            "new_sequencing": [
                {
                    "prompt": "Order the standard pipeline stages of an optimizing compiler front-end and back-end",
                    "ordered_sequence": [
                        "Lexical Analysis scanning source characters into tokens",
                        "Syntactic Parsing building the Abstract Syntax Tree (AST)",
                        "Semantic Analysis verifying types, scopes, and symbol tables",
                        "Intermediate Representation (IR) generation in SSA form",
                        "Target machine code generation and hardware register allocation"
                    ]
                }
            ],
            "new_sorting": [
                {
                    "prompt": "Classify the following languages into Statically Typed or Dynamically Typed",
                    "categories": [
                        "Statically Typed",
                        "Dynamically Typed"
                    ],
                    "items": {
                        "Statically Typed": [
                            "Rust",
                            "Go",
                            "TypeScript"
                        ],
                        "Dynamically Typed": [
                            "Python",
                            "JavaScript",
                            "Ruby"
                        ]
                    }
                }
            ]
        },

        # --- EXPANSION FOR Computer Science (Foundations) ---
        "Computer Science": {
            "new_tf": [
                {
                    "statement": "Turing completeness means a computing system can simulate any single-taped Turing machine given sufficient time and memory.",
                    "is_true": True,
                    "explanation": "A system is Turing complete if it can compute any computable function (Church-Turing thesis)."
                },
                {
                    "statement": "The Halting Problem proven by Alan Turing is decidable: an algorithm exists that can determine if any arbitrary program will halt.",
                    "is_true": False,
                    "explanation": "Turing proved by diagonalization that no general algorithm can decide whether arbitrary programs will halt."
                },
                {
                    "statement": "Two's complement representation allows binary addition and subtraction to be executed by identical CPU ALU hardware.",
                    "is_true": True,
                    "explanation": "Two's complement represents negative numbers such that addition works uniformly without sign-magnitude special cases."
                }
            ],
            "new_mc": [
                {
                    "question": "What is the P versus NP problem in theoretical computer science?",
                    "choices": [
                        "Whether every problem whose solution can be quickly verified in polynomial time can also be solved in polynomial time",
                        "Whether parallel processors are faster than quantum computers",
                        "Whether pointer arithmetic is safer than reference counting",
                        "Whether Python can be compiled to native ARM64 assembly"
                    ],
                    "correct_index": 0,
                    "explanation": "P is the set of problems solvable in polynomial time; NP is the set of problems verifiable in polynomial time."
                }
            ],
            "new_matching": [
                {
                    "prompt": "Match each foundational computer science pioneer with their milestone breakthrough",
                    "pairs": {
                        "Alan Turing": "Formalized computation with the Turing machine and proved the Halting Problem",
                        "Claude Shannon": "Information theory, entropy, and digital circuit logic design",
                        "John von Neumann": "Stored-program computer architecture and game theory",
                        "Edsger Dijkstra": "Shortest-path algorithm, semaphores, and structured programming",
                        "Donald Knuth": "The Art of Computer Programming, TeX, and algorithm analysis"
                    }
                }
            ],
            "new_sequencing": [
                {
                    "prompt": "Order the hierarchy of formal grammars in the Chomsky Hierarchy from most restrictive to most general",
                    "ordered_sequence": [
                        "Type-3: Regular Grammars (Finite State Automata)",
                        "Type-2: Context-Free Grammars (Pushdown Automata)",
                        "Type-1: Context-Sensitive Grammars (Linear-Bounded Automata)",
                        "Type-0: Unrestricted Grammars (Turing Machines)"
                    ]
                }
            ],
            "new_sorting": [
                {
                    "prompt": "Classify the following complexity classes into Deterministic or Non-Deterministic / Hard",
                    "categories": [
                        "Deterministic Polynomial",
                        "NP / Hard / Exponential"
                    ],
                    "items": {
                        "Deterministic Polynomial": [
                            "O(1) Constant Time",
                            "O(log N) Logarithmic Time",
                            "O(N^3) Cubic Time"
                        ],
                        "NP / Hard / Exponential": [
                            "Travelling Salesperson Problem (Exact)",
                            "Boolean Satisfiability (3-SAT)",
                            "O(2^N) Exponential Subsets"
                        ]
                    }
                }
            ]
        }
    }


def main():
    db_path = Path("assets/db.json")
    if not db_path.exists():
        print(f"Error: {db_path} does not exist.")
        return

    with open(db_path, "r", encoding="utf-8") as f:
        db = json.load(f)

    curr = db.setdefault("Curriculum", {})
    expansions = get_batch2_data()
    total_added = 0

    # 1. Add new domain
    for domain_name, data in expansions.items():
        if domain_name not in curr:
            curr[domain_name] = data
            qs = data.get("questions", {})
            q_count = sum(len(v) for v in qs.values())
            total_added += q_count
            print(f"[NEW DOMAIN] Added '{domain_name}' with {q_count} questions.")
        else:
            domain_qs = curr[domain_name].setdefault("questions", {})
            if "new_tf" in data:
                domain_qs.setdefault("True-False", []).extend(data["new_tf"])
                total_added += len(data["new_tf"])
                print(f"[EXPANSION] Added {len(data['new_tf'])} True-False to '{domain_name}'.")
            if "new_mc" in data:
                domain_qs.setdefault("Multi-Choice", []).extend(data["new_mc"])
                total_added += len(data["new_mc"])
                print(f"[EXPANSION] Added {len(data['new_mc'])} Multi-Choice to '{domain_name}'.")
            if "new_matching" in data:
                domain_qs.setdefault("Matching", []).extend(data["new_matching"])
                total_added += len(data["new_matching"])
                print(f"[EXPANSION] Added {len(data['new_matching'])} Matching to '{domain_name}'.")
            if "new_sequencing" in data:
                domain_qs.setdefault("Sequencing", []).extend(data["new_sequencing"])
                total_added += len(data["new_sequencing"])
                print(f"[EXPANSION] Added {len(data['new_sequencing'])} Sequencing to '{domain_name}'.")
            if "new_sorting" in data:
                domain_qs.setdefault("Sorting-Classification", []).extend(data["new_sorting"])
                total_added += len(data["new_sorting"])
                print(f"[EXPANSION] Added {len(data['new_sorting'])} Sorting to '{domain_name}'.")

    db["version"] = 8
    print(f"\nBatch 2 total new questions added: {total_added}")

    with open(db_path, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2, ensure_ascii=False)
    print(f"Saved expanded database to {db_path} (version 8)")


if __name__ == "__main__":
    main()
