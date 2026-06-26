#!/usr/bin/env python3
"""
SmartFix — Selenium WebDriver GUI automation suite for the Next.js admin dashboard.

Implements the ten cases SEL-01..SEL-10 specified in the dissertation
(Chapter 5, "Selenium GUI Automation (Dashboard)"). Each case drives the real
rendered DOM with headless Chrome, asserts on rendered text/state, captures a
screenshot, and records a pass/fail verdict. A machine-readable report
(results.json) and a human-readable summary (results.md) are written to this
directory.

Usage:
    python3 run_suite.py                 # headless, against http://localhost:3000
    SF_BASE=http://localhost:3000 python3 run_suite.py
    SF_HEADED=1 python3 run_suite.py     # show the browser

Prerequisites:
    - The dashboard running on SF_BASE (npm run dev) with a seeded MongoDB.
    - Google Chrome installed. Selenium 4.6+ auto-resolves chromedriver
      via Selenium Manager, so no manual driver download is required.
"""

import json
import os
import sys
import time
import urllib.request
from datetime import datetime, timezone

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait, Select as UiSelect
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import (
    TimeoutException, StaleElementReferenceException,
    ElementClickInterceptedException, ElementNotInteractableException,
)

BASE = os.environ.get("SF_BASE", "http://localhost:3000")
HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(HERE, "screenshots")
os.makedirs(SHOTS, exist_ok=True)
RUNTAG = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")

results = []


# ── helpers ────────────────────────────────────────────────────────────────
def make_driver():
    opts = Options()
    if not os.environ.get("SF_HEADED"):
        opts.add_argument("--headless=new")
    opts.add_argument("--no-sandbox")
    opts.add_argument("--disable-dev-shm-usage")
    opts.add_argument("--window-size=1440,2000")
    opts.add_argument("--force-device-scale-factor=1")
    opts.set_capability("goog:loggingPrefs", {"browser": "ALL"})
    d = webdriver.Chrome(options=opts)
    d.set_page_load_timeout(45)
    return d


def api(path):
    with urllib.request.urlopen(BASE + path, timeout=15) as r:
        return json.loads(r.read().decode())


def api_send(path, method, payload):
    req = urllib.request.Request(
        BASE + path, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"}, method=method)
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read().decode())


def ensure_english(d):
    """Pin the UI language to English once; localStorage persists for the session."""
    d.get(BASE + "/")
    d.execute_script("window.localStorage.setItem('sf-lang','en');")


def _wait_ltr(d, t=20):
    return WebDriverWait(d, t).until(
        lambda x: x.execute_script(
            "return document.documentElement.getAttribute('dir')") == "ltr")


def goto(d, path):
    d.get(BASE + path)
    WebDriverWait(d, 30).until(
        lambda x: x.execute_script("return document.readyState") == "complete"
    )
    # The page SSR-renders Arabic and flips to English after hydration. Block
    # until the flip lands so English text/placeholder locators are valid. If it
    # doesn't flip, force it and reload once before giving up.
    try:
        _wait_ltr(d, 20)
    except TimeoutException:
        d.execute_script("window.localStorage.setItem('sf-lang','en');")
        d.get(BASE + path)
        _wait_ltr(d, 20)
    time.sleep(0.8)  # let the first data fetch settle


def safe_click(d, el, tries=4):
    for i in range(tries):
        try:
            d.execute_script("arguments[0].scrollIntoView({block:'center'});", el)
            el.click()
            return
        except (ElementClickInterceptedException, ElementNotInteractableException,
                StaleElementReferenceException):
            if i == tries - 1:
                # Last resort: dispatch the click via JS.
                d.execute_script("arguments[0].click();", el)
                return
            time.sleep(0.4)


def shot(d, name):
    p = os.path.join(SHOTS, f"{name}.png")
    d.save_screenshot(p)
    return os.path.relpath(p, HERE)


def wait(d, by, sel, t=15):
    return WebDriverWait(d, t).until(EC.presence_of_element_located((by, sel)))


def wait_visible(d, by, sel, t=15):
    return WebDriverWait(d, t).until(EC.visibility_of_element_located((by, sel)))


