import argparse
import json
import os
import random
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


def cls():
    os.system("cls" if os.name == "nt" else "clear")


def wait_key():
    result = None
    if os.name == "nt":
        import msvcrt
        result = msvcrt.getwch()
    else:
        import termios
        fd = sys.stdin.fileno()
        oldterm = termios.tcgetattr(fd)
        newattr = termios.tcgetattr(fd)
        newattr[3] = newattr[3] & ~termios.ICANON & ~termios.ECHO
        termios.tcsetattr(fd, termios.TCSANOW, newattr)
        try:
            result = sys.stdin.read(1)
        except IOError:
            pass
        finally:
            termios.tcsetattr(fd, termios.TCSAFLUSH, oldterm)
    return result


class PriorityRandomGenerator:
    def __init__(self, n_patterns, priorities):
        self.indices = [x for x in range(n_patterns)]
        self.priorities = priorities
        self.n = len(self.priorities)

    def prefixSums(self):
        p = [0] * (self.n + 1)
        for k in range(1, self.n + 1):
            p[k] = p[k - 1] + self.priorities[k - 1]
        return p

    def pickIndex(self):
        preS = self.prefixSums()
        sumP = sum(self.priorities)
        if sumP <= 0:
            return 0
        p_i = random.uniform(0, sumP)
        for i in range(0, len(preS) - 1):
            if preS[i] <= p_i <= preS[i + 1]:
                return i
        return 0


class LearnerTracker:
    """Pedagogical tracking and explanation throttling for human learners.
    Rules:
    - First encounter: Shows formal concept definition (introduction).
    - Consecutive misses >= 2: Shows targeted remediation.
    - Outright failure (consecutive misses >= 3): Shows comprehensive architectural deep dive.
    - Explanation Throttling: If explanations occur repeatedly, decays frequency exponentially
      so the user is not overwhelmed with identical explanations.
    """

    def __init__(self):
        self.seen_topics: Dict[str, int] = {}
        self.consecutive_misses: Dict[str, int] = {}
        self.explanation_counts: Dict[str, int] = {}
        self.last_explanation_turn: Dict[str, int] = {}
        self.turn: int = 0

    def record_turn(self):
        self.turn += 1

    def observe_topic(self, topic: str) -> Optional[Tuple[str, str]]:
        """Check if first-time explanation should be presented."""
        count = self.seen_topics.get(topic, 0)
        self.seen_topics[topic] = count + 1
        if count == 0:
            return ("Introduction", f"First time exploring '{topic}'. Review the formal concept definition:")
        return None

    def record_result(self, topic: str, is_correct: bool, topic_metadata: Optional[Dict[str, Any]] = None) -> Optional[Tuple[str, str]]:
        """Record answer outcome and determine if throttled remediation should be presented."""
        meta = topic_metadata or {}
        if is_correct:
            self.consecutive_misses[topic] = 0
            return None

        misses = self.consecutive_misses.get(topic, 0) + 1
        self.consecutive_misses[topic] = misses

        exp_count = self.explanation_counts.get(topic, 0)
        last_turn = self.last_explanation_turn.get(topic, -999)

        # Exponential backoff on explanation frequency: interval = 2^exp_count
        min_interval = min(16, 2 ** exp_count)
        if (self.turn - last_turn) < min_interval and exp_count > 0:
            # Throttled!
            return None

        # Determine explanation tier
        if misses >= 3 and meta.get("deep_dive"):
            self.explanation_counts[topic] = exp_count + 1
            self.last_explanation_turn[topic] = self.turn
            return ("Architectural Deep Dive (Outright Failure Remediation)", meta["deep_dive"])
        elif misses >= 2 and meta.get("remediation"):
            self.explanation_counts[topic] = exp_count + 1
            self.last_explanation_turn[topic] = self.turn
            return ("Targeted Remediation Hint", meta["remediation"])
        elif misses == 1 and meta.get("introduction") and exp_count == 0:
            self.explanation_counts[topic] = exp_count + 1
            self.last_explanation_turn[topic] = self.turn
            return ("Concept Refresh", meta["introduction"])

        return None


