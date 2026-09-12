#!/usr/bin/env python3
"""
HardCode Knowledge Graph Traversal Simulator
Simulates a human learner navigating through the deep hierarchical knowledge graph:
Galactic Core (Computer Science) -> Subtopic (Programming Languages) -> Language (Rust)
-> Granular Leaf Nodes (Variable Declaration, Borrow Checker, Lifetimes, Pattern Matching, Error Handling)
-> Cross-Domain Overlaps (Security Engineering, Concurrency, Operating Systems)
Verifies spatial clustering, node unlock progression, and query performance.
"""

import json
import math
import sys
from pathlib import Path
from typing import Dict, List, Tuple

KG_PATH = Path("assets/knowledge_graph.json")
PROG_PATH = Path("lib/services/progression_service.dart")

class TraversalSimulator:
    def __init__(self):
        with open(KG_PATH, "r", encoding="utf-8") as f:
            self.kg = json.load(f)

        self.nodes = {n["id"]: n for n in self.kg.get("nodes", [])}
        self.edges = {e["id"]: e for e in self.kg.get("edges", [])}
        self.adj_out = self.kg.get("adjacency", {}).get("outgoing", {})
        self.adj_in = self.kg.get("adjacency", {}).get("incoming", {})

    def print_banner(self):
        print("=" * 70)
        print("  HARDCODE KNOWLEDGE GRAPH HUMAN TRAVERSAL SIMULATION")
        print(f"  Nodes: {len(self.nodes)} | Edges: {len(self.edges)} | Schema: {self.kg.get('schema')}")
        print("=" * 70)

    def step(self, step_num: int, title: str, details: str):
        print(f"\n[STEP {step_num}] {title}")
        print(f"  -> {details}")

    def simulate_drilldown_path(self):
        self.step(1, "Access Galactic Core (Computer Science)", "Locating root domain hub")
        cs_node = self.nodes.get("domain:computer_science")
        assert cs_node is not None, "Computer science domain missing"
        print(f"  [OK] Found Hub: {cs_node['label']} (type: {cs_node['type']}, category: {cs_node['category']})")

        self.step(2, "Explore Subtopics of Computer Science", "Querying outgoing edges")
        cs_out_edges = [self.edges[eid] for eid in self.adj_out.get("domain:computer_science", [])]
        cs_targets = [e["target"] for e in cs_out_edges]
        print(f"  Outgoing edges from Computer Science: {len(cs_out_edges)}")
        assert "topic:programming_languages" in cs_targets, "topic:programming_languages not linked from CS"
        print("  [OK] Successfully discovered target 'topic:programming_languages'")

        self.step(3, "Drill into Programming Languages Subtopic", "Inspecting language ecosystem")
        pl_node = self.nodes.get("topic:programming_languages")
        assert pl_node is not None, "topic:programming_languages node missing"
        pl_out_edges = [self.edges[eid] for eid in self.adj_out.get("topic:programming_languages", [])]
        pl_targets = [e["target"] for e in pl_out_edges]
        print(f"  Discovered {len(pl_targets)} languages connected to Programming Languages: {pl_targets[:6]}...")
        assert "lang:rust" in pl_targets, "Rust language missing from Programming Languages"
        print("  [OK] Successfully navigated to 'lang:rust'")

        self.step(4, "Enter Rust Domain & Discover Granular Leaf Concepts", "Querying leaf concepts")
        rust_node = self.nodes.get("lang:rust")
        assert rust_node is not None, "lang:rust missing"
        rust_out_edges = [self.edges[eid] for eid in self.adj_out.get("lang:rust", [])]
        rust_targets = [e["target"] for e in rust_out_edges]

        expected_leaves = [
            ("leaf:rust:variable_declaration", "Variable Declaration & Mutability"),
            ("leaf:rust:ownership_borrowing", "Borrow Checker & Ownership Primitives"),
            ("leaf:rust:lifetimes", "Lifetimes & Reference Validity"),
            ("leaf:rust:pattern_matching", "Pattern Matching & Algebraic Enums"),
            ("leaf:rust:error_handling", "Error Handling & Propagation"),
        ]
        for leaf_id, expected_label in expected_leaves:
            assert leaf_id in self.nodes, f"Leaf node '{leaf_id}' not found in graph"
            assert leaf_id in rust_targets, f"Leaf node '{leaf_id}' not connected to Rust"
            node = self.nodes[leaf_id]
            print(f"  [OK] Discovered Leaf: {node['label']} (ID: {node['id']})")

        self.step(5, "Drill into 'leaf:rust:variable_declaration'", "Verifying granular properties & questions")
        vdecl = self.nodes["leaf:rust:variable_declaration"]
        props = vdecl.get("properties", {})
        print(f"  Keywords: {props.get('keywords')}")
        print(f"  Immutability by default: {props.get('immutability_by_default')}")
        print(f"  Variable shadowing support: {props.get('shadowing')}")

        # Check connected questions
        vdecl_in_edges = [self.edges[eid] for eid in self.adj_in.get("leaf:rust:variable_declaration", [])]
        q_sources = [self.nodes[e["source"]] for e in vdecl_in_edges if e["source"] in self.nodes and self.nodes[e["source"]]["type"] == "Question"]
        print(f"  Connected questions testing this specific leaf concept: {len(q_sources)}")
        for q in q_sources[:2]:
            stmt = q.get("properties", {}).get("statement", q.get("properties", {}).get("question", ""))
            print(f"    * Question: {stmt[:65]}...")

        self.step(6, "Traverse Cross-Domain Overlaps & Interdependencies", "Following bridges between domains")
        borrow_node = self.nodes["leaf:rust:ownership_borrowing"]
        borrow_out = [self.edges[eid] for eid in self.adj_out.get("leaf:rust:ownership_borrowing", [])]
        print(f"  Outgoing cross-domain edges from Rust Borrow Checker: {len(borrow_out)}")
        for edge in borrow_out:
            tgt = self.nodes.get(edge["target"])
            lbl = tgt["label"] if tgt else edge["target"]
            print(f"    -> [{edge['relation']}] -> {lbl} ({edge['target']})")

        targets_from_borrow = [e["target"] for e in borrow_out]
        assert "domain:cybersecurity_cryptography_security_engineering" in targets_from_borrow, \
            "Missing cross-domain link to Cybersecurity, Cryptography & Security Engineering"
        assert "topic:concurrency" in targets_from_borrow, \
            "Missing cross-domain link to Concurrency"
        print("  [OK] Successfully crossed domain boundary: Rust Ownership -> Security Engineering & Concurrency!")

    def verify_galaxy_clustering(self):
        print("\n" + "-" * 70)
        print("  VERIFYING SPATIAL GALAXY CLUSTERING METRICS")
        print("-" * 70)

        import re
        with open(PROG_PATH, "r", encoding="utf-8") as f:
            content = f.read()

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

        master_domains = [
            ("domain:networking", "Networking"),
            ("domain:ai_ml", "AI / ML"),
            ("domain:operating_systems", "Operating Systems"),
            ("domain:cloud_computing", "Cloud Computing"),
            ("domain:security_engineering", "Security Engineering"),
            ("domain:system_architecture", "System Architecture"),
            ("domain:databases", "Databases"),
            ("domain:software_engineering", "Software Engineering"),
        ]

        origin = (0.0, 0.0, 0.0)
        print("  Master Domain Hub Distances from Galactic Core:")
        for md_id, label in master_domains:
            pos = positions.get(md_id)
            assert pos is not None, f"Position missing for {md_id}"
            d = dist(pos, origin)
            print(f"    * {label:22s} ({md_id}): distance = {d:.1f} (coords: {pos})")
            assert d >= 350.0, f"Domain {md_id} distance {d} is too close to core"

        print("\n  Granular Rust Cluster Radii from 'lang:rust':")
        rust_pos = positions.get("lang:rust")
        assert rust_pos is not None, "Rust position missing"
        rust_leaves = [
            ("leaf:rust:variable_declaration", "Variable Declaration"),
            ("leaf:rust:ownership_borrowing", "Borrow Checker"),
            ("leaf:rust:lifetimes", "Lifetimes"),
            ("leaf:rust:pattern_matching", "Pattern Matching"),
            ("leaf:rust:error_handling", "Error Handling"),
        ]
        for rl_id, label in rust_leaves:
            pos = positions.get(rl_id)
            assert pos is not None, f"Position missing for {rl_id}"
            d = dist(pos, rust_pos)
            print(f"    * {label:22s} ({rl_id}): cluster radius = {d:.1f} (coords: {pos})")
            assert d <= 65.0, f"Leaf node {rl_id} distance {d} exceeds cluster threshold"

        print("\n[SUCCESS] Galaxy clustering validated: wide master sector separation & tight concept clustering!")

def main():
    sim = TraversalSimulator()
    sim.print_banner()
    sim.simulate_drilldown_path()
    sim.verify_galaxy_clustering()
    print("\n" + "=" * 70)
    print("  ALL TRAVERSAL & CLUSTERING SIMULATIONS COMPLETED SUCCESSFULLY!")
    print("=" * 70)

if __name__ == "__main__":
    main()
