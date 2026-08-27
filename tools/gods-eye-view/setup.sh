#!/usr/bin/env bash
# Richtet God's Eye View (https://github.com/bilawalsidhu/gods-eye-view) ein
# und startet den lokalen Dev-Server. Gegenstueck zu setup.ps1 fuer Windows.
#
#   ./setup.sh                        # Standard: ~/gods-eye-view, Port 4173
#   ./setup.sh --dir /pfad --port 5173
#   ./setup.sh --setup-only           # nur einrichten, nicht starten
#
set -euo pipefail

REPO_URL="https://github.com/bilawalsidhu/gods-eye-view.git"
KEY_PLACEHOLDER="your_google_maps_api_key_here"

INSTALL_DIR="${GEV_DIR:-$HOME/gods-eye-view}"
PORT="${PORT:-4173}"
SETUP_ONLY=0
REINSTALL=0
SKIP_NODE_CHECK=0
NO_BROWSER=0
NON_INTERACTIVE=0

step() { printf '\033[36m[SETUP]\033[0m %s\n' "$1"; }
ok()   { printf '\033[32m[OK]   \033[0m %s\n' "$1"; }
warn() { printf '\033[33m[HINW] \033[0m %s\n' "$1"; }
err()  { printf '\033[31m[FEHLER]\033[0m %s\n' "$1" >&2; }
fail() { err "$1"; exit 1; }

usage() {
  cat <<'USAGE'
Optionen:
  --dir <pfad>       Zielordner (Default: ~/gods-eye-view, oder $GEV_DIR)
  --port <nummer>    Port des Dev-Servers (Default: 4173)
  --setup-only       Nur einrichten, nicht starten
  --reinstall        node_modules loeschen und neu installieren
  --skip-node-check  Node-Versionspruefung ueberspringen
  --no-browser       Browser nicht automatisch oeffnen
  --non-interactive  Keine Rueckfragen stellen
  -h, --help         Diese Hilfe
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --setup-only) SETUP_ONLY=1; shift ;;
    --reinstall) REINSTALL=1; shift ;;
    --skip-node-check) SKIP_NODE_CHECK=1; shift ;;
    --no-browser) NO_BROWSER=1; shift ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unbekannte Option: $1"; usage; exit 1 ;;
  esac
done

echo
echo "==================================================="
echo "   God's Eye View - lokales Setup"
echo "==================================================="
echo
step "Zielordner: ${INSTALL_DIR}"

# --- Git ---------------------------------------------------------------------
if ! command -v git >/dev/null 2>&1; then
  err "Git wurde nicht gefunden."
  echo "  macOS:  xcode-select --install    (oder: brew install git)"
  echo "  Debian: sudo apt install git"
  exit 1
fi
ok "Git gefunden: $(git --version)"

# --- Node --------------------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
  err "Node.js wurde nicht gefunden."
  echo "  Empfohlen: Node 24 LTS ueber nvm — https://github.com/nvm-sh/nvm"
  echo "    nvm install 24 && nvm use 24"
  exit 1
fi

NODE_RAW="$(node --version)"
NODE_MAJOR="$(printf '%s' "$NODE_RAW" | sed -E 's/^v([0-9]+)\..*/\1/')"
NODE_MINOR="$(printf '%s' "$NODE_RAW" | sed -E 's/^v[0-9]+\.([0-9]+)\..*/\1/')"
NODE_OK=0
# package.json des Projekts verlangt: >=24.14.0 <25 || >=26 <27
if [[ "$NODE_MAJOR" == "24" && "$NODE_MINOR" -ge 14 ]]; then NODE_OK=1; fi
if [[ "$NODE_MAJOR" == "26" ]]; then NODE_OK=1; fi

if [[ "$NODE_OK" -eq 1 ]]; then
  ok "Node-Version passt: ${NODE_RAW}"
elif [[ "$SKIP_NODE_CHECK" -eq 1 ]]; then
  warn "Node ${NODE_RAW} entspricht nicht der geforderten Version (24.14+ oder 26.x)."
  warn "Weiter wegen --skip-node-check. Unerwartete Fehler sind moeglich."
else
  err "Node ${NODE_RAW} wird vom Projekt nicht unterstuetzt."
  echo "  Gefordert (package.json): >=24.14.0 <25 || >=26 <27"
  echo "  nvm install 24 && nvm use 24"
  echo "  Trotzdem versuchen: ./setup.sh --skip-node-check"
  exit 1
fi

# --- Repository klonen / aktualisieren ---------------------------------------
if [[ -d "${INSTALL_DIR}/.git" ]]; then
  step "Repository gefunden, hole Updates ..."
  if git -C "${INSTALL_DIR}" pull --ff-only; then
    ok "Repository aktuell."
  else
    warn "git pull fehlgeschlagen (lokale Aenderungen?). Bestehender Stand wird verwendet."
  fi
