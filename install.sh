#!/usr/bin/env bash
# Glassy Self-Host installer.
#
# Checks this machine, writes .env (keeping anything already there), starts
# Glassy and confirms it is running. Safe to run again: it never replaces a
# value you already set and never touches your data.
#
#   ./install.sh                      ask for what it needs
#   ./install.sh --check              only check this machine; change nothing
#   ./install.sh --email you@example.com --token-file ~/glassy-token.txt --yes
#
# Options:
#   --email <address>      your Glassy account email
#   --token <token>        your self-host pairing token (prefer --token-file)
#   --token-file <path>    a file holding the pairing token
#   --cloud <app|clear|URL> where your account lives (default: app)
#   --port <number>        the port Glassy answers on (default: 3000)
#   --with-ollama          also start the bundled Ollama for AI on this machine
#   --yes                  don't ask questions; stop if something is missing
#   --check                check only
#   --no-start             write .env, then stop before starting Glassy
#
# Exit codes (for scripts and agents):
#   0 running and confirmed   2 an option was not understood
#   10 Docker missing or not running, or no curl/wget to check Glassy with
#   11 port in use
#   12 a required value is missing or wrong (email, token, GLASSY_TAG, the folder)
#   13 another container already uses the name "glassy"
#   20 Glassy did not start   21 started, but did not become healthy in time
set -euo pipefail

cd "$(dirname "$0")"

EMAIL="${GLASSY_MEMBER_EMAIL:-}"
TOKEN="${GLASSY_SELFHOST_TOKEN:-}"
TOKEN_FILE=""
CLOUD=""
PORT=""
WITH_OLLAMA=0
ASSUME_YES=0
CHECK_ONLY=0
NO_START=0

need_value() { [ $# -ge 2 ] || { echo "$1 needs a value  (try ./install.sh --help)" >&2; exit 2; }; }

while [ $# -gt 0 ]; do
  case "$1" in
    --email|--token|--token-file|--cloud|--port) need_value "$@" ;;
  esac
  case "$1" in
    --email) EMAIL="${2:-}"; shift 2 ;;
    --token) TOKEN="${2:-}"; shift 2 ;;
    --token-file) TOKEN_FILE="${2:-}"; shift 2 ;;
    --cloud) CLOUD="${2:-}"; shift 2 ;;
    --port) PORT="${2:-}"; shift 2 ;;
    --with-ollama) WITH_OLLAMA=1; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    --check) CHECK_ONLY=1; shift ;;
    --no-start) NO_START=1; shift ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1  (try ./install.sh --help)" >&2; exit 2 ;;
  esac
done

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  G=$'\033[32m'; Y=$'\033[33m'; D=$'\033[2m'; B=$'\033[1m'; N=$'\033[0m'
else
  G=""; Y=""; D=""; B=""; N=""
fi
ok()   { printf '  %sok%s    %s\n' "$G" "$N" "$1"; }
note() { printf '  %snote%s  %s\n' "$Y" "$N" "$1"; }
stop() { printf '\n  %sstopped%s  %s\n' "$Y" "$N" "$1" >&2; [ -n "${2:-}" ] && printf '           %s\n' "$2" >&2; exit "${3:-1}"; }
step() { printf '\n%s%s%s\n' "$B" "$1" "$N"; }

interactive() { [ "$ASSUME_YES" -eq 0 ] && [ -t 0 ]; }

# Read KEY from .env (last assignment wins, as Compose does). Prints nothing if unset.
env_get() {
  [ -f .env ] || return 0
  grep -E "^$1=" .env | tail -n 1 | cut -d= -f2- || true
}

