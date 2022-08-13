; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; This file borrows from the w6502c TinyCore kernel by the same author.

            .cpu        "w65c02"

            .namespace  hardware

ps2         .namespace

self        .namespace
            .virtual    DevState
dummy       .word       ?   ; TODO: Crazy?
upper       .byte       ?       ; upper handler
irq         .byte       ?       ; IRQ vector
port        .byte       ?       ; PS2 port (0/1)
state       .byte       ?       ; State machine state.
wait        .byte       ?       ; starting tick
rx1         .byte       ?       ; least recent auto-detect byte
rx2         .byte       ?       ; middle auto-detect byte
rx3         .byte       ?       ; most recent auto-detect byte
            .endv
            .endn            

            .section    kernel

vectors     .kernel.device.mkdev    dev

init
    ; A = upper,  Y = IRQ
    ; X <- initialized device, or carry set on error
    
            jsr     kernel.device.alloc
            bcs     _out

            sta     self.upper,x
            tya
            sta     self.irq,x
            
            sec
            sbc     #irq.ps2_0
            sta     self.port,x

            lda     #<vectors
            sta     kernel.src
            lda     #>vectors
            sta     kernel.src+1
            jsr     kernel.device.install

_out        rts

dev_open

            stz     self.rx1,x
            stz     self.rx2,x
            stz     self.rx3,x
            jsr     hardware.kbd1.init
            jsr     hardware.kbd2.init

          ; Wait for reset success
            lda     #state.reset
            stz     self.state,x

          ; Install our IRQ handler
            txa
            ldy     self.irq,x
            jsr     irq.install
            
          ; Enable our IRQ
            lda     self.irq,x
            jsr     irq.enable

            phx
            txa
            tay

          ; Enable the port and interrupts
            phy
            lda     self.upper,y
            tax
            lda     self.port,y
            tay
            jsr     kernel.device.set
            ply
            bcs     _out

          ; Send a reset
            lda     #$ff    ; Reset
            jsr     send_cmd
            bcs     _out

          ; Wait for the state to change
            lda     kernel.ticks
            sta     self.wait,y
_loop       lda     self.state,y
            cmp     #state.reset
            clc
            bne     _out
            jsr     kernel.thread.yield
            lda     kernel.ticks
            sec
            sbc     self.wait,y
            cmp     #60*3
            bcc     _loop
            
          ; Ugh, no response ... just send some enables.
            jsr     report

_out        plx
            rts

send_cmd
            phy
            pha
            
            lda     self.upper,y
            tax

            lda     self.port,y
            tay
    
            pla            
            jsr     kernel.device.send
            ply

            rts                     

dev_close
            lda     self.irq,x
            jmp     irq.disable

dev_get
dev_set
dev_send
dev_status
dev_fetch
            clc
            rts

dev_data
            txa
            tay

          ; Spin the IRQ counter
.if false
            lda     #2
            sta     $1
            ldx     self.irq,y
            inc     $c000,x
            stz     $1
.endif
            ldx     self.upper,y
            jsr     kernel.device.get

            ldx     self.state,y
    cpx #state.end
    bcc _ok
    ldx #0
_ok    
            jmp     (_table,x)
            
_table      .dstruct    state

state       .struct
reset       .word   wait_reset
ack         .word   wait_ack
data        .word   wait_data
kbd1        .word   state_kbd1      ; Mode-1 keyboard state machine
kbd2        .word   state_kbd2      ; Mode-2 keyboard state machine
mouse0      .word   state_mouse0    ; Original 3-byte state machine
end         .ends



wait_reset   
    ; Whatever we got, advance
            jmp     report


            cmp     #$aa        ; self test passed
            beq     report

            cmp     #$fc
            beq     _done   ; Reset failed, wait for user.
            cmp     #$fd
            beq     _done   ; Reset failed, wait for user.
            
            lda     #$ff        ; reset
            jmp     send_cmd    ; Resend requested

_done       rts

report
            lda     #state.data
            sta     self.state,y

          ; Request reporting
            lda     #$f4    ; Enable reporting
            jmp     send_cmd

wait_ack
            cmp     #$fa
            beq     _next

            lda     #$d4
            jmp     send_cmd
            
_next       lda     #state.data
            sta     self.state,y
            rts

wait_data
            bra     wait_auto
            
            cmp     #$aa
            ;beq     report ; Hot-plug event
            rts



wait_auto
            pha
            lda     self.rx2,b,y
            sta     self.rx1,b,y
            lda     self.rx3,b,y
            sta     self.rx2,b,y
            pla
            sta     self.rx3,b,y
.if false
          ; Mode1 keyboard?
_check1     lda     self.rx3,b,y
            bpl     _not1
            and     #$7f
            cmp     self.rx2,b,y
            beq     _mode1
_not1       nop
.endif            
          ; Mode2 keyboard?  
_check2     lda     self.rx2,b,y
            cmp     #$f0    ; release
            bne     _not2
            lda     self.rx1,b,y
            cmp     self.rx3,b,y
            beq     _mode2
_not2       nop  
            
          ; Mouse?
            lda     self.rx1,b,y
            and     #$cf
            eor     #$08
            beq     _mouse

_out        rts

_mode1      
          ; Switch to the mode1 machine
            lda     #state.kbd1
            sta     self.state,b,y

          ; Forward the last keypress to the machine.
            lda     self.rx2,b,y
            jsr     state_kbd1
            lda     self.rx3,b,y
            jsr     state_kbd1

            rts
_mode2
          ; Switch to the mode2 machine.
            lda     #state.kbd2
            sta     self.state,b,y

          ; Forward the last keypress to the mode2 machine.
            lda     self.rx1,b,y
            jsr     state_kbd2
            lda     self.rx2,b,y
            jsr     state_kbd2
            lda     self.rx3,b,y
            jsr     state_kbd2

            rts
            
_mouse      
          ; Discard the detected movement;
          ; switch to standard 3-byte mouse machine.
            lda     #state.mouse0
            sta     self.state,b,y
            rts

state_kbd1
        ; Replace with a local state machine.
            jsr     hardware.kbd1.accept
            rts

state_kbd2     
        ; Replace with a local state machine.
            jsr     hardware.kbd2.accept
            rts

state_mouse0
        ; Just drop the byte for now
            rts


            .send
            .endn
            .endn
