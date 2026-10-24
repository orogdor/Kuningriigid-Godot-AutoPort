#!/usr/bin/env node
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {readExportedLiteral} from './static-literal.mjs';

export const SOURCE='https://github.com/orogdor/Kuningriigid';
export const TABLES=Object.freeze({
  tech_tree:['tech-tree-data-v118.js','TECH_TREE_V118'],
  tech_reforms:['technology-reforms-v125.js','TECHS_V125'],
  production_reforms:['technology-reforms-v125.js','PRODUCTION_REFORMS_V125'],
  goods:['city-needs-v87.js','GOODS'],
  good_buildings:['city-needs-v87.js','GOOD_BUILDINGS'],
  food_needs:['city-needs-v87.js','NEEDS'],
  era_costs:['era-economy.js','ERA_MATERIALS'],
  era_techs:['era-economy.js','ERA_TECHS'],
  bronze_min_turns:['bronze-city-balance-v160.js','MIN_BRONZE_TURNS_V160'],
  bronze_fortify_pop:['bronze-city-balance-v160.js','BRONZE_FORTIFY_POP_V160'],
  bronze_full_wall_pop:['bronze-city-balance-v160.js','BRONZE_FULL_WALL_POP_V160'],
  science_per_resident:['science.js','SCIENCE_PER_RESIDENT'],
  science_per_city:['science.js','SCIENCE_PER_CITY'],
  science_per_turn:['science.js','SCIENCE_PER_TURN'],
  eureka_fraction:['science.js','EUREKA_FRACTION']
});
const stable=value=>{
  if(Array.isArray(value))return value.map(stable);
  if(value!==null && typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(k=>[k,stable(value[k])]));
  return value;
};
const json=value=>JSON.stringify(stable(value),null,2)+'\n';
const sha=data=>createHash('sha256').update(data).digest('hex');
const ensure=(truth,message)=>{if(!truth)throw new Error(message);};

export function validate(tables){
  for(const key of Object.keys(TABLES))ensure(Object.hasOwn(tables,key),'Missing table '+key);
  ensure(Object.keys(tables.tech_tree).length>=80,'Too few technologies');
  for(const [id,tech] of Object.entries(tables.tech_tree)){
    ensure(typeof tech.name==='string'&&Number.isInteger(tech.age)&&tech.age>=0&&tech.age<=6,'Invalid technology '+id);
    for(const dep of [...(tech.requires||[]),...(tech.oneOf||[])])
      ensure(Object.hasOwn(tables.tech_tree,dep)||Object.hasOwn(tables.tech_reforms,dep),'Missing prerequisite '+dep+' for '+id);
  }
  ensure(Object.keys(tables.era_costs).length===6,'Expected six era-cost tiers');
  for(const [age,costs] of Object.entries(tables.era_costs))
    for(const [resource,cost] of Object.entries(costs))
      ensure(Number.isFinite(cost)&&cost>0,'Invalid price '+age+'/'+resource);
  ensure(Array.isArray(tables.food_needs)&&tables.food_needs.length===7,'Expected seven food need tiers');
  ensure(tables.bronze_min_turns>=1&&tables.bronze_fortify_pop<tables.bronze_full_wall_pop,'Invalid Bronze town thresholds');
  ensure(tables.science_per_resident===1,'Expected one science point per resident');
  const visited=new Set(),visiting=new Set();
  const visit=id=>{
    if(visiting.has(id))throw new Error('Research prerequisite cycle at '+id);
    if(visited.has(id))return;
    visiting.add(id);
    for(const dep of tables.tech_tree[id].requires||[])
      if(Object.hasOwn(tables.tech_tree,dep))visit(dep);
    visiting.delete(id);visited.add(id);
  };
  for(const id of Object.keys(tables.tech_tree))visit(id);
  return {technologies:Object.keys(tables.tech_tree).length,
    reform_technologies:Object.keys(tables.tech_reforms).length,
    goods:Object.keys(tables.goods).length,
    good_buildings:Object.keys(tables.good_buildings).length,
    era_tiers:Object.keys(tables.era_costs).length};
}

export async function convert({source,out,commit='unknown'}){
  ensure(source&&out,'Pass --source <checkout> and --out <generated folder>');
  const tables=Object.create(null),provenance=Object.create(null),input=new Map();
  for(const [table,[path,identifier]] of Object.entries(TABLES)){
    if(!input.has(path))input.set(path,await readFile(join(resolve(source),path),'utf8'));
    tables[table]=readExportedLiteral(input.get(path),identifier);
    provenance[table]={path,export:identifier,source_sha256:sha(input.get(path))};
  }
  const counts=validate(tables),files={};
  await mkdir(resolve(out),{recursive:true});
  for(const [table,data] of Object.entries(tables)){
    const filename=table+'.json',body=json(data);
    await writeFile(join(resolve(out),filename),body);
    files[table]={...provenance[table],file:filename,sha256:sha(body)};
  }
  const manifest={format:1,source_repository:SOURCE,source_branch:'main',
    source_commit:commit,tables:files,counts,
    procedural_not_ported:['Three.js rendering','navigation and animation',
      'economy tick functions','city construction runtime',
      'research progression','battle simulation','AI decisions']};
  await writeFile(join(resolve(out),'manifest.json'),json(manifest));
  return manifest;
}
function arg(name){const i=process.argv.indexOf('--'+name);return i<0?undefined:process.argv[i+1];}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  try{
    const source=arg('source'),out=arg('out')||'game/data/generated';let commit=arg('commit');
    if(!commit){try{commit=execFileSync('git',['-C',source,'rev-parse','HEAD'],{encoding:'utf8'}).trim();}catch{commit='unknown';}}
    const manifest=await convert({source,out,commit});
    console.log('GODOT_RULES_EXPORTED:',JSON.stringify(manifest.counts),'to',resolve(out));
  }catch(err){console.error('PORT FAILED:',err.stack||err);process.exitCode=1;}
}
