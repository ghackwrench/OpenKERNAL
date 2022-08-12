            .cpu        "65c02"
            .namespace  platform

;        .include "queue.inc"

PRA  =  $dc01  ; CIA#1 (Port Register A)
DDRA =  $dc03  ; CIA#1 (Data Direction Register A)

PRB  =  $dc00  ; CIA#1 (Port Register B)
DDRB =  $dc02  ; CIA#1 (Data Direction Register B)

        .section    kmem
row:    .byte   ?
col:    .byte   ?
clr:    .byte   ?
kbusy:  .byte   ?
x:      .byte   ?
y:      .byte   ?
;keys::  $queue  5
cursor: .byte   ?
        .send

        .section    kmem
state:  .fill       64
        .send

        .section    kernel
        
kbd_init:

;        $queue_init keys

;    inc *0x01
 stz platform.shadow1
 stz $1
        lda #$ff    ; CIA#1 port A = outputs 
        sta DDRA             

        lda #$00    ; CIA#1 port B = inputs
        sta DDRB   
        sta PRA     ; Pull all keys low for quick checks for keys
;    dec *0x01

;        sta *kbusy  ; Protection from recursion
        sta *cursor ; certainly not busy!

    ; Init the roll-table
        lda #0
        ldx #64
_loop   sta state-1,x
        dex
        bne _loop
        sta *clr
        rts

kbd_irq:
;        bit *kbusy  ; Return immediately if we're already scanning
;        bpl 1$
;        rts

        stz $1
 
        lda PRB
        eor #$ff
        ora *clr
        beq _out
        dec *kbusy      ; mark us as working
        cli             ; allow higher priority interrupts
        stx *x
        sty *y
        jsr keyboard
        ldx *x
        ldy *y
;        inc *kbusy      ; we're done
_out    rts

keyboard:
        ldx #0
        lda *clr
        beq check

    ; age the roll-table
        stx *clr
        ldx #64
_loop   ldy state-1,x
        beq _ok
        dey
        tya
        sta state-1,x
        inc *clr        ; Table needs to be aged again
_ok     dex
        bne _loop

check:
    lda PRB
    eor #255
    bne scan
    rts

scan:
        lda #$7f
        sta PRA
        sta *row
        nop
        nop
        nop
        nop

_1      lda #$80       ; Start col
_2      bit PRB
        beq _4
_3      inx
        clc
        ror a
        bcc _2
        lda *row
        sec
        ror a
        sta PRA
        nop
        nop
        nop
        nop
        sta *row
        bcs _1
        ldx #0
        stx PRA         ; fast detect next round
        nop
        nop
        nop
        nop
        rts

_4 ; Key pressed
        ldy keytab,x    ; Found a key, see if it's valid
        cpy #'_'
        beq _3          ; not a character; keep looking

        ldy state,x
        beq _45         ; New!

        inc state,x     ; Already reported, don't age
        jmp _3
        
_45     sta *col    ; Don't lose current col
        lda #4         ; New keypress!  Track it!
        sta state,x
        sta *clr
        ldy keytab,x    ; Found a key, see if it's valid
        
    ; Handle shifted characters

        lda #253    ; Check LSHIFT
        sta PRA
        nop
        nop
        nop
        nop
        lda #128
        and PRB
        beq _5      ; shifted

        lda #255-64 ; Check RSHIFT
        sta PRA
        nop
        nop
        nop
        nop
        lda #16
        and PRB
        bne _6      ; not shifted, still in Y
        
_5      ldy shift,x ; Handle shifted characters
        cpy #'_'        ; change this
        bne _5
_0      lda *row
        sta PRA
        nop
        nop
        nop
        nop
        lda *col
        jmp _3      ; not a character; keep looking
        

_6      lda #127    ; Handle CTRL
        sta PRA
        lda #32
        and PRB
        bne alt      ; Nope, move on to alt
        
        cpy #64     ; try to find a valid ctrl target
        bmi _0
        cpy #96
        bmi ctrl
        ldy shift,x
        cpy #64
        bmi _0
        cpy #96
        bpl _0      ; invalid key combination
        
ctrl:   tya
        sec
        sbc #64
        tay
        
alt:    lda #127
        sta PRA
        nop
        nop
        nop
        nop
        tya
        bit PRB
        bmi _1
        ora #128

_1      ;$queue_insert keys
    pha
    lda #2
    sta $1
    pla
    sta $c004 
    stz $1
        stx PRA
        nop
        nop
        nop
        nop
        rts

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
