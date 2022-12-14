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

STAT_RX_NEMPTY  =     1
STAT_RX_FULL    =     2
STAT_RX_EOI     =     4
STAT_NO_ACK     =    16     ; Device not preset

            .section    dp
iec_timeout .byte       ?
mark        .byte       ? 
eoi         .byte       ?
            .send            

            .section    kernel

settmo
            sta     iec_timeout
            rts
            
read_byte

          ; Return EOI if the stream has hit EOI.
            lda     eoi
            beq     _read
            lda     #kernel.iec.EOI
            sec
            rts

_read
          ; Save I/O map and switch to I/O Zero.
            phx
            ldx     $1
            stz     $1

        smb     1,$1
        inc     $c000+79
        stz     $1

          ; Set 'mark' to the future timeout time.
          ; The C64 claims to time out after 64ms.
          ; To be safe (not knowing where we are
          ; in the current "tick" cycle), we wait 
          ; ~0.066 - ~0.08s.
            lda     kernel.ticks
            clc
            adc     #5      ; 4=0.66s + 1
            sta     mark
_loop
            lda     LISTNER_FIFO_STAT
            lsr     a       ; Carry set if fifo is empty
            bcc     _found

          ; If timeouts are disabled, just keep trying...
            lda     iec_timeout
            ;bpl     _loop       ; no timeout check

          ; Otherwise, keep trying until we reach mark.
            lda     kernel.ticks
            cmp     mark
            bcc     _loop

          ; Report a timeout; carry is already set.
            lda     kernel.iec.TIMEOUT_READ                                            
            bra     _out

_found
          ; Read the data.
            lda     LISTNER_DTA

          ; Update our internal EOI flag.
            pha
            lda     LISTNER_FIFO_STAT
            and     #STAT_RX_EOI
            sta     eoi
            pla

_out
          ; Restore I/O map.
            stx     $1
            plx
            rts
            

write_byte
            phx
            ldx     $1
            stz     $1
            sta     TALKER_DTA
            bra     ret_stat

write_last_byte
            phx
            ldx     $1
            stz     $1
            sta     TALKER_DTA_LAST
            bra     ret_stat

send_atn_byte
        smb     1,$1
        rmb     1,$1
        inc     $c000+78
        stz     $1
            phx
            ldx     $1
            stz     $1
            sta     TALKER_CMD
            bra     ret_stat

send_atn_last_byte
            phx
            ldx     $1
            stz     $1
            sta     TALKER_CMD_LAST
            bra     ret_stat

ret_stat
            stz     eoi
            jsr     delay500us  ; Better would be wait for empty tx fifo or timeout.
            lda     LISTNER_FIFO_STAT
            and     #STAT_NO_ACK
            clc
            beq     _out
            sec
            lda     #kernel.iec.NO_DEVICE   ; TODO: when is this set?
_out        
            stx     $1
            plx
            rts

delay500us
            lda     #50         ; Kill ~500us
_loop       jsr     _delay10us
            dec     a
            bne     _loop

_delay10us  jsr     _delay2
_delay8     jsr     _delay4
_delay4     jsr     _delay2
_delay2     jsr     _delay1
_delay1   ; Kill 8 clock cycles ... slightly larger than 1Mhz = 1us
            nop
            nop
            nop
            nop
            nop            
            rts

            .send
            .endn
            .endn
