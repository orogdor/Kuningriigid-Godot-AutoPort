#!/usr/bin/env node
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
const index=process.argv.indexOf('--source');
if(index<0||!process.argv[index+1])throw Error('--source <upstream> is required');
const base=resolve(process.argv[index+1]);
const collision=await import(pathToFileURL(join(base,'soldier-collision-v90.js')).href);
const contact=await import(pathToFileURL(join(base,'combat-contact-v96.js')).href);
const formations=await import(pathToFileURL(join(base,'formations-v94.js')).href);
const battle=await import(pathToFileURL(join(base,'individual-battle-v91.js')).href);
assert.equal(collision.soldierCount({kind:'spearman'}),24);
assert.equal(collision.soldierCount({kind:'axeman'}),24);
assert.equal(collision.soldierCount({kind:'slinger'}),24);
assert.equal(contact.soldierBodyRadius({kind:'spearman'}),.34);
assert.equal(contact.meleeReach({kind:'spearman'},{radius:.34},{radius:.34}),1.73);
assert.equal(battle.MAX_BATTLE_MEN,500);
const line=formations.formationSlot({kind:'spearman',formation:'line'},0,24);
const spear=formations.formationSlot({kind:'spearman',formation:'spear_wall'},0,24);
const loose=formations.formationSlot({kind:'slinger',formation:'loose'},0,24);
for(const [got,expected] of [[line.x,-1.575],[line.z,-2.625],[spear.x,-1.35],[spear.z,-2.5],[loose.x,-2.4],[loose.z,-4]]){
 assert.ok(Math.abs(got-expected)<1e-9,'V94 source formation slot changed: '+got+' vs '+expected);
}
const gd=await readFile('game/scripts/individual_v56.gd','utf8');
for(const term of ['const PER_SQUAD: int=24','const BODY_RADIUS: float=0.34',
 'const LINE_X: float=337.5','const MAX_MEN: int=216','static func formation_slot(',
 'static func _attack(','static func _march_man(','static func _aggregate(']){
 assert.ok(gd.includes(term),'Godot individual actor system missing '+term);
}
const raider=await readFile('game/scripts/raider_v56.gd','utf8');
assert.ok(raider.includes('static func colliding_ids('));
assert.ok(raider.includes('static func tick('));
const content=await readFile('game/scripts/content.gd','utf8');
assert.ok(content.includes('Battle55.start_campaign('));
assert.ok(content.includes('Raider56.tick('));
console.log('INDIVIDUAL_SOURCE_V56 SUCCESS: 24-man squads, V94 slot spacing, V96 body/reach, 500-source cap; mobile slice capped at 216');
