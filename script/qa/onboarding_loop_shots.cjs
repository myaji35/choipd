const { chromium } = require('playwright');
// 새 회원 가입 → 첫 공개 여정 촬영·측정(로컬 개발 DB 전용). usage: node onboarding_loop_shots.cjs <base> <outDir> <runTag>
// 승인 대기 계정 비밀번호는 환경변수 PENDING_PW (ux-pending@impd.test)
const [,, base, outDir, runTag] = process.argv;
const fs = require('fs'); fs.mkdirSync(outDir, {recursive:true});
const snap = async (p, opts) => { try { await p.screenshot({ timeout: 45000, ...opts }); } catch (e) { console.error('screenshot skipped: ' + opts.path); } };
const pw = 'Onb-' + Math.random().toString(36).slice(2, 12);
(async () => {
  const browser = await chromium.launch();
  const report = [];
  for (const [vw, vh, tag] of [[1440, 900, 'd'], [390, 844, 'm']]) {
    const ctx = await browser.newContext({ viewport: {width: vw, height: vh}, locale: 'ko-KR', deviceScaleFactor: 1 });
    const page = await ctx.newPage();
    const errors = []; const blocked = [];
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text().slice(0,200)); });
    page.on('pageerror', e => errors.push('pageerror: ' + String(e).slice(0,200)));
    const metric = async (target = page) => target.evaluate(() => {
      const inFold = el => {
        if (!el || !el.checkVisibility({ checkVisibilityCSS: true })) return false;
        const rect = el.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0 && rect.bottom > 0 && rect.top < innerHeight;
      };
      const fold = [...document.querySelectorAll('h1,h2,h3,p,a,button,label,[role=status],[role=alert]')]
        .filter(inFold).map(el => (el.innerText || '').trim()).filter(Boolean).join(' | ');
      return {
        overflowX: document.documentElement.scrollWidth > document.documentElement.clientWidth,
        height: document.documentElement.scrollHeight,
        url: location.pathname + location.search,
        fold: fold.slice(0, 700),
        welcomeSeen: fold.includes('환영합니다'),
        ownerBarInFold: inFold(document.querySelector('[data-owner-bar] a')),
        pendingNoticeSeen: inFold(document.querySelector('[data-pending-notice]'))
      };
    });
    const shot = async (name, extra = {}) => {
      await page.waitForTimeout(300);
      const { url, overflowX, height, fold, welcomeSeen, ownerBarInFold } = await metric();
      await snap(page, { path: outDir + '/' + name + '-' + tag + '.png', fullPage: true });
      await snap(page, { path: outDir + '/' + name + '-' + tag + '-fold.png' });
      const row = { step: name, tag, url, overflowX, height, fold, consoleErrors: [...errors], ...extra };
      if (name === 'landing') Object.assign(row, { welcomeSeen, ownerBarInFold });
      if (name === 'first-click') row.reachedAdmin = /\/admin\//.test(url);
      errors.length = 0;
      report.push(row);
      return row;
    };
    let clicks = 0, typed = 0;
    // 1) 가입 화면
    const r1 = await page.goto(base + '/auth/signup', {waitUntil: 'networkidle'});
    const { fields, submitTop } = await page.evaluate(() => {
      const form = document.querySelector('form[action="/auth/signup"]');
      const fields = [...form.querySelectorAll('input, select, textarea')].filter(el =>
        el.type !== 'hidden' && el.type !== 'submit' && !el.closest('details:not([open])') &&
        el.getBoundingClientRect().width > 0
      ).length;
      return { fields, submitTop: form.querySelector('button[type=submit]').getBoundingClientRect().top + scrollY };
    });
    await shot('signup', { status: r1 && r1.status(), visibleFields: fields, submitTop });
    await page.locator('[data-signup-more] summary').click();
    report.push({ step: 'signup-open', tag, overflowX: (await metric()).overflowX });
    // 2) 가입: 필수 칸만(이름·이메일·비밀번호·확인) + 약관 동의 + 가입
    const email = 'ux-onb-' + runTag + '-' + tag + '@impd.test';
    await page.fill('#member_name', '온보딩 시험 ' + tag); typed++;
    await page.fill('#member_email', email); typed++;
    await page.fill('#member_password', pw); typed++;
    if (await page.$('#member_password_confirmation')) { await page.fill('#member_password_confirmation', pw); typed++; }
    if (await page.$('#terms_agree')) { await page.check('#terms_agree'); clicks++; }
    await Promise.all([page.waitForLoadState('networkidle'), page.locator('form').filter({ has: page.locator('#member_email') }).locator('button[type=submit], input[type=submit]').first().click()]); clicks++;
    const landing = await shot('landing');
    // 3) 처음 쓰는 사람처럼: 도착 화면 첫 화면에서 '편집·관리·시작' 류 링크를 누른다
    const nav = page.locator('.impd-topnav-actions a, [data-owner-bar] a')
      .filter({ hasText: /내 페이지/ })
      .filter({ visible: true }).first();
    if (await nav.count() && await nav.evaluate(el => {
      const rect = el.getBoundingClientRect();
      return rect.top < innerHeight && rect.bottom > 0;
    })) {
      const navText = (await nav.innerText()).trim();
      await nav.click();
      await page.waitForFunction(path => location.pathname + location.search !== path, landing.url, { timeout: 5000 }).catch(() => {});
      clicks++;
      const afterNav = await shot('first-click', { navText });
      if (!afterNav.reachedAdmin) blocked.push('first-click: 눌러도 관리 화면으로 안 감');
    } else blocked.push('landing: 편집으로 가는 길이 첫 화면에 없음');
    const slug = landing.url.split('/')[1];
    // 4) 대시보드·에디터·서비스
    for (const [name, path] of [['dashboard', '/admin/dashboard'], ['editor1', '/admin/editor?step=1'], ['services', '/admin/services']]) {
      const r = await page.goto(base + '/' + slug + path, {waitUntil: 'networkidle'}).catch(() => null);
      const row = await shot(name, { status: r && r.status() });
      if (!r || r.status() >= 400 || /login|auth/.test(row.url)) blocked.push(name + ': ' + (r && r.status()) + ' ' + row.url);
    }
    // 서비스 1개 등록(제목만)
    let svcOk = false; let svcFields = null;
    try {
      svcFields = await page.evaluate(() => { const f = [...document.querySelectorAll('form')].find(f => f.querySelector('[name*="title"]')); return f ? [...f.querySelectorAll('input, select, textarea')].filter(el => el.type !== 'hidden' && el.type !== 'submit' && el.getBoundingClientRect().width > 0).length : null; });
      const title = page.locator('form [name*="[title]"]').first();
      if (await title.count()) {
        if (!(await title.isVisible())) { const opener = page.locator('a, button, summary').filter({ hasText: /서비스 추가|새 서비스|추가하기|만들기/ }).first(); if (await opener.count()) { await opener.click(); clicks++; } }
        await title.fill('첫 상담 서비스'); typed++;
        const form = page.locator('form').filter({ has: page.locator('[name*="[title]"]') }).first();
        await Promise.all([page.waitForLoadState('networkidle'), form.locator('button[type=submit], input[type=submit]').first().click()]); clicks++;
        const savedTitle = page.getByRole('heading', { name: '첫 상담 서비스', exact: true });
        await savedTitle.waitFor({ state: 'visible', timeout: 5000 });
        svcOk = true;
      } else blocked.push('services: 서비스 제목 칸 없음');
    } catch (e) { blocked.push('services: ' + String(e).slice(0,120)); }
    await shot('service-added', { svcOk, svcFields });
    // 5) 공개 페이지(방문자 눈): 새 창 비로그인
    const anon = await browser.newContext({ viewport: {width: vw, height: vh}, locale: 'ko-KR' });
    const ap = await anon.newPage();
    const publicErrors = [];
    ap.on('console', m => { if (m.type() === 'error') publicErrors.push(m.text().slice(0, 200)); });
    ap.on('pageerror', e => publicErrors.push('pageerror: ' + String(e).slice(0, 200)));
    const pr = await ap.goto(base + '/' + slug, {waitUntil: 'networkidle'}).catch(() => null);
    const ready = await ap.evaluate(() => ({ service: document.body.innerText.includes('첫 상담 서비스'), contactForm: !!document.querySelector('#contact form'), cta: !!document.querySelector('a[href$="#contact"]') }));
    await snap(ap, { path: outDir + '/public-' + tag + '-fold.png' });
    await snap(ap, { path: outDir + '/public-' + tag + '.png', fullPage: true });
    const ownerBarLeak = await ap.evaluate(() => !!document.querySelector('[data-owner-bar]'));
    if (ownerBarLeak) blocked.push('public: 본인용 띠가 방문자에게 보임');
    report.push({ step: 'public', tag, status: pr && pr.status(), ready, ownerBarLeak,
      overflowX: (await metric(ap)).overflowX, consoleErrors: publicErrors });
    await anon.close();
    // 6) 승인 대기 회원 로그인
    if (process.env.PENDING_PW) {
      const pc = await browser.newContext({ viewport: {width: vw, height: vh}, locale: 'ko-KR' });
      const pg = await pc.newPage();
      const pendingErrors = [];
      pg.on('console', m => { if (m.type() === 'error') pendingErrors.push(m.text().slice(0, 200)); });
      pg.on('pageerror', e => pendingErrors.push('pageerror: ' + String(e).slice(0, 200)));
      await pg.goto(base + '/auth/login', {waitUntil: 'networkidle'});
      await pg.fill('input[name=email]', 'ux-pending@impd.test'); await pg.fill('input[name=password]', process.env.PENDING_PW);
      await Promise.all([pg.waitForLoadState('networkidle'), pg.locator('form').filter({ has: pg.locator('input[name=password]') }).locator('button[type=submit], input[type=submit]').first().click()]);
      await pg.waitForTimeout(300);
      const { url, fold, pendingNoticeSeen, overflowX } = await metric(pg);
      if (!pendingNoticeSeen) blocked.push('pending: 승인 대기 안내가 첫 화면에 없음');
      await snap(pg, { path: outDir + '/pending-' + tag + '-fold.png' });
      report.push({ step: 'pending', tag, url, fold, pendingNoticeSeen, overflowX, consoleErrors: pendingErrors });
      await pc.close();
    }
    report.push({ step: 'summary', tag, slug, clicks, typed, signupFields: fields, blocked, ready, svcOk });
    await ctx.close();
  }
  await browser.close();
  fs.writeFileSync(outDir + '/report.json', JSON.stringify(report, null, 1));
  console.log(JSON.stringify(report.filter(r => r.step === 'summary' || r.overflowX || (r.consoleErrors && r.consoleErrors.length)).map(r => r.step === 'summary' ? [r.tag, 'slug '+r.slug, 'clicks '+r.clicks, 'typed '+r.typed, 'signupFields '+r.signupFields, 'svc '+r.svcOk, 'ready '+JSON.stringify(r.ready), 'blocked '+r.blocked.length+' '+r.blocked.join('; ')] : [r.step+'-'+r.tag, r.overflowX?'OVERFLOW':'', 'err'+(r.consoleErrors||[]).length])));
})();
