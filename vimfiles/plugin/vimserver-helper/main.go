package main

import (
    "os"
    "log"
    "io"
    "encoding/json"
)

func main() {
    name := os.Args[1]

    if len(os.Args) == 3 && os.Args[2] == "listen" {
        // server
        ln, err := Listen(name)
        if err != nil {
            log.Fatalln(err)
        }
        defer ln.Close()
        for {
            conn, err := ln.Accept()
            if err != nil {
                log.Println(err)
                continue
            }
            if _, err := io.Copy(os.Stdout, conn); err != nil {
                log.Println(err)
            }
            conn.Close()
        }
    } else {
        // client
        conn, err := Dial(name)
        if err != nil {
            log.Fatalln(err)
        }
        defer conn.Close()

        if len(os.Args) >= 3 {
            // terminal-api style
            funcname := os.Args[2]
            argument := []string{}
            for _, s := range os.Args[3:] {
                argument = append(argument, s)
            }
            finalArg := []interface{}{"call", funcname, argument}
            if s, ok := os.LookupEnv("VIMSERVER_CLIENT_PID"); ok {
                finalArg = append(finalArg, s)
            }
            data, err := json.Marshal(finalArg)
            if err != nil {
                log.Fatalln(err)
            }
            data = append(data, '\n')
            if _, err := conn.Write(data); err != nil {
                log.Fatalln(err)
            }
        } else {
            // use stdin
            if _, err := io.Copy(conn, os.Stdin); err != nil {
                log.Fatalln(err)
            }
        }
    }
}
