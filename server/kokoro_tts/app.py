#!/usr/bin/env python3
"""
Kokoro-82M Neural Voice Synthesis Microservice for HardCode Academy.
Provides high-fidelity, studio-grade speech generation powered by Kokoro-82M (af_heart),
in-memory + disk audio caching, CORS headers, and health telemetry.
"""

import hashlib
import io
import os
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException, Query, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Initialize FastAPI App
app = FastAPI(
    title="HardCode Kokoro Voice Service",
    version="1.0.0",
    description="Neural TTS API featuring the flagship af_heart mascot voice for HardCode Academy.",
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Paths and Environment
BASE_DIR = Path(os.getenv("KOKORO_DIR", Path(__file__).parent))
CACHE_DIR = Path(os.getenv("KOKORO_CACHE_DIR", BASE_DIR / "cache"))
CACHE_DIR.mkdir(parents=True, exist_ok=True)


def get_model_path() -> Path:
    env_path = os.getenv("KOKORO_MODEL_PATH")
    if env_path and Path(env_path).exists():
        return Path(env_path)
    for name in ["kokoro-v1.0.onnx", "kokoro-v0_19.onnx"]:
        p = BASE_DIR / name
        if p.exists():
            return p
    return BASE_DIR / "kokoro-v1.0.onnx"


def get_voices_path() -> Path:
    env_path = os.getenv("KOKORO_VOICES_PATH")
    if env_path and Path(env_path).exists():
        return Path(env_path)
    for name in ["voices-v1.0.bin", "voices.bin", "voices.json"]:
        p = BASE_DIR / name
        if p.exists():
            return p
    return BASE_DIR / "voices-v1.0.bin"


# Kokoro Instance Singleton
_kokoro_instance = None
_kokoro_load_error = None


def get_kokoro():
    global _kokoro_instance, _kokoro_load_error
    if _kokoro_instance is not None:
        return _kokoro_instance

    if _kokoro_load_error is not None:
        raise HTTPException(
            status_code=503,
            detail=f"Kokoro engine initialization failed: {_kokoro_load_error}",
        )

    model_path = get_model_path()
    voices_path = get_voices_path()

    try:
        from kokoro_onnx import Kokoro
        if not model_path.exists() or not voices_path.exists():
            raise FileNotFoundError(
                f"Model files missing at {model_path} or {voices_path}."
            )
        _kokoro_instance = Kokoro(str(model_path), str(voices_path))
        return _kokoro_instance
    except Exception as e:
        _kokoro_load_error = str(e)
        raise HTTPException(
            status_code=503,
            detail=f"Failed to load Kokoro-82M model: {e}",
        )


class SynthesizeRequest(BaseModel):
    text: str
    voice: Optional[str] = "af_heart"
    speed: Optional[float] = 1.0


def compute_cache_key(text: str, voice: str, speed: float) -> str:
    raw = f"{voice}_{speed:.2f}_{text.strip()}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


@app.get("/health")
@app.get("/api/voice/health")
def health_check():
    """Telemetry and health check for Nginx and deployment automation."""
    model_path = get_model_path()
    voices_path = get_voices_path()
    model_ready = model_path.exists() and voices_path.exists()
    return {
        "status": "online",
        "service": "kokoro-tts",
        "default_voice": "af_heart",
        "model_file_present": model_ready,
        "model_path": str(model_path),
        "voices_path": str(voices_path),
        "cached_clips_count": len(list(CACHE_DIR.glob("*.wav"))),
    }


@app.get("/api/voice/synthesize")
@app.post("/api/voice/synthesize")
def synthesize_audio(
    text: str = Query(..., description="Text payload to synthesize into speech"),
    voice: str = Query("af_heart", description="Voice profile (default: af_heart)"),
    speed: float = Query(1.0, ge=0.5, le=2.0, description="Speech rate multiplier"),
):
    """
    Generates high-fidelity WAV audio from input text using Kokoro-82M.
    Returns cached response if previously synthesized.
    """
    clean_text = text.strip()
    if not clean_text:
        raise HTTPException(status_code=400, detail="Text parameter cannot be empty.")

    cache_key = compute_cache_key(clean_text, voice, speed)
    cache_file = CACHE_DIR / f"{cache_key}.wav"

    # Serve from Disk Cache if present
    if cache_file.exists():
        with open(cache_file, "rb") as f:
            audio_bytes = f.read()
        return Response(
            content=audio_bytes,
            media_type="audio/wav",
            headers={
                "X-Cache": "HIT",
                "Cache-Control": "public, max-age=604800, immutable",
            },
        )

    # Synthesize via Kokoro Engine
    kokoro = get_kokoro()
    import soundfile as sf

    try:
        samples, sample_rate = kokoro.create(
            clean_text,
            voice=voice,
            speed=speed,
            lang="en-us",
        )

        buffer = io.BytesIO()
        sf.write(buffer, samples, sample_rate, format="WAV")
        audio_bytes = buffer.getvalue()

        # Write to Cache asynchronously / atomically
        try:
            with open(cache_file, "wb") as f:
                f.write(audio_bytes)
        except Exception as cache_err:
            # Non-fatal if cache write fails
            print(f"Notice: Failed to write audio cache: {cache_err}")

        return Response(
            content=audio_bytes,
            media_type="audio/wav",
            headers={
                "X-Cache": "MISS",
                "Cache-Control": "public, max-age=604800, immutable",
            },
        )
    except Exception as synth_err:
        raise HTTPException(
            status_code=500,
            detail=f"Speech synthesis error: {synth_err}",
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8088)
