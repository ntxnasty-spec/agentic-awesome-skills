#!/usr/bin/env bash
#
# Bootstrap God's Eye View (https://github.com/bilawalsidhu/gods-eye-view).
#
# Installs whatever is missing -- Node.js, git, the repo, its dependencies --
# then starts the dev server and opens the app.
#
#   ./install-gods-eye-view.sh              # install and start
#   ./install-gods-eye-view.sh --no-start   # install only
#   ./install-gods-eye-view.sh --dir ~/apps/gev
#
# Node goes into ~/.nvm via nvm, so nothing touches system directories and no
# existing Node install is replaced. git is the only step that may use sudo,
# and only if git is genuinely missing.

set -euo pipefail

REPO_URL="https://github.com/bilawalsidhu/gods-eye-view"
NODE_VERSION="24.14.0"          # satisfies the project's ">=24.14.0 <25"
NVM_VERSION="v0.40.3"
INSTALL_DIR="${GEV_DIR:-$HOME/gods-eye-view}"
PORT="${PORT:-4173}"
START=1

BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RST=$'\033[0m'
[ -t 1 ] || { BOLD=""; DIM=""; RED=""; GRN=""; YEL=""; RST=""; }

step() { printf '%s==>%s %s\n' "$BOLD" "$RST" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$GRN" "$RST" "$*"; }
warn() { printf '%swarn%s %s\n' "$YEL" "$RST" "$*" >&2; }
die()  { printf '%s fail%s %s\n' "$RED" "$RST" "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --no-start) START=0; shift ;;
    --dir) INSTALL_DIR="${2:?--dir needs a path}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

# ---------------------------------------------------------------- preflight --
case "$(uname -s)" in
  Darwin) OS=macos ;;
  Linux)  OS=linux ;;
  *) die "unsupported OS: $(uname -s). On Windows use WSL2, or the Pinokio one-click installer." ;;
esac

have curl || die "curl is required but not installed."

# ---------------------------------------------------------------------- git --
pkg_install() {
  if   have apt-get; then sudo apt-get update -qq && sudo apt-get install -y "$@"
  elif have dnf;     then sudo dnf install -y "$@"
  elif have pacman;  then sudo pacman -Sy --noconfirm "$@"
  elif have zypper;  then sudo zypper install -y "$@"
  elif have apk;     then sudo apk add "$@"
  elif have brew;    then brew install "$@"
  else return 1
  fi
}

step "Checking git"
if have git; then
  ok "git $(git --version | awk '{print $3}')"
else
  warn "git not found -- installing it (this step may ask for your password)"
  if [ "$OS" = macos ] && ! have brew; then
    xcode-select --install 2>/dev/null || true
    die "Accept the Xcode Command Line Tools prompt, then re-run this script."
  fi
  pkg_install git || die "Could not install git automatically. Install it, then re-run."
  ok "git installed"
fi

# --------------------------------------------------------------------- node --
# The project requires Node >=24.14 <25 or >=26 <27. Node 25 works but is EOL.
node_verdict() {
  local v maj min
  v="$(node -v 2>/dev/null | sed 's/^v//')" || return 2
  [ -n "$v" ] || return 2
  maj="${v%%.*}"; min="${v#*.}"; min="${min%%.*}"
  if   [ "$maj" -eq 24 ] && [ "$min" -ge 14 ]; then return 0
  elif [ "$maj" -eq 26 ]; then return 0
  elif [ "$maj" -eq 25 ]; then return 1   # usable, EOL
  else return 2                            # too old / too new
  fi
}

load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  # nvm's script trips over `set -u`.
  set +u
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  set -u
}

step "Checking Node.js"
load_nvm
set +e; node_verdict; verdict=$?; set -e
if [ "$verdict" -eq 0 ]; then
  ok "Node $(node -v)"
elif [ "$verdict" -eq 1 ]; then
  warn "Node $(node -v) is end-of-life but usable -- continuing"
else
  current="$(node -v 2>/dev/null || echo 'none')"
  warn "Node $current does not meet the requirement (>=24.14) -- installing $NODE_VERSION via nvm"

  if [ ! -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
    step "Installing nvm $NVM_VERSION into ${NVM_DIR:-$HOME/.nvm}"
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash \
      || die "nvm install failed."
  fi
  load_nvm
  have nvm || die "nvm installed but could not be loaded. Open a new shell and re-run."

  nvm install "$NODE_VERSION" || die "Could not install Node $NODE_VERSION."
  nvm use "$NODE_VERSION" >/dev/null
  nvm alias default "$NODE_VERSION" >/dev/null 2>&1 || true
  set +e; node_verdict; verdict=$?; set -e
  [ "$verdict" -le 1 ] || die "Node is still wrong after install: $(node -v)"
  ok "Node $(node -v) (via nvm)"
fi

have npm || die "npm is missing alongside Node -- reinstall Node and retry."

# --------------------------------------------------------------------- repo --
step "Fetching God's Eye View into $INSTALL_DIR"
if [ -d "$INSTALL_DIR/.git" ]; then
  remote="$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || echo '')"
  case "$remote" in
    *bilawalsidhu/gods-eye-view*)
      git -C "$INSTALL_DIR" pull --ff-only || warn "Could not fast-forward; keeping the local checkout as-is."
      ok "updated existing checkout"
      ;;
    *) die "$INSTALL_DIR already exists and is a different repository ($remote). Use --dir to pick another path." ;;
  esac
elif [ -e "$INSTALL_DIR" ] && [ -n "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
  die "$INSTALL_DIR exists and is not empty. Use --dir to pick another path."
else
  git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" || die "Clone failed."
  ok "cloned"
fi

cd "$INSTALL_DIR"

# ------------------------------------------------------------- dependencies --
step "Installing dependencies (a few minutes on first run)"
npm install --no-audit --no-fund || die "npm install failed."
ok "dependencies installed"

step "Running the project's setup doctor"
npm run doctor || warn "The doctor reported findings -- the app usually still starts. Review the output above."

# -------------------------------------------------------------------- start --
if [ "$START" -eq 0 ]; then
  cat <<EOF

${BOLD}Ready.${RST} Start it whenever you like:

  cd $INSTALL_DIR
  npm run dev

Then open http://localhost:$PORT
EOF
  exit 0
fi

open_url() {
  if   have xdg-open; then (xdg-open "$1" >/dev/null 2>&1 &)
  elif have open;     then (open "$1" >/dev/null 2>&1 &)
  fi
}

cat <<EOF

${BOLD}Starting God's Eye View${RST} -- http://localhost:$PORT
${DIM}No API keys needed. Click POWER UP in the app to add them later.
Keys: 1-7 sensor styles - C cockpit - H HUD - Esc out.
Press Ctrl+C to stop the server.${RST}

EOF

# Open the browser once the server actually answers.
(
  for _ in $(seq 1 90); do
    if curl -sf "http://localhost:$PORT" >/dev/null 2>&1; then
      open_url "http://localhost:$PORT"
      exit 0
    fi
    sleep 1
  done
) &

exec npm run dev
