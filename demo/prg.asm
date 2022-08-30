                .cpu    "6502"

boot            .namespace

* = $7ff
        .text   $01,$08
        .text   $0c,$08,$00,$00,$9e,"2064",$00  ; Next, line #, SYS 2064, EOL
        .text   $00,$00                         ; End of Basic
        
* = $810
        jmp    start

        .dsection   code

                .endn        
        
