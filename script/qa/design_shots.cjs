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
  const explore = !!document.querySelector('.explore-wrap');
  const contrasts = home || explore ? textElements.map(contrast).filter(Boolean) : [];
  const cards = [...document.querySelectorAll('.impd-flow-card:not([data-copy])')];
  const shown = selector => [...document.querySelectorAll(selector)].filter(visible);
  const flowTrack = document.querySelector('.impd-flow-track');
  const resourceTotals = {};
  for (const { name, initiatorType, transferSize } of resources) {
    const type = /\.woff2/.test(name) ? 'font' : /\.js(?:\?|$)/.test(name) ? 'js' :
      /\.css(?:\?|$)/.test(name) ? 'css' : initiatorType;
    const total = resourceTotals[type] ||= { count: 0, bytes: 0 };
    total.count += 1;
    total.bytes += transferSize;
  }
  return {
    resources: resourceTotals,
    cls: window.designShotCLS,
    heroFlowCards: cards.length,
    heroFlowUniqueMembers: new Set(cards.map(card => card.getAttribute('href'))).size,
    visibleFlowCards: cards.filter(visible).length,
    peopleCards: document.querySelectorAll('#people .impd-member-grid > a').length,
    momentsPhotos: shown('#moments .impd-moment img').length,
    photoSizes: shown('#moments .impd-moment').map(el => [el.offsetWidth, el.offsetHeight]),
    newsItems: document.querySelectorAll('.impd-news li').length,
    heroCount: Number(document.querySelector('.impd-hero-fact .impd-count-up')?.textContent) || null,
    exploreCards: document.querySelectorAll('.explore-grid .impd-member-card').length,
    exploreChips: shown('.explore-filter-row:first-child .explore-chip').map(el => el.textContent.trim().replace(/\s+/g, ' ')),
    flowTransform: flowTrack && getComputedStyle(flowTrack).transform,
    copyLinksFocusable: [...document.querySelectorAll('.impd-flow [data-copy]')].filter(el => !el.inert || el.tabIndex !== -1).length,
    pauseHeight: shown('.impd-flow-pause')[0]?.getBoundingClientRect().height,
    fontsInContent: [...new Set(textElements.filter(el => el.closest('.impd-home, .explore-wrap') && !el.closest('.hero-phone'))
      .map(el => parseFloat(getComputedStyle(el).fontSize)))].sort((a, b) => a - b),
    buttonHeights: shown('.impd-hero-actions a, #close .impd-btn').map(el => el.offsetHeight),
    chipHeights: [...new Set(shown('.impd-profession-pill, .explore-chip').map(el => el.offsetHeight))],
    animations: document.getAnimations().map(animation => ({
      target: animation.effect.target.className,
      name: animation.animationName,
      running: animation.playState === 'running',
      infinite: animation.effect.getTiming().iterations === Infinity
    })),
    ...(explore && {
      lowContrast: contrasts.filter(result => result.ratio < result.minimum),
      leftEdgeDifference: box('.impd-topnav-bar > a')?.left - box('.explore-title')?.left,
      rightEdgeDifference: (box('.impd-topnav-actions a:last-child')?.width ? box('.impd-topnav-actions a:last-child') : box('.impd-nav-toggle'))?.right - box('.explore-grid')?.right,
    }),
    overflowX: viewport.scrollWidth > viewport.clientWidth,
    width: viewport.clientWidth,
    h: viewport.scrollHeight,
    fonts: [...new Set(textElements.map(element => family(getComputedStyle(element).fontFamily)))].sort(),
    loadedFonts: [...new Set([...document.fonts].filter(font => font.status === 'loaded').map(font => family(font.family)))].sort(),
    fontBytes: fontResources.reduce((sum, entry) => sum + entry.transferSize, 0),
    fontFiles: fontResources.length,
    externalFontRequests: resources.map(entry => entry.name).filter(url => /\/\/(fonts\.googleapis\.com|fonts\.gstatic\.com|cdn\.jsdelivr\.net)\//.test(url)),
    ...(home && {
      headline: h1?.innerText.replace(/\s+/g, " ").trim(),
      headlineCount: document.querySelectorAll('h1').length,
      headlineFits: h1?.scrollWidth <= h1?.clientWidth,
      headlineLines: Math.round(h1.offsetHeight / parseFloat(getComputedStyle(h1).lineHeight)),
      nextHeadingTop: box('#people h2')?.top,
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

async function checkPause(page) {
  const button = page.locator('.impd-flow-pause');
  const track = page.locator('.impd-flow-track').first();
  if (!(await button.isVisible()) || !(await track.count())) return null;

  const transform = () => track.evaluate(element => getComputedStyle(element).transform);
  const sample = async () => {
    await page.waitForTimeout(50);
    const first = await transform();
    await page.waitForTimeout(500);
    return first === await transform();
  };
  const port = page.locator('.impd-flow-window');
  await port.hover({ position: { x: 40, y: 60 } });
  const hoverStopped = await sample();
  await page.mouse.move(0, 0);
  const focused = track.locator('.impd-flow-card:not([data-copy])').first();
  await focused.focus();
  const focusStopped = await sample();
  const focusRing = await focused.evaluate(element => getComputedStyle(element).outlineStyle);
  await button.click();
  const pressed = await button.getAttribute('aria-pressed');
  const text = (await button.innerText()).trim();
  const stopped = await sample();
  await page.reload({ waitUntil: 'domcontentloaded' });
  await button.waitFor({ state: 'visible' });
  const persisted = await button.getAttribute('aria-pressed');
  await button.click();
  const resumed = !(await sample());
  return { pressed, text, stopped, persisted, resumed, hoverStopped, focusStopped, focusRing };
}

async function checkFrames(context, page) {
  const cdp = await context.newCDPSession(page);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 });
  try {
    return await page.evaluate(() => new Promise(resolve => {
      const start = performance.now();
      let previous = start;
      let total = 0;
      let long = 0;
      function sample(now) {
        if (now - previous > 50) long += 1;
        previous = now;
        total += 1;
        if (now - start < 5000) requestAnimationFrame(sample);
        else resolve({ total, long, ratio: long / total });
      }
      requestAnimationFrame(sample);
    }));
  } finally {
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
    await cdp.detach();
  }
}

async function main() {
  const { chromium } = require('playwright');
  const [base, outDir] = process.argv.slice(2);
  if (!base || !outDir) throw new Error('Usage: node design_shots.cjs BASE_URL OUTPUT_DIR');
  fs.mkdirSync(outDir, { recursive: true });
  const report = [];
  const controllerBytes = ['member_flow', 'count_up'].reduce((sum, name) => {
    const file = path.join(__dirname, '../../app/javascript/controllers', `${name}_controller.js`);
    return sum + (fs.existsSync(file) ? fs.statSync(file).size : 0);
  }, 0);
  const browser = await chromium.launch();
  try {
    const checks = sizes.flatMap(([width, height, t]) => pages.map(([n, url]) => ({ width, height, t, n, url })));
    checks.push(...pages.slice(0, 2).map(([n, url]) => ({ width: 320, height: 844, t: '320', n, url })));
    checks.push(...sizes.map(([width, height, t]) => ({ width, height, t, n: 'home', url: '/', reducedMotion: 'reduce' })));
    for (const { width, height, t, n, url, reducedMotion } of checks) {
      const context = await browser.newContext({ viewport: { width, height }, locale: 'ko-KR', reducedMotion });
      try {
        await context.addInitScript(() => {
          window.designShotCLS = 0;
          new PerformanceObserver(list => {
            for (const entry of list.getEntries()) {
              if (!entry.hadRecentInput) window.designShotCLS += entry.value;
            }
          }).observe({ type: 'layout-shift', buffered: true });
        });
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
        const start = Date.now();
        await page.evaluate(() => document.fonts.ready.then(() => true));
        await page.waitForTimeout(Math.max(0, 900 - (Date.now() - start)));
        const metrics = await page.evaluate(measure);
        const prefix = `${n}-${t}`;
        const shot = (suffix, fullPage = false) =>
          page.screenshot({ path: path.join(outDir, `${prefix}${suffix}.png`), fullPage });
        await shot(reducedMotion ? '-fold-rm' : '-fold');
        let second;
        if (n === 'home' && t !== '320') {
          await page.waitForTimeout(Math.max(0, 4900 - (Date.now() - start)));
          const close = page.locator('.promo-popup-close').first();
          if (await close.isVisible()) await close.click();
          await shot(reducedMotion ? '-fold-rm-t2' : '-fold-t2');
          second = await page.evaluate(measure);
        }
        if (!reducedMotion) {
          await page.addStyleTag({ content: '.impd-home-section, .impd-home-footer { content-visibility: visible !important; }' });
          await page.evaluate(() => document.fonts.ready);
          await shot('', true);
        }
        const pause = n === 'home' && !reducedMotion ? await checkPause(page) : null;
        const frames = t === 'm' && pause ? await checkFrames(context, page) : null;
        report.push({ n, t, reducedMotion, status: response.status(), ...metrics, second, pause, frames, controllerBytes, externalFontRequests: [...externalRequests], err });
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