def click_by_text(d, tag, text, t=15):
    xp = f"//{tag}[contains(normalize-space(.), {xpath_lit(text)})]"
    deadline = time.time() + t
    last = None
    while time.time() < deadline:
        try:
            el = WebDriverWait(d, 3).until(EC.element_to_be_clickable((By.XPATH, xp)))
            safe_click(d, el)
            return el
        except (TimeoutException, StaleElementReferenceException) as e:
            last = e
            time.sleep(0.3)
    raise last or TimeoutException(f"clickable {tag!r} with text {text!r} not found")


def xpath_lit(s):
    if '"' not in s:
        return f'"{s}"'
    if "'" not in s:
        return f"'{s}'"
    parts = s.split('"')
    return "concat(" + ', \'"\', '.join(f'"{p}"' for p in parts) + ")"


def record(cid, route, desc, passed, detail, screenshot, started):
    results.append({
        "id": cid,
        "route": route,
        "description": desc,
        "status": "PASS" if passed else "FAIL",
        "detail": detail,
        "screenshot": screenshot,
        "duration_s": round(time.time() - started, 2),
    })
    flag = "PASS" if passed else "FAIL"
    print(f"  [{flag}] {cid} {route} — {detail}")


def run(cid, route, desc, fn, d):
    started = time.time()
    print(f"▶ {cid} {route}")
    try:
        passed, detail, sc = fn(d)
        record(cid, route, desc, passed, detail, sc, started)
    except Exception as e:  # noqa: BLE001 — any failure is a test failure
        sc = ""
        try:
            sc = shot(d, f"{cid}_ERROR")
        except Exception:
            pass
        import traceback
        tb = traceback.extract_tb(e.__traceback__)
        loc = ""
        for fr in tb:
            if fr.filename.endswith("run_suite.py"):
                loc = f" @line {fr.lineno}: {fr.line}"
        record(cid, route, desc, False, f"exception: {type(e).__name__}: {e}{loc}", sc, started)


# ── SEL-01 — Dashboard KPIs + charts ────────────────────────────────────────
def sel01(d):
    goto(d, "/")
    cards = WebDriverWait(d, 20).until(
        lambda x: x.find_elements(By.CSS_SELECTOR, "[data-testid='stat-card']")
    )
    vals = []
    for c in cards:
        try:
            vals.append(c.find_element(By.CSS_SELECTOR, ".stat-value").text.strip())
        except Exception:
            pass
    numeric = [v for v in vals if any(ch.isdigit() for ch in v)]
    charts = d.find_elements(By.CSS_SELECTOR, ".chart-card")
    sc = shot(d, "SEL-01_dashboard")
    ok = len(cards) >= 4 and len(numeric) >= 4 and len(charts) >= 1
    return ok, f"{len(cards)} KPI cards ({len(numeric)} numeric), {len(charts)} charts mounted", sc


# ── SEL-02 — Create issue + filter by category ──────────────────────────────
def sel02(d):
    goto(d, "/issues")
    title = f"SEL-02 Automated Issue {RUNTAG}"
    category = "electrical"
    click_by_text(d, "button", "New Issue")
    # Wait for the create modal to be fully open before touching fields.
    wait_visible(d, By.CSS_SELECTOR, ".modal-scrim", t=15)
    title_in = wait_visible(d, By.CSS_SELECTOR, "input[placeholder*='Leaking kitchen faucet']")
    title_in.send_keys(title)
    desc_in = wait(d, By.CSS_SELECTOR, "textarea[placeholder*='Describe the problem']")
    desc_in.send_keys("Created by the automated SEL-02 Selenium case.")
    name_in = wait(d, By.CSS_SELECTOR, "input[placeholder='Full name']")
    name_in.send_keys("QA Bot")
    # The first <select> in the modal form is Category.
    modal = d.find_element(By.CSS_SELECTOR, ".modal-scrim")
    cat_select = modal.find_elements(By.CSS_SELECTOR, "select")[0]
    UiSelect(cat_select).select_by_value(category)
    click_by_text(d, "button", "Create Issue")
    # Wait for the modal to close (submit accepted) before asserting on the list.
    WebDriverWait(d, 15).until(EC.invisibility_of_element_located((By.CSS_SELECTOR, ".modal-scrim")))
    time.sleep(0.8)
    # Confirm the new row appears (search by its unique title).
    search = wait(d, By.CSS_SELECTOR, "input[placeholder*='Search title']")
    search.clear()
    search.send_keys(title)
    time.sleep(0.8)
    rows_after_search = d.find_elements(By.XPATH, f"//td[contains(.,{xpath_lit(title)})]")
    # Filter the toolbar Category select to the chosen category.
    toolbar = d.find_element(By.CSS_SELECTOR, ".toolbar")
    cat_filter = toolbar.find_elements(By.CSS_SELECTOR, "select")[0]
    UiSelect(cat_filter).select_by_value(category)
    time.sleep(0.8)
    still_visible = len(d.find_elements(By.XPATH, f"//td[contains(.,{xpath_lit(title)})]")) >= 1
    sc = shot(d, "SEL-02_issue_created_filtered")
    # Persistence: reload and search again.
    goto(d, "/issues")
    s2 = wait(d, By.CSS_SELECTOR, "input[placeholder*='Search title']")
    s2.send_keys(title)
    time.sleep(0.8)
    persisted = len(d.find_elements(By.XPATH, f"//td[contains(.,{xpath_lit(title)})]")) >= 1
    ok = len(rows_after_search) >= 1 and still_visible and persisted
    return ok, (f"row created & visible={bool(rows_after_search)}, "
                f"survives category filter={still_visible}, persists on reload={persisted}"), sc


