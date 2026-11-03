#!/usr/bin/env node
// Verify the small source-grounded tactical slice without claiming the
// complete Three.js 24-man / projectile / siege combat engine has been ported.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
const index=process.argv.indexOf('--source');
if(index<0||!process.argv[index+1])throw Error('--source <upstream checkout> required');
const source=resolve(process.argv[index+1]);
const moduleOf=file=>import(pathToFileURL(join(source,file)).href);
const {BATTLEFIELD:battlefield,battlefieldTiles}=await moduleOf('battlefield-v88.js');
const {BATTLE_TIME_SCALE}=await moduleOf('battle-pacing-v93.js');
const forms=(await moduleOf('formations-v94.js')).FORMATIONS;
const {formationOptions}=await moduleOf('formations-v94.js');
assert.equal(battlefield.columns,3);
assert.equal(battlefield.rows,3);
assert.equal(battlefield.ring,1);
assert.equal(battlefield.tileWidth,225);
assert.equal(battlefield.tileDepth,195);
assert.equal(battlefield.minX,-337.5);
assert.equal(battlefield.maxX,337.5);
assert.equal(battlefield.minZ,-292.5);
assert.equal(battlefield.outerMaxX,562.5);
assert.equal(battlefield.outerMaxZ,487.5);
assert.equal(battlefieldTiles({c:50,r:50}).length,25);
assert.equal(battlefieldTiles({c:50,r:50}).filter(x=>x.retreat).length,16);
assert.equal(BATTLE_TIME_SCALE,0.5);
assert.equal(forms.line.speed,1);
assert.equal(forms.hold.speed,0.8);
assert.equal(forms.spear_wall.speed,0.35);
assert.equal(forms.loose.speed,1);
assert.equal(forms.skirmish.speed,1);
assert.ok(formationOptions({kind:'spearman'},{spearman:{age:0}}).includes('spear_wall'));
assert.ok(formationOptions({kind:'slinger'},{slinger:{age:0}}).includes('loose'));
assert.ok(!formationOptions({kind:'axeman'},{axeman:{age:0}}).includes('spear_wall'));
const battle=await readFile('game/scripts/battle_v55.gd','utf8');
for(const constant of [
 'const SCALE: float=0.5',
 'const HALF_X: float=337.5',
 'const HALF_Z: float=292.5',
 'const OUTER_X: float=562.5',
 'const OUTER_Z: float=487.5',
 '"spear_wall":{"speed":0.35',
 '"hold":{"speed":0.8'
])assert.ok(battle.includes(constant),'Missing source-grounded detail '+constant);
assert.ok(battle.includes('opposing raider')||battle.includes('opposing raider'.replace('opposing','opposing')),
 'Skirmish must clearly remain labeled as opt-in demo, not campaign combat');
console.log('BATTLE_SOURCE_V55 SUCCESS: original 3x3 battlefield, 16 retreat tiles, speed, 3 Stone Age formations');
