import unittest
import json
from pathlib import Path
import re
import sys

# Ensure hardcode directory is in path
ROOT_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT_DIR))

from scripts.bump_version import (
    parse_semver,
    calculate_next_version,
    load_version_state,
    bump_version,
    VERSION_FILE,
    PUBSPEC_FILE,
    README_FILE,
    KG_FILE,
    DB_FILE,
)


class TestVersionBumpSystem(unittest.TestCase):
    """Test suite validating automated version management and synchronization."""

    def test_parse_semver(self):
        self.assertEqual(parse_semver("1.3.0"), (1, 3, 0))
        self.assertEqual(parse_semver("v2.10.4"), (2, 10, 4))
        self.assertEqual(parse_semver("0.0.1"), (0, 0, 1))
        with self.assertRaises(ValueError):
            parse_semver("invalid-semver")
        with self.assertRaises(ValueError):
            parse_semver("1.2")

    def test_calculate_next_version(self):
        self.assertEqual(calculate_next_version("1.3.0", "patch"), "1.3.1")
        self.assertEqual(calculate_next_version("1.3.9", "patch"), "1.3.10")
        self.assertEqual(calculate_next_version("1.3.5", "minor"), "1.4.0")
        self.assertEqual(calculate_next_version("1.3.5", "major"), "2.0.0")
        with self.assertRaises(ValueError):
            calculate_next_version("1.3.0", "unknown")

    def test_version_files_consistency(self):
        """Ensure version.json, pubspec.yaml, README.md, and Knowledge Graph are in sync."""
        self.assertTrue(VERSION_FILE.exists(), "version.json must exist")
        state = load_version_state()
        version = state["version"]
        self.assertTrue(re.match(r"^\d+\.\d+\.\d+$", version))

        # Check pubspec.yaml
        if PUBSPEC_FILE.exists():
            with open(PUBSPEC_FILE, "r", encoding="utf-8") as f:
                content = f.read()
            self.assertIn(f"version: {version}", content)

        # Check README.md
        if README_FILE.exists():
            with open(README_FILE, "r", encoding="utf-8") as f:
                readme = f.read()
            self.assertIn(f"v{version}", readme)

        # Check Knowledge Graph
        if KG_FILE.exists():
            with open(KG_FILE, "r", encoding="utf-8") as f:
                kg = json.load(f)
            self.assertEqual(kg.get("graph_version"), f"{version}-graph")

    def test_dry_run_bump(self):
        """Verify dry-run mode returns new version without modifying files."""
        initial_state = load_version_state()
        next_ver = bump_version(bump_type="patch", dry_run=True)
        self.assertEqual(next_ver, calculate_next_version(initial_state["version"], "patch"))
        # Verify file was not modified
        after_state = load_version_state()
        self.assertEqual(initial_state["version"], after_state["version"])

    def test_git_hooks_installed(self):
        """Verify post-merge and pre-push hooks are installed in .git/hooks."""
        hooks_dir = ROOT_DIR / ".git" / "hooks"
        if hooks_dir.exists():
            post_merge = hooks_dir / "post-merge"
            pre_push = hooks_dir / "pre-push"
            self.assertTrue(post_merge.exists(), "post-merge hook must be installed")
            self.assertTrue(pre_push.exists(), "pre-push hook must be installed")


if __name__ == "__main__":
    unittest.main()
