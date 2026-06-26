#!/usr/bin/env node
// Quick headless screenshot: node scripts/shot.mjs <url> <out.png> [width] [waitMs] [full]
import puppeteer from 'puppeteer-core';
const [url, out, width = '390', waitMs = '2500', full = ''] = process.argv.slice(2);
const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome',
  headless: 'new',
  args: ['--no-sandbox', '--disable-setuid-sandbox'],
});
const page = await browser.newPage();
await page.setViewport({ width: +width, height: 900, deviceScaleFactor: 2, isMobile: +width < 700 });
try { await page.goto(url, { waitUntil: 'networkidle2', timeout: 40000 }); } catch (e) { console.log('goto:', e.message); }
await new Promise((r) => setTimeout(r, +waitMs));
await page.screenshot({ path: out, fullPage: full === 'full' });
console.log('saved', out, await page.title());
await browser.close();
