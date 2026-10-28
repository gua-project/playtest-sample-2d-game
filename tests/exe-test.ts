import {strict as assert} from 'node:assert';
import {mkdirSync, writeFileSync} from 'node:fs';
const port=process.env.GUA_BRIDGE_PORT??'8793';
const mode=process.env.GUILD_TEST_MODE??'normal';
const output=process.env.GUILD_EVIDENCE??`output/evidence-${mode}`;
mkdirSync(output,{recursive:true});
const transcript:any[]=[];
const socket=new WebSocket(`ws://127.0.0.1:${port}`);
await new Promise<void>((resolve,reject)=>{socket.onopen=()=>resolve(); socket.onerror=reject;});
let id=0;
const waiting=new Map<number,any>();
socket.onmessage=e=>{const response=JSON.parse(String(e.data)); const callback=waiting.get(response.id); if(callback){waiting.delete(response.id); callback(response);}};
async function request(type:string, extra:any={}) {
 const key=++id;
 const result:any=await new Promise((resolve,reject)=>{
  const timer=setTimeout(()=>{waiting.delete(key);socket.close();reject(new Error(`timeout ${type}`));},6000);
  waiting.set(key,(value:any)=>{clearTimeout(timer);resolve(value)});
  socket.send(JSON.stringify({id:key,type,...extra}));
 });
 transcript.push({request:{id:key,type,...extra},response:result});
 assert.equal(result.ok,true,JSON.stringify(result)); return result.result;
}
async function click(nodeId:string) {
 const tree=await request('get_ui_tree');
 assert.ok(tree.nodes.some((n:any)=>n.id===nodeId&&n.visible&&n.enabled),`missing ${nodeId} on ${tree.screen}`);
 const receipt=await request('click_node',{nodeId});
 assert.ok(Number.isSafeInteger(receipt?.requestId)&&receipt.requestId>0,'missing action receipt');
 {
  let completed=false;
  for(let i=0;i<100;i++){
   const result=await request('poll_events',{requestId:receipt.requestId});
   if(result){assert.equal(result.requestId,receipt.requestId);assert.equal(result.nodeId,nodeId);assert.equal(result.succeeded,true,JSON.stringify(result)); completed=true;break;}
   await Bun.sleep(20);
  }
  assert.ok(completed,`incomplete ${nodeId}`);
 }
 await Bun.sleep(60);
}
async function state(){
 const observation=await request('get_observe_snapshot');
 const entry=observation.document.entries.find((e:any)=>e.name==='state');
 assert.ok(entry,JSON.stringify(observation)); return JSON.parse(entry.value.value);
}
async function shot(name:string){
 const image=await request('get_screenshot');
 if(image?.dataUri?.startsWith('data:image/png;base64,')) writeFileSync(`${output}/${name}.png`,Buffer.from(image.dataUri.split(',')[1],'base64'));
 else transcript.push({screenshot:name,status:'unavailable',result:image});
}
try {
 const version=await request('get_version');
 writeFileSync(`${output}/version.json`,JSON.stringify(version,null,2));
 await click('start'); await click('talk'); await click('talk_supplies'); await click('back');
 const initial=await state(); assert.equal(initial.day,1);
 assert.deepEqual(initial.bugs,mode==='normal'?[]:[mode]);
 await Bun.sleep(1200); assert.equal((await state()).day,1);
 await click('shop');
 const shop=await request('get_ui_tree');
 const quantityLabel=shop.nodes.find((n:any)=>n.label==='数量: 1'||n.label==='Quantity: 1');
 assert.ok(quantityLabel?.bounds.w>=150,'quantity text must have readable width');
 await click('buy');
 const confirmation=await request('get_ui_tree'); assert.equal(confirmation.screen,'confirmation');
 assert.ok(!confirmation.nodes.some((n:any)=>n.id==='back'));
 await click('cancel_trade');
 const afterCancel=await state();
 assert.equal(afterCancel.gold, mode==='cancel_charge'?56:60);
 if(mode==='cancel_charge') {assert.notEqual(afterCancel.gold,initial.gold); await shot('cancel-defect');}
 else {
  for(const [item,qty] of [['herb',3],['rope',2],['crystal',2]] as const){
   await click('select_'+item);
   for(let i=1;i<qty;i++)await click('qty_plus');
   await click('buy');await click('confirm_trade');
   for(let i=1;i<qty;i++)await click('qty_minus');
  }
  await click('back'); await click('inventory');await click('bag_herb');await click('sort');
  const obs=await request('get_observe_snapshot');
  const selection=obs.document.entries.find((e:any)=>e.name==='selection').value.value;
  assert.equal(selection,mode==='sort_target'?'rope':'herb');
  if(mode==='sort_target') {assert.notEqual(selection,'herb');await shot('sort-defect');}
  else {
   await click('back'); await click('quests');
   for(let i=0;i<3;i++)await click('accept_'+i);
   for(let i=0;i<3;i++){
    await click('choose_item');await click('bag_'+['herb','rope','crystal'][i]);await click('to_requests');
    for(let j=0;j<[3,2,2][i];j++) {
     await click('deliver_'+i);
     if(i===0&&j===0){
      await click('back'); await click('pause');await click('save');await click('load');
      assert.equal((await state()).quests[0].delivered,1);
      await click('quests');
     }
    }
    await click('claim_'+i);
    if(i===0){
     const before=(await state()).gold;await click('claim_0');
     assert.equal((await state()).gold,before+(mode==='double_reward'?20:0));
    }
   }
   assert.equal((await request('get_ui_tree')).screen,'result');
   assert.ok((await state()).quests.every((q:any)=>q.status==='done'));
   await shot('result-ja');
   await click('pause');await click('save');await click('settings');await click('language');await click('size_880');
   await shot('settings-en-880');await click('settings_back');await click('load');
   assert.equal((await request('get_ui_tree')).screen,'result');
   await click('replay');assert.equal((await state()).gold,60);assert.equal((await state()).day,1);
   await click('next_day');assert.equal((await state()).day,2);
  }
 }
 writeFileSync(`${output}/final-state.json`,JSON.stringify(await state(),null,2));
 console.log(`PASS EXE ${mode}`);
} catch(error){transcript.push({error:String(error)});console.error(error);process.exitCode=1;}
finally {writeFileSync(`${output}/transcript.json`,JSON.stringify(transcript,null,2));socket.close();}
