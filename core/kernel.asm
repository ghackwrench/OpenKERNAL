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
KBUF        .dsection   kbuf    ; kernal
KMEM        .dsection   kmem    ; KERNAL 
            .cerror * > $03ff, "Out of kbuf space."

*           = $0400     ; Device tables (from the TinyCore kernel)
            .dsection   kpages


free_mem    = $800  ; Traditional start.



; $e000 - $e500 contains a simple command line shell which may be
; used to load applications in the absence of either CBM BASIC or
; a more general ROM.  If CBM BASIC is bundled, it will overwrite
; this section of the kernel. 

*           = $e000
            .dsection   shell
            .cerror * > $e4ff, "Out of shell space."

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
            .send            

            .namespace  kernel

            .section    dp
ticks       .word   ?
src         .word   ?   ; src ptr for copy operations.
dest        .word   ?   ; dest ptr for copy operations.
size        .word   ?   ; size of data at dest.
tos_l       .byte   ?   ; For BCD conversions
tos_h       .byte   ?
fname       .word       ?       ; file name pointer
fname_len   .byte       ?       ; file name length
cur_logical .byte       ?       ; current logical device
cur_device  .byte       ?       ; current assoc dev #
cur_addr    .byte       ?       ; current associated secondary addr
            .send


            .section    dp
mem_start   .word       ?
mem_end     .word       ?
msg_switch  .byte       ?
current_dev .byte       ?
            .send


TOO_MANY_FILES          =   1
FILE_OPEN               =   2
FILE_NOT_OPEN           =   3
FILE_NOT_FOUND          =   4
DEVICE_NOT_PRESENT      =   5
NOT_INPUT_FILE          =   6
NOT_OUTPUT_FILE         =   7
MISSING_FILE_NAME       =   8
ILLEGAL_DEVICE_NUMBER   =   9

            .section    kernel
            
copyright
            .text   "OpenKERNAL - a clean-room implementation of the C64 KERNAL ABI",13
            .text   "Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.",13
            .text   "Released under the GPL3 license with the kernel exception:",13
            .text   "applications which simply use the ABI are not 'derived works'.", 13
            .byte   0
            
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


banner
            lda     #<copyright
            sta     src
            lda     #>copyright
            sta     src+1
            jmp     puts

puts            
            ldy     #0
_loop       lda     (src),y
            beq     _done
            jsr     CHROUT
            iny
            bne     _loop
            inc     src+1
            bra     _loop
_done       
            clc
            rts

error
        pha
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
_done   
        pla
        clc
        adc     #'0'
        jsr     platform.console.putc
        lda     #13
        jsr     platform.console.putc
        rts
_msg    .null   "Error "

strcmp      ldy     #$ff
_loop       iny
            lda     (src),y
            beq     _out
            eor     (dest),y
            beq     _loop
_out        rts            


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CBM stuff below ... move to another file.

basic = $a000

start       
            stz     $1  ; Default to the sys map.

            jsr     ramtas
            jsr     restor
            jsr     SCINIT
            jsr     IOINIT
            jmp     chain

chain
            ldx     #0
_loop       
          ; Point src and dest at the expected signature and offset
            lda     _table,x
            sta     src+0
            inx
            lda     _table,x
            sta     src+1
            inx
            lda     _table,x
            sta     dest+0
            inx
            lda     _table,x
            sta     dest+1
            inx
            
          ; Chain on signature match.
            jsr     strcmp
            bne     _next
            jmp     (_table,x)
_next       inx
            inx
            bra     _loop            
_table      
            .word   cbm_bytes,      $a004, cbm_start    ; Check for CBM BASIC
            .word   bas02_bytes,    $8004, bas02_start  ; Check for BASIC02
            .word   cli_bytes,      $e000, cli_start    ; Always last

cbm_bytes   .null   "CBMBASIC"
cbm_start   jmp     (basic)

bas02_bytes .null   "BASIC02"
bas02_start jmp     $8000

cli_bytes   .null   ""          ; Fall-through match.
cli_start   jmp     shell.start


vectors     .struct
SCINIT      jmp     scinit
IOINIT      jmp     io.ioinit
RAMTAS      jmp     ramtas
RESTOR      jmp     restor
VECTOR      jmp     vector
SETMSG      jmp     setmsg
LSTNSA      jmp     iec.lstnsa
TALKSA      jmp     iec.talksa
MEMBOT      jmp     membot
MEMTOP      jmp     memtop
SCNKEY      jmp     scnkey
SETTMO      jmp     iec.settmo
IECIN       jmp     iec.iecin
IECOUT      jmp     iec.iecout
UNTALK      jmp     iec.untalk
UNLSTN      jmp     iec.unlstn
LISTEN      jmp     iec.listen
TALK        jmp     iec.talk
READST      jmp     iec.readst
SETLFS      jmp     io.setlfs
SETNAM      jmp     io.setnam
OPEN        jmp     io.open
CLOSE       jmp     io.close
CHKIN       jmp     io.chkin
CHKOUT      jmp     io.chkout
CLRCHN      jmp     io.clrchn
CHRIN       jmp     io.chrin
CHROUT      jmp     io.chrout
LOAD        jmp     iec.load
SAVE        jmp     iec.save
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
