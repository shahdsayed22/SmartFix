#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SmartFix · LAN demo bring-up — "wire up the dashboard with the app"
#
# One command stands up the whole stack so 3 phones on the same Wi-Fi can install
# and use the PWA, all talking to ONE MongoDB:
#
#   MongoDB (reuse :27017)  →  Next.js :3000 (0.0.0.0)  ──/api──┐
#                              ├─ Admin PWA          http://<LAN>:3000/
#                              └─ /launch + /connect (QR landing)
#                           Flutter Web :8080 (0.0.0.0) ─ customer + technician PWA
#
# Usage:
#   ./scripts/wireup.sh            bring everything up (build web if needed)
#   ./scripts/wireup.sh --reseed   wipe + reseed the demo data first
#   ./scripts/wireup.sh --no-web   backend only (skip the Flutter web build/serve)
#   ./scripts/wireup.sh --rebuild  force a fresh Flutter web build
#   ./scripts/wireup.sh --status   show what's running + the URLs/QRs
#   ./scripts/wireup.sh --down     stop the servers this script started
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RUN_DIR="$ROOT/.wireup"; mkdir -p "$RUN_DIR"
NEXT_PORT=3000
WEB_PORT_BASE=8090   # 8080 is often taken (php/other); auto-pick a free one below
NEXT_BIN="$ROOT/node_modules/.bin/next"

# ── colors ──
if [ -t 1 ]; then B="\033[1m"; G="\033[32m"; Y="\033[33m"; R="\033[31m"; C="\033[36m"; X="\033[0m"; else B=""; G=""; Y=""; R=""; C=""; X=""; fi
say()  { printf "${C}▸${X} %s\n" "$*"; }
ok()   { printf "${G}✔${X} %s\n" "$*"; }
warn() { printf "${Y}!${X} %s\n" "$*"; }
die()  { printf "${R}✗ %s${X}\n" "$*" >&2; exit 1; }

# ── args ──
RESEED=0; SKIP_WEB=0; REBUILD=0; MODE="up"
for a in "$@"; do case "$a" in
  --reseed)  RESEED=1 ;;
  --no-web)  SKIP_WEB=1 ;;
  --rebuild) REBUILD=1 ;;
  --status)  MODE="status" ;;
  --down)    MODE="down" ;;
  -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
  *) warn "unknown arg: $a" ;;
esac; done

# ── LAN IP detection ──
lan_ip() {
  local ip
  ip="$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.*src \([0-9.]*\).*/\1/p' | head -1)"
  [ -z "$ip" ] && ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  echo "${ip:-127.0.0.1}"
}
LAN_IP="$(lan_ip)"

