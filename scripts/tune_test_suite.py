#!/usr/bin/env python3
"""
Autonomous Test Suite Tuning Harness for Hardcode Academy.
Measures Playwright test results, chaos coverage, and state invariants.
Iterates with local Ollama or Gemini to optimize test depth and resilience.
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any, Dict, List

# Ensure safe UTF-8 output on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HARDCODE_ROOT = Path(__file__).resolve().parent.parent
SPEC_PATH = HARDCODE_ROOT / "test" / "e2e" / "chaos_game_breaker.spec.ts"
RESULTS_PATH = HARDCODE_ROOT / "test-results" / "results.json"
HISTORY_PATH = HARDCODE_ROOT / "test-results" / "tuning_history.json"

QUESTION_TYPES = [
    "multiChoiceSyntax",
    "conceptualMultiChoice",
    "trueFalse",
    "matching",
    "sequencing",
    "sortingClassification",
]

CHAOS_VECTORS = [
    "rapid-fire button mashing",
    "boundary handling",
    "monkey click thrashing",
    "telemetry hook",
    "invariants",
]

TARGET_FITNESS = 0.85


def run_playwright_suite() -> Dict[str, Any]:
    """Runs the Playwright chaos test suite and captures output."""
    RESULTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    cmd = "npx playwright test test/e2e/chaos_game_breaker.spec.ts --reporter=json"
    
    start_time = time.time()
    res = subprocess.run(
        cmd,
        cwd=str(HARDCODE_ROOT),
        shell=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=180,
    )
    duration = time.time() - start_time

    pass_rate = 0.0
    passed_count = 0
    total_count = 0
    error_messages: List[str] = []

    if RESULTS_PATH.is_file():
        try:
            with open(RESULTS_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                stats = data.get("stats", {})
                passed_count = stats.get("expected", 0)
                failed_count = stats.get("unexpected", 0)
                total_count = passed_count + failed_count
                pass_rate = (passed_count / total_count) if total_count > 0 else 0.0

                for suite in data.get("suites", []):
                    for spec in suite.get("specs", []):
                        if not spec.get("ok", True):
                            for test_entry in spec.get("tests", []):
                                for r in test_entry.get("results", []):
                                    for err in r.get("errors", []):
                                        error_messages.append(err.get("message", "Unknown test error"))
        except Exception as e:
            error_messages.append(f"Failed parsing results.json: {e}")
    else:
        # Heuristic fallback if results.json was not generated
        if res.returncode == 0:
            pass_rate = 1.0
            passed_count, total_count = 1, 1
        else:
            error_messages.append(res.stderr[-500:] if res.stderr else "Non-zero exit without results.json")

    return {
        "success": (res.returncode == 0 and pass_rate >= TARGET_FITNESS),
        "exit_code": res.returncode,
        "pass_rate": pass_rate,
        "passed_count": passed_count,
        "total_count": total_count,
        "duration": duration,
        "errors": error_messages,
        "raw_stdout": res.stdout[-1500:],
        "raw_stderr": res.stderr[-1500:],
    }


def evaluate_spec_coverage() -> Dict[str, Any]:
    """Calculates coverage of question types and chaos vectors within the spec."""
    if not SPEC_PATH.is_file():
        return {"type_coverage": 0.0, "vector_coverage": 0.0, "coverage_score": 0.0}

    spec_code = SPEC_PATH.read_text(encoding="utf-8", errors="replace").lower()

    found_types = [qt for qt in QUESTION_TYPES if qt.lower() in spec_code]
    found_vectors = [cv for cv in CHAOS_VECTORS if cv.lower() in spec_code]

    type_cov = len(found_types) / len(QUESTION_TYPES)
    vector_cov = len(found_vectors) / len(CHAOS_VECTORS)
    coverage_score = (0.6 * type_cov) + (0.4 * vector_cov)

    return {
        "found_types": found_types,
        "missing_types": [qt for qt in QUESTION_TYPES if qt.lower() not in spec_code],
        "type_coverage": type_cov,
        "found_vectors": found_vectors,
        "missing_vectors": [cv for cv in CHAOS_VECTORS if cv.lower() not in spec_code],
        "vector_coverage": vector_cov,
        "coverage_score": coverage_score,
    }


def compute_fitness(run_metrics: Dict[str, Any], cov_metrics: Dict[str, Any]) -> float:
    """
    Fitness formula:
    Fitness = 0.40 * PassRate + 0.40 * CoverageScore + 0.20 * SpeedScore
    """
    pass_rate = run_metrics.get("pass_rate", 0.0)
    cov_score = cov_metrics.get("coverage_score", 0.0)
    duration = run_metrics.get("duration", 60.0)

    # Speed score: 1.0 if under 30s, down to 0.0 if above 120s
    speed_score = max(0.0, min(1.0, 1.0 - ((duration - 30.0) / 90.0)))

    fitness = (0.40 * pass_rate) + (0.40 * cov_score) + (0.20 * speed_score)
    return round(fitness, 3)


def consult_local_ollama(prompt: str, model: str = "qwen3-coder:30b") -> str:
    """Calls local Ollama endpoint if active."""
    url = "http://127.0.0.1:11434/api/generate"
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.2}
    }
    try:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=45) as resp:
            res_data = json.loads(resp.read().decode("utf-8"))
            return res_data.get("response", "").strip()
    except Exception as e:
        return f"[Ollama consultation skipped: {e}]"


def main():
    parser = argparse.ArgumentParser(description="Hardcode Test Suite Tuning Harness")
    parser.add_argument("--dry-run", action="store_true", help="Evaluate current suite fitness without LLM mutation")
    parser.add_argument("--threshold", type=float, default=TARGET_FITNESS, help="Target fitness threshold (0.0 - 1.0)")
    parser.add_argument("--max-iterations", type=int, default=5, help="Maximum tuning cycles")
    args = parser.parse_args()

    print("=" * 65)
    print("[*] HardCode Academy - Autonomous Test Suite Tuning Harness")
    print("=" * 65)

    cov = evaluate_spec_coverage()
    print(f"[i] Spec Coverage Analysis:")
    print(f"   - Question Types: {len(cov['found_types'])}/{len(QUESTION_TYPES)} ({cov['type_coverage']*100:.1f}%)")
    print(f"   - Chaos Vectors:  {len(cov['found_vectors'])}/{len(CHAOS_VECTORS)} ({cov['vector_coverage']*100:.1f}%)")

    print("\n[>] Running Playwright UI Chaos Test Suite...")
    run_result = run_playwright_suite()

    fitness = compute_fitness(run_result, cov)

    print("\n" + "-" * 65)
    print(f"[#] TUNING EVALUATION REPORT:")
    print(f"   - Total Tests:     {run_result['total_count']}")
    print(f"   - Tests Passed:    {run_result['passed_count']}")
    print(f"   - Pass Rate:       {run_result['pass_rate']*100:.1f}%")
    print(f"   - Duration:        {run_result['duration']:.2f}s")
    print(f"   - Coverage Score:  {cov['coverage_score']*100:.1f}%")
    print(f"   - FITNESS SCORE:   {fitness:.3f} (Target: {args.threshold})")
    print("-" * 65)

    is_optimal = fitness >= args.threshold
    status = "OPTIMALLY TUNED [SUCCESS]" if is_optimal else "NEEDS TUNING [INCOMPLETE]"
    print(f"Status: {status}\n")

    history_record = {
        "timestamp": time.time(),
        "fitness": fitness,
        "threshold": args.threshold,
        "is_optimal": is_optimal,
        "pass_rate": run_result["pass_rate"],
        "coverage_score": cov["coverage_score"],
        "duration": run_result["duration"],
        "errors": run_result["errors"],
    }

    # Record history
    history = []
    if HISTORY_PATH.is_file():
        try:
            with open(HISTORY_PATH, "r", encoding="utf-8") as f:
                history = json.load(f)
        except Exception:
            history = []
    history.append(history_record)
    with open(HISTORY_PATH, "w", encoding="utf-8") as f:
        json.dump(history, f, indent=2)

    if not is_optimal and not args.dry_run:
        print("[AI] Invoking Local Ollama (qwen3-coder:30b) for Test Suite Optimization recommendations...")
        prompt = (
            f"You are a QA Optimization Agent for Hardcode Academy (Flutter/Dart learning app).\n"
            f"Test Suite Fitness: {fitness:.3f} (Target: {args.threshold}).\n"
            f"Missing Question Types: {cov['missing_types']}\n"
            f"Missing Chaos Vectors: {cov['missing_vectors']}\n"
            f"Errors: {run_result['errors']}\n"
            f"Suggest 2 precise Playwright test cases to close coverage gaps and harden game resilience."
        )
        recommendations = consult_local_ollama(prompt)
        print("\n--- AI TUNING RECOMMENDATIONS ---")
        print(recommendations)
        print("---------------------------------")

    sys.exit(0 if is_optimal else 1)


if __name__ == "__main__":
    main()
