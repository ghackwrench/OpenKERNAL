; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel

            .section    dp
printing    .byte       ?
            .send            

            .section    kernel

settmo
            sta     iec_timeout
            rts
            
iecin


iecout
            sta    TALKER_DTA
            rts 

untalk
            lda     #$5f
            jmp     send_talker_cmd
            rts

unlstn
            lda     #$3f
            jmp     send_talker_cmd

talk
            cmp     #32
            bcs     _out
            ora     #$40
            jmp     send_talker_cmd
_out        rts            
            
listen
            cmp     #32
            bcs     _out
            ora     #$20
            jmp     send_talker_cmd
_out        rts            

talksa
lstnsa
    ; These two routines are nominally separate to hint the kernel
    ; about what the bus is expected to do.  On the C256 Jr., the
    ; state machine in the FPGA automatically handles both cases.
            cmp     #32
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
            lda     #13
            jsr     platform.console.putc

            phx
            phy

            ldx     #0  ; count MSB
            ldy     #0  ; count LSB

            lda     #<$801
            sta     src+0
            lda     #>$801
            sta     src+1

_line       
          ; File ends when the would-be next address is zero.
            jsr     _fetch
            sta     tos_l       ; tmp
            jsr     _fetch
            ora     tos_l
            beq     _done

          ; Fetch the line number
            jsr     _fetch
            sta     tos_l
            jsr     _fetch          
            sta     tos_h
            
          ; Print the line number
            jsr     print_number          

          ; Print the rest of the line
_loop       
            jsr     _fetch
            beq     _eol
            
            cmp     #32
            bcc     _fill
            cmp     #128
            bcc     _putc
_fill       lda     #' '
          ; Check for a token...
_putc       jsr     platform.console.putc
            bra     _loop
            
_eol        lda     #13
            jsr     platform.console.putc
            bra     _line
                        
_fetch
            lda     (src),y
            iny
            bne     _fetched
            inc     src+1
_fetched
            ora     #0
            rts  
            
_done       
            ply
            plx
            clc
            rts

print_number
            phx
            phy

            stz     printing
            ldx     #0      ; Not yet printing
            ldy     #0
_loop       jsr     _cmp
            bcc     _print
            inc     printing
            inx
            jsr     _sub
            bra     _loop
_print      lda     printing
            beq     _next

            txa
            clc
            adc     #'0'
            jsr     platform.console.putc
            ldx     #0
_next
            iny
            iny
            cpy     #10
            bne     _loop

            lda     printing
            bne     _done
            lda     #'0'
            jsr     platform.console.putc
            
_done
            lda     #' '
            jsr     platform.console.putc
            ply
            plx
            clc
            rts            
_cmp
            lda     tos_h
            cmp     _table+1,y
            bcc     _out        ; MSB is lower
            bne     _out        ; MSB is higher
            lda     tos_l
            cmp     _table+0,y  ; Result is LSB compare
_out        rts            

_sub        
            sec
            lda     tos_l
            sbc     _table+0,y
            sta     tos_l
            lda     tos_h
            sbc     _table+1,y
            sta     tos_h
            rts
           
            
_table
            .word   10000, 1000, 100, 10, 1

            
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
