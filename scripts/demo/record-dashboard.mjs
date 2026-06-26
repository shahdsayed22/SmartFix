/* ============================================================
   SmartFix — Automated WHOLE-dashboard + AI demo recorder.
   Tours every admin page, and on the Issues page creates a real
   issue that fires the durable AI triage (auto-classify + match),
   filming it auto-assign live. Then the AI Insights research tour.
   Output: scripts/demo/out/demo.webm  (run-demo.sh muxes to .mp4)
   ============================================================ */
import puppeteer from 'puppeteer-core';
import { resolve } from 'node:path';

const BASE = process.env.DEMO_BASE || 'http://localhost:3000';
const OUT = resolve('scripts/demo/out/demo.webm');
const CHROME = process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/bin/google-chrome-stable';
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const TITLE = `DEMO — Burst pipe, kitchen flooding #${Date.now() % 100000}`;

async function caption(page, text, sub = '') {
  await page.evaluate((text, sub) => {
    let b = document.getElementById('__cap');
    if (!b) {
      b = document.createElement('div');
      b.id = '__cap';
      b.style.cssText =
        'position:fixed;left:50%;bottom:30px;transform:translateX(-50%);z-index:2147483647;' +
        'background:rgba(8,12,24,.94);color:#fff;padding:14px 26px;border-radius:14px;' +
        'font-family:Inter,system-ui,sans-serif;box-shadow:0 12px 40px rgba(0,0,0,.45);' +
        'border:1px solid rgba(255,255,255,.14);max-width:78vw;text-align:center;transition:opacity .35s';
      document.body.appendChild(b);
    }
    b.style.opacity = '1';
    b.innerHTML =
      `<div style="font-size:17px;font-weight:700;letter-spacing:-.2px">${text}</div>` +
      (sub ? `<div style="font-size:13px;font-weight:500;opacity:.7;margin-top:3px">${sub}</div>` : '');
  }, text, sub);
}
const hideCap = (page) => page.evaluate(() => { const b = document.getElementById('__cap'); if (b) b.style.opacity = '0'; });

async function smoothScroll(page, to, ms = 1400) {
  await page.evaluate(async (to, ms) => {
    const start = window.scrollY, dist = to - start, t0 = performance.now();
    await new Promise((res) => {
      function step(t) {
        const p = Math.min((t - t0) / ms, 1), e = 1 - Math.pow(1 - p, 3);
        window.scrollTo(0, start + dist * e);
        p < 1 ? requestAnimationFrame(step) : res();
      }
      requestAnimationFrame(step);
    });
  }, to, ms);
}

// generic page visit: navigate, caption, then slow-scroll through it
async function tour(page, path, title, sub, { scrolls = [500, 1000], hold = 2200 } = {}) {
  await hideCap(page);
  await page.goto(`${BASE}${path}`, { waitUntil: 'networkidle2' });
  await wait(1200);
  await caption(page, title, sub);
  await wait(hold);
  for (const y of scrolls) { await smoothScroll(page, y, 1300); await wait(1700); }
  await smoothScroll(page, 0, 900);
}

