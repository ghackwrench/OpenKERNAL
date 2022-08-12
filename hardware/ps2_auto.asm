            .cpu        "m65c02"

            .namespace  hardware

            .namespace  ps2

            .namespace  dev
            .virtual    State
ext         .byte   ?   ; External driver
port        .byte   ?   ; external port
state       .byte   ?   ; Current receive state
chain       .byte   ?   ; State to enter after an ack.
rx1         .byte   ?   ; first received byte after ack
rx2         .byte   ?   ; second received byte after ack
rx3         .byte   ?   ; second received byte after ack
last        .byte   ?   ; last received byte
touched     .byte   ?   ; Time of last received character
wake        .byte   ?   ; Wake the auto-detect thread.

mouse       .byte   ?
mouse_1     .byte   ?
mouse_2     .byte   ?
mouse_3     .byte   ?
mouse_4     .byte   ?
            .endv
            .endn

init
            jsr     dev_alloc
            bcs     _out            

        ; Initialize the interface
            phx
            ldy     #0
_loop       lda     _iface,y
            sta     Drivers,x
            inx
            iny
            cpy     #device.size
            bne     _loop            
            plx

            clc
_out        rts


auto_init:  ; Should just go to idle
    ; X->this
    ; A->ext driver
    ; Y->port

            sta     dev.ext,x
            tya
            sta     dev.port,x
            
            lda     #state.debug
            sta     dev.state,x
            stz     dev.mouse,x
            rts

auto_open:
    ; X->this
    ; A = i8042 device
    ; Y->port

            sta     ext,x
            tya
            sta     port,x

            txa
            tay
            
            ldx     ext,y
            jsr    device_open
            bcs    _out


          ; Initialize the state
            lda     #state.test
            sta     dev.state,x

          ; Initialize the idle timer
          ; Not yet used; was for reducing
          ; the chance of mis-identifying
          ; a hot-plug self-test $aa.
            lda     kernel.ticks
            sta     dev.touched,x
            

          ; Enable events from the device
            phy
            lda     #set_enable
            ldy     dev.port,x
            lda     dev.ext,x
            tax
            jsr     device_set
            ply
            bcs     _out
            

          ; TODO: register the device with the kernel

          ; Manage the device
            jsr     kernel.thread.fork
            bcs     manage

_out        rts

auto_close
     ; TODO: stop device, turn off interrupts
            clc
            rts


manage      
          ; Start with a reset to clear any previous configuration.
            jsr     reset
            bcs     _infer  ; Device didn't reset ... try a heuristic approach.

          ; Ask the device for its type
_ident      jsr     ident
            bcs     _infer  ; Device type not recongnised; try heuristics.
            
          ; Process events from the device until a hot-swap is detected.
_wait       jsr     wait    ; Device is running
            bra     _ident  ; hot-swap reset detected, try to identify.

          ; Try to infer the type from any data the device sends.
_infer      jsr     infer
            bra     _wait


wait
    ; Ideally, we would wait for a real-time signal.
    ; For now, periodically check a flag.
            stz     dev.wake,b,x
_loop       lda     #60
            jsr     kernel.thread.sleep
            lda     dev.wake,b,x
            beq     _loop
            rts
          
wake
    ; Wake the hot-plug thread.
    ; Eventually, we'll have a real kernel call.
            inc     dev.wake,b,x
            rts

infer
        ; Try to identify by content; most checks are for
        ; three byte packets: simple mouse, or a mode-2
        ; press/release cycle.  Also detects hot-plug
        ; $aa events.

            ldy     #_message
            jsr     kernel.log.log_string

          ; Clear any previous history
            stz     dev.rx1,b,x
            stz     dev.rx2,b,x
            stz     dev.rx3,b,x
            
          ; Pass further bytes through the detector
            lda     #state.auto
            sta     dev.state,b,x

          ; Send a scan-enable just in case.
            lda     #$f4
            jsr     (dev.send,x)
            rts

_message    .null   "Unidentified device: waiting for activity."
            
