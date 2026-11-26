const fs = require('node:fs');
const path = require('node:path');

function measure() {
  const box = selector => document.querySelector(selector)?.getBoundingClientRect();
  const visible = element => element.getClientRects().length && getComputedStyle(element).visibility === 'visible';
  const textElements = [...document.querySelectorAll('body *')].filter(element =>
    !element.matches('script, style, i') && visible(element) &&
    [...element.childNodes].some(node => node.nodeType === Node.TEXT_NODE && node.textContent.trim())
  );
  const family = value => value.split(',')[0].replaceAll(/["']/g, '');
  const resources = performance.getEntriesByType('resource');
  const fontResources = resources.filter(entry => /\/fonts\/.*\.woff2(?:\?|$)/.test(entry.name));
  const h1 = document.querySelector('h1');
  const viewport = document.documentElement;
  const home = !!document.querySelector('.impd-home');
  const elements = [...document.querySelectorAll('a[href], button, summary')].filter(visible);
  const cssColor = value => {
    if (!/^rgba?\(/.test(value)) return null;
    const [r, g, b, a = 1] = value.match(/[\d.]+/g).map(Number);
    return [r, g, b, a];
  };
  const composite = (front, back) => front.slice(0, 3).map((channel, index) =>
    channel * front[3] + back[index] * (1 - front[3])
  );
  const luminance = color => color.reduce((sum, channel, index) => {
    const c = channel / 255;
    return sum + [0.2126, 0.7152, 0.0722][index] * (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
  }, 0);
  const contrast = element => {
    const style = getComputedStyle(element);
    const color = cssColor(style.color);
    if (!color) return null;
    const layers = [];
    for (let parent = element; parent; parent = parent.parentElement) {
      const parentStyle = getComputedStyle(parent);
      if (parentStyle.backgroundImage !== 'none') return null;
      const layer = cssColor(parentStyle.backgroundColor);
      if (layer?.[3]) layers.push(layer);
      if (layer?.[3] === 1) break;
    }
    const background = layers.reduceRight((back, layer) => composite(layer, back), [255, 255, 255]);
    const a = luminance(composite(color, background));
    const b = luminance(background);
    const ratio = (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
    const size = parseFloat(style.fontSize);
    const minimum = size >= 24 || (size >= 18.66 && Number(style.fontWeight) >= 700) ? 3 : 4.5;
    return { ratio: Number(ratio.toFixed(2)), minimum, text: element.textContent.trim().slice(0, 110) };
  };
  const contrasts = home ? textElements.map(contrast).filter(Boolean) : [];
  return {
    overflowX: viewport.scrollWidth > viewport.clientWidth,
    width: viewport.clientWidth,
    h: viewport.scrollHeight,
    fonts: [...new Set(textElements.map(element => family(getComputedStyle(element).fontFamily)))].sort(),
    loadedFonts: [...new Set([...document.fonts].filter(font => font.status === 'loaded').map(font => family(font.family)))].sort(),
    fontBytes: fontResources.reduce((sum, entry) => sum + entry.transferSize, 0),
    fontFiles: fontResources.length,
    externalFontRequests: resources.map(entry => entry.name).filter(url => /\/\/(fonts\.googleapis\.com|fonts\.gstatic\.com|cdn\.jsdelivr\.net)\//.test(url)),
    ...(home && {
      headline: h1?.innerText,
      headlineCount: document.querySelectorAll('h1').length,
      headlineFits: h1?.scrollWidth <= h1?.clientWidth,
      headlineLines: Math.round(h1.offsetHeight / parseFloat(getComputedStyle(h1).lineHeight)),
      nextHeadingTop: box('#how h2')?.top,
      primaryBottom: box('.impd-hero-actions .impd-btn-primary')?.bottom,
      heroActions: document.querySelectorAll('.impd-hero-actions a').length,
      visibleSignupActions: elements.filter(element => {
        const rect = element.getBoundingClientRect();
        return rect.top >= 0 && rect.bottom <= innerHeight && element.textContent.trim() === '내 페이지 만들기';
      }).length,
      leftEdgeDifference: box('.impd-topnav-bar > a')?.left - box('#home-title')?.left,
      rightEdgeDifference: (box('.impd-topnav-actions a:last-child')?.width ? box('.impd-topnav-actions a:last-child') : box('.impd-nav-toggle'))?.right -
        (box('#how .impd-home-grid')?.right),
      smallTargets: elements.filter(element => !element.closest('p') && element.getBoundingClientRect().height < 44)
        .map(element => ({ text: element.textContent.trim(), height: element.getBoundingClientRect().height })),
      lowContrast: contrasts.filter(result => result.ratio < result.minimum),
      minimumTextContrast: Math.min(...contrasts.filter(result => result.minimum === 4.5).map(result => result.ratio)),
    }),
  };
}

const pages = [['home', '/'], ['explore', '/explore'], ['profile', '/kang-seung-sig'], ['signup', '/auth/signup']];
const sizes = [[1440, 900, 'd'], [390, 844, 'm']];

async function main() {
  const { chromium } = require('playwright');
  const [base, outDir] = process.argv.slice(2);
  if (!base || !outDir) throw new Error('Usage: node design_shots.cjs BASE_URL OUTPUT_DIR');
  fs.mkdirSync(outDir, { recursive: true });
  const report = [];
  const browser = await chromium.launch();
  try {
    const checks = sizes.flatMap(([width, height, t]) => pages.map(([n, url]) => ({ width, height, t, n, url })));
    checks.push({ width: 320, height: 844, t: '320', n: 'home', url: '/' });
    for (const { width, height, t, n, url } of checks) {
      const context = await browser.newContext({ viewport: { width, height }, locale: 'ko-KR' });
      try {
        const page = await context.newPage();
        const err = [];
        const externalRequests = new Set();
        page.on('console', message => { if (message.type() === 'error') err.push(message.text()); });
        page.on('pageerror', error => err.push(error.message));
        page.on('request', request => {
          if (/\/(fonts\.googleapis\.com|fonts\.gstatic\.com|cdn\.jsdelivr\.net)\//.test(request.url())) {
            externalRequests.add(request.url());
          }
        });
        const response = await page.goto(new URL(url, base).href, { waitUntil: 'domcontentloaded' });
        await page.evaluate(() => document.fonts.ready.then(() => true));
        await page.waitForTimeout(650);
        const metrics = await page.evaluate(measure);
        for (const [suffix, fullPage] of [['-fold', false], ['', true]]) {
          await page.screenshot({ path: path.join(outDir, `${n}-${t}${suffix}.png`), fullPage });
        }
        report.push({ n, t, status: response.status(), ...metrics, externalFontRequests: [...externalRequests], err });
      } finally {
        await context.close();
      }
    }
  } finally {
    await browser.close();
    fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify(report, null, 2) + '\n');
  }
  console.log(JSON.stringify(report.map(row => [row.n + '-' + row.t, row.status, row.overflowX, row.fontBytes, row.err.length])));
}

module.exports = { measure, pages, sizes };
if (require.main === module) main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
