// Usage: PLAYWRIGHT_MODULE=/path/to/playwright CHROME_EXECUTABLE=/path/to/chrome
// node app/test/browser/run_gameplay_soak.cjs /tmp/chess-browser-soak
const {createServer} = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = path.resolve(process.argv[2] || '/tmp/chess-browser-soak');
const output = process.env.SOAK_OUTPUT || '/tmp/chess-browser-soak-result.json';
const types = {'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm', '.json':'application/json','.css':'text/css','.png':'image/png','.webp':'image/webp','.svg':'image/svg+xml','.ttf':'font/ttf'};
const server = createServer((request,response) => {
  let file;
  try { file=path.resolve(root, '.'+decodeURIComponent(new URL(request.url,'http://localhost').pathname)); }
  catch {response.writeHead(400).end();return;}
  if(!file.startsWith(root+path.sep)&&file!==root){response.writeHead(403).end();return;}
  if(file===root||fs.existsSync(file)&&fs.statSync(file).isDirectory())file=path.join(file,'index.html');
  if(!fs.existsSync(file)){response.writeHead(404).end();return;}
  response.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream',
    'Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp',
    'Cross-Origin-Resource-Policy':'cross-origin','Cache-Control':'no-store'});
  fs.createReadStream(file).pipe(response);
});
(async()=>{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const url=`http://127.0.0.1:${server.address().port}/`;
  const browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE||'/tmp/chess-chrome',headless:true,
    args:['--no-sandbox','--disable-dev-shm-usage','--enable-unsafe-swiftshader','--autoplay-policy=no-user-gesture-required']});
  const page=await browser.newPage({viewport:{width:1280,height:900}});
  const errors=[],workers=[];
  page.on('pageerror',error=>{errors.push(String(error));console.log('PAGE_ERROR',String(error));});
  page.on('worker',worker=>{workers.push(worker.url());console.log('WORKER',worker.url());});
  page.on('console',message=>{
    const text=message.text();
    if(text.startsWith('BROWSER_SOAK ')){
      try {const data=JSON.parse(text.slice(13));if(!data.done)console.log(JSON.stringify(data));}catch{console.log(text.slice(0,250));}
    } else if(message.type()==='error')console.log('CONSOLE_ERROR',text.slice(0,500));
  });
  await page.addInitScript(()=>{
    globalThis.soakHeartbeat={maxGapMs:0,count:0};let last=performance.now();
    setInterval(()=>{const now=performance.now();globalThis.soakHeartbeat.maxGapMs=Math.max(globalThis.soakHeartbeat.maxGapMs,now-last);globalThis.soakHeartbeat.count++;last=now;},50);
  });
  console.log('BROWSER_SOAK_URL',url);
  let result;
  try {
    await page.goto(url,{waitUntil:'domcontentloaded'});
    await page.waitForFunction(()=>globalThis.chessBrowserSoak?.done===true,null,{timeout:12*60*1000});
    result=await page.evaluate(()=>({result:globalThis.chessBrowserSoak,heartbeat:globalThis.soakHeartbeat,
      isolated:crossOriginIsolated,userAgent:navigator.userAgent}));
  } catch(error) {
    result={failure:String(error),state:await page.evaluate(()=>globalThis.chessBrowserSoak||null).catch(()=>null)};
  }
  result.workers=workers;result.browserErrors=errors;result.url=url;
  fs.writeFileSync(output,JSON.stringify(result,null,2));
  await page.screenshot({path:output.replace(/\.json$/,'.png')});
  console.log('BROWSER_SOAK_COMPLETE',JSON.stringify({passed:result.result?.passed??false,
    replies:result.result?.results?.length??0,error:result.result?.error||result.failure,
    isolated:result.isolated,heartbeat:result.heartbeat,output}));
  await browser.close();await new Promise(resolve=>server.close(resolve));
  if(!result.result?.passed)process.exitCode=1;
})().catch(error=>{console.error(error);server.close();process.exitCode=1;});