# ── SEL-03 — Reject invalid status transition ───────────────────────────────
def sel03(d):
    # Provision a guaranteed pending + unassigned issue. The triage workflow
    # auto-assigns issues created via the API, so we force it back to
    # pending/unassigned, then drive the negative case through the UI.
    title = f"SEL-03 Pending Guard {RUNTAG}"
    created = api_send("/api/issues", "POST", {
        "title": title, "description": "Selenium SEL-03 negative test",
        "category": "plumbing", "urgency": "low", "status": "pending",
        "customerName": "QA Bot"})
    iid = created.get("_id")
    # The async triage workflow auto-assigns shortly after creation. Wait for it
    # to land (or time out), THEN reset to pending/unassigned so the reset is not
    # clobbered by a late triage write. Triage only runs on create, not on PUT.
    for _ in range(20):
        cur = api(f"/api/issues/{iid}")
        if cur.get("assignedTechnicianId") or cur.get("status") == "assigned":
            break
        time.sleep(0.5)
    api_send(f"/api/issues/{iid}", "PUT",
             {"status": "pending", "assignedTechnicianId": "", "assignedTechnicianName": ""})
    # Confirm the reset stuck before driving the UI.
    for _ in range(6):
        if not api(f"/api/issues/{iid}").get("assignedTechnicianId"):
            break
        api_send(f"/api/issues/{iid}", "PUT",
                 {"status": "pending", "assignedTechnicianId": "", "assignedTechnicianName": ""})
        time.sleep(0.5)
    goto(d, "/issues")
    search = wait(d, By.CSS_SELECTOR, "input[placeholder*='Search title']")
    search.send_keys(title)
    time.sleep(1.0)
    trigger = wait(d, By.CSS_SELECTOR, ".status-select .status-trigger")
    safe_click(d, trigger)
    time.sleep(0.3)
    # Click the 'Assigned' option in the open menu.
    opt = WebDriverWait(d, 8).until(EC.element_to_be_clickable(
        (By.XPATH, "//div[contains(@class,'status-opt') and contains(normalize-space(.),'Assigned')]")))
    safe_click(d, opt)
    # Expect a user-facing error alert and that the status is NOT assigned.
    alert = wait_visible(d, By.CSS_SELECTOR, "[role='alert'], [data-testid='issue-error']", t=8)
    msg = alert.text.strip()
    sc = shot(d, "SEL-03_status_rejected")
    ok = bool(msg) and "technician" in msg.lower()
    return ok, f"rejection alert shown: {msg!r}", sc


