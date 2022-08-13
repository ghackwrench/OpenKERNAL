; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

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
_fetch      ldx     platform.console.cur_x
            ldx     platform.console.cur_y
            rts

            .send
            .endn