elif [[ -d "${INSTALL_DIR}" ]] && [[ -n "$(ls -A "${INSTALL_DIR}" 2>/dev/null)" ]]; then
  fail "Ordner '${INSTALL_DIR}' existiert, ist aber kein Git-Repository und nicht leer. Anderen --dir waehlen."
else
  step "Klone ${REPO_URL} ..."
  git clone "${REPO_URL}" "${INSTALL_DIR}"
  ok "Repository geklont."
fi

cd "${INSTALL_DIR}"

# --- .env --------------------------------------------------------------------
if [[ ! -f .env ]]; then
  [[ -f .env.example ]] || fail ".env.example fehlt im Repository."
  cp .env.example .env
  ok ".env aus .env.example angelegt."
fi

read_env_value() {
  # Liest einen Wert aus .env, ohne die Datei als Shell-Code auszufuehren.
  sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*(.*)$/\1/p" .env | head -n1
}

set_env_value() {
  local name="$1" value="$2" tmp
  tmp="$(mktemp)"
  if grep -qE "^[[:space:]]*${name}[[:space:]]*=" .env; then
    awk -v name="${name}" -v value="${value}" '
      $0 ~ "^[[:space:]]*" name "[[:space:]]*=" { print name "=" value; next }
      { print }
    ' .env > "${tmp}"
  else
    cat .env > "${tmp}"
    printf '%s=%s\n' "${name}" "${value}" >> "${tmp}"
  fi
  cat "${tmp}" > .env
  rm -f "${tmp}"
}

GOOGLE_KEY="$(read_env_value GOOGLE_MAPS_API_KEY)"
if [[ -z "${GOOGLE_KEY}" || "${GOOGLE_KEY}" == "${KEY_PLACEHOLDER}" ]]; then
  echo
  warn "GOOGLE_MAPS_API_KEY fehlt - er liefert den fotorealistischen 3D-Globus."
  echo "  Key holen: https://console.cloud.google.com/  (Map Tiles API aktivieren)"
  echo "  Kostenpflichtig/metered: Key einschraenken und ein Budget-Limit setzen."
  if [[ "${NON_INTERACTIVE}" -eq 0 ]]; then
    read -r -p "  Key jetzt einfuegen (Enter = spaeter nachtragen): " ENTERED || ENTERED=""
    if [[ -n "${ENTERED}" ]]; then
      set_env_value GOOGLE_MAPS_API_KEY "${ENTERED}"
      ok "Key in .env gespeichert."
    else
      warn "Ohne Key startet die App, der 3D-Globus bleibt aber leer."
      warn "Nachtragen in: ${INSTALL_DIR}/.env"
    fi
  fi
else
  ok "GOOGLE_MAPS_API_KEY ist gesetzt."
fi

# OpenSky ohne Zugangsdaten: anonymer Modus haelt die Flug-Ebene am Leben.
if [[ -z "$(read_env_value OPENSKY_CLIENT_ID)" && "$(read_env_value OPENSKY_AUTH_MODE)" == "oauth" ]]; then
  set_env_value OPENSKY_AUTH_MODE anon
  ok "OPENSKY_AUTH_MODE=anon gesetzt (keine OpenSky-Zugangsdaten hinterlegt)."
fi

# --- Abhaengigkeiten ---------------------------------------------------------
if [[ "${REINSTALL}" -eq 1 && -d node_modules ]]; then
  step "Entferne node_modules ..."
  rm -rf node_modules
fi

if [[ ! -d node_modules ]]; then
  step "Installiere Abhaengigkeiten (dauert beim ersten Mal einige Minuten) ..."
  npm install
  ok "Abhaengigkeiten installiert."
else
  ok "node_modules vorhanden (Neuinstallation mit --reinstall)."
fi

if [[ "${SETUP_ONLY}" -eq 1 ]]; then
  echo
  ok "Setup abgeschlossen. Start mit: npm run dev -- --host localhost --port ${PORT}"
  exit 0
fi

# --- Start -------------------------------------------------------------------
URL="http://localhost:${PORT}/"
echo
step "Starte Dev-Server auf ${URL}"
echo "  Beenden mit Strg+C."
echo "  Der Server ist nur von diesem Rechner erreichbar (localhost)."
echo

if [[ "${NO_BROWSER}" -eq 0 ]]; then
  (
    for _ in $(seq 1 180); do
      if curl -sf -o /dev/null "${URL}" 2>/dev/null; then
        if command -v open >/dev/null 2>&1; then open "${URL}"
        elif command -v xdg-open >/dev/null 2>&1; then xdg-open "${URL}" >/dev/null 2>&1
        fi
        break
      fi
      sleep 1
    done
  ) &
fi

npm run dev -- --host localhost --port "${PORT}"
