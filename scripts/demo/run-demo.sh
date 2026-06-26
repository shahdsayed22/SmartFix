#!/usr/bin/env bash
# ============================================================
# SmartFix — one-command automated dashboard + AI demo recorder.
# Boots the API+dashboard (if needed), warms the AI triage runtime,
# drives Chrome through the whole flow, and saves an .mp4.
#
#   bash scripts/demo/run-demo.sh
#
# Output: scripts/demo/out/smartfix-dashboard-demo.mp4
# ============================================================
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="scripts/demo/out"
mkdir -p "$OUT"
BASE="${DEMO_BASE:-http://localhost:3000}"

say(){ printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }

# ── 1. Mongo reachable? ──────────────────────────────────────
if ! timeout 2 bash -c '</dev/tcp/127.0.0.1/27017' 2>/dev/null; then
  echo "⚠ MongoDB is not listening on 27017. Start it first (mongod / service / docker)."; exit 1
fi

# ── 2. Dashboard + API up? start it if not. ──────────────────
STARTED_SERVER=0
if ! timeout 2 bash -c '</dev/tcp/127.0.0.1/3000' 2>/dev/null; then
  say "Starting Next.js dev server (API + dashboard + AI triage runtime)…"
  nohup npm run dev > "$OUT/devserver.log" 2>&1 &
  STARTED_SERVER=1
fi
say "Waiting for $BASE …"
curl -s --retry 60 --retry-delay 2 --retry-connrefused -o /dev/null "$BASE/api/health"

# ── 3. Seed technicians if the DB is empty (AI needs someone to match) ──
TECHS=$(curl -s "$BASE/api/technicians?limit=1" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{const j=JSON.parse(s);console.log(j.pagination?.total??0)}catch{console.log(0)}})")
if [ "${TECHS:-0}" -lt 1 ]; then
  say "Seeding database (technicians + issues)…"; npm run seed
fi

# ── 4. Warm the durable workflow (first run compiles bundles ~20-30s) ──
say "Warming the AI triage runtime…"
WID=$(curl -s -X POST "$BASE/api/issues" -H 'Content-Type: application/json' \
  -d '{"title":"__warmup__","description":"pipe burst flooding","category":"plumbing","urgency":"emergency","city":"Cairo","customerName":"warmup"}' \
  | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{console.log(JSON.parse(s)._id)}catch{console.log('')}})")
# trigger + wait until it assigns (bundle compile happens here, not on camera)
curl -s -X POST "$BASE/api/workflows/issue-triage" -H 'Content-Type: application/json' -d "{\"issueId\":\"$WID\"}" -o /dev/null || true
for i in $(seq 1 20); do
  ST=$(curl -s "$BASE/api/issues?search=__warmup__&limit=1" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const i=(JSON.parse(s).issues||[])[0]||{};console.log(i.status||'')})")
  [ "$ST" = "assigned" ] && break
  curl -s --retry 2 --retry-delay 1 -o /dev/null "$BASE/api/issues"
done
[ -n "$WID" ] && curl -s -X DELETE "$BASE/api/issues/$WID" -o /dev/null || true
echo "  runtime warm."

# ── 5. Record ────────────────────────────────────────────────
say "Recording the dashboard + AI demo (headful Chrome)…"
DISPLAY="${DISPLAY:-:1}" node scripts/demo/record-dashboard.mjs

# ── 6. Mux webm → shareable mp4 + poster ─────────────────────
if [ -f "$OUT/demo.webm" ]; then
  say "Encoding mp4…"
  ffmpeg -y -loglevel error -i "$OUT/demo.webm" -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
    "$OUT/smartfix-dashboard-demo.mp4"
  ffmpeg -y -loglevel error -sseof -3 -i "$OUT/smartfix-dashboard-demo.mp4" -vframes 1 "$OUT/poster.png" || true
  echo
  echo "✅ Done:"
  ls -lh "$OUT"/smartfix-dashboard-demo.mp4 "$OUT"/demo.webm 2>/dev/null
else
  echo "⚠ No webm produced — see recorder output above."; exit 1
fi

[ "$STARTED_SERVER" = "1" ] && echo "(left the dev server running; stop with: pkill -f 'next dev')" || true
