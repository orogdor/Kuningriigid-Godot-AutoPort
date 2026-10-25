//go:build !windows
package main
import ("fmt";"os")
func showFatal(s string){fmt.Fprintln(os.Stderr,s)}
