const fs = require('node:fs');
const path = require('node:path');

const root = fs.realpathSync(path.resolve(__dirname, '../..'));
const baseUrl = process.env.BASE_URL || 'http://127.0.0.1:3008';
const outDir = process.env.OUT_DIR || path.resolve(__dirname, '../../tmp/qa/readability');

async function checkPage(browser, route, width, outputDir) {
  const page = await browser.newPage({ viewport: { width, height: 844 } });
  const consoleErrorItems = [];
  page.on('console', message => {
    if (message.type() === 'error') consoleErrorItems.push(message.text());
  });
  page.on('pageerror', error => {
    consoleErrorItems.push(`pageerror: ${error.message}`);
  });

  try {
    const requestedUrl = new URL(route, baseUrl);
    const response = await page.goto(requestedUrl.href, { waitUntil: 'load' });
    const status = response?.status() ?? null;
    const finalPath = new URL(page.url()).pathname;
    if (status !== 200 || finalPath !== requestedUrl.pathname) {
      return {
        path: route, width, navigationError: { status, finalPath },
        consoleErrors: consoleErrorItems.length, consoleErrorItems,
      };
    }
    await page.evaluate(() => document.fonts.ready.then(() => undefined));
    const checks = await page.evaluate(({ route, width }) => {
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
      for (const element of document.querySelectorAll('footer, footer *')) {
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
          contrastItems.push({ text, ratio: ratio.toFixed(2) });
        }
      }

      const wordBreakItems = [];
      const range = document.createRange();
      for (const paragraph of document.querySelectorAll('footer p, .edu-hero-content p')) {
        const walker = document.createTreeWalker(paragraph, NodeFilter.SHOW_TEXT);
        for (let node = walker.nextNode(); node; node = walker.nextNode()) {
          for (const match of node.textContent.matchAll(/\S+/g)) {
            const word = match[0];
            let firstRect;
            let wordBreak = false;
            let offset = match.index;
            for (const character of word) {
              range.setStart(node, offset);
              offset += character.length;
              range.setEnd(node, offset);
              for (const rect of range.getClientRects()) {
                if (rect.width <= 0 || rect.height <= 0) continue;
                firstRect ??= rect;
                if (Math.abs(rect.top - firstRect.top) >= rect.height * 0.5) {
                  wordBreak = true;
                  break;
                }
              }
              if (wordBreak) break;
            }
            if (wordBreak) {
              wordBreakItems.push({ issue: '단어 중간 줄바꿈', word, path: route, width });
            }
          }
        }
      }

      const { scrollWidth, clientWidth } = document.documentElement;
      return {
        minContrast: Number.isFinite(minContrast) ? minContrast.toFixed(2) : null,
        contrastItems,
        wordBreakItems,
        overflow: scrollWidth > clientWidth ? { scrollWidth, clientWidth } : null,
      };
    }, { route, width });

    const footerFile = path.resolve(outputDir, `footer-${route.slice(1)}-${width}.png`);
    await page.locator('footer').screenshot({ path: footerFile, timeout: 10000 });
    return {
      path: route, width, ...checks, consoleErrors: consoleErrorItems.length, consoleErrorItems,
      files: [path.relative(root, fs.realpathSync(footerFile))],
    };
  } catch (error) {
    return { path: route, width, error: error.message, consoleErrors: consoleErrorItems.length, consoleErrorItems };
  } finally {
    await page.close();
  }
}

async function main() {
  const { chromium } = require(require.resolve('playwright', { paths: [__dirname] }));
  fs.mkdirSync(outDir, { recursive: true });
  const outputDir = fs.realpathSync(outDir);
  const browser = await chromium.launch({ headless: true });
  const results = [];
  try {
    for (const route of ['/education', '/works']) {
      for (const width of [1280, 390, 320]) {
        results.push(await checkPage(browser, route, width, outputDir));
      }
    }
  } finally {
    await browser.close();
  }

  const pass = results.every(result => !result.error && !result.navigationError && result.minContrast !== null
    && result.contrastItems.length === 0 && result.wordBreakItems.length === 0
    && !result.overflow && result.consoleErrors === 0);
  console.log(JSON.stringify({ results }));
  console.log(`SUMMARY pass=${pass}`);
  process.exitCode = pass ? 0 : 1;
}

main().catch(error => {
  console.log(JSON.stringify({ error: error.message }));
  console.log('SUMMARY pass=false');
  process.exitCode = 1;
});
