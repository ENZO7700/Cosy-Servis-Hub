#!/usr/bin/env bash
# Diagnostic smoke for CRM lead import + lead-assistant edge function.
#
# Usage:
#   ./tool/smoke_lead_diagnostic.sh
#   FIREBASE_ID_TOKEN='...' ./tool/smoke_lead_diagnostic.sh

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FN_URL="${LEAD_ASSISTANT_URL:-https://kpsnwpuydqqojwmrnkdy.supabase.co/functions/v1/lead-assistant}"
API_KEY="${SUPABASE_PUBLISHABLE_KEY:-}"
if [[ -z "$API_KEY" && -f secrets.json ]]; then
  API_KEY="$(python3 -c 'import json;print(json.load(open("secrets.json")).get("VITE_SUPABASE_PUBLISHABLE_KEY",""))' 2>/dev/null || true)"
fi

PASS=0
FAIL=0
SKIP=0

green() { printf '\033[32m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
section() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

ok() { PASS=$((PASS + 1)); green "PASS  $*"; }
bad() { FAIL=$((FAIL + 1)); red "FAIL  $*"; }
skip() { SKIP=$((SKIP + 1)); yellow "SKIP  $*"; }

section "1) Offline Flutter smoke tests"
if flutter test test/smoke/lead_import_smoke_test.dart test/integration/lead_inbox_test.dart; then
  ok "flutter unit/integration smoke"
else
  bad "flutter unit/integration smoke"
fi

section "2) Edge function CORS"
check_cors() {
  local origin="$1"
  local headers
  headers="$(curl -sS -D- -o /dev/null \
    -X OPTIONS "$FN_URL" \
    -H "Origin: $origin" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: authorization,content-type,apikey" 2>&1 || true)"
  if echo "$headers" | rg -qi "access-control-allow-origin: ${origin}"; then
    ok "CORS allow $origin"
  else
    bad "CORS missing for $origin"
    echo "$headers" | head -20
  fi
}

check_cors "http://localhost:5174"
check_cors "https://flutterdashb-h4ck3d.vercel.app"

section "3) Auth / origin validation (no token)"
body_short="$(curl -sS -w '\n%{http_code}' -X POST "$FN_URL" \
  -H 'Content-Type: application/json' \
  -H 'Origin: http://localhost:5174' \
  ${API_KEY:+-H "apikey: $API_KEY"} \
  -d '{"action":"parse_leads","raw_text":"short"}' 2>&1 || true)"
code_short="$(echo "$body_short" | tail -1)"
json_short="$(echo "$body_short" | sed '$d')"
if [[ "$code_short" == "401" ]] && echo "$json_short" | rg -q 'unauthorized'; then
  ok "no token => 401 unauthorized"
else
  bad "unexpected no-token response http=$code_short body=$json_short"
fi

body_origin="$(curl -sS -w '\n%{http_code}' -X POST "$FN_URL" \
  -H 'Content-Type: application/json' \
  -H 'Origin: http://localhost:9999' \
  ${API_KEY:+-H "apikey: $API_KEY"} \
  -d '{"action":"parse_leads","raw_text":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}' 2>&1 || true)"
code_origin="$(echo "$body_origin" | tail -1)"
json_origin="$(echo "$body_origin" | sed '$d')"
if [[ "$code_origin" == "403" ]] && echo "$json_origin" | rg -q 'forbidden_origin'; then
  ok "unknown origin => 403 forbidden_origin"
else
  bad "expected forbidden_origin, got http=$code_origin body=$json_origin"
fi

section "4) Live parse_leads (optional FIREBASE_ID_TOKEN)"
if [[ -n "${FIREBASE_ID_TOKEN:-}" ]]; then
  SAMPLE='🔥 LEAD 1 — Smoke Test Company s.r.o.
Firma: Smoke Test Company s.r.o.
Web: https://smoke-test.example
Lokácia: Bratislava, Slovakia
Veľkosť: 10-50
Sektor: Software
Kontakt: Ján Smoke, CEO
Email: jan@smoke-test.example
Telefón: +421900000000
Problém: manuálne lead follow-upy a chýbajúci CRM pipeline
Decision maker: overený founder
Trigger: rast tímu a nový produkt launch
Revenue: 100k-500k
Zdroje: LinkedIn, web report'

  payload="$(SAMPLE="$SAMPLE" python3 -c 'import json,os; print(json.dumps({"action":"parse_leads","raw_text":os.environ["SAMPLE"]}))')"
  resp="$(curl -sS -w '\n%{http_code}' -X POST "$FN_URL" \
    -H 'Content-Type: application/json' \
    -H 'Origin: http://localhost:5174' \
    -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}" \
    ${API_KEY:+-H "apikey: $API_KEY"} \
    -d "$payload" 2>&1 || true)"
  code="$(echo "$resp" | tail -1)"
  json="$(echo "$resp" | sed '$d')"
  if [[ "$code" == "200" ]] && echo "$json" | rg -q '"leads"'; then
    count="$(echo "$json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(len(d.get("leads") or []))' 2>/dev/null || echo '?')"
    ok "live parse_leads => 200, leads=$count"
  else
    bad "live parse_leads failed http=$code body=$(echo "$json" | head -c 400)"
  fi
else
  skip "set FIREBASE_ID_TOKEN to run authenticated parse_leads"
fi

section "Summary"
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
if [[ "$FAIL" -gt 0 ]]; then
  red "SMOKE FAILED"
  exit 1
fi
green "SMOKE PASSED"
exit 0
