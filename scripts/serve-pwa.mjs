// Minimal static server for the built Flutter Web PWA (build/web) on a port.
// Usage: node scripts/serve-pwa.mjs [root] [port]
import http from 'http';
import { readFile, stat } from 'fs/promises';
import { join, normalize, extname, resolve } from 'path';

const ROOT = resolve(process.argv[2] || 'build/web');
const PORT = Number(process.argv[3] || 8090);
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif',
  '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.wasm': 'application/wasm',
  '.woff2': 'font/woff2', '.woff': 'font/woff', '.ttf': 'font/ttf', '.otf': 'font/otf',
  '.map': 'application/json', '.bin': 'application/octet-stream', '.txt': 'text/plain',
};

const server = http.createServer(async (req, res) => {
  try {
    let p = decodeURIComponent((req.url || '/').split('?')[0]);
    if (p === '/' || p === '') p = '/index.html';
    let fp = normalize(join(ROOT, p));
    if (!fp.startsWith(ROOT)) { res.writeHead(403); return res.end('forbidden'); }
    let s = null;
    try { s = await stat(fp); } catch { fp = join(ROOT, 'index.html'); }
    if (s && s.isDirectory()) fp = join(fp, 'index.html');
    const data = await readFile(fp);
    res.writeHead(200, {
      'Content-Type': MIME[extname(fp).toLowerCase()] || 'application/octet-stream',
      'Service-Worker-Allowed': '/',
      'Cache-Control': 'no-cache',
    });
    res.end(data);
  } catch (e) {
    try { const idx = await readFile(join(ROOT, 'index.html')); res.writeHead(200, { 'Content-Type': 'text/html' }); res.end(idx); }
    catch { res.writeHead(404); res.end('not found'); }
  }
});
server.listen(PORT, () => console.log(`PWA serving ${ROOT} on http://localhost:${PORT}`));