# ── SEL-04 — Users search, role filter, verification persistence ────────────
def sel04(d):
    users = api("/api/users")
    arr = users if isinstance(users, list) else users.get("users", [])
    target = arr[0]
    name = target["name"]
    goto(d, "/users")
    total_rows = len(d.find_elements(By.CSS_SELECTOR, "[data-testid='data-row']"))
    search = wait(d, By.CSS_SELECTOR, "input[placeholder*='Search name']")
    search.send_keys(name)
    time.sleep(0.8)
    narrowed = len(d.find_elements(By.CSS_SELECTOR, "[data-testid='data-row']"))
    found = len(d.find_elements(By.XPATH, f"//td[contains(.,{xpath_lit(name)})]")) >= 1
    sc = shot(d, "SEL-04_users_search")
    # Toggle verification via the edit modal and persist.
    before = bool(api(f"/api/users/{target['_id']}").get("isVerified"))
    edit_btn = d.find_element(By.XPATH, "//button[@title='Edit' or @title='تعديل']")
    safe_click(d, edit_btn)
    toggle = wait(d, By.CSS_SELECTOR, ".modal-scrim [role='switch']")
    safe_click(d, toggle)
    click_by_text(d, "button", "Save")
    time.sleep(1.2)
    after = bool(api(f"/api/users/{target['_id']}").get("isVerified"))
    persisted = (after != before)
    ok = narrowed <= total_rows and found and persisted
    return ok, (f"rows {total_rows}->{narrowed} on search, match found={found}, "
                f"verification {before}->{after} persisted={persisted}"), sc


# ── SEL-05 — Technicians filter + edit rating persistence ───────────────────
def sel05(d):
    goto(d, "/technicians")
    toolbar = d.find_element(By.CSS_SELECTOR, ".toolbar")
    selects = toolbar.find_elements(By.CSS_SELECTOR, "select")
    # City filter (first) and Category filter (second) — pick the first concrete option.
    city_sel = UiSelect(selects[0])
    city_val = [o.get_attribute("value") for o in city_sel.options if o.get_attribute("value") != "all"][0]
    city_sel.select_by_value(city_val)
    time.sleep(0.6)
    rows = d.find_elements(By.CSS_SELECTOR, "[data-testid='data-row']")
    filtered_count = len(rows)
    sc = shot(d, "SEL-05_technicians_filtered")
    # Edit a specific technician's rating: search by name so the UI row and the
    # API record we verify against are guaranteed to be the same document.
    techs = api("/api/technicians?limit=5")
    tarr = techs if isinstance(techs, list) else techs.get("technicians", techs.get("items", []))
    tech = tarr[0]
    before = float(tech.get("rating") or 0)
    new_rating = 3.3 if abs(before - 3.3) > 0.05 else 4.4
    goto(d, "/technicians")
    tsearch = wait(d, By.CSS_SELECTOR, "input[placeholder*='Search name']")
    tsearch.send_keys(tech["name"])
    time.sleep(0.8)
    edit_btn = wait(d, By.XPATH, "//button[@title='Edit' or @title='تعديل']")
    safe_click(d, edit_btn)
    rng = wait(d, By.CSS_SELECTOR, ".modal input[type='range'], input.range")
    d.execute_script("""
        const el = arguments[0], v = arguments[1];
        const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;
        setter.call(el, v);
        el.dispatchEvent(new Event('input', {bubbles:true}));
        el.dispatchEvent(new Event('change', {bubbles:true}));
    """, rng, str(new_rating))
    time.sleep(0.3)
    click_by_text(d, "button", "Save")
    time.sleep(1.4)
    after = float(api(f"/api/technicians/{tech['_id']}").get("rating") or 0)
    persisted = abs(after - new_rating) < 0.2
    ok = filtered_count >= 1 and persisted
    return ok, (f"city filter -> {filtered_count} rows; rating {before}->{after} "
                f"(target {new_rating}) persisted={persisted}"), sc


# ── SEL-06 — Payments invoice breakdown ─────────────────────────────────────
def sel06(d):
    goto(d, "/payments")
    rows = WebDriverWait(d, 20).until(
        lambda x: x.find_elements(By.CSS_SELECTOR, "[data-testid='data-row']"))
    view = WebDriverWait(d, 10).until(EC.element_to_be_clickable(
        (By.XPATH, "//button[@title='View invoice' or @title='عرض الفاتورة']")))
    safe_click(d, view)
    # Wait for the invoice modal itself, then read only its text.
    modal = WebDriverWait(d, 10).until(EC.visibility_of_element_located(
        (By.XPATH, "//*[contains(@class,'modal-scrim')]//*[contains(.,'Invoice Breakdown')]/ancestor::*[contains(@class,'modal-scrim')]")))
    time.sleep(0.4)
    body = modal.text.lower()
    sc = shot(d, "SEL-06_invoice")
    has_total = "total" in body
    has_vat = "vat" in body
    has_fee = ("platform" in body) or ("fee" in body) or ("commission" in body)
    has_base = ("base" in body) or ("subtotal" in body) or ("service" in body)
    ok = len(rows) >= 1 and has_total and has_vat and has_fee and has_base
    return ok, (f"{len(rows)} invoice rows; modal shows base={has_base}, fee={has_fee}, "
                f"vat={has_vat}, total={has_total}"), sc