# Set KEY=VALUE in .env: replace the existing line, or add one.
# The value travels in the environment, not on a command line, so a token or secret never
# shows in the process list, and awk does not reinterpret backslashes in it.
env_set() {
  local key="$1" tmp
  tmp="$(mktemp)"
  if grep -qE "^$key=" .env; then
    ENV_SET_VALUE="$2" awk -v k="$key" 'BEGIN{FS="="} $1==k && !done {print k "=" ENVIRON["ENV_SET_VALUE"]; done=1; next} {print}' .env > "$tmp"
  else
    cat .env > "$tmp"
    # Start on a new line even if the file did not end with one.
    [ -s "$tmp" ] && [ -n "$(tail -c 1 "$tmp")" ] && printf '\n' >> "$tmp"
    printf '%s=%s\n' "$key" "$2" >> "$tmp"
  fi
  cat "$tmp" > .env; rm -f "$tmp"
}

random_hex() {
  if command -v openssl >/dev/null 2>&1; then openssl rand -hex 32
  else head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

port_in_use() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then ss -ltn 2>/dev/null | grep -qE "[:.]$p[[:space:]]"
  elif command -v lsof >/dev/null 2>&1; then lsof -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1
  elif command -v nc >/dev/null 2>&1; then nc -z 127.0.0.1 "$p" >/dev/null 2>&1
  else (exec 3<>"/dev/tcp/127.0.0.1/$p") >/dev/null 2>&1
  fi
}

http_get() {
  if command -v curl >/dev/null 2>&1; then curl -fsS --max-time 5 "$1" 2>/dev/null
  else wget -qO- --timeout=5 "$1" 2>/dev/null
  fi
}

json_field() { # json_field <json> <key>  → the string or number at top-level "key"
  printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" | head -n 1
}

# ───────────────────────────── 1. Check this machine ─────────────────────────
step "Checking this machine"

command -v docker >/dev/null 2>&1 \
  || stop "Docker isn't installed." "Install Docker Desktop (Windows, Mac) or Docker Engine (Linux), then run this again: https://docs.docker.com/get-docker/" 10
docker info >/dev/null 2>&1 \
  || stop "Docker is installed but isn't running." "Start Docker Desktop (or 'sudo systemctl start docker'), then run this again." 10
docker compose version >/dev/null 2>&1 \
  || stop "This Docker doesn't have Compose v2." "Update Docker, or install the Compose plugin: https://docs.docker.com/compose/install/" 10
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 \
  || stop "This machine has neither curl nor wget, so the installer can't check that Glassy answers." "Install curl, then run this again." 10
ok "Docker and Compose are ready"

[ -f .env.example ] && [ -f docker-compose.yml ] \
  || stop "This doesn't look like the Glassy Self-Host folder." "Run install.sh from the folder you cloned (it holds docker-compose.yml and .env.example)." 12

ALREADY_RUNNING=0
if docker ps --format '{{.Names}}' | grep -qx glassy; then
  owner="$(docker inspect glassy --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' 2>/dev/null || true)"
  if [ "$owner" = "$PWD" ]; then
    ALREADY_RUNNING=1
    ok "Glassy from this folder is already running"
  else
    stop "A container named \"glassy\" is already running from somewhere else${owner:+ ($owner)}." \
         "That is another Glassy on this machine. Nothing was changed. Use that folder, or stop that one first if you mean to replace it." 13
  fi
elif docker ps -a --format '{{.Names}}' | grep -qx glassy; then
  owner="$(docker inspect glassy --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' 2>/dev/null || true)"
  if [ "$owner" != "$PWD" ]; then
    stop "A stopped container named \"glassy\" already exists from somewhere else${owner:+ ($owner)}." \
         "Nothing was changed. Start it from its own folder, or remove it yourself if it is no longer wanted." 13
  fi
fi

[ -n "$PORT" ] || PORT="$(env_get APP_PORT)"
[ -n "$PORT" ] || PORT=3000
case "$PORT" in ''|*[!0-9]*) stop "The port has to be a number (you gave \"$PORT\")." "" 12 ;; esac

if [ "$ALREADY_RUNNING" -eq 0 ] && port_in_use "$PORT"; then
  stop "Port $PORT is already in use on this machine." "Pick another one, for example: ./install.sh --port 3005" 11
fi
[ "$ALREADY_RUNNING" -eq 0 ] && ok "Port $PORT is free"

