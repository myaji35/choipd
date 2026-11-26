const { chromium } = require('playwright');
// 방문 고객(비로그인) 관점 공개 페이지 촬영·측정. usage: node public_loop_shots.cjs <base> <outDir> [submit]
const [,, base, outDir, submit] = process.argv;
const fs = require('fs'); fs.mkdirSync(outDir, {recursive:true});
const pages = [
  ['editorial', '/kang-seung-sig'], ['grid', '/ux-grid'], ['sparse', '/ux-member'], ['card', '/kang-seung-sig/card']
];
(async () => {
  const gridPhotoResponse = await fetch(base + '/ux-photo', { redirect: 'manual' }).catch(() => null);
  const hasGridPhoto = gridPhotoResponse?.status === 200;
  await gridPhotoResponse?.body?.cancel();
  const browser = await chromium.launch();
  const report = [];
  for (const [vw, vh, tag] of [[1440, 900, 'd'], [390, 844, 'm']]) {
    const targets = hasGridPhoto ? [...pages, ['gridphoto', '/ux-photo']] : pages;
    for (const [name, path] of targets) {
      const ctx = await browser.newContext({ viewport: {width: vw, height: vh}, locale: 'ko-KR', deviceScaleFactor: 1 });
      const page = await ctx.newPage();
      const errors = [];
      page.on('console', m => { if (m.type() === 'error') errors.push(m.text().slice(0,200)); });
      page.on('pageerror', e => errors.push('pageerror: ' + String(e).slice(0,200)));
      const resp = await page.goto(base + path, {waitUntil: 'networkidle'}).catch(() => null);
      await page.waitForTimeout(400);
      const m = await page.evaluate((vh) => {
        const vis = el => { const r = el.getBoundingClientRect(); const s = getComputedStyle(el); return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none'; };
        const ctas = [...document.querySelectorAll('a, button, input[type=submit]')].filter(vis).filter(el => /문의|상담|신청|연락|예약/.test((el.innerText || el.value || '').trim()) && !el.closest('nav, header nav'));
        const first = ctas.map(el => ({ text: (el.innerText || el.value).trim().slice(0,30), top: Math.round(el.getBoundingClientRect().top + scrollY), h: Math.round(el.getBoundingClientRect().height), href: el.getAttribute('href') })).sort((a,b) => a.top - b.top)[0] || null;
        const sub = document.querySelector('#contact input[type=submit], #contact button[type=submit]');
        const subTop = sub ? Math.round(sub.getBoundingClientRect().top + scrollY) : null;
        const h1 = document.querySelector('h1'); 
        const fold = [...document.querySelectorAll('h1,h2,h3,p,a,button')].filter(vis).filter(el => el.getBoundingClientRect().top < vh && el.getBoundingClientRect().bottom > 0).map(el => (el.innerText||'').trim()).filter(Boolean).join(' | ').slice(0, 600);
        return { sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth, h: document.documentElement.scrollHeight,
          firstCta: first, ctaScroll: first ? Math.max(0, first.top + first.h - vh) : null, submitTop: subTop, submitScroll: subTop != null ? Math.max(0, subTop + 40 - vh) : null,
          h1: h1 ? h1.innerText.trim().slice(0,60) : null, fold };
      }, vh);
      let extra = {};
      if (name === 'gridphoto') {
        const photoPath = await page.locator('a[href^="/p/ux-photo/"]').first().evaluateAll(links => links[0]?.getAttribute('href'));
        if (photoPath) targets.push(['photo', photoPath]);
        extra = await page.evaluate(() => {
          const classes = document.getElementById('classes');
          return { classesTop: classes ? classes.getBoundingClientRect().top + scrollY : null };
        });
      }
      if (name === 'photo') {
        extra = await page.evaluate(() => {
          const cta = document.querySelector('a.primary');
          return {
            chrome: {
              joinstrip: !!document.querySelector('.impd-joinstrip'),
              platformNav: !!document.querySelector('nav.impd-topnav-links'),
              frap: !!document.querySelector('.impd-frap')
            },
            cta: { href: cta?.getAttribute('href') ?? null, inFold: !!cta && cta.getBoundingClientRect().bottom <= innerHeight }
          };
        });
      }
      let reach = null;
      if (name === 'editorial' || name === 'grid') {
        const contactTop = await page.locator('#contact').evaluate(el => el.getBoundingClientRect().top + scrollY);
        reach = { points: 0, withCta: 0, gaps: [] };
        for (let y = 0; y <= contactTop - vh; y += 300) {
          await page.evaluate(y => window.scrollTo({ top: y, left: 0, behavior: 'instant' }), y);
          await page.waitForTimeout(250);
          const hasCta = await page.evaluate(() => {
            const nav = document.querySelector('.impd-topnav');
            const navBottom = nav.getBoundingClientRect().bottom;
            return [...document.querySelectorAll("a[href$='#contact']")].some(el => {
              const rect = el.getBoundingClientRect();
              const style = getComputedStyle(el);
              return rect.width > 0 && style.visibility === 'visible' && style.display !== 'none' &&
                rect.bottom <= innerHeight && (rect.top >= navBottom || nav.contains(el));
            });
          });
          reach.points++;
          if (hasCta) reach.withCta++;
          else reach.gaps.push(y);
        }
        await page.evaluate(() => window.scrollTo({ top: 0, left: 0, behavior: 'instant' }));
        await page.waitForTimeout(250);
      }
      await page.screenshot({ path: outDir + '/' + name + '-' + tag + '.png', fullPage: true });
      await page.screenshot({ path: outDir + '/' + name + '-' + tag + '-fold.png' });
      let svc = null;
      let fail = null;
      let badContact = null;
      if (name === 'editorial' || name === 'grid') {
        await page.fill('#member_inquiry_sender_name', '쓰던 이름');
        await page.evaluate(() => window.scrollTo(0, 0));
        await page.locator('a.public-service-action[data-inquiry-service]').first().click();
        await page.waitForTimeout(800);
        svc = await page.evaluate(() => ({
          prefill: document.getElementById('member_inquiry_message').value,
          keptName: document.getElementById('member_inquiry_sender_name').value === '쓰던 이름',
          headingClear: document.querySelector('#contact h2').getBoundingClientRect().top >=
            document.querySelector('.impd-topnav').getBoundingClientRect().bottom,
          focus: document.activeElement.id
        }));
        await page.evaluate(() => sessionStorage.clear());
        await page.goto(base + path, {waitUntil: 'networkidle'});
      }
      if (submit && name === 'editorial' && tag === 'm') {
        await page.fill('#member_inquiry_sender_name', '쓰던 이름');
        await page.fill('#member_inquiry_sender_email', '010');
        await page.fill('#member_inquiry_message', '연락처 확인 시험입니다.');
        await page.check('#member_inquiry_consent');
        await page.click('#contact input[type=submit], #contact button[type=submit]');
        await page.waitForTimeout(500);
        badContact = await page.evaluate(() => ({
          message: document.getElementById('member_inquiry_sender_email')?.validationMessage ?? '',
          blocked: !!document.querySelector('#contact form') && !document.getElementById('inquiry-sent')
        }));
        await page.evaluate(() => sessionStorage.clear());
        await page.goto(base + path, {waitUntil: 'networkidle'});

        await page.fill('#member_inquiry_sender_name', '쓰던 이름');
        await page.fill('#member_inquiry_sender_email', '010-0000-0000');
        await page.fill('#member_inquiry_message', ' '.repeat(10));
        await page.check('#member_inquiry_consent');
        await page.click('#contact input[type=submit], #contact button[type=submit]');
        await page.waitForTimeout(600);
        fail = await page.evaluate(() => {
          const alert = document.querySelector('#contact [role=alert]');
          const rect = alert?.getBoundingClientRect();
          return {
            alert: alert?.innerText.trim() ?? null,
            inView: !!rect && rect.top >= 0 && rect.bottom <= innerHeight,
            keptName: document.getElementById('member_inquiry_sender_name').value === '쓰던 이름',
            keptContact: document.getElementById('member_inquiry_sender_email').value === '010-0000-0000'
          };
        });
        await page.evaluate(() => sessionStorage.clear());
        await page.goto(base + path, {waitUntil: 'networkidle'});
      }
      let flow = null;
      if (submit && (name === 'editorial' || name === 'grid')) {
        // 실제 문의 흐름: 첫 문의 버튼 클릭 → 이름·연락처·내용 → 동의 → 보내기
        flow = { clicks: 0, ok: false, step: '' };
        try {
          if (m.firstCta && !/^(문의 보내기)$/.test(m.firstCta.text)) {
            const loc = page.locator('a, button').filter({ hasText: m.firstCta.text }).first();
            await loc.click(); flow.clicks++; await page.waitForTimeout(500);
          }
          flow.step = 'fill';
          await page.fill('#member_inquiry_sender_name', 'UX 루프 시험');
          await page.fill('#member_inquiry_sender_email', 'ux-visitor@impd.test');
          const msg = await page.inputValue('#member_inquiry_message');
          if (!msg) await page.fill('#member_inquiry_message', '루프 시험 문의입니다. 연락 주세요.');
          flow.prefilled = !!msg;
          await page.check('#member_inquiry_consent'); flow.clicks++;
          await Promise.all([page.waitForLoadState('networkidle'), page.click('#contact input[type=submit], #contact button[type=submit]')]); flow.clicks++;
          await page.waitForTimeout(500);
          const st = await page.evaluate(() => { const s = document.querySelector('[role=status]'); if (!s) return null; const r = s.getBoundingClientRect(); return { text: s.innerText.trim().slice(0,60), inView: r.top < innerHeight && r.bottom > 0 }; });
          flow.ok = !!st; flow.notice = st;
          await page.screenshot({ path: outDir + '/' + name + '-' + tag + '-sent.png' });
          if (flow.ok) {
            await page.goto(base + path, {waitUntil: 'networkidle'});
            flow.draftCleared = (await page.inputValue('#member_inquiry_sender_name')) === '' &&
              (await page.inputValue('#member_inquiry_message')) === '';
          }
        } catch (e) { flow.error = String(e).slice(0,160); }
      }
      report.push({ name, tag, status: resp && resp.status(), overflowX: m.sw > m.cw, height: m.h, h1: m.h1, firstCta: m.firstCta, ctaScroll: m.ctaScroll, submitScroll: m.submitScroll, fold: m.fold, reach, svc, badContact, fail, flow, consoleErrors: [...errors], ...extra });
      await ctx.close();
    }
  }
  await browser.close();
  fs.writeFileSync(outDir + '/report.json', JSON.stringify(report, null, 1));
  console.log(JSON.stringify(report.map(r => [r.name+'-'+r.tag, r.status, r.overflowX ? 'OVERFLOW' : '', 'cta:'+(r.firstCta && r.firstCta.text)+'@'+r.ctaScroll, 'submit@'+r.submitScroll, r.flow ? ('flow '+r.flow.clicks+(r.flow.ok?' ok':' FAIL '+(r.flow.error||''))+(r.flow.notice && !r.flow.notice.inView ? ' notice-offscreen':'')) : '', 'err'+r.consoleErrors.length])));
})();