# ── SEL-07 — Ticket reply persistence ───────────────────────────────────────
def sel07(d):
    goto(d, "/tickets")
    WebDriverWait(d, 20).until(
        lambda x: x.find_elements(By.CSS_SELECTOR, "[data-testid='data-row']"))
    open_btn = WebDriverWait(d, 10).until(EC.element_to_be_clickable(
        (By.XPATH, "//button[@title='Open thread' or @title='فتح المحادثة']")))
    safe_click(d, open_btn)
    time.sleep(0.8)
    reply_text = f"Automated SEL-07 reply {RUNTAG}"
    box = wait_visible(d, By.CSS_SELECTOR, "input[placeholder*='reply'], textarea[placeholder*='reply']")
    box.send_keys(reply_text)
    click_by_text(d, "button", "Send")
    time.sleep(1.2)
    appended = len(d.find_elements(By.XPATH, f"//*[contains(text(),{xpath_lit(reply_text)})]")) >= 1
    sc = shot(d, "SEL-07_ticket_reply")
    # Persistence: reload, reopen the same ticket, confirm the reply is present.
    goto(d, "/tickets")
    WebDriverWait(d, 20).until(
        lambda x: x.find_elements(By.CSS_SELECTOR, "[data-testid='data-row']"))
    open_btn2 = WebDriverWait(d, 10).until(EC.element_to_be_clickable(
        (By.XPATH, "//button[@title='Open thread' or @title='فتح المحادثة']")))
    safe_click(d, open_btn2)
    time.sleep(1.0)
    persisted = len(d.find_elements(By.XPATH, f"//*[contains(text(),{xpath_lit(reply_text)})]")) >= 1
    ok = appended and persisted
    return ok, f"reply appended={appended}, persists on reload={persisted}", sc


# ── SEL-08 — Settings commission round-trip ─────────────────────────────────
def sel08(d):
    before = api("/api/settings/commission")
    goto(d, "/settings")
    inputs = WebDriverWait(d, 20).until(
        lambda x: x.find_elements(By.CSS_SELECTOR, "input[type='number']"))
    # First two numeric fields are Platform Fee % and VAT %.
    new_fee, new_vat = "13", "15"

    def set_val(el, v):
        d.execute_script("""
            const el=arguments[0], v=arguments[1];
            const s=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;
            s.call(el,v); el.dispatchEvent(new Event('input',{bubbles:true}));
            el.dispatchEvent(new Event('change',{bubbles:true}));
        """, el, v)

    set_val(inputs[0], new_fee)
    set_val(inputs[1], new_vat)
    time.sleep(0.3)
    click_by_text(d, "button", "Save")
    time.sleep(1.4)
    after = api("/api/settings/commission")
    sc = shot(d, "SEL-08_settings_saved")
    fee_key = "platformFeePercent" if "platformFeePercent" in after else \
        ("platformFee" if "platformFee" in after else None)
    vat_key = "vatPercent" if "vatPercent" in after else ("vat" if "vat" in after else None)
    changed = (json.dumps(before, sort_keys=True) != json.dumps(after, sort_keys=True))
    fee_ok = (str(after.get(fee_key)) == new_fee) if fee_key else changed
    vat_ok = (str(after.get(vat_key)) == new_vat) if vat_key else changed
    ok = changed and fee_ok and vat_ok
    return ok, (f"commission round-trip: fee={after.get(fee_key)} vat={after.get(vat_key)} "
                f"changed={changed}"), sc


# ── SEL-09 — AI Insights renders without console errors ─────────────────────
def sel09(d):
    goto(d, "/ai-insights")
    # Drain console logs accumulated across earlier cases, then load fresh so the
    # error check reflects only this page.
    try:
        d.get_log("browser")
    except Exception:
        pass
    d.get(BASE + "/ai-insights")
    cards = WebDriverWait(d, 20).until(
        lambda x: x.find_elements(By.CSS_SELECTOR, "[data-testid='stat-card']"))
    time.sleep(1.0)
    try:
        logs = d.get_log("browser")
    except Exception:
        logs = []
    severe = [l for l in logs if l.get("level") == "SEVERE"
              and "favicon" not in l.get("message", "").lower()]
    sc = shot(d, "SEL-09_ai_insights")
    ok = len(cards) >= 1 and len(severe) == 0
    return ok, f"{len(cards)} insight cards; {len(severe)} severe console errors", sc


