import unittest
from pathlib import Path
import json
import sys

# Ensure hardcode directory is in python path
sys.path.insert(0, str(Path(__file__).parent.parent))

from python_driver import (
    LearnerTracker,
    load_database,
    evaluate_true_false_question,
    evaluate_matching_question,
    evaluate_sequencing_question,
    evaluate_sorting_question,
    run_automated_validation,
)


class TestHardCodeSuite(unittest.TestCase):
    def setUp(self):
        self.db = load_database()

    def test_database_version_and_question_types(self):
        self.assertGreaterEqual(self.db.get("version", 0), 5)
        q_types = self.db.get("Question Types", {})
        expected = ["Multi-Choice", "True-False", "Matching", "Sequencing", "Sorting-Classification"]
        for eq in expected:
            self.assertIn(eq, q_types)

    def test_curriculum_domains_present(self):
        curriculum = self.db.get("Curriculum", {})
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
            self.assertIn(dom, curriculum)
            dom_data = curriculum[dom]
            self.assertIn("introduction", dom_data)
            self.assertIn("remediation", dom_data)
            self.assertIn("deep_dive", dom_data)
            self.assertIn("questions", dom_data)

    def test_true_false_evaluator(self):
        q_true = {"statement": "Test True", "is_true": True, "explanation": "It is true"}
        q_false = {"statement": "Test False", "is_true": False, "explanation": "It is false"}

        corr, exp = evaluate_true_false_question(q_true, "T")
        self.assertTrue(corr)
        corr, exp = evaluate_true_false_question(q_true, "1")
        self.assertTrue(corr)
        corr, exp = evaluate_true_false_question(q_false, "F")
        self.assertTrue(corr)
        corr, exp = evaluate_true_false_question(q_false, "0")
        self.assertTrue(corr)

        wrong, _ = evaluate_true_false_question(q_true, "F")
        self.assertFalse(wrong)

    def test_matching_evaluator(self):
        q = {
            "prompt": "Match items",
            "pairs": {
                "TCP": "Transport",
                "HTTP": "Application",
            }
        }
        user_correct = {"TCP": "Transport", "HTTP": "Application"}
        user_wrong = {"TCP": "Application", "HTTP": "Transport"}

        corr, count, tot = evaluate_matching_question(q, user_correct)
        self.assertTrue(corr)
        self.assertEqual(count, 2)
        self.assertEqual(tot, 2)

        corr_w, count_w, tot_w = evaluate_matching_question(q, user_wrong)
        self.assertFalse(corr_w)
        self.assertEqual(count_w, 0)

    def test_sequencing_evaluator(self):
        q = {
            "prompt": "Sequence steps",
            "ordered_sequence": ["Step A", "Step B", "Step C"]
        }
        self.assertTrue(evaluate_sequencing_question(q, ["Step A", "Step B", "Step C"])[0])
        self.assertFalse(evaluate_sequencing_question(q, ["Step B", "Step A", "Step C"])[0])

    def test_sorting_evaluator(self):
        q = {
            "prompt": "Sort items",
            "categories": ["LIFO", "FIFO"],
            "items": {
                "LIFO": ["Stack"],
                "FIFO": ["Queue"]
            }
        }
        self.assertTrue(evaluate_sorting_question(q, {"LIFO": ["Stack"], "FIFO": ["Queue"]})[0])
        self.assertFalse(evaluate_sorting_question(q, {"LIFO": ["Queue"], "FIFO": ["Stack"]})[0])

    def test_pedagogical_throttling(self):
        tracker = LearnerTracker()
        meta = {"introduction": "Intro", "remediation": "Remed", "deep_dive": "Deep"}

        tracker.record_turn()
        intro = tracker.observe_topic("Algorithms")
        self.assertIsNotNone(intro)
        self.assertEqual(intro[0], "Introduction")

        # Miss 1
        exp1 = tracker.record_result("Algorithms", False, meta)
        self.assertEqual(exp1[0], "Concept Refresh")

        # Turn 2: Different topic
        tracker.record_turn()
        tracker.observe_topic("Networking")

        # Turn 3: Miss 2 (interval >= 2) -> Remediation
        tracker.record_turn()
        exp2 = tracker.record_result("Algorithms", False, meta)
        self.assertEqual(exp2[0], "Targeted Remediation Hint")

        # Turn 4: Immediate Miss 3 (interval < 4) -> Throttled
        tracker.record_turn()
        exp3 = tracker.record_result("Algorithms", False, meta)
        self.assertIsNone(exp3)

    def test_automated_validation_routine(self):
        self.assertTrue(run_automated_validation())


if __name__ == "__main__":
    unittest.main()
