; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel
            .namespace  io

            .section    dp

cur_in      .byte       ?       ; current input device
cur_out     .byte       ?       ; current output device
io_last     .byte       ?       ; device # of most recent read/write operation
io_status   .byte       ?       ; status from most recent read/write operation

; These could be moved to the file object
scraping    .byte       ?       ; screen scraping bool.
scrape_x    .byte       ?       ; screen scrape x value.
quoted      .byte       ?       ; screen scrape inside quotes.

            .send

MAX_FILES   =   10

            .section    kmem
files       .fill       MAX_FILES * 8          
            .send
            
file        .namespace
            .virtual    files
state       .byte       ?       ; OPEN/CLOSED state
device      .byte       ?
secondary   .byte       ?
            .endv
            .endn

            .section    kernel

spin
        lda #2
        sta $1
_loop        
        lda $c000
        inc a
        sta $c000
        bra _loop


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

find:

    ; IN: A = logical file #
    ; SUCCESS:
    ;   Carry clear
    ;   X->device entry
    ;   Y->file entry
    ; FAIL:
    ;   Carry set
    ;   A = FILE_NOT_OPEN or TOO_MANY_FILES
    
            jsr     link
            bcs     _out
            lda     file.state,y
            bne     _device
            lda     #FILE_NOT_OPEN
            sec
_out        rts            

_device    
            lda     file.device,y
            cmp     #8
            bcc     _found
            lda     #8

_found
            asl     a
            asl     a
            asl     a
            tax
            rts             

link:
    ; IN: A = logical file #
    ; SUCCESS:
    ;   Carry clear
    ;   Y->file entry
    ; FAIL:
    ;   Carry set
    ;   A = TOO_MANY_FILES

            cmp     #MAX_FILES
            bcc     _link
            lda     #TOO_MANY_FILES
            sec
            rts

_link       asl     a
            asl     a
            asl     a
            tay
            rts

error
    jsr dump
            pha
            phy
            pha
            ldy     #0
_loop       lda     _msg,y
            beq     _number
            jsr     platform.console.putc
            iny
            bra     _loop
_number     pla
            clc
            adc     #'0'
            jsr     platform.console.putc
            jsr     crlf
            ply
            pla
            sec
            rts
_msg        .null   "I/O ERROR "

crlf
            lda     #$0a
            jsr     platform.console.putc
            lda     #$0d
            jsr     platform.console.putc
            rts

dump
        pha
        phx
        phy
        lda #$0d
        jsr platform.console.putc
        ldy #0
_loop   lda files,y
        jsr _pb
        iny
        tya
        and #$07
        bne _loop        
        lda #$0d
        jsr platform.console.putc
        cpy #80
        bne _loop
        
        ply
        plx
        pla
        rts
_pb
        pha
        lsr a        
        lsr a        
        lsr a        
        lsr a        
        jsr _nibble
        pla
        and #$0f
        jsr _nibble
        lda #' '
        jmp platform.console.putc
_nibble        
        tax
        lda _hex,x
        jmp platform.console.putc
_hex    .null "0123456789abcdef"
        

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ioinit
            stz     scraping    ; Not presently screen scraping.
            stz     quoted      ; Not presently in a quoted string 

          ; Init (zero) the files table
            ldx     #0
_loop       stz     files,x
            inx
            cpx     #8 * MAX_FILES
            bne     _loop
            jmp     reopen

reopen
          ; Open keyboard as stdin
            lda     #0      ; stdin
            ldx     #0      ; keyboard
            ldy     #0      ; dummy sub-device
            jsr     setlfs
            jsr     open
            ldx     #0
            jsr     chkin

          ; Open screen as stdout
            lda     #1      ; stdout
            ldx     #3      ; screen
            ldy     #0      ; dummy sub-device
            jsr     setlfs
            jsr     open
            ldx     #1
            jsr     chkout

            rts
          

readst 
            lda     io_last
            lda #0
            rts

setlfs      
            sta     cur_logical
            stx     cur_device
            sty     cur_addr
            rts            

setnam    
            sta     fname_len
            stx     fname+0
            sty     fname+1
            rts        

open
            lda     cur_logical
            jsr     link
            bcs     _error
            lda     file.state,y
            beq     _open
            lda     #FILE_OPEN
_error      jmp     error

