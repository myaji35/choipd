const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const baseUrl = process.env.BASE_URL || 'http://127.0.0.1:3008';
const start = process.env.START || '/education?type=online';
const widths = (process.env.WIDTHS ?? '1280,390,320').split(',').map(Number);
const outDir = path.resolve(root, process.env.OUT_DIR || 'tmp/qa/education-empty');
const expectedType = process.env.EXPECT_TYPE;
const inquiryPath = '/inquiries/new';

function readEmptyState() {
  const fallbackBackground = [10, 14, 26];
  const colorChannels = color => color.match(/[\d.]+/g).map(Number);
  const composite = ([red, green, blue, alpha = 1], background) =>
    [red, green, blue].map((channel, index) => channel * alpha + background[index] * (1 - alpha));

  function luminance(rgb) {
    const [red, green, blue] = rgb.map(value => {
      const channel = value / 255;
      return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
    });
    return red * 0.2126 + green * 0.7152 + blue * 0.0722;
  }

  function contrast(element) {
    if (!element) return null;

    const layers = [];
    for (let node = element; node; node = node.parentElement) {
      layers.push(colorChannels(getComputedStyle(node).backgroundColor));
      if (node === document.body) break;
    }
    const background = layers.reverse().reduce(
      (base, layer) => composite(layer, base), fallbackBackground
    );
    const foreground = composite(colorChannels(getComputedStyle(element).color), background);
    const [darker, lighter] = [luminance(foreground), luminance(background)].sort((a, b) => a - b);
    return (lighter + 0.05) / (darker + 0.05);
  }

  const emptyStates = document.querySelectorAll('.empty-state');
  const empty = emptyStates[0];
  const links = empty?.querySelectorAll('a.empty-state-cta');
  const cta = links?.[0];
  const [title, sub] = empty?.querySelectorAll('p') ?? [];
  const { scrollWidth, clientWidth } = document.documentElement;

  return {
    emptyCount: emptyStates.length,
    ctaCount: links?.length ?? 0,
    ctaHref: cta?.getAttribute('href') ?? null,
    ctaText: cta?.innerText.trim() ?? null,
    titleText: title?.innerText.trim() ?? null,
    contrast: { title: contrast(title), sub: contrast(sub), cta: contrast(cta) },
    ctaHeight: cta?.getBoundingClientRect().height ?? null,
    hScroll: scrollWidth > clientWidth,
    clipped: Array.from(empty?.querySelectorAll('*') ?? [])
      .filter(element => element.scrollWidth > element.clientWidth + 1).length,
  };
}

async function checkInquiry(page, width) {
  const [response] = await Promise.all([
    page.waitForResponse(candidate => {
      const request = candidate.request();
      return new URL(candidate.url()).pathname === inquiryPath
        && request.frame() === page.mainFrame()
        && (request.isNavigationRequest()
          || (request.resourceType() === 'fetch' && request.headers().accept?.includes('text/html')));
    }),
    page.locator('.empty-state a.empty-state-cta').click(),
  ]);
  await page.waitForURL(url => url.pathname === inquiryPath, { waitUntil: 'load' });
  const select = page.locator('form select[name="inquiry[inquiry_type]"]').first();
  await select.waitFor({ state: 'attached' }).catch(error => {
    if (error.name !== 'TimeoutError') throw error;
  });
  const formFound = (await select.count()) > 0;

  return {
    width,
    finalPath: new URL(page.url()).pathname,
    status: response.status(),
    formFound,
    typeSelected: formFound ? await select.inputValue() : null,
  };
}

async function main() {
  const result = { widths: [], clicks: [], consoleErrors: [], badResponses: [], errors: [] };
  let browser;
  let pass = true;

  try {
    if (widths.some(width => !Number.isSafeInteger(width) || width <= 0)) {
      throw new Error('WIDTHS must contain comma-separated positive integers');
    }

    const { chromium } = require(require.resolve('playwright', { paths: [__dirname] }));
    fs.mkdirSync(outDir, { recursive: true });
    browser = await chromium.launch({ headless: true });

    for (const width of widths) {
      const page = await browser.newPage({ viewport: { width, height: width >= 1024 ? 900 : 844 } });
      page.setDefaultTimeout(10000);
      page.on('console', message => {
        if (message.type() === 'error') result.consoleErrors.push({ width, text: message.text() });
      });
      page.on('pageerror', error => {
        result.consoleErrors.push({ width, text: `pageerror: ${error.message}` });
      });
      page.on('response', response => {
        const status = response.status();
        const url = response.url();
        if (status >= 400 && status < 600 && !/\/favicon(?:[./]|$)/i.test(new URL(url).pathname)) {
          result.badResponses.push({ width, status, url });
        }
      });

      try {
        await page.goto(new URL(start, baseUrl).href, { waitUntil: 'load' });
        await page.evaluate(() => document.fonts.ready.then(() => undefined));
        const { ctaText, titleText, contrast, ...state } = await page.evaluate(readEmptyState);
        const viewportResult = {
          width, ...state,
          contrast: Object.fromEntries(Object.entries(contrast).map(([name, ratio]) =>
            [name, ratio?.toFixed(2) ?? null])),
          screenshot: null,
        };
        result.widths.push(viewportResult);

        const hrefPath = state.ctaHref && new URL(state.ctaHref, page.url()).pathname;
        pass = state.emptyCount === 1 && state.ctaCount === 1
          && ctaText === '원하는 강좌 문의하기' && hrefPath === inquiryPath
          && /^등록된 강좌가 없습니다\.?$/.test(titleText)
          && Object.values(contrast).every(ratio => ratio >= 4.5)
          && state.ctaHeight >= 44 && !state.hScroll && state.clipped === 0 && pass;

        if (state.emptyCount > 0) {
          const file = path.join(outDir, `empty-${width}.png`);
          await page.locator('.empty-state').first().scrollIntoViewIfNeeded();
          await page.waitForTimeout(700);
          await page.screenshot({ path: file, fullPage: false });
          viewportResult.screenshot = path.relative(root, file);
        }

        if ((width === 1280 || width === 390) && state.emptyCount === 1 && state.ctaCount === 1) {
          const click = await checkInquiry(page, width);
          result.clicks.push(click);
          pass = click.finalPath === inquiryPath && click.status === 200 && click.formFound
            && (expectedType === undefined || click.typeSelected === expectedType) && pass;
        }
      } catch (error) {
        result.errors.push({ width, message: error.message });
      } finally {
        await page.close();
      }
    }
  } catch (error) {
    result.errors.push({ message: error.message });
  } finally {
    await browser?.close();
  }

  pass = pass && result.errors.length === 0
    && result.consoleErrors.length === 0 && result.badResponses.length === 0;
  console.log(JSON.stringify(result));
  console.log(`SUMMARY pass=${pass}`);
  if (!pass) process.exitCode = 1;
}

main().catch(error => {
  console.log(JSON.stringify({ error: error.message }));
  console.log('SUMMARY pass=false');
  process.exitCode = 1;
});