ident
    ; Set up the device and chain to the appropriate 
    ; state machine based on the result of a basic
    ; device identity request.
    
            jsr     identify
            bcc     _found
            rts

_found      
            cmp     #$ab
            beq     _ab
            cmp     #0
            beq     _0
            cmp     #3
            beq     _3
            cmp     #4
            beq     _4

            sec
            rts

_0          jmp     mouse
_3          jmp     scroll_mouse
_4          jmp     five_button_mouse
_ab         jmp     keyboard
            
mouse
    ; Should try to upgrade to a scroll mouse.
    ; Just stay at mouse3 for now.

            ldy     #_ident
            jsr     kernel.log.log_string
    
            lda     #200
            jsr     _touch
            
            lda     #100
            jsr     _touch
            
            lda     #80
            jsr     _touch
            
            ldy     #_upgrade
            jsr     kernel.log.log_string

            jsr     identify
            bcs     _out
            cmp     #3
            beq     scroll_mouse

            jsr     configure_mouse
            lda     #state.mouse0
            jmp     scan

_ident      .null   "Two-Button Mouse detected."            
_upgrade    .null   "Mouse upgrade requested."

_touch      ora     #$f300  ; Set Rate
            jsr     cmd
            bcc     _out
            pla     ; Return to parent
_out        rts            

scroll_mouse
            ldy     #_ident
            jsr     kernel.log.log_string
            jsr     configure_mouse
            lda     #state.mouse3
            jmp     scan
_ident      .null   "Scroll-Button Mouse detected."
            
five_button_mouse
            ldy     #_ident
            jsr     kernel.log.log_string
            jsr     configure_mouse
            lda     #state.mouse4
            jmp     scan
_ident      .null   "Five-Button Mouse detected."

configure_mouse
            ldy     #_configure
            jsr     kernel.log.log_string
            lda     #$e803  ; Set resolution to 8 counts/mm
            jsr     cmd
            lda     #$f364  ; 100 samples/sec
            jsr     cmd
            lda     #$e602  ; Double reported values
            jsr     cmd
            rts

_configure  .null   "Configuring mouse: 8 counts/mm, 100 samples/s, dynamic accel."

keyboard
            ldy     #_message
            jsr     kernel.log.log_string
            
            lda     #$ed01  ; set the scroll-lock LED
            jsr     cmd
            lda     #state.kbd2
            jmp     scan

_message    .null   "Mode-2 Keyboard detected."            

scan
            sta     dev.chain,b,x
            lda     #$f4
            ldy     #state.chain
            jmp     send_command

identify
            jsr     stop
            bcs     _out

          ; Request ident.
            lda     #$F2
            jsr     cmd
            bcs     _out

          ; Wait for a variable number of ID bytes to trickle in.
            lda     #8
            jsr     kernel.thread.sleep 

          ; No report; probably an XT keyboard; heuristics will match it.
            lda     dev.state,b,x
            cmp     #state.data1
            beq     _unknown

            cmp     #state.data2
            beq     _found              ; Somd kind of pointing device
            
            lda     dev.rx1,b,x
            cmp     #$ab
            bne     _unknown            ; Unknown keyboard type
            
            lda     dev.rx2,b,x
            cmp     #$83                ; Mode2 keyboard (expected)
            beq     _found

_unknown    sec
            bra     _out

_found      lda     dev.rx1,b,x         ; Mouse or mode-2 keyboard
            clc
_out        rts


stop
            jsr     _stop
            bcc     _done
            jsr     _stop
            bcc     _done
            jsr     _stop
_done       rts            
            
_stop

    ; Send a stop-scanning request, but don't change
    ; the state machine, as the device might be in
    ; the middle of making a report when the stop
    ; request is made.

            lda     #$F5
            jsr     (dev.send,x)
            bcs     _out
            lda     #2
            jsr     kernel.thread.sleep
            lda     dev.last,b,x
            cmp     #$fa        ; ack
            clc
            beq     _out
            sec
_out        rts

