#!/usr/bin/env bash
# Glassy Self-Host doctor: one command that says what is healthy and what
# needs attention, in plain words. It only reads; it changes nothing.
#
#   ./doctor.sh           a short report for a person
#   ./doctor.sh --json    the same findings for a script or an agent
#
# Exit codes: 0 all good · 1 something needs attention · 2 Glassy isn't working
set -uo pipefail

cd "$(dirname "$0")"

# In Git Bash on Windows, stop paths like /app/data from being rewritten on their way to Docker.
export MSYS_NO_PATHCONV=1

JSON=0
[ "${1:-}" = "--json" ] && JSON=1
[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "$JSON" -eq 0 ]; then
  G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'
else G=""; Y=""; R=""; N=""; fi

WORST=0
FINDINGS=""
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
# add <level: ok|attention|problem> <id> <message> [what to do]
add() {
  local level="$1" id="$2" msg="$3" fix="${4:-}"
  case "$level" in attention) [ "$WORST" -lt 1 ] && WORST=1 ;; problem) WORST=2 ;; esac
  if [ "$JSON" -eq 1 ]; then
    FINDINGS="$FINDINGS${FINDINGS:+,}{\"id\":\"$id\",\"level\":\"$level\",\"message\":\"$(esc "$msg")\",\"fix\":\"$(esc "$fix")\"}"
  else
    case "$level" in
      ok)        printf '  %sok%s         %s\n' "$G" "$N" "$msg" ;;
      attention) printf '  %sattention%s  %s\n' "$Y" "$N" "$msg" ;;
      problem)   printf '  %sproblem%s    %s\n' "$R" "$N" "$msg" ;;
    esac
    [ -n "$fix" ] && printf '             → %s\n' "$fix"
  fi
}
finish() {
  if [ "$JSON" -eq 1 ]; then
    local s=ok; [ "$WORST" -eq 1 ] && s=attention; [ "$WORST" -eq 2 ] && s=problem
    printf '{"status":"%s","findings":[%s]}\n' "$s" "$FINDINGS"
  else
    case "$WORST" in
      0) printf '\nGlassy is healthy.\n' ;;
      1) printf '\nGlassy is running. The items marked "attention" are worth a look.\n' ;;
      2) printf '\nGlassy needs a fix before it will work. Start with the first "problem" above.\n' ;;
    esac
  fi
  exit "$WORST"
}

env_get() { [ -f .env ] && grep -E "^$1=" .env | tail -n 1 | cut -d= -f2- || true; }
http_get() {
  if command -v curl >/dev/null 2>&1; then curl -fsS --max-time 6 "$1" 2>/dev/null
  else wget -qO- --timeout=6 "$1" 2>/dev/null; fi
}
json_field() { printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" | head -n 1; }

[ "$JSON" -eq 0 ] && printf 'Glassy check\n\n'

# ── Docker ───────────────────────────────────────────────────────────────────
if ! command -v docker >/dev/null 2>&1; then
  add problem docker "Docker isn't installed." "Install Docker, then run ./install.sh"; finish
fi
if ! docker info >/dev/null 2>&1; then
  add problem docker "Docker isn't running." "Start Docker Desktop (or 'sudo systemctl start docker') and run this again."; finish
fi
add ok docker "Docker is running"

# ── Settings ─────────────────────────────────────────────────────────────────
if [ ! -f .env ]; then
  add problem env "There is no .env file here, so Glassy hasn't been set up in this folder." "Run ./install.sh"; finish
fi
TAG="$(env_get GLASSY_TAG)"
PORT="$(env_get APP_PORT)"; [ -n "$PORT" ] || PORT=3000
BASE="http://localhost:$PORT"
missing=""
for k in GLASSY_TAG GLASSY_MEMBER_EMAIL GLASSY_SELFHOST_TOKEN JWT_SECRET API_KEY_ENCRYPTION_KEY; do
  [ -n "$(env_get "$k")" ] || missing="$missing $k"
done
if [ -n "$missing" ]; then
  add problem env ".env is missing:$missing" "Run ./install.sh; it fills in what is missing and keeps the rest."
else
  add ok env ".env has everything Glassy needs"
fi
case "$TAG" in latest|main)
  add problem tag "GLASSY_TAG is \"$TAG\". That build is for Glassy's own cloud and hides the self-host features." \
    "Set GLASSY_TAG in .env to the version in .env.example, then: docker compose up -d" ;;
