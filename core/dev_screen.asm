; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel
            .namespace  io

            .section    kernel



screen_open 
            jmp     simple_open

screen_close
            jmp     simple_close

screen_stat
            lda     #0
            clc
            rts            
            
screen_io
            bcs     _write
            lda     #0
            clc
            rts
_write      jsr     platform.console.putc
            clc
            rts


            .send
            .endn
            .endn
