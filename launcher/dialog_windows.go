//go:build windows
package main

import (
 "syscall"
 "unsafe"
)
func showFatal(message string){
 dll:=syscall.NewLazyDLL("user32.dll")
 proc:=dll.NewProc("MessageBoxW")
 title,_:=syscall.UTF16PtrFromString("Kuningriigid")
 body,_:=syscall.UTF16PtrFromString(message)
 proc.Call(0,uintptr(unsafe.Pointer(body)),uintptr(unsafe.Pointer(title)),0x10)
}
