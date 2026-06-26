#!/usr/bin/env node
// Headless render check: load each role's PWA URL on a phone-sized viewport,
// let Flutter boot + route past the splash, and screenshot it. Proves the
// no-login role entry lands on the right home instead of the login screen.
import puppeteer from 'puppeteer-core';

const BASE = process.argv[2] || 'http://localhost:8090';
const OUT = '/tmp';
const targets = [
  { role: 'customer', url: `${BASE}/?role=customer` },
  { role: 'technician', url: `${BASE}/?role=technician` },
  { role: 'none', url: `${BASE}/` },
];

const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome',
  headless: 'new',
  args: ['--no-sandbox', '--disable-setuid-sandbox'],
});

for (const t of targets) {
  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2, isMobile: true });
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  try {
    await page.goto(t.url, { waitUntil: 'networkidle2', timeout: 45000 });
  } catch (e) {
    console.log(`[${t.role}] goto warning: ${e.message}`);
  }
  // Flutter boot + 1.5s splash + route + paint.
  await new Promise((r) => setTimeout(r, 9000));
  const file = `${OUT}/pwa-${t.role}.png`;
  await page.screenshot({ path: file });
  const title = await page.title();
  console.log(`[${t.role}] ${t.url}`);
  console.log(`   title="${title}"  screenshot=${file}`);
  if (errors.length) console.log(`   console errors (first 3): ${errors.slice(0, 3).join(' | ')}`);
  await page.close();
}

await browser.close();
console.log('done');
