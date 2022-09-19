; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Startup for OpenKERNAL on the C256 Foenix Jr.

            .cpu    "w65c02"

*           = $fff6 ; Keep the Jr's CPU busy during code upload.
wreset      jmp     wreset

*           = $fffa ; Hardware vectors.
            .word   platform.hw_nmi
            .word   platform.hw_reset
            .word   platform.hw_irq

platform    .namespace

            .section    dp
mmuctl      .byte       ?       ; Holds $0 during interrupt processing.
iomap       .byte       ?       ; Holds $1 during interrupt processing.
ptr         .word       ?       ; for far_write
tmp         .byte       ?       ; for far_write
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

      ; Set up MMU LUTs
        jsr     mmu_init

      ; Initialize the hardware
        jsr     init
        bcs     _error

      ; Default $c000 to general I/O.
        stz     $1
        
      ; Switch to MMU 3 and chain to the kernel.
        lda     #%00110011  ; LUT3 mapped and pre-set for edit.
        sta     $0
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


mmu_init

      ; Set up MMU LUTs 1-3 to match MMU0 while interrupts are off.
        lda     #%10000000  ; Edit MMU 0 (MMU0 mapped)
        jsr     _fill
        lda     #%10010000  ; Edit MMU 1 (MMU0 mapped)
        jsr     _fill
        lda     #%10100000  ; Edit MMU 2 (MMU0 mapped)
        jsr     _fill
        lda     #%10110000  ; Edit MMU 3 (MMU0 mapped)
        jsr     _fill
                
        stz     $0          ; Return MMU0, no LUT mapped.
        rts
_fill
        sta     $0
        ldx     #0
_loop         
        txa
        sta     $8,x
        sta     $10,x
        inx
        cpx     #8
        bne     _loop
        
        rts        

