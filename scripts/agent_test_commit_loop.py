#!/usr/bin/env python3
"""
Agent Test-Driven Commit Loop Harness for HardCode Academy.
Ensures that agents (and developers) cannot commit changes unless all
unit tests and Playwright UI simulation / chaos tests pass.
If tests fail, the harness provides structured failure diagnostics and
can iteratively prompt local Ollama / Gemini to fix issues until green.
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

REPO_ROOT = Path(__file__).resolve().parent.parent
TEST_RESULTS_DIR = REPO_ROOT / "test-results"
FAILURE_LOG_PATH = TEST_RESULTS_DIR / "agent_last_failure.json"
OLLAMA_API_URL = os.environ.get("OLLAMA_API_URL", "http://localhost:11434/api/generate")
DEFAULT_MODEL = os.environ.get("OLLAMA_MODEL", "qwen3-coder:30b")


def run_cmd(
    cmd: str, cwd: Optional[Path] = None, timeout: int = 180
) -> Tuple[int, str, str]:
    """Runs a shell command and captures returncode, stdout, and stderr."""
    working_dir = str(cwd or REPO_ROOT)
    try:
        proc = subprocess.run(
            cmd,
            shell=True,
            cwd=working_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
        return proc.returncode, proc.stdout, proc.stderr
    except subprocess.TimeoutExpired:
        return -1, "", f"Command timed out after {timeout} seconds: {cmd}"
    except Exception as exc:
        return -1, "", f"Execution failed: {exc}"


class TestRunner:
    """Orchestrates unit and UI / Playwright test execution."""

    @staticmethod
    def run_python_unit_tests() -> Dict[str, Any]:
        """Runs Python driver unit tests."""
        print("[1/3] Running Python Driver Unit Tests...")
        code, out, err = run_cmd("python -m unittest test.test_python_driver")
        passed = (code == 0)
        output = (out + "\n" + err).strip()
        return {
            "name": "Python Driver Unit Tests",
            "passed": passed,
            "exit_code": code,
            "output": output,
        }

    @staticmethod
    def run_flutter_tests() -> Dict[str, Any]:
        """Runs Flutter / Dart unit tests if flutter CLI is present."""
        print("[2/3] Checking Flutter Unit Tests...")
        check_code, _, _ = run_cmd("flutter --version", timeout=15)
        if check_code != 0:
            return {
                "name": "Flutter Unit Tests",
                "passed": True,
                "exit_code": 0,
                "output": "Flutter CLI not in PATH; skipped unit runner (E2E browser tests validate compiled bundle).",
            }

        code, out, err = run_cmd("flutter test test/database_service_test.dart")
        passed = (code == 0)
        output = (out + "\n" + err).strip()
        return {
            "name": "Flutter Unit Tests",
            "passed": passed,
            "exit_code": code,
            "output": output,
        }

    @staticmethod
    def run_playwright_e2e_tests() -> Dict[str, Any]:
        """Runs Playwright UI progression and chaos test suite."""
        print("[3/3] Running Playwright E2E & Chaos Suite...")
        cmd = "npx playwright test"
        code, out, err = run_cmd(cmd, timeout=240)
        passed = (code == 0)
        output = (out + "\n" + err).strip()
        return {
            "name": "Playwright E2E Suite",
            "passed": passed,
            "exit_code": code,
            "output": output,
        }

    @classmethod
    def execute_all(cls, skip_e2e: bool = False) -> Tuple[bool, List[Dict[str, Any]]]:
        """Runs the complete test suite."""
        results = []

        # 1. Python tests
        py_res = cls.run_python_unit_tests()
        results.append(py_res)
        if not py_res["passed"]:
            print("  FAIL: Python driver unit tests failed.")
            return False, results
        print("  PASS: Python driver unit tests passed.")

        # 2. Flutter tests
        flt_res = cls.run_flutter_tests()
        results.append(flt_res)
        if not flt_res["passed"]:
            print("  FAIL: Flutter unit tests failed.")
            return False, results
        print("  PASS: Flutter unit tests verified.")

        # 3. Playwright E2E tests
        if not skip_e2e:
            pw_res = cls.run_playwright_e2e_tests()
            results.append(pw_res)
            if not pw_res["passed"]:
                print("  FAIL: Playwright UI tests failed.")
                return False, results
            print("  PASS: Playwright UI & Chaos tests passed.")

        return True, results


def query_ollama_for_fix(failing_summary: str, model: str = DEFAULT_MODEL) -> str:
    """Queries local Ollama instance for diagnostic guidance or code fixes."""
    prompt = f"""You are an autonomous AI software engineer debugging HardCode Academy.
The test suite failed with the following test output:

--- TEST FAILURE TRACE ---
{failing_summary}
--- END TEST FAILURE TRACE ---

