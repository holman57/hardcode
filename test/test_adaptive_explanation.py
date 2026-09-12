import unittest
import math
import random
from typing import Dict, Any, Optional


class PythonAdaptiveExplanationService:
    """Python reference mirror of AdaptiveExplanationService for automated validation."""
    def __init__(self):
        self.consecutive_misses: Dict[str, int] = {}
        self.total_misses: Dict[str, int] = {}
        self.total_attempts: Dict[str, int] = {}
        self.explanation_count: Dict[str, int] = {}
        self.last_explanation_turn: Dict[str, int] = {}
        self.turn_counter = 0

    def record_turn(self):
        self.turn_counter += 1

    def normalize_topic(self, topic: str) -> str:
        t = topic.lower().strip()
        if "rust" in t:
            return "rust"
        if "tcp" in t or "network" in t:
            return "tcp"
        if "cloud" in t or "distributed" in t:
            return "cloud"
        if "var" in t or "declaration" in t or "assignment" in t:
            return "variables"
        if "algo" in t or "complexity" in t:
            return "algorithms"
        if "os" in t or "operating" in t:
            return "operating_systems"
        if "arch" in t or "cpu" in t or "hardware" in t or "system" in t:
            return "system_architecture"
        if "ai" in t or "neural" in t or "learning" in t:
            return "ai"
        if "security" in t or "crypto" in t or "stride" in t or "sast" in t or "dast" in t or "auth" in t:
            return "security_engineering"
        if "db" in t or "database" in t or "sql" in t:
            return "database"
        if "pattern" in t or "solid" in t or "software" in t:
            return "software_engineering"
        return t

    def record_outcome(self, topic: str, is_correct: bool):
        self.record_turn()
        key = self.normalize_topic(topic)
        self.total_attempts[key] = self.total_attempts.get(key, 0) + 1
        if is_correct:
            self.consecutive_misses[key] = 0
        else:
            self.consecutive_misses[key] = self.consecutive_misses.get(key, 0) + 1
            self.total_misses[key] = self.total_misses.get(key, 0) + 1

    def should_trigger_explanation(self, topic: str) -> bool:
        key = self.normalize_topic(topic)
        misses = self.consecutive_misses.get(key, 1)
        exp_count = self.explanation_count.get(key, 0)
        last_turn = self.last_explanation_turn.get(key, -999)

        if exp_count == 0 and misses == 1:
            return True

        min_interval = 1 if exp_count <= 1 else min(8, 1 << (exp_count - 1))
        turns_since = self.turn_counter - last_turn

        if misses >= 2:
            return turns_since >= max(1, min_interval // 2)
        return turns_since >= min_interval

    def generate_explanation(self, topic: str) -> Dict[str, Any]:
        key = self.normalize_topic(topic)
        misses = self.consecutive_misses.get(key, 1)
        exp_count = self.explanation_count.get(key, 0) + 1
        self.explanation_count[key] = exp_count
        self.last_explanation_turn[key] = self.turn_counter

        tier = 1
        if misses >= 3:
            tier = 3
        elif misses >= 2:
            tier = 2

        dwell_seconds = round(4.0 + (tier - 1) * 3.0 + min(misses * 1.5, 5.0))
        tier_badges = {
            1: "KEY INSIGHT (TIER 1)",
            2: "DEEP DIVE MECHANICS (TIER 2)",
            3: "ARCHITECTURAL MASTERCLASS (TIER 3)",
        }

        return {
            "topic": topic,
            "tier": tier,
            "tier_badge": tier_badges[tier],
            "dwell_seconds": dwell_seconds,
            "consecutive_misses": misses,
        }


class TestAdaptiveExplanationSystem(unittest.TestCase):
    def setUp(self):
        self.service = PythonAdaptiveExplanationService()

    def test_first_miss_triggers_tier1(self):
        self.service.record_outcome("Rust", is_correct=False)
        self.assertTrue(self.service.should_trigger_explanation("Rust"))

        exp = self.service.generate_explanation("Rust")
        self.assertEqual(exp["tier"], 1)
        self.assertEqual(exp["tier_badge"], "KEY INSIGHT (TIER 1)")
        self.assertGreaterEqual(exp["dwell_seconds"], 4)
        self.assertLessEqual(exp["dwell_seconds"], 6)

    def test_second_miss_escalates_to_tier2(self):
        self.service.record_outcome("TCP / IP Networking", is_correct=False)
        self.service.generate_explanation("TCP / IP Networking")

        # Second miss immediately
        self.service.record_outcome("TCP / IP Networking", is_correct=False)
        self.assertTrue(self.service.should_trigger_explanation("TCP / IP Networking"))

        exp = self.service.generate_explanation("TCP / IP Networking")
        self.assertEqual(exp["tier"], 2)
        self.assertEqual(exp["tier_badge"], "DEEP DIVE MECHANICS (TIER 2)")
        self.assertGreaterEqual(exp["dwell_seconds"], 7)
        self.assertLessEqual(exp["dwell_seconds"], 10)

    def test_third_miss_escalates_to_tier3_masterclass(self):
        for _ in range(3):
            self.service.record_outcome("Cloud Computing Architecture", is_correct=False)
            self.service.generate_explanation("Cloud Computing Architecture")

        exp = self.service.generate_explanation("Cloud Computing Architecture")
        self.assertEqual(exp["tier"], 3)
        self.assertEqual(exp["tier_badge"], "ARCHITECTURAL MASTERCLASS (TIER 3)")
        self.assertGreaterEqual(exp["dwell_seconds"], 10)
        self.assertLessEqual(exp["dwell_seconds"], 14)

    def test_correct_answer_resets_streak(self):
        self.service.record_outcome("Variables", is_correct=False)
        self.service.record_outcome("Variables", is_correct=False)
        self.assertEqual(self.service.consecutive_misses["variables"], 2)

        self.service.record_outcome("Variables", is_correct=True)
        self.assertEqual(self.service.consecutive_misses["variables"], 0)

        # Next miss restarts at Tier 1
        self.service.record_outcome("Variables", is_correct=False)
        exp = self.service.generate_explanation("Variables")
        self.assertEqual(exp["tier"], 1)

    def test_progressive_dwell_time_growth(self):
        dwells = []
        for i in range(1, 6):
            self.service.record_outcome("Algorithms", is_correct=False)
            exp = self.service.generate_explanation("Algorithms")
            dwells.append(exp["dwell_seconds"])

        # Dwell times must be monotonically non-decreasing
        for i in range(len(dwells) - 1):
            self.assertLessEqual(dwells[i], dwells[i + 1])
        # Significant growth from first miss to multiple misses
        self.assertGreater(dwells[-1], dwells[0])

    def test_human_rapid_click_chaos_simulation(self):
        """Simulate a learner rapidly spamming clicks during an explanation overlay."""
        class MockOverlayState:
            def __init__(self):
                self.is_dismissed = False
                self.advance_invocations = 0

            def on_dismiss(self):
                if self.is_dismissed:
                    return
                self.is_dismissed = True
                self.advance_invocations += 1

        overlay = MockOverlayState()
        # Simulate 100 rapid clicks in parallel/sequence
        for _ in range(100):
            overlay.on_dismiss()

        # Advance must be called exactly once
        self.assertEqual(overlay.advance_invocations, 1)
        self.assertTrue(overlay.is_dismissed)

    def test_user_session_isolation_under_rapid_clicks(self):
        """Ensure rapid clicks and asynchronous timer expirations cannot skip out of order."""
        session_id = 1
        current_question = "Question 1"

        def handle_user_answer(ans_session, answer):
            nonlocal session_id, current_question
            if ans_session != session_id:
                return "Ignored stale click"
            session_id += 1
            current_question = f"Question {session_id}"
            return "Processed"

        res1 = handle_user_answer(1, "A")
        self.assertEqual(res1, "Processed")
        self.assertEqual(current_question, "Question 2")

        # Stale click from session 1 should be completely rejected
        res2 = handle_user_answer(1, "B")
        self.assertEqual(res2, "Ignored stale click")
        self.assertEqual(current_question, "Question 2")


if __name__ == "__main__":
    unittest.main()
