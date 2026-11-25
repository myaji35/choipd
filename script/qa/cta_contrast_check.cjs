const { chromium } = require(require.resolve('playwright', { paths: [__dirname] }));

const url = new URL('/education', process.env.BASE_URL || 'http://127.0.0.1:3008');
const required = 4.5;

function parseColor(value) {
  const [r, g, b, alpha = 1] = value.match(/^rgba?\((.*)\)$/)[1].split(',').map(Number);
  const [red, green, blue] = [r, g, b].map(channel => {
    const c = channel / 255;
    return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return { luminance: 0.2126 * red + 0.7152 * green + 0.0722 * blue, alpha };
}

async function measure(page, selector, state) {
  const target = page.locator(selector);
  await target.waitFor({ state: 'visible' });
  const { color, background } = await target.evaluate(element => {
    const style = getComputedStyle(element);
    return { color: style.color, background: style.backgroundColor };
  });
  const foreground = parseColor(color);
  const bg = parseColor(background);
  const luminances = [foreground.luminance, bg.luminance];
  const opaque = foreground.alpha === 1 && bg.alpha === 1;
  const contrast = (Math.max(...luminances) + 0.05) / (Math.min(...luminances) + 0.05);

  return {
    viewport: page.viewportSize().width,
    selector,
    state,
    color,
    background,
    ratio: opaque ? Number(contrast.toFixed(2)) : null,
    required,
    pass: opaque && contrast >= required
  };
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  try {
    const desktop = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    await desktop.goto(url.href, { waitUntil: 'domcontentloaded' });
    const cta = 'header .nav-cta';
    const results = [await measure(desktop, cta, 'default')];
    await desktop.hover(cta);
    await desktop.waitForTimeout(400);
    results.push(await measure(desktop, cta, 'hover'));
    results.push(await measure(desktop, '.filter-pill.active', 'default'));

    const mobile = await browser.newPage({ viewport: { width: 390, height: 844 } });
    await mobile.goto(url.href, { waitUntil: 'domcontentloaded' });
    await mobile.click('.nav-mobile-btn');
    results.push(await measure(mobile, '#mobile-nav .nav-cta', 'menu open'));

    const pass = results.every(result => result.pass);
    console.log(JSON.stringify({ results, pass }, null, 2));
    process.exitCode = pass ? 0 : 1;
  } finally {
    await browser.close();
  }
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 2;
});
