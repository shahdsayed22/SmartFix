# SmartFix — System Verification (Windows / PowerShell)
# Run from the repo root:  powershell -ExecutionPolicy Bypass -File scripts/verify-system.ps1
# Verifies the BACKEND stack end-to-end: Docker -> MongoDB -> Next.js API -> Triage workflow.
# (Flutter / Firebase / Google Maps are device-side and covered in VERIFY.md.)

$ErrorActionPreference = "Stop"
$base      = "http://localhost:3000/api"
$container = "smartfix-mongo"
$db        = "smartfix"
$pass = 0; $fail = 0

function Ok($m)   { Write-Host "  [PASS] $m" -ForegroundColor Green; $script:pass++ }
function Bad($m)  { Write-Host "  [FAIL] $m" -ForegroundColor Red;   $script:fail++ }
function Head($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }

# 1. Docker + MongoDB container
Head "1. MongoDB container (Docker)"
try {
    $up = docker ps --filter "name=$container" --filter "status=running" --format "{{.Names}}"
    if ($up -eq $container) { Ok "Container '$container' is running" }
    else { Bad "Container '$container' is NOT running -> run: docker start $container"; }
} catch { Bad "Docker not reachable -> start Docker Desktop" }

# 2. Mongo data counts (queried inside the container)
Head "2. Database collections (seeded data)"
function MongoCount($coll) {
    $v = docker exec $container mongosh $db --quiet --eval "db.$coll.countDocuments()" 2>$null
    return [int]($v -replace '\D','')
}
try {
    $i = MongoCount "issues"; $t = MongoCount "technicians"; $u = MongoCount "users"
    if ($i -ge 2000) { Ok "issues = $i" }       else { Bad "issues = $i (expected >= 2000 -> run: npm run seed)" }
    if ($t -ge 500)  { Ok "technicians = $t" }  else { Bad "technicians = $t (expected >= 500 -> run: npm run seed)" }
    if ($u -ge 500)  { Ok "users = $u" }        else { Bad "users = $u (expected >= 500 -> run: npm run seed)" }
} catch { Bad "Could not query MongoDB inside the container" }

# 3. Next.js dev server + API <-> DB
Head "3. Next.js API (reads from MongoDB)"
try {
    $r = Invoke-RestMethod "$base/issues?limit=2" -TimeoutSec 10
    if ($r.pagination.total -ge 2000) { Ok "/api/issues -> total = $($r.pagination.total)" }
    else { Bad "/api/issues -> total = $($r.pagination.total)" }
} catch { Bad "/api/issues unreachable -> is 'npm run dev' running on :3000?" }

foreach ($ep in @(@{p="technicians";k="technicians"}, @{p="users";k="users"})) {
    try {
        $r = Invoke-RestMethod "$base/$($ep.p)?limit=2" -TimeoutSec 10
        if ($r.($ep.k).Count -gt 0) { Ok "/api/$($ep.p) returns records" }
        else { Bad "/api/$($ep.p) returned no records" }
    } catch { Bad "/api/$($ep.p) unreachable" }
}

try {
    $a = Invoke-RestMethod "$base/analytics" -TimeoutSec 10
    if ($a.issueStats.total -ge 2000) { Ok "/api/analytics -> issueStats.total = $($a.issueStats.total)" }
    else { Bad "/api/analytics -> issueStats.total = $($a.issueStats.total)" }
} catch { Bad "/api/analytics unreachable" }

# 4. Triage workflow (Workflow DevKit) fires on issue creation
Head "4. Issue-triage workflow (POST /api/issues)"
try {
    $before = (Invoke-RestMethod "$base/issues?limit=1" -TimeoutSec 10).pagination.total
    $body = @{ title="VERIFY test"; description="smoke-test leak"; category="plumbing"; customerName="VERIFY"; city="Cairo" } | ConvertTo-Json
    $created = Invoke-RestMethod "$base/issues" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 15
    Start-Sleep -Seconds 1
    $after = (Invoke-RestMethod "$base/issues?limit=1" -TimeoutSec 10).pagination.total
    if ($created._id -and $after -eq ($before + 1)) {
        Ok "Issue created (total $before -> $after); triage fired (check dev-server console for 'triage')"
    } else { Bad "Issue POST did not increment count as expected" }
} catch { Bad "Issue POST failed -> $($_.Exception.Message)" }

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
if ($fail -eq 0) { Write-Host "ALL BACKEND CHECKS PASSED ($pass)  ✅" -ForegroundColor Green }
else { Write-Host "$pass passed, $fail FAILED  ❌  (see [FAIL] lines above)" -ForegroundColor Yellow }
Write-Host "Next: run the Flutter/Firebase/Maps checks in VERIFY.md" -ForegroundColor Cyan