free_kb="$(df -Pk . | awk 'NR==2 {print $4}')"
if [ -n "$free_kb" ] && [ "$free_kb" -lt 4000000 ]; then
  note "Less than 4 GB of disk is free here. Glassy needs about 2 GB, plus room for your notes."
else
  ok "Enough disk space"
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  printf '\nThis machine is ready for Glassy. Nothing was changed.\n'
  exit 0
fi

# ───────────────────────────── 2. Settings (.env) ────────────────────────────
step "Settings"

if [ ! -f .env ]; then
  cp .env.example .env
  ok "Made .env from .env.example"
else
  ok "Keeping your existing .env"
fi
chmod 600 .env 2>/dev/null || true

[ -n "$EMAIL" ] || EMAIL="$(env_get GLASSY_MEMBER_EMAIL)"
if [ -n "$TOKEN_FILE" ]; then
  [ -r "$TOKEN_FILE" ] || stop "Can't read the token file $TOKEN_FILE." "" 12
  TOKEN="$(tr -d '\r\n' < "$TOKEN_FILE")"
fi
[ -n "$TOKEN" ] || TOKEN="$(env_get GLASSY_SELFHOST_TOKEN)"

case "$CLOUD" in
  ""|app)  CLOUD_URL="$(env_get GLASSY_VERIFY_CLOUD_URL)"; [ -n "$CLOUD_URL" ] || CLOUD_URL="https://app.glassy.fyi"
           [ "$CLOUD" = app ] && CLOUD_URL="https://app.glassy.fyi" ;;
  clear)   CLOUD_URL="https://clear.glassy.fyi" ;;
  http*)   CLOUD_URL="${CLOUD%/}" ;;
  *)       stop "--cloud takes app, clear, or a full https:// address." "" 12 ;;
esac

if [ -z "$EMAIL" ]; then
  if interactive; then
    printf '  Your Glassy account email (a free account is enough; sign up at https://glassy.fyi): '
    read -r EMAIL
  fi
  [ -n "$EMAIL" ] || stop "Glassy needs your account email." "Run again with --email you@example.com" 12
fi

if [ -z "$TOKEN" ]; then
  if interactive; then
    printf '\n  Your pairing token ties this Glassy to your account.\n'
    printf '  Make one at %s/#/settings?g=account&s=selfhost  (Settings → Account → Self-hosting → Generate token)\n' "$CLOUD_URL"
    printf '  Paste it here (it will not be shown): '
    read -rs TOKEN; printf '\n'
  fi
  [ -n "$TOKEN" ] || stop "Glassy needs your pairing token." \
    "Make one at $CLOUD_URL/#/settings?g=account&s=selfhost, save it to a file, and run again with --token-file <path>" 12
fi

env_set GLASSY_MEMBER_EMAIL "$EMAIL"
env_set GLASSY_SELFHOST_TOKEN "$TOKEN"
env_set GLASSY_VERIFY_CLOUD_URL "$CLOUD_URL"
ok "Account: $EMAIL  (at ${CLOUD_URL#https://})"

if [ -z "$(env_get JWT_SECRET)" ]; then env_set JWT_SECRET "$(random_hex)"; made_secret=1; fi
if [ -z "$(env_get API_KEY_ENCRYPTION_KEY)" ]; then env_set API_KEY_ENCRYPTION_KEY "$(random_hex)"; made_secret=1; fi
if [ "${made_secret:-0}" -eq 1 ]; then
  ok "Made this machine's two secret keys (kept in .env; back that file up)"
else
  ok "Keeping the secret keys already in .env"
fi

TAG="$(env_get GLASSY_TAG)"
[ -n "$TAG" ] || stop ".env has no GLASSY_TAG." "Copy the GLASSY_TAG line from .env.example into .env." 12
case "$TAG" in latest|main) stop "GLASSY_TAG is \"$TAG\", which is the build for Glassy's own cloud and hides the self-host features." "Set GLASSY_TAG in .env to the version in .env.example." 12 ;; esac
ok "Version: $TAG"

