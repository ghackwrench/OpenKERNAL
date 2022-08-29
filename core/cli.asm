; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Simple command-line interface for use when nothing else is included.

            .cpu    "w65c02"

            .namespace  kernel
shell       .namespace            

            .virtual    Tokens  ; $90 bytes here in page 2
cmd         .fill   80
            .endv

            .section    dp
str_ptr     .word       ?
printing    .word       ?
            .send            

            .section    shell

strings:
str         .namespace
unknown     .text   "?", 13, 0
prompt      .text   13,"READY",13,0
dir         .null   "DIR"
stat        .null   "STAT"
rds         .null   "RDS"
cls         .null   "CLS"
list        .null   "LIST"
            .endn


start
            jsr     banner

            lda     #>strings
            sta     str_ptr+1
            bra     shell

shell
            jsr     prompt
_loop       jsr     get_cmd
            jsr     do_cmd
            bcc     _loop

            ldy     #<str.unknown
            jsr     puts
            bra     _loop

prompt
            ldy     #<str.prompt
            jmp     puts
            
get_cmd
            ldx     #0
_loop       phx           
            jsr     CHRIN
            plx
            sta     cmd,x
            inx
            cmp     #13
            bne     _loop
            jmp     platform.console.putc

do_cmd
            clc
            ldx     #0
_loop       ldy     _table,x
            beq     _out
            inx
            inx
            jsr     strcmp
            bcs     _next
            jsr     _call
            jmp     prompt
_next
            inx
            inx
            bra     _loop
_out                    
            rts
_call
            jmp     (_table,x)
_table
            .word   str.cls,    cls
            .word   str.dir,    dir
            .word   str.list,   list
;            .word   str.stat,   my_status
;            .word   str.rds,    Read_Drive_Status
            .byte   0           

strcmp
            sty     str_ptr
            ldy     #0
_loop       
            clc
            lda     (str_ptr),y
            beq     _out
            iny
            cmp     cmd-1,y
            beq     _loop
            sec
_out        rts            

cls         lda     #12
            jmp     putc

dir
            phx
            phy

          ; Point 'src' at the file name ("$").
            ldx     #<_fname
            ldy     #>_fname
            lda     #1
            jsr     SETNAM

          ; Request operation on 0,8,0
            lda     #0      ; Logical device # ... not meaningful here.
            ldx     #8      ; Hard-coded for the moment
            ldy     #0      ; No sub-device / "command" -> use $0801
            jsr     SETLFS

          ; Load the data
            lda     #0      ; load, not verify
            ldx     #<$801
            ldy     #>$801
            jsr     LOAD
            bcs     _out    ; TODO: print the error
            
          ; Show the data
            jsr     list
            
_out
            ply
            plx
            rts
_fname      .text   "$"            

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



putc
    ; IN: A = character code
            jmp     platform.console.putc

puts
    ; IN: Y=LSB of a string in 'strings' above.
            sty     str_ptr
            ldy     #0
_loop       lda     (str_ptr),y
            beq     _out
            jsr     putc
            iny
            bra     _loop
_out        
            clc
            rts                        
        

            .send 
            .endn
            .endn
                     

.if false


SetIOPage0
            stz     $1
            rts

SetIOPage2
            stz     $1
            inc     $1
            inc     $1
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

.endif