esac

APP_URL="$(env_get APP_URL)"; CORS="$(env_get CORS_ORIGINS)"
if [ "$PORT" != "3000" ]; then
  case "$APP_URL" in http://localhost:3000*) add attention url "APP_PORT is $PORT but APP_URL still says port 3000, so sign-in links will point at the wrong place." "Set APP_URL=http://localhost:$PORT in .env, then: docker compose up -d" ;; esac
  case "$CORS" in http://localhost:3000) add attention cors "APP_PORT is $PORT but CORS_ORIGINS still says port 3000, so the page can't reach Glassy." "Set CORS_ORIGINS=http://localhost:$PORT in .env, then: docker compose up -d" ;; esac
fi

# ── The container ────────────────────────────────────────────────────────────
state="$(docker inspect glassy --format '{{.State.Status}}' 2>/dev/null || true)"
if [ -z "$state" ]; then
  add problem container "Glassy isn't started." "Start it with: docker compose up -d"; finish
fi
if [ "$state" != "running" ]; then
  add problem container "Glassy's container is \"$state\", not running." "See why with: docker compose logs --tail 40 glassy   then: docker compose up -d"; finish
fi
owner="$(docker inspect glassy --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' 2>/dev/null || true)"
# Docker Desktop on Windows records the folder as C:\path; Git Bash calls the same folder /c/path.
same_folder() {
  local a b
  a="$(printf '%s' "$1" | tr '\\' '/' | sed -e 's|^\([A-Za-z]\):|/\1|' -e 's|/*$||' | tr 'A-Z' 'a-z')"
  b="$(printf '%s' "$2" | tr '\\' '/' | sed -e 's|^\([A-Za-z]\):|/\1|' -e 's|/*$||' | tr 'A-Z' 'a-z')"
  [ "$a" = "$b" ]
}
# Git Bash can also mount a Windows folder elsewhere (the Temp folder is /tmp); `pwd -W` gives
# its Windows name, so compare against both.
here_win="$(pwd -W 2>/dev/null || true)"
if [ -n "$owner" ] && ! same_folder "$owner" "$PWD" && { [ -z "$here_win" ] || ! same_folder "$owner" "$here_win"; }; then
  add attention folder "The running Glassy was started from $owner, not this folder. This report reads this folder's .env, so some lines may not match." "Run doctor.sh from $owner"
fi
add ok container "Glassy's container is running"

health="$(http_get "$BASE/api/health" || true)"
if [ "$(json_field "$health" status)" != "ok" ]; then
  dstate="$(docker inspect glassy --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' 2>/dev/null || true)"
  if [ "$dstate" = "starting" ]; then
    add attention health "Glassy is still starting." "Wait a minute and run this again."
  else
    add problem health "Glassy isn't answering at $BASE." "Check APP_PORT in .env, and the log: docker compose logs --tail 40 glassy"
  fi
  finish
fi
running="v$(json_field "$health" version)"
if [ -n "$TAG" ] && [ "$running" != "$TAG" ]; then
  add attention version "Running $running, but .env asks for $TAG." "Apply it with: docker compose pull && docker compose up -d"
else
  add ok version "Running $running at $BASE"
fi

# ── What kind of Glassy this is ──────────────────────────────────────────────
instance="$(http_get "$BASE/api/instance" || true)"
if [ "$(json_field "$instance" instanceId)" != "self_hosted" ]; then
  add problem identity "This build doesn't report itself as a self-host, so agent access, search and your own AI keys are hidden." \
    "Set GLASSY_TAG in .env to a released version (see .env.example), then: docker compose pull && docker compose up -d"
