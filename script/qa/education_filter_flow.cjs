const assert = require('node:assert/strict');

const baseUrl = process.env.BASE_URL || 'http://127.0.0.1:3008';
const viewport = { width: 390, height: 844 };

async function readEducation(page) {
  const buttons = page.locator('.filter-bar a.filter-pill:visible');
  return {
    selectedTexts: (await page.locator('.filter-bar a[aria-current="page"]').allTextContents())
      .map(text => text.trim()),
    courseCount: await page.locator('.course-card').count(),
    buttons: await buttons.evaluateAll(links => links.map(link => {
      const { top, height, left, right } = link.getBoundingClientRect();
      const range = document.createRange();
      range.selectNodeContents(link);
      const lineTops = [];
      for (const rect of range.getClientRects()) {
        if (!lineTops.some(top => Math.abs(top - rect.top) <= 1)) {
          lineTops.push(rect.top);
        }
      }
      return {
        text: link.textContent.trim(),
        top,
        height,
        left,
        right,
        lineHeight: parseFloat(getComputedStyle(link).lineHeight),
        textLines: lineTops.length,
      };
    })),
  };
}

async function checkOnline(page, educationUrl, expectedOnlineCount, details) {
  await page.evaluate(() => {
    window.__qaEducationLoaded = false;
    document.addEventListener('turbo:load', () => {
      window.__qaEducationLoaded = true;
    }, { once: true });
  });

  const isOnlineUrl = url =>
    url.pathname === educationUrl.pathname && url.searchParams.get('type') === 'online';
  const [response] = await Promise.all([
    page.waitForResponse(response =>
      response.request().method() === 'GET' && isOnlineUrl(new URL(response.url()))),
    page.locator('.filter-bar').getByRole('link', { name: '온라인', exact: true }).click(),
  ]);
  await page.waitForURL(isOnlineUrl, { waitUntil: 'load' });
  await page.waitForFunction(() => window.__qaEducationLoaded !== false);

  Object.assign(details, await readEducation(page), { expectedOnlineCount });
  const html = await response.text();
  details.serverCourseTitleCount = await page.evaluate(html =>
    new DOMParser().parseFromString(html, 'text/html').querySelectorAll('.course-title').length,
    html
  );
  details.onlineCourseCount = await page.locator(
    '.course-card:has(.course-type-badge.badge-online)'
  ).count();

  assert.deepEqual(details.selectedTexts, ['온라인'], 'S1 selected filter');
  assert.equal(details.buttons.length, 4, 'S1 visible filter count');
  const tops = details.buttons.map(button => button.top);
  assert.ok(Math.max(...tops) - Math.min(...tops) <= 2, 'S1 filters must fit on one row');
  for (const { text, height, textLines, left, right } of details.buttons) {
    assert.ok(height >= 32, `S1 ${text} filter height is below 32px`);
    assert.equal(textLines, 1, `S1 ${text} filter text must fit on one line`);
    assert.ok(left >= 0 && right <= viewport.width, `S1 ${text} filter must fit within the viewport`);
  }
  assert.equal(details.onlineCourseCount, details.courseCount, 'S1 all cards must be online');
  assert.equal(details.courseCount, expectedOnlineCount, 'S1 all online courses must be shown');
  assert.ok(response.ok(), `S1 server returned HTTP ${response.status()}`);
  assert.equal(details.serverCourseTitleCount, details.courseCount, 'S1 server and DOM counts');
}

async function checkInvalidType(page, educationUrl, unfilteredCourseCount, details) {
  const invalidUrl = new URL(educationUrl);
  invalidUrl.searchParams.set('type', 'onlne');
  const response = await page.goto(invalidUrl.href, { waitUntil: 'load' });
  details.status = response?.status() ?? null;
  assert.ok(response && response.ok(), `S2 expected a successful response, got HTTP status ${details.status}`);
  Object.assign(details, await readEducation(page), { unfilteredCourseCount });

  assert.deepEqual(details.selectedTexts, ['전체'], 'S2 selected filter');
  assert.equal(details.courseCount, unfilteredCourseCount, 'S2 fallback and unfiltered counts');
}

async function main() {
  const result = { viewport, consoleErrorItems: [], pageErrorItems: [], s1: {}, s2: {} };
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

    const educationUrl = new URL('/education', baseUrl);
    await page.goto(educationUrl.href, { waitUntil: 'load' });
    const unfilteredCourseCount = await page.locator('.course-card').count();
    const expectedOnlineCount = await page.locator(
      '.course-card:has(.course-type-badge.badge-online)'
    ).count();
    if (unfilteredCourseCount === 0) result.dataLimited = true;

    try {
      await checkOnline(page, educationUrl, expectedOnlineCount, result.s1);
    } catch (error) {
      result.s1.error = error.message;
    }

    try {
      await checkInvalidType(page, educationUrl, unfilteredCourseCount, result.s2);
    } catch (error) {
      result.s2.error = error.message;
    }
  } catch (error) {
    result.error = error.message;
  } finally {
    await browser?.close();
  }

  result.consoleErrors = result.consoleErrorItems.length;
  result.pageErrors = result.pageErrorItems.length;
  const pass = !result.error && !result.s1.error && !result.s2.error &&
    result.consoleErrors === 0 && result.pageErrors === 0;
  console.log(JSON.stringify(result));
  console.log(`SUMMARY pass=${pass}`);
  if (!pass) process.exitCode = 1;
}

main().catch(error => {
  console.log(JSON.stringify({ error: error.message }));
  console.log('SUMMARY pass=false');
  process.exitCode = 1;
});
