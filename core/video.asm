            .cpu    "65c02"

            .namespace  kernel
            .section    kernel


screen
        ldx     #platform.console.COLS
        ldy     #platform.console.ROWS
        rts

plot
        bcs     _fetch
        jsr     platform.console.gotoxy
_fetch  ldx     platform.console.cur_x
        ldx     platform.console.cur_y
        rts

            .send
            .endn
