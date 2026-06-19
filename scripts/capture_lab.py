#!/usr/bin/env python3
from pathlib import Path
import argparse
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
HTML = (ROOT / 'visual-lab/index.html').read_text()
CSS = (ROOT / 'visual-lab/lab.css').read_text()
JS = (ROOT / 'visual-lab/lab.js').read_text()

def document(query: str) -> str:
    base = HTML.replace('<link rel="stylesheet" href="lab.css">', f'<style>{CSS}</style>')
    base = base.replace('<script src="lab.js"></script>', f'<script>window.__CAPTURE_QUERY__={query!r};</script><script>{JS}</script>')
    return base

def capture(screen: str, pass_no: int, out: Path, width=1600, height=900):
    q = f'?screen={screen}&pass={pass_no}&capture=1&t=18.4'
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, executable_path='/usr/bin/chromium', args=[
            '--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu', '--font-render-hinting=none'
        ])
        page = browser.new_page(viewport={'width': width, 'height': height}, device_scale_factor=1)
        page.set_content(document(q), wait_until='load', timeout=30000)
        page.wait_for_function('window.__NOCTURNE_READY__ === true', timeout=30000)
        page.screenshot(path=str(out))
        browser.close()

if __name__ == '__main__':
    ap=argparse.ArgumentParser()
    ap.add_argument('--screen', default='gameplay')
    ap.add_argument('--pass-no', type=int, default=3)
    ap.add_argument('--out', required=True)
    args=ap.parse_args()
    out=Path(args.out);out.parent.mkdir(parents=True,exist_ok=True)
    capture(args.screen,args.pass_no,out)
