; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Driver for a VIC20/C264 keyboard connected to the 6522 port.

            .cpu        "w65c02"

            .namespace  platform
c64kbd      .namespace


PRA  =  $dc01  ; CIA#1 (Port Register A)
DDRA =  $dc03  ; CIA#1 (Data Direction Register A)

PRB  =  $dc00  ; CIA#1 (Port Register B)
DDRB =  $dc02  ; CIA#1 (Data Direction Register B)

        .section    kmem
mask    .byte       ?   ; Copy of PRA output
hold    .byte       ?   ; Copy of PRB during processing
bitno   .byte       ?   ; # of the col bit being processed
        .send

        .section    dp  ; So we can branch on bits :).
state:  .fill       8
        .send

        .section    kernel
        
init:
        stz $1

        lda #$ff    ; CIA#1 port A = outputs 
        sta DDRA             

        lda #$00    ; CIA#1 port B = inputs
        sta DDRB   

      ; Init the roll-table
        lda     #$ff    ; no key grounded
        ldx     #7
_loop   sta     state,x
        dex
        bpl     _loop
        rts

scan
        stz     $1
        lda     #$7f
        ldx     #0
        
_loop   
        sta     PRA
        sta     mask        

        lda     PRB
        sta     hold
        eor     state,x
        beq     _next

        jsr     report        

_next
        inx
        lda     mask
        lsr     a
        ora     #$80
        bcs     _loop
        rts


report

    ; Current state doesn't match last state.
    ; Walk the bits and report any new keys.

_loop ; Process any bits that differ between PRB and state,x

      ; Y->next diff bit to check
        tay
        lda     irq.first_bit,y
        sta     bitno
        tay

      ; Clear the current state for this bit
        lda     irq.bit,y   ; 'A' contains a single diff-bit
        eor     #$ff
        and     state,x
        sta     state,x

      ; Report key and update the state
        lda     irq.bit,y   ; 'A' contains a single diff-bit
        and     hold        ; Get the state of this specific bit
        bne     _save       ; Key is released; no action.
        pha
        jsr     _report     ; Key is pressed; report it.
        pla
_save
      ; Save the state of the bit
        ora     state,x
        sta     state,x
_next  
        lda     hold
        eor     state,x
        bne     _loop 

_done   rts

_report
      ; A = row #
        txa     ; Row #

      ; Bit numbers are the reverse of
      ; the table order, so advance one
      ; row and then "back up" by bitno.
        inc     a

      ; A = table offset for row
        asl     a
        asl     a
        asl     a

      ; A = table entry for key
        sbc     bitno
        
      ; Y-> table entry
        tay

        lda     keytab,y
        cmp     #'_'
        beq     _out    ; Don't report meta keys

        bbr    2,state+0,_ctrl   ; CTRL
        bbr    4,state+1,_shift  ; RSHIFT
        bbr    7,state+6,_shift  ; LSHIFT

_alt    bbs    5,state+0,_queue  ; C= (ALT)
        ora     #$80
        
_queue
        jmp     kernel.keyboard.enque

_ctrl
        and     #$1f
        bra     _alt
        
_shift
        lda     shift,y
        cmp     #'_'
        bne     _alt

_out    rts

        .enc   "none"
keytab: .text  "_q_ 2_`1"
        .text  "/^=__;*~"
        .text  ",@:.-lp+"
        .text  "nokm0ji9"
        .text  "vuhb8gy7"
        .text  "xtfc6dr5"
        .text  "_esz4aw3"
        .byte  'N'-64, 5+128, 3+128, 1+128, 7+128, 'F'-64, 13, 8

shift:  .text  "_Q_ ",34,"_~!"
        .text  "?^=__]*~"
        .text  "<@[>-LP+"
        .text  "NOKM0JI)"
        .text  "VUHB(GY'"
        .text  "XTFC&DR%"
        .text  "_ESZ$AW#"
        .byte   'P'-64, 5+128, 3+128, 1+128, 7+128, 'B'-64, 13, 8

        .send
        .endn
        .endn
