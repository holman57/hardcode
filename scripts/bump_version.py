#!/usr/bin/env python3
"""
Automated Version Management & Synchronization System for HardCode.
Synchronizes version increments across:
1. version.json (Single source of truth)
2. pubspec.yaml (Flutter application version + build number)
3. README.md (Badges, edition titles, and changelog headers)
4. assets/knowledge_graph.json (Graph schema & metadata versioning)
5. assets/db.json (Curriculum database version)
"""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import sys
from typing import Dict, Optional, Tuple


ROOT_DIR = Path(__file__).parent.parent
VERSION_FILE = ROOT_DIR / "version.json"
PUBSPEC_FILE = ROOT_DIR / "pubspec.yaml"
README_FILE = ROOT_DIR / "README.md"
KG_FILE = ROOT_DIR / "assets" / "knowledge_graph.json"
DB_FILE = ROOT_DIR / "assets" / "db.json"


def parse_semver(version_str: str) -> Tuple[int, int, int]:
    """Parse semver string into (major, minor, patch) integers."""
    clean = version_str.strip().lstrip("v")
    match = re.match(r"^(\d+)\.(\d+)\.(\d+)", clean)
    if not match:
        raise ValueError(f"Invalid semver version string: '{version_str}'")
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


def calculate_next_version(current_ver: str, bump_type: str) -> str:
    """Calculate the next semver version string based on bump type."""
    major, minor, patch = parse_semver(current_ver)
    b_type = bump_type.lower().strip()

    if b_type == "major":
        return f"{major + 1}.0.0"
    elif b_type == "minor":
        return f"{major}.{minor + 1}.0"
    elif b_type == "patch":
        return f"{major}.{minor}.{patch + 1}"
    else:
        raise ValueError(f"Unknown bump type: '{bump_type}'. Expected 'major', 'minor', or 'patch'.")


def load_version_state() -> Dict[str, any]:
    """Load current version state from version.json with fallbacks."""
    if VERSION_FILE.exists():
        with open(VERSION_FILE, "r", encoding="utf-8") as f:
            return json.load(f)

    # Fallback to pubspec
    if PUBSPEC_FILE.exists():
        with open(PUBSPEC_FILE, "r", encoding="utf-8") as f:
            content = f.read()
            m = re.search(r"version:\s*([0-9\.]+)\+?(\d+)?", content)
            if m:
                ver = m.group(1)
                build = int(m.group(2)) if m.group(2) else 1
                return {"version": ver, "build_number": build}

    return {"version": "1.3.0", "build_number": 1}


def update_file(path: Path, new_content: str, dry_run: bool = False):
    """Write updated content to file if changed."""
    if dry_run:
        print(f"[DRY-RUN] Would update {path.name}")
        return
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)


