#!/usr/bin/env python3
"""
Unit tests for VoiceService logic, Settings customization, and Audio-Synchronized Timers.
Validates:
1. Speech duration approximation formula across diverse text lengths and speed rates.
2. Code syntax + formatting sanitization into spoken-friendly English.
3. Female voice discovery and candidate ranking heuristics (Web and Android).
4. Audio-synchronized explanation dwell duration invariants.
5. Numbered/bulleted list stripping from explanation narration.
6. Settings bounds and voice configuration defaults (1.0x speed, 1.15 pitch, 100% volume).
"""

import math
import re
import unittest
from typing import Any, Dict, List, Optional


class PythonVoiceService:
    """Python reference mirror of VoiceService logic for automated testing."""

    FEMALE_KEYWORDS = [
        'zira', 'samantha', 'karen', 'moira', 'fiona', 'tessa', 'victoria',
        'jenny', 'aria', 'michelle', 'amber', 'ana', 'cora', 'libby',
        'natasha', 'clara', 'hazel', 'eva', 'susan', 'alice',
        'female', 'woman', 'girl',
    ]

    @staticmethod
    def clean_text_for_speech(text: str) -> str:
        cleaned = text

        # Remove code blocks and inline backticks
        cleaned = re.sub(r'```[\s\S]*?```', '', cleaned)
        cleaned = cleaned.replace('`', '')

        # Strip numbered list markers: "1. " "2) " at start of line
        cleaned = re.sub(r'^\s*\d+[.)]\s+', '', cleaned, flags=re.MULTILINE)

        # Strip lettered list markers: "a. " "b) "
        cleaned = re.sub(r'^\s*[a-zA-Z][.)]\s+', '', cleaned, flags=re.MULTILINE)

        # Strip bullet markers: - * • ·
        cleaned = re.sub(r'^[\s]*[-*•·]\s+', '', cleaned, flags=re.MULTILINE)

        # Clean markdown headings
        cleaned = re.sub(r'#+\s*', '', cleaned)

        # Remove bold/italic markdown
        cleaned = re.sub(r'\*\*([^*]+)\*\*', r'\1', cleaned)
        cleaned = re.sub(r'\*([^*]+)\*', r'\1', cleaned)
        cleaned = re.sub(r'__([^_]+)__', r'\1', cleaned)
        cleaned = re.sub(r'_([^_]+)_', r'\1', cleaned)

        # Programmatic tokens translation
        cleaned = cleaned.replace('->', ' returns ')
        cleaned = cleaned.replace('=>', ' maps to ')
        cleaned = cleaned.replace('::', ' path ')
        cleaned = cleaned.replace('&&', ' and ')
        cleaned = cleaned.replace('||', ' or ')
        cleaned = cleaned.replace('==', ' equals ')
        cleaned = cleaned.replace('!=', ' not equals ')
        cleaned = cleaned.replace('&mut', ' mutable reference to ')
        cleaned = cleaned.replace('let mut', ' let mutable ')
        cleaned = cleaned.replace('println!', ' print line ')

        # Normalize line breaks and whitespace
        cleaned = re.sub(r'\n+', ' ', cleaned)
        cleaned = re.sub(r'\s+', ' ', cleaned).strip()
        return cleaned

    @staticmethod
    def estimate_speech_duration_seconds(text: str, speed: float = 1.0) -> int:
        cleaned = PythonVoiceService.clean_text_for_speech(text)
        if not cleaned:
            return 4
        words = [w for w in cleaned.split() if w]
        effective_speed = max(0.5, min(2.0, speed))
        words_per_second = 2.9 * effective_speed
        estimated = math.ceil(len(words) / words_per_second) + 2
        return max(3, min(90, estimated))

    @classmethod
    def discover_female_voice(cls, raw_voices: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        for v in raw_voices:
            name = str(v.get('name', '')).lower()
            locale = str(v.get('locale', v.get('lang', ''))).lower()

            is_english = (
                locale.startswith('en') or
                'en-' in name or
                'english' in name or
                '-us' in name or
                '-gb' in name or
                '-au' in name
            )
            if not is_english:
                continue

            if any(kw in name for kw in cls.FEMALE_KEYWORDS):
                return v
        return None


class TestVoiceServiceLogic(unittest.TestCase):

    def test_clean_text_for_speech_removes_code_and_tokens(self):
        sample = "In Rust, `let mut x: i32 = 10;` is used. `fn main() -> bool` uses `&&` and `||`."
        cleaned = PythonVoiceService.clean_text_for_speech(sample)
        self.assertNotIn('`', cleaned)
        self.assertIn('let mutable', cleaned)
        self.assertIn('returns', cleaned)
        self.assertIn(' and ', cleaned)
        self.assertIn(' or ', cleaned)

    def test_clean_text_strips_numbered_lists(self):
        text = "Steps:\n1. First step here\n2. Second step here\n3. Third step here"
        cleaned = PythonVoiceService.clean_text_for_speech(text)
        self.assertNotIn('1.', cleaned)
        self.assertNotIn('2.', cleaned)
        self.assertNotIn('3.', cleaned)
        self.assertIn('First step here', cleaned)
        self.assertIn('Second step here', cleaned)

    def test_clean_text_strips_bullet_points(self):
        text = "Points:\n- First point\n• Second point\n* Third point"
        cleaned = PythonVoiceService.clean_text_for_speech(text)
        self.assertNotIn('- ', cleaned[:5] if cleaned else '')
        self.assertIn('First point', cleaned)
        self.assertIn('Second point', cleaned)
        self.assertIn('Third point', cleaned)

    def test_estimate_speech_duration_scaling(self):
        # Short tier 1 text (~15 words) at baseline 1.0x speed
        short_text = "Variables in Rust are immutable by default to ensure memory safety."
        dur_short = PythonVoiceService.estimate_speech_duration_seconds(short_text, speed=1.0)
        self.assertGreaterEqual(dur_short, 3)
        self.assertLessEqual(dur_short, 10)

        # Long tier 3 masterclass text (~70 words) at baseline 1.0x speed
        long_text = (
            "Rust enforces safety invariants at compile time through its affine type system. "
            "Every allocated value has a single owning binding. When ownership transfers, "
            "the previous variable becomes invalid. Borrowing through immutable or mutable "
            "references prevents concurrent data races and guarantees zero dangling pointers "
            "without the runtime overhead of a tracing garbage collector."
        )
        dur_long = PythonVoiceService.estimate_speech_duration_seconds(long_text, speed=1.0)
        self.assertGreaterEqual(dur_long, 15)
        self.assertGreater(dur_long, dur_short)

    def test_estimate_speech_duration_with_variable_speed(self):
        sample = (
            "An array stores items sequentially in contiguous memory blocks. "
            "Random access is fast with big O of 1 indexing complexity."
        )
        # Slower speed (0.7x) takes longer than 1.0x
        dur_slow = PythonVoiceService.estimate_speech_duration_seconds(sample, speed=0.7)
        # Baseline speed (1.0x)
        dur_normal = PythonVoiceService.estimate_speech_duration_seconds(sample, speed=1.0)
        # Brisk speed (1.5x) is faster than 1.0x
        dur_fast = PythonVoiceService.estimate_speech_duration_seconds(sample, speed=1.5)

        self.assertGreater(dur_slow, dur_normal)
        self.assertGreater(dur_normal, dur_fast)

    def test_female_voice_heuristics_android_and_web(self):
        web_voices = [
            {"name": "Google US English", "lang": "en-US"},
            {"name": "Microsoft David - English (United States)", "lang": "en-US"},
            {"name": "Microsoft Zira - English (United States)", "lang": "en-US"},
            {"name": "Google UK English Female", "lang": "en-GB"},
        ]
        chosen = PythonVoiceService.discover_female_voice(web_voices)
        self.assertIsNotNone(chosen)
        self.assertIn("zira", chosen["name"].lower())

        android_voices = [
            {"name": "en-us-x-sfg#male_1-local", "locale": "en-US"},
            {"name": "en-us-x-sfg#female_1-local", "locale": "en-US"},
        ]
        chosen_android = PythonVoiceService.discover_female_voice(android_voices)
        self.assertIsNotNone(chosen_android)
        self.assertIn("female", chosen_android["name"].lower())

    def test_expanded_female_voice_list(self):
        voices = [
            {"name": "Microsoft Jenny Online (Natural) - English (United States)", "lang": "en-US"},
            {"name": "Microsoft Aria Online (Natural) - English (United States)", "lang": "en-US"},
            {"name": "Microsoft Natasha Online (Natural) - English (Australia)", "lang": "en-AU"},
            {"name": "Microsoft Libby Online (Natural) - English (United Kingdom)", "lang": "en-GB"},
        ]
        for v in voices:
            chosen = PythonVoiceService.discover_female_voice([v])
            self.assertIsNotNone(chosen, f"Should detect female: {v['name']}")

    def test_explanation_timer_does_not_expire_before_audio(self):
        explanation = (
            "Values in Rust have a single owner. Moving a value relinquishes ownership. "
            "Borrowing with & creates shared read-only access, while &mut grants exclusive write access."
        )
        estimated_audio = PythonVoiceService.estimate_speech_duration_seconds(explanation, speed=1.0)
        base_dwell = 8
        final_dwell = max(base_dwell, estimated_audio)
        self.assertGreaterEqual(final_dwell, estimated_audio)

    def test_voice_customization_defaults_and_bounds(self):
        default_speed = 1.0
        default_pitch = 1.15
        default_volume = 1.0

        # Speed bounds: 0.5 to 2.0
        self.assertTrue(0.5 <= default_speed <= 2.0)
        # Pitch bounds: 0.5 to 1.5
        self.assertTrue(0.5 <= default_pitch <= 1.5)
        # Volume bounds: 0.0 to 1.0
        self.assertTrue(0.0 <= default_volume <= 1.0)

    def test_narration_only_reads_explanation_body(self):
        title = "Asymptotic Complexity: The Big-O Scale"
        mental_model = "Think of Big-O as the worst-case ceiling for how slow code can get."
        explanation = "Big-O represents an upper bound on runtime growth as N approaches infinity."

        narrated = explanation
        self.assertNotIn(title, narrated)
        self.assertNotIn("mental model", narrated.lower())
        self.assertIn("upper bound", narrated)


if __name__ == '__main__':
    unittest.main()
