// +build !windows

package main

import (
    "net"
)

func Listen(name string) (net.Listener, error) {
    return net.Listen("unix", name)
}

func Dial(addr string) (net.Conn, error) {
    return net.Dial("unix", addr)
}
