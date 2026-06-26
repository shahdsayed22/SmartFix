# SmartFix Selenium Suite — Execution Report

- **Run:** `20260618-075122`  
- **Started:** 2026-06-18T07:51:22.793502+00:00  
- **Base URL:** http://localhost:3000  
- **Browser:** chrome 149.0.7827.155 (chromedriver 149.0.7827.155)  
- **Selenium:** 4.43.0 · **Platform:** linux  
- **Result:** 10/10 passed

| ID | Route | Status | Duration (s) | Detail |
|----|-------|--------|--------------|--------|
| SEL-01 | `/` | **PASS** | 23.32 | 8 KPI cards (8 numeric), 6 charts mounted |
| SEL-02 | `/issues` | **PASS** | 7.13 | row created & visible=True, survives category filter=True, persists on reload=True |
| SEL-03 | `/issues` | **PASS** | 4.52 | rejection alert shown: 'Cannot set status to "assigned" without an assigned technician.' |
| SEL-04 | `/users` | **PASS** | 3.91 | rows 8->1 on search, match found=True, verification False->True persisted=True |
| SEL-05 | `/technicians` | **PASS** | 6.25 | city filter -> 8 rows; rating 4.4->3.3 (target 3.3) persisted=True |
| SEL-06 | `/payments` | **PASS** | 2.21 | 1 invoice rows; modal shows base=True, fee=True, vat=True, total=True |
| SEL-07 | `/tickets` | **PASS** | 5.91 | reply appended=True, persists on reload=True |
| SEL-08 | `/settings` | **PASS** | 3.02 | commission round-trip: fee=13 vat=15 changed=True |
| SEL-09 | `/ai-insights` | **PASS** | 2.85 | 9 insight cards; 0 severe console errors |
| SEL-10 | `/health` | **PASS** | 1.48 | 12 metric tiles rendered (12 with values) |

Screenshots are in `screenshots/`.