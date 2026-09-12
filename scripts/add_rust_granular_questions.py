#!/usr/bin/env python3
"""
Add granular questions for Rust variable declaration, mutability, ownership, borrowing,
lifetimes, pattern matching, and error handling to assets/db.json.
"""

import json
from pathlib import Path

DB_PATH = Path("assets/db.json")

def main():
    with open(DB_PATH, "r", encoding="utf-8") as f:
        db = json.load(f)

    curriculum = db.setdefault("Curriculum", {})
    pl = curriculum.setdefault("Programming Languages & Compilers", {})
    questions = pl.setdefault("questions", {})

    tf_list = questions.setdefault("True-False", [])
    mc_list = questions.setdefault("Multi-Choice", [])
    matching_list = questions.setdefault("Matching", [])
    seq_list = questions.setdefault("Sequencing", [])
    sort_list = questions.setdefault("Sorting-Classification", [])

    new_tf = [
        {
            "statement": "In Rust, variables declared with `let` are immutable by default and require `let mut` for reassignment.",
            "is_true": True,
            "explanation": "Rust variables are immutable by default to ensure safety and avoid race conditions. Mutability must be explicitly declared with `mut`."
        },
        {
            "statement": "In Rust, variable shadowing with `let x = ...` is forbidden by the compiler if variable `x` already exists in scope.",
            "is_true": False,
            "explanation": "Rust explicitly supports variable shadowing using `let`, creating a new binding that can even change the variable's type."
        },
        {
            "statement": "Rust's borrow checker permits multiple simultaneous mutable references (`&mut T`) to the same data within the same scope.",
            "is_true": False,
            "explanation": "Rust enforces the aliasing XOR mutability rule: you can have many shared references (`&T`) OR exactly one mutable reference (`&mut T`), never both."
        },
        {
            "statement": "In Rust, the `'static` lifetime indicates that the referenced data lives for the entire execution duration of the program.",
            "is_true": True,
            "explanation": "The `'static` lifetime specifier signifies that data (such as string literals) lives for the entire duration of the running program."
        },
        {
            "statement": "In Rust, pattern matching with `match` must be exhaustive, requiring all possible enum variants or values to be covered.",
            "is_true": True,
            "explanation": "The Rust compiler strictly requires exhaustive pattern matching to ensure no unhandled variant can trigger undefined behavior."
        }
    ]

    new_mc = [
        {
            "question": "Which Rust statement correctly declares a mutable 32-bit signed integer initialized to 42?",
            "options": [
                "let mut count: i32 = 42;",
                "var mut count: int = 42;",
                "mut let count: i32 = 42;",
                "val count: i32 = 42;"
            ],
            "correct": "let mut count: i32 = 42;",
            "correct_index": 0,
            "explanation": "Rust uses `let mut variable_name: Type = value;` to bind mutable typed variables on the stack."
        },
        {
            "question": "What occurs in Rust when a value without the `Copy` trait is assigned to another variable?",
            "options": [
                "Ownership is moved to the new variable, invalidating the original binding",
                "A shallow bitwise copy is made and both variables remain fully accessible",
                "The runtime performs an automatic deep heap clone",
                "A compilation error occurs because non-Copy values cannot be assigned"
            ],
            "correct": "Ownership is moved to the new variable, invalidating the original binding",
            "correct_index": 0,
            "explanation": "In Rust, assignment of non-Copy types transfers ownership via move semantics, preventing use-after-free and double-free bugs."
        },
        {
            "question": "What does the `?` operator do when applied to a `Result<T, E>` expression in Rust?",
            "options": [
                "Unwraps `Ok(val)` or returns early with `Err(err)` from the current function",
                "Suppresses runtime panics and converts any error into `None`",
                "Immediately aborts the process with an error code",
                "Asynchronously awaits the completion of an I/O future"
            ],
            "correct": "Unwraps `Ok(val)` or returns early with `Err(err)` from the current function",
            "correct_index": 0,
            "explanation": "The `?` operator provides syntactic sugar for error propagation, extracting `Ok` or immediately returning `Err`."
        },
        {
            "question": "Why does Rust's borrow checker enforce exclusive access for mutable references (`&mut T`)?",
            "options": [
                "To eliminate data races and pointer aliasing bugs at compile time without garbage collection",
                "To optimize L1 cache coherency across different CPU cores",
                "To enable automatic LLVM function inlining",
                "To minimize binary size by stripping debug symbols"
            ],
            "correct": "To eliminate data races and pointer aliasing bugs at compile time without garbage collection",
            "correct_index": 0,
            "explanation": "Exclusive mutable references prevent data races (concurrent read/write) and iterator invalidation at compile time."
        }
    ]

    new_matching = [
        {
            "prompt": "Match the Rust variable and memory construct to its guarantee:",
            "pairs": {
                "let mut": "Permits in-place reassignment and modification",
                "&T (Shared Ref)": "Permits concurrent read-only aliasing",
                "&mut T (Unique Ref)": "Guarantees exclusive mutable access with zero aliasing",
                "'a (Lifetime)": "Proves references never outlive target allocations"
            }
        }
    ]

    new_seq = [
        {
            "prompt": "Order the lifecycle phases of a Rust variable under borrow checking rules:",
            "sequence": [
                "1. Stack allocation initialized with single owner binding",
                "2. Shared immutable references (&T) created for reading",
                "3. Shared references go out of scope releasing read locks",
                "4. Exclusive mutable reference (&mut T) acquired and used",
                "5. Owner reaches end of scope and value drops deterministically"
            ],
            "ordered_sequence": [
                "1. Stack allocation initialized with single owner binding",
                "2. Shared immutable references (&T) created for reading",
                "3. Shared references go out of scope releasing read locks",
                "4. Exclusive mutable reference (&mut T) acquired and used",
                "5. Owner reaches end of scope and value drops deterministically"
            ]
        }
    ]

    new_sort = [
        {
            "prompt": "Classify the Rust constructs into Variable & Mutability, Ownership & Borrowing, or Error Handling:",
            "categories": [
                "Variable & Mutability",
                "Ownership & Borrowing",
                "Error Handling"
            ],
            "items": {
                "let mut counter: u32 = 0": "Variable & Mutability",
                "const MAX_SIZE: usize = 4096": "Variable & Mutability",
                "Variable Shadowing let x = x + 1": "Variable & Mutability",
                "Move Semantics let s2 = s1": "Ownership & Borrowing",
                "Shared Borrow &data": "Ownership & Borrowing",
                "Unique Borrow &mut data": "Ownership & Borrowing",
                "Lifetime Specifier 'a": "Ownership & Borrowing",
                "Result Ok(val) / Err(err)": "Error Handling",
                "Question Mark Operator ?": "Error Handling",
                "Option Some(val) / None": "Error Handling"
            }
        }
    ]

    # Add only if not already present
    existing_tf_stmts = {q.get("statement") for q in tf_list}
    for q in new_tf:
        if q["statement"] not in existing_tf_stmts:
            tf_list.append(q)

    existing_mc_questions = {q.get("question") for q in mc_list}
    for q in new_mc:
        if q["question"] not in existing_mc_questions:
            mc_list.append(q)

    existing_matching_prompts = {q.get("prompt") for q in matching_list}
    for q in new_matching:
        if q["prompt"] not in existing_matching_prompts:
            matching_list.append(q)

    existing_seq_prompts = {q.get("prompt") for q in seq_list}
    for q in new_seq:
        if q["prompt"] not in existing_seq_prompts:
            seq_list.append(q)

    existing_sort_prompts = {q.get("prompt") for q in sort_list}
    for q in new_sort:
        if q["prompt"] not in existing_sort_prompts:
            sort_list.append(q)

    with open(DB_PATH, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2, ensure_ascii=False)

    print(f"[SUCCESS] Expanded Curriculum -> Programming Languages & Compilers questions:")
    print(f"  True-False: {len(tf_list)}")
    print(f"  Multi-Choice: {len(mc_list)}")
    print(f"  Matching: {len(matching_list)}")
    print(f"  Sequencing: {len(seq_list)}")
    print(f"  Sorting-Classification: {len(sort_list)}")

if __name__ == "__main__":
    main()
