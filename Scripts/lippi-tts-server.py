#!/usr/bin/env python3
"""Small local HTTP bridge for Lippi's Piper neural speech model."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import tempfile
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


HOME = Path(os.environ.get("LIPPI_TTS_HOME", Path.home() / ".lippi" / "tts"))
PIPER = Path(os.environ.get("LIPPI_TTS_PIPER", HOME / "venv" / "bin" / "piper"))
VOICE_NAME = os.environ.get("LIPPI_TTS_VOICE", "ru_RU-irina-medium")
MODEL = Path(os.environ.get("LIPPI_TTS_MODEL", HOME / "voices" / f"{VOICE_NAME}.onnx"))
MAX_TEXT_LENGTH = 2_400


def model_ready() -> bool:
    return PIPER.is_file() and os.access(PIPER, os.X_OK) and MODEL.is_file()


class LippiTTSHandler(BaseHTTPRequestHandler):
    server_version = "LippiTTS/1.0"

    def do_GET(self) -> None:
        if self.path.rstrip("/") != "/health":
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        self._send_json(
            HTTPStatus.OK,
            {"ready": model_ready(), "voice": VOICE_NAME},
        )

    def do_POST(self) -> None:
        if self.path.rstrip("/") != "/v1/audio/speech":
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        if not model_ready():
            self._send_json(HTTPStatus.SERVICE_UNAVAILABLE, {"error": "model_unavailable"})
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            if content_length <= 0 or content_length > 16_384:
                raise ValueError("invalid_content_length")
            payload = json.loads(self.rfile.read(content_length).decode("utf-8"))
            text = str(payload.get("text", "")).strip()
            length_scale = float(payload.get("length_scale", 1.0))
            if not text or len(text) > MAX_TEXT_LENGTH:
                raise ValueError("invalid_text")
            length_scale = min(1.30, max(0.80, length_scale))
        except (UnicodeDecodeError, ValueError, json.JSONDecodeError):
            self._send_json(HTTPStatus.BAD_REQUEST, {"error": "invalid_request"})
            return

        output_path = None
        try:
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as output_file:
                output_path = Path(output_file.name)

            subprocess.run(
                [
                    str(PIPER),
                    "--model",
                    str(MODEL),
                    "--output_file",
                    str(output_path),
                    "--length-scale",
                    f"{length_scale:.2f}",
                    "--sentence-silence",
                    "0.10",
                ],
                input=text.encode("utf-8"),
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=45,
            )
            audio = output_path.read_bytes()
            if len(audio) <= 44:
                raise RuntimeError("empty_audio")
        except (OSError, subprocess.SubprocessError, RuntimeError):
            self._send_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": "synthesis_failed"})
            return
        finally:
            if output_path is not None:
                output_path.unlink(missing_ok=True)

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Content-Length", str(len(audio)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(audio)

    def log_message(self, _format: str, *_args: object) -> None:
        return

    def _send_json(self, status: HTTPStatus, payload: dict[str, object]) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", default=8158, type=int)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), LippiTTSHandler)
    server.daemon_threads = True
    server.serve_forever()


if __name__ == "__main__":
    main()
