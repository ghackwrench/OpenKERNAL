; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel
            .namespace  io

            .section    kernel

keyboard_open
            jmp     simple_open
            
keyboard_close
            jmp     simple_close
            
keyboard_stat
            lda     #0
            clc
            rts            
            
keyboard_io
            bcs     _write
_loop       jsr     keyboard.deque
            bcc     _out
            lda     #0
            clc
_out        rts
_write      lda     #NOT_OUTPUT_FILE
            jmp     error            

            .send
            .endn
            .endn
            
