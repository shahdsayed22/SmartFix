# SmartFix — Selenium WebDriver GUI Test Suite (Admin Dashboard)

Automated GUI tests for the Next.js admin dashboard, implementing the ten cases
**SEL-01 … SEL-10** specified in the dissertation (Chapter 5, *Selenium GUI
Automation (Dashboard)*). Each case drives the real rendered DOM with headless
Chrome, asserts on rendered text/state, captures a screenshot, and records a
pass/fail verdict.

## Why Selenium is scoped to the dashboard

The dashboard renders a real, introspectable HTML DOM, so WebDriver can locate
elements by stable selectors and assert on rendered text and state. The Flutter
Web customer/technician apps paint to a single `<canvas>` and expose no widget
tree to WebDriver, so they are validated by manual cases and Puppeteer smoke
checks instead (see Chapter 5).

## Cases

| ID | Route | What it verifies |
|----|-------|------------------|
| SEL-01 | `/` | KPI cards show numeric values and charts mount |
| SEL-02 | `/issues` | Create an issue, filter by category, persists on reload |
| SEL-03 | `/issues` | Setting status to `assigned` without a technician is **rejected** with a user-facing error |
| SEL-04 | `/users` | Search narrows the list; verification toggle persists on reload |
| SEL-05 | `/technicians` | City filter narrows the grid; an edited rating persists |
| SEL-06 | `/payments` | Invoice modal shows base, platform fee, VAT and total |
| SEL-07 | `/tickets` | A posted reply is appended and persists on reload |
| SEL-08 | `/settings` | Commission fee/VAT edits round-trip to the API |
| SEL-09 | `/ai-insights` | Insight cards render with no severe console errors |
| SEL-10 | `/health` | Health metric tiles render with values |

## Prerequisites

- The dashboard running on `http://localhost:3000` with a seeded MongoDB
  (`mongodb://localhost:27017/smartfix`).
- Python 3.10+ and `selenium` (`pip install selenium`). Selenium 4.6+
  auto-resolves chromedriver via Selenium Manager — no manual driver download.
- Google Chrome installed.

A **production build** (`npm run build && npm start`) is recommended over
`npm run dev`: the dev server compiles each route on first request, which adds
variable latency and makes runs less reproducible.

## Running

```bash
# 1) start a seeded dashboard (production build recommended)
npm run build && npm run start          # serves on :3000

# 2) run the suite
cd tests/selenium
python3 run_suite.py                     # headless
SF_HEADED=1 python3 run_suite.py         # watch the browser
SF_BASE=http://localhost:3000 python3 run_suite.py
```

## Outputs

- `results.json` — machine-readable report (environment + per-case verdicts).
- `results.md` — human-readable summary table.
- `screenshots/SEL-*.png` — one screenshot per case.

Exit code is `0` when all cases pass, `1` otherwise.

## Notes on test design

- The UI defaults to Arabic and flips to English after hydration; the suite pins
  English via `localStorage['sf-lang']` and waits for the RTL→LTR flip so text
  locators are stable.
- SEL-03 provisions its own pending/unassigned issue via the API and waits out
  the asynchronous AI-triage workflow (which auto-assigns new issues) before
  driving the negative case, so the test is independent of seed-data state.
