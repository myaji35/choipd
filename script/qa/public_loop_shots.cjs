const { chromium } = require('playwright');
// 방문 고객(비로그인) 관점 공개 페이지 촬영·측정. usage: node public_loop_shots.cjs <base> <outDir> [submit]
const [,, base, outDir, submit] = process.argv;
const fs = require('fs'); fs.mkdirSync(outDir, {recursive:true});
const pages = [
  ['editorial', '/kang-seung-sig'], ['grid', '/ux-grid'], ['sparse', '/ux-member'], ['card', '/kang-seung-sig/card']
];
(async () => {
  const browser = await chromium.launch();
  const report = [];
  for (const [vw, vh, tag] of [[1440, 900, 'd'], [390, 844, 'm']]) {
    for (const [name, path] of pages) {
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
      await page.screenshot({ path: outDir + '/' + name + '-' + tag + '.png', fullPage: true });
      await page.screenshot({ path: outDir + '/' + name + '-' + tag + '-fold.png' });
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
        } catch (e) { flow.error = String(e).slice(0,160); }
      }
      report.push({ name, tag, status: resp && resp.status(), overflowX: m.sw > m.cw, height: m.h, h1: m.h1, firstCta: m.firstCta, ctaScroll: m.ctaScroll, submitScroll: m.submitScroll, fold: m.fold, flow, consoleErrors: [...errors] });
      await ctx.close();
    }
  }
  await browser.close();
  fs.writeFileSync(outDir + '/report.json', JSON.stringify(report, null, 1));
  console.log(JSON.stringify(report.map(r => [r.name+'-'+r.tag, r.status, r.overflowX ? 'OVERFLOW' : '', 'cta:'+(r.firstCta && r.firstCta.text)+'@'+r.ctaScroll, 'submit@'+r.submitScroll, r.flow ? ('flow '+r.flow.clicks+(r.flow.ok?' ok':' FAIL '+(r.flow.error||''))+(r.flow.notice && !r.flow.notice.inView ? ' notice-offscreen':'')) : '', 'err'+r.consoleErrors.length])));
})();
