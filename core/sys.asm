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
            

           
restor
            pha
            stx     tmp_x
            ldx     #0
_loop       lda     ivec_start,x
            sta     $314,x
            inx
            cmp     #ivec_size
            bne     _loop
            ldx     tmp_x
            pla
            rts

vector
            stx     tmp2+0
            sty     tmp2+1

            ldy     #0
            bcs     _out      
        
_in         lda     (tmp2),y
            sta     $314,y
            iny
            cpy     #ivec_size
            bne     _in
            rts
            
_out        lda     $314,y
            sta     (tmp2),y
            iny
            cpy     #ivec_size
            bne     _out
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


irq
break
nmi
user
        sec
        rts
        
iobase
        ldx     #$dc
        ldy     #$00
        rts


            .send
            .endn
            

            
