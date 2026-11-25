const fs = require('node:fs');
const path = require('node:path');

const root = fs.realpathSync(path.resolve(__dirname, '../..'));
const baseUrl = process.env.BASE_URL || 'http://127.0.0.1:3008';
const outDir = process.env.OUT_DIR || path.resolve(__dirname, '../../qa/ISS-508');
const routes = [{ name: 'home', path: '/' }, { name: 'inquiries-new', path: '/inquiries/new' }];
const viewports = [{ width: 1280, height: 900 }, { width: 390, height: 844 }];

async function main() {
  const { chromium } = require(require.resolve('playwright', { paths: [__dirname] }));
  fs.mkdirSync(outDir, { recursive: true });
  const outputDir = fs.realpathSync(outDir);
  const browser = await chromium.launch({ headless: true });
  let pass = true;
  try {
    for (const route of routes) {
      for (const viewport of viewports) {
        const page = await browser.newPage({ viewport });
        const url = new URL(route.path, baseUrl).href;
        try {
          await page.goto(url, { waitUntil: 'networkidle' });
        } catch {
          await page.goto(url, { waitUntil: 'load' });
        }
        await page.waitForTimeout(500);
        const file = path.resolve(outputDir, `${route.name}-${viewport.width}.png`);
        await page.screenshot({ path: file, fullPage: true });
        const result = await page.evaluate(() => {
          const { scrollWidth, clientWidth } = document.documentElement;
          const elements = document.querySelectorAll('a.impd-btn, button, input[type=submit], input:not([type=hidden]), select, textarea');
          const clippedItems = [];
          let checked = 0;
          for (const el of elements) {
            const rect = el.getBoundingClientRect();
            const { visibility, display } = getComputedStyle(el);
            if (rect.width <= 0 || rect.height <= 0 || visibility === 'hidden' || display === 'none' || !el.getClientRects().length) continue;
            checked += 1;
            // 문서 좌표에서 좌우 경계를 비교한다.
            const left = rect.left + window.scrollX;
            const right = rect.right + window.scrollX;
            if (left < -0.5 || right > clientWidth + 0.5) {
              const text = (el.value || el.innerText || el.name || '').slice(0, 30);
              clippedItems.push({ tag: el.localName, text, left, right });
            }
          }
          const footerWrappedItems = [];
          for (const el of document.querySelectorAll('footer a')) {
            const { visibility, display } = getComputedStyle(el);
            if (visibility === 'hidden' || display === 'none') continue;
            const range = document.createRange();
            range.selectNodeContents(el);
            const lineTops = new Set();
            for (const rect of range.getClientRects()) {
              if (rect.width > 0) lineTops.add(Math.round(rect.top));
            }
            const lines = lineTops.size;
            if (lines > 1) {
              footerWrappedItems.push({ text: el.innerText.slice(0, 20), lines });
            }
          }
          return {
            scrollWidth, clientWidth, hScroll: scrollWidth > clientWidth, checked, clipped: clippedItems.length, clippedItems,
            footerWrapped: footerWrappedItems.length, footerWrappedItems,
          };
        });
        console.log(JSON.stringify({
          route: route.path, width: viewport.width, file: path.relative(root, fs.realpathSync(file)), bytes: fs.statSync(file).size, ...result,
        }));
        pass = pass && !result.hScroll && result.clipped === 0 && result.footerWrapped === 0;
        await page.close();
      }
    }
  } finally {
    await browser.close();
  }
  console.log(`SUMMARY pass=${pass}`);
  process.exitCode = pass ? 0 : 1;
}

main().catch(error => {
  console.error(error.message);
  console.log('SUMMARY pass=false');
  process.exitCode = 2;
});
