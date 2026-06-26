#!/bin/bash
# ============================================================
#  SmartFix — One-Click Setup for Linux/Mac
#  Run:  chmod +x scripts/setup-linux.sh && ./scripts/setup-linux.sh
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}===================================="
echo "  SmartFix — Automated Setup"
echo -e "====================================${NC}"
echo ""

# ─── 1. Node.js ──────────────────────────────────────────────
echo -e "${YELLOW}[1/4] Checking Node.js...${NC}"
if command -v node &> /dev/null; then
    echo -e "${GREEN}  Node.js $(node --version) already installed${NC}"
else
    echo -e "${YELLOW}  Installing Node.js via nvm...${NC}"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    echo -e "${GREEN}  Node.js installed!${NC}"
fi

# ─── 2. MongoDB ──────────────────────────────────────────────
echo -e "${YELLOW}[2/4] Checking MongoDB...${NC}"
if command -v mongod &> /dev/null; then
    echo -e "${GREEN}  MongoDB already installed${NC}"
else
    echo -e "${YELLOW}  Installing MongoDB...${NC}"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Ubuntu/Debian
        curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
        echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
        sudo apt-get update
        sudo apt-get install -y mongodb-org
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew tap mongodb/brew
        brew install mongodb-community
    fi
    echo -e "${GREEN}  MongoDB installed!${NC}"
fi

# Start MongoDB
echo -e "${YELLOW}  Starting MongoDB...${NC}"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo systemctl start mongod 2>/dev/null || mongod --fork --logpath /tmp/mongod.log 2>/dev/null || true
elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew services start mongodb-community 2>/dev/null || true
fi
echo -e "${GREEN}  MongoDB is running${NC}"

# ─── 3. Clone & install ─────────────────────────────────────
echo -e "${YELLOW}[3/4] Setting up project...${NC}"

PROJECT_DIR="$HOME/Documents/SmartFix"

if [ -d "$PROJECT_DIR" ]; then
    echo -e "${GREEN}  Project exists, pulling latest...${NC}"
    cd "$PROJECT_DIR"
    git pull origin main
else
    echo -e "${YELLOW}  Cloning repository...${NC}"
    git clone https://github.com/YOUR_ACCOUNT/smartfix.git "$PROJECT_DIR"
    cd "$PROJECT_DIR"
fi

# .env.local
if [ ! -f ".env.local" ]; then
    cp .env.example .env.local
    echo -e "${GREEN}  Created .env.local${NC}"
fi

echo -e "${YELLOW}  Installing dependencies...${NC}"
npm install
echo -e "${GREEN}  Dependencies installed!${NC}"

# ─── 4. Seed ─────────────────────────────────────────────────
echo -e "${YELLOW}[4/4] Seeding database...${NC}"
npm run seed

# ─── Done ────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}===================================="
echo "  Setup Complete!"
echo -e "====================================${NC}"
echo ""
echo -e "${CYAN}Run the dashboard:${NC}"
echo "  cd $PROJECT_DIR"
echo "  npm run dev"
echo ""
echo "Then open http://localhost:3000"
echo ""
echo -e "${YELLOW}For Flutter: install Flutter SDK, then:${NC}"
echo "  flutter pub get && flutter run"
echo ""
