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
            .send            

            .section    shell

strings:
str         .namespace
unknown     .text   "?", 13, 0
prompt      .text   13,"READY",13,0
dir         .null   "DIR"
stat        .null   "STAT"
rds         .null   "RDS"
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
            rts

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
            .word   str.dir,    dir
            .word   str.stat,   my_status
            .word   str.rds,    Read_Drive_Status
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
                     

