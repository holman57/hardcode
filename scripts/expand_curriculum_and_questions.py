#!/usr/bin/env python3
"""
Curriculum and Knowledge Graph Expansion Engine.
Massively expands HardCode question bank and topics across:
- Computer Science & Architecture
- Computer Networking & Protocols
- Artificial Intelligence & Machine Learning
- Operating Systems & Concurrency
- Cloud Computing & Distributed Consensus
- Cybersecurity & Cryptography
- Database Systems & Storage Engines
- Software Engineering & Design Patterns
- Programming Languages & Compilers
"""

import json
from pathlib import Path

def get_expansion_data():
    return {
        # --- NEW MASTER DOMAIN 1: Cybersecurity & Cryptography ---
        "Cybersecurity & Cryptography": {
            "introduction": "Cybersecurity investigates threat modeling, public-key cryptography, authorization protocols, and defenses against memory and network exploits.",
            "remediation": "Focus on asymmetric vs symmetric key distribution, cryptographic salt uniqueness, and defense-in-depth principles (Zero Trust).",
            "deep_dive": "Cryptographic security relies on computationally intractable mathematical problems (integer factorization in RSA, discrete log in ECC Curve25519). Modern security enforces TLS 1.3 with forward secrecy, memory-safe languages to eliminate 70% of CVE buffer overflows, and authenticated encryption with associated data (AEAD, AES-GCM).",
            "questions": {
                "True-False": [
                    {
                        "statement": "Symmetric encryption algorithms like AES use the exact same cryptographic key for both encryption and decryption.",
                        "is_true": True,
                        "explanation": "AES is a symmetric cipher where sender and receiver share the same secret key."
                    },
                    {
                        "statement": "MD5 and SHA-1 are recommended today for secure cryptographic password hashing in modern production applications.",
                        "is_true": False,
                        "explanation": "MD5 and SHA-1 suffer from collision attacks and lack memory-hardness. Modern apps must use Argon2id or bcrypt."
                    },
                    {
                        "statement": "Perfect Forward Secrecy (PFS) ensures that compromise of a server's long-term private key cannot decrypt previously recorded network traffic.",
                        "is_true": True,
                        "explanation": "PFS generates unique ephemeral session keys (ECDHE) for each TLS session so old traffic remains indecipherable."
                    },
                    {
                        "statement": "In a SQL injection attack, attackers exploit flaws where user inputs are concatenated directly into raw database command strings.",
                        "is_true": True,
                        "explanation": "Parameterized queries and prepared statements completely neutralize SQL injection by separating code from data."
                    },
                    {
                        "statement": "Zero Trust network architecture assumes that any device inside the internal corporate network firewall can be inherently trusted.",
                        "is_true": False,
                        "explanation": "Zero Trust operates under 'Never Trust, Always Verify', enforcing mutual TLS and per-request authorization internally."
                    },
                    {
                        "statement": "Cross-Site Scripting (XSS) occurs when an application includes untrusted data in a web page without proper escaping, allowing malicious script execution.",
                        "is_true": True,
                        "explanation": "XSS allows attackers to hijack session cookies, deface DOM elements, or redirect users to malicious endpoints."
                    },
                    {
                        "statement": "A cryptographic salt should be kept top-secret alongside the server's master root key in an encrypted vault.",
                        "is_true": False,
                        "explanation": "Salts do not need to be secret; their sole purpose is uniqueness per user to defeat precomputed rainbow tables."
                    },
                    {
                        "statement": "Elliptic Curve Cryptography (ECC) achieves equivalent security to RSA with significantly smaller key sizes (e.g. 256-bit ECC ≈ 3072-bit RSA).",
                        "is_true": True,
                        "explanation": "ECC provides equal security with vastly shorter keys, reducing CPU cycles and network transmission overhead."
                    }
                ],
                "Multi-Choice": [
                    {
                        "question": "Which password hashing algorithm was selected as the official winner of the Password Hashing Competition for its memory-hard defense against ASIC/GPU attacks?",
                        "choices": [
                            "Argon2id",
                            "PBKDF2-HMAC-SHA256",
                            "MD5-Crypt",
                            "SHA-512"
                        ],
                        "correct_index": 0,
                        "explanation": "Argon2id combines data-independent and data-dependent memory access to resist both side-channel and GPU/ASIC brute force attacks."
                    },
                    {
                        "question": "Which HTTP security header instructs browsers to strictly communicate with a domain exclusively over HTTPS for a defined duration?",
                        "choices": [
                            "Strict-Transport-Security (HSTS)",
                            "Content-Security-Policy (CSP)",
                            "X-Frame-Options",
                            "Access-Control-Allow-Origin"
                        ],
                        "correct_index": 0,
                        "explanation": "HSTS eliminates SSL stripping attacks by forcing browsers to rewrite all HTTP URLs to HTTPS before making network requests."
                    },
                    {
                        "question": "What type of attack exploits race conditions between the verification of a resource condition and the subsequent use of that resource?",
                        "choices": [
                            "Time-of-Check to Time-of-Use (TOCTOU)",
                            "Buffer Overflow",
                            "Cross-Site Request Forgery (CSRF)",
                            "Server-Side Request Forgery (SSRF)"
                        ],
                        "correct_index": 0,
                        "explanation": "TOCTOU is a concurrency vulnerability where state changes between permission validation and operation execution."
                    },
                    {
                        "question": "In asymmetric cryptography, which key must the sender use to digitally sign a message digest so recipients can verify authenticity?",
                        "choices": [
                            "The sender's private key",
                            "The recipient's public key",
                            "The sender's public key",
                            "A pre-shared symmetric key"
                        ],
                        "correct_index": 0,
                        "explanation": "A digital signature is created using the sender's private key and verified by anyone using the sender's public key."
                    },
                    {
                        "question": "Which defense completely prevents Cross-Site Request Forgery (CSRF) in modern state-changing POST requests?",
                        "choices": [
                            "Cryptographic Anti-CSRF tokens and SameSite=Strict cookie policy",
                            "Base64 encoding all form submissions",
                            "Using HTTP Basic Authentication over TLS",
                            "Hiding the HTML submit button with CSS"
                        ],
                        "correct_index": 0,
                        "explanation": "SameSite cookies prevent cross-origin ambient cookie delivery, and anti-CSRF tokens guarantee deliberate user intent."
                    }
                ],
                "Matching": [
                    {
                        "prompt": "Match each cryptographic primitive with its primary technical purpose",
                        "pairs": {
                            "AES-256-GCM": "Authenticated high-speed symmetric payload encryption",
                            "RSA / ECC Curve25519": "Asymmetric key exchange and digital identity signatures",
                            "HMAC-SHA256": "Message authentication code verifying tamper-proof data integrity",
                            "Argon2id": "Memory-hard password key derivation resisting GPU cracking",
                            "Diffie-Hellman (ECDHE)": "Ephemeral shared secret agreement over untrusted networks"
                        }
                    },
                    {
                        "prompt": "Match each cybersecurity vulnerability with its standard mitigation",
                        "pairs": {
                            "SQL Injection": "Parameterized queries / prepared statements with placeholder bindings",
                            "Cross-Site Scripting (XSS)": "Context-aware HTML/JS output encoding and Content Security Policy",
                            "Buffer Overflow": "Memory-safe languages (Rust/Go) or compiler stack canaries and ASLR",
                            "Man-In-The-Middle (MITM)": "TLS certificate pinning and Strict-Transport-Security (HSTS)",
                            "Credential Stuffing": "Multi-Factor Authentication (MFA) and adaptive rate limiting"
                        }
                    }
                ],
                "Sequencing": [
                    {
                        "prompt": "Order the sequence of operations in a standard TLS 1.3 cryptographic handshake",
                        "ordered_sequence": [
                            "Client sends ClientHello with supported cipher suites and ephemeral Diffie-Hellman key share",
                            "Server replies with ServerHello, selecting cipher suite and providing its own key share",
                            "Both parties derive symmetric session encryption keys from the shared Diffie-Hellman secret",
                            "Server sends encrypted certificate chain and digital signature for identity verification",
                            "Client verifies certificate and both parties exchange Finished messages to begin secure data transfer"
                        ]
                    },
                    {
                        "prompt": "Order the defense-in-depth steps to securely authenticate and store a user password",
                        "ordered_sequence": [
                            "User submits plaintext password over an encrypted TLS connection",
                            "Server generates a cryptographically secure random salt (at least 16 bytes)",
                            "Password and salt are hashed using Argon2id with calibrated time and memory costs",
                            "Salt, algorithm parameters, and resulting password hash are saved to the user table",
                            "Original plaintext password variable is zeroed in RAM immediately after hashing"
                        ]
                    }
                ],
                "Sorting-Classification": [
                    {
                        "prompt": "Classify the following cryptographic algorithms into Symmetric or Asymmetric",
                        "categories": [
                            "Symmetric",
                            "Asymmetric"
                        ],
                        "items": {
                            "Symmetric": [
                                "AES-256-GCM",
                                "ChaCha20-Poly1305",
                                "Triple DES (3DES)"
                            ],
                            "Asymmetric": [
                                "RSA-4096",
                                "ECC Curve25519",
                                "Diffie-Hellman (DH)"
                            ]
                        }
                    },
                    {
                        "prompt": "Classify the following security concerns into Network Security or Application Security",
                        "categories": [
                            "Network Security",
                            "Application Security"
                        ],
                        "items": {
                            "Network Security": [
                                "SYN Flood DDoS",
                                "ARP Spoofing",
                                "DNS Cache Poisoning"
                            ],
                            "Application Security": [
                                "SQL Injection (SQLi)",
                                "Remote Code Execution (RCE)",
                                "Cross-Site Scripting (XSS)"
                            ]
                        }
                    }
                ]
            }
        },

        # --- EXPANSION FOR Computer Networking ---
        "Computer Networking": {
            "new_tf": [
                {
                    "statement": "HTTP/3 replaces TCP with QUIC, which runs over UDP to eliminate head-of-line blocking across independent streams.",
                    "is_true": True,
                    "explanation": "QUIC operates over UDP, so lost packets on one stream do not stall unrelated multiplexed streams."
                },
                {
                    "statement": "The Border Gateway Protocol (BGP) is an interior gateway routing protocol used strictly within a single local area network.",
                    "is_true": False,
                    "explanation": "BGP is the exterior routing protocol that connects Autonomous Systems (AS) across the global Internet backbone."
                },
                {
                    "statement": "A subnet mask of /24 corresponds to the dotted-decimal subnet mask 255.255.255.0, providing 256 total IP addresses.",
                    "is_true": True,
                    "explanation": "/24 leaves 8 host bits (2^8 = 256 addresses, with 254 usable for hosts after network and broadcast)."
                },
                {
                    "statement": "TCP flow control is managed by the receiver announcing its receive window (rwnd) size in packet headers.",
                    "is_true": True,
                    "explanation": "The receive window advertises available buffer space so the sender does not overwhelm the receiver's memory."
                }
            ],
            "new_mc": [
                {
                    "question": "Which DNS record type maps a domain name directly to an IPv6 128-bit address?",
                    "choices": [
                        "AAAA Record",
                        "A Record",
                        "CNAME Record",
                        "MX Record"
                    ],
                    "correct_index": 0,
                    "explanation": "An 'A' record maps to a 32-bit IPv4 address, while a quad-A 'AAAA' record maps to a 128-bit IPv6 address."
                },
                {
                    "question": "What is the primary technical distinction between TCP Reno and TCP BBR congestion control algorithms?",
                    "choices": [
                        "BBR models bottleneck bandwidth and round-trip propagation time instead of relying purely on packet loss",
                        "TCP Reno uses UDP sockets while BBR requires custom hardware ASICs",
                        "BBR disables TCP acknowledgments to double maximum bandwidth",
                        "TCP Reno runs exclusively inside satellite ground stations"
                    ],
                    "correct_index": 0,
                    "explanation": "BBR (Bottleneck Bandwidth and RTT) avoids bufferbloat by pacing packets to match physical pipe capacity rather than waiting for loss."
                },
                {
                    "question": "In the OSI 7-layer model, at which layer does IP packet routing and fragmentation occur?",
                    "choices": [
                        "Layer 3 (Network Layer)",
                        "Layer 2 (Data Link Layer)",
                        "Layer 4 (Transport Layer)",
                        "Layer 7 (Application Layer)"
                    ],
                    "correct_index": 0,
                    "explanation": "Routers operate at Layer 3 (Network Layer), inspecting IP headers and making hop-by-hop forwarding decisions."
                }
            ],
            "new_matching": [
                {
                    "prompt": "Match each network protocol with its standard default port number",
                    "pairs": {
                        "HTTPS": "Port 443",
                        "DNS": "Port 53",
                        "SSH": "Port 22",
                        "BGP": "Port 179",
                        "HTTP": "Port 80"
                    }
                }
            ],
            "new_sequencing": [
                {
                    "prompt": "Order the sequence of network encapsulation when an HTTP GET request packet travels down the networking stack",
                    "ordered_sequence": [
                        "Application Layer generates HTTP GET request text header",
                        "Transport Layer encapsulates into TCP segment with Source/Destination ports and SEQ number",
                        "Network Layer encapsulates into IP packet with Source/Destination IP addresses and TTL",
                        "Data Link Layer encapsulates into Ethernet Frame with MAC addresses and CRC checksum",
                        "Physical Layer converts frame bits into electrical, optical, or radio physical signals"
                    ]
                }
            ],
            "new_sorting": [
                {
                    "prompt": "Classify the following protocols into Transport Layer or Application Layer",
                    "categories": [
                        "Transport Layer",
                        "Application Layer"
                    ],
                    "items": {
                        "Transport Layer": [
                            "TCP",
                            "UDP",
                            "SCTP"
                        ],
                        "Application Layer": [
                            "DNS",
                            "HTTP/2",
                            "SSH"
                        ]
                    }
                }
            ]
        },

        # --- EXPANSION FOR Artificial Intelligence ---
        "Artificial Intelligence": {
            "new_tf": [
                {
                    "statement": "The vanishing gradient problem in deep networks was significantly mitigated by replacing Sigmoid activations with Rectified Linear Units (ReLU).",
                    "is_true": True,
                    "explanation": "ReLU has a constant derivative of 1.0 for positive inputs, preventing gradients from decaying to near-zero across many layers."
                },
                {
                    "statement": "In unsupervised learning, training datasets must contain ground-truth human labels for every sample.",
                    "is_true": False,
                    "explanation": "Unsupervised learning (e.g. K-means, PCA, autoencoders) discovers hidden patterns without explicit ground-truth labels."
                },
                {
                    "statement": "Reinforcement Learning from Human Feedback (RLHF) trains a reward model to align LLM completions with human preferences.",
                    "is_true": True,
                    "explanation": "RLHF uses Proximal Policy Optimization (PPO) against a learned reward model to guide generative outputs."
                }
            ],
            "new_mc": [
                {
                    "question": "In the Transformer architecture, what is the computational complexity of the standard self-attention mechanism with respect to sequence length N?",
                    "choices": [
                        "O(N^2) Quadratic complexity",
                        "O(N) Linear complexity",
                        "O(log N) Logarithmic complexity",
                        "O(N!) Factorial complexity"
                    ],
                    "correct_index": 0,
                    "explanation": "Every token computes dot-product attention against every other token in the sequence, producing an N x N attention matrix."
                },
                {
                    "question": "What technique prevents overfitting in deep neural networks by randomly deactivating a fraction of neurons during each training step?",
                    "choices": [
                        "Dropout",
                        "Batch Normalization",
                        "Gradient Clipping",
                        "Greedy Decoding"
                    ],
                    "correct_index": 0,
                    "explanation": "Dropout breaks co-adaptation between neurons by forcing the network to learn redundant, robust representations."
                }
            ],
            "new_matching": [
                {
                    "prompt": "Match each machine learning concept with its primary definition",
                    "pairs": {
                        "Backpropagation": "Calculus chain-rule backward pass to compute gradients of loss with respect to weights",
                        "Stochastic Gradient Descent": "Iterative weight updates computed on randomized mini-batches of training data",
                        "Convolutional Layer": "Parameter-sharing kernel filters capturing spatial hierarchies in images",
                        "Softmax": "Mathematical function converting raw model logits into a normalized probability distribution",
                        "Embeddings": "Dense vector representations mapping discrete tokens into continuous semantic vector space"
                    }
                }
            ],
            "new_sequencing": [
                {
                    "prompt": "Order the standard workflow stages of training and evaluating a deep learning model",
                    "ordered_sequence": [
                        "Data ingestion, cleaning, normalization, and tokenization",
                        "Model architecture definition and randomized weight initialization",
                        "Forward pass computing predictions and evaluating loss function",
                        "Backward pass (backpropagation) calculating gradients via chain rule",
                        "Optimizer updates weights opposite the gradient and validation loss is logged"
                    ]
                }
            ],
            "new_sorting": [
                {
                    "prompt": "Classify the following tasks into Supervised Learning or Reinforcement Learning",
                    "categories": [
                        "Supervised Learning",
                        "Reinforcement Learning"
                    ],
                    "items": {
                        "Supervised Learning": [
                            "Image Classification with labeled ImageNet",
                            "Spam email detection with labeled ham/spam datasets",
                            "Linear regression predicting house prices from sales records"
                        ],
                        "Reinforcement Learning": [
                            "Chess engine learning via game win/loss reward signals",
                            "Robotic arm locomotion guided by trajectory penalty functions",
                            "Self-driving steering optimization via distance rewards"
                        ]
                    }
                }
            ]
        },

        # --- EXPANSION FOR Cloud & Distributed Computing ---
        "Cloud & Distributed Computing": {
            "new_tf": [
                {
                    "statement": "According to the CAP theorem, a distributed data store can simultaneously provide Consistency, Availability, and Partition Tolerance during a network partition.",
                    "is_true": False,
                    "explanation": "When network partition (P) occurs, a distributed system MUST choose between Consistency (C) or Availability (A)."
                },
                {
                    "statement": "In the Raft consensus algorithm, all log entries flow strictly in one direction: from the elected Leader to the Followers.",
                    "is_true": True,
                    "explanation": "Raft simplifies consensus by ensuring followers only accept log entries appended by the current term's leader."
                },
                {
                    "statement": "Horizontal pod autoscaling in Kubernetes scales applications by increasing CPU and RAM allocations on existing nodes rather than creating new pod replicas.",
                    "is_true": False,
                    "explanation": "Horizontal autoscaling creates new pod replicas; vertical autoscaling adjusts resource limits of existing containers."
                }
            ],
            "new_mc": [
                {
                    "question": "Which consensus protocol is widely used in Apache ZooKeeper and etcd to coordinate distributed cluster state?",
                    "choices": [
                        "Raft / Paxos",
                        "MapReduce",
                        "Gossip Protocol",
                        "Two-Phase Locking (2PL)"
                    ],
                    "correct_index": 0,
                    "explanation": "etcd uses Raft and ZooKeeper uses ZAB (a Paxos variant) to guarantee linearizable consistency across quorum nodes."
                },
                {
                    "question": "What is the primary benefit of deploying microservices using an Envoy-based Service Mesh architecture?",
                    "choices": [
                        "Offloads mTLS encryption, traffic routing, circuit breaking, and telemetry out of application code into sidecar proxies",
                        "Eliminates the need for databases by caching all state directly in L3 CPU cache",
                        "Automatically converts interpreted Python scripts into binary x86 assembly",
                        "Guarantees zero-millisecond network latency across transatlantic cables"
                    ],
                    "correct_index": 0,
                    "explanation": "A service mesh handles service-to-service communication infrastructure (observability, security, resilience) transparently."
                }
            ],
            "new_matching": [
                {
                    "prompt": "Match each distributed systems design pattern with its problem domain",
                    "pairs": {
                        "Circuit Breaker": "Prevents cascading failures by stopping calls to failing downstream services",
                        "Consistent Hashing": "Minimizes key redistribution when nodes are added or removed from cache clusters",
                        "Saga Pattern": "Manages distributed transactions across microservices using compensating actions",
                        "Idempotency Key": "Ensures duplicate HTTP requests produce identical results without duplicate side effects",
                        "Write-Ahead Log (WAL)": "Appends mutations sequentially to persistent disk before memory updates for crash recovery"
                    }
                }
            ],
            "new_sequencing": [
                {
                    "prompt": "Order the steps of a distributed Two-Phase Commit (2PC) protocol",
                    "ordered_sequence": [
                        "Coordinator node receives transaction request from client application",
                        "Coordinator sends PREPARE request to all participating cohort nodes",
                        "Each cohort executes transaction locally, locks resources, and votes YES or NO",
                        "If all cohorts vote YES, Coordinator broadcasts COMMIT; otherwise broadcasts ABORT",
                        "Cohorts finalize commit or rollback, release locks, and send acknowledgment to Coordinator"
                    ]
                }
            ],
            "new_sorting": [
                {
                    "prompt": "Classify the following cloud storage types into Object Storage or Block Storage",
                    "categories": [
                        "Object Storage",
                        "Block Storage"
                    ],
                    "items": {
                        "Object Storage": [
                            "Amazon S3",
                            "Google Cloud Storage",
                            "Azure Blob Storage"
                        ],
                        "Block Storage": [
                            "AWS EBS Volume",
                            "SAN (Storage Area Network)",
                            "Local NVMe SSD Mount"
                        ]
                    }
                }
            ]
        },

        # --- EXPANSION FOR Databases & Distributed Storage ---
        "Databases & Distributed Storage": {
            "new_tf": [
                {
                    "statement": "In database normalization, Third Normal Form (3NF) requires that every non-key column is non-transitively dependent on the primary key.",
                    "is_true": True,
                    "explanation": "3NF ensures each column depends on the key, the whole key, and nothing but the key."
                },
                {
                    "statement": "NoSQL document stores like MongoDB strictly enforce compile-time schema validation across all foreign key relationships.",
                    "is_true": False,
                    "explanation": "Document stores are schema-flexible, storing nested BSON/JSON documents without rigid relational foreign key constraints."
                },
                {
                    "statement": "Database indexes improve SELECT query performance but incur a write penalty during INSERT, UPDATE, and DELETE operations.",
                    "is_true": True,
                    "explanation": "Every mutation must also update index B-trees or hash maps on disk."
                }
            ],
            "new_mc": [
                {
                    "question": "Which database transaction isolation level prevents Dirty Reads and Non-Repeatable Reads, but may still permit Phantom Reads under the ANSI SQL standard?",
                    "choices": [
                        "Repeatable Read",
                        "Read Committed",
                        "Read Uncommitted",
                        "Serializable"
                    ],
                    "correct_index": 0,
                    "explanation": "Repeatable Read locks accessed rows to prevent modifications, but new rows matching the WHERE clause (phantoms) can still appear unless Serializable is used."
                },
                {
                    "question": "What data structure do modern high-throughput write-heavy storage engines (like RocksDB and Cassandra) use to buffer writes before flushing to disk?",
                    "choices": [
                        "Log-Structured Merge-tree (LSM-tree) with in-memory MemTable",
                        "Doubly Linked List without disk persistence",
                        "Single-threaded Binary Heap",
                        "B-Tree with synchronous random disk seeks"
                    ],
                    "correct_index": 0,
                    "explanation": "LSM trees turn random writes into sequential disk writes by buffering in RAM and flushing sorted SSTables to disk."
                }
            ],
            "new_matching": [
                {
                    "prompt": "Match each database term with its core technical definition",
                    "pairs": {
                        "B+ Tree": "Balanced multi-way search tree where all keys are redundantly replicated in leaf nodes",
                        "Write-Ahead Log (WAL)": "Append-only log ensuring Durability by persisting transactions before page table writes",
                        "Sharding": "Horizontal partitioning of database rows across multiple physical database servers",
                        "Read Replica": "Read-only database clone asynchronously streaming replication logs from primary",
                        "Foreign Key": "Referential constraint ensuring a column value matches a primary key in another table"
                    }
                }
            ],
            "new_sequencing": [
                {
                    "prompt": "Order the SQL query execution lifecycle inside a relational database engine",
                    "ordered_sequence": [
                        "Parser verifies SQL syntax and constructs an Abstract Syntax Tree (AST)",
                        "Semantic Analyzer verifies table names, column existence, and user access permissions",
                        "Query Optimizer generates candidate execution plans using table statistics and calculates costs",
                        "Execution Engine runs the selected plan, fetching pages via Buffer Pool Manager",
                        "Result set is assembled, formatted, and streamed back to the client connection"
                    ]
                }
            ],
            "new_sorting": [
                {
                    "prompt": "Classify the following database engines into Relational (RDBMS) or NoSQL (Non-Relational)",
                    "categories": [
                        "Relational (RDBMS)",
                        "NoSQL (Non-Relational)"
                    ],
                    "items": {
                        "Relational (RDBMS)": [
                            "PostgreSQL",
                            "MySQL",
                            "SQLite"
                        ],
                        "NoSQL (Non-Relational)": [
                            "Redis (Key-Value)",
                            "MongoDB (Document)",
                            "Neo4j (Graph)"
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
    expansions = get_expansion_data()
    total_added = 0

    # 1. Add new domain if not present
    if "Cybersecurity & Cryptography" not in curr:
        curr["Cybersecurity & Cryptography"] = expansions["Cybersecurity & Cryptography"]
        qs = expansions["Cybersecurity & Cryptography"]["questions"]
        q_count = sum(len(v) for v in qs.values())
        total_added += q_count
        print(f"[NEW DOMAIN] Added 'Cybersecurity & Cryptography' with {q_count} questions.")

    # 2. Expand existing domains
    for domain_name, data in expansions.items():
        if domain_name == "Cybersecurity & Cryptography":
            continue

        if domain_name in curr:
            domain_qs = curr[domain_name].setdefault("questions", {})
            # True-False
            if "new_tf" in data:
                tf_list = domain_qs.setdefault("True-False", [])
                tf_list.extend(data["new_tf"])
                total_added += len(data["new_tf"])
                print(f"[EXPANSION] Added {len(data['new_tf'])} True-False questions to '{domain_name}'.")

            # Multi-Choice
            if "new_mc" in data:
                mc_list = domain_qs.setdefault("Multi-Choice", [])
                mc_list.extend(data["new_mc"])
                total_added += len(data["new_mc"])
                print(f"[EXPANSION] Added {len(data['new_mc'])} Multi-Choice questions to '{domain_name}'.")

            # Matching
            if "new_matching" in data:
                m_list = domain_qs.setdefault("Matching", [])
                m_list.extend(data["new_matching"])
                total_added += len(data["new_matching"])
                print(f"[EXPANSION] Added {len(data['new_matching'])} Matching questions to '{domain_name}'.")

            # Sequencing
            if "new_sequencing" in data:
                s_list = domain_qs.setdefault("Sequencing", [])
                s_list.extend(data["new_sequencing"])
                total_added += len(data["new_sequencing"])
                print(f"[EXPANSION] Added {len(data['new_sequencing'])} Sequencing questions to '{domain_name}'.")

            # Sorting
            if "new_sorting" in data:
                sort_list = domain_qs.setdefault("Sorting-Classification", [])
                sort_list.extend(data["new_sorting"])
                total_added += len(data["new_sorting"])
                print(f"[EXPANSION] Added {len(data['new_sorting'])} Sorting questions to '{domain_name}'.")

    # Update version
    db["version"] = 8
    print(f"\nTotal new questions added: {total_added}")

    # Write back to db.json
    with open(db_path, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2, ensure_ascii=False)
    print(f"Saved expanded database to {db_path} (version 8)")


if __name__ == "__main__":
    main()
