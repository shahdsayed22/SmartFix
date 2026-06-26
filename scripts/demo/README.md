# SmartFix — Automated demo recording

Two recordings, both driven automatically:

| Part | Script | Output | State |
|---|---|---|---|
| **Whole dashboard + live AI** | `run-demo.sh` → `record-dashboard.mjs` | `out/smartfix-dashboard-demo.mp4` | ✅ fully automated (Chrome + Puppeteer) |
| **Mobile app, 2 roles** | `capture-mobile.sh` + `drive-phone.sh` | `out/smartfix-mobile-demo.mp4` | ▶ needs the phone **unlocked** |

## 1. Dashboard (one command)

```bash
bash scripts/demo/run-demo.sh
```
Boots the API+dashboard if needed, **warms the AI triage runtime** (first workflow run compiles bundles ~20–30 s — done off-camera), then drives Chrome through every page: Dashboard → Issues (creates a real issue that fires the durable **AI triage** and films it auto-assigning a verified technician) → Technicians → Users → **AI Insights** (the research models) → Verified → Ratings → System Health. Encodes to `out/smartfix-dashboard-demo.mp4`.

Requires: MongoDB on `27017`, Chrome, ffmpeg, `puppeteer-core` (already a dep).

## 2. Mobile (real Android phone)

Prereqs that must be true **before** running:
- Phone connected via USB, debugging on, and **UNLOCKED** (a secure PIN/pattern lockscreen blocks automation — unlock it, ideally set Screen lock → None for the take).
- App `com.smartfix.smart_fix` installed (it already is on the test phone).
- The `demo.customer@smartfix.app` / `demo.tech@smartfix.app` accounts exist (they do).

```bash
bash scripts/demo/capture-mobile.sh start   # reverse 3000 + keep awake + launch + record
bash scripts/demo/drive-phone.sh            # automated taps: customer + technician tour
bash scripts/demo/capture-mobile.sh stop    # finish + encode mp4
```

The tour uses the **Quick Demo Login** buttons (one tap each) and the known on-screen labels to drive the Customer flow (browse → report issue wizard → track) and the Technician flow (jobs → accept → start → complete), with chat.