port_open() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
pid_alive() { [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null; }

# Resolve the Flutter-web port: reuse the one we already serve on, else pick the
# first free port from the candidate list (avoids clashing with php/other apps).
if pid_alive "$RUN_DIR/web.pid" && [ -f "$RUN_DIR/web.port" ]; then
  WEB_PORT="$(cat "$RUN_DIR/web.port")"
else
  WEB_PORT="$WEB_PORT_BASE"
  for p in "$WEB_PORT_BASE" 8091 8092 8093 5173 9080; do
    if ! port_open "$p"; then WEB_PORT="$p"; break; fi
  done
fi
echo "$WEB_PORT" > "$RUN_DIR/web.port"

ADMIN_URL="http://$LAN_IP:$NEXT_PORT/"
LAUNCH_URL="http://$LAN_IP:$NEXT_PORT/launch"
CONNECT_URL="http://$LAN_IP:$NEXT_PORT/connect"
GUIDE_URL="http://$LAN_IP:$NEXT_PORT/install.html"
CUST_URL="http://$LAN_IP:$WEB_PORT/?role=customer"
TECH_URL="http://$LAN_IP:$WEB_PORT/?role=technician"

print_qr() { # $1=label $2=url
  printf "\n${B}%s${X}\n  ${C}%s${X}\n" "$1" "$2"
  if command -v qrencode >/dev/null 2>&1; then qrencode -t ANSIUTF8 -m 1 "$2"; else echo "  (install qrencode to show a scannable code)"; fi
}

show_urls() {
  printf "\n${B}═══ SmartFix is reachable on your Wi-Fi (LAN IP %s) ═══${X}\n" "$LAN_IP"
  print_qr "🛠  ADMIN dashboard PWA"        "$ADMIN_URL"
  if [ "$SKIP_WEB" = 0 ]; then
    print_qr "👤  CUSTOMER PWA (Flutter Web)"  "$CUST_URL"
    print_qr "🔧  TECHNICIAN PWA (Flutter Web)" "$TECH_URL"
  fi
  print_qr "📖  HOW-TO-INSTALL guide (share this)" "$GUIDE_URL"
  printf "\n${B}QR hub:${X} %s   |   ${B}Guide:${X} %s\n" "$CONNECT_URL" "$GUIDE_URL"
  printf "Phones must be on the SAME Wi-Fi as this laptop.\n"
}

# ── --down ──
if [ "$MODE" = "down" ]; then
  for s in next web; do
    if pid_alive "$RUN_DIR/$s.pid"; then kill "$(cat "$RUN_DIR/$s.pid")" 2>/dev/null && ok "stopped $s (pid $(cat "$RUN_DIR/$s.pid"))"; fi
    rm -f "$RUN_DIR/$s.pid"
  done
  ok "Mongo (shared container) left running."
  exit 0
fi

# ── --status ──
if [ "$MODE" = "status" ]; then
  port_open 27017 && ok "Mongo  :27017 up" || warn "Mongo  :27017 DOWN"
  (pid_alive "$RUN_DIR/next.pid" || port_open $NEXT_PORT) && ok "Next   :$NEXT_PORT up" || warn "Next   :$NEXT_PORT DOWN"
  (pid_alive "$RUN_DIR/web.pid"  || port_open $WEB_PORT)  && ok "Web    :$WEB_PORT up"  || warn "Web    :$WEB_PORT DOWN"
  [ -d build/web ] && ok "Flutter web build present (build/web)" || warn "no build/web yet"
  show_urls
  exit 0
fi

printf "${B}SmartFix wire-up${X}  ·  repo: %s  ·  LAN IP: %s\n\n" "$ROOT" "$LAN_IP"

# ── 1. env ──
if [ ! -f .env.local ]; then
  [ -f .env.example ] && cp .env.example .env.local && warn "created .env.local from .env.example" || warn "no .env.local and no .env.example"
fi
MONGO_URI="$(grep -E '^MONGODB_URI=' .env.local 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r' | xargs)"
MONGO_URI="${MONGO_URI:-mongodb://localhost:27017/smartfix}"
ok "MONGODB_URI = $MONGO_URI"

# ── 2. Mongo (reuse if up, else start a container) ──
if port_open 27017; then
  ok "MongoDB already listening on :27017 (reusing it)"
else
  if command -v docker >/dev/null 2>&1; then
    say "starting MongoDB container (smartfix-mongo)…"
    docker start smartfix-mongo >/dev/null 2>&1 || docker run -d --name smartfix-mongo -p 27017:27017 mongo:7 >/dev/null 2>&1 \
      || die "could not start MongoDB via docker"
    for i in $(seq 1 30); do port_open 27017 && break; sleep 1; done
    port_open 27017 && ok "MongoDB up on :27017" || die "MongoDB did not come up"
  else
    die "MongoDB not running on :27017 and docker not available — start Mongo first"
  fi
fi

# ── 3. deps ──
if [ ! -d node_modules ]; then say "npm install…"; npm install || die "npm install failed"; else ok "node_modules present"; fi

# ── 4. Next.js on 0.0.0.0:3000 ──
if port_open $NEXT_PORT; then
  ok "Next.js already up on :$NEXT_PORT"
else
  [ -x "$NEXT_BIN" ] || NEXT_BIN="npx next"
  say "starting Next.js on 0.0.0.0:$NEXT_PORT …"
  nohup $NEXT_BIN dev -H 0.0.0.0 -p $NEXT_PORT >"$RUN_DIR/next.log" 2>&1 &
  echo $! > "$RUN_DIR/next.pid"
fi
say "waiting for the API to answer…"
API_UP=0
for i in $(seq 1 90); do
  if curl -sf "http://127.0.0.1:$NEXT_PORT/api/categories" >/dev/null 2>&1; then API_UP=1; break; fi
  sleep 1
done
[ "$API_UP" = 1 ] && ok "Next.js API responding on :$NEXT_PORT" || { tail -n 25 "$RUN_DIR/next.log" 2>/dev/null; die "Next.js API never came up (see $RUN_DIR/next.log)"; }

# ── 5. seed if empty (or --reseed) ──
ISSUE_N="$(curl -sf "http://127.0.0.1:$NEXT_PORT/api/issues?limit=1" 2>/dev/null | jq -r '(.issues // []) | length' 2>/dev/null || echo 0)"
if [ "$RESEED" = 1 ]; then
  say "reseeding demo data (--reseed)…"; npm run seed || die "seed failed"; ok "reseeded"
elif [ "${ISSUE_N:-0}" = "0" ]; then
  say "DB looks empty — seeding demo data…"; npm run seed || die "seed failed"; ok "seeded"
else
  ok "DB already has data (skipping seed; use --reseed to wipe+reseed)"
fi

# ── 6. health-check the REAL DB path (not /api/health, which is synthetic) ──
for ep in issues technicians users; do
  if curl -sf "http://127.0.0.1:$NEXT_PORT/api/$ep?limit=1" >/dev/null 2>&1; then ok "GET /api/$ep → live"; else warn "GET /api/$ep failed"; fi
done

# ── 7. Flutter Web PWA (customer + technician) ──
if [ "$SKIP_WEB" = 0 ]; then
  if ! command -v flutter >/dev/null 2>&1; then
    warn "flutter not on PATH — skipping web build (backend is up; run with --no-web to silence)"
    SKIP_WEB=1
  else
    flutter config --enable-web >/dev/null 2>&1 || true
    if [ "$REBUILD" = 1 ] || [ ! -f build/web/index.html ]; then
      say "flutter pub get…"; flutter pub get >/dev/null 2>&1 || warn "pub get reported issues"
      say "building Flutter Web (first build can take a few minutes)…"
      if flutter build web >"$RUN_DIR/flutterbuild.log" 2>&1; then
        ok "Flutter web build complete (build/web)"
      else
        warn "Flutter web build FAILED — see $RUN_DIR/flutterbuild.log"; tail -n 20 "$RUN_DIR/flutterbuild.log"; SKIP_WEB=1
      fi
    else
      ok "reusing existing build/web (use --rebuild to refresh)"
    fi
  fi
fi

if [ "$SKIP_WEB" = 0 ]; then
  if port_open $WEB_PORT; then
    ok "web server already up on :$WEB_PORT"
  else
    say "serving Flutter web on 0.0.0.0:$WEB_PORT …"
    nohup node "$ROOT/scripts/serve-web.mjs" "$ROOT/build/web" $WEB_PORT >"$RUN_DIR/web.log" 2>&1 &
    echo $! > "$RUN_DIR/web.pid"
    for i in $(seq 1 15); do port_open $WEB_PORT && break; sleep 1; done
    port_open $WEB_PORT && ok "Flutter web PWA serving on :$WEB_PORT" || warn "web server did not bind (see $RUN_DIR/web.log)"
  fi
fi

# ── 7b. refresh the install-guide QR codes for the current LAN IP/port ──
if command -v qrencode >/dev/null 2>&1; then
  mkdir -p "$ROOT/public/qr"
  qrencode -o "$ROOT/public/qr/customer.png"   -s 8 -m 2 "$CUST_URL"   2>/dev/null || true
  qrencode -o "$ROOT/public/qr/technician.png" -s 8 -m 2 "$TECH_URL"   2>/dev/null || true
  qrencode -o "$ROOT/public/qr/admin.png"      -s 8 -m 2 "$ADMIN_URL"  2>/dev/null || true
  qrencode -o "$ROOT/public/qr/guide.png"      -s 8 -m 2 "http://$LAN_IP:$NEXT_PORT/install.html" 2>/dev/null || true
  ok "install-guide QR codes refreshed (http://$LAN_IP:$NEXT_PORT/install.html)"
fi

# ── 8. URLs + QR per role ──
show_urls

printf "\n${B}Next:${X} scan a code above on a phone (same Wi-Fi).  Stop with: ${C}./scripts/wireup.sh --down${X}\n"
printf "Logs: %s/{next,web,flutterbuild}.log   Status: ${C}./scripts/wireup.sh --status${X}\n" "$RUN_DIR"