fi
case "$(json_field "$instance" membershipState)" in
  verified) add ok account "Your Glassy account is confirmed" ;;
  *) add attention account "Glassy couldn't confirm your account at the last start. Everything on this machine still works." \
       "Check GLASSY_MEMBER_EMAIL, GLASSY_SELFHOST_TOKEN and GLASSY_VERIFY_CLOUD_URL in .env, then: docker compose restart glassy" ;;
esac

if docker exec glassy test -f /app/data/.initial_admin_password 2>/dev/null; then
  add attention firstsignin "Nobody has signed in yet. The first password is still waiting." \
    "Read it with: docker exec glassy cat /app/data/.initial_admin_password   then sign in at $BASE and choose your own."
fi

# ── Agents and search ────────────────────────────────────────────────────────
caps="$(http_get "$BASE/api/capabilities" || true)"
if printf '%s' "$caps" | grep -q '"mountState":"mounted"'; then
  add ok agents "Agent access is on ($BASE/mcp)"
else
  add attention agents "Agent access (MCP) is off, so assistants can't connect." "Remove ENABLE_MCP_SERVER=false from .env if it is there, then: docker compose up -d"
fi

ollama_up=0
ollama_url="$(docker exec glassy printenv OLLAMA_BASE_URL 2>/dev/null || true)"
if [ -n "$ollama_url" ]; then
  if docker exec glassy node -e "fetch('${ollama_url%/}/api/tags',{signal:AbortSignal.timeout(4000)}).then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" >/dev/null 2>&1; then
    ollama_up=1
    add ok ollama "Ollama is reachable, so AI can run on your own machine"
  else
    add ok ollama "No Ollama found at ${ollama_url}. That's fine if you use AI in the browser or your own key."
  fi
fi

# Search by words always works. Search by meaning needs a model the person chose; not having
# one is a choice, not a fault, so it only needs attention when a model is there and failing.
ready="$(http_get "$BASE/api/monitoring/ready" || true)"
if printf '%s' "$ready" | grep -q '"embeddingHealth":{"ok":false'; then
  if [ "$ollama_up" -eq 1 ]; then
    add attention search "Search by meaning has a problem; search by words still works." "Open Settings → Connections & data → Second Brain in Glassy to see what it needs."
  else
    add ok search "Search works by words. To also search by meaning, choose where AI runs (docs/ai.md)."
  fi
fi

# ── Backups and disk ─────────────────────────────────────────────────────────
age="$(printf '%s' "$health" | sed -n 's/.*"ageHours":\([0-9.]*\).*/\1/p')"
if [ -z "$age" ]; then
  up="$(json_field "$health" uptime)"
  if [ -n "$up" ] && [ "$up" -gt 172800 ] 2>/dev/null; then
    add attention backup "Glassy has been up for two days and hasn't made a backup yet." "See docs/backups.md"
  else
    add ok backup "No backup yet. Glassy makes its first one overnight."
  fi
elif [ "${age%.*}" -gt 48 ] 2>/dev/null; then
  add attention backup "The newest backup is ${age%.*} hours old." "See docs/backups.md"
elif [ "${age%.*}" -lt 1 ] 2>/dev/null; then
  add ok backup "Backed up within the last hour (kept inside Glassy's data volume; keep a copy elsewhere too)"
else
  add ok backup "Backed up ${age%.*} hours ago (kept inside Glassy's data volume; keep a copy elsewhere too)"
fi

free_kb="$(df -Pk . | awk 'NR==2 {print $4}')"
if [ -n "$free_kb" ] && [ "$free_kb" -lt 2000000 ]; then
  add attention disk "Less than 2 GB of disk is free on this drive." "Free some space before the next update."
fi

finish
