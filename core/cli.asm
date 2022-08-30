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
device      .byte       ?
            .send            

            .section    shell

strings:
str         .namespace
unknown     .text   "?", 13, 0
prompt      .text   13,"READY DEVICE",0
dir         .null   "DIR"
stat        .null   "STAT"
rds         .null   "RDS"
cls         .null   "CLS"
list        .null   "LIST"
load        .null   "LOAD"
drive       .null   "DRIVE"
run         .null   "RUN"
sys         .null   "SYS"
help        .null   "HELP"
intro       .text   13,"Type 'help' for help.",13,0
            .endn

help_text      
            .text   13,"Supported commands:",13
            .text   "   cls         Clears the screen.",13
            .text   "   drive #     Changes the drive to #.",13
            .text   "   dir         Displays the directory.",13
            .text   "   load",$22,"fname",$22," Loads the given file ',1'.", 13
            .text   "   list        LISTs directories and simple programs.",13
            .text   "   run         Runs loaded programs.",13
            .text   "   help        Shows this help.",13
            .text   13,0

commands
            .word   str.cls,    cls
            .word   str.dir,    dir
            .word   str.list,   list
            .word   str.load,   load
            .word   str.drive,  drive
            .word   str.run,    platform.far_exec
            .word   str.help,   help
            .byte   0           

help
            lda     #<help_text
            sta     src+0
            lda     #>help_text
            sta     src+1
            jmp     kernel.puts

start
            jsr     banner

            lda     #>strings
            sta     str_ptr+1

            ldy     #<str.intro
            jsr     puts
            bra     shell

shell
            lda     #8
            sta     device

            stz     far_addr+0
            stz     far_addr+1
            stz     far_addr+2
            stz     far_addr+3
            
            jsr     prompt
_loop       jsr     get_cmd
            jsr     do_cmd
            bcc     _loop

            ldy     #<str.unknown
            jsr     puts
            bra     _loop

cr
            lda     #13
            jmp     putc

prompt
            ldy     #<str.prompt
            jsr     puts
            lda     #' '
            jsr     putc
            lda     device
            ora     #'0'
            jsr     putc
            jmp     cr
            
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
_loop       ldy     commands,x
            beq     _out
            inx
            inx
            jsr     strcmp
            bcs     _next
            jsr     _call
            bcc     _ready
            jsr     kernel.error
_ready            
            jmp     prompt
_next
            inx
            inx
            bra     _loop
_out                    
            rts
_call
            jmp     (commands,x)

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
            jsr     putc
            clc
            rts

find_arg
    ; IN: Y points just beyond the command string

_loop
            lda     cmd,y
            cmp     #' '
            beq     _next
            cmp     #13
            beq     _error
            clc
            rts
_next
            iny
            bne     _loop
_error
            sec
            rts                                    

drive
            jsr     find_arg
            lda     #ILLEGAL_DEVICE_NUMBER
            bcs     _done

            lda     cmd,y
            cmp     #'8'
            beq     _set
            cmp     #'9'
            beq     _set

            lda     #ILLEGAL_DEVICE_NUMBER
            sec
_done       
            rts
_set
            sbc     #'0'
            sta     device
            clc
            bra     _done                        

dir
            phx
            phy

          ; Point 'src' at the file name ("$").
            ldx     #<_fname
            ldy     #>_fname
            lda     #1
            jsr     SETNAM

          ; Request operation on 0,device,0
            lda     #0      ; Logical device # ... not meaningful here.
            ldx     device
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

