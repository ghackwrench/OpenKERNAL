; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu        "w65c02"

            .namespace  kernel
            .section    kernel


ramtas      
            
            ldx     #2
_11         stz     $0,x
            inx
            cpx     #<DP        ; Don't clear the kernel's dp.
            bne     _11
            
            stz     $100
            stz     $101

            ldx     #0
_l2         stz     $200,x
            inx
            cpx     #<p2end     ; Don't clear the kernel's page 2 memory.
            bne     _l2

            ldx     #0
_l3         stz     $300,x  
            inx
            cpx     #<p3end     ; Don't clear the kernel's page 3 memory
            bne     _l3

            ldx     #0
            ldy     #>free_mem
            clc     ; set
            jsr     memtop

            ldx     #0     
            ldy     #>basic
            clc     ; set
            jsr     membot

            rts
            

setmsg
            sta     msg_switch
            rts

membot
            bcc     _save
            
_load       ldx     mem_end+0
            ldy     mem_end+1
            rts

_save       stx     mem_end+0
            sty     mem_end+1
            rts

memtop
            bcc     _save

_load       ldx     mem_start+0
            ldy     mem_start+1
            rts

_save       stx     mem_start+0
            sty     mem_start+1
            rts

 

scnkey
            ; PS2 keyboard is interrupt driven.
            ; May be used to force a CIA scan.
            rts

iobase
        ldx     #$dc
        ldy     #$00
        rts


            .send
            .endn
            

            
