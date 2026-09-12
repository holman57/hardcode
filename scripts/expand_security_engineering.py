#!/usr/bin/env python3
"""
Expands HardCode curriculum with the Security Engineering Core Master Domain.
Covers:
- Threat Modeling (STRIDE, DREAD, Attack Trees)
- Secure Software Development Lifecycle (SSDLC, SAST, DAST, IAST)
- Memory Safety & Binary Exploit Mitigations (ASLR, DEP/NX, Stack Canaries, ROP)
- Identity & Access Management (OAuth 2.0, OIDC, RBAC, ABAC)
- Cryptographic Key Management (HSM, KMS, Key Derivation, Rotation)
"""

import json
from pathlib import Path

def get_security_engineering_data():
    return {
        "introduction": "Security Engineering designs systems to remain dependable and resilient in the face of malice, error, or targeted compromise, spanning threat modeling, hardware-enforced isolation, and defense-in-depth.",
        "remediation": "Focus on the STRIDE threat matrix (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege), compile-time memory protections (ASLR/DEP/canaries), and the Principle of Least Privilege.",
        "deep_dive": "Modern Security Engineering incorporates formal Threat Modeling during architectural design, automated static/dynamic security testing (SAST/DAST) in CI/CD, and cryptographically verified identities (mTLS, SPIFFE/SPIRE). Binary hardening eliminates memory corruption attack vectors via Return-Oriented Programming (ROP) defenses, Control Flow Integrity (CFI), and hardware-backed Key Management Systems (HSM/KMS).",
        "questions": {
            "True-False": [
                {
                    "statement": "Address Space Layout Randomization (ASLR) randomizes the memory locations of program segments (stack, heap, libraries) to prevent predictable buffer overflow exploits.",
                    "is_true": True,
                    "explanation": "ASLR makes it computationally infeasible for attackers to reliably target hardcoded shellcode or function pointers in virtual memory."
                },
                {
                    "statement": "Static Application Security Testing (SAST) requires executing the compiled binary inside a live running test environment.",
                    "is_true": False,
                    "explanation": "SAST analyzes raw source code, byte code, or binary files without running the application; DAST analyzes running applications from the outside."
                },
                {
                    "statement": "In the STRIDE threat modeling framework, the letter 'R' stands for 'Repudiation'—the ability of an actor to deny having performed an action without proof.",
                    "is_true": True,
                    "explanation": "Repudiation threats are mitigated through tamper-evident digital signatures, secure audit logs, and non-repudiation controls."
                },
                {
                    "statement": "Stack Canaries are known sentinel values placed on the stack before the return address to detect stack buffer overflows prior to function return.",
                    "is_true": True,
                    "explanation": "If a buffer overflow corrupts the stack, the canary value changes. The CPU checks this value before returning and aborts immediately if corrupted."
                },
                {
                    "statement": "Attribute-Based Access Control (ABAC) evaluates permissions strictly based on predefined fixed user job title roles without considering contextual environment attributes.",
                    "is_true": False,
                    "explanation": "Role-Based Access Control (RBAC) relies on fixed roles; ABAC dynamically evaluates attributes of the user, resource, action, and environment (e.g. time, IP, device security posture)."
                },
                {
                    "statement": "Data Execution Prevention (DEP / W^X) enforces that memory pages can be writable or executable, but never simultaneously writable AND executable.",
                    "is_true": True,
                    "explanation": "W^X (Write XOR Execute) stops attackers from injecting malicious machine code into data buffers (stack/heap) and executing it."
                }
            ],
            "Multi-Choice": [
                {
                    "question": "Which binary exploitation technique bypasses non-executable stack protections (DEP/NX) by chaining together existing small machine code snippets ending in a RET instruction?",
                    "choices": [
                        "Return-Oriented Programming (ROP)",
                        "SQL Injection",
                        "Cross-Site Scripting (XSS)",
                        "DNS Amplification"
                    ],
                    "correct_index": 0,
                    "explanation": "ROP locates 'gadgets' already present in executable program memory (e.g. libc) and chains them together by manipulating stack frame pointers."
                },
                {
                    "question": "In the OAuth 2.0 authorization framework, which grant type is recommended for single-page web applications and mobile apps to protect against authorization code interception?",
                    "choices": [
                        "Authorization Code Grant with PKCE (Proof Key for Code Exchange)",
                        "Implicit Grant",
                        "Resource Owner Password Credentials Grant",
                        "Client Credentials Grant"
                    ],
                    "correct_index": 0,
                    "explanation": "PKCE creates a dynamic cryptographic code verifier and challenge, completely replacing the vulnerable legacy Implicit Grant for public clients."
                },
                {
                    "question": "What is the primary operational advantage of storing master cryptographic encryption keys inside a dedicated Hardware Security Module (HSM)?",
                    "choices": [
                        "Keys never leave the physical tamper-resistant hardware boundary in plaintext and are zeroized upon physical intrusion",
                        "Triples the network throughput of HTTP/2 requests",
                        "Eliminates the need for software unit tests",
                        "Automatically compresses SQL database indexes"
                    ],
                    "correct_index": 0,
                    "explanation": "HSMs are FIPS 140-2 Level 3/4 certified physical appliances designed to generate, store, and execute cryptographic operations without exposing raw keys to host OS memory."
                },
                {
                    "question": "Which principle of Security Engineering dictates that every program and every privileged user of the system should operate using the least amount of privilege necessary to complete the job?",
                    "choices": [
                        "Principle of Least Privilege (PoLP)",
                        "Defense-in-Depth",
                        "Fail-Safe Defaults",
                        "Economy of Mechanism"
                    ],
                    "correct_index": 0,
                    "explanation": "The Principle of Least Privilege limits the potential blast radius if a process or credential is compromised."
                }
            ],
            "Matching": [
                {
                    "prompt": "Match each Security Engineering concept with its primary objective",
                    "pairs": {
                        "STRIDE Matrix": "Systematic architectural threat categorization framework (Spoofing to Elevation of Privilege)",
                        "Control Flow Integrity (CFI)": "Hardware/compiler defense restricting runtime execution paths to valid call graph targets",
                        "Static Application Security Testing (SAST)": "White-box automated code scanning for vulnerabilities before compilation",
                        "Dynamic Application Security Testing (DAST)": "Black-box fault injection testing against running target applications",
                        "OpenID Connect (OIDC)": "Identity and authentication layer built directly on top of the OAuth 2.0 protocol"
                    }
                },
                {
                    "prompt": "Match each binary exploit defense with its protection mechanism",
                    "pairs": {
                        "ASLR": "Randomizes base addresses of stack, heap, and libraries in virtual memory",
                        "Stack Canary": "Detects buffer overflow overwrites before return instruction executes",
                        "DEP / NX Bit": "Marks data pages non-executable so injected shellcode cannot run",
                        "Pointer Authentication (PAC)": "Cryptographically signs code pointers in unused 64-bit address bits (ARMv8.3+)",
                        "RELRO (Relocation Read-Only)": "Hardens Global Offset Table (GOT) against arbitrary pointer overwrite attacks"
                    }
                }
            ],
            "Sequencing": [
                {
                    "prompt": "Order the stages of a Secure Software Development Lifecycle (SSDLC)",
                    "ordered_sequence": [
                        "Security requirements definition and regulatory compliance scoping",
                        "Architectural threat modeling and attack surface decomposition (STRIDE)",
                        "Secure coding with automated static analysis (SAST) and dependency scanning",
                        "Dynamic application security testing (DAST) and interactive penetration testing",
                        "Continuous production monitoring, automated patching, and incident response readiness"
                    ]
                },
                {
                    "prompt": "Order the steps an attacker takes during a traditional stack buffer overflow exploit and its defense response",
                    "ordered_sequence": [
                        "Attacker sends input exceeding the allocated stack buffer boundary",
                        "Malicious payload overwrites local variables and approaches the stack canary",
                        "Payload corrupts the stack canary value on its way to the function return address",
                        "Function epilogue executes `__stack_chk_fail` after detecting canary mismatch",
                        "Kernel terminates the process immediately with SIGABRT, preventing malicious code execution"
                    ]
                }
            ],
            "Sorting-Classification": [
                {
                    "prompt": "Classify the following security testing tools into SAST (Static) or DAST (Dynamic)",
                    "categories": [
                        "SAST (Static Analysis)",
                        "DAST (Dynamic Analysis)"
                    ],
                    "items": {
                        "SAST (Static Analysis)": [
                            "Semgrep code rule engine",
                            "SonarQube source analyzer",
                            "CodeQL AST query engine"
                        ],
                        "DAST (Dynamic Analysis)": [
                            "OWASP ZAP vulnerability scanner",
                            "Burp Suite web proxy fuzzer",
                            "Nuclei network vulnerability scanner"
                        ]
                    }
                },
                {
                    "prompt": "Classify the following security controls into Preventive or Detective",
                    "categories": [
                        "Preventive Controls",
                        "Detective Controls"
                    ],
                    "items": {
                        "Preventive Controls": [
                            "Multi-Factor Authentication (MFA)",
                            "Input parameterization (Prepared Statements)",
                            "Hardware Security Module (HSM) key isolation"
                        ],
                        "Detective Controls": [
                            "Intrusion Detection System (IDS)",
                            "Security Information and Event Management (SIEM) log alerts",
                            "File Integrity Monitoring (FIM)"
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
    sec_data = get_security_engineering_data()
    curr["Security Engineering"] = sec_data

    qs = sec_data.get("questions", {})
    q_count = sum(len(v) for v in qs.values())
    print(f"[SECURITY ENGINEERING] Injected Security Engineering with {q_count} questions into {db_path}.")

    with open(db_path, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2, ensure_ascii=False)
    print("Database updated successfully.")


if __name__ == "__main__":
    main()
