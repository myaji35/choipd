
const { chromium } = require('playwright');
const [,, base, outDir, email, pass] = process.argv;
const fs = require('fs'); fs.mkdirSync(outDir, {recursive:true});
const slug = 'kang-seung-sig';
const pages = [
 ['dashboard', '/'+slug+'/admin/dashboard'], ['editor1','/'+slug+'/admin/editor?step=1'], ['editor2','/'+slug+'/admin/editor?step=2'],
 ['editor3','/'+slug+'/admin/editor?step=3'], ['editor4','/'+slug+'/admin/editor?step=4'], ['services','/'+slug+'/admin/services'],
 ['faqs','/'+slug+'/admin/faqs'], ['posts','/'+slug+'/admin/posts'], ['inquiries','/'+slug+'/admin/inquiries'],
 ['reviews','/'+slug+'/admin/reviews'], ['bookings','/'+slug+'/admin/bookings'], ['brand','/'+slug+'/admin/brand'],
 ['public','/'+slug]
];
(async () => {
  const browser = await chromium.launch();
  const report = [];
  for (const [vw, vh, tag] of [[1440, 900, 'd'], [390, 844, 'm']]) {
    const ctx = await browser.newContext({ viewport: {width: vw, height: vh}, locale: 'ko-KR', deviceScaleFactor: 1 });
    const page = await ctx.newPage();
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text().slice(0,200)); });
    await page.goto(base + '/admin/login');
    await page.fill('input[type=email]', email); await page.fill('input[type=password]', pass);
    await Promise.all([page.waitForLoadState('networkidle'), page.click('input[type=submit], button[type=submit]')]);
    for (const [name, path] of pages) {
      errors.length = 0;
      const resp = await page.goto(base + path, {waitUntil: 'networkidle'}).catch(e => null);
      await page.waitForTimeout(400);
      const m = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth, h: document.documentElement.scrollHeight }));
      const file = outDir + '/' + name + '-' + tag + '.png';
      await page.screenshot({ path: file, fullPage: true });
      report.push({ name, tag, status: resp && resp.status(), overflowX: m.sw > m.cw, height: m.h, consoleErrors: [...errors] });
    }
    await ctx.close();
  }
  await browser.close();
  fs.writeFileSync(outDir + '/report.json', JSON.stringify(report, null, 1));
  console.log(JSON.stringify(report.map(r => [r.name+'-'+r.tag, r.status, r.overflowX ? 'OVERFLOW' : '', r.consoleErrors.length])));
})();
