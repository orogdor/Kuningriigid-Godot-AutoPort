#!/usr/bin/env node
import {mkdir,writeFile} from 'node:fs/promises';
import {resolve,dirname,join} from 'node:path';
import {pathToFileURL} from 'node:url';

const arg = (key) => {
  const pos=process.argv.indexOf('--'+key);
  return pos<0?null:process.argv[pos+1];
};
const source=arg('source');
const out=arg('out')||'game/tests/world_v06_fixtures.json';
const commit=arg('commit')||'unknown';
if(!source)throw Error('source path required');
const {continentLayout}=await import(pathToFileURL(join(resolve(source),'continent-map.js')).href);
const seeds=[12,19065,82026];
const cases=[];
for(const seed of seeds){
 for(const islands of [false,true]){
  const sourceWorld=continentLayout(seed,islands);
  cases.push({seed,islands,count:sourceWorld.count,
    bridges:sourceWorld.bridges,
    centers:sourceWorld.centers,
    polygons:sourceWorld.polygons,
    starts:sourceWorld.starts,
    islandCenters:sourceWorld.islands});
 }
}
await mkdir(dirname(resolve(out)),{recursive:true});
await writeFile(resolve(out),JSON.stringify({format:1,source_commit:commit,cases},null,2)+'\n');
console.log('WORLD_V06_REFERENCE',cases.length,'seeded worlds from real continent-map.js');
