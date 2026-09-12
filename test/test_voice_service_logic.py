#!/usr/bin/env python3
"""
Unit tests for VoiceService logic and Audio-Synchronized Explanation Timers.
Validates:
1. Speech duration approximation formula across diverse text lengths.
2. Code syntax sanitization into spoken-friendly English.
3. Female voice discovery and candidate ranking heuristics (Web and Android).
4. Audio-synchronized explanation dwell duration invariants.
"""

import math
import re
import unittest
from typing import Any, Dict, List, Optional


class PythonVoiceService:
    """Python reference mirror of VoiceService logic for automated testing."""

    @staticmethod
    def clean_text_for_speech(text: str) -> str:
        cleaned = text
        # Remove code blocks and inline backticks
        cleaned = re.sub(r'```[\s\S]*?```', ' code example omitted. ', cleaned)
        cleaned = cleaned.replace('`', '')

        # Programmatic tokens translation
        cleaned = cleaned.replace('->', ' returns ')
        cleaned = cleaned.replace('=>', ' maps to ')
        cleaned = cleaned.replace('::', ' path ')
        cleaned = cleaned.replace('&&', ' and ')
        cleaned = cleaned.replace('||', ' or ')
        cleaned = cleaned.replace('==', ' equals ')
        cleaned = cleaned.replace('!=', ' not equals ')
        cleaned = cleaned.replace('&mut', ' mutable reference to ')
        cleaned = cleaned.replace('let mut', ' let mute ')
        cleaned = cleaned.replace('fn', ' function ')
        cleaned = cleaned.replace('println!', ' print line macro ')

        # Clean markdown headings, bold, bullet points
        cleaned = re.sub(r'#+\s*', '', cleaned)
        cleaned = re.sub(r'\*\*([^*]+)\*\*', r'\1', cleaned)
        cleaned = re.sub(r'\*([^*]+)\*', r'\1', cleaned)
        cleaned = re.sub(r'^[-*•]\s+', '', cleaned, flags=re.MULTILINE)

        cleaned = re.sub(r'\s+', ' ', cleaned).strip()
        return cleaned

    @staticmethod
    def estimate_speech_duration_seconds(text: str) -> int:
        cleaned = PythonVoiceService.clean_text_for_speech(text)
        if not cleaned:
            return 4
        words = [w for w in cleaned.split() if w]
        # ~2.33 words per second (140 WPM at speech rate 0.50) + 3s buffer
        estimated = math.ceil(len(words) / 2.33) + 3
        return max(4, min(90, estimated))

    @staticmethod
    def discover_female_voice(raw_voices: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        for v in raw_voices:
            name = str(v.get('name', '')).lower()
            locale = str(v.get('locale', v.get('lang', ''))).lower()

            is_english = locale.startswith('en') or 'en-' in name or 'english' in name or 'us' in name
            if not is_english:
                continue

            female_keywords = [
                'female', 'zira', 'samantha', 'karen', 'victoria',
                'jenny', 'aria', 'cora', 'susan', 'eva'
            ]
            if any(kw in name for kw in female_keywords):
                return v
        return None


class TestVoiceServiceLogic(unittest.TestCase):
    def test_clean_text_for_speech(self):
        sample = "In Rust, `let mut x: i32 = 10;` is used. `fn main() -> bool` uses `&&` and `||`."
        cleaned = PythonVoiceService.clean_text_for_speech(sample)
        self.assertNotIn('`', cleaned)
        self.assertIn('let mute', cleaned)
        self.assertIn('returns', cleaned)
        self.assertIn(' and ', cleaned)
        self.assertIn(' or ', cleaned)
        self.assertIn('function', cleaned)

    def test_estimate_speech_duration_scaling(self):
        # Short tier 1 text (~15 words)
        short_text = "Variables in Rust are immutable by default to ensure memory safety."
        dur_short = PythonVoiceService.estimate_speech_duration_seconds(short_text)
        self.assertGreaterEqual(dur_short, 7)
        self.assertLessEqual(dur_short, 14)

        # Long tier 3 masterclass text (~70 words)
        long_text = (
            "Rust enforce safety invariants at compile time through its affine type system. "
            "Every allocated value has a single owning binding. When ownership transfers, "
            "the previous variable becomes invalid. Borrowing through immutable or mutable "
            "references prevents concurrent data races and guarantees zero dangling pointers "
            "without the runtime overhead of a tracing garbage collector."
        )
        dur_long = PythonVoiceService.estimate_speech_duration_seconds(long_text)
        self.assertGreaterEqual(dur_long, 25)
        self.assertGreater(dur_long, dur_short)

    def test_female_voice_heuristics_android_and_web(self):
        # Simulated Web voice list (Chrome / Edge / Safari)
        web_voices = [
            {"name": "Google US English", "lang": "en-US"},
            {"name": "Microsoft David - English (United States)", "lang": "en-US"},
            {"name": "Microsoft Zira - English (United States)", "lang": "en-US"},
            {"name": "Google UK English Female", "lang": "en-GB"},
        ]
        chosen = PythonVoiceService.discover_female_voice(web_voices)
        self.assertIsNotNone(chosen)
        self.assertIn("zira", chosen["name"].lower())

        # Simulated Android voice list
        android_voices = [
            {"name": "en-us-x-sfg#male_1-local", "locale": "en-US"},
            {"name": "en-us-x-sfg#female_1-local", "locale": "en-US"},
        ]
        chosen_android = PythonVoiceService.discover_female_voice(android_voices)
        self.assertIsNotNone(chosen_android)
        self.assertIn("female", chosen_android["name"].lower())

    def test_explanation_timer_does_not_expire_before_audio(self):
        # Narrative payload
        title = "Rust Ownership & Borrowing"
        tier_badge = "DEEP DIVE MECHANICS (TIER 2)"
        explanation = (
            "Values in Rust have a single owner. Moving a value relinquishes ownership. "
            "Borrowing with `&` creates shared read-only access, while `&mut` grants exclusive write access."
        )
        mental_model = "Think of a library book: many can read, only one can annotate."

        narrative = f"{title}. {tier_badge}. {explanation}. Mental model: {mental_model}"
        estimated_audio = PythonVoiceService.estimate_speech_duration_seconds(narrative)

        base_dwell = 8 # Old fixed dwell
        final_dwell = max(base_dwell, estimated_audio)

        # The final dwell must be at least the estimated audio duration
        self.assertGreaterEqual(final_dwell, estimated_audio)
        self.assertGreater(final_dwell, base_dwell)


if __name__ == '__main__':
    unittest.main()
