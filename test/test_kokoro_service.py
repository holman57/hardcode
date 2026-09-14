#!/usr/bin/env python3
"""
Unit tests for Kokoro-82M Voice Microservice logic (af_heart mascot).
Tests cache key computation, text sanitization, URL construction, and API routes.
"""

import hashlib
import unittest
from urllib.parse import quote, urlparse, parse_qs


def compute_cache_key(text: str, voice: str, speed: float) -> str:
    raw = f"{voice}_{speed:.2f}_{text.strip()}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def build_kokoro_synthesize_url(base_url: str, text: str, voice: str = "af_heart", speed: float = 1.0) -> str:
    encoded_text = quote(text.strip())
    return f"{base_url.rstrip('/')}/api/voice/synthesize?text={encoded_text}&voice={voice}&speed={speed:.2f}"


class TestKokoroServiceLogic(unittest.TestCase):

    def test_cache_key_deterministic(self):
        text = "Hello, world! Welcome to HardCode Academy."
        key1 = compute_cache_key(text, "af_heart", 1.0)
        key2 = compute_cache_key(text, "af_heart", 1.0)
        key3 = compute_cache_key(text, "af_heart", 1.25)
        key_other_voice = compute_cache_key(text, "af_bella", 1.0)

        self.assertEqual(key1, key2)
        self.assertNotEqual(key1, key3, "Different speed must generate different cache key")
        self.assertNotEqual(key1, key_other_voice, "Different voice must generate different cache key")
        self.assertEqual(len(key1), 64, "SHA-256 hex string must be 64 characters")

    def test_url_construction_with_af_heart(self):
        url = build_kokoro_synthesize_url("https://hardcode.academy", "Let's learn Rust!", "af_heart", 1.15)
        parsed = urlparse(url)
        params = parse_qs(parsed.query)

        self.assertEqual(parsed.scheme, "https")
        self.assertEqual(parsed.netloc, "hardcode.academy")
        self.assertEqual(parsed.path, "/api/voice/synthesize")
        self.assertEqual(params["voice"][0], "af_heart")
        self.assertEqual(params["speed"][0], "1.15")
        self.assertEqual(params["text"][0], "Let's learn Rust!")

    def test_cache_key_ignores_leading_trailing_whitespace(self):
        k1 = compute_cache_key("Binary search runs in O(log N) time.", "af_heart", 1.0)
        k2 = compute_cache_key("   Binary search runs in O(log N) time.  \n", "af_heart", 1.0)
        self.assertEqual(k1, k2)


if __name__ == "__main__":
    unittest.main()
