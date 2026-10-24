/**
 * Parse static JavaScript export const literals without executing source code.
 * Supported: objects, arrays, strings, finite numbers, booleans and null.
 * Reject functions, spreads, identifiers as values and ambiguous object keys.
 */
export class LiteralSyntaxError extends Error {}

export function readExportedLiteral(source, name) {
  if (!/^[A-Za-z_$][\w$]*$/.test(name)) throw new LiteralSyntaxError('Invalid export name');
  const re = new RegExp('\\bexport\\s+const\\s+'+name+'\\s*=', 'g');
  const matches = [...source.matchAll(re)];
  if (matches.length!==1) throw new LiteralSyntaxError('Expected exactly one export const '+name+'; found '+matches.length);
  let i=matches[0].index+matches[0][0].length;
  const fail=message=>{throw new LiteralSyntaxError(name+': '+message+' at byte '+i);};
  const ws=()=>{
    while(i<source.length){
      if(/\s/.test(source[i])){i++;continue;}
      if(source.slice(i,i+2)==='//'){const end=source.indexOf('\n',i+2);i=end<0?source.length:end;continue;}
      if(source.slice(i,i+2)==='/*'){const end=source.indexOf('*/',i+2);if(end<0)fail('Unterminated comment');i=end+2;continue;}
      break;
    }
  };
  const quoted=()=>{
    const quote=source[i++];let result='';
    while(i<source.length){
      let c=source[i++];
      if(c===quote)return result;
      if(c==='\n'||c==='\r')fail('Newline in string');
      if(c!=='\\'){result+=c;continue;}
      if(i>=source.length)fail('Unterminated string escape');
      c=source[i++];
      const map={n:'\n',r:'\r',t:'\t',b:'\b',f:'\f',v:'\v','0':'\0'};
      if(Object.hasOwn(map,c)){result+=map[c];continue;}
      if(c==='u'||c==='x'){
        const size=c==='u'?4:2,chunk=source.slice(i,i+size);
        if(!new RegExp('^[0-9a-fA-F]{'+size+'}$').test(chunk))fail('Invalid unicode escape');
        result+=String.fromCharCode(parseInt(chunk,16));i+=size;continue;
      }
      if(c==='\n')continue;
      if(!['\\','"',"'",'/'].includes(c))fail('Unsupported string escape');
      result+=c;
    }
    fail('Unterminated string');
  };
  const identifier=()=>{
    const m=/^[A-Za-z_$][\w$]*/.exec(source.slice(i));
    if(!m)fail('Invalid identifier');i+=m[0].length;return m[0];
  };
  let nodes=0;
  const value=(depth=0)=>{
    ws();
    if(depth>48||++nodes>40000)fail('Literal exceeds safety limit');
    if(i>=source.length)fail('Unexpected end');
    if(source[i]==='"'||source[i]==="'")return quoted();
    if(source[i]==='{'){
      i++;const result=Object.create(null);ws();
      if(source[i]==='}'){i++;return result;}
      while(true){
        ws();const key=source[i]==='"'||source[i]==="'"?quoted():identifier();
        if(['__proto__','constructor','prototype'].includes(key))fail('Forbidden key');
        ws();if(source[i++]!==':')fail('Expected colon after '+key);
        if(Object.hasOwn(result,key))fail('Duplicate key '+key);
        result[key]=value(depth+1);ws();
        const c=source[i++];if(c==='}')return result;if(c!==',')fail('Expected comma or }');
        ws();if(source[i]==='}'){i++;return result;}
      }
    }
    if(source[i]==='['){
      i++;const a=[];ws();if(source[i]===']'){i++;return a;}
      while(true){
        a.push(value(depth+1));ws();const c=source[i++];
        if(c===']')return a;if(c!==',')fail('Expected comma or ]');
        ws();if(source[i]===']'){i++;return a;}
      }
    }
    if(/[\d.\-]/.test(source[i])){
      const m=/^-?(?:(?:\d+\.?\d*|\.\d+))(?:[eE][+-]?\d+)?/.exec(source.slice(i));
      if(!m)fail('Invalid number');i+=m[0].length;const n=Number(m[0]);
      if(!Number.isFinite(n))fail('Nonfinite number');return n;
    }
    if(/[A-Za-z_$]/.test(source[i])){
      const id=identifier();
      if(id==='true')return true;if(id==='false')return false;if(id==='null')return null;
      fail('Unsupported expression '+id);
    }
    fail('Unsupported token '+source[i]);
  };
  const extracted=value();ws();
  if(i<source.length&&![';',','].includes(source[i]))fail('Unexpected text after literal');
  return extracted;
}
