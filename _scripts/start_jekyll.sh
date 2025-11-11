#!/usr/bin/env bash
set -euo pipefail

# Arbeitsverzeichnis: Repo-Root
cd "$(dirname "$0")/.."

# Portbereiche (anpassbar)
SITE_PORT_START=4000
SITE_PORT_END=4010
LR_PORT_START=35729
LR_PORT_END=35740

# Prüft ob ein Port frei ist (returns 0 = frei)
is_port_free() {
  local port=$1
  if lsof -iTCP:"$port" -sTCP:LISTEN -P -n >/dev/null 2>&1; then
    return 1
  else
    return 0
  fi
}

find_free_in_range() {
  local start=$1 end=$2
  for ((p=start; p<=end; p++)); do
    if is_port_free "$p"; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

echo "Suche freie Ports..."

SITE_PORT="$(find_free_in_range $SITE_PORT_START $SITE_PORT_END || true)"
if [ -z "$SITE_PORT" ]; then
  echo "Kein freier Site-Port im Bereich $SITE_PORT_START..$SITE_PORT_END gefunden." >&2
  exit 1
fi

LR_PORT="$(find_free_in_range $LR_PORT_START $LR_PORT_END || true)"
if [ -z "$LR_PORT" ]; then
  echo "Kein freier LiveReload-Port im Bereich $LR_PORT_START..$LR_PORT_END gefunden." >&2
  exit 1
fi

echo "Verwende Site-Port: $SITE_PORT  LiveReload-Port: $LR_PORT"

# Gems sicherstellen
if ! bundle check >/dev/null 2>&1; then
  echo "Gems fehlen — running: bundle install"
  bundle install
fi

JEKYLL_CMD=(bundle exec jekyll serve --livereload --livereload-port "$LR_PORT" --host 0.0.0.0 --port "$SITE_PORT")

echo "Starte Jekyll: ${JEKYLL_CMD[*]}"
"${JEKYLL_CMD[@]}" &
JEKYLL_PID=$!

trap 'echo "Beende Jekyll (pid $JEKYLL_PID) ..."; kill "$JEKYLL_PID" 2>/dev/null || true' EXIT INT TERM

URL="http://localhost:$SITE_PORT/"

# Warte bis Jekyll antwortet (Timeout 30s)
echo "Warte auf $URL ..."
SECS=0
MAX_SECS=30
until curl -sSfL "$URL" >/dev/null 2>&1; do
  sleep 1
  SECS=$((SECS+1))
  if [ "$SECS" -ge "$MAX_SECS" ]; then
    echo "Timeout: $URL ist nach $MAX_SECS Sekunden nicht erreichbar." >&2
    exit 1
  fi
done

echo "Öffne Browser: $URL"
"$BROWSER" "$URL" >/dev/null 2>&1 || echo "Browser konnte nicht automatisch geöffnet werden. Bitte manuell öffnen: $URL"

# Terminal an Jekyll übergeben (warten bis Prozess endet)
wait "$JEKYLL_PID"