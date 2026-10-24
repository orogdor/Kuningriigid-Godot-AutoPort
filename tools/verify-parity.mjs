#!/usr/bin/env node
import {readFile} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {readExportedLiteral} from './static-literal.mjs';
import {TABLES,validate,SOURCE} from './port.mjs';
const sha=s=>createHash('sha256').update(s).digest('hex');
const arg=name=>{const i=process.argv.indexOf('--'+name);return i<0?undefined:process.argv[i+1];};
export async function verify(source,out){
  const manifest=JSON.parse(await readFile(join(out,'manifest.json'),'utf8'));
  assert.equal(manifest.format,1);assert.equal(manifest.source_repository,SOURCE);
  const tables={};
  for(const [table,[path,name]] of Object.entries(TABLES)){
    const input=await readFile(join(source,path),'utf8');
    const output=await readFile(join(out,table+'.json'),'utf8');
    const spec=manifest.tables[table];
    assert.equal(spec.path,path);assert.equal(spec.export,name);
    assert.equal(spec.source_sha256,sha(input));assert.equal(spec.sha256,sha(output));
    tables[table]=JSON.parse(output);
    assert.deepEqual(tables[table],JSON.parse(JSON.stringify(readExportedLiteral(input,name))),table+' differs from the Three.js source');
  }
  assert.deepEqual(manifest.counts,validate(tables));
  return manifest.counts;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  try{
    const source=arg('source'),out=arg('out')||'game/data/generated';
    assert(source,'Missing --source <checkout>');
    console.log('SOURCE_PARITY_OK:',JSON.stringify(await verify(resolve(source),resolve(out))));
  }catch(err){console.error('PARITY FAILED:',err.stack||err);process.exitCode=1;}
}