def load_database() -> Dict[str, Any]:
    """Loads database favoring assets/db.json with fallback to db_backup.json."""
    candidates = [
        Path("assets/db.json"),
        Path(__file__).parent / "assets" / "db.json",
        Path("db_backup.json"),
        Path(__file__).parent / "db_backup.json",
    ]
    for c in candidates:
        if c.exists():
            try:
                with open(c, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                continue
    raise FileNotFoundError("Could not find assets/db.json or db_backup.json")


def renderPatternBranching(answer: str, pattern: List[str], db: Dict[str, Any]) -> str:
    int_small_var_set = ["x", "y", "n", "i", "j"]
    int_var_name = db.get("Variables", {}).get("Int Variable Names", ["count", "val"])
    int_rust_var_type = db.get("Variables", {}).get("Rust Int Variable Types", ["i32", "u64"])
    render = answer
    for p in pattern:
        if p == "[random int variable]":
            r = random.randint(1, 3)
            if r == 1:
                render = render.replace(p, chr(random.randint(ord("a"), ord("z"))))
            elif r == 2:
                render = render.replace(p, random.choice(int_var_name))
            elif r == 3:
                render = render.replace(p, random.choice(int_small_var_set))
        if p == "[random integer]":
            r = random.randint(1, 4)
            if r == 1:
                render = render.replace(p, str(random.randint(0, 9)))
            elif r == 2:
                render = render.replace(p, str(random.randint(0, 9999)))
            elif r == 3:
                render = render.replace(p, str(random.randint(0, 999999)))
            elif r == 4:
                render = render.replace(p, str(random.randint(0, 99)))
        if p == "[random rust data type]":
            render = render.replace(p, random.choice(int_rust_var_type))
    return render.strip()


def renderPatternOptions(answer: str, pattern: List[str]) -> str:
    render = answer
    for p in pattern:
        if p in answer:
            options = p.replace("[", "").replace("]", "").split("|")
            option = random.choice(options)
            if option == "None":
                render = render.replace(p, "")
            else:
                render = render.replace(p, option)
    return render.strip()


# -----------------------------------------------------------------------------
# New Question Types Evaluators
# -----------------------------------------------------------------------------

def evaluate_true_false_question(q: Dict[str, Any], user_input: str) -> Tuple[bool, str]:
    """Evaluates True/False question. Expected user_input: 'T'/'t'/'1' or 'F'/'f'/'0'."""
    clean = user_input.strip().lower()
    user_bool = clean in ("t", "true", "1", "y")
    is_correct = (user_bool == q["is_true"])
    return is_correct, q.get("explanation", "")


def evaluate_matching_question(q: Dict[str, Any], user_pairs: Dict[str, str]) -> Tuple[bool, int, int]:
    """Evaluates Matching question pairs."""
    actual_pairs = q["pairs"]
    correct_count = 0
    for k, v in user_pairs.items():
        if actual_pairs.get(k) == v:
            correct_count += 1
    total = len(actual_pairs)
    return (correct_count == total), correct_count, total


def evaluate_sequencing_question(q: Dict[str, Any], user_sequence: List[str]) -> Tuple[bool, List[str]]:
    """Evaluates ordered sequence question."""
    expected = q["ordered_sequence"]
    is_correct = (user_sequence == expected)
    return is_correct, expected


def evaluate_sorting_question(q: Dict[str, Any], user_groups: Dict[str, List[str]]) -> Tuple[bool, Dict[str, List[str]]]:
    """Evaluates Sorting/Classification question."""
    expected = q["items"]
    all_match = True
    for cat, items in expected.items():
        user_cat_items = sorted(user_groups.get(cat, []))
        if sorted(items) != user_cat_items:
            all_match = False
            break
    return all_match, expected


def evaluate_multi_choice_question(q: Dict[str, Any], user_choice: int) -> Tuple[bool, str]:
    """Evaluates Multi-Choice question. user_choice is 0-indexed integer."""
    is_correct = (user_choice == q["correct_index"])
    return is_correct, q.get("explanation", "")


def run_automated_validation() -> bool:
    """Non-interactive test routine for CI/CD and System Alpha verification."""
    print("=== HardCode Automated Validation Suite ===")
    db = load_database()
    print(f"[OK] Database loaded successfully (version: {db.get('version', 1)})")

    # 1. Validate Question Types Catalog
    q_types = db.get("Question Types", {})
    expected_types = ["Multi-Choice", "True-False", "Matching", "Sequencing", "Sorting-Classification"]
    for qt in expected_types:
        assert qt in q_types, f"Missing question type in catalog: {qt}"
    print(f"[OK] Verified all 5 Question Types: {list(q_types.keys())}")

    # 2. Validate Curriculum Domains
    curriculum = db.get("Curriculum", {})
    expected_domains = [
        "System Architecture",
        "Artificial Intelligence",
        "Operating Systems",
        "Computer Networking",
        "Algorithms & Asymptotic Complexity",
        "Data Structures",
        "Automata & Discrete Mathematics",
    ]
    for dom in expected_domains:
        assert dom in curriculum, f"Missing curriculum domain: {dom}"
        dom_data = curriculum[dom]
        assert "introduction" in dom_data, f"Missing introduction in {dom}"
        assert "remediation" in dom_data, f"Missing remediation in {dom}"
        assert "deep_dive" in dom_data, f"Missing deep_dive in {dom}"
        assert "questions" in dom_data, f"Missing questions in {dom}"
    print(f"[OK] Verified all {len(expected_domains)} Computer Science curriculum domains")

    # 3. Validate Question Types Execution
    for dom, dom_data in curriculum.items():
        q_dict = dom_data.get("questions", {})
        # True-False
        for tf in q_dict.get("True-False", []):
            corr, exp = evaluate_true_false_question(tf, "T" if tf["is_true"] else "F")
            assert corr, f"TF question failed correct evaluation: {tf['statement']}"
            wrong, _ = evaluate_true_false_question(tf, "F" if tf["is_true"] else "T")
            assert not wrong, f"TF question failed incorrect evaluation: {tf['statement']}"
        # Matching
        for m in q_dict.get("Matching", []):
            corr, match_c, tot = evaluate_matching_question(m, m["pairs"])
            assert corr and match_c == tot, f"Matching question failed: {m['prompt']}"
        # Sequencing
        for s in q_dict.get("Sequencing", []):
            corr, exp = evaluate_sequencing_question(s, s["ordered_sequence"])
            assert corr, f"Sequencing question failed: {s['prompt']}"
        # Sorting
        for sc in q_dict.get("Sorting-Classification", []):
            corr, exp = evaluate_sorting_question(sc, sc["items"])
            assert corr, f"Sorting question failed: {sc['prompt']}"
        # Multi-Choice
        for mc in q_dict.get("Multi-Choice", []):
            corr, exp = evaluate_multi_choice_question(mc, mc["correct_index"])
            assert corr, f"MC question failed correct evaluation: {mc['question']}"
            wrong_idx = (mc["correct_index"] + 1) % len(mc["choices"])
            wrong, _ = evaluate_multi_choice_question(mc, wrong_idx)
            assert not wrong, f"MC question failed incorrect evaluation: {mc['question']}"
    print("[OK] Verified mathematical correctness of all question evaluators")

    # 4. Validate Pedagogical Throttling Logic
    tracker = LearnerTracker()
    test_meta = {
        "introduction": "Introductory concept.",
        "remediation": "Remediation hint.",
        "deep_dive": "Comprehensive deep dive."
    }
    # Turn 1: First encounter
    tracker.record_turn()
    first_enc = tracker.observe_topic("Operating Systems")
    assert first_enc is not None and first_enc[0] == "Introduction"

    # Turn 1: Miss 1
    exp1 = tracker.record_result("Operating Systems", False, test_meta)
    assert exp1 is not None and exp1[0] == "Concept Refresh"

    # Turn 2: Drilling another topic
    tracker.record_turn()
    tracker.observe_topic("Computer Networking")

    # Turn 3: Miss 2 on Operating Systems (turn diff = 2 >= min_interval 2) -> Remediation Hint!
    tracker.record_turn()
    exp2 = tracker.record_result("Operating Systems", False, test_meta)
    assert exp2 is not None and exp2[0] == "Targeted Remediation Hint"

    # Turn 4: Immediate Miss 3 (turn diff = 1 < min_interval 4) -> Throttled!
    tracker.record_turn()
    exp3 = tracker.record_result("Operating Systems", False, test_meta)
    assert exp3 is None, "Immediate repeat should be throttled by exponential backoff"

    # Advance 4 turns (turns 5, 6, 7, 8) -> Miss 4 occurs at turn diff >= 4 -> Deep Dive!
    for _ in range(4):
        tracker.record_turn()
    exp4 = tracker.record_result("Operating Systems", False, test_meta)
    assert exp4 is not None and "Deep Dive" in exp4[0]

    print("[OK] Verified Pedagogical Explanation Throttling with exponential backoff")
    print("=== All HardCode Automated Validation Checks Passed! ===")
    return True


def run_interactive_quiz(db: Dict[str, Any], tracker: LearnerTracker, domain_filter: str = "all"):
    """Interactive quiz loop that loops through all 5 question types across domains."""
    print("=" * 60)
    print("        HARDCODE ACADEMY - INTERACTIVE KNOWLEDGE DRILL")
    print("=" * 60)
    print("Question Types: Multi-Choice | True-False | Matching | Sequencing | Sorting")
    print("Type 'q' or 'quit' at any prompt to exit.\n")

    # Filter domains based on domain_filter argument
    syntax_keywords = ["Control Flow", "Functions", "Object-Oriented", "Error", "Async", "Loops", "Collections", "Strings", "Memory"]
    if domain_filter == "syntax":
        available_domains = [d for d in curriculum.keys() if any(kw in d for kw in syntax_keywords)]
    elif domain_filter == "cs":
        available_domains = [d for d in curriculum.keys() if not any(kw in d for kw in syntax_keywords)]
    else:
        available_domains = list(curriculum.keys())

    if not available_domains:
        available_domains = list(curriculum.keys())

    score = 0
    total = 0
    streak = 0
    best_streak = 0

    question_types = ["Multi-Choice", "True-False", "Matching", "Sequencing", "Sorting-Classification"]
    turn = 0

    while True:
        tracker.record_turn()
        target_q_type = question_types[turn % len(question_types)]
        turn += 1

        # Pick domain that has the target question type
        domains_with_target = [
            d for d in available_domains
            if target_q_type in curriculum[d].get("questions", {}) and len(curriculum[d]["questions"][target_q_type]) > 0
        ]
        if domains_with_target:
            dom = random.choice(domains_with_target)
            q_type = target_q_type
        else:
            dom = random.choice(available_domains)
            q_dict = curriculum[dom].get("questions", {})
            valid_types = [t for t in question_types if t in q_dict and len(q_dict[t]) > 0]
            if not valid_types:
                continue
            q_type = random.choice(valid_types)

        dom_data = curriculum[dom]
        q_dict = dom_data.get("questions", {})
        q_item = random.choice(q_dict[q_type])

        print(f"\n--- [ {dom} • {q_type} ] (Score: {score}/{total} | Streak: {streak}) ---")
        is_correct = False
        explanation = ""

        if q_type == "True-False":
            print(f"Statement: {q_item['statement']}")
            ans = input("Your answer ([T]rue / [F]alse): ").strip()
            if ans.lower() in ("q", "quit", "exit"):
                break
            is_correct, explanation = evaluate_true_false_question(q_item, ans)

        elif q_type == "Multi-Choice":
            print(f"Question: {q_item['question']}")
            for idx, choice in enumerate(q_item["choices"], start=1):
                print(f"  [{idx}] {choice}")
            ans = input("Select [1-4]: ").strip()
            if ans.lower() in ("q", "quit", "exit"):
                break
            try:
                choice_idx = int(ans) - 1
                is_correct, explanation = evaluate_multi_choice_question(q_item, choice_idx)
            except ValueError:
                is_correct = False
                explanation = q_item.get("explanation", "")

        elif q_type == "Matching":
            print(f"Prompt: {q_item['prompt']}")
            pairs = q_item["pairs"]
            terms = list(pairs.keys())
            defs = list(pairs.values())
            random.shuffle(defs)
            letters = [chr(ord('A') + i) for i in range(len(defs))]
            def_map = dict(zip(letters, defs))

            print("Terms to match:")
            for idx, t in enumerate(terms, start=1):
                print(f"  [{idx}] {t}")
            print("Definitions:")
            for ltr, d in def_map.items():
                print(f"  [{ltr}] {d}")

            print("\nEnter pairing for each term (e.g. 1=A, 2=B) or 'all' to auto-check:")
            ans = input("Pairings (comma separated): ").strip()
            if ans.lower() in ("q", "quit", "exit"):
                break
            user_pairs = {}
            if ans.lower() == "all":
                user_pairs = pairs
            else:
                for chunk in ans.split(","):
                    if "=" in chunk:
                        parts = chunk.strip().split("=")
                        try:
                            t_idx = int(parts[0].strip()) - 1
                            ltr = parts[1].strip().upper()
                            if 0 <= t_idx < len(terms) and ltr in def_map:
                                user_pairs[terms[t_idx]] = def_map[ltr]
                        except Exception:
                            pass
            is_correct, match_c, tot = evaluate_matching_question(q_item, user_pairs)
            explanation = f"Matched {match_c} of {tot} correctly. Correct pairs:\n" + "\n".join(f"  * {k} -> {v}" for k, v in pairs.items())

        elif q_type == "Sequencing":
            print(f"Prompt: {q_item['prompt']}")
            expected = q_item["ordered_sequence"]
            shuffled = list(expected)
            random.shuffle(shuffled)
            for idx, step in enumerate(shuffled, start=1):
                print(f"  [{idx}] {step}")
            ans = input(f"Enter correct order (comma separated numbers 1-{len(shuffled)}): ").strip()
            if ans.lower() in ("q", "quit", "exit"):
                break
            try:
                order_indices = [int(x.strip()) - 1 for x in ans.split(",")]
                user_sequence = [shuffled[i] for i in order_indices if 0 <= i < len(shuffled)]
            except Exception:
                user_sequence = []
            is_correct, exp_seq = evaluate_sequencing_question(q_item, user_sequence)
            explanation = "Correct Sequence:\n" + "\n".join(f"  {i+1}. {s}" for i, s in enumerate(exp_seq))

        elif q_type == "Sorting-Classification":
            print(f"Prompt: {q_item['prompt']}")
            cats = q_item["categories"]
            cat_map = {str(i + 1): cat for i, cat in enumerate(cats)}
            print(f"Categories: " + " | ".join(f"[{k}] {v}" for k, v in cat_map.items()))
            items = []
            for c, it_list in q_item["items"].items():
                items.extend(it_list)
            random.shuffle(items)
            user_groups = {c: [] for c in cats}
            ans = ""
            for it in items:
                ans = input(f"Classify '{it}' (1-{len(cats)}): ").strip()
                if ans.lower() in ("q", "quit", "exit"):
                    break
                if ans in cat_map:
                    user_groups[cat_map[ans]].append(it)
            if ans.lower() in ("q", "quit", "exit"):
                break
            is_correct, exp_groups = evaluate_sorting_question(q_item, user_groups)
            explanation = "Correct Classifications:\n" + "\n".join(f"  * {c}: {', '.join(its)}" for c, its in exp_groups.items())

        total += 1
        if is_correct:
            score += 1
            streak += 1
            if streak > best_streak:
                best_streak = streak
            print(">>> [CORRECT!] Excellent work! +15 XP")
            if explanation:
                print(f"Note: {explanation}")
        else:
            streak = 0
            print(">>> [INCORRECT]")
            if explanation:
                print(f"Explanation:\n{explanation}")

        ped = tracker.record_result(dom, is_correct, dom_data)
        if ped:
            print(f"\n[{ped[0]}]")
            print(f"-> {ped[1]}")

    print("\n" + "=" * 60)
    print("SESSION COMPLETE")
    print(f"Total Questions: {total} | Correct: {score}")
    acc = (score / total * 100) if total > 0 else 0
    print(f"Accuracy: {acc:.1f}% | Best Streak: {best_streak}")
    print("=" * 60)


def main():
    parser = argparse.ArgumentParser(description="HardCode Flashcard & CS Learning CLI Driver")
    parser.add_argument("--test", action="store_true", help="Run automated validation suite non-interactively")
    parser.add_argument("--domain", choices=["all", "cs", "syntax"], default="all", help="Curriculum domain to drill")
    args = parser.parse_args()

    if args.test:
        success = run_automated_validation()
        sys.exit(0 if success else 1)

    # Interactive Quiz Mode
    db = load_database()
    tracker = LearnerTracker()
    run_interactive_quiz(db, tracker, domain_filter=args.domain)


if __name__ == "__main__":
    main()

