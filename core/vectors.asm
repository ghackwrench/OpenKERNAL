; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "65c02"

            .namespace  kernel
            .section    kernel
            
vectors     .struct
SCINIT      jmp     scinit
IOINIT      jmp     ioinit
RAMTAS      jmp     ramtas
RESTOR      jmp     restor
VECTOR      jmp     vector
SETMSG      jmp     setmsg
LSTNSA      jmp     lstnsa
TALKSA      jmp     talksa
MEMBOT      jmp     membot
MEMTOP      jmp     memtop
SCNKEY      jmp     scnkey
SETTMO      jmp     settmo
IECIN       jmp     iecin
IECOUT      jmp     iecout
UNTALK      jmp     untalk
UNLSTN      jmp     unlstn
LISTEN      jmp     listen
TALK        jmp     talk
READST      jmp     readst
SETLFS      jmp     setlfs
SETNAM      jmp     setnam
OPEN        jmp     open
CLOSE       jmp     close
CHKIN       jmp     chkin
CHKOUT      jmp     chkout
CLRCHN      jmp     clrchn
CHRIN       jmp     chrin
CHROUT      jmp     chrout
LOAD        jmp     load
SAVE        jmp     save
SETTIM      jmp     settim
RDTIM       jmp     rdtim
STOP        jmp     stop
GETIN       jmp     getin
CLALL       jmp     clall
UDTIM       jmp     udtim
SCREEN      jmp     screen
PLOT        jmp     plot
IOBASE      jmp     iobase
            .ends


            .send
            .endn
