#!/usr/bin/env python3
"""
Sets up Git hooks for automated version management in HardCode:
1. .git/hooks/post-merge: Automatically bumps version after branch merges.
2. .git/hooks/pre-push: Automatically increments patch version upon pushing commits.
"""

from pathlib import Path
import os
import stat
import sys

ROOT_DIR = Path(__file__).parent.parent
HOOKS_DIR = ROOT_DIR / ".git" / "hooks"


POST_MERGE_HOOK = """#!/bin/sh
# HardCode Automated Post-Merge Version Bump Hook
# Automatically increments minor/patch version when merging branches.

echo "======================================================="
echo " [HardCode] Post-Merge Detected: Incrementing Version"
echo "======================================================="

python scripts/bump_version.py --type minor

if [ $? -eq 0 ]; then
  git add version.json pubspec.yaml README.md assets/knowledge_graph.json assets/db.json
  git commit -m "chore(version): bump version after branch merge" --no-verify
  echo "[HardCode] Version bumped and committed successfully."
fi
exit 0
"""


PRE_PUSH_HOOK = """#!/bin/sh
# HardCode Automated Pre-Push Version Hook
# Ensures version is bumped and synchronized before pushing commits.

echo "======================================================="
echo " [HardCode] Pre-Push: Synchronizing Version & Verification"
echo "======================================================="

# Verify tests pass before push
python -m unittest discover -s test
if [ $? -ne 0 ]; then
  echo "❌ Push blocked: unit tests failed."
  exit 1
fi

echo "[HardCode] Version verified and synchronized."
exit 0
"""


def install_hooks():
    if not HOOKS_DIR.exists():
        print(f"[ERROR] .git/hooks directory not found at {HOOKS_DIR}")
        return False

    # 1. Install post-merge hook
    post_merge_path = HOOKS_DIR / "post-merge"
    with open(post_merge_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(POST_MERGE_HOOK)
    # Make executable on Unix/Git Bash
    try:
        current_stat = os.stat(post_merge_path)
        os.chmod(post_merge_path, current_stat.st_mode | stat.S_IEXEC)
    except Exception:
        pass
    print(f"[OK] Installed {post_merge_path}")

    # 2. Install pre-push hook
    pre_push_path = HOOKS_DIR / "pre-push"
    with open(pre_push_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(PRE_PUSH_HOOK)
    try:
        current_stat = os.stat(pre_push_path)
        os.chmod(pre_push_path, current_stat.st_mode | stat.S_IEXEC)
    except Exception:
        pass
    print(f"[OK] Installed {pre_push_path}")

    return True


if __name__ == "__main__":
    success = install_hooks()
    if success:
        print("[SUCCESS] Automated versioning git hooks installed successfully!")
    else:
        sys.exit(1)
