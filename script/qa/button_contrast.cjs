const { chromium } = require(require.resolve('playwright', { paths: [__dirname] }));

const url = new URL('/inquiries/new', process.env.BASE_URL || 'http://127.0.0.1:3008');
const selector = 'input[type=submit][value="문의 접수하기"]';
const viewports = [{ width: 1280, height: 900 }, { width: 390, height: 844 }];

// 브라우저가 반환한 RGB 채널을 선형화해 상대휘도를 구한다.
function parseColor(value) {
  const [r, g, b, alpha = 1] = value.match(/^rgba?\((.*)\)$/)[1].split(',').map(Number);
  const [red, green, blue] = [r, g, b].map(channel => {
    const c = channel / 255;
    return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return { luminance: 0.2126 * red + 0.7152 * green + 0.0722 * blue, alpha };
}

async function main() {
  let pass = true;
  const browser = await chromium.launch({ headless: true });
  try {
    for (const size of viewports) {
      const page = await browser.newPage({ viewport: size });
      await page.goto(url.href);
      const button = page.locator(selector);
      if (await button.count() === 0) throw new Error(`대상 버튼 없음: ${size.width}x${size.height}`);

      for (const state of ['default', 'hover']) {
        if (state === 'hover') {
          await button.hover();
          await page.waitForTimeout(400);
        }
        const { color, background, fontSize, fontWeight } = await button.evaluate(element => {
          const style = getComputedStyle(element);
          return { color: style.color, background: style.backgroundColor, fontSize: style.fontSize, fontWeight: style.fontWeight };
        });
        const foreground = parseColor(color);
        const bg = parseColor(background);
        const luminances = [foreground.luminance, bg.luminance];
        const contrast = (Math.max(...luminances) + 0.05) / (Math.min(...luminances) + 0.05);
        const px = parseFloat(fontSize);
        const large = px >= 24 || (px >= 18.66 && Number(fontWeight) >= 700);
        const required = large ? 3 : 4.5;
        const result = bg.alpha !== 0 && contrast >= required;
        const ratio = bg.alpha === 0 ? null : Number(contrast.toFixed(2));
        const viewport = `${size.width}x${size.height}`;
        console.log(JSON.stringify({ viewport, state, color, background, fontSize, fontWeight, large, ratio, required, pass: result }));
        pass = pass && result;
      }
      await page.close();
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
