; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel
            .section    kernel

settmo
            sta     iec_timeout
            rts
            
iecin
iecout
untalk
unlstn
listen
talk
            sec
            rts
            
lstnsa
talksa
            sec
            rts
            


; IEC
; When Writting
TALKER_CMD      = $D680     ; Write all Command here, save $3F, $5F
TALKER_CMD_LAST = $D681     ; This is for $3F or $5F Only
TALKER_DTA      = $D682     ; Any other data, write here
TALKER_DTA_LAST = $D683     ; Write to this address for the last data to send
; Reading
LISTNER_DTA     = $D680     ; Read Data From FIFO
LISTNER_FIFO_STAT   = $D681 ; Bit[0] Empty Flag (1 = Empty, 0 = Data in FIFO)
LISTNER_FIFO_CNT_LO = $D682 
LISTNER_FIFO_CNT_HI = $D683


SetIOPage0
        stz     $1
        rts
        
SetIOPage2
        pha
        lda     #2
        sta     $1
        pla
        rts

Read_Drive_Status
            jsr SetIOPage0
            ldx #$00
            lda #$48
            sta TALKER_CMD
            lda #$6F
            sta TALKER_CMD
            lda #$5F
            sta TALKER_CMD_LAST 
Not_The_Last_Byte_Rx:
FIFO_Empty_Still:
            lda LISTNER_FIFO_STAT       
            and #$01
            cmp #$01
            beq FIFO_Empty_Still     
            ; There is a Byte the FIFO go read it
            lda LISTNER_DTA
            and #$BF 
            pha 
            jsr SetIOPage2        ;
            pla 
            sta $C320, x    ; Store it in the buffer
            jsr SetIOPage0        ;            
            inx
            lda LISTNER_FIFO_STAT ; Read the Stat Again, because Last Bit has been updated when you read a byte out FiFo
            and #$80
            cmp #$80
            bne Not_The_Last_Byte_Rx
            ; if get here, it is because we read the last byte and we are done.

            
            rts
            

status
            stz $1
            ldx #$00

            lda #$48
            sta TALKER_CMD
            lda #$6F
            sta TALKER_CMD
            lda #$5F
            sta TALKER_CMD_LAST 

            jsr read_data

            lda #$5F
            ;sta TALKER_CMD_LAST

            ; Close the transaction
            lda #$28
            sta TALKER_CMD
            lda #$E0 
            sta TALKER_CMD
            lda #$3F
            sta TALKER_CMD_LAST
            rts

my_status
            stz $1

            lda #$48
            sta TALKER_CMD          ; Talk 8 (device)
            lda #$6F
            sta TALKER_CMD          ; Reopen channel 15

            jsr read_data

            lda #$5F                ; Untalk channel 15
            sta TALKER_CMD_LAST

            lda #$3F                ; Unlisten all devices (until atn)
            sta TALKER_CMD_LAST
 rts


            ;sta TALKER_CMD_LAST


            rts


test_IEC
            stz     $1

            ;IEC Test 
            ; Send the command
            lda #$28
            sta TALKER_CMD
            lda #$F0 
            sta TALKER_CMD
            lda #'$' 
            sta TALKER_DTA_LAST
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
            rts

send_str
            phx
            phy

            lda     (src)
            tax
            ldy     #1
_loop
            lda     (src),y
            beq     _done
            stx     TALKER_DTA
            tax
            iny
            bra     _loop

_done       stx     TALKER_DTA_LAST
            clc
            
            ply
            plx
            rts

dir
            phy

          ; Point 'src' at the file name ("$").
            lda     #<_fname
            sta     src+0
            lda     #>_fname
            sta     src+1

          ; Load the data to $801
            ldy     #0      ; Use write to address in 'dest'
            lda     #<$801
            sta     dest+0
            lda     #>$801
            sta     dest+1
            
          ; Load the data
            jsr     load
            bcs     _out
            
          ; Show the data
            jsr     list
            
_out
            ply
            rts
_fname      .null   "$"            
            
list
            phx
            phy

            lda     #2
            sta     $1

            lda     #<$801
            sta     src+0
            lda     #>$801
            sta     src+1

            lda     #<$c000+800
            sta     dest+0
            lda     #>$c000+800
            sta     dest+1
            
            ldy     #0
            ldx     size+1
_outer      
            beq     _last
_bulk       
            lda     (src),y
            sta     (dest),y
            iny
            bne     _bulk
            inc     src
            ;inc     dest
            dex
            bra     _outer            

_last
            cpy     size+1
            beq     _done
            lda     (src),y
            sta     (dest),y
            iny
            bra     _last
            
_done       
            stz     $1
            ply
            plx
            clc
            rts
            
load
    ; IN:   src points to the file name
    ;       Y = sub-device (0 implies dest = load address)
            
            stz     $1

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
            sty size+0
            sta size+1

            lda #$5F
            sta TALKER_CMD_LAST

            ; Close the transaction
            lda #$28
            sta TALKER_CMD
            lda #$E0 
            sta TALKER_CMD
            lda #$3F
            sta TALKER_CMD_LAST
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
            ldx     #0            
            ldy     #0

_loop       jsr     read_byte
            bcs     _done
            smb     1,$1
            sta     (dest),y
            stz     $1
            iny
            bne     _loop
            inx
            inc     dest+1
            bra     _loop
_done
            txa
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
            
Read_Dir    stz $1
            ldx #$00
            ;IEC Test 
            ; Send the command                
            lda #$28
            sta TALKER_CMD
            lda #$F0 
            sta TALKER_CMD
            lda #'$' 
            sta TALKER_DTA_LAST    
            lda #$3F
            sta TALKER_CMD_LAST
            ; go read the data 

            lda #$48
            sta TALKER_CMD
            lda #$60
            sta TALKER_CMD
            lda #$5F
            sta TALKER_CMD_LAST
Not_The_Last_Byte_RxDir:
FIFO_Empty_StillDir:
            lda LISTNER_FIFO_STAT       
            and #$01
            cmp #$01
            beq FIFO_Empty_StillDir     
            ; There is a Byte the FIFO go read it
            lda LISTNER_DTA
            and #$BF 
            pha 
            jsr SetIOPage2        ;
            pla 
            sta $C320, x    ; Store it in the buffer of your choice
            jsr SetIOPage0        ;            
            inx
            lda LISTNER_FIFO_STAT ; Read the Stat Again, because Last Bit has been updated when you read a byte out FiFo
            and #$80
            cmp #$80
            bne Not_The_Last_Byte_RxDir
            ; Close the transaction
            lda #$28
            sta TALKER_CMD
            lda #$E0 
            sta TALKER_CMD
            lda #$3F
            sta TALKER_CMD_LAST
            rts
            
            .send
            .endn
