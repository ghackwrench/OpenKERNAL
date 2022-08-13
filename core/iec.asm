; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "65c02"

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
            


            .send
            .endn
