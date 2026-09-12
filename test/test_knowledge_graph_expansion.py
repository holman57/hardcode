import unittest
import json
from pathlib import Path
import sys

# Ensure hardcode directory is in path
sys.path.insert(0, str(Path(__file__).parent.parent))

from python_driver import load_database, LearnerTracker


class TestKnowledgeGraphExpansion(unittest.TestCase):
    """Test suite validating Knowledge Graph expansion, 3D structure, and human click simulation."""

    def setUp(self):
        self.kg_path = Path("assets/knowledge_graph.json")
        self.assertTrue(self.kg_path.exists(), "assets/knowledge_graph.json must exist")
        with open(self.kg_path, "r", encoding="utf-8") as f:
            self.kg_data = json.load(f)
        self.db = load_database()

    def test_no_constellation_in_metadata_or_root(self):
        """Ensure all primary graph entities and metadata refer to 'Knowledge Graph' rather than 'Constellation'."""
        metadata = self.kg_data.get("metadata", {})
        self.assertIn("Knowledge Graph", metadata.get("name", ""))
        self.assertNotIn("Constellation", metadata.get("name", ""))

        root = next((n for n in self.kg_data.get("nodes", []) if n.get("type") == "SystemRoot"), None)
        self.assertIsNotNone(root)
        self.assertIn("HardCode Knowledge", root["label"])
        self.assertNotIn("Constellation", root["label"])

    def test_massive_expansion_counts(self):
        """Verify the graph has expanded significantly beyond the original 310 questions and 509 nodes."""
        nodes = self.kg_data.get("nodes", [])
        edges = self.kg_data.get("edges", [])
        q_nodes = [n for n in nodes if n.get("type") == "Question"]

        self.assertGreaterEqual(len(nodes), 600, f"Expected >= 600 nodes, got {len(nodes)}")
        self.assertGreaterEqual(len(edges), 680, f"Expected >= 680 edges, got {len(edges)}")
        self.assertGreaterEqual(len(q_nodes), 400, f"Expected >= 400 questions, got {len(q_nodes)}")

    def test_all_five_question_modalities_present(self):
        """Verify all 5 question types exist in substantial numbers."""
        q_nodes = [n for n in self.kg_data.get("nodes", []) if n.get("type") == "Question"]
        by_subtype = {}
        for q in q_nodes:
            sub = q.get("properties", {}).get("sub_type")
            by_subtype[sub] = by_subtype.get(sub, 0) + 1

        expected = ["True-False", "Multi-Choice", "Matching", "Sequencing", "Sorting-Classification"]
        for eq in expected:
            self.assertIn(eq, by_subtype)
            self.assertGreaterEqual(by_subtype[eq], 15, f"Subtype {eq} count should be >= 15, got {by_subtype[eq]}")

    def test_new_and_expanded_domains_present(self):
        """Verify new domains like Cybersecurity and DevOps are present with full explanations."""
        curriculum_nodes = [n for n in self.kg_data.get("nodes", []) if n.get("type") == "CurriculumDomain"]
        domain_names = {n["properties"].get("name") for n in curriculum_nodes}

        required_domains = [
            "Computer Science",
            "Computer Networking",
            "Artificial Intelligence",
            "Operating Systems",
            "System Architecture",
            "Cloud & Distributed Computing",
            "Databases & Distributed Storage",
            "Software Engineering",
            "Cybersecurity & Cryptography",
            "DevOps & Site Reliability Engineering",
            "Security Engineering",
        ]
        for rd in required_domains:
            self.assertIn(rd, domain_names, f"Missing required domain: '{rd}'")
            dom_node = next(n for n in curriculum_nodes if n["properties"].get("name") == rd)
            props = dom_node.get("properties", {})
            self.assertTrue(len(props.get("introduction", "")) > 20, f"Introduction too short for {rd}")
            self.assertTrue(len(props.get("remediation", "")) > 20, f"Remediation too short for {rd}")
            self.assertTrue(len(props.get("deep_dive", "")) > 20, f"Deep dive too short for {rd}")

    def test_relational_integrity_no_dangling_edges(self):
        """Ensure all edge sources and targets strictly resolve to existing vertices."""
        node_ids = {n["id"] for n in self.kg_data.get("nodes", [])}
        for e in self.kg_data.get("edges", []):
            self.assertIn(e["source"], node_ids, f"Dangling edge source: {e['source']}")
            self.assertIn(e["target"], node_ids, f"Dangling edge target: {e['target']}")

    def test_human_learner_simulation_adaptive_remediation(self):
        """Simulate a learner clicking through questions, failing repeatedly on a topic,
        and verifying tiered escalation from Key Insight -> Remediation Hint -> Deep Dive."""
        tracker = LearnerTracker()
        cyber_meta = {
            "introduction": "Intro to Cryptography & Zero Trust",
            "remediation": "Focus on asymmetric vs symmetric keys",
            "deep_dive": "Mathematical intractability and AEAD AES-GCM",
        }

        # First encounter intro check
        intro = tracker.observe_topic("Cybersecurity & Cryptography")
        self.assertIsNotNone(intro)
        self.assertEqual(intro[0], "Introduction")

        # Turn 1: First wrong answer -> Tier 1 Refresh
        tracker.turn = 1
        res1 = tracker.record_result("Cybersecurity & Cryptography", False, cyber_meta)
        self.assertIsNotNone(res1)
        self.assertEqual(res1[0], "Concept Refresh")

        # Turn 3: 2 turns later (satisfies 2^1 backoff) -> Tier 2 Remediation
        tracker.turn = 3
        res2 = tracker.record_result("Cybersecurity & Cryptography", False, cyber_meta)
        self.assertIsNotNone(res2)
        self.assertEqual(res2[0], "Targeted Remediation Hint")

        # Turn 7: 4 turns later (satisfies 2^2 backoff) -> Tier 3 Deep Dive
        tracker.turn = 7
        res3 = tracker.record_result("Cybersecurity & Cryptography", False, cyber_meta)
        self.assertIsNotNone(res3)
        self.assertIn("Deep Dive", res3[0])

        # Turn 8: Correct answer resets consecutive misses
        tracker.turn = 8
        res4 = tracker.record_result("Cybersecurity & Cryptography", True, cyber_meta)
        self.assertIsNone(res4)
        self.assertEqual(tracker.consecutive_misses["Cybersecurity & Cryptography"], 0)

        # Also verify PythonAdaptiveExplanationService on new domains
        from test.test_adaptive_explanation import PythonAdaptiveExplanationService
        adapt_service = PythonAdaptiveExplanationService()
        adapt_service.record_outcome("Cybersecurity", is_correct=False)
        self.assertTrue(adapt_service.should_trigger_explanation("Cybersecurity"))
        e1 = adapt_service.generate_explanation("Cybersecurity")
        self.assertEqual(e1["tier"], 1)

        adapt_service.record_outcome("Cybersecurity", is_correct=False)
        self.assertTrue(adapt_service.should_trigger_explanation("Cybersecurity"))
        e2 = adapt_service.generate_explanation("Cybersecurity")
        self.assertEqual(e2["tier"], 2)

        adapt_service.record_outcome("Cybersecurity", is_correct=False)
        self.assertTrue(adapt_service.should_trigger_explanation("Cybersecurity"))
        e3 = adapt_service.generate_explanation("Cybersecurity")
        self.assertEqual(e3["tier"], 3)

        # Test Security Engineering domain specifically
        sec_eng_service = PythonAdaptiveExplanationService()
        sec_eng_service.record_outcome("Security Engineering (STRIDE)", is_correct=False)
        self.assertTrue(sec_eng_service.should_trigger_explanation("Security Engineering (STRIDE)"))
        se1 = sec_eng_service.generate_explanation("Security Engineering (STRIDE)")
        self.assertEqual(se1["tier"], 1)
        self.assertEqual(sec_eng_service.normalize_topic("Security Engineering (STRIDE)"), "security_engineering")


if __name__ == "__main__":
    unittest.main()
