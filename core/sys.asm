; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu        "w65c02"

            .namespace  kernel
            .section    kernel


ramtas      
            lda     #0
            
            ldx     #2
_l1         sta     $0,x
            inx
            bne     _l1
            
            sta     $100
            sta     $101

_l2         sta     $200,x
            sta     $300,x
            inx
            bne     _l2

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

stop
    lda #1
    clc
    rts


iobase
        ldx     #$dc
        ldy     #$00
        rts


            .send
            .endn
            

            
