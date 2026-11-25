const assert = require('node:assert/strict');

const baseUrl = process.env.BASE_URL || 'http://127.0.0.1:3008';
const viewport = { width: 390, height: 844 };

async function clickAndCheck(page, expectedDisplay, expectedExpanded) {
  await page.locator('.nav-mobile-btn').click();
  const state = await page.evaluate(() => ({
    display: getComputedStyle(document.getElementById('mobile-nav')).display,
    expanded: document.querySelector('.nav-mobile-btn').getAttribute('aria-expanded'),
  }));
  assert.deepEqual(state, { display: expectedDisplay, expanded: expectedExpanded });
  return state;
}

async function main() {
  const result = { viewport, consoleErrorItems: [], pageErrorItems: [] };
  let browser;

  try {
    const { chromium } = require(require.resolve('playwright', { paths: [__dirname] }));
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({ viewport });
    page.setDefaultTimeout(10000);
    page.on('console', message => {
      if (message.type() === 'error') result.consoleErrorItems.push(message.text());
    });
    page.on('pageerror', error => {
      result.pageErrorItems.push(error.message);
    });

    await page.goto(new URL('/education', baseUrl).href, { waitUntil: 'load' });
    result.educationOpen = await clickAndCheck(page, 'flex', 'true');
    result.educationClosed = await clickAndCheck(page, 'none', 'false');

    await page.evaluate(() => {
      window.__qaMobileMenuInitialDocument = document;
      document.addEventListener('turbo:load', () => {
        window.__qaMobileMenuLoadedPath = location.pathname;
      }, { once: true });
      window.Turbo.visit('/works');
    });
    await page.waitForURL(url => url.pathname === '/works', { timeout: 10000 });
    result.worksSameDocument = await page.evaluate(() =>
      window.__qaMobileMenuInitialDocument === document
    );
    assert.equal(result.worksSameDocument, true, 'Turbo visit replaced the document');
    await page.waitForFunction(() => window.__qaMobileMenuLoadedPath === '/works');
    result.worksOpen = await clickAndCheck(page, 'flex', 'true');
  } catch (error) {
    result.error = error.message;
  } finally {
    await browser?.close();
  }

  result.consoleErrors = result.consoleErrorItems.length;
  result.pageErrors = result.pageErrorItems.length;
  const pass = !result.error && result.consoleErrors === 0 && result.pageErrors === 0;
  console.log(JSON.stringify(result));
  console.log(`SUMMARY pass=${pass}`);
  if (!pass) process.exitCode = 1;
}

main().catch(error => {
  console.log(JSON.stringify({ error: error.message }));
  console.log('SUMMARY pass=false');
  process.exitCode = 1;
});
