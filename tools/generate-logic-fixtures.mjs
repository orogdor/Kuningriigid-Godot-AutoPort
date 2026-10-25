#!/usr/bin/env node
// Evaluate real upstream JS functions on deterministic inputs. Godot must agree.
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {join,resolve,dirname} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';

const MODULES=['growth-balance-v125.js','bronze-city-balance-v160.js'];
const ageList=[-1,0,1,2,3,4,5,6,7];
const times=[-60,0,540,599,600,601,1559,1560,1561,5700,18000,36000];
const pops=[0,1,3,7,11,12,18,25,29,30,50,100];
const foodRatios=[0,0.5,1.1,1.59,1.6,2.2,2.99,3,5];
const houses=[-1,0,0.5,1,2,6];

export async function generate({source,out,commit='unknown'}){
  if(!source||!out)throw new Error('Expected --source and --out');
  const sourceHashes={};
  for(const name of MODULES)sourceHashes[name]=createHash('sha256').update(await readFile(join(resolve(source),name))).digest('hex');
  // These modules have no imports in upstream; use real exports without copying formulas.
  const a=await import(pathToFileURL(join(resolve(source),MODULES[0])).href);
  const b=await import(pathToFileURL(join(resolve(source),MODULES[1])).href);
  const required=[a.cityCapacity,a.settlerPolicy,a.armyCapacity,a.knowledgeCostFactor,a.knowledgeCityMultiplier,b.prosperousTownGrowth];
  if(required.some(fn=>typeof fn!=='function'))throw new Error('Upstream gameplay function missing; fail closed');
  const cases=[];
  const add=(fn,input,result)=>cases.push({fn,input,expected:result});
  for(let i=0;i<144;i++){
    const age=ageList[i%ageList.length], time=times[i%times.length];
    const pop=pops[i%pops.length], cities=i%17, pending=i%4;
    add('city_capacity',{time,age},a.cityCapacity(time,age));
    const args={time,age,cities,pending,pop,food:Math.max(0,pop*foodRatios[i%foodRatios.length]),lastAt:times[(i+5)%times.length],hasSettlement:i%5!==0};
    add('settler_policy',args,a.settlerPolicy(args));
    add('army_capacity',{ownCities:cities,age,atWar:i%2===0},a.armyCapacity(cities,age,i%2===0));
    add('knowledge_cost_factor',{age},a.knowledgeCostFactor(age));
    const n=[0,1,2,3,6,10,20,45,100,i/3][i%10];
    add('knowledge_city_multiplier',{n},a.knowledgeCityMultiplier(n));
    const waterMultiplier=[0,1.09,1.1,1.5,4][i%5];
    const stock={bread:pop*foodRatios[i%foodRatios.length]*0.5,
      flour:pop*foodRatios[(i+2)%foodRatios.length]*0.2,
      grain:pop*foodRatios[(i+4)%foodRatios.length]*0.15,
      meat:pop*foodRatios[(i+6)%foodRatios.length]*0.1,
      fish:i%4,berries:i%3,vegetables:i%5,fruit:i%2,cheese:i%6,
      water:pop*waterMultiplier};
    const town={age,pop,stock,marketVarieties:i%5,housingFree:houses[i%houses.length]};
    add('prosperous_town_growth',town,b.prosperousTownGrowth(town));
  }
  const doc={format:1,source_commit:commit,source_modules_sha256:sourceHashes,cases};
  await mkdir(dirname(resolve(out)),{recursive:true});
  await writeFile(resolve(out),JSON.stringify(doc,null,2)+'\n');
  return {total:cases.length,functions:6,sourceHashes};
}
const direct=process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url);
if(direct){
  const arg=k=>{const i=process.argv.indexOf('--'+k);return i<0?undefined:process.argv[i+1];};
  try{
    const result=await generate({source:arg('source'),out:arg('out')||'game/tests/logic_parity_cases.json',commit:arg('commit')});
    console.log('UPSTREAM_LOGIC_FIXTURES:',JSON.stringify(result));
  }catch(err){console.error('LOGIC FIXTURE GENERATION FAILED:',err.stack||err);process.exitCode=1;}
}