if [ "$PORT" != "3000" ] || [ -n "$(env_get APP_PORT)" ]; then
  env_set APP_PORT "$PORT"
  cur_url="$(env_get APP_URL)"
  case "$cur_url" in ""|http://localhost:*) env_set APP_URL "http://localhost:$PORT" ;; esac
  cur_cors="$(env_get CORS_ORIGINS)"
  case "$cur_cors" in ""|http://localhost:*) case "$cur_cors" in *,*) ;; *) env_set CORS_ORIGINS "http://localhost:$PORT" ;; esac ;; esac
  [ "$PORT" != "3000" ] && ok "Glassy will answer on port $PORT"
fi

if [ "$NO_START" -eq 1 ]; then
  printf '\n.env is ready. Start Glassy when you like with:  docker compose up -d\n'
  exit 0
fi

# ───────────────────────────── 3. Start ──────────────────────────────────────
step "Starting Glassy"

# If the bundled Ollama was started from this folder before, keep it in the picture, so a
# later run without --with-ollama doesn't leave Glassy pointing away from it.
if [ "$WITH_OLLAMA" -eq 0 ]; then
  ollama_owner="$(docker inspect glassy-ollama --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' 2>/dev/null || true)"
  [ "$ollama_owner" = "$PWD" ] && WITH_OLLAMA=1
fi
COMPOSE=(docker compose -f docker-compose.yml)
[ "$WITH_OLLAMA" -eq 1 ] && COMPOSE+=(-f docker-compose.ollama.yml)

printf '  %sGetting Glassy %s (about 2 GB the first time)…%s\n' "$D" "$TAG" "$N"
"${COMPOSE[@]}" pull --quiet >/dev/null 2>&1 \
  || stop "Couldn't download Glassy $TAG." "Check this machine's internet connection, then run this again. Nothing else was changed." 20
"${COMPOSE[@]}" up -d >/dev/null 2>&1 \
  || stop "Docker couldn't start Glassy." "See why with:  docker compose logs --tail 40 glassy" 20

BASE="http://localhost:$PORT"
health=""
for _ in $(seq 1 60); do
  health="$(http_get "$BASE/api/health" || true)"
  [ "$(json_field "$health" status)" = "ok" ] && break
  sleep 3
done
[ "$(json_field "$health" status)" = "ok" ] \
  || stop "Glassy started but isn't answering yet." "Give it a minute, then run ./doctor.sh. The log is at:  docker compose logs --tail 40 glassy" 21

running="v$(json_field "$health" version)"
if [ "$running" = "$TAG" ]; then ok "Glassy $running is running at $BASE"
else note "Glassy is running at $BASE as $running, though .env asks for $TAG"; fi

instance="$(http_get "$BASE/api/instance" || true)"
[ "$(json_field "$instance" instanceId)" = "self_hosted" ] \
  || note "This build doesn't report itself as a self-host. Check GLASSY_TAG in .env against .env.example."

account_state="$(json_field "$instance" membershipState)"
if [ "$account_state" = "verified" ]; then
  ok "Your account is confirmed"
else
  note "Glassy couldn't confirm your account just now. Everything on this machine works."
  note "It checks again at the next start. If it stays this way, check the email and token in .env."
fi

# ───────────────────────────── 4. What's next ────────────────────────────────
step "Glassy is ready"

if docker exec glassy test -f /app/data/.initial_admin_password 2>/dev/null; then
  cat <<EOF

  1. Read your first sign-in details (email on line one, password on line two):
       docker exec glassy cat /app/data/.initial_admin_password
  2. Open $BASE and sign in. Glassy asks you to choose your own password
     straight away; the first one stops working after that.
EOF
else
  cat <<EOF

  Open $BASE and sign in with your own password.
EOF
fi

cat <<EOF

  Then:
    • Choose where AI runs, connect an assistant, link Obsidian:  docs/configure.md
    • Setting this up with an AI agent? Point it at:              AGENTS.md
    • Check on Glassy any time:                                   ./doctor.sh

  Back up .env. It holds the two keys that unlock this Glassy's data.
EOF