init
        jsr     INIT_CODEC
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
      ; Save registers on user's stack
        pha
        phx
        phy
        
        lda     $0      ; Read the current MMU state
        stz     $0      ; MMU0 active, LUT0 not mapped.
        sta     mmuctl  ; Save it (we know we're mapped now).

        lda     $1
        sta     iomap

        lda     #2
        sta     $1
        lda     mmuctl
        and     #3
        ora     #'0'
        sta     $c000

        jsr     irq.dispatch
       
_resume
        lda     iomap
        sta     $1

        lda     mmuctl
        sta     $0
        
      ; Restore registers from user's stack.
        ply
        plx
        pla
        rti

far_store
        phx

      ; Anything above 2MB is bogus.
        ldx     kernel.shell.far_dest+3
        bne     _nope

      ; Anything above 64k requires special treatment.
        ldx     kernel.shell.far_dest+2
        bne     _slow

        sta     (kernel.shell.far_dest)
        clc
_done
        plx
        rts
_nope
  lda #2
  sta $1
  inc $c000+78
        sec
        bra     _done

_slow  bra _nope
      ; Anything above 512k is bogus.
        bit     kernel.shell.far_dest+2
        bmi     _nope   ; bit 7
        bvs     _nope   ; bit 6
        
        pha
        
      ; Map ptr into the $c000..dfff range.
        lda     kernel.shell.far_dest+0
        sta     ptr+0
        lda     kernel.shell.far_dest+1
        and     #$1f
        ora     #$c0
        sta     ptr+1
        
      ; Pull the top three bits of the LSW into A.
        lda     kernel.shell.far_dest+1
        sta     tmp
        lda     kernel.shell.far_dest+2
        asl     tmp
        rol     a
        asl     tmp
        rol     a
        asl     tmp
        rol     a

      ; $C000 is RAM
        ldx     #4
        stx     $1

      ; Edit MMU LUT 0
        ldx     #$90
        stx     $0

      ; Patch the MMU slot for $c000
        sta     $8+6

      ; Store the byte
        pla
        sta     (ptr)

      ; Restore $c000 to $c000
        lda     #6  ; Original $c000 block (should read)
        sta     $8+6
        
      ; Re-hide the MMU
        stz     $0 

        clc
        bra     _done
        

far_exec

      ; Make sure we have a non-zero exec address.
        lda     kernel.shell.far_addr+0
        ora     kernel.shell.far_addr+1
        beq     _nope

      ; Make sure it's in the first 64k.
        lda     kernel.shell.far_addr+2
        ora     kernel.shell.far_addr+3
        bne     _nope

        jsr     _call
        clc
        rts
_nope   
        lda     #kernel.FILE_NOT_FOUND
        sec
        rts
_call   
        jmp     (kernel.shell.far_addr)
        

;/////////////////////////
;// CODEC
;/////////////////////////
CODEC_LOW        = $D620
CODEC_HI         = $D621
CODEC_CTRL       = $D622
INIT_CODEC stz  $1
            ;                LDA #%00011010_00000000     ;R13 - Turn On Headphones
            lda #%00000000
            sta CODEC_LOW
            lda #%00011010
            sta CODEC_HI
            lda #$01
            sta CODEC_CTRL ; 
            jsr CODEC_WAIT_FINISH
            ; LDA #%0010101000000011       ;R21 - Enable All the Analog In
            lda #%00000011
            sta CODEC_LOW
            lda #%00101010
            sta CODEC_HI
            lda #$01
            sta CODEC_CTRL ; 
            jsr CODEC_WAIT_FINISH
            ; LDA #%0010001100000001      ;R17 - Enable All the Analog In
            lda #%00000001
            sta CODEC_LOW
            lda #%00100011
            sta CODEC_HI
            lda #$01
            sta CODEC_CTRL ; 
            jsr CODEC_WAIT_FINISH
            ;   LDA #%0010110000000111      ;R22 - Enable all Analog Out
            lda #%00000111
            sta CODEC_LOW
            lda #%00101100
            sta CODEC_HI
            lda #$01
            sta CODEC_CTRL ; 
            jsr CODEC_WAIT_FINISH
            ; LDA #%0001010000000010      ;R10 - DAC Interface Control
            lda #%00000010
            sta CODEC_LOW
            lda #%00010100
            sta CODEC_HI
            lda #$01
            sta CODEC_CTRL ; 
            jsr CODEC_WAIT_FINISH
            ; LDA #%0001011000000010      ;R11 - ADC Interface Control
            lda #%00000010
            sta CODEC_LOW
            lda #%00010110
            sta CODEC_HI
            lda #$01
            sta CODEC_CTRL ; 
            jsr CODEC_WAIT_FINISH
            ; LDA #%0001100111010101      ;R12 - Master Mode Control
            lda #%01000101
            sta CODEC_LOW
            lda #%00011000
            sta CODEC_HI
            lda #$01
            sta CODEC_CTRL ; 
            jsr CODEC_WAIT_FINISH
            
            jmp     PSG_MUTE

PSG_INT_L_PORT = $D600          ; Control register for the SN76489
PSG_INT_R_PORT = $D610          ; Control register for the SN76489

PSG_MUTE:   stz $1
            lda #$9f            ; Mute channel #0 (1001111)
            sta PSG_INT_L_PORT
            sta PSG_INT_R_PORT

            lda #$bf            ; Mute channel #2 (1011111)
            sta PSG_INT_L_PORT
            sta PSG_INT_R_PORT

            lda #$df            ; Mute channel #3 (1101111)
            sta PSG_INT_L_PORT
            sta PSG_INT_R_PORT

            lda #$ff            ; Mute channel #4 (1111111)
            sta PSG_INT_L_PORT
            sta PSG_INT_R_PORT

            clc
            rts

CODEC_WAIT_FINISH
CODEC_Not_Finished:
            lda CODEC_CTRL
            and #$01
            cmp #$01 
            beq CODEC_Not_Finished
            rts
            
        .send
        .endn


