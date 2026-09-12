#!/usr/bin/env python3
"""
HardCode Knowledge Graph Builder
Translates assets/db.json into a formal, queryable Knowledge Graph
structure (assets/knowledge_graph.json) optimized for graph queries,
relational integrity, and interactive visual layout.
"""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple


def slugify(text: str) -> str:
    """Convert text into a normalized, deterministic slug ID preserving language distinctions."""
    s = str(text).strip()
    s = s.replace("++", "pp").replace("+", "plus").replace("#", "sharp")
    s = s.lower()
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[\s_-]+", "_", s)
    return s.strip("_") or "entity"


def generate_node_id(prefix: str, label: str) -> str:
    """Generate a clean namespaced node identifier."""
    slug = slugify(label)
    return f"{prefix}:{slug}"


def generate_edge_id(source: str, relation: str, target: str) -> str:
    """Generate a clean deterministic edge identifier."""
    return f"e:{source}->{relation}->{target}"


class KnowledgeGraphBuilder:
    def __init__(self, source_db_path: Path):
        self.source_db_path = source_db_path
        self.nodes: Dict[str, Dict[str, Any]] = {}
        self.edges: Dict[str, Dict[str, Any]] = {}
        self.edge_keys: Set[Tuple[str, str, str]] = set()

        # Group colors for visualization
        self.group_styles = {
            "root": {"color": "#1E1E2E", "size": 38, "level": 0, "icon": "hub"},
            "domain": {"color": "#6366F1", "size": 32, "level": 1, "icon": "domain"},
            "language": {"color": "#3B82F6", "size": 26, "level": 2, "icon": "code"},
            "database": {"color": "#EC4899", "size": 22, "level": 2, "icon": "storage"},
            "paradigm": {"color": "#8B5CF6", "size": 22, "level": 2, "icon": "category"},
            "os": {"color": "#06B6D4", "size": 22, "level": 2, "icon": "devices"},
            "concept": {"color": "#F59E0B", "size": 20, "level": 2, "icon": "lightbulb"},
            "syntax": {"color": "#0EA5E9", "size": 18, "level": 3, "icon": "terminal"},
            "question_tf": {"color": "#14B8A6", "size": 16, "level": 3, "icon": "check_circle"},
            "question_matching": {"color": "#F97316", "size": 16, "level": 3, "icon": "compare_arrows"},
            "question_sequencing": {"color": "#A855F7", "size": 16, "level": 3, "icon": "format_list_numbered"},
            "question_sorting": {"color": "#E11D48", "size": 16, "level": 3, "icon": "dashboard_customize"},
            "question_mc": {"color": "#10B981", "size": 16, "level": 3, "icon": "quiz"},
        }

    def add_node(
        self,
        node_id: str,
        label: str,
        node_type: str,
        category: str,
        group: str,
        properties: Optional[Dict[str, Any]] = None,
        custom_size: Optional[int] = None,
        custom_color: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Add or update a vertex in the Knowledge Graph with visualization attributes."""
        style = self.group_styles.get(group, {"color": "#64748B", "size": 20, "level": 2, "icon": "circle"})
        
        node = {
            "id": node_id,
            "label": label,
            "type": node_type,
            "category": category,
            "properties": properties or {},
            "visualization": {
                "group": group,
                "color": custom_color or style["color"],
                "size": custom_size or style["size"],
                "level": style["level"],
                "icon": style["icon"],
            },
        }
        self.nodes[node_id] = node
        return node

    def add_edge(
        self,
        source_id: str,
        target_id: str,
        relation: str,
        label: Optional[str] = None,
        weight: float = 1.0,
        directed: bool = True,
        properties: Optional[Dict[str, Any]] = None,
    ) -> Optional[Dict[str, Any]]:
        """Add a directed edge between two vertices with relational integrity checks."""
        if source_id not in self.nodes:
            print(f"[WARN] Edge source '{source_id}' does not exist. Skipping edge.")
            return None
        if target_id not in self.nodes:
            print(f"[WARN] Edge target '{target_id}' does not exist. Skipping edge.")
            return None

        edge_tuple = (source_id, relation, target_id)
        if edge_tuple in self.edge_keys:
            return None
        self.edge_keys.add(edge_tuple)

        edge_id = generate_edge_id(source_id, relation, target_id)
        display_label = label or relation.replace("_", " ").title()

        edge = {
            "id": edge_id,
            "source": source_id,
            "target": target_id,
            "relation": relation,
            "label": display_label,
            "weight": weight,
            "directed": directed,
            "properties": properties or {},
        }
        self.edges[edge_id] = edge
        return edge

    def build(self) -> Dict[str, Any]:
        """Build the complete knowledge graph from the source JSON database."""
        with open(self.source_db_path, "r", encoding="utf-8") as f:
            raw_db = json.load(f)

        # 1. Root Knowledge Node
        root_id = "root:hardcode"
        self.add_node(
            node_id=root_id,
            label="HardCode Knowledge Base",
            node_type="SystemRoot",
            category="Root",
            group="root",
            properties={
                "description": "Central root for all programming languages, system paradigms, and CS curriculum.",
                "original_version": raw_db.get("version", 7),
            },
        )

        # 2. Programming Paradigms
        paradigms = {
            "paradigm:oop": ("Object-Oriented Programming", "Programming Paradigm"),
            "paradigm:functional": ("Functional Programming", "Programming Paradigm"),
            "paradigm:systems": ("Systems Programming", "Programming Paradigm"),
            "paradigm:scripting": ("Scripting & Automation", "Programming Paradigm"),
        }
        for pid, (plabel, pcat) in paradigms.items():
            self.add_node(pid, plabel, "Paradigm", pcat, "paradigm")
            self.add_edge(root_id, pid, "COVERS_PARADIGM", "Covers Paradigm", weight=1.5)

        # 3. Operating Systems
        os_data = raw_db.get("Operating System", {})
        os_names = os_data.get("Names", ["Desktop", "Mobile"])
        for os_group in os_names:
            group_id = generate_node_id("os_group", os_group)
            self.add_node(group_id, os_group, "OperatingSystemGroup", "Platform", "os")
            self.add_edge(root_id, group_id, "TARGETS_PLATFORM_GROUP", "Targets Platform Group")
            for specific_os in os_data.get(os_group, []):
                os_id = generate_node_id("os", specific_os)
                self.add_node(os_id, specific_os, "OperatingSystem", os_group, "os")
                self.add_edge(group_id, os_id, "CONTAINS_OS", "Contains OS")

        # 4. Programming Languages
        oop_list = raw_db.get("OOP", [])
        lang_notes = raw_db.get("Language Specific Notes", {})
        languages = raw_db.get("Language", [])
        for lang in languages:
            lang_id = generate_node_id("lang", lang)
            is_oop = lang in oop_list
            notes = lang_notes.get(lang, [])

            self.add_node(
                node_id=lang_id,
                label=lang,
                node_type="Language",
                category="Programming Language",
                group="language",
                properties={
                    "name": lang,
                    "is_oop": is_oop,
                    "notes": notes,
                },
            )
            self.add_edge(root_id, lang_id, "INCLUDES_LANGUAGE", "Includes Language", weight=2.0)

            if is_oop:
                self.add_edge(lang_id, "paradigm:oop", "SUPPORTS_PARADIGM", "Supports Paradigm")

        # 5. Databases
        db_specific_notes = raw_db.get("DB Specific Notes", {})
        general_db_notes = raw_db.get("General DB Notes", [])
        databases = raw_db.get("DB", [])

        # Database category node
        db_root_id = "category:databases"
        self.add_node(db_root_id, "Database Engines", "Category", "Data Management", "database", {
            "general_notes": general_db_notes
        })
        self.add_edge(root_id, db_root_id, "COVERS_CATEGORY", "Covers Category")

        for db_name in databases:
            db_id = generate_node_id("db", db_name)
            notes = db_specific_notes.get(db_name, [])
            self.add_node(
                node_id=db_id,
                label=db_name,
                node_type="Database",
                category="Database",
                group="database",
                properties={"name": db_name, "notes": notes},
            )
            self.add_edge(db_root_id, db_id, "INCLUDES_DATABASE", "Includes Database")

        # 6. Language Structure Concepts
        lang_structure = raw_db.get("Language Structure", {})
        for concept_group, subtopics in lang_structure.items():
            group_id = generate_node_id("concept_group", concept_group)
            self.add_node(group_id, concept_group, "ConceptGroup", "Language Structure", "concept")
            self.add_edge(root_id, group_id, "COVERS_CONCEPT_GROUP", "Covers Concept Group")
            for sub in subtopics:
                sub_id = generate_node_id("concept", f"{concept_group}_{sub}")
                self.add_node(sub_id, sub, "Concept", concept_group, "concept")
                self.add_edge(group_id, sub_id, "HAS_SUBTOPIC", "Has Subtopic")

        # 7. Variables Syntax Templates & Rules
        variables_data = raw_db.get("Variables", {})
        decl_data = variables_data.get("Declaration", {})

        syntax_root_id = "concept:variable_syntax"
        self.add_node(
            syntax_root_id,
            "Variable Syntax Engine",
            "SyntaxEngine",
            "Language Mechanics",
            "syntax",
            properties={
                "int_variable_names": variables_data.get("Int Variable Names", []),
                "int_small_var_sets": variables_data.get("Integer Small Variable Sets", []),
                "rust_int_types": variables_data.get("Rust Int Variable Types", []),
                "string_variable_names": variables_data.get("String Variable Names", []),
                "string_values": variables_data.get("String Values", []),
                "bool_variable_names": variables_data.get("Bool Variable Names", []),
                "bool_values": variables_data.get("Bool Values", []),
                "variable_permutations": variables_data.get("Variable Permutations", []),
                "random_variables": variables_data.get("Random Variables", []),
            },
        )
        self.add_edge(root_id, syntax_root_id, "HAS_SYNTAX_ENGINE", "Has Syntax Engine")

        for category_name, cat_val in decl_data.items():
            if not isinstance(cat_val, dict):
                continue
            cat_node_id = generate_node_id("syntax_cat", category_name)
            self.add_node(
                cat_node_id,
                category_name,
                "SyntaxCategory",
                "Variable Declaration",
                "syntax",
                properties={
                    "type": cat_val.get("Type"),
                    "sub_type": cat_val.get("Sub-Type"),
                    "questions": cat_val.get("Question", []),
                    "answers": cat_val.get("Answers", {}),
                },
            )
            self.add_edge(syntax_root_id, cat_node_id, "HAS_SYNTAX_CATEGORY", "Has Syntax Category")

            # Link languages to their specific syntax answers
            answers = cat_val.get("Answers", {})
            pref = answers.get("Preferred", {})
            for lang_name, syntax_snippet in pref.items():
                lang_node_id = generate_node_id("lang", lang_name)
                if lang_node_id in self.nodes:
                    self.add_edge(
                        lang_node_id,
                        cat_node_id,
                        "IMPLEMENTS_SYNTAX",
                        "Implements Syntax",
                        properties={"preferred_syntax": syntax_snippet},
                    )

        # 8. Curriculum Domains & Interactive Questions
        curriculum = raw_db.get("Curriculum", {})
        q_count = 0

        for domain_name, ddata in curriculum.items():
            domain_id = generate_node_id("domain", domain_name)
            self.add_node(
                domain_id,
                domain_name,
                "CurriculumDomain",
                "Computer Science",
                "domain",
                properties={
                    "name": domain_name,
                    "introduction": ddata.get("introduction", ""),
                    "remediation": ddata.get("remediation", ""),
                    "deep_dive": ddata.get("deep_dive", ""),
                },
            )
            self.add_edge(root_id, domain_id, "COVERS_CURRICULUM_DOMAIN", "Covers Domain", weight=2.5)

            questions = ddata.get("questions", {})

            # 8a. True / False Questions
            for i, q in enumerate(questions.get("True-False", [])):
                q_count += 1
                qid = f"q:tf:{slugify(domain_name)}_{i+1}"
                stmt = q.get("statement", "")
                label = (stmt[:42] + "...") if len(stmt) > 42 else stmt
                self.add_node(
                    qid,
                    label,
                    "Question",
                    "True-False",
                    "question_tf",
                    properties={
                        "domain": domain_name,
                        "sub_type": "True-False",
                        "statement": stmt,
                        "is_true": q.get("is_true", True),
                        "explanation": q.get("explanation", ""),
                    },
                )
                self.add_edge(domain_id, qid, "HAS_QUESTION", "Has Question")

            # 8b. Matching Questions
            for i, q in enumerate(questions.get("Matching", [])):
                q_count += 1
                qid = f"q:matching:{slugify(domain_name)}_{i+1}"
                prompt = q.get("prompt", "Match items")
                label = (prompt[:42] + "...") if len(prompt) > 42 else prompt
                pairs = q.get("pairs", {})
                self.add_node(
                    qid,
                    label,
                    "Question",
                    "Matching",
                    "question_matching",
                    properties={
                        "domain": domain_name,
                        "sub_type": "Matching",
                        "prompt": prompt,
                        "pairs": pairs,
                    },
                )
                self.add_edge(domain_id, qid, "HAS_QUESTION", "Has Question")

            # 8c. Sequencing Questions
            for i, q in enumerate(questions.get("Sequencing", [])):
                q_count += 1
                qid = f"q:sequencing:{slugify(domain_name)}_{i+1}"
                prompt = q.get("prompt", "Arrange steps")
                label = (prompt[:42] + "...") if len(prompt) > 42 else prompt
                seq = q.get("sequence", []) or q.get("ordered_sequence", [])
                self.add_node(
                    qid,
                    label,
                    "Question",
                    "Sequencing",
                    "question_sequencing",
                    properties={
                        "domain": domain_name,
                        "sub_type": "Sequencing",
                        "prompt": prompt,
                        "sequence": seq,
                        "ordered_sequence": seq,
                    },
                )
                self.add_edge(domain_id, qid, "HAS_QUESTION", "Has Question")

            # 8d. Sorting / Classification Questions
            for i, q in enumerate(questions.get("Sorting-Classification", [])):
                q_count += 1
                qid = f"q:sorting:{slugify(domain_name)}_{i+1}"
                prompt = q.get("prompt", "Classify items")
                label = (prompt[:42] + "...") if len(prompt) > 42 else prompt
                categories = q.get("categories", [])
                items = q.get("items", {})
                self.add_node(
                    qid,
                    label,
                    "Question",
                    "Sorting-Classification",
                    "question_sorting",
                    properties={
                        "domain": domain_name,
                        "sub_type": "Sorting-Classification",
                        "prompt": prompt,
                        "categories": categories,
                        "items": items,
                    },
                )
                self.add_edge(domain_id, qid, "HAS_QUESTION", "Has Question")

            # 8e. Multi-Choice Conceptual Questions
            for i, q in enumerate(questions.get("Multi-Choice", [])):
                q_count += 1
                qid = f"q:mc:{slugify(domain_name)}_{i+1}"
                qtext = q.get("question", "Conceptual question")
                label = (qtext[:42] + "...") if len(qtext) > 42 else qtext
                choices = q.get("choices", []) or q.get("options", [])
                c_idx = q.get("correct_index", 0)
                correct = q.get("correct", "")
                if not correct and choices and 0 <= c_idx < len(choices):
                    correct = choices[c_idx]
                self.add_node(
                    qid,
                    label,
                    "Question",
                    "Multi-Choice",
                    "question_mc",
                    properties={
                        "domain": domain_name,
                        "sub_type": "Multi-Choice",
                        "question": qtext,
                        "options": choices,
                        "choices": choices,
                        "correct": correct,
                        "correct_index": c_idx,
                        "explanation": q.get("explanation", ""),
                    },
                )
                self.add_edge(domain_id, qid, "HAS_QUESTION", "Has Question")

        # 9. Compute Adjacency & Indices
        adjacency_outgoing: Dict[str, List[str]] = {nid: [] for nid in self.nodes}
        adjacency_incoming: Dict[str, List[str]] = {nid: [] for nid in self.nodes}

        for edge_id, edge in self.edges.items():
            src = edge["source"]
            tgt = edge["target"]
            adjacency_outgoing[src].append(edge_id)
            adjacency_incoming[tgt].append(edge_id)

        index_by_type: Dict[str, List[str]] = {}
        index_by_group: Dict[str, List[str]] = {}
        index_by_category: Dict[str, List[str]] = {}

        for nid, node in self.nodes.items():
            ntype = node["type"]
            ngroup = node["visualization"]["group"]
            ncat = node["category"]

            index_by_type.setdefault(ntype, []).append(nid)
            index_by_group.setdefault(ngroup, []).append(nid)
            index_by_category.setdefault(ncat, []).append(nid)

        # 10. Assemble Final Graph Object
        semver = "1.3.0"
        v_file = self.source_db_path.parent.parent / "version.json" if self.source_db_path else None
        if v_file and v_file.exists():
            try:
                with open(v_file, "r", encoding="utf-8") as vf:
                    semver = json.load(vf).get("version", "1.3.0")
            except Exception:
                pass

        graph_data = {
            "version": raw_db.get("version", 7),
            "graph_version": f"{semver}-graph",
            "schema": "knowledge-graph",
            "metadata": {
                "name": "HardCode Knowledge Graph",
                "schema": "knowledge-graph",
                "version": raw_db.get("version", 7),
                "graph_version": f"{semver}-graph",
                "description": "Structured graph database powering syntax flashcards, CS curriculum, and visual navigation.",
                "node_count": len(self.nodes),
                "edge_count": len(self.edges),
                "question_count": q_count,
                "created_at": "2026-09-10T21:30:00Z",
                "types": sorted(list(index_by_type.keys())),
                "groups": sorted(list(index_by_group.keys())),
            },
            "nodes": list(self.nodes.values()),
            "edges": list(self.edges.values()),
            "adjacency": {
                "outgoing": adjacency_outgoing,
                "incoming": adjacency_incoming,
            },
            "indices": {
                "by_type": index_by_type,
                "by_group": index_by_group,
                "by_category": index_by_category,
            },
            # Bridge accessors providing 100% backward-compatible dictionary shapes
            # for legacy question generators during transition
            "legacy_bridge": {
                "version": raw_db.get("version", 7),
                "Language": languages,
                "Curriculum": curriculum,
                "Variables": variables_data,
                "DB": databases,
                "OOP": oop_list,
                "Operating System": os_data,
                "Language Structure": lang_structure,
                "Question Types": raw_db.get("Question Types", {}),
                "Pedagogy": raw_db.get("Pedagogy", {}),
            },
        }

        return graph_data


def validate_graph(graph: Dict[str, Any]) -> bool:
    """Run comprehensive validation on graph structure, references, and styling."""
    nodes = {n["id"]: n for n in graph.get("nodes", [])}
    edges = graph.get("edges", [])
    adj_out = graph.get("adjacency", {}).get("outgoing", {})
    adj_in = graph.get("adjacency", {}).get("incoming", {})

    print(f"[VALIDATION] Total Nodes: {len(nodes)}")
    print(f"[VALIDATION] Total Edges: {len(edges)}")
    print(f"[VALIDATION] Total Questions: {graph.get('metadata', {}).get('question_count')}")

    # 1. No dangling edges
    for e in edges:
        src = e["source"]
        tgt = e["target"]
        if src not in nodes:
            raise ValueError(f"Dangling edge source: '{src}' in edge {e['id']}")
        if tgt not in nodes:
            raise ValueError(f"Dangling edge target: '{tgt}' in edge {e['id']}")

    # 2. Every node has valid visualization metadata
    for nid, node in nodes.items():
        vis = node.get("visualization")
        if not vis:
            raise ValueError(f"Node '{nid}' missing visualization block")
        for req_field in ["group", "color", "size", "level", "icon"]:
            if req_field not in vis:
                raise ValueError(f"Node '{nid}' missing visualization field '{req_field}'")
        if not vis["color"].startswith("#") or len(vis["color"]) != 7:
            raise ValueError(f"Node '{nid}' has invalid hex color '{vis['color']}'")

    # 3. Adjacency consistency
    for e in edges:
        eid = e["id"]
        src = e["source"]
        tgt = e["target"]
        if eid not in adj_out.get(src, []):
            raise ValueError(f"Edge {eid} missing from outgoing adjacency of {src}")
        if eid not in adj_in.get(tgt, []):
            raise ValueError(f"Edge {eid} missing from incoming adjacency of {tgt}")

    # 4. Check all 5 question types exist
    q_types = set()
    for n in nodes.values():
        if n["type"] == "Question":
            q_types.add(n["properties"].get("sub_type"))
    expected_q_types = {"True-False", "Matching", "Sequencing", "Sorting-Classification", "Multi-Choice"}
    missing_q_types = expected_q_types - q_types
    if missing_q_types:
        raise ValueError(f"Missing question types in graph: {missing_q_types}")

    print(f"[VALIDATION SUCCESS] All integrity checks passed! Question types verified: {sorted(list(q_types))}")
    return True


def main():
    parser = argparse.ArgumentParser(description="HardCode Knowledge Graph Builder")
    parser.add_argument("--source", default=None, help="Path to source db.json if rebuilding")
    parser.add_argument("--output", default="assets/knowledge_graph.json", help="Path to target knowledge_graph.json")
    parser.add_argument("--validate", action="store_true", help="Run validation on output graph")

    args = parser.parse_args()
    output_path = Path(args.output)

    if args.source:
        source_path = Path(args.source)
        if not source_path.exists():
            print(f"Error: Source file '{source_path}' does not exist.", file=sys.stderr)
            sys.exit(1)

        print(f"Building Knowledge Graph from '{source_path}'...")
        builder = KnowledgeGraphBuilder(source_path)
        graph = builder.build()

        print(f"Writing Knowledge Graph to '{output_path}'...")
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(graph, f, indent=2, ensure_ascii=False)

        print(f"Saved {len(graph['nodes'])} nodes and {len(graph['edges'])} edges.")
    else:
        if not output_path.exists():
            print(f"Error: Target graph '{output_path}' does not exist.", file=sys.stderr)
            sys.exit(1)
        with open(output_path, "r", encoding="utf-8") as f:
            graph = json.load(f)

    validate_graph(graph)


if __name__ == "__main__":
    main()
