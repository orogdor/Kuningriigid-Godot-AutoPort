#!/usr/bin/env node
// Detect drift in the precise upstream definitions ported by military_v54.gd.
// Runtime calculations are based on the real economy.js, military-v88,
// ai-development-v128 and unit-balance-v99 modules, not guessed prices.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
const flag=process.argv.indexOf('--source');
if(flag<0||!process.argv[flag+1])throw Error('Usage: --source <Three.js checkout>');
const dir=resolve(process.argv[flag+1]);
const core=await readFile(join(dir,'civilization-core.js'),'utf8');
for(const statement of [
 "Object.assign(BUILDINGS.barracks,{name:'Sõdalaste laager',cost:{wood:35,stone:15},requires:['lumber','quarry']});",
 "BUILDINGS.barracks.requires=['hall']",
 "slinger:{name:'Kiviviskajad',age:0,cost:{wood:8,stone:18}",
 "spearman:{name:'Puuodamehed',age:0,cost:{wood:22,stone:4}",
 "axeman:{name:'Kivikirvemehed',age:0,cost:{wood:14,stone:14}",
 "for(const [kind,d]of Object.entries(TROOPS))d.time={scout:18,slinger:25,spearman:30,axeman:35"
])assert.ok(core.includes(statement),'Upstream military definition changed: '+statement);
const base=(await import(pathToFileURL(join(dir,'economy.js')).href)).BUILDINGS;
const ai=(await import(pathToFileURL(join(dir,'ai-development-v128.js')).href));
const v99=(await import(pathToFileURL(join(dir,'unit-balance-v99.js')).href));
const barracks={...base.barracks,name:'Sõdalaste laager',cost:{wood:35,stone:15},requires:['hall']};
const defs={...base,barracks};
const units={
 slinger:{cost:{wood:8,stone:18},time:25,hp:85,role:'ranged',age:0},
 spearman:{cost:{wood:22,stone:4},time:30,hp:125,role:'melee',age:0},
 axeman:{cost:{wood:14,stone:14},time:35,hp:140,role:'melee',age:0}
};
v99.balanceUnitDefinitions(units);
ai.applyDevelopmentBalance(defs,units);
assert.deepEqual(barracks.cost,{wood:20,stone:9});
assert.equal(barracks.time,18);
const expected={
 slinger:{cost:{wood:6,stone:12},time:19,hp:170},
 spearman:{cost:{wood:15,stone:3},time:23,hp:250},
 axeman:{cost:{wood:10,stone:10},time:27,hp:280}
};
for(const [name,values] of Object.entries(expected)){
 assert.deepEqual(units[name].cost,values.cost);
 assert.equal(units[name].time,values.time);
 assert.equal(units[name].hp,values.hp);
}
const gd=await readFile('game/scripts/military_v54.gd','utf8');
for(const text of ['"wood":20.0,"stone":9.0','"wood":6.0,"stone":12.0',
 '"wood":15.0,"stone":3.0','"wood":10.0,"stone":10.0',
 '"seconds":19.0,"hp":170.0','"seconds":23.0,"hp":250.0',
 '"seconds":27.0,"hp":280.0']){
 assert.ok(gd.includes(text),'Godot V54 snapshot changed: '+text);
}
console.log('MILITARY_SOURCE_V54 SUCCESS: source camp and 3 units match final V128/V99/V88 balances');
