import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
const source=readFileSync(new URL('../src/CavalryQuickbarPanel.js',import.meta.url),'utf8');
const defaultState=()=>({version:1,active:0,custom:[],profiles:[{name:'工作台',slots:['@scripts/Alpha.js','','@scripts/Panel.js'],modes:['script','script','ui']}]});
function mount(options={}){
 const state=options.state===undefined?defaultState():options.state;
 const logs=[],loads=[],uiLoads=[],processes=[],writes=[],deletes=[],files=new Map();
 const base=options.root??'/scripts',platform=options.platform??'macOS';
 const fileSet=new Set(options.files??[base+'/Alpha.js',base+'/Panel.js',base+'/CavalryToolbar.js',base+'/CavalryToolbar_assets/CavalryWheel.app/Contents/MacOS/CavalryWheel',base+'/CavalryToolbar_assets/CavalryWheel.ps1',base+'/CavalryToolbar_assets/UIRelay.js']);
 const api={getPlatform:()=>platform,getHomeFolder:()=>'/Users/example',getTempFolder:()=>'/tmp',getPreferenceObject:()=>state,hasPreferenceObject:()=>state!=null,
  isFile:p=>fileSet.has(p),writeToFile(p,data){files.set(p,data);writes.push({path:p,data});return options.writeFailure?false:true;},
  readFromFile:p=>files.get(p),deleteFilePath(p){deletes.push(p);files.delete(p);},
  load:p=>{loads.push(p);if(options.loadError)throw new Error('expected String, typeof=boolean');},
  runProcess(command,args){
   processes.push({command,args});
   if(args[args.length-1]===`printf '%s' "$PPID"` || args.includes('(Get-Process -Id $PID).Parent.Id'))return {output:options.parentOutput??'12345'};
   if(args.includes('--dispatch-ui'))return options.dispatchError?{error:'dispatch failed'}:{};
   const output=options.output??JSON.stringify({version:1,action:'run',profile:0,slot:0});
   if(args.includes('CavalryWheelWait') || args.includes('-WaitResponsePath')) return {output:options.waitOutput??JSON.stringify({version:1,action:'run',profile:0,slot:0})};
   if (!options.initialEmpty) files.set(platform==='macOS'?args[args.length-1]:args[args.indexOf('-ResponsePath')+1],output);
   return options.processFailure?{error:'permission not granted'}:{output};
  }};
 if(options.noHasPreference)delete api.hasPreferenceObject;
 if(options.noProcess)delete api.runProcess;
 const ui=options.plain?(options.plainUILoader?{scriptLocation:base,runFileScript:p=>uiLoads.push(p)}:{}):{scriptLocation:base,runFileScript:p=>uiLoads.push(p)};
 const code=options.legacy?'Array.prototype.fill=undefined;Number.isInteger=undefined;\n'+source:source;
 const result=vm.runInNewContext(code,{api,ui,console:{log:m=>logs.push(m)},Date,Math,cavalryToolbarWheelUIContext:options.plain?undefined:true});
 const request=writes.length?JSON.parse(writes[0].data):null;
 return {result,request,logs,loads,uiLoads,processes,writes,deletes,files,state};
}
test('one shortcut invokes a one-shot wheel and then loads the chosen ordinary script',()=>{
 const app=mount();assert.equal(app.result,'finished');assert.deepEqual(app.loads,['/scripts/Alpha.js']);
 assert.equal(app.processes[0].command,'/usr/bin/open');assert.deepEqual(Array.from(app.processes[0].args).slice(0,4),['-W','-n','-a','/scripts/CavalryToolbar_assets/CavalryWheel.app']);
 assert.equal(app.request.profiles[0].items.length,2);assert.deepEqual(app.request.profiles[0].items.map(i=>i.slot),[0,2]);
 assert.equal(app.deletes.length,2);assert.equal(app.files.size,0);
});
test('native request contains only display names and indices, never executable source or script paths',()=>{
 const app=mount();const raw=app.writes[0].data;
 assert.doesNotMatch(raw,/\/scripts|api\.load|runFileScript/);assert.equal(app.request.profiles[0].items[0].name,'Alpha');
});
test('cancellation exits without any script or preference write',()=>{
 const state=defaultState();const app=mount({state,output:JSON.stringify({version:1,action:'cancel'})});
 assert.equal(app.result,'cancelled');assert.deepEqual(app.loads,[]);assert.deepEqual(app.uiLoads,[]);assert.deepEqual(state,defaultState());
});
test('UI selection uses the UI loader only when a real UI context exists',()=>{
 const app=mount({output:JSON.stringify({version:1,action:'run',profile:0,slot:2})});
 assert.equal(app.result,'finished');assert.deepEqual(app.uiLoads,['/scripts/Panel.js']);assert.deepEqual(app.loads,[]);
});
test('macOS plain shortcut requests one-shot UI menu dispatch for the exact caller without ordinary fallback',()=>{
 const root='/Users/example/Library/Application Support/Cavalry/Scripts';
 const app=mount({plain:true,root,output:JSON.stringify({version:1,action:'run',profile:0,slot:2})});
 assert.equal(app.result,'ui-dispatch-pending');assert.deepEqual(app.loads,[]);assert.deepEqual(app.uiLoads,[]);
 assert.equal(app.processes.length,3);assert.equal(app.processes[1].command,'/usr/bin/env');
 const request=JSON.parse(app.writes[1].data);assert.equal(request.hostPID,12345);assert.equal(request.target,root+'/Panel.js');
 const args=Array.from(app.processes[2].args);assert.equal(app.processes[2].command,'/usr/bin/open');assert.ok(!args.includes('-W'));assert.ok(args.includes('--dispatch-ui'));
 assert.match(app.logs.join(' '),/不是脚本成功证明/);
});
test('a plain context exposing runFileScript still cannot use it; menu dispatch is required',()=>{
 const root='/Users/example/Library/Application Support/Cavalry/Scripts';
 const app=mount({plain:true,plainUILoader:true,root,output:JSON.stringify({version:1,action:'run',profile:0,slot:2})});
 assert.equal(app.result,'ui-dispatch-pending');assert.deepEqual(app.uiLoads,[]);assert.deepEqual(app.loads,[]);
 assert.equal(app.processes.length,3);assert.ok(Array.from(app.processes[2].args).includes('--dispatch-ui'));
});
test('the editor-declared UI context still uses its live UI loader without menu dispatch',()=>{
 const app=mount({output:JSON.stringify({version:1,action:'run',profile:0,slot:2})});
 assert.equal(app.result,'finished');assert.deepEqual(app.uiLoads,['/scripts/Panel.js']);assert.equal(app.processes.length,1);
});
test('an unknown caller PID never dispatches to some other running Cavalry',()=>{
 for(const parentOutput of ['', '0','123abc','-1','2147483648']){
  const app=mount({plain:true,root:'/Users/example/Library/Application Support/Cavalry/Scripts',parentOutput,output:JSON.stringify({version:1,action:'run',profile:0,slot:2})});
  assert.equal(app.result,'ui-unavailable');assert.equal(app.processes.length,2);assert.deepEqual(app.loads,[]);
 }
});
test('declined dispatch launch cleans its request without ordinary fallback',()=>{
 const app=mount({plain:true,root:'/Users/example/Library/Application Support/Cavalry/Scripts',dispatchError:true,output:JSON.stringify({version:1,action:'run',profile:0,slot:2})});
 assert.equal(app.result,'error');assert.deepEqual(app.loads,[]);assert.ok(app.deletes.some(p=>p.endsWith('-ui.json')));
});
test('Windows plain entry dispatches UI with the actual caller PID and waits for the native result',()=>{
 const app=mount({plain:true,root:'/Users/example/AppData/Roaming/Cavalry/Scripts',platform:'Windows',output:JSON.stringify({version:1,action:'run',profile:0,slot:2}),waitOutput:JSON.stringify({action:'ui-dispatch',status:'menu-invoked'})});
 assert.equal(app.result,'ui-dispatch-pending');assert.deepEqual(app.loads,[]);assert.deepEqual(app.uiLoads,[]);
 assert.equal(app.processes.length,4);
 const request=JSON.parse(app.writes[1].data);assert.equal(request.hostPID,12345);
 const args=Array.from(app.processes[2].args);assert.ok(args.includes('-DispatchUI'));assert.ok(args.includes('-DispatchResponsePath'));
 assert.ok(Array.from(app.processes[3].args).includes('-WaitResponsePath'));
 assert.ok(app.deletes.some(p=>p.endsWith('-ui.json')));assert.ok(app.deletes.some(p=>p.endsWith('-ui-response.json')));
});
test('configuration action uses the editor only from an available UI context',()=>{
 const app=mount({output:JSON.stringify({version:1,action:'settings'})});assert.deepEqual(app.uiLoads,['/scripts/CavalryToolbar.js']);
});
test('unknown config versions and corrupt configurations fail closed without rewriting preferences',()=>{
 for(const state of [null,{...defaultState(),version:2},{...defaultState(),version:0},{version:1,profiles:[null]},{...defaultState(),custom:'bad'}]){
  const app=mount({state});assert.equal(app.result,'incompatible');assert.equal(app.processes.length,0);assert.equal(app.writes.length,0);
 }
});
test('unavailable helper or host process API reports the concrete gap',()=>{
 assert.equal(mount({noProcess:true}).result,'unavailable');
 assert.equal(mount({files:['/scripts/Alpha.js']}).result,'missing-helper');
});
test('declined trust, failed request writes and malformed response never launch',()=>{
 for(const options of [{processFailure:true},{writeFailure:true},{output:'not json'},{output:JSON.stringify({version:2,action:'run',profile:0,slot:0})}]){
  const app=mount(options);assert.deepEqual(app.loads,[]);assert.deepEqual(app.uiLoads,[]);assert.ok(app.deletes.length>=1);
 }
});
test('native return is indices only and cannot inject a path or launch an unbound slot',()=>{
 for(const response of [{version:1,action:'run',profile:3,slot:0},{version:1,action:'run',profile:0,slot:1},{version:1,action:'run',profile:0,slot:12},{version:1,action:'run',profile:0,slot:0.5},{version:1,action:'run',path:'/evil.js'}]){
  const app=mount({output:JSON.stringify(response)});assert.deepEqual(app.loads,[]);assert.notEqual(app.result,'finished');
 }
});
test('missing and self-referential targets remain disabled and cannot dispatch',()=>{
 for(const path of ['/scripts/Missing.js','/scripts/CavalryQuickbarPanel.js','/scripts/CavalryToolbar.js']){
  const state=defaultState();state.profiles[0].slots[0]=path;
  const app=mount({state});assert.equal(app.request.profiles[0].items[0].available,false);assert.deepEqual(app.loads,[]);
 }
});
test('Windows invocation uses separate PowerShell arguments, not a shell command or policy bypass',()=>{
 const root='C:/Users/Test/AppData/Roaming/Cavalry/Scripts';
 const app=mount({platform:'Windows',root});assert.equal(app.processes[0].command,'powershell.exe');
 assert.deepEqual(Array.from(app.processes[0].args).slice(0,4),['-NoProfile','-STA','-File',root+'/CavalryToolbar_assets/CavalryWheel.ps1']);
 assert.ok(!app.processes[0].args.includes('-ExecutionPolicy'));assert.deepEqual(app.loads,[root+'/Alpha.js']);
});
test('plain entry resolves the documented macOS root without a Script UI parent',()=>{
 const root='/Users/example/Library/Application Support/Cavalry/Scripts';const app=mount({plain:true,root});
 assert.deepEqual(app.loads,[root+'/Alpha.js']);assert.equal(app.processes[0].args[3],root+'/CavalryToolbar_assets/CavalryWheel.app');
});
test('legacy JS and older preference API still work with the native wheel',()=>{
 assert.equal(mount({legacy:true,noHasPreference:true}).result,'finished');
});
test('JSC invocation and boolean-return exceptions do not assert business success',()=>{
 const state=defaultState();state.profiles[0].slots[0]='/scripts/Encrypted.jsc';
 const app=mount({state,files:['/scripts/Encrypted.jsc','/scripts/CavalryToolbar_assets/CavalryWheel.app/Contents/MacOS/CavalryWheel']});
 assert.match(app.logs.join(' '),/jsc invoked; check the host result/);
 assert.match(mount({loadError:true}).logs.join(' '),/script may have run/);
});