def bump_version(
    bump_type: Optional[str] = "patch",
    explicit_version: Optional[str] = None,
    sync_only: bool = False,
    dry_run: bool = False,
    edition_name: Optional[str] = None,
) -> str:
    """Increment version and synchronize across all tracking files."""
    state = load_version_state()
    current_ver = state.get("version", "1.3.0")
    build_num = state.get("build_number", 1)

    if explicit_version:
        parse_semver(explicit_version) # Validate
        new_version = explicit_version.strip().lstrip("v")
        new_build = build_num + 1 if not sync_only else build_num
    elif sync_only:
        new_version = current_ver
        new_build = build_num
    else:
        new_version = calculate_next_version(current_ver, bump_type)
        new_build = build_num + 1

    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    edition = edition_name or state.get("edition", "HardCode Multi-Language Edition")

    print(f"[VERSION BUMP] {current_ver} -> {new_version} (build: {new_build})")

    # 1. Update version.json
    state["version"] = new_version
    state["build_number"] = new_build
    state["updated_at"] = now_iso
    state["edition"] = edition
    if not dry_run:
        with open(VERSION_FILE, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2, ensure_ascii=False)
            f.write("\n")
    print(f"  [OK] {VERSION_FILE.relative_to(ROOT_DIR)}")

    # 2. Update pubspec.yaml
    if PUBSPEC_FILE.exists():
        with open(PUBSPEC_FILE, "r", encoding="utf-8") as f:
            pub_content = f.read()
        new_pub = re.sub(
            r"version:\s*[^\n]+",
            f"version: {new_version}+{new_build}",
            pub_content,
        )
        update_file(PUBSPEC_FILE, new_pub, dry_run)
        print(f"  [OK] {PUBSPEC_FILE.relative_to(ROOT_DIR)}")

    # 3. Update README.md
    if README_FILE.exists():
        with open(README_FILE, "r", encoding="utf-8") as f:
            readme_content = f.read()

        # Update edition subtitle: > **...(vX.Y.Z)**
        new_readme = re.sub(
            r"(>\s*\*\*[^*]+\(v)[0-9\.]+(\)\*\*)",
            rf"\g<1>{new_version}\g<2>",
            readme_content,
        )
        # Update badge: Version-vX.Y.Z-blue
        new_readme = re.sub(
            r"(badge/Version-v)[0-9\.]+-(blue)",
            rf"\g<1>{new_version}-\g<2>",
            new_readme,
        )
        update_file(README_FILE, new_readme, dry_run)
        print(f"  [OK] {README_FILE.relative_to(ROOT_DIR)}")

    # 4. Update assets/knowledge_graph.json
    if KG_FILE.exists():
        try:
            with open(KG_FILE, "r", encoding="utf-8") as f:
                kg_data = json.load(f)
            kg_data["graph_version"] = f"{new_version}-graph"
            if "metadata" in kg_data:
                kg_data["metadata"]["graph_version"] = f"{new_version}-graph"
                kg_data["metadata"]["last_updated"] = now_iso
            if not dry_run:
                with open(KG_FILE, "w", encoding="utf-8") as f:
                    json.dump(kg_data, f, indent=2, ensure_ascii=False)
            print(f"  [OK] {KG_FILE.relative_to(ROOT_DIR)}")
        except Exception as e:
            print(f"  [WARN] Failed to update {KG_FILE.name}: {e}")

    # 5. Update assets/db.json
    if DB_FILE.exists():
        try:
            with open(DB_FILE, "r", encoding="utf-8") as f:
                db_data = json.load(f)
            major, minor, _ = parse_semver(new_version)
            db_data["version"] = max(db_data.get("version", 0), major * 10 + minor)
            db_data["last_updated"] = now_iso
            if not dry_run:
                with open(DB_FILE, "w", encoding="utf-8") as f:
                    json.dump(db_data, f, indent=2, ensure_ascii=False)
            print(f"  [OK] {DB_FILE.relative_to(ROOT_DIR)}")
        except Exception as e:
            print(f"  [WARN] Failed to update {DB_FILE.name}: {e}")

    print(f"[SUCCESS] Version updated to v{new_version}")
    return new_version


def main():
    parser = argparse.ArgumentParser(description="HardCode Version Management System")
    parser.add_argument(
        "--type",
        choices=["patch", "minor", "major"],
        default="patch",
        help="Semver increment level (default: patch)",
    )
    parser.add_argument("--set", dest="explicit_version", help="Explicitly set version (e.g. 1.3.0)")
    parser.add_argument("--sync-only", action="store_true", help="Sync all files to version.json without bumping")
    parser.add_argument("--dry-run", action="store_true", help="Preview version updates without writing")
    parser.add_argument("--edition", help="Optional edition label for version.json and README.md")

    args = parser.parse_args()

    bump_version(
        bump_type=args.type,
        explicit_version=args.explicit_version,
        sync_only=args.sync_only,
        dry_run=args.dry_run,
        edition_name=args.edition,
    )


if __name__ == "__main__":
    main()