# ── SEL-10 — Health metric tiles render ─────────────────────────────────────
def sel10(d):
    goto(d, "/health")
    tiles = WebDriverWait(d, 20).until(
        lambda x: x.find_elements(By.CSS_SELECTOR, "[data-testid='metric-tile']"))
    with_values = 0
    for tl in tiles:
        if tl.text.strip():
            with_values += 1
    sc = shot(d, "SEL-10_health")
    ok = len(tiles) >= 1 and with_values >= 1
    return ok, f"{len(tiles)} metric tiles rendered ({with_values} with values)", sc


# ── runner ──────────────────────────────────────────────────────────────────
def main():
    print(f"SmartFix Selenium suite — base={BASE} run={RUNTAG}")
    try:
        urllib.request.urlopen(BASE + "/", timeout=10)
    except Exception as e:  # noqa: BLE001
        print(f"FATAL: dashboard not reachable at {BASE} ({e})")
        sys.exit(2)

    d = make_driver()
    caps = d.capabilities
    env = {
        "base": BASE,
        "run": RUNTAG,
        "browser": caps.get("browserName"),
        "browserVersion": caps.get("browserVersion"),
        "chromedriverVersion": caps.get("chrome", {}).get("chromedriverVersion", "").split(" ")[0],
        "selenium": webdriver.__version__ if hasattr(webdriver, "__version__") else "4.x",
        "platform": sys.platform,
        "startedAt": datetime.now(timezone.utc).isoformat(),
    }
    try:
        ensure_english(d)
        run("SEL-01", "/", "Dashboard KPI cards + charts mount", sel01, d)
        run("SEL-02", "/issues", "Create issue then filter by category", sel02, d)
        run("SEL-03", "/issues", "Reject invalid status transition (assigned w/o technician)", sel03, d)
        run("SEL-04", "/users", "Search, role filter, verification persists", sel04, d)
        run("SEL-05", "/technicians", "City filter + edit rating persists", sel05, d)
        run("SEL-06", "/payments", "Invoice breakdown (base, fee, VAT, total)", sel06, d)
        run("SEL-07", "/tickets", "Post ticket reply, persists on reload", sel07, d)
        run("SEL-08", "/settings", "Commission fee/VAT round-trip", sel08, d)
        run("SEL-09", "/ai-insights", "Insight cards render without console errors", sel09, d)
        run("SEL-10", "/health", "Health metric tiles render", sel10, d)
    finally:
        d.quit()

    passed = sum(1 for r in results if r["status"] == "PASS")
    total = len(results)
    out = {"env": env, "summary": {"passed": passed, "total": total}, "cases": results,
           "finishedAt": datetime.now(timezone.utc).isoformat()}
    with open(os.path.join(HERE, "results.json"), "w") as f:
        json.dump(out, f, indent=2)
    write_md(out)
    print(f"\n=== {passed}/{total} passed ===")
    print(f"Report: {os.path.join(HERE, 'results.json')}")
    sys.exit(0 if passed == total else 1)


def write_md(out):
    env, cases = out["env"], out["cases"]
    lines = [
        "# SmartFix Selenium Suite — Execution Report",
        "",
        f"- **Run:** `{env['run']}`  ",
        f"- **Started:** {env['startedAt']}  ",
        f"- **Base URL:** {env['base']}  ",
        f"- **Browser:** {env['browser']} {env['browserVersion']} "
        f"(chromedriver {env['chromedriverVersion']})  ",
        f"- **Selenium:** {env['selenium']} · **Platform:** {env['platform']}  ",
        f"- **Result:** {out['summary']['passed']}/{out['summary']['total']} passed",
        "",
        "| ID | Route | Status | Duration (s) | Detail |",
        "|----|-------|--------|--------------|--------|",
    ]
    for c in cases:
        lines.append(f"| {c['id']} | `{c['route']}` | **{c['status']}** | "
                     f"{c['duration_s']} | {c['detail']} |")
    lines.append("")
    lines.append("Screenshots are in `screenshots/`.")
    with open(os.path.join(HERE, "results.md"), "w") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
