package main

// Native Windows bootstrapper. Downloads only changed files from immutable Git
// commits, verifies SHA-256, and keeps a known-good version for offline startup.
import (
 "context"
 "crypto/sha256"
 "encoding/hex"
 "encoding/json"
 "errors"
 "fmt"
 "io"
 "net/http"
 "os"
 "os/exec"
 "path/filepath"
 "regexp"
 "strings"
 "time"
)

const releasesAPI = "https://api.github.com/repos/orogdor/Kuningriigid-Godot-AutoPort/releases/latest"
const sourceRoot = "https://raw.githubusercontent.com/orogdor/Kuningriigid-Godot-AutoPort/"
const engineAsset = "Kuningriigid-Engine.exe"
const manifestAsset = "Windows-files.json"

var hexHash = regexp.MustCompile("^[a-f0-9]{64}$")
var commitHash = regexp.MustCompile("^[a-f0-9]{40}$")
var client = &http.Client{} // Use per-request context: 45 s metadata, 6 min engine download.

type asset struct {
 Name string `json:"name"`
 URL string `json:"browser_download_url"`
 Digest string `json:"digest"`
}
type release struct {
 Tag string `json:"tag_name"`
 Assets []asset `json:"assets"`
}
type gameFile struct {
 Path string `json:"path"`
 SHA string `json:"sha256"`
}
type manifest struct {
 Format int `json:"format"`
 Commit string `json:"commit"`
 Files []gameFile `json:"files"`
}
type installed struct {
 Commit string `json:"commit"`
 EngineSHA string `json:"engine_sha256"`
}
func fetch(url string) ([]byte,error) {
 ctx,cancel:=context.WithTimeout(context.Background(),45*time.Second)
 defer cancel()
 req,err:=http.NewRequestWithContext(ctx,"GET",url,nil); if err!=nil{return nil,err}
 req.Header.Set("User-Agent","Kuningriigid-Windows-Bootstrap/1.0")
 req.Header.Set("Accept","application/vnd.github+json")
 res,err:=client.Do(req);if err!=nil{return nil,err};defer res.Body.Close()
 if res.StatusCode!=200{return nil,fmt.Errorf("GitHub HTTP %d",res.StatusCode)}
 return io.ReadAll(io.LimitReader(res.Body,2<<20))
}
func digestBytes(b []byte) string {h:=sha256.Sum256(b);return hex.EncodeToString(h[:])}
func digestFile(path string) (string,error) {
 f,err:=os.Open(path);if err!=nil{return "",err};defer f.Close()
 h:=sha256.New();if _,err=io.Copy(h,f);err!=nil{return "",err}
 return hex.EncodeToString(h.Sum(nil)),nil
}
func matching(path,expected string) bool {
 hash,err:=digestFile(path)
 return err==nil&&hash==expected
}
func atomicWrite(path string,data []byte) error {
 if err:=os.MkdirAll(filepath.Dir(path),0755);err!=nil{return err}
 tmp:=path+".download"
 if err:=os.WriteFile(tmp,data,0644);err!=nil{return err}
 if err:=os.Rename(tmp,path);err!=nil {os.Remove(tmp);return err}
 return nil
}
func download(url,dest,sha string) error {
 if !hexHash.MatchString(sha){return errors.New("invalid file checksum")}
 ctx,cancel:=context.WithTimeout(context.Background(),6*time.Minute)
 defer cancel()
 req,err:=http.NewRequestWithContext(ctx,"GET",url,nil);if err!=nil{return err}
 req.Header.Set("User-Agent","Kuningriigid-Windows-Bootstrap/1.0")
 res,err:=client.Do(req);if err!=nil{return err};defer res.Body.Close()
 if res.StatusCode!=200{return fmt.Errorf("download HTTP %d",res.StatusCode)}
 if err:=os.MkdirAll(filepath.Dir(dest),0755);err!=nil{return err}
 temp:=dest+".download"
 f,err:=os.Create(temp);if err!=nil{return err}
 h:=sha256.New()
 _,err=io.Copy(io.MultiWriter(f,h),io.LimitReader(res.Body,220<<20))
 closeErr:=f.Close()
 if err!=nil||closeErr!=nil{os.Remove(temp);return fmt.Errorf("file write: %v %v",err,closeErr)}
 if hex.EncodeToString(h.Sum(nil))!=sha {os.Remove(temp);return fmt.Errorf("SHA-256 differs for %s",filepath.Base(dest))}
 if err=os.Rename(temp,dest);err!=nil {os.Remove(temp);return err}
 return nil
}
func safePath(path string) bool {
 if path==""||strings.ContainsAny(path,":\\")||strings.HasPrefix(path,"/"){return false}
 for _,segment:=range strings.Split(path,"/") {
  if segment==""||segment=="."||segment==".."||strings.HasSuffix(segment,".")||strings.HasSuffix(segment," "){return false}
 }
 return true
}
func validate(m manifest) error {
 if m.Format!=1||!commitHash.MatchString(m.Commit){return errors.New("unsupported or invalid manifest")}
 if len(m.Files)<10||len(m.Files)>10000{return errors.New("manifest file count outside expected range")}
 seen:=map[string]bool{}
 for _,entry:=range m.Files {
  if !safePath(entry.Path)||!hexHash.MatchString(entry.SHA){return fmt.Errorf("unsafe entry: %q",entry.Path)}
  key:=strings.ToLower(entry.Path)
  if seen[key]{return fmt.Errorf("duplicate manifest path %s",entry.Path)}
  seen[key]=true
 }
 if !seen["project.godot"]||!seen["content.tscn"]||!seen["main.tscn"]{return errors.New("missing Godot entrypoints")}
 return nil
}
func findAsset(assets []asset, name string) (asset,bool) {
 for _,a:=range assets {if a.Name==name&&strings.HasPrefix(a.URL,"https://github.com/orogdor/Kuningriigid-Godot-AutoPort/releases/download/"){return a,true}}
 return asset{},false
}
func readState(home string) installed {
 var info installed
 data,err:=os.ReadFile(filepath.Join(home,"active.json"));if err!=nil{return info}
 if json.Unmarshal(data,&info)!=nil||!commitHash.MatchString(info.Commit)||!hexHash.MatchString(info.EngineSHA){return installed{}}
 return info
}
func readManifest(home,commit string)(manifest,error){
 var m manifest
 data,err:=os.ReadFile(filepath.Join(home,"versions",commit,"manifest.json"));if err!=nil{return m,err}
 if err=json.Unmarshal(data,&m);err!=nil{return m,err}
 if err=validate(m);err!=nil{return m,err}
 if m.Commit!=commit{return m,errors.New("manifest version mismatch")}
 return m,nil
}
func validGame(home string,m manifest) bool {
 root:=filepath.Join(home,"versions",m.Commit,"game")
 for _,file:=range m.Files {
  if !matching(filepath.Join(root,filepath.FromSlash(file.Path)),file.SHA){return false}
 }
 return true
}
func runtimePath(home,sha string) string {return filepath.Join(home,"runtime",sha,"Godot.exe")}
func installRuntime(home string,a asset) (string,string,error) {
 sha:=strings.TrimPrefix(a.Digest,"sha256:")
 if !hexHash.MatchString(sha){return "","",errors.New("Godot release binary has no SHA-256 digest")}
 path:=runtimePath(home,sha)
 if !matching(path,sha){
  if err:=download(a.URL,path,sha);err!=nil{return "","",err}
 }
 return path,sha,nil
}
func installGame(home string,m manifest,prior installed)error {
 final:=filepath.Join(home,"versions",m.Commit)
 if old,err:=readManifest(home,m.Commit);err==nil && validGame(home,old) && identical(old,m){return nil}
 stage:=filepath.Join(home,"versions",".stage-"+m.Commit)
 os.RemoveAll(stage)
 if err:=os.MkdirAll(filepath.Join(stage,"game"),0755);err!=nil{return err}
 defer os.RemoveAll(stage)
 oldManifest,_:=readManifest(home,prior.Commit)
 oldPaths:=map[string]string{}
 for _,f:=range oldManifest.Files {oldPaths[f.Path]=f.SHA}
 for _,file:=range m.Files {
  dest:=filepath.Join(stage,"game",filepath.FromSlash(file.Path))
  if err:=os.MkdirAll(filepath.Dir(dest),0755);err!=nil{return err}
  old:=filepath.Join(home,"versions",prior.Commit,"game",filepath.FromSlash(file.Path))
  if oldPaths[file.Path]==file.SHA&&matching(old,file.SHA) {
   data,err:=os.ReadFile(old);if err!=nil{return err}
   if err=atomicWrite(dest,data);err!=nil{return err}
  } else {
   url:=sourceRoot+m.Commit+"/game/"+file.Path
   if err:=download(url,dest,file.SHA);err!=nil{return err}
  }
 }
 if !validStage(stage,m){return errors.New("installed content failed SHA-256 check")}
 encoded,_:=json.MarshalIndent(m,"","  ")
 if err:=atomicWrite(filepath.Join(stage,"manifest.json"),encoded);err!=nil{return err}
 // A corrupted installation may be replaced only after complete validation.
 if err:=os.RemoveAll(final);err!=nil{return err}
 return os.Rename(stage,final)
}
func identical(a,b manifest)bool{
 if len(a.Files)!=len(b.Files){return false}
 for i:=range a.Files {if a.Files[i]!=b.Files[i]{return false}}
 return true
}
func validStage(stage string,m manifest) bool{
 for _,f:=range m.Files{
  if !matching(filepath.Join(stage,"game",filepath.FromSlash(f.Path)),f.SHA){return false}
 }
 return true
}
func currentRuntime(home string,state installed)string{
 if !hexHash.MatchString(state.EngineSHA){return ""}
 path:=runtimePath(home,state.EngineSHA)
 if matching(path,state.EngineSHA){return path}
 return ""
}
func upgrade(home string,prior installed)(installed,error){
 var r release
 bytes,err:=fetch(releasesAPI);if err!=nil{return prior,err}
 if err=json.Unmarshal(bytes,&r);err!=nil{return prior,err}
 mAsset,ok:=findAsset(r.Assets,manifestAsset);if !ok{return prior,errors.New("release has no Windows file manifest")}
 eAsset,ok:=findAsset(r.Assets,engineAsset);if !ok{return prior,errors.New("release has no Godot runtime")}
 body,err:=fetch(mAsset.URL);if err!=nil{return prior,err}
 digest:=strings.TrimPrefix(mAsset.Digest,"sha256:")
 if !hexHash.MatchString(digest)||digestBytes(body)!=digest{return prior,errors.New("Windows manifest digest mismatch")}
 var m manifest
 if err=json.Unmarshal(body,&m);err!=nil{return prior,err}
 if err=validate(m);err!=nil{return prior,err}
 // The previous working version remains active until BOTH downloads complete.
 _,engineSha,err:=installRuntime(home,eAsset);if err!=nil{return prior,err}
 if err=installGame(home,m,prior);err!=nil{return prior,err}
 next:=installed{Commit:m.Commit,EngineSHA:engineSha}
 state,_:=json.MarshalIndent(next,"","  ")
 if err:=atomicWrite(filepath.Join(home,"active.json"),state);err!=nil{return prior,err}
 return next,nil
}
func start(home string,state installed)error{
 if !commitHash.MatchString(state.Commit){return errors.New("no installed game; internet required for first run")}
 m,err:=readManifest(home,state.Commit);if err!=nil{return err}
 if !validGame(home,m){return errors.New("cached game files are damaged")}
 engine:=currentRuntime(home,state);if engine==""{return errors.New("Godot runtime is missing or damaged")}
 game:=filepath.Join(home,"versions",state.Commit,"game")
 command:=exec.Command(engine,"--path",game)
 command.Dir=game
 if err=command.Start();err!=nil{return err}
 return command.Process.Release()
}
func run()error{
 exe,err:=os.Executable();if err!=nil{return err}
 base:=filepath.Join(filepath.Dir(exe),"Kuningriigid-Data")
 if custom:=os.Getenv("KUNINGRIIGID_HOME");custom!=""{base=custom}
 if err=os.MkdirAll(base,0755);err!=nil{return err}
 state:=readState(base)
 updated,updateErr:=upgrade(base,state)
 if updateErr!=nil{fmt.Fprintln(os.Stderr,"Update unavailable:",updateErr)}
 if os.Getenv("KUNINGRIIGID_VERIFY_ONLY") == "1" {
  if !commitHash.MatchString(updated.Commit) {return fmt.Errorf("no downloaded files available: %v",updateErr)}
  m,err:=readManifest(base,updated.Commit)
  if err!=nil{return err}
  if !validGame(base,m) || currentRuntime(base,updated)=="" {
   return errors.New("cached Godot files failed Windows verification")
  }
  return nil
 }
 if err=start(base,updated);err==nil{return nil}
 if updated!=state {
  if err=start(base,state);err==nil {
   // Roll back active selection when a newly installed version cannot start.
   previous,_:=json.MarshalIndent(state,"","  ")
   _=atomicWrite(filepath.Join(base,"active.json"),previous)
   return nil
  }
 }
 if updateErr!=nil{return fmt.Errorf("GitHub: %v; game not available offline",updateErr)}
 return errors.New("no working game version; try again with internet")
}
func main() {
 if err := run(); err != nil {
  // A diagnosable error file for unattended Windows installs and bug reports.
  if executable, e := os.Executable(); e == nil {
   dir := filepath.Join(filepath.Dir(executable),"Kuningriigid-Data")
   if custom:=os.Getenv("KUNINGRIIGID_HOME");custom!=""{dir=custom}
   _=os.MkdirAll(dir,0755)
   _=os.WriteFile(filepath.Join(dir,"last-error.txt"),[]byte(err.Error()),0644)
  }
  showFatal("Kuningriigid ei käivitu:\n" + err.Error())
  os.Exit(1)
 }
}
