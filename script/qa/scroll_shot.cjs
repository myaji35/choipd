const { chromium } = require('playwright');
const [,, url, out, w, h] = process.argv;
(async () => { const b = await chromium.launch(); const p = await (await b.newContext({viewport:{width:+w,height:+h},locale:'ko-KR'})).newPage();
 await p.goto(url,{waitUntil:'networkidle'}); const H = await p.evaluate(()=>document.documentElement.scrollHeight);
 for (let y=0;y<H;y+=+h/2){ await p.evaluate(y=>scrollTo(0,y),y); await p.waitForTimeout(250);} await p.evaluate(()=>scrollTo(0,0)); await p.waitForLoadState('networkidle'); await p.waitForTimeout(800);
 const broken = await p.evaluate(()=>[...document.querySelectorAll('img[data-source=ai-generated]')].filter(i=>!i.complete||i.naturalWidth===0).map(i=>i.currentSrc||i.src));
 await p.screenshot({path:out, fullPage:true}); console.log(JSON.stringify({broken})); await b.close(); })();