async function main() {
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: false,
    defaultViewport: { width: 1440, height: 900 },
    args: ['--window-size=1456,980', '--window-position=0,0', '--no-first-run', '--no-default-browser-check', '--disable-infobars', '--hide-scrollbars'],
  });
  const page = (await browser.pages())[0] || (await browser.newPage());
  page.setDefaultNavigationTimeout(60000);
  const recorder = await page.screencast({ path: OUT });
  console.log('● recording →', OUT);

  // ── 1. Dashboard overview ─────────────────────────────────
  await tour(page, '/', 'SmartFix — Admin Command Center', 'Real-time analytics across the whole platform', { scrolls: [420, 900], hold: 2600 });

  // ── 2. Issues + LIVE AI triage ────────────────────────────
  await hideCap(page);
  await page.goto(`${BASE}/issues`, { waitUntil: 'networkidle2' });
  await wait(1200);
  await caption(page, 'Issue queue — live from the mobile app', 'Search, filter, assign and resolve maintenance requests');
  await wait(2600);
  await caption(page, 'A customer reports an emergency', 'Plumbing · “Burst pipe, kitchen flooding”');
  const created = await page.evaluate(async (title) => {
    const res = await fetch('/api/issues', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title, description: 'Pipe burst under the kitchen sink, water flooding the floor — leaking fast.',
        category: 'plumbing', urgency: 'emergency', city: 'Cairo',
        customerName: 'Mariam Hassan', customerPhone: '+20 100 222 3344',
        customerEmail: 'mariam@demo.app', address: '15 El-Tahrir St, Dokki, Cairo',
      }),
    });
    return res.json();
  }, TITLE);
  console.log('● created issue', created?._id);
  const search = await page.$('input[placeholder^="Search title"]');
  if (search) { await search.click({ clickCount: 3 }); await search.type(TITLE, { delay: 16 }); }
  await wait(1500);
  await caption(page, 'Logged instantly — status “Pending”', 'No dispatcher has touched it yet');
  await wait(3200);
  await caption(page, 'Durable AI triage fires automatically…', 'Scores urgency + anomaly, then matches a technician');
  let tech = '';
  for (let i = 0; i < 24; i++) {
    const r = await page.evaluate(async (t) => {
      const it = ((await (await fetch('/api/issues?search=' + encodeURIComponent(t) + '&limit=1', { cache: 'no-store' })).json()).issues || [])[0] || {};
      return { status: it.status, tech: it.assignedTechnicianName || '' };
    }, TITLE);
    if (r.status === 'assigned' && r.tech) { tech = r.tech; break; }
    await wait(1500);
  }
  await wait(1400);
  await caption(page, 'AI auto-matched a verified technician' + (tech ? ` — ${tech}` : ''), 'Status → “Assigned”, fully automatic');
  await wait(4600);
  if (search) { await search.click({ clickCount: 3 }); await page.keyboard.press('Backspace'); }
  await wait(1200);

  // ── 3. Technicians ────────────────────────────────────────
  await tour(page, '/technicians', 'Technician workforce', '500 field technicians across Egypt — skills, ratings, verification', { scrolls: [480, 980], hold: 2400 });

  // ── 4. Users ──────────────────────────────────────────────
  await tour(page, '/users', 'Users', 'Customers and workers on the platform', { scrolls: [460], hold: 2200 });

  // ── 5. AI Insights (research showcase) ────────────────────
  await hideCap(page);
  await page.goto(`${BASE}/ai-insights`, { waitUntil: 'networkidle2' });
  await wait(1300);
  await caption(page, 'AI Insights — the research powering SmartFix', 'Anomaly-detection models · IMSA-2026 · 210 experiments');
  await wait(3000);
  await smoothScroll(page, 380, 1300); await wait(1500);
  await caption(page, 'Per-domain model performance', 'Best F1 0.967 on electrical-fault detection');
  await wait(2400);
  await smoothScroll(page, 760, 1300); await wait(1100);
  try { await page.select('select', 'NASA C-MAPSS'); await wait(2200); } catch {}
  await caption(page, 'Confusion matrix + ensemble ablation', 'Live, per-model — from the experiment output');
  try { await page.select('select', 'Water Leak'); await wait(2400); } catch {}
  await smoothScroll(page, 1250, 1500); await wait(1600);
  await caption(page, 'Per-domain leaderboard', '7 datasets · 3 models · 10-fold CV · all tests significant');
  await wait(2400);
  await smoothScroll(page, 2050, 1600); await wait(1400);
  await caption(page, 'Publication figures from the paper', '');
  await wait(1400);
  try { await page.click('img[alt="F1-Score Comparison"]'); await wait(3000); await page.keyboard.press('Escape'); await wait(1000); } catch {}

  // ── 6. Verified profiles ──────────────────────────────────
  await tour(page, '/verified', 'Verified profiles', 'Trust & verification workflow', { scrolls: [460], hold: 2200 });

  // ── 7. Ratings ────────────────────────────────────────────
  await tour(page, '/ratings', 'Ratings', 'Transparent quality scoring across the network', { scrolls: [460], hold: 2200 });

  // ── 8. System health (AI ops) ─────────────────────────────
  await tour(page, '/health', 'System health', 'Live infrastructure & AI-engine monitoring', { scrolls: [460, 920], hold: 2400 });

  await caption(page, 'SmartFix — AI-powered maintenance platform', 'Live dashboard · trained research models · mobile app');
  await wait(3200);
  await hideCap(page);
  await wait(700);

  await recorder.stop();
  console.log('■ recording saved');
  await browser.close();
}
main().catch((e) => { console.error('RECORDER FAILED:', e); process.exit(1); });
