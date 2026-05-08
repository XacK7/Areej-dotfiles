#!/bin/bash
# control-panel launcher: starts the python server on a free loopback port,
# opens chromium in --app= mode, and tears the server down on exit.
#
# Falls back to xdg-open if chromium isn't on PATH.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"

PORT=$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(('127.0.0.1', 0))
print(s.getsockname()[1])
s.close()
PY
)

cleanup() {
    [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

python3 "$DIR/server.py" --host 127.0.0.1 --port "$PORT" &
SERVER_PID=$!

# Wait for the server to come up (max ~2 s).
for _ in $(seq 1 20); do
    if curl -s "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done

URL="http://127.0.0.1:$PORT/"
if command -v chromium >/dev/null 2>&1; then
    chromium --app="$URL"
elif command -v google-chrome >/dev/null 2>&1; then
    google-chrome --app="$URL"
else
    xdg-open "$URL"
    wait "$SERVER_PID"
fi
