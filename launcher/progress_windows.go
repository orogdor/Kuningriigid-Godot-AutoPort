//go:build windows

package main

// Small native Win32 splash window; no installed .NET, PowerShell or external
// libraries required. All HWND work happens on one locked OS thread.
import (
 "fmt"
 "os"
 "runtime"
 "sync"
 "syscall"
 "time"
 "unsafe"
)

type progressEvent struct { percent int; message string }
var updateEvents chan progressEvent
var updateStop chan struct{}
var updateReady chan struct{}
var updateOnce sync.Once
var user32 = syscall.NewLazyDLL("user32.dll")
var common = syscall.NewLazyDLL("comctl32.dll")
var createWindow = user32.NewProc("CreateWindowExW")
var setWindowText = user32.NewProc("SetWindowTextW")
var sendMessage = user32.NewProc("SendMessageW")
var peekMessage = user32.NewProc("PeekMessageW")
var translateMessage = user32.NewProc("TranslateMessage")
var dispatchMessage = user32.NewProc("DispatchMessageW")
var destroyWindow = user32.NewProc("DestroyWindow")
var showWindow = user32.NewProc("ShowWindow")
var updateWindow = user32.NewProc("UpdateWindow")
var getSystemMetrics = user32.NewProc("GetSystemMetrics")
const wsVisible = 0x10000000
const wsChild = 0x40000000
const wsCaption = 0x00c00000
const wsBorder = 0x00800000
const pbmSetPos = 0x402

type winMsg struct {
 hwnd uintptr
 message uint32
 wparam uintptr
 lparam uintptr
 timestamp uint32
 ptX int32
 ptY int32
 private uint32
}
type commonControlSettings struct { size uint32; flags uint32 }
func ptr(s string) uintptr {
 p,_:=syscall.UTF16PtrFromString(s)
 return uintptr(unsafe.Pointer(p))
}
func window(class,title string,style uintptr,x,y,w,h int32,parent uintptr) uintptr {
 hwnd,_,_:=createWindow.Call(0,ptr(class),ptr(title),style,
  uintptr(x),uintptr(y),uintptr(w),uintptr(h),parent,0,0,0)
 return hwnd
}
func updateText(hwnd uintptr,s string) {
 if hwnd!=0 {setWindowText.Call(hwnd,ptr(s))}
}
func updatePercent(hwnd uintptr,value int){
 if hwnd!=0 {sendMessage.Call(hwnd,pbmSetPos,uintptr(value),0)}
}
func pumpWindows(){
 for {
  var msg winMsg
  ok,_,_:=peekMessage.Call(uintptr(unsafe.Pointer(&msg)),0,0,0,1)
  if ok==0 {return}
  translateMessage.Call(uintptr(unsafe.Pointer(&msg)))
  dispatchMessage.Call(uintptr(unsafe.Pointer(&msg)))
 }
}
func runUpdateWindow(){
 runtime.LockOSThread()
 defer runtime.UnlockOSThread()
 // ICC_PROGRESS_CLASS = 0x20, InitCommonControlsEx.
 opts:=commonControlSettings{size:8,flags:0x20}
 common.NewProc("InitCommonControlsEx").Call(uintptr(unsafe.Pointer(&opts)))
 sw,_,_:=getSystemMetrics.Call(0)
 sh,_,_:=getSystemMetrics.Call(1)
 x,y:=int32(100),int32(100)
 if sw>500{x=int32((sw-500)/2)}
 if sh>180{y=int32((sh-180)/2)}
 parent:=window("STATIC","Kuningriigid - UPDATE",wsVisible|wsCaption|wsBorder,x,y,500,180,0)
 if parent==0 {
  close(updateReady)
  <-updateStop
  return
 }
 head:=window("STATIC","UPDATE: kontrollin GitHubi...",wsVisible|wsChild,20,22,450,26,parent)
 bar:=window("msctls_progress32","",wsVisible|wsChild,20,61,450,26,parent)
 footer:=window("STATIC","0% | Palun oota",wsVisible|wsChild,20,102,450,26,parent)
 showWindow.Call(parent,5)
 updateWindow.Call(parent)
 close(updateReady)
 ticker:=time.NewTicker(32*time.Millisecond)
 defer ticker.Stop()
 for {
  select {
  case e:=<-updateEvents:
   updateText(head,e.message)
   updatePercent(bar,e.percent)
   updateText(footer,fmt.Sprintf("UPDATE %d%%",e.percent))
   pumpWindows()
  case <-ticker.C:
   pumpWindows()
  case <-updateStop:
   destroyWindow.Call(parent)
   pumpWindows()
   return
  }
 }
}
func startUpdateUI(){
 if os.Getenv("CI")=="true" || os.Getenv("KUNINGRIIGID_NO_WINDOW")=="1" {return}
 updateOnce.Do(func(){
  updateEvents=make(chan progressEvent,32)
  updateStop=make(chan struct{})
  updateReady=make(chan struct{})
  go runUpdateWindow()
  <-updateReady
 })
}
func showUpdate(percent int, message string){
 if updateEvents==nil {return}
 e:=progressEvent{percent:percent,message:message}
 select {
 case updateEvents<-e:
 default:
  // Keep the newest progress report when downloading rapidly.
  select {case <-updateEvents: default:}
  select {case updateEvents<-e: default:}
 }
}
func stopUpdateUI(){
 if updateStop!=nil {
  close(updateStop)
  updateStop=nil
 }
}
