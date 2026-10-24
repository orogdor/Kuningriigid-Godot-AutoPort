import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,readFile,readdir,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {readExportedLiteral,LiteralSyntaxError} from '../tools/static-literal.mjs';
import {convert,TABLES} from '../tools/port.mjs';
import {verify} from '../tools/verify-parity.mjs';

test('static parser accepts literal JS objects, comments and trailing commas',()=>{
  const input="// test\nexport const SAMPLE = {foo:'Tere',bar:[.85,-2,true,null,], /* note */ nested:{age:3,},};";
  assert.deepEqual(JSON.parse(JSON.stringify(readExportedLiteral(input,'SAMPLE'))),
    {foo:'Tere',bar:[.85,-2,true,null],nested:{age:3}});
});
test('unsafe JS expressions are rejected and never executed',()=>{
  globalThis.autoportUnsafeProbe=0;
  for(const expr of ['(globalThis.autoportUnsafeProbe=42)','process.exit(9)','{x:foo()}','{...other}','[1+2]']){
    assert.throws(()=>readExportedLiteral('export const A = '+expr+';','A'),LiteralSyntaxError);
  }
  assert.equal(globalThis.autoportUnsafeProbe,0);
  delete globalThis.autoportUnsafeProbe;
});
test('duplicate and dangerous keys and missing export are rejected',()=>{
  for(const code of ['export const A = {__proto__:4};','export const A = {x:1,x:2};',
      'const A = {x:1};','export const A=[1]; export const A=[2];']){
    assert.throws(()=>readExportedLiteral(code,'A'),LiteralSyntaxError);
  }
});

async function fixture(folder){
  const tech=Object.fromEntries(Array.from({length:83},(_,i)=>
    ['tech_'+i,{name:'Tech '+i,age:i%7,requires:i?['tech_'+(i-1)]:[]}]));
  const source={
    tech_tree:tech,tech_reforms:{civic:{name:'Civic',age:1}},
    production_reforms:[{id:'civic',outputs:['food'],bonus:.05}],
    goods:{meat:{name:'Meat',age:0,food:true}},
    good_buildings:{hunter:{name:'Hunter',age:0,out:'meat'}},
    food_needs:Array.from({length:7},(_,i)=>({food:i+1,luxury:i})),
    era_costs:{bronze:{wood:35},iron:{stone:50},civics:{iron:20},
      renaissance:{iron:35},industrialization:{plank:120},modernity:{steel:35}},
    era_techs:{bronze:1},bronze_min_turns:95,bronze_fortify_pop:18,bronze_full_wall_pop:25,
    science_per_resident:1,science_per_city:0,science_per_turn:10,eureka_fraction:.35
  };
  const files=new Map();
  for(const [table,[path,name]] of Object.entries(TABLES))
    files.set(path,(files.get(path)||'')+'export const '+name+' = '+JSON.stringify(source[table])+';\n');
  for(const [path,content] of files)await writeFile(join(folder,path),content);
  return source;
}

test('full conversion preserves provenance, JSON values and output hashes',async t=>{
  const temp=await mkdtemp(join(tmpdir(),'autoport-'));
  t.after(()=>rm(temp,{recursive:true,force:true}));
  const src=join(temp,'source'),out=join(temp,'out'),again=join(temp,'again');
  await mkdir(src);
  const original=await fixture(src);
  const result=await convert({source:src,out,commit:'0123456789abcdef'});
  assert.equal(result.source_commit,'0123456789abcdef');
  assert.equal(result.counts.technologies,83);
  assert.equal(result.counts.era_tiers,6);
  assert.equal(Object.keys(result.tables).length,Object.keys(TABLES).length);
  const manifest=JSON.parse(await readFile(join(out,'manifest.json'),'utf8'));
  assert.deepEqual(manifest,JSON.parse(JSON.stringify(result)));
  for(const [table,meta] of Object.entries(result.tables)){
    const bytes=await readFile(join(out,meta.file));
    assert.equal(createHash('sha256').update(bytes).digest('hex'),meta.sha256);
    assert.deepEqual(JSON.parse(bytes),original[table]);
  }
  assert.deepEqual(await verify(src,out),result.counts);
  await convert({source:src,out:again,commit:'0123456789abcdef'});
  assert.deepEqual((await readdir(out)).sort(),(await readdir(again)).sort());
  for(const file of await readdir(out))assert.deepEqual(await readFile(join(out,file)),await readFile(join(again,file)),file);
});

test('unknown technology prerequisites fail closed',async t=>{
  const temp=await mkdtemp(join(tmpdir(),'autoport-invalid-'));
  t.after(()=>rm(temp,{recursive:true,force:true}));
  const src=join(temp,'source');await mkdir(src);
  const tables=await fixture(src);
  tables.tech_tree.tech_7.requires=['ghost'];
  await writeFile(join(src,'tech-tree-data-v118.js'),'export const TECH_TREE_V118 = '+JSON.stringify(tables.tech_tree)+';\n');
  await assert.rejects(convert({source:src,out:join(temp,'out')}),/Missing prerequisite/);
});

test('parity verification detects corrupted destination file',async t=>{
  const temp=await mkdtemp(join(tmpdir(),'autoport-corrupted-'));
  t.after(()=>rm(temp,{recursive:true,force:true}));
  const src=join(temp,'source'),out=join(temp,'out');
  await mkdir(src);await fixture(src);await convert({source:src,out});
  assert.equal((await verify(src,out)).technologies,83);
  await writeFile(join(out,'bronze_min_turns.json'),'96\n');
  await assert.rejects(verify(src,out),/Expected values to be strictly equal|differs/);
});
