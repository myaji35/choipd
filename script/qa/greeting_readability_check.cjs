const { chromium } = require('playwright');

const baseUrl = process.env.BASE_URL || 'http://127.0.0.1:3008';
const route = '/media/greeting';

async function checkPage(browser, width) {
  const page = await browser.newPage({ viewport: { width, height: 844 } });

  try {
    const url = new URL(route, baseUrl);
    const response = await page.goto(url.href, { waitUntil: 'load' });
    const status = response?.status() ?? null;
    const finalPath = new URL(page.url()).pathname;
    if (status !== 200 || finalPath !== route) {
      return { width, navigationError: { status, finalPath } };
    }
    await page.evaluate(() => document.fonts.ready.then(() => undefined));

    const checks = await page.evaluate(() => {
      function rgba(color) {
        if (!/^rgba?\(/.test(color)) return null;
        const [r, g, b, alpha = 1] = color.match(/[\d.]+/g).map(Number);
        return { channels: [r, g, b], alpha };
      }

      function composite(foreground, background) {
        return foreground.channels.map((value, index) =>
          value * foreground.alpha + background[index] * (1 - foreground.alpha));
      }

      function luminance(channels) {
        const linear = channels.map(channel => {
          const value = channel / 255;
          return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
        });
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
      }

      function backgroundFor(element) {
        const layers = [];
        for (let current = element; current; current = current.parentElement) {
          layers.push(getComputedStyle(current));
        }
        let background = [10, 14, 26];
        let opacity = 1;
        for (const style of layers.reverse()) {
          if (style.backgroundImage !== "none") return { unsupportedColor: style.backgroundImage };
          opacity *= Number(style.opacity);
          const layer = rgba(style.backgroundColor);
          if (!layer) return { unsupportedColor: style.backgroundColor };
          layer.alpha *= opacity;
          background = composite(layer, background);
        }
        return { background, opacity };
      }

      function textNodes(element) {
        if (getComputedStyle(element).visibility !== 'visible') return [];
        for (let current = element; current; current = current.parentElement) {
          if (Number(getComputedStyle(current).opacity) === 0) return [];
        }

        return [...element.childNodes].filter(node => {
          if (node.nodeType !== Node.TEXT_NODE || !node.textContent.trim()) return false;
          const range = document.createRange();
          range.selectNodeContents(node);
          return [...range.getClientRects()].some(rect => rect.width > 0 && rect.height > 0);
        });
      }

      const contrastItems = [];
      let minContrast = Infinity;
      for (const element of document.querySelectorAll('main, main *')) {
        const text = textNodes(element).map(node => node.textContent).join(' ').trim().replace(/\s+/g, ' ').slice(0, 30);
        if (!text) continue;

        const color = getComputedStyle(element).color;
        const foregroundColor = rgba(color);
        const { background, opacity, unsupportedColor } = backgroundFor(element);
        if (!foregroundColor || unsupportedColor !== undefined) {
          contrastItems.push({ text, ratio: null, issue: '해석 못 하는 색 형식', color: foregroundColor ? unsupportedColor : color });
          continue;
        }
        foregroundColor.alpha *= opacity;
        const foreground = composite(foregroundColor, background);
        const levels = [luminance(foreground), luminance(background)];
        const ratio = (Math.max(...levels) + 0.05) / (Math.min(...levels) + 0.05);
        minContrast = Math.min(minContrast, ratio);
        if (ratio < 4.5) {
          contrastItems.push({ text, ratio: Number(ratio.toFixed(2)) });
        }
      }


      const breadcrumbTop = document.querySelector('main nav')?.getBoundingClientRect().top ?? null;
      const headerBottom = document.querySelector('#nav')?.getBoundingClientRect().bottom ?? null;
      return {
        minContrast: Number.isFinite(minContrast) ? Number(minContrast.toFixed(2)) : null,
        contrastItems,
        breadcrumbTop,
        headerBottom,
        noHeaderOverlap: breadcrumbTop !== null && headerBottom !== null && breadcrumbTop > headerBottom,
      };
    });
    return { width, ...checks };
  } catch (error) {
    return { width, error: error.message };
  } finally {
    await page.close();
  }
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const results = [];
  try {
    for (const width of [1280, 390, 320]) {
      results.push(await checkPage(browser, width));
    }
  } finally {
    await browser.close();
  }

  const pass = results.every(result => !result.error && !result.navigationError
    && result.minContrast !== null && result.contrastItems.length === 0 && result.noHeaderOverlap);
  console.log(JSON.stringify({ path: route, pass, results }, null, 2));
  process.exitCode = pass ? 0 : 1;
}

main().catch(error => {
  console.log(JSON.stringify({ path: route, pass: false, error: error.message }));
  process.exitCode = 1;
});
