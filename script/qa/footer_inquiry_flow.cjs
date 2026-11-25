const fs = require('node:fs');
const path = require('node:path');

const root = fs.realpathSync(path.resolve(__dirname, '../..'));
const baseUrl = process.env.BASE_URL || 'http://127.0.0.1:3008';
const start = process.env.START || '/education';
const width = Number(process.env.WIDTH ?? '390');
const outDir = process.env.OUT_DIR || path.resolve(__dirname, '../../tmp/qa/flow');

async function main() {
  if (!Number.isSafeInteger(width) || width <= 0) {
    throw new Error('WIDTH 에 양의 정수 폭을 지정해야 합니다');
  }

  const { chromium } = require(require.resolve('playwright', { paths: [__dirname] }));
  const baseOrigin = new URL(baseUrl).origin;
  fs.mkdirSync(outDir, { recursive: true });
  const outputDir = fs.realpathSync(outDir);
  const browser = await chromium.launch({ headless: true });
  let result;
  try {
    const page = await browser.newPage({ viewport: { width, height: 844 } });
    const consoleErrorItems = [];
    const badResponseItems = [];
    const files = [];
    let status = null;
    let navigation = null;
    page.on('console', message => {
      if (message.type() === 'error') consoleErrorItems.push(message.text().slice(0, 200));
    });
    page.on('pageerror', error => {
      consoleErrorItems.push(`pageerror: ${error.message}`.slice(0, 200));
    });
    page.on('response', response => {
      const responseStatus = response.status();
      const url = new URL(response.url());
      if (responseStatus >= 400 && responseStatus < 600 && url.origin === baseOrigin) {
        badResponseItems.push({ status: responseStatus, url: response.url() });
      }
      const request = response.request();
      const resourceType = request.resourceType();
      if (url.pathname === '/inquiries/new' && request.method() === 'GET'
        && (resourceType === 'document' || resourceType === 'fetch')
        && request.frame() === page.mainFrame()) {
        status = responseStatus;
        navigation = resourceType;
      }
    });

    await page.goto(new URL(start, baseUrl).href, { waitUntil: 'load' });
    status = null;
    navigation = null;
    const link = page.locator('footer a[href="/inquiries/new"]').filter({ hasText: /^B2B\/B2G 문의하기$/ }).first();
    const linkFound = (await link.count()) > 0;
    const linkVisible = linkFound && await link.isVisible();
    let linkLines = null;
    let formFound = false;
    if (linkVisible) {
      linkLines = await link.evaluate(el => {
        const range = document.createRange();
        range.selectNodeContents(el);
        const lineTops = new Set();
        for (const rect of range.getClientRects()) {
          if (rect.width > 0) lineTops.add(Math.round(rect.top));
        }
        return lineTops.size;
      });

      await link.scrollIntoViewIfNeeded();
      const footerFile = path.resolve(outputDir, `footer-${width}.png`);
      await page.screenshot({ path: footerFile });
      files.push(path.relative(root, fs.realpathSync(footerFile)));
      try {
        await Promise.all([
          page.waitForResponse(response => {
            const request = response.request();
            const resourceType = request.resourceType();
            return new URL(response.url()).pathname === '/inquiries/new'
              && request.method() === 'GET'
              && (resourceType === 'document' || resourceType === 'fetch')
              && request.frame() === page.mainFrame();
          }, { timeout: 10000 }),
          link.click(),
        ]);
      } catch {
        // Continue collecting the result if the click or response wait fails.
      }
      try {
        await page.waitForURL('**/inquiries/new', { timeout: 5000 });
      } catch {
        // The final path is recorded below even if navigation fails.
      }
      try {
        await page.locator('form[action$="/inquiries"]').first().waitFor({ state: 'visible', timeout: 10000 });
        formFound = true;
      } catch (error) {
        if (error.name !== 'TimeoutError') throw error;
      }
    }

    const finalPath = new URL(page.url()).pathname;
    if (linkVisible) {
      const formFile = path.resolve(outputDir, `inquiry-form-${width}.png`);
      await page.screenshot({ path: formFile, fullPage: true });
      files.push(path.relative(root, fs.realpathSync(formFile)));
    }

    result = {
      start, width, linkFound, linkVisible, linkLines, finalPath, status, navigation, formFound,
      consoleErrors: consoleErrorItems.length, consoleErrorItems,
      badResponses: badResponseItems.length, badResponseItems, files,
    };
  } finally {
    await browser.close();
  }

  const pass = result.linkFound && result.linkVisible && result.linkLines === 1
    && result.finalPath === '/inquiries/new' && result.status === 200 && result.formFound
    && result.consoleErrors === 0 && result.badResponses === 0;
  console.log(JSON.stringify(result));
  console.log(`SUMMARY pass=${pass}`);
  process.exitCode = pass ? 0 : 1;
}

main().catch(error => {
  console.error(error.message);
  console.log('SUMMARY pass=false');
  process.exitCode = 2;
});
