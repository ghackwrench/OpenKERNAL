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
            
read_byte
            smb     1,$1
            inc     $c000+79
            stz     $1
            lda     LISTNER_FIFO_STAT
            lsr     a
            bcs     read_byte
            lda     LISTNER_DTA
            pha
            lda     LISTNER_FIFO_STAT
            asl     a
            pla
            rts
            

send_data
            phx
            ldx     $1
            stz     $1
            sta     TALKER_DTA
            bra     ret_stat

send_data_last
            phx
            ldx     $1
            stz     $1
            sta     TALKER_DTA_LAST
            bra     ret_stat

send_atn
            phx
            ldx     $1
            stz     $1
            sta     TALKER_CMD
            bra     ret_stat

send_atn_last
            phx
            ldx     $1
            stz     $1
            sta     TALKER_CMD_LAST
            bra     ret_stat

ret_stat
            lda     LISTNER_FIFO_STAT
            and     #16
            clc
            adc     #$ff
            lda     #kernel.io.DEVICE_NOT_PRESENT
            stx     $1
            plx
            rts


            .send
            .endn
            .endn
