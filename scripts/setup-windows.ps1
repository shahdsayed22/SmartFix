# ============================================================
#  SmartFix — One-Click Setup for Windows
#  Run this in PowerShell as Administrator:
#    Set-ExecutionPolicy Bypass -Scope Process -Force
#    .\scripts\setup-windows.ps1
# ============================================================

Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  SmartFix — Automated Setup" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# ─── 1. Install Node.js ─────────────────────────────────────
Write-Host "[1/5] Checking Node.js..." -ForegroundColor Yellow
if (Get-Command node -ErrorAction SilentlyContinue) {
    $nodeVer = node --version
    Write-Host "  Node.js $nodeVer already installed" -ForegroundColor Green
} else {
    Write-Host "  Installing Node.js via winget..." -ForegroundColor Yellow
    winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  Node.js installed!" -ForegroundColor Green
}

# ─── 2. Install MongoDB ─────────────────────────────────────
Write-Host "[2/5] Checking MongoDB..." -ForegroundColor Yellow
if (Get-Command mongod -ErrorAction SilentlyContinue) {
    Write-Host "  MongoDB already installed" -ForegroundColor Green
} else {
    Write-Host "  Installing MongoDB Community via winget..." -ForegroundColor Yellow
    winget install MongoDB.Server --accept-source-agreements --accept-package-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  MongoDB installed!" -ForegroundColor Green
}

# Start MongoDB service
Write-Host "  Starting MongoDB service..." -ForegroundColor Yellow
try {
    Start-Service MongoDB -ErrorAction SilentlyContinue
    Write-Host "  MongoDB service is running" -ForegroundColor Green
} catch {
    Write-Host "  Note: Could not auto-start MongoDB service. You may need to start it manually." -ForegroundColor DarkYellow
}

# ─── 3. Install Git (if missing) ────────────────────────────
Write-Host "[3/5] Checking Git..." -ForegroundColor Yellow
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host "  Git already installed" -ForegroundColor Green
} else {
    Write-Host "  Installing Git via winget..." -ForegroundColor Yellow
    winget install Git.Git --accept-source-agreements --accept-package-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  Git installed!" -ForegroundColor Green
}

# ─── 4. Clone repo & install deps ───────────────────────────
Write-Host "[4/5] Setting up project..." -ForegroundColor Yellow

$projectDir = "$HOME\Documents\SmartFix"

if (Test-Path $projectDir) {
    Write-Host "  Project folder already exists at $projectDir" -ForegroundColor Green
    Write-Host "  Pulling latest changes..." -ForegroundColor Yellow
    Push-Location $projectDir
    git pull origin main
} else {
    Write-Host "  Cloning repository..." -ForegroundColor Yellow
    git clone https://github.com/YOUR_ACCOUNT/smartfix.git $projectDir
    Push-Location $projectDir
}

# Create .env.local
if (-not (Test-Path ".env.local")) {
    Copy-Item ".env.example" ".env.local"
    Write-Host "  Created .env.local from template" -ForegroundColor Green
}

# npm install
Write-Host "  Installing Node.js dependencies (npm install)..." -ForegroundColor Yellow
npm install
Write-Host "  Dependencies installed!" -ForegroundColor Green

# ─── 5. Seed database & run ─────────────────────────────────
Write-Host "[5/5] Seeding database..." -ForegroundColor Yellow
npm run seed

Pop-Location

# ─── Done! ───────────────────────────────────────────────────
Write-Host ""
Write-Host "====================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host ""
Write-Host "To run the dashboard:" -ForegroundColor Cyan
Write-Host "  cd $projectDir" -ForegroundColor White
Write-Host "  npm run dev" -ForegroundColor White
Write-Host ""
Write-Host "Then open http://localhost:3000" -ForegroundColor Cyan
Write-Host ""
Write-Host "For the Flutter app, install Flutter SDK from:" -ForegroundColor Yellow
Write-Host "  https://docs.flutter.dev/get-started/install/windows" -ForegroundColor White
Write-Host "Then run: flutter pub get && flutter run" -ForegroundColor White
Write-Host ""