reset
            lda     #$ff
            ldy     #state.test
            jmp     send_command

cmd
    ; A = command
            ldy     #state.data
            jmp     send_command

            
send_command
    ; A = command or command:arg
    ; Y = initial state

          ; Try three times before giving up.
            jsr     _try
            bcc     _out
            jsr     _try
            bcc     _out
            jsr     _try
_out        rts            

_try        pha

          ; Set the vector
            tya
            sta     dev.state,b,x
            
          ; Send the command
            lda     1,s
            bit     #$ff00
            beq     _low     
_high       xba
            jsr     (dev.send,x)
            bcs     _wait   ; Ignore errors ... they'll show up as timeouts.
            xba
_low        jsr     (dev.send,x)
            bcs     _wait   ; Ignore errors ... they'll show up as timeouts.

          ; Start the timer
_wait       lda     kernel.ticks
            pha

_loop       jsr     kernel.thread.yield

            tya
            clc
            eor     dev.state,b,x
            bne     _done

            lda     kernel.ticks
            sec
            sbc     1,s
            cmp     #60     ; 1s
            bcc     _loop

_done       pla
            pla
            rts
            

state       .struct
debug       .word   state_debug     ; debug
test        .word   wait_self_test  ; Wait for a "self-test successful" response.
chain       .word   wait_ack_chain  ; Wait for ack then switch to this.chain.
data        .word   wait_ack_data   ; Wait for ack then collect the next two bytes
data1       .word   state_data1     ; Wait for the next byte after the ack
data2       .word   state_data2     ; Wait for the next byte after wait_1
idle        .word   state_idle      ; Drop additional bytes
auto        .word   state_auto      ; Identify device from data
kbd1        .word   state_kbd1      ; Mode-2 keyboard state machine
kbd2        .word   state_kbd2      ; Mode-2 keyboard state machine
mouse0      .word   state_mouse0    ; Original 3-byte state machine
mouse3      .word   state_mouse3    ; Scroll Mouse 4-byte state machine
mouse4      .word   state_mouse4    ; 5-button 4-byte state machine
            .ends

rx
    ; Process an incoming byte from the device
    
 pha
 jsr (dev.increment,x)
 pla
            sta     dev.last,b,x    ; Always save the last byte received
            cmp     #$aa
            beq     _hotswap
            txy                     ; Y->this
            ldx     dev.state,b,y
            jmp     (_table,x)

_hotswap    lda     #state.idle
            sta     dev.state,b,x
            jmp     wake

_table      .state

state_idle  rts
            
state_mouse4
state_debug
            tyx
            jmp     (dev.increment,x)            

wait_self_test
            cmp     #$aa    ; Passed
            bne     _out
            lda     #state.idle
            sta     dev.state,b,y
_out        rts

wait_ack_chain
            cmp     #$fa
            bne     _out
            lda     dev.chain,b,y
            sta     dev.state,b,y
_out        rts            

wait_ack_data
            cmp     #$fa
            bne     _out
            lda     #state.data1
            sta     dev.state,b,y
_out        rts            

state_data1
            sta     dev.rx1,b,y
            lda     #state.data2
            sta     dev.state,b,y
            rts
            
state_data2
            sta     dev.rx2,b,y
            lda     #state.idle
            sta     dev.state,b,y
            rts

state_kbd1
        ; Replace with a local state machine.
            sep     #$30
            jsr     kernel.kbd1.accept
            rep     #$30
            rts

state_kbd2     
        ; Replace with a local state machine.
            sep     #$30
            jsr     kernel.kbd2.accept
            rep     #$30
            rts

state_mouse0
        ; Replace with a local state machine.
            jmp     ps2_1

state_mouse3
        ; Replace with a local state machine.
            jmp     scroller

state_auto
            pha
            lda     dev.rx2,b,y
            sta     dev.rx1,b,y
            lda     dev.rx3,b,y
            sta     dev.rx2,b,y
            pla
            sta     dev.rx3,b,y

          ; Mode1 keyboard?
