            .cpu    "w65c02"
            .namespace  platform
            .section    kernel
i8042       .hardware.i8042 $D640
           .send
           .endn

            
