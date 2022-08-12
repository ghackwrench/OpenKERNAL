;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
;
; This file is part of OpenKERNAL -- a clean-room implementation of the
; KERNAL interface documented in the Commodore 64 Programmer's Reference.
; 
; OpenKERNAL is free software: you may redistribute it and/or modify it under
; the terms of the GNU Lesser General Public License as published by the Free
; Software Foundation, either version 3 of the License, or (at your option)
; any later version.
; 
; OpenKERNAL is distributed in the hope that it will be useful, but WITHOUT
; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
; FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License
; for more details.
; 
; You should have received a copy of the GNU Lesser General Public License
; along with OpenKERNAL. If not, see <https://www.gnu.org/licenses/>.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            .cpu    "w65c02"
            
;reserved   = $0000     ; $00 - $02
;basic      = $0002     ; $02 - $90
*           = $0090     ; $90 - $fb kernel
*           = $00a3     ; $90 - $fb kernel
            .dsection   dp
            .cerror * >= $00fb, "Out of dp space."

Stack       = $0100
Page2       = $0200     ; BASIC, some KERNAL
Page3       = $0300     ; BASIC

*           = $0400     ; KERNEL    ; TODO: 200, fill 59, ramtas
KMEM        .dsection   kmem 
            .cerror * > $04ff, "Out of kmem space."

*           = $0500     ; Device table (borrowed from the TinyCore kernel)
            .dsection   kbuf
            .align      256
            .dsection   kpages
            .fill       256     ; BASIC...
free_mem



; $e000 - $e500 contains a simple command line shell which may be
; used to load applications in the absence of either CBM BASIC or
; a more general ROM.  If CBM BASIC is bundled, it will overwrite
; this section of the kernel. 

*           = $e000
            .dsection   cli
            .cerror * > $e4ff, "Out of cli space."

; Start of the kernel proper, pushed back to accomodate the use of
; CBM BASIC.
*           = $e500
            .dsection   tables
            .dsection   kernel
            .cerror * > $feff, "Out of kernel space."

*           = $ff81
kernel      .namespace
            .dstruct    vectors            
            .endn

            .section    kpages
frame
Devices     .fill       256
DevState    .fill       256
Tokens      .fill       256
            
;            .fill       256     ; Something goes wonky otherwise...
            .send            

            .namespace  kernel

            .section    dp
tmp_x       .byte   ?
tmp2        .byte   ?
ticks       .word   ?
src         .word   ?   ; src ptr for copy operations.
            .send


            .section    dp
mem_start   .word       ?
mem_end     .word       ?
msg_switch  .byte       ?
iec_timeout .byte       ?
current_dev .byte       ?
input       .byte       ?
            .send

            .section    cli
            .byte   0
            .send          

            .section    kernel
            
font        
fcb     .macro
        .byte   \@
        .endm
.if true
            .fill   20*8,0
            .include     "8x8.fcb"
.else
            .binary     "characters.906143-02.bin"
.endif

thread  .namespace  ; For devices borrowed from the TinyCore kernel.
yield       wai
            rts
        .endn

error:
        lda     #<_msg
        sta     src
        lda     #>_msg
        sta     src+1
        ldy     #0
_loop   lda     (src),y
        beq     _done
        jsr     platform.console.putc
        iny
        bra     _loop
_done   jmp     wreset       
_msg    .null   "Error"



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CBM stuff below ... move to another file.

basic = $a000

start       
  stz   input
        
  lda #2
  sta platform.shadow1
  sta $1
  
            jsr     ramtas
            jsr     restor
            jsr     SCINIT
            jsr     IOINIT
            jmp     (basic)
            

ivec_start
            .word   irq
            .word   break
            .word   nmi
            .word   open     
            .word   close
            .word   chkin
            .word   chkout
            .word   clrchn
            .word   chrin
            .word   chrout
            .word   stop
            .word   getin
            .word   clall
            .word   user
            .word   load
            .word   save
ivec_end
ivec_size   =   ivec_end - ivec_start



stop
    lda #1
    clc
    rts



scinit
            jmp     platform.console.init

ioinit      jmp     io.ioinit

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
            
lstnsa
talksa
            sec
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

settmo
            sta     iec_timeout
            rts
            
iecin
iecout
untalk
unlstn
listen
talk
            sec
            rts

readst      jmp     io.readst
setlfs      jmp     io.setlfs
setnam      jmp     io.setnam
open        jmp     io.open
close       jmp     io.close
chkin       jmp     io.chkin
chkout      jmp     io.chkout
clrchn      jmp     io.chkin
chrin       jsr     io.chrin
chrout      jmp     io.chrout

    
load
save
    sec
    rts

getin       jmp     io.getin
clall       jmp     io.clall

.if true
irq
break
nmi
user
        sec
        rts
.endif
        
iobase
        ldx     #$dc
        ldy     #$00
        rts




            
            .send
            .endn
