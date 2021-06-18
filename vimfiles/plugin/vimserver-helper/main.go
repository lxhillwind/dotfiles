package main

import (
    npipe "gopkg.in/natefinch/npipe.v2"
    "os"
    "log"
    "io"
)

func main() {
    mode := os.Args[1]
    name := `\\.\pipe\` + os.Args[2]
    if mode == "server" {
        ln, err := npipe.Listen(name)
        if err != nil {
            log.Fatalln(err)
        }
        for {
            conn, err := ln.Accept()
            if err != nil {
                log.Println(err)
                continue
            }
            if _, err := io.Copy(os.Stdout, conn); err != nil {
                log.Println(err)
            }
        }
    } else {
        conn, err := npipe.Dial(name)
        if err != nil {
            log.Fatalln(err)
        }
        if _, err := io.Copy(conn, os.Stdin); err != nil {
            log.Fatalln(err)
        }
    }
}
