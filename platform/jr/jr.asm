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

; Startup for OpenKERNAL on the C256 Foenix Jr.

            .cpu    "w65c02"

*           = $fffa ; Hardware vectors.
            .word   platform.hw_nmi
            .word   platform.hw_reset
            .word   platform.hw_irq

*           = $ff00 ; Keep the Jr's CPU busy during code upload.
wreset      jmp     wreset

platform    .namespace

            .section    dp
iomap       .byte       ?       ; Holds $1 during interrupt processing.
            .send            

            .section    kmem
shadow0     .byte       ?
shadow1     .byte       ?
nmi_flag    .byte       ?
            .send

spin    .macro   OFFSET
.if false
        pha
        php
        sei
        lda  #2
        sta  $1
        inc  $c000+\1
        stz  $1
        plp
        pla
.endif        
        .endm

            .section    kernel

booted      .byte       0       ; Reset detect; overwritten by a code push.

hw_reset:

        sei

      ; Initialize the stack pointer
        ldx     #$ff
        txs        

      ; "clear" the NMI flag.
        tsx
        stx     nmi_flag

      ; Check for a reset after the kernel has started.
        lda     booted
        bne     upload  ; Enter "wait for upload" mode.
        inc     booted

      ; Initialize the hardware
        jsr     init
        bcs     _error

      ; Default $c000 to general I/O.
        stz     $1
        
      ; Chain to the kernel
        jmp     kernel.start
_error  jmp     kernel.error

upload: ; TODO: use kernel string service
        jsr     console.init
        lda     #<_msg
        sta     kernel.src
        lda     #>_msg
        sta     kernel.src+1
        ldy     #0
_loop   lda     (kernel.src),y
        beq     _done
        jsr     console.putc
        iny
        bra     _loop
_done   jmp     wreset       
_msg    .null   "Upload"


init
        jsr     irq.init
        jsr     kernel.init
        jsr     console.init 
        bcs     _out
        stz     shadow1
        stz     $1
        jsr     frame_init
        bcs     _out
        jsr     ps2.init
        bcs     _out

_out    rts        


frame_init  ; TODO: move to kernel

        lda     #<frame_irq
        sta     frame+0
        lda     #>frame_irq
        sta     frame+1

        lda     #<frame
        ldy     #irq.frame
        jsr     irq.install

        lda     #irq.frame
        jsr     irq.enable
        
        rts

frame_irq

_ticks
        inc     kernel.ticks
        bne     _end
        inc     kernel.ticks+1
_end
        
        #spin   0
        ;jsr platform.kbd_irq
        rts


hw_nmi: 
        stz     nmi_flag
   pha
   lda #2
   sta $1
   lda $c002
   inc a
   sta $c002
   lda shadow1
   sta $1
   pla
        rti

hw_irq:
        pha
        phx
        phy
        
        lda     $1
        sta     iomap
        jsr     irq.dispatch
       
_resume
        lda     iomap
        sta     $1
        
        ply
        plx
        pla
        rti

        .send
        .endn


