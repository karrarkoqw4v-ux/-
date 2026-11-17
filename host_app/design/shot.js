const {chromium}=require('playwright');
(async()=>{const b=await chromium.launch();for(const n of [1,2,3]){const p=await b.newPage({viewport:{width:1360,height:740},deviceScaleFactor:1.6});
await p.goto('file://'+process.cwd()+`/s${n}.html`);await p.screenshot({path:`design-${n}.png`});}await b.close()})();
