; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  platform
iec         .namespace              

; The C256 Foenix Jr. has the low-level IEC protocol implemented in its FPGA.

; IEC

; Writting:
TALKER_CMD      = $D680     ; Write all Command here, save $3F, $5F
TALKER_CMD_LAST = $D681     ; This is for $3F or $5F Only
TALKER_DTA      = $D682     ; Any other data, write here
TALKER_DTA_LAST = $D683     ; Write to this address for the last data to send

; Reading:
LISTNER_DTA     = $D680     ; Read Data From FIFO
LISTNER_FIFO_STAT   = $D681 ; Bit[0] Empty Flag (1 = Empty, 0 = Data in FIFO)
LISTNER_FIFO_CNT_LO = $D682 
LISTNER_FIFO_CNT_HI = $D683

            .section    dp
iec_timeout .byte       ?
            .send            

            .section    kernel

settmo
            sta     iec_timeout ; TODO: move here.
            rts
            
iecin


iecout
            sta    TALKER_DTA
            rts 

talk
            cmp     #16
            bcs     _out
            ora     #$40
            jmp     send_talker_cmd
_out        rts            
            
untalk
            lda     #$5f
            jmp     send_talker_cmd
            rts

listen
            cmp     #16
            bcs     _out
            ora     #$20
            jmp     send_talker_cmd
_out        rts            


unlstn
            lda     #$3f
            jmp     send_talker_cmd


talksa
lstnsa
    ; These two routines are nominally separate to hint the kernel
    ; about what the bus is expected to do.  On the C256 Jr., the
    ; state machine in the FPGA automatically handles both cases.
            cmp     #16
            bcs     _out
            ora     #$60
            jmp     send_talker_cmd
_out        rts            


send_talker_cmd
            phx
            ldx     $1
            stz     $1
            cmp     #$3f
            beq     _last
            cmp     #$5f
            beq     _last
            sta     TALKER_CMD
_done       stx     $1
            plx
            clc
            rts
_last       sta     TALKER_CMD_LAST
            bra     _done


            .send
            .endn
            .endn