test('macOS response is an explicit atomic file, not LaunchServices stdout redirection',()=>{
 const app=mount();const args=Array.from(app.processes[0].args);
 assert.ok(!args.includes('--stdout'));
 assert.equal(args[4],'--args');assert.equal(args[5],app.writes[0].path);
 assert.match(args[6],/-response\.json$/);
});


test('host process wait ending early does not discard a later wheel selection',()=>{
 const app=mount({initialEmpty:true});assert.equal(app.result,'finished');assert.deepEqual(app.loads,['/scripts/Alpha.js']);
 assert.equal(app.processes[1].command,'/usr/bin/env');assert.deepEqual(Array.from(app.processes[1].args).slice(0,2),['-u','DYLD_INSERT_LIBRARIES']);assert.ok(app.processes[1].args.includes('/bin/sh'));assert.ok(app.processes[1].args.includes('CavalryWheelWait'));
 assert.equal(app.request.timeoutSeconds,180);
});
test('bounded pending waits terminate without executing when no selection arrives',()=>{
 const app=mount({initialEmpty:true,waitOutput:JSON.stringify({pending:true})});assert.equal(app.result,'timeout');assert.equal(app.processes.length,13);assert.deepEqual(app.loads,[]);
});


test('macOS reader has no GUI bundle identity and passes hostile-looking paths only as arguments',()=>{
 const app=mount({initialEmpty:true});const args=Array.from(app.processes[1].args);
 assert.equal(args[2],'/bin/sh');assert.equal(args[3],'-c');
 assert.ok(args[4].includes('"$1"'));
 assert.ok(!args[4].includes('/tmp/'));
 assert.equal(args[args.length-1],app.writes[0].path.replace(/\.json$/,'-response.json'));
 assert.ok(!args.some(x=>x.endsWith('/MacOS/CavalryWheel')));
});
