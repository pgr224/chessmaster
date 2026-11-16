// Run with NODE_PATH pointing to a Playwright installation. No live API calls.
const {chromium}=require('playwright');
const {performance}=require('node:perf_hooks');
const {Chess}=require('../../../backend/node_modules/chess.js');
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../web');
(async()=>{
 const server=http.createServer((req,res)=>{
  res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');res.setHeader('Cache-Control','no-store');
  if(req.url.startsWith('/audit')){res.setHeader('Content-Type','text/html');res.end('<base href="/"><script src="engine/sunfish_engine.js"></script><script src="engine/chess_logic.js"></script><script src="engine/engine_service.js"></script>');return;}
  const file=path.resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]));if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return;}
  res.setHeader('Content-Type',file.endsWith('.wasm')?'application/wasm':'text/javascript');fs.createReadStream(file).on('error',()=>{res.writeHead(404);res.end();}).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 let browser;
 try{
  browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE,headless:true,args:['--no-sandbox']});
  const report=[];
  for(const difficulty of (process.env.ENGINE_DIFFICULTIES?.split(',')??['basic','intermediate','advanced','impossible','aiMode'])){
   const page=await browser.newPage();const errors=[],workers=[];
   page.on('pageerror',e=>errors.push(e.message));page.on('worker',w=>workers.push(w));
   await page.goto(`http://127.0.0.1:${server.address().port}/audit`);
   await page.evaluate(d=>ChessEngineService.initEngine('singlePlayer',d),difficulty);
   const chess=new Chess(),times=[],sources=[],heaps=[],wallTimes=[],pageTimes=[];
   for(let turn=0;turn<Number(process.env.ENGINE_TURNS??12) && !chess.isGameOver();turn++){
    const fen=chess.fen(),started=performance.now(),wallStarted=Date.now();
    const measured=await page.evaluate(async({fen,first})=>{const started=performance.now();const result=await Promise.race([
      ChessEngineService.getBestMove(fen,first?undefined:1000),
      new Promise((_,reject)=>setTimeout(()=>reject(Error('Search never settled')),26000)),
    ]);return {result,elapsedMs:performance.now()-started};},{fen,first:turn===0||process.env.ENGINE_FULL_BUDGET==='1'});
    const raw=measured.result;pageTimes.push(measured.elapsedMs);
    const move=typeof raw==='string'?raw:raw?.move;
    assert.ok(move,`${difficulty} turn ${turn}: no move`);
    chess.move({from:move.slice(0,2),to:move.slice(2,4),promotion:move[4]});
    times.push(Math.round(performance.now()-started));wallTimes.push(Date.now()-wallStarted);if(process.env.ENGINE_VERBOSE)console.log(JSON.stringify({difficulty,turn,elapsedMs:times.at(-1),pageMs:pageTimes.at(-1),wallMs:wallTimes.at(-1)}));sources.push(await page.evaluate(()=>ChessEngineService.getActiveEngine()));
    for(const worker of page.workers())if(worker.url().includes('stockfish_hybrid')){heaps.push(await worker.evaluate(()=>typeof stockfishEngine!=='undefined'?stockfishEngine?.HEAPU8?.byteLength??null:null));}
    if(chess.isGameOver())break;
    const moves=chess.moves({verbose:true});const human=moves[(turn*7+5)%moves.length];chess.move(human);
   }
   const expected=['basic','intermediate'].includes(difficulty)?'sunfish':'stockfish';
   assert.ok(sources.every(s=>s===expected),`${difficulty} unexpectedly switched source: ${sources}`);
   assert.equal(errors.length,0,`${difficulty}: browser errors ${errors}`);
   const record={difficulty,legalAiReplies:times.length,totalPlies:chess.history().length,firstMs:times[0],maxMs:Math.max(...times),workerInstances:workers.length,liveWorkers:page.workers().length,wasmBytes:[...new Set(heaps)],timesMs:times,pageTimesMs:pageTimes,wallTimesMs:wallTimes,sources:[...new Set(sources)],errors};
   report.push(record);console.log(JSON.stringify(record));
   await page.evaluate(()=>ChessEngineService.dispose());await page.close();
  }
  if(process.env.ENGINE_REPORT)fs.writeFileSync(process.env.ENGINE_REPORT,JSON.stringify(report,null,2));
 }finally{await browser?.close();await new Promise(r=>server.close(r));}
})().catch(error=>{console.error(error);process.exitCode=1;});
