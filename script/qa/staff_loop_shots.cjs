
const { chromium } = require('playwright');
const [,, base, outDir, aEmail, aPass, pEmail, pPass] = process.argv;
const fs = require('fs'); fs.mkdirSync(outDir, {recursive:true});
const NEW = 25, OLD = 4, OLD_BRAND = 22;
const sets = [
  ['admin', aEmail, aPass, [
    ['a-members', '/admin/members'], ['a-member-new', '/admin/members/'+NEW], ['a-member-old', '/admin/members/'+OLD],
    ['a-brand-old', '/admin/brands/'+OLD_BRAND], ['a-channel-new', '/admin/brands/'+OLD_BRAND+'/brand_channels/new'],
    ['a-pa-new', '/pd/people_accounts/new?member_id='+NEW],
    ['r-dash-new', '/ux-member/admin/dashboard'], ['r-channels-new', '/ux-member/admin/channels'], ['r-dash-old', '/kang-seung-sig/admin/dashboard']
  ]],
  ['pd', pEmail, pPass, [
    ['p-home', '/pd'], ['p-pa-index', '/pd/people_accounts'], ['p-pa-new', '/pd/people_accounts/new?member_id='+NEW],
    ['p-member-dash', '/ux-member/admin/dashboard']
  ]]
];
(async () => {
  const browser = await chromium.launch();
  const report = [];
  for (const [role, email, pass, pages] of sets) for (const [vw, vh, tag] of [[1440, 900, 'd'], [390, 844, 'm']]) {
    const ctx = await browser.newContext({ viewport: {width: vw, height: vh}, locale: 'ko-KR' });
    const page = await ctx.newPage(); const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text().slice(0,200)); });
    await page.goto(base + '/admin/login');
    await page.fill('input[type=email]', email); await page.fill('input[type=password]', pass);
    await Promise.all([page.waitForLoadState('networkidle'), page.click('input[type=submit], button[type=submit]')]);
    for (const [name, path] of pages) {
      errors.length = 0;
      const resp = await page.goto(base + path, {waitUntil: 'networkidle'}).catch(() => null);
      await page.waitForTimeout(300);
      const m = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }));
      await page.screenshot({ path: outDir + '/' + name + '-' + tag + '.png', fullPage: true });
      report.push({ role, name, tag, status: resp && resp.status(), finalUrl: page.url().replace(base,''), overflowX: m.sw > m.cw, consoleErrors: [...errors] });
    }
    await ctx.close();
  }
  await browser.close();
  fs.writeFileSync(outDir + '/report.json', JSON.stringify(report, null, 1));
  console.log(JSON.stringify(report.map(r => [r.name+'-'+r.tag, r.status, r.finalUrl, r.overflowX ? 'OVERFLOW' : '', r.consoleErrors.length])));
})();
