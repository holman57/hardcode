import unittest
from typing import Optional, List, Dict, Any


class MotionGraphicMilestoneEngine:
    """Models milestone evaluation and event triggering for HardCode Motion Graphics."""
    def __init__(self):
        self.streak_milestones = {3: "streak3", 5: "streak5", 10: "streak10", 20: "streak20"}
        self.triggered_events: List[Dict[str, Any]] = []

    def evaluate_turn(
        self,
        current_streak: int,
        old_level: int,
        new_level: int,
        topic: str,
        is_level_start: bool = False,
        idle_seconds: float = 0.0,
    ) -> Optional[str]:
        if is_level_start:
            event = {"type": "levelStart", "topic": topic}
            self.triggered_events.append(event)
            return "levelStart"

        if new_level > old_level:
            event = {"type": "levelComplete", "new_level": new_level, "topic": topic}
            self.triggered_events.append(event)
            return "levelComplete"

        if current_streak in self.streak_milestones:
            m_type = self.streak_milestones[current_streak]
            event = {"type": m_type, "streak": current_streak, "topic": topic}
            self.triggered_events.append(event)
            return m_type

        if idle_seconds >= 15.0:
            event = {"type": "idleReengagement", "topic": topic}
            self.triggered_events.append(event)
            return "idleReengagement"

        return None


class TestMotionGraphicsEngine(unittest.TestCase):
    def setUp(self):
        self.engine = MotionGraphicMilestoneEngine()

    def test_streak_milestone_escalation(self):
        # 1x and 2x streaks do not trigger overlay
        self.assertIsNone(self.engine.evaluate_turn(1, 1, 1, "Rust"))
        self.assertIsNone(self.engine.evaluate_turn(2, 1, 1, "Rust"))

        # 3x Streak triggers Warming Up
        t3 = self.engine.evaluate_turn(3, 1, 1, "Rust")
        self.assertEqual(t3, "streak3")

        # 4x does not trigger
        self.assertIsNone(self.engine.evaluate_turn(4, 1, 1, "Rust"))

        # 5x Streak triggers On Fire!
        t5 = self.engine.evaluate_turn(5, 1, 1, "Rust")
        self.assertEqual(t5, "streak5")

        # 10x Streak triggers Unstoppable!
        t10 = self.engine.evaluate_turn(10, 1, 1, "Rust")
        self.assertEqual(t10, "streak10")

        # 20x Streak triggers Godlike Mastery!
        t20 = self.engine.evaluate_turn(20, 1, 1, "Rust")
        self.assertEqual(t20, "streak20")

    def test_level_complete_priority_over_streak(self):
        # If user both reaches 3x streak AND levels up, Level Complete takes precedence
        t = self.engine.evaluate_turn(current_streak=3, old_level=1, new_level=2, topic="TCP")
        self.assertEqual(t, "levelComplete")
        self.assertEqual(self.engine.triggered_events[-1]["new_level"], 2)

    def test_level_start_event(self):
        t = self.engine.evaluate_turn(0, 1, 1, "Cloud Computing", is_level_start=True)
        self.assertEqual(t, "levelStart")

    def test_idle_reengagement_trigger(self):
        self.assertIsNone(self.engine.evaluate_turn(0, 1, 1, "Algorithms", idle_seconds=10.0))
        t = self.engine.evaluate_turn(0, 1, 1, "Algorithms", idle_seconds=15.5)
        self.assertEqual(t, "idleReengagement")

    def test_instant_skip_simulation(self):
        """Verify that learner tapping or pressing a key immediately dismisses motion graphics."""
        class MockMotionOverlay:
            def __init__(self):
                self.is_active = True
                self.dismiss_count = 0

            def tap_or_key_pressed(self):
                if not self.is_active:
                    return
                self.is_active = False
                self.dismiss_count += 1

        overlay = MockMotionOverlay()
        self.assertTrue(overlay.is_active)
        # User presses space or taps screen after 200ms
        overlay.tap_or_key_pressed()
        self.assertFalse(overlay.is_active)
        self.assertEqual(overlay.dismiss_count, 1)

        # Subsequent spam clicks do not re-trigger
        overlay.tap_or_key_pressed()
        self.assertEqual(overlay.dismiss_count, 1)


if __name__ == "__main__":
    unittest.main()