_check1     lda     dev.rx3,b,x
            bpl     _not1
            and     #$7f
            cmp     dev.rx2,b,x
            beq     _mode1
_not1       nop
            
          ; Mode2 keyboard?  
_check2     lda     dev.rx2,b,y
            cmp     #$f0    ; release
            bne     _not2
            lda     dev.rx1,b,y
            cmp     dev.rx3,b,y
            beq     _mode2
_not2       nop  
            
          ; Mouse?
            lda     dev.rx1,b,y
            and     #$cf
            eor     #$08
            beq     _mouse

_out        rts

_mode1      
          ; Switch to the mode1 machine
            lda     #state.kbd1
            sta     dev.state,b,y

          ; Forward the last keypress to the machine.
            lda     dev.rx2,b,y
            jsr     state_kbd1
            lda     dev.rx3,b,y
            jsr     state_kbd1

            rts
_mode2
          ; Switch to the mode2 machine.
            lda     #state.kbd2
            sta     dev.state,b,y

          ; Forward the last keypress to the mode2 machine.
            lda     dev.rx1,b,y
            jsr     state_kbd2
            lda     dev.rx2,b,y
            jsr     state_kbd2
            lda     dev.rx3,b,y
            jsr     state_kbd2

            rts
            
_mouse      
          ; Discard the detected movement;
          ; switch to standard 3-byte mouse machine.
            lda     #state.mouse0
            sta     dev.state,b,y
            rts

ps2_1:
        php
        sep     #$30
        jsr     _mouse
        plp
        rts
        .asxs
_mouse
        ldx     dev.mouse,b,y
        jmp     (_table,x)
_table  .word   _0, _1, _2

_0      bit     #8
        beq     _out
        bit     #192
        bne     _out
        sta     dev.mouse_1,b,y
        bra     _next

_1      sta     dev.mouse_2,b,y
        bra     _next

_2      sta     dev.mouse_3,b,y

        lda     dev.mouse_1,b,y
        sta     $AF0706
        lda     dev.mouse_2,b,y
        sta     $AF0707
        lda     dev.mouse_3,b,y
        sta     $AF0708

_retry  lda     #0
        sta     dev.mouse,b,y
_out    rts
        
_next   inx
        inx
        txa
        sta     dev.mouse,b,y
        rts
        .alxl


scroller
        ldx     dev.mouse,b,y
        jmp     (_table,x)

_table  .word   _1
        .word   _2
        .word   _3
        .word   _4

_1      bit     #8
        beq     _out
        bit     #192
        bne     _out
        sta     dev.mouse_1,b,y
        bra     _next
_2      sta     dev.mouse_2,b,y
        bra     _next
_3      sta     dev.mouse_3,b,y
        bra     _next
_4      sta     dev.mouse_4,b,y

        sep     #$20
        lda     dev.mouse_1,b,y
        sta     $AF0706
        lda     dev.mouse_2,b,y
        sta     $AF0707
        lda     dev.mouse_3,b,y
        sta     $AF0708
        rep     #$20

.if true
        tya
        clc
        adc     #dev.mouse_1
        jsr     kernel.mouse_event
.endif

        lda     #0
        sta     dev.mouse,b,y
        rts
        
_next   inx
        inx
        txa
        sta     dev.mouse,b,y
_out    rts
        
        .alxl


print_hex_word:
            pha
            xba
            jsr     print_hex_byte
            lda     1,s
            jsr     print_hex_byte
            pla
            rts
            
print_hex_byte
            pha
            php
            lsr     a
            lsr     a
            lsr     a
            lsr     a
            plp
            jsr     print_hex_nibble
            lda     1,s
            jsr     print_hex_nibble
            pla
            rts
            
print_hex_nibble
            and     #$0f
            phx
            tax
            lda     _tab,x
            tyx
            sep     #$20
            sta     $afa000,x
            rep     #$20
            iny
            plx
            rts
_tab        .null   "0123456789ABCDEF"            


            .send
            .endn
            .endn
            .endn
 
