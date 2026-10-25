#!/usr/bin/env node
// Generate reference results by executing real upstream economy.js for 200 turns.
// Isolated conditions: one hall, one city, 60 seconds/turn, immediate delivery,
// no deposits/terrain routing, no AI. Verifies the exact scope of Godot 0.5.
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {resolve,join,dirname} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';

const TYPES=['hall','lumber','saw','quarry','house','well','farm','mill','bakery','market','warehouse','cellar','vegetable_garden'];
const RESOURCE_KEYS=['bread','grain','flour','water','wood','plank','stone','berries','meat','fish','gold'];
const hash=data=>createHash('sha256').update(data).digest('hex');
const json=obj=>JSON.stringify(obj,null,2)+'\n';
const safeNumber=n=>Number(n??0);
const fields=(s)=>{
 const realm=s.realms[0],stock=realm.resources;
 return {
  time:safeNumber(s.time),pop:safeNumber(realm.pop),
  stock:Object.fromEntries(RESOURCE_KEYS.map(k=>[k,safeNumber(stock[k])])),
  housing:safeNumber(realm.housingCapacity),shortage:safeNumber(realm.shortageTurns),
  growthProgress:safeNumber(realm.growthProgress),growthNeed:safeNumber(realm.growthNeed),
  employed:safeNumber(realm.employed),marketVarieties:safeNumber(realm.marketFoodVarietiesV137),
  marketBonus:safeNumber(realm.marketFoodBonusV137),
  buildings:s.buildings.map(b=>({type:b.type,ready:!!b.ready,timer:safeNumber(b.timer),
   progress:safeNumber(b.progress),assigned:safeNumber(b.assigned),efficiency:safeNumber(b.efficiency)}))
 };
};
export async function generate({source,definitions,fixtures,commit='unknown'}){
 if(!source||!definitions||!fixtures)throw new Error('Need --source --definitions --fixtures');
 const input=resolve(source);
 const [economy,market,bronze]=await Promise.all([
  import(pathToFileURL(join(input,'economy.js')).href),
  import(pathToFileURL(join(input,'city-growth-v137.js')).href),
  import(pathToFileURL(join(input,'bronze-city-balance-v160.js')).href)
 ]);
 for(const key of TYPES)if(!economy.BUILDINGS[key])throw Error('Upstream building missing: '+key);
 for(const fn of [economy.tickEconomy,market.marketFoodGrowth,bronze.prosperousTownGrowth])if(typeof fn!=='function')throw Error('Upstream economy export missing');
 const exported={
  format:1, source_commit:commit,
  upstream_files: Object.fromEntries(await Promise.all(['economy.js','labor.js','city-needs-v87.js','city-growth-v137.js','bronze-city-balance-v160.js'].map(async path=>[path,hash(await readFile(join(input,path)))]))),
  start:economy.START,
  goods:(await import(pathToFileURL(join(input,'city-needs-v87.js')).href)).GOODS,
  buildings:Object.fromEntries(TYPES.map(k=>[k,{
   name:economy.BUILDINGS[k].name||k, workers:economy.BUILDINGS[k].workers||0,
   cost:economy.BUILDINGS[k].cost||{}, requires:economy.BUILDINGS[k].requires||[],
   age:economy.BUILDINGS[k].age||0,time:economy.BUILDINGS[k].time||0,
   ...(economy.BUILDINGS[k].out?{out:economy.BUILDINGS[k].out}:{}),
   ...(economy.BUILDINGS[k].input?{input:economy.BUILDINGS[k].input}:{}),
   ...(economy.BUILDINGS[k].rate?{rate:economy.BUILDINGS[k].rate}:{}),
   ...(economy.BUILDINGS[k].cycle?{cycle:economy.BUILDINGS[k].cycle}:{})
  }]))
 };
 await mkdir(dirname(resolve(definitions)),{recursive:true});
 await writeFile(resolve(definitions),json(exported));
 const cases=[
  {name:'founding',age:0,types:['hall'],pop:3,stock:{}},
  {name:'water-and-wood',age:0,types:['hall','well','lumber','quarry','house'],pop:4,stock:{bread:130,water:32}},
  {name:'food-production-chain',age:0,types:['hall','well','farm','mill','bakery','house','house','lumber','saw'],pop:6,stock:{bread:80,water:110,grain:65,flour:40}},
  {name:'shortage-and-recovery',age:0,types:['hall','house','well','lumber','quarry'],pop:5,stock:{bread:1,water:2,berries:0}},
  {name:'market-bonus',age:1,types:['hall','house','house','market','well','farm','mill','bakery','vegetable_garden'],pop:5,stock:{bread:170,water:180,vegetables:20,meat:20,fish:20,berries:20}},
  {name:'staffing-and-building',age:0,types:['hall','lumber','saw','house','well','quarry','farm','mill'],pop:3,stock:{bread:80,water:90},underConstruction:[2,5]},
 ];
 const scenarios=[];
 for(const cfg of cases){
  const stock={...economy.START,...cfg.stock};
  const buildings=cfg.types.map((type,i)=>({
   type,team:0,x:0,z:0,hp:type==='hall'?1200:350,
   ready:!(cfg.underConstruction||[]).includes(i),timer:0,progress:0
  }));
  const initial={time:0,age:cfg.age,buildings,realms:[{pop:cfg.pop,
   resources:stock, growthProgress:0,shortageTurns:0,tech:0,log:[]}],
   cargo:[], ended:false};
  const state=structuredClone(initial);
  const env={
   marketFoodGrowth:(_team,realm)=>market.marketFoodGrowth(state.buildings,realm.resources,realm.pop,cfg.age),
   bronzeGrowthMultiplier:(_team,realm)=>{
    const varieties=market.marketFoodGrowth(state.buildings,realm.resources,realm.pop,cfg.age).varieties.length;
    const housing=4+state.buildings.filter(b=>b.type==='house'&&b.ready&&b.hp>0).length*1.5;
    return bronze.prosperousTownGrowth({age:cfg.age,pop:realm.pop,stock:realm.resources,
      marketVarieties:varieties,housingFree:housing-realm.pop});
   }
  };
  const turns=[];
  for(let turn=0;turn<200;turn++){
   economy.tickEconomy(state,60,env);
   turns.push(fields(state));
  }
  scenarios.push({name:cfg.name,initial,turns});
 }
 const fixtureDoc={format:1,source_commit:commit,source_sha256:exported.upstream_files,scenarios};
 await mkdir(dirname(resolve(fixtures)),{recursive:true});
 await writeFile(resolve(fixtures),json(fixtureDoc));
 return {cases:scenarios.length,turns:scenarios.reduce((n,s)=>n+s.turns.length,0),recipes:TYPES.length};
}
const arg=k=>{const i=process.argv.indexOf('--'+k);return i<0?undefined:process.argv[i+1];};
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  console.log('CITY_V05_REFERENCE',JSON.stringify(await generate({
   source:arg('source'),definitions:arg('definitions')||'game/data/generated/city_buildings.json',
   fixtures:arg('fixtures')||'game/tests/city_v05_fixtures.json',commit:arg('commit')||'unknown'
  })));
 }catch(e){console.error('CITY_V05_REFERENCE FAILED',e.stack||e);process.exitCode=1;}
}
