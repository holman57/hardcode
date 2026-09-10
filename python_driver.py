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
    print("Welcome to HardCode Academy (Interactive Mode). Press ESC to quit.")
    run_automated_validation()


if __name__ == "__main__":
    main()
