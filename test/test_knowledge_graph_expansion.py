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
            "DevOps & Site Reliability Engineering",
            "Cybersecurity, Cryptography & Security Engineering",
        ]
        for rd in required_domains:
            self.assertIn(rd, domain_names, f"Missing required domain: '{rd}'")
            dom_node = next(n for n in curriculum_nodes if n["properties"].get("name") == rd)
            props = dom_node.get("properties", {})
            self.assertTrue(len(props.get("introduction", "")) > 20, f"Introduction too short for {rd}")
            self.assertTrue(len(props.get("remediation", "")) > 20, f"Remediation too short for {rd}")
            self.assertTrue(len(props.get("deep_dive", "")) > 20, f"Deep dive too short for {rd}")

        # Verify combined domain has full set of 35 questions across all 5 modalities
        combined_node = next(n for n in curriculum_nodes if n["properties"].get("name") == "Cybersecurity, Cryptography & Security Engineering")
        connected_edges = [e for e in self.kg_data.get("edges", []) if e["source"] == combined_node["id"]]
        self.assertGreaterEqual(len(connected_edges), 30, f"Expected >= 30 questions in combined security domain, got {len(connected_edges)}")

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
        intro = tracker.observe_topic("Cybersecurity, Cryptography & Security Engineering")
        self.assertIsNotNone(intro)
        self.assertEqual(intro[0], "Introduction")

        # Turn 1: First wrong answer -> Tier 1 Refresh
        tracker.turn = 1
        res1 = tracker.record_result("Cybersecurity, Cryptography & Security Engineering", False, cyber_meta)
        self.assertIsNotNone(res1)
        self.assertEqual(res1[0], "Concept Refresh")

        # Turn 3: 2 turns later (satisfies 2^1 backoff) -> Tier 2 Remediation
        tracker.turn = 3
        res2 = tracker.record_result("Cybersecurity, Cryptography & Security Engineering", False, cyber_meta)
        self.assertIsNotNone(res2)
        self.assertEqual(res2[0], "Targeted Remediation Hint")

        # Turn 7: 4 turns later (satisfies 2^2 backoff) -> Tier 3 Deep Dive
        tracker.turn = 7
        res3 = tracker.record_result("Cybersecurity, Cryptography & Security Engineering", False, cyber_meta)
        self.assertIsNotNone(res3)
        self.assertIn("Deep Dive", res3[0])

        # Turn 8: Correct answer resets consecutive misses
        tracker.turn = 8
        res4 = tracker.record_result("Cybersecurity, Cryptography & Security Engineering", True, cyber_meta)
        self.assertIsNone(res4)
        self.assertEqual(tracker.consecutive_misses["Cybersecurity, Cryptography & Security Engineering"], 0)

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

    def test_hierarchical_drilldown_to_rust_leaf_concepts(self):
        """Verify the exact hierarchical chain:
        Computer Science -> Programming Languages -> Rust -> Variable Declaration & Mutability
        along with all core Rust leaf concepts."""
        nodes_by_id = {n["id"]: n for n in self.kg_data.get("nodes", [])}
        adj_out = self.kg_data.get("adjacency", {}).get("outgoing", {})
        edges_by_id = {e["id"]: e for e in self.kg_data.get("edges", [])}

        # 1. Computer Science domain exists
        self.assertIn("domain:computer_science", nodes_by_id)

        # 2. Programming Languages subtopic exists and is linked from Computer Science
        self.assertIn("topic:programming_languages", nodes_by_id)
        cs_targets = {edges_by_id[eid]["target"] for eid in adj_out.get("domain:computer_science", [])}
        self.assertIn("topic:programming_languages", cs_targets)

        # 3. Rust language exists and is linked from Programming Languages
        self.assertIn("lang:rust", nodes_by_id)
        pl_targets = {edges_by_id[eid]["target"] for eid in adj_out.get("topic:programming_languages", [])}
        self.assertIn("lang:rust", pl_targets)

        # 4. Granular Rust leaf concepts exist and are linked from Rust
        rust_targets = {edges_by_id[eid]["target"] for eid in adj_out.get("lang:rust", [])}
        expected_rust_leaves = [
            "leaf:rust:variable_declaration",
            "leaf:rust:ownership_borrowing",
            "leaf:rust:lifetimes",
            "leaf:rust:pattern_matching",
            "leaf:rust:error_handling",
        ]
        for rleaf in expected_rust_leaves:
            self.assertIn(rleaf, nodes_by_id, f"Missing expected leaf node '{rleaf}'")
            self.assertIn(rleaf, rust_targets, f"Leaf node '{rleaf}' must be linked from 'lang:rust'")

        # 5. Check variable declaration specifics
        var_decl = nodes_by_id["leaf:rust:variable_declaration"]
        self.assertIn("Variable Declaration", var_decl["label"])
        props = var_decl.get("properties", {})
        self.assertIn("let", props.get("keywords", []))
        self.assertIn("let mut", props.get("keywords", []))
        self.assertTrue(props.get("immutability_by_default"))

    def test_cross_domain_overlapping_links(self):
        """Verify cross-domain overlapping edges connecting granular concepts back across domains."""
        edges = self.kg_data.get("edges", [])
        edge_pairs = {(e["source"], e["target"]) for e in edges}

        # Rust ownership -> Security Engineering (vulnerability elimination)
        self.assertIn(
            ("leaf:rust:ownership_borrowing", "domain:cybersecurity_cryptography_security_engineering"),
            edge_pairs,
            "Rust ownership must link to Security Engineering",
        )

        # Rust ownership -> Concurrency
        self.assertIn(
            ("leaf:rust:ownership_borrowing", "topic:concurrency"),
            edge_pairs,
            "Rust ownership must link to Concurrency",
        )

        # Rust variable declaration -> Variable syntax engine
        self.assertIn(
            ("leaf:rust:variable_declaration", "concept:variable_syntax"),
            edge_pairs,
            "Rust variable declaration must link to variable syntax engine",
        )

        # Rust lifetimes -> Operating Systems
        self.assertIn(
            ("leaf:rust:lifetimes", "domain:operating_systems"),
            edge_pairs,
            "Rust lifetimes must link to Operating Systems",
        )

        # Go goroutines -> Concurrency
        self.assertIn(
            ("leaf:go:goroutines_channels", "topic:concurrency"),
            edge_pairs,
            "Go goroutines must link to Concurrency",
        )

    def test_spatial_galaxy_clustering_properties(self):
        """Verify 3D spatial properties:
        - Master domains are separated across wide distances (R >= 350)
        - Subtopics and leaf nodes are clustered tightly near their parents (distance < 75)"""
        import math

        # Parse progression nodes from progression_service.dart
        prog_path = Path("lib/services/progression_service.dart")
        self.assertTrue(prog_path.exists())
        with open(prog_path, "r", encoding="utf-8") as f:
            content = f.read()

        import re
        # Find TopicProgressionNode entries and their position3D
        node_pattern = re.compile(
            r"id:\s*'([^']+)'[\s\S]*?position3D:\s*const\s*Vector3D\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)",
            re.MULTILINE,
        )
        positions = {}
        for m in node_pattern.finditer(content):
            nid, x, y, z = m.group(1), float(m.group(2)), float(m.group(3)), float(m.group(4))
            positions[nid] = (x, y, z)

        def dist(p1, p2):
            return math.sqrt((p1[0] - p2[0])**2 + (p1[1] - p2[1])**2 + (p1[2] - p2[2])**2)

        # 1. Master domains are spread far apart
        master_domains = [
            "domain:networking",
            "domain:ai_ml",
            "domain:operating_systems",
            "domain:cloud_computing",
            "domain:security_engineering",
            "domain:system_architecture",
            "domain:databases",
            "domain:software_engineering",
        ]
        origin = (0.0, 0.0, 0.0)
        for md in master_domains:
            self.assertIn(md, positions)
            d = dist(positions[md], origin)
            self.assertGreaterEqual(d, 350.0, f"Master domain '{md}' should be >= 350 from core, got {d:.1f}")

        # 2. Rust leaf nodes are clustered tightly around Rust
        self.assertIn("lang:rust", positions)
        rust_pos = positions["lang:rust"]
        rust_leaves = [
            "leaf:rust:variable_declaration",
            "leaf:rust:ownership_borrowing",
            "leaf:rust:lifetimes",
            "leaf:rust:pattern_matching",
            "leaf:rust:error_handling",
        ]
        for rl in rust_leaves:
            self.assertIn(rl, positions)
            d = dist(positions[rl], rust_pos)
            self.assertLessEqual(d, 65.0, f"Rust leaf '{rl}' should be clustered <= 65 from Rust, got {d:.1f}")

    def test_interactive_node_traversal_simulation(self):
        """Simulate human learner graph traversal through the hierarchical drilldown path:
        Computer Science -> Programming Languages -> Rust -> Variable Declaration
        -> Rust Ownership -> Security Engineering, unlocking knowledge nodes sequentially."""
        from python_driver import PythonKnowledgeGraph

        pkg = PythonKnowledgeGraph(self.kg_data)
        self.assertGreaterEqual(len(pkg.nodes), 600)

        # Step 1: Start at Computer Science
        cs_node = pkg.get_node("domain:computer_science")
        self.assertIsNotNone(cs_node)
        cs_neighbors = pkg.get_outgoing_neighbors("domain:computer_science")
        self.assertIn("topic:programming_languages", cs_neighbors)

        # Step 2: Traverse to Programming Languages
        pl_node = pkg.get_node("topic:programming_languages")
        self.assertIsNotNone(pl_node)
        pl_neighbors = pkg.get_outgoing_neighbors("topic:programming_languages")
        self.assertIn("lang:rust", pl_neighbors)

        # Step 3: Traverse to Rust
        rust_node = pkg.get_node("lang:rust")
        self.assertIsNotNone(rust_node)
        rust_neighbors = pkg.get_outgoing_neighbors("lang:rust")
        self.assertIn("leaf:rust:variable_declaration", rust_neighbors)
        self.assertIn("leaf:rust:ownership_borrowing", rust_neighbors)

        # Step 4: Traverse to Leaf: Rust Variable Declaration
        var_decl_node = pkg.get_node("leaf:rust:variable_declaration")
        self.assertIsNotNone(var_decl_node)
        self.assertEqual(var_decl_node["category"], "Rust")

        # Step 5: Follow cross-domain link from Ownership to Security Engineering
        ownership_node = pkg.get_node("leaf:rust:ownership_borrowing")
        self.assertIsNotNone(ownership_node)
        ownership_neighbors = pkg.get_outgoing_neighbors("leaf:rust:ownership_borrowing")
        self.assertIn("domain:cybersecurity_cryptography_security_engineering", ownership_neighbors)
        self.assertIn("topic:concurrency", ownership_neighbors)


if __name__ == "__main__":
    unittest.main()

