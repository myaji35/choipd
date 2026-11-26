const { chromium } = require('playwright');
// 새 회원 가입 → 첫 공개 여정 촬영·측정(로컬 개발 DB 전용). usage: node onboarding_loop_shots.cjs <base> <outDir> <runTag>
// 승인 대기 계정 비밀번호는 환경변수 PENDING_PW (ux-pending@impd.test)
const [,, base, outDir, runTag] = process.argv;
const fs = require('fs'); fs.mkdirSync(outDir, {recursive:true});
const snap = async (p, opts) => { try { await p.screenshot({ timeout: 45000, ...opts }); } catch (e) { console.error('screenshot skipped: ' + opts.path); } };
const bioText = '온보딩 시험 소개 글입니다. 어떤 분께 무엇을 해 드리는지 두세 줄로 적어 보는 중이에요. 문의는 편하게 주세요.';
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
        unchosenProfession: /크리에이터/.test((document.querySelector('.public-hero') || document.body).innerText),
        title: document.title,
        nextTask: document.querySelector('.dashboard-next')?.dataset.nextTask ?? null,
        nextHref: document.querySelector('.dashboard-next a.impd-btn-accent')?.getAttribute('href') ?? null,
        nextStepInFold: [...document.querySelectorAll('[data-next-step] a')].some(inFold),
        nextStepTask: document.querySelector('.next-step-title')?.innerText.trim() ?? null,
        welcomeSeen: fold.includes('환영합니다'),
        ownerBarInFold: inFold(document.querySelector('[data-owner-bar] a')),
        ownerNext: document.querySelector('[data-owner-bar] [data-owner-next]')?.dataset.ownerNext ?? null,
        bioFieldInFold: inFold(document.querySelector('#member_bio')),
        bioRequiredMarks: [...document.querySelectorAll('form.editor-fields label')]
          .filter(label => label.checkVisibility({ checkVisibilityCSS: true }))
          .reduce((count, label) => count + (label.innerText.match(/\(필수\)/g) || []).length, 0),
        photoPickerInFold: inFold(document.querySelector('#profile-photo .profile-photo-picker')),
        photoCapture: document.querySelector('#profile-photo input[type=file]')?.getAttribute('capture') ?? null,
        photoNoticeSeen: fold.includes('프로필 사진을 올렸어요'),
        bioPlaceholderLen: document.querySelector('#member_bio')?.placeholder.length ?? null,
        arrivalSeen: !!document.querySelector('.checklist-arrival'),
        pendingNoticeSeen: inFold(document.querySelector('[data-pending-notice]')),
        pendingPrepSeen: inFold(document.querySelector('[data-pending-prep]')),
        pendingNoticeHeight: document.querySelector('[data-pending-notice]')?.getBoundingClientRect().height ?? null
      };
    });
    const shot = async (name, extra = {}) => {
      await page.waitForTimeout(300);
      const { url, overflowX, height, fold, welcomeSeen, ownerBarInFold, unchosenProfession,
        nextTask, nextHref, nextStepInFold, nextStepTask, ownerNext,
        bioFieldInFold, bioPlaceholderLen, arrivalSeen, bioRequiredMarks,
        photoPickerInFold, photoCapture, photoNoticeSeen } = await metric();
      await snap(page, { path: outDir + '/' + name + '-' + tag + '.png', fullPage: true });
      await snap(page, { path: outDir + '/' + name + '-' + tag + '-fold.png' });
      const row = { step: name, tag, url, overflowX, height, fold, consoleErrors: [...errors], ...extra };
      if (name === 'landing') Object.assign(row, { welcomeSeen, ownerBarInFold, unchosenProfession, ownerNext });
      if (name === 'dashboard' || name === 'first-click') Object.assign(row, { nextTask, nextHref });
      if (name === 'service-added') Object.assign(row, { nextStepInFold, nextStepTask });
      if (name === 'bio') Object.assign(row, { bioFieldInFold, bioPlaceholderLen, arrivalSeen, bioRequiredMarks });
      if (name === 'photo') Object.assign(row, { photoPickerInFold, photoCapture, arrivalSeen });
      if (name === 'photo-saved') Object.assign(row, { nextTask, photoNoticeSeen });
      if (name === 'bio-saved') row.nextTask = nextTask;
      if (name === 'first-click') {
        row.reachedAdmin = /\/admin\//.test(url);
        row.directToTask = /\/admin\/services/.test(url);
      }
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
    if (landing.ownerNext !== 'services') blocked.push('landing: 띠의 다음 할 일이 서비스가 아님');
    if (landing.unchosenProfession) blocked.push('landing: 고르지 않은 직업이 보임');
    const checkNextTask = row => {
      if (row.nextTask !== 'services' || !row.nextHref?.includes('/admin/services')) {
        blocked.push('dashboard: 다음 할 일이 하는 일(서비스)이 아님');
      }
    };
    const slug = landing.url.split('/')[1];
    const dashboardPath = '/' + slug + '/admin/dashboard';
    const servicesPath = '/' + slug + '/admin/services';
    // 대시보드 자체의 안내도 확인한 뒤 첫 클릭은 공개 페이지에서 시작한다.
    const dashboardResponse = await page.goto(base + dashboardPath, {waitUntil: 'networkidle'});
    checkNextTask(await shot('dashboard', { status: dashboardResponse.status() }));
    await page.goto(base + '/' + slug, {waitUntil: 'networkidle'});

    const ownerAction = page.locator('[data-owner-bar] a.owner-bar-action');
    const inFold = async locator => await locator.count() && await locator.evaluate(el => {
      const rect = el.getBoundingClientRect();
      return el.checkVisibility({ checkVisibilityCSS: true }) && rect.top < innerHeight && rect.bottom > 0;
    });
    const nav = await inFold(ownerAction) ? ownerAction : page.locator('.impd-topnav-actions a')
      .filter({ hasText: /내 페이지/ }).filter({ visible: true }).first();
    let directToTask = false;
    if (await inFold(nav)) {
      const navText = (await nav.innerText()).trim();
      await nav.click();
      await page.waitForFunction(path => location.pathname + location.search !== path, landing.url, { timeout: 5000 }).catch(() => {});
      clicks++;
      const afterNav = await shot('first-click', { navText });
      directToTask = afterNav.directToTask;
      if (new URL(page.url()).pathname === dashboardPath) checkNextTask(afterNav);
      if (!afterNav.reachedAdmin) blocked.push('first-click: 눌러도 관리 화면으로 안 감');
    } else blocked.push('landing: 편집으로 가는 길이 첫 화면에 없음');

    let guided = directToTask;
    let servicesResponse;
    if (!directToTask) {
      if (new URL(page.url()).pathname !== dashboardPath) await page.goto(base + dashboardPath, {waitUntil: 'networkidle'});
      try {
        await page.locator('.dashboard-next a.impd-btn-accent').click({ timeout: 5000 });
        clicks++;
        await page.waitForURL(url => url.pathname === servicesPath, { timeout: 5000 });
        guided = true;
      } catch {
        blocked.push('dashboard: 다음 할 일 버튼으로 서비스 화면에 도착하지 못함');
        servicesResponse = await page.goto(base + servicesPath, {waitUntil: 'networkidle'});
      }
    }
    await shot('services', { status: servicesResponse?.status() ?? null });
    // 서비스 1개 등록(제목만)
    let svcOk = false; let svcFields = null; let svcSubmitInFold = false;
    try {
      svcFields = await page.evaluate(() => {
        const form = document.querySelector('#new-service form');
        if (!form) return null;
        return [...form.querySelectorAll('input, select, textarea')].filter(el =>
          el.type !== 'hidden' && el.type !== 'submit' && !el.closest('details:not([open])') &&
          el.getBoundingClientRect().width > 0
        ).length;
      });
      const title = page.locator('form [name*="[title]"]').first();
      if (await title.count()) {
        if (!(await title.isVisible())) { const opener = page.locator('a, button, summary').filter({ hasText: /서비스 추가|새 서비스|추가하기|만들기/ }).first(); if (await opener.count()) { await opener.click(); clicks++; } }
        const form = page.locator('form').filter({ has: page.locator('[name*="[title]"]') }).first();
        const submit = form.locator('button[type=submit], input[type=submit]').first();
        svcSubmitInFold = await submit.evaluate(el => {
          const rect = el.getBoundingClientRect();
          return rect.height > 0 && rect.top >= 0 && rect.bottom <= innerHeight;
        });
        await title.fill('첫 상담 서비스'); typed++;
        await Promise.all([page.waitForLoadState('networkidle'), submit.click()]); clicks++;
        const savedTitle = page.getByRole('heading', { name: '첫 상담 서비스', exact: true });
        await savedTitle.waitFor({ state: 'visible', timeout: 5000 });
        svcOk = true;
      } else blocked.push('services: 서비스 제목 칸 없음');
    } catch (e) { blocked.push('services: ' + String(e).slice(0,120)); }
    if (!svcSubmitInFold) blocked.push('services: 저장 버튼이 첫 화면 밖');
    const saved = await shot('service-added', { svcOk, svcFields, svcSubmitInFold });
    if (svcOk) {
      await page.locator('#new-service [data-service-more] summary').first().click();
      report.push({ step: 'services-open', tag, overflowX: (await metric()).overflowX });
    }
    if (!saved.nextStepInFold) blocked.push('service-added: 저장 뒤 다음 할 일 안내가 첫 화면에 없음');
    let bioClicks = 0, bioTyped = 0, bioGuided = false;
    const bioField = page.locator('#member_bio');
    try {
      const bioLink = page.locator('[data-next-step] a.impd-btn-accent');
      await bioLink.click({ timeout: 5000 });
      bioClicks++;
      await bioField.waitFor({ timeout: 5000 }).catch(() => {});
    } catch {
      blocked.push('service-added: 자기소개 쓰기 버튼으로 이동하지 못함');
    }
    const bio = await shot('bio');
    if (bio.bioRequiredMarks !== 2) blocked.push('bio: 필수 표시가 실제와 다름');
    let bioSaved;
    if (!(await bioField.count())) {
      blocked.push('bio: 자기소개 칸 없음');
    } else {
      try {
        await bioField.fill(bioText, { timeout: 5000 });
        bioTyped++;
        const bioForm = page.locator('form').filter({ has: bioField });
        await bioForm.locator('button[type=submit]').click({ timeout: 5000 });
        bioClicks++;
        await page.waitForURL(url => url.pathname === dashboardPath, { timeout: 5000 }).catch(() => {});
      } catch (e) {
        blocked.push('bio: ' + String(e).slice(0, 120));
      }
      bioSaved = await shot('bio-saved');
      if (bioSaved.url !== dashboardPath || bioSaved.nextTask !== 'profile-photo') {
        blocked.push('bio-saved: 저장 뒤 다음 할 일로 안 이어짐');
      } else {
        bioGuided = bioClicks === 2 && bioTyped === 1;
      }
    }
    let photoClicks = 0, photoGuided = false;
    if (bioSaved?.url !== dashboardPath || bioSaved.nextTask !== 'profile-photo') {
      blocked.push('photo: 사진 할 일에 도착하지 못함');
    } else {
      try {
        const photoLink = page.locator('.dashboard-next a.impd-btn-accent');
        const fileInput = page.locator('#profile-photo input[type=file]');
        await photoLink.click({ timeout: 5000 });
        photoClicks++;
        await fileInput.waitFor({ state: 'attached', timeout: 5000 });
        const photo = await shot('photo');
        if (photo.photoCapture !== null) blocked.push('photo: 사진 칸이 카메라만 엶');

        const png = await page.evaluate(() => {
          const canvas = document.createElement('canvas');
          canvas.width = canvas.height = 64;
          const drawing = canvas.getContext('2d');
          drawing.fillStyle = '#52879b';
          drawing.fillRect(0, 0, canvas.width, canvas.height);
          return canvas.toDataURL('image/png').split(',')[1];
        });
        const buffer = Buffer.from(png, 'base64');
        await fileInput.setInputFiles({ name: 'face.png', mimeType: 'image/png', buffer });
        photoClicks++;
        await page.waitForURL(url => url.pathname === dashboardPath, { timeout: 10000 }).catch(() => {});
        const photoSaved = await shot('photo-saved');
        if (photoSaved.url !== dashboardPath || photoSaved.nextTask !== 'profession-region') {
          blocked.push('photo-saved: 올린 뒤 다음 할 일로 안 이어짐');
        } else {
          photoGuided = photoClicks === 2;
        }
      } catch (e) {
        blocked.push('photo: ' + String(e).slice(0, 120));
      }
    }
    const editorResponse = await page.goto(base + '/' + slug + '/admin/editor?step=1', {waitUntil: 'networkidle'});
    await shot('editor1', { status: editorResponse.status() });
    // 5) 공개 페이지(방문자 눈): 새 창 비로그인
    const anon = await browser.newContext({ viewport: {width: vw, height: vh}, locale: 'ko-KR' });
    const ap = await anon.newPage();
    const publicErrors = [];
    ap.on('console', m => { if (m.type() === 'error') publicErrors.push(m.text().slice(0, 200)); });
    ap.on('pageerror', e => publicErrors.push('pageerror: ' + String(e).slice(0, 200)));
    const pr = await ap.goto(base + '/' + slug, {waitUntil: 'networkidle'}).catch(() => null);
    const ready = await ap.evaluate(bioPrefix => ({ bio: document.body.innerText.includes(bioPrefix), service: document.body.innerText.includes('첫 상담 서비스'), contactForm: !!document.querySelector('#contact form'), cta: document.querySelector('a.public-service-action[href="#contact"]')?.textContent.trim() === '이 서비스 문의하기', photo: !!document.querySelector('.public-hero img.public-avatar') }), bioText.slice(0, 10));
    await snap(ap, { path: outDir + '/public-' + tag + '-fold.png' });
    await snap(ap, { path: outDir + '/public-' + tag + '.png', fullPage: true });
    const ownerBarLeak = await ap.evaluate(() => !!document.querySelector('[data-owner-bar]'));
    if (ownerBarLeak) blocked.push('public: 본인용 띠가 방문자에게 보임');
    const { overflowX, unchosenProfession, title } = await metric(ap);
    if (unchosenProfession) blocked.push('public: 고르지 않은 직업이 고객에게 보임');
    report.push({ step: 'public', tag, status: pr && pr.status(), ready, ownerBarLeak,
      overflowX, unchosenProfession, title, consoleErrors: publicErrors });
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
      const { url, fold, pendingNoticeSeen, pendingPrepSeen, pendingNoticeHeight, overflowX } = await metric(pg);
      if (!pendingNoticeSeen) blocked.push('pending: 승인 대기 안내가 첫 화면에 없음');
      if (!pendingPrepSeen) blocked.push('pending: 기다리는 동안 준비할 것 안내 없음');
      await snap(pg, { path: outDir + '/pending-' + tag + '-fold.png' });
      report.push({ step: 'pending', tag, url, fold, pendingNoticeSeen, pendingPrepSeen, pendingNoticeHeight, overflowX, consoleErrors: pendingErrors });
      await pc.close();
    }
    report.push({ step: 'summary', tag, slug, clicks, typed, bioClicks, bioTyped, bioGuided, photoClicks, photoGuided, svcSubmitInFold, signupFields: fields, blocked, ready, svcOk, guided });
    await ctx.close();
  }
  await browser.close();
  fs.writeFileSync(outDir + '/report.json', JSON.stringify(report, null, 1));
  console.log(JSON.stringify(report.filter(r => r.step === 'summary' || r.overflowX || (r.consoleErrors && r.consoleErrors.length)).map(r => r.step === 'summary' ? [r.tag, 'slug '+r.slug, 'clicks '+r.clicks, 'typed '+r.typed, 'photoClicks '+r.photoClicks, 'photoGuided '+r.photoGuided, 'signupFields '+r.signupFields, 'svc '+r.svcOk, 'ready '+JSON.stringify(r.ready), 'blocked '+r.blocked.length+' '+r.blocked.join('; ')] : [r.step+'-'+r.tag, r.overflowX?'OVERFLOW':'', 'err'+(r.consoleErrors||[]).length])));
})();
