/* Minimal static file server for Vampire City (no external deps). */
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.argv[2] || process.env.PORT || '5599', 10);
const ROOT = path.resolve(__dirname);
const PUBLIC_PREFIXES = ['/assets/', '/css/', '/js/'];
const PUBLIC_FILES = new Set(['/index.html', '/favicon.ico']);
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

function send(res, status, body, type = 'text/plain; charset=utf-8') {
  res.writeHead(status, { 'Content-Type': type, 'Cache-Control': 'no-cache' });
  res.end(body);
}

function isPublicPath(urlPath) {
  return PUBLIC_FILES.has(urlPath) || PUBLIC_PREFIXES.some((prefix) => urlPath.startsWith(prefix));
}

const server = http.createServer((req, res) => {
  try {
    let urlPath;
    try {
      urlPath = decodeURIComponent(req.url.split('?')[0]);
    } catch (e) {
      send(res, 400, 'Bad request');
      return;
    }
    if (urlPath === '/') urlPath = '/index.html';
    if (urlPath.includes('\0') || urlPath.includes('\\') || urlPath.split('/').includes('..') || !isPublicPath(urlPath)) {
      send(res, 403, 'Forbidden');
      return;
    }
    const filePath = path.resolve(ROOT, '.' + urlPath);
    const relPath = path.relative(ROOT, filePath);
    if (relPath === '' || relPath === '..' || relPath.startsWith('..' + path.sep) || path.isAbsolute(relPath)) { send(res, 403, 'Forbidden'); return; }
    fs.readFile(filePath, (err, data) => {
      if (err) { send(res, 404, 'Not found: ' + urlPath); return; }
      const ext = path.extname(filePath).toLowerCase();
      res.writeHead(200, { 'Content-Type': TYPES[ext] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
      res.end(data);
    });
  } catch (e) { send(res, 500, 'Error'); }
});

server.listen(PORT, () => console.log('Vampire City server running at http://localhost:' + PORT + '/'));
