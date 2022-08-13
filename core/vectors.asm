; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "65c02"

            .namespace  kernel
            .section    kernel
            

            

ivec_start
            .word   irq
            .word   break
            .word   nmi
            .word   io.open     
            .word   io.close
            .word   io.chkin
            .word   io.chkout
            .word   io.clrchn
            .word   io.chrin
            .word   io.chrout
            .word   stop
            .word   io.getin
            .word   io.clall
            .word   user
            .word   io.load
            .word   io.save
ivec_end
ivec_size   =   ivec_end - ivec_start

            
           
restor
            pha
            phx
            ldx     #0
_loop       lda     ivec_start,x
            sta     $314,x
            inx
            cmp     #ivec_size
            bne     _loop
            plx
            pla
            rts

vector
            stx     src+0
            sty     src+1

            ldy     #0
            bcs     _out      
        
_in         lda     (src),y
            sta     $314,y
            iny
            cpy     #ivec_size
            bne     _in
            rts
            
_out        lda     $314,y
            sta     (src),y
            iny
            cpy     #ivec_size
            bne     _out
            rts



irq
break
nmi
user
        sec
        rts
        

            .send
            .endn
