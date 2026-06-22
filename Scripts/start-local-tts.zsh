#!/bin/zsh
set -u

root="${SRCROOT:-${0:A:h:h}}"
ttsHome="${LIPPI_TTS_HOME:-$HOME/.lippi/tts}"
pythonBin="$ttsHome/venv/bin/python"
server="$root/scripts/lippi-tts-server.py"
port="${LIPPI_TTS_PORT:-8158}"
healthURL="http://127.0.0.1:${port}/health"
logFile="$ttsHome/lippi-tts.log"
launchctlBin="/bin/launchctl"
label="com.illumionix.lippi.tts"
domain="gui/$(/usr/bin/id -u)"
job="${domain}/${label}"

if /usr/bin/curl --silent --fail --connect-timeout 1 --max-time 2 "$healthURL" >/dev/null 2>&1; then
  exit 0
fi

if [[ ! -x "$pythonBin" || ! -f "$server" ]]; then
  echo "Lippi: neural voice is not installed; using the iPhone fallback voice."
  exit 0
fi

mkdir -p "$ttsHome"
if "$launchctlBin" print "$job" >/dev/null 2>&1; then
  "$launchctlBin" kickstart -k "$job" >/dev/null 2>&1 || true
else
  "$launchctlBin" submit \
    -l "$label" \
    -o "$logFile" \
    -e "$logFile" \
    -- "$pythonBin" "$server" --host 0.0.0.0 --port "$port" >/dev/null 2>&1 || \
    nohup "$pythonBin" "$server" --host 0.0.0.0 --port "$port" >"$logFile" 2>&1 &
fi

for _ in {1..8}; do
  if /usr/bin/curl --silent --fail --connect-timeout 1 --max-time 1 "$healthURL" >/dev/null 2>&1; then
    echo "Lippi: local neural voice is ready on port ${port}."
    exit 0
  fi
  sleep 0.25
done

echo "Lippi: neural voice did not start; using the iPhone fallback voice."
exit 0
