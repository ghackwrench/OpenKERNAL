; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel

            .section    kernel

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



send_str
            phx
            phy

            lda     (src)
   smb 1,$1
   ;sta $c000
   stz $1
            tax
            ldy     #1
_loop
            lda     (src),y
            beq     _done
            cmp     #$22    ; end quote
            beq     _done
   smb 1,$1
   ;sta $c000,y
   stz $1
            stx     TALKER_DTA
            tax
            iny
            bra     _loop

_done       stx     TALKER_DTA_LAST
            clc
            
            ply
            plx
            rts
            
            
load
    ; IN:   src points to the file name
    ;       Y = sub-device (0 implies dest = load address)
            
            stz     $1
  smb 1,$1
  tya
  ora #48
  ;sta $c000+80
  stz $1

            ;IEC Test 
            ; Send the command
            lda #$28
            sta TALKER_CMD
            lda #$F0 
            sta TALKER_CMD

            jsr     send_str

            lda #$3F
            sta TALKER_CMD_LAST
            
            lda #$48
            sta TALKER_CMD
            lda #$60
            sta TALKER_CMD

          ; go read the data 
            jsr read_data

            lda #$5F
            sta TALKER_CMD_LAST

            ; Close the transaction
            lda #$28
            sta TALKER_CMD
            lda #$E0 
            sta TALKER_CMD
            lda #$3F
            sta TALKER_CMD_LAST

            clc
            rts
            
read_data
    ; IN:   Y=0 (load to dest) or Y=1 (load to embedded address)
    ; Out:  A:Y = count of bytes read, dest updated.  CS on error.
 
            phx
            
          ; Read the would-be load-address into A:X
            jsr     read_byte
            bcs     _out
            tax                 ; Stash the LSB in X
            jsr     read_byte
            bcs     _out

          ; Update dest ptr if the sub-channel is 1
            cpy     #1
            bne     _read
            stx     dest+0
            sta     dest+1

_read       

_loop       jsr     read_byte
            smb     1,$1
            sta     (dest)
            stz     $1
            inc     dest
            bne     _next
            inc     dest+1
_next       bcc     _loop
            clc
_out
            plx
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
            
            .send
            .endn
