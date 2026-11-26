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
    const metric = async () => page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth, h: document.documentElement.scrollHeight, url: location.pathname + location.search,
      fold: [...document.querySelectorAll('h1,h2,h3,p,a,button,label,[role=status],[role=alert]')].filter(el => { const r = el.getBoundingClientRect(); return r.width > 0 && r.height > 0 && r.top < innerHeight && r.bottom > 0; }).map(el => (el.innerText||'').trim()).filter(Boolean).join(' | ').slice(0, 700) }));
    const shot = async (name, extra = {}) => { await page.waitForTimeout(300); const m = await metric(); await snap(page, { path: outDir + '/' + name + '-' + tag + '.png', fullPage: true }); await snap(page, { path: outDir + '/' + name + '-' + tag + '-fold.png' }); const row = { step: name, tag, url: m.url, overflowX: m.sw > m.cw, height: m.h, fold: m.fold, consoleErrors: [...errors], ...extra }; errors.length = 0; report.push(row); return row; };
    let clicks = 0, typed = 0;
    // 1) 가입 화면
    const r1 = await page.goto(base + '/auth/signup', {waitUntil: 'networkidle'});
    const fields = await page.evaluate(() => [...document.querySelectorAll('form input, form select, form textarea')].filter(el => el.type !== 'hidden' && el.type !== 'submit' && el.getBoundingClientRect().width > 0).length);
    await shot('signup', { status: r1 && r1.status(), visibleFields: fields });
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
    const nav = await page.evaluate(() => { const el = [...document.querySelectorAll('a, button')].find(a => { const r = a.getBoundingClientRect(); return r.width > 0 && r.top < innerHeight && /편집|관리|시작|채우|대시보드|내 페이지/.test((a.innerText||'').trim()); }); return el ? { text: el.innerText.trim().slice(0,40), href: el.getAttribute('href') } : null; });
    let afterNav = null;
    if (nav) { await Promise.all([page.waitForLoadState('networkidle').catch(()=>{}), page.locator('a, button').filter({ hasText: nav.text }).first().click()]); clicks++; afterNav = await shot('first-click', { navText: nav.text }); }
    else blocked.push('landing: 편집으로 가는 길이 첫 화면에 없음');
    const slug = (await page.evaluate(() => { const m = location.pathname.match(/^\/([a-z0-9][a-z0-9-]+)/); return m ? m[1] : null; })) || (landing.url.match(/^\/([a-z0-9][a-z0-9-]+)/) || [])[1];
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
        svcOk = await page.evaluate(() => document.body.innerText.includes('첫 상담 서비스'));
      } else blocked.push('services: 서비스 제목 칸 없음');
    } catch (e) { blocked.push('services: ' + String(e).slice(0,120)); }
    await shot('service-added', { svcOk, svcFields });
    // 5) 공개 페이지(방문자 눈): 새 창 비로그인
    const anon = await browser.newContext({ viewport: {width: vw, height: vh}, locale: 'ko-KR' });
    const ap = await anon.newPage();
    const pr = await ap.goto(base + '/' + slug, {waitUntil: 'networkidle'}).catch(() => null);
    const ready = await ap.evaluate(() => ({ service: document.body.innerText.includes('첫 상담 서비스'), contactForm: !!document.querySelector('#contact form'), cta: !!document.querySelector('a[href$="#contact"]') }));
    await snap(ap, { path: outDir + '/public-' + tag + '-fold.png' });
    await snap(ap, { path: outDir + '/public-' + tag + '.png', fullPage: true });
    report.push({ step: 'public', tag, status: pr && pr.status(), ready });
    await anon.close();
    // 6) 승인 대기 회원 로그인
    if (process.env.PENDING_PW) {
      const pc = await browser.newContext({ viewport: {width: vw, height: vh}, locale: 'ko-KR' });
      const pg = await pc.newPage();
      await pg.goto(base + '/auth/login', {waitUntil: 'networkidle'});
      await pg.fill('input[name=email]', 'ux-pending@impd.test'); await pg.fill('input[name=password]', process.env.PENDING_PW);
      await Promise.all([pg.waitForLoadState('networkidle'), pg.locator('form').filter({ has: pg.locator('input[name=password]') }).locator('button[type=submit], input[type=submit]').first().click()]);
      await pg.waitForTimeout(300);
      const pm = await pg.evaluate(() => ({ url: location.pathname, fold: [...document.querySelectorAll('h1,h2,p,a,button,[role=status],[role=alert],.flash, .notice')].filter(el => { const r = el.getBoundingClientRect(); return r.width > 0 && r.top < innerHeight && r.bottom > 0; }).map(el => (el.innerText||'').trim()).filter(Boolean).join(' | ').slice(0,500) }));
      await snap(pg, { path: outDir + '/pending-' + tag + '-fold.png' });
      report.push({ step: 'pending', tag, ...pm });
      await pc.close();
    }
    report.push({ step: 'summary', tag, slug, clicks, typed, signupFields: fields, blocked, ready, svcOk });
    await ctx.close();
  }
  await browser.close();
  fs.writeFileSync(outDir + '/report.json', JSON.stringify(report, null, 1));
  console.log(JSON.stringify(report.filter(r => r.step === 'summary' || r.overflowX || (r.consoleErrors && r.consoleErrors.length)).map(r => r.step === 'summary' ? [r.tag, 'slug '+r.slug, 'clicks '+r.clicks, 'typed '+r.typed, 'signupFields '+r.signupFields, 'svc '+r.svcOk, 'ready '+JSON.stringify(r.ready), 'blocked '+r.blocked.length+' '+r.blocked.join('; ')] : [r.step+'-'+r.tag, r.overflowX?'OVERFLOW':'', 'err'+(r.consoleErrors||[]).length])));
})();
