#!/usr/bin/env bash
set -euo pipefail

# Bounded verification for the Taskboard (Rails) app.
#
# Preps databases, runs the test suite, boots Puma in production mode, probes
# every health endpoint plus anonymous-access behavior, exercises the worker
# command, and checks that data persists across a full server restart.
#
# Environment knobs:
#   VERIFY_TIMEOUT       overall budget in seconds (default 300)
#   VERIFY_PORT          port to run the probe server on (default 3117)
#   VERIFY_STEP_TIMEOUT  per-command timeout in seconds (default 120)
#   VERIFY_RAILS_ENV     env to boot the probe server with (default production)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUDGET="${VERIFY_TIMEOUT:-300}"
PORT="${VERIFY_PORT:-3117}"
STEP_TIMEOUT="${VERIFY_STEP_TIMEOUT:-120}"
PROBE_ENV="${VERIFY_RAILS_ENV:-production}"
BASE_URL="http://127.0.0.1:${PORT}"
LOG="${ROOT}/tmp/verify-server.log"
JAR="${ROOT}/tmp/verify-cookies.txt"
SERVER_PID=""
START="$(date +%s)"

say()  { printf '\033[1;34mverify:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mverify FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
ok()   { printf '\033[1;32mverify OK:\033[0m %s\n' "$*"; }

deadline() {
  local now; now="$(date +%s)"
  if (( now - START > BUDGET )); then
    die "exceeded the ${BUDGET}s budget"
  fi
}

run() {
  deadline
  if command -v timeout >/dev/null 2>&1; then
    timeout "$STEP_TIMEOUT" "$@"
  else
    "$@"
  fi
}

stop_server() {
  if [[ -n "${SERVER_PID}" ]]; then
    kill "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
    SERVER_PID=""
  fi
  rm -f "${ROOT}/tmp/pids/server.pid"
}
trap 'stop_server' EXIT

start_server() {
  stop_server
  SECRET_KEY_BASE="${SECRET_KEY_BASE:-$(ruby -rsecurerandom -e 'print SecureRandom.hex(64)')}"
  env RAILS_ENV="${PROBE_ENV}" PORT="${PORT}" SECRET_KEY_BASE="${SECRET_KEY_BASE}" \
    nohup bin/rails server -b 127.0.0.1 -p "${PORT}" -e "${PROBE_ENV}" >"${LOG}" 2>&1 &
  SERVER_PID=$!
}

wait_ready() {
  local attempt=0
  until curl -sf "${BASE_URL}/health/ready" >/dev/null 2>&1; do
    deadline
    attempt=$((attempt + 1))
    (( attempt < 90 )) || die "Puma did not become ready; see log tail:\n$(tail -n 20 "${LOG}")"
    sleep 1
  done
}

say "budget=${BUDGET}s port=${PORT} probe_env=${PROBE_ENV}"
mkdir -p "${ROOT}/tmp/pids"

say "preparing databases"
run env RAILS_ENV=test bin/rails db:prepare
# Production sandbox: load the schema (seeds deliberately refuse to run in
# production; the login user is created explicitly below). The env check is
# overridden because this is a throwaway local sandbox database, not a real one.
run env DISABLE_DATABASE_ENVIRONMENT_CHECK=1 RAILS_ENV=production bin/rails db:schema:load

say "seeding a login user into the production database"
run env RAILS_ENV=production bin/rails runner \
  "User.find_or_create_by!(email: 'demo@example.com') { |u| u.password = 'password' }" \
  >/dev/null

say "running test suite"
run env RAILS_ENV=test bin/rails test

say "booting Puma (RAILS_ENV=${PROBE_ENV}) on :${PORT}"
start_server
wait_ready
ok "Puma ready"

say "probing endpoints"
body() { curl -sS "${BASE_URL}$1"; }
code() { curl -sS -o /dev/null -w '%{http_code}' "${BASE_URL}$1"; }

body /health/live    | grep -q '"status":"ok"'            || die "/health/live malformed: $(body /health/live)"
body /health/ready   | grep -q '"status":"ok"'            || die "/health/ready malformed: $(body /health/ready)"
body /health/ready   | grep -q '"db":"up"'                || die "/health/ready db not up"
release="$(tr -d '[:space:]' < "${ROOT}/RELEASE")"
body /health/release | grep -q "${release}"               || die "/health/release does not match RELEASE marker"
[[ "$(code /up)" = "200" ]]                              || die "/up returned $(code /up)"
[[ "$(code /health/live)" = "200" ]]                     || die "liveness not 200"
[[ "$(code /health/ready)" = "200" ]]                    || die "readiness not 200"
[[ "$(code /health/release)" = "200" ]]                  || die "release not 200"
[[ "$(code /session/new)" = "200" ]]                     || die "login page not 200"
[[ "$(code /tasks)" = "302" ]]                           || die "anonymous /tasks should redirect, got $(code /tasks)"
[[ "$(code /)" = "302" ]]                                || die "anonymous / should redirect, got $(code /)"
ok "all probes passed (liveness, readiness, release, login page, anonymous redirect)"

say "exercising worker command"
run env RAILS_ENV="${PROBE_ENV}" bin/rails runner \
  "Job.create!(name: 'verify-echo', payload: '{\"action\":\"echo\",\"message\":\"verify\"}')" \
  >/dev/null
run env RAILS_ENV="${PROBE_ENV}" bin/worker --once
queued="$(run env RAILS_ENV="${PROBE_ENV}" bin/rails runner 'puts Job.where(status: :done).count')"
(( queued >= 1 )) || die "worker did not finish the queued job"
say "worker processed jobs (done count: ${queued})"

say "exercising an authenticated create across a server restart (restart persistence)"
rm -f "${JAR}"
csrf_from() { sed -n 's/.*name="csrf-token" content="\([^"]*\)".*/\1/p' <<<"$1" | head -1; }

PAGE="$(curl -sS -c "${JAR}" "${BASE_URL}/session/new")"
TOKEN="$(csrf_from "${PAGE}")"
[[ -n "${TOKEN}" ]] || die "no CSRF token on the login page"
code="$(curl -sS -o /dev/null -w '%{http_code}' -b "${JAR}" -c "${JAR}" \
  -H "X-CSRF-Token: ${TOKEN}" \
  -d "session[email]=demo@example.com&session[password]=password" \
  "${BASE_URL}/session")"
[[ "${code}" = "302" ]] || die "sign-in failed (http ${code})"

TITLE="restart-check-$(date +%s)"
PAGE="$(curl -sS -b "${JAR}" -c "${JAR}" "${BASE_URL}/tasks")"
TOKEN="$(csrf_from "${PAGE}")"
[[ -n "${TOKEN}" ]] || die "no CSRF token on the tasks page"
code="$(curl -sS -o /dev/null -w '%{http_code}' -b "${JAR}" -c "${JAR}" \
  -H "X-CSRF-Token: ${TOKEN}" \
  -d "task[title]=${TITLE}&task[owner]=verify&task[status]=todo&task[priority]=medium&task[description]=restart-persistence" \
  "${BASE_URL}/tasks")"
[[ "${code}" = "302" ]] || die "task create failed (http ${code})"

stop_server
start_server
wait_ready
ok "Puma restarted"

curl -sS -b "${JAR}" "${BASE_URL}/tasks" | grep -q "${TITLE}" \
  || die "task ${TITLE} did not survive the restart"
ok "task persisted across the restart"

stop_server
ok "all checks passed"
