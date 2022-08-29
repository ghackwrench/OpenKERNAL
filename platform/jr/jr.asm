; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

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

        stz     $1
        jsr     tick_init
        jsr     ps2.init
        bcs     _out

_out    rts        


tick_init
        ; TODO: allocate the device handle.

        jsr     c64kbd.init

        lda     #<tick
        sta     frame+0
        lda     #>tick
        sta     frame+1

        lda     #<frame
        ldy     #irq.frame
        jsr     irq.install

        lda     #irq.frame
        jsr     irq.enable
        
        rts

tick
        jsr     c64kbd.scan
        jmp     kernel.tick

hw_nmi: 
        stz     nmi_flag
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

far_poke
        sta     (kernel.shell.far_dest)
        clc
        rts

far_exec
        ldy     #1
        lda     (kernel.shell.far_addr)
        ora     (kernel.shell.far_addr),y
        beq     _nope
        jmp     (kernel.shell.far_addr)
_nope   sec
        rts
        
        .send
        .endn