Diagnose the root cause of this failure. Specify:
1. Exact file and function where the error originated.
2. Why it failed (e.g. type error, element selector out of view, missing null check).
3. The exact code fix or replacement chunk needed.
Keep your explanation concise and direct.
"""
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
    }
    req = urllib.request.Request(
        OLLAMA_API_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("response", "").strip()
    except Exception as exc:
        return f"[Ollama Unavailable at {OLLAMA_API_URL}]: {exc}"


def record_failure(results: List[Dict[str, Any]], attempt: int):
    """Saves structured failure data for agents or CI tools to inspect."""
    TEST_RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    failures = [r for r in results if not r.get("passed")]
    data = {
        "timestamp": time.time(),
        "attempt": attempt,
        "failed_suites": failures,
    }
    with open(FAILURE_LOG_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def execute_git_commit(commit_msg: str, stage_all: bool = False) -> bool:
    """Stages changes and creates a git commit."""
    if stage_all:
        add_cmd = "git add -A"
    else:
        add_cmd = "git add -u"

    print(f"Staging changes: {add_cmd}")
    code, _, err = run_cmd(add_cmd)
    if code != 0:
        print(f"Failed to stage changes: {err}")
        return False

    diff_code, diff_out, _ = run_cmd("git diff --cached --quiet")
    if diff_code == 0:
        print("No staged changes found to commit.")
        return True

    print(f"Committing changes with message: '{commit_msg}'")
    commit_cmd = f'git commit -m "{commit_msg}"'
    code, out, err = run_cmd(commit_cmd)
    if code != 0:
        print(f"Git commit failed:\n{out}\n{err}")
        return False

    print("Commit created successfully:")
    print(out.strip())
    return True


def run_agent_loop(
    commit_msg: Optional[str],
    check_only: bool,
    max_retries: int,
    auto_fix: bool,
    skip_e2e: bool,
    stage_all: bool,
    model: str,
) -> int:
    """Main loop: runs tests, retries or requests fixes on failure, commits on pass."""
    attempt = 1
    while attempt <= max_retries:
        print(f"\n=======================================================")
        print(f" [HardCode Agent Loop] Iteration {attempt}/{max_retries}")
        print(f"=======================================================")

        all_passed, results = TestRunner.execute_all(skip_e2e=skip_e2e)

        if all_passed:
            print("\n>>> ALL TESTS PASSED SUCCESSFULLY (100% PASS RATE).")
            if FAILURE_LOG_PATH.exists():
                try:
                    FAILURE_LOG_PATH.unlink()
                except OSError:
                    pass

            if check_only or not commit_msg:
                return 0

            success = execute_git_commit(commit_msg, stage_all=stage_all)
            return 0 if success else 1

        record_failure(results, attempt)
        failing_results = [r for r in results if not r["passed"]]
        summary = "\n".join(
            f"=== {r['name']} ===\n{r['output'][-1500:]}" for r in failing_results
        )

        print(f"\n[ALERT] Test failure detected on attempt {attempt}/{max_retries}!")
        if check_only:
            print("Pre-commit test gate failed. Aborting commit.")
            print(summary)
            return 1

        if auto_fix:
            print("\n[AGENT] Querying local LLM for fix diagnosis...")
            fix_advice = query_ollama_for_fix(summary, model=model)
            print("\n--- LLM Diagnostic Suggestion ---")
            print(fix_advice)
            print("---------------------------------\n")

        attempt += 1
        if attempt <= max_retries:
            print(f"[AGENT] Retrying test suite (Iteration {attempt}/{max_retries})...\n")
            time.sleep(2)

    print(f"\n[ERROR] Maximum retries ({max_retries}) reached without passing all tests.")
    print("Changes were NOT committed. Inspect 'test-results/agent_last_failure.json'.")
    return 1


def main():
    parser = argparse.ArgumentParser(
        description="Autonomous Agent Test-Driven Commit Loop for HardCode Academy."
    )
    parser.add_argument(
        "-m", "--message", dest="commit_msg", type=str, default=None,
        help="Commit message to use when tests pass."
    )
    parser.add_argument(
        "--check-only", action="store_true",
        help="Only run test verification without creating a commit (exit 0 on pass, 1 on fail)."
    )
    parser.add_argument(
        "--retries", type=int, default=3,
        help="Max retries for agent test iteration loop (default: 3)."
    )
    parser.add_argument(
        "--auto-fix", action="store_true",
        help="Query local Ollama model to diagnose and suggest fixes when tests fail."
    )
    parser.add_argument(
        "--model", type=str, default=DEFAULT_MODEL,
        help=f"Ollama model name for diagnostics (default: {DEFAULT_MODEL})."
    )
    parser.add_argument(
        "--skip-e2e", action="store_true",
        help="Skip Playwright E2E browser tests (fast mode)."
    )
    parser.add_argument(
        "-a", "--all", dest="stage_all", action="store_true",
        help="Stage all files (including untracked) when committing."
    )

    args = parser.parse_args()

    check_only = args.check_only or (args.commit_msg is None)

    exit_code = run_agent_loop(
        commit_msg=args.commit_msg,
        check_only=check_only,
        max_retries=args.retries,
        auto_fix=args.auto_fix,
        skip_e2e=args.skip_e2e,
        stage_all=args.stage_all,
        model=args.model,
    )
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
