#!/usr/bin/env node
// Minimal zero-dependency static server for the Flutter Web (PWA) build.
// Serves correct MIME types (incl. .wasm for CanvasKit), binds 0.0.0.0 so a
// phone on the LAN can reach it, and falls back to index.html (SPA routing).
//
//   node scripts/serve-web.mjs <dir> <port>
//   node scripts/serve-web.mjs build/web 8080
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] || 'build/web');
const port = Number(process.argv[3] || 8080);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.webmanifest': 'application/manifest+json',
  '.map': 'application/json',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.bin': 'application/octet-stream',
  '.symbols': 'text/plain',
};

const sendFile = (res, fp, status = 200) => {
  fs.readFile(fp, (err, buf) => {
    if (err) {
      res.writeHead(404, { 'content-type': 'text/plain' });
      return res.end('404 not found');
    }
    res.writeHead(status, {
      'content-type': MIME[path.extname(fp).toLowerCase()] || 'application/octet-stream',
      'cache-control': 'no-cache',
      // Allow the page to call the Next API on a different port if ever needed.
      'access-control-allow-origin': '*',
    });
    res.end(buf);
  });
};

http
  .createServer((req, res) => {
    let pathname = '/';
    try {
      pathname = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    } catch {
      /* malformed URL → treat as root */
    }
    if (pathname.endsWith('/')) pathname += 'index.html';
    const fp = path.join(root, pathname);
    // Block path traversal outside the build dir.
    if (!fp.startsWith(root)) {
      res.writeHead(403, { 'content-type': 'text/plain' });
      return res.end('403');
    }
    fs.stat(fp, (err, st) => {
      if (err || !st.isFile()) {
        // SPA fallback: unknown path → index.html
        return sendFile(res, path.join(root, 'index.html'));
      }
      sendFile(res, fp);
    });
  })
  .listen(port, '0.0.0.0', () => {
    console.log(`[serve-web] serving ${root} on http://0.0.0.0:${port}`);
  });
