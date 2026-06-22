#!/bin/zsh

# Keep the Mac model ready for the Smart Goals screen without delaying Xcode.
model="${LIPPI_OLLAMA_MODEL:-qwen3:4b}"
ollamaURL="${LIPPI_OLLAMA_URL:-http://127.0.0.1:11434}"
keepAlive="${LIPPI_OLLAMA_KEEP_ALIVE:-15m}"

if ! /usr/bin/curl --silent --show-error --connect-timeout 1 --max-time 3 "${ollamaURL}/api/tags" >/dev/null 2>&1; then
  echo "Lippi: local Ollama is unavailable; building continues normally."
  exit 0
fi

payload=$(printf '{"model":"%s","prompt":"{\\"warm\\":true}","stream":false,"think":false,"keep_alive":"%s","options":{"num_predict":6}}' "${model}" "${keepAlive}")

echo "Lippi: warming ${model} on this Mac."
if ! /usr/bin/curl --silent --show-error --max-time 45 \
  --request POST "${ollamaURL}/api/generate" \
  --header "Content-Type: application/json" \
  --data "${payload}" \
  >/dev/null 2>&1; then
  echo "Lippi: model warm-up did not finish; building continues normally."
fi
