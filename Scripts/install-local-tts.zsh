#!/bin/zsh
set -euo pipefail

ttsHome="${LIPPI_TTS_HOME:-$HOME/.lippi/tts}"
voice="${LIPPI_TTS_VOICE:-ru_RU-irina-medium}"
pythonBin="${PYTHON_BIN:-python3}"

mkdir -p "$ttsHome/voices"
"$pythonBin" -m venv "$ttsHome/venv"
"$ttsHome/venv/bin/python" -m pip install --upgrade pip certifi 'piper-tts==1.4.2'

certFile=$("$ttsHome/venv/bin/python" -c 'import certifi; print(certifi.where())')
SSL_CERT_FILE="$certFile" "$ttsHome/venv/bin/python" -m piper.download_voices \
  --download-dir "$ttsHome/voices" \
  "$voice"

echo "Lippi neural voice is ready: $voice"