_open
            lda     cur_device
            sta     file.device,y
            lda     cur_addr
            sta     file.secondary,y

            lda     cur_device
            asl     a
            asl     a
            asl     a
            tax

            jsr     open_x
            bcs     _error
            rts


close
            jsr     find
            bcc     _close
            jmp     error
_close      jmp     close_x

chk
    ; IN: X = logical file ID
    ; Reports and returns an error if the file is invalid.
            phx
            txa
            jsr     find
            bcc     _out
            jsr     error
_out        plx
            rts

chkin
            phy
            jsr     chk
            bcs     _out
            stx     cur_in
_out        ply
            rts
chkout
            phy
            jsr     chk
            bcs     _out
            stx     cur_out
_out        ply
            rts
            
clrchn ; TODO: not sure how this is /supposed/ to work.
   clc
   rts
            phy
            
_stdin      lda     cur_in
            jsr     find
            bcs     _stdout
            jsr     close_x
            
_stdout     lda     cur_out
            jsr     find
            bcs     _reset
            jsr     close_x

          ; Reset stdin/stdout to 0/1
_reset      ldx     #0
            jsr     chkin
            ldx     #1
            jsr     chkout

            clc
            ply
            rts

chrin
            phx
            phy
            lda     cur_in
            jsr     find
            bcs     _error

            lda     file.device,y
            bne     _read

_screen     jsr     screen
            bra     _out

_read       jsr     read_x
            bcc     _out
_error      
            jsr     error
_out        
            ply
            plx
            rts            

screen
      ; Resume an inprogress screen-scrape 
        lda     scraping
        bne     _next

      ; Begin screen editing
        lda     platform.console.cur_x
        sta     scrape_x    ; Start of input
        sta     quoted      ; Disables toupper if not at col zero

_read   jsr     kernel.keyboard.deque
        bcc     _key
        jsr     kernel.thread.yield
        bra     _read
        
_key    cmp     #13     ; ENTER
        beq     _scrape
        jsr     emacs
        jsr     platform.console.putc
        bra     _read

_scrape
        sta     scraping    ; 13 (enter) is non-zero.
_next
        ldy     scrape_x
        cpy     platform.console.cur_x
        bne     _getchar
        stz     scraping
        stz     quoted
        lda     #13
        bra     _okay

_getchar
        phx
        ldx     $1  ; TODO: move to console driver.
        lda     #2
        sta     $1
        lda     (platform.console.ptr),y
        stx     $1
        plx
        
        inc     scrape_x
        cmp     #32
        bcc     _next   ; can't generate these
        cmp     #$22    ; Quote
        beq     _quote
        ldx     quoted
        bne     _okay
        cmp     #'z'+1
        bcs     _okay
        cmp     #'a'
        bcc     _okay
        eor     #$20    ; toupper
_okay   
        clc
        rts

_quote  
        lda     quoted
        stz     quoted
        bne     _ret
        inc     quoted
_ret    lda     #$22     ; quote
        bra     _okay

map     .macro  key, ctrl
        .byte   \key, (\ctrl & 31)
        .endm
emacs
        phx
        ldx     #0
_loop   cmp     _map,x
        beq     _found
        inx
        inx
        cpx     #_end
        bne     _loop
        bra     _out
_found  lda     _map+1,x
_out    plx
        rts
_map
        .map    HOME,   'a'
        .map    END,    'e'
        .map    UP,     'p'
        .map    DOWN,   'n'
        .map    LEFT,   'b'
        .map    RIGHT,  'f'
_end    = * - _map        

getin
            phx
            lda     cur_in
            jsr     find
            bcs     _error
            jsr     read_x
            bcc     _done
_error      jsr     error
_done       plx
            ora     #0
            rts

chrout
            phx
            phy
            pha
            lda     cur_out
            jsr     find
            bcc     _okay
            ply     ; drop the character
            jsr     error
            bra     _done
_okay       pla
            pha
            jsr     write_x
            pla
_done       ply
            plx
            rts

clall
            phy

          ; Close all
          ; Manually, to hide errors.
            lda     #0
_loop       pha
            jsr     find
            bcs     _next            
            jsr     close_x
_next       pla
            inc     a
            cmp     #MAX_FILES
            bne     _loop            

          ; Reset stdin/stdout
            jsr     reopen
            ply
            rts



            .send
            .endn
            .endn

