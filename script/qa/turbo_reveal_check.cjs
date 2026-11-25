const fs = require('node:fs');
const path = require('node:path');

const root = fs.realpathSync(path.resolve(__dirname, '../..'));
const baseUrl = process.env.BASE_URL || 'http://127.0.0.1:3008';
const start = process.env.START || '/education';
const width = Number(process.env.WIDTH ?? '1280');
const outDir = process.env.OUT_DIR || path.resolve(root, 'tmp/qa/turbo-reveal');

async function clickFooterLink(page, pathname) {
  const exact = page.locator(`footer a[href="${pathname}"]`).first();
  const link = await exact.count() ? exact : page.locator(`footer a[href^="${pathname}"]`).first();
  await page.evaluate(() => {
    window.__qaTurboLoadPromise = new Promise(resolve => {
      document.addEventListener('turbo:load', () => resolve(location.pathname), { once: true });
    });
  });
  await Promise.all([
    page.waitForURL(url => url.pathname === pathname, { timeout: 10000 }),
    link.click({ timeout: 10000 }),
  ]);
  let timeout;
  try {
    const loadedPathname = await Promise.race([
      page.evaluate(() => window.__qaTurboLoadPromise),
      new Promise((_, reject) => {
        timeout = setTimeout(() => reject(new Error('turbo:load 대기 시간 초과')), 10000);
      }),
    ]);
    if (loadedPathname !== pathname) {
      throw new Error(`turbo:load 경로 불일치 (${loadedPathname} !== ${pathname})`);
    }
  } finally {
    clearTimeout(timeout);
  }
  await page.waitForTimeout(200);
}

async function main() {
  if (!Number.isSafeInteger(width) || width <= 0) {
    throw new Error('WIDTH 에 양의 정수 폭을 지정해야 합니다');
  }

  const { chromium } = require(require.resolve('playwright', { paths: [__dirname] }));
  fs.mkdirSync(outDir, { recursive: true });
  const outputDir = fs.realpathSync(outDir);
  const browser = await chromium.launch({ headless: true });
  const result = { start, width, consoleErrors: 0, consoleErrorItems: [], files: [] };

  try {
    const page = await browser.newPage({ viewport: { width, height: 844 } });
    page.on('console', message => {
      if (message.type() === 'error') result.consoleErrorItems.push(message.text());
    });
    page.on('pageerror', error => {
      result.consoleErrorItems.push(`pageerror: ${error.message}`);
    });
    await page.addInitScript(() => {
      window.__scrollListenerCount = 0;
      const addEventListener = window.addEventListener;
      window.addEventListener = function(type, ...args) {
        if (type === 'scroll') window.__scrollListenerCount++;
        return addEventListener.call(this, type, ...args);
      };
    });

    const startUrl = new URL(start, baseUrl);
    await page.goto(startUrl.href, { waitUntil: 'load' });
    result.initialScrollListenerCount = await page.evaluate(() => {
      window.__qaInitialDocument = document;
      return window.__scrollListenerCount;
    });

    await clickFooterLink(page, '/works');
    await page.evaluate(async () => {
      window.scrollTo({ top: 0, behavior: 'instant' });
      while (window.scrollY + window.innerHeight < document.scrollingElement.scrollHeight - 1) {
        window.scrollBy({ top: 400, behavior: 'instant' });
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    });
    try {
      await page.waitForFunction(() => {
        const renderedRevealElements = [...document.querySelectorAll('.reveal')].filter(el =>
          el.getClientRects().length > 0 && el.getBoundingClientRect().height > 0
        );
        return renderedRevealElements.every(el =>
          el.classList.contains('visible') && getComputedStyle(el).opacity === '1'
        );
      }, undefined, { timeout: 3000 });
    } catch (error) {
      if (error.name !== 'TimeoutError') throw error;
    }
    Object.assign(result, await page.evaluate(() => {
      const revealElements = [...document.querySelectorAll('.reveal')];
      const renderedRevealElements = revealElements.filter(el =>
        el.getClientRects().length > 0 && el.getBoundingClientRect().height > 0
      );
      return {
        revealTotal: renderedRevealElements.length,
        revealHidden: renderedRevealElements.filter(el => getComputedStyle(el).opacity === '0').length,
        revealNotVisibleClass: renderedRevealElements.filter(el => !el.classList.contains('visible')).length,
        revealSkippedHidden: revealElements.length - renderedRevealElements.length,
        worksScrollListenerCount: window.__scrollListenerCount,
        worksSameDocument: window.__qaInitialDocument === document,
      };
    }));

    const screenshot = path.join(outputDir, `works-${width}.png`);
    await page.screenshot({ path: screenshot, fullPage: true });
    result.files.push(path.relative(root, screenshot));

    const educationLink = page.locator('footer a[href="/education"]');
    const returnPath = await educationLink.count() ? '/education' : startUrl.pathname;
    await clickFooterLink(page, returnPath);
    Object.assign(result, await page.evaluate(() => ({
      scrollProgBound: window.__chopdScrollProgBound === true,
      scrollListenerCount: window.__scrollListenerCount,
      returnSameDocument: window.__qaInitialDocument === document,
    })));
    result.scrollListenerGrowth = result.scrollListenerCount - result.initialScrollListenerCount;
  } catch (error) {
    result.error = error.message;
  } finally {
    await browser.close();
  }

  result.consoleErrors = result.consoleErrorItems.length;
  const pass = !result.error && result.consoleErrors === 0 && result.revealTotal > 0
    && result.revealHidden === 0 && result.revealNotVisibleClass === 0
    && result.worksScrollListenerCount === result.initialScrollListenerCount
    && result.scrollListenerCount === result.initialScrollListenerCount
    && result.scrollProgBound && result.worksSameDocument && result.returnSameDocument;
  console.log(JSON.stringify(result));
  console.log(`SUMMARY pass=${pass}`);
  if (!pass) process.exitCode = 1;
}

main().catch(error => {
  console.log(JSON.stringify({ error: error.message, files: [] }));
  console.log('SUMMARY pass=false');
  process.exitCode = 1;
});
