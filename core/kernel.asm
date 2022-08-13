; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Memory layout and general support for TinyCore device drivers.

            .cpu    "w65c02"
            
;reserved   = $0000     ; $00 - $02
;basic      = $0002     ; $02 - $90
*           = $0090     ; $90 - $fb kernel
*           = $00a3     ; $90 - $fb kernel
DP          .dsection   dp
            .cerror * >= $00fb, "Out of dp space."

*           = $0100     ; Stack
Stack       .fill       $100

*           = $0200     ; BASIC, some KERNAL
Tokens      .fill       $90     ; BASIC
p2end            
tokens_start
            .cerror * > $02ff, "Out of kmem space."

*           = $0300     
            .fill   $34         ; Shared vectors
p3end       
            .cerror * > $03ff, "Out of kbuf space."

*           = $0400     ; Device tables (from the TinyCore kernel)
            .dsection   kpages
KBUF        .dsection   kbuf    ; kernal
KMEM        .dsection   kmem    ; KERNAL 


free_mem    = $800  ; Traditional start.



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
            


thread      .namespace  ; For devices borrowed from the TinyCore kernel.
yield       wai
            rts
            .endn

init
      ; Initialize device driver services.
        jsr     token.init
        jsr     device.init
        jsr     keyboard.init
        rts

tick
        inc     kernel.ticks
        bne     _end
        inc     kernel.ticks+1
_end    rts

error
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
            stz     $1  ; Default to the sys map.

            jsr     ramtas
            jsr     restor
            jsr     SCINIT
            jsr     IOINIT
            jmp     (basic)


vectors     .struct
SCINIT      jmp     scinit
IOINIT      jmp     io.ioinit
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
READST      jmp     io.readst
SETLFS      jmp     io.setlfs
SETNAM      jmp     io.setnam
OPEN        jmp     io.open
CLOSE       jmp     io.close
CHKIN       jmp     io.chkin
CHKOUT      jmp     io.chkout
CLRCHN      jmp     io.clrchn
CHRIN       jmp     io.chrin
CHROUT      jmp     io.chrout
LOAD        jmp     io.load
SAVE        jmp     io.save
SETTIM      jmp     settim
RDTIM       jmp     rdtim
STOP        jmp     stop
GETIN       jmp     io.getin
CLALL       jmp     io.clall
UDTIM       jmp     udtim
SCREEN      jmp     screen
PLOT        jmp     plot
IOBASE      jmp     iobase
            .ends


            .send
            .endn
