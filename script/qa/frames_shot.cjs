const { chromium } = require('playwright');
const [,, url, outDir, w, h, n] = process.argv; const fs=require('fs'); fs.mkdirSync(outDir,{recursive:true});
(async () => { const b = await chromium.launch(); const p = await (await b.newContext({viewport:{width:+w,height:+h},locale:'ko-KR'})).newPage();
 await p.goto(url,{waitUntil:'networkidle'}); await p.waitForTimeout(1200);
 const H = await p.evaluate(()=>document.documentElement.scrollHeight); const out=[];
 for (let i=0, y=0; y<H && i<+n; i++, y+=+h) { await p.evaluate(y=>scrollTo(0,y),y); await p.waitForTimeout(1400); const f=outDir+'/f'+String(i).padStart(2,'0')+'.png'; await p.screenshot({path:f}); out.push(f);} 
 console.log(out.length, H); await b.close(); })();