import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
const template=readFileSync(new URL('../native/macos/UIRelay.js',import.meta.url),'utf8');
function mount(script, options={}) {
 const pending=[],receipts=[],logs=[],children=[];
 const native={scriptLocation:'/Scripts',title:'',shown:0,Label:function(text){this.text=text;},add(...items){children.push(...items);},setTitle(value){this.title=value;},show(){this.shown++;}};
 const api={readFromFile:p=>{assert.equal(p,"/External '中文/Panel.js");return script;},writeToFile(p,text){receipts.push({path:p,value:JSON.parse(text)});return true;},Timer:function(callbacks){this.active=false;this.stop=()=>{this.active=false;};this.setInterval=v=>{this.interval=v;};this.setRepeating=v=>{this.repeating=v;};this.start=()=>{this.active=true;};this.fire=()=>{if(this.active)callbacks.onTimeout();};pending.push(this);}};
 const payload={target:"/External '中文/Panel.js",directory:"/External '中文",receipt:'/tmp/receipt.json'};
 const context={ui:native,api,console:{log:m=>logs.push(m)}};
 if(options.noProxy)context.Proxy=undefined;
 const result=vm.runInNewContext(template.replace('__CAVALRY_WHEEL_DISPATCH__',JSON.stringify(payload)),context);
 return {result,native,pending,receipts,logs,children,context,flush(){pending.forEach(t=>t.fire());}};
}
test('external UI waits for its own engine, uses the true asset directory, and shows exactly one window',()=>{
 const app=mount(`'use strict'; ui.setTitle(ui.scriptLocation + '/assets'); ui.add(new ui.Label('UI_OK')); ui.show(); ui.onClose=function(){return ui.scriptLocation;};`);
 assert.equal(app.result,'scheduled');assert.equal(app.native.shown,0);assert.equal(app.receipts.length,0);
 app.flush();app.flush();assert.equal(app.native.shown,1);assert.equal(app.native.title,"/External '中文/assets");assert.equal(app.children[0].text,'UI_OK');
 assert.equal(app.native.onClose(),"/External '中文");assert.equal(app.native.scriptLocation,'/Scripts');assert.equal(app.pending[0].active,false);assert.equal(app.context.cavalryToolbarUIRelayTask,null);
 assert.equal(app.receipts[0].value.status,'evaluated');
});
test('a native non-configurable scriptLocation remains untouched while the facade reports the external directory',()=>{
 const app=mount(`ui.add(new ui.Label(ui.scriptLocation)); ui.show();`);
 Object.defineProperty(app.native,'scriptLocation',{value:'/Scripts',writable:false,configurable:false});
 app.flush();assert.equal(app.children[0].text,"/External '中文");assert.equal(app.receipts[0].value.status,'evaluated');
});
test('source or runtime capability errors report partial execution rather than silently plain-loading',()=>{
 for(const options of [{},{noProxy:true}]){
  const app=mount(`throw new Error('fixture failed');`,options);app.flush();
  assert.equal(app.receipts[0].value.status,'error');assert.equal(app.pending[0].active,false);assert.ok(app.receipts[0].value.message);
 }
});
