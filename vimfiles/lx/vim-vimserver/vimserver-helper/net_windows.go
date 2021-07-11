// +build windows

package main

import (
    npipe "gopkg.in/natefinch/npipe.v2"
    "net"
)

func Listen(name string) (net.Listener, error) {
    return npipe.Listen(`\\.\pipe\` + name)
}

func Dial(addr string) (net.Conn, error) {
    return npipe.Dial(`\\.\pipe\` + addr)
}
