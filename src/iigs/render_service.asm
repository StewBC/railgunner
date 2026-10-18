; One bounded-work foreground service hook. All renderer callers are M=X16.
; Preserves A/X/Y/P/D/DBR. Parent supplies renderer_platform_service (RTL), which
; samples/maps input, runs due50Hz gameplay, and may update live producer state.
; It MUST NOT mutate pending snapshot, background, candidate, bitmap or spans.
; Standalone diagnostic supplies only an empty-game clock service stub.
; Disabled until platform clock/input/game services have initialized.
render_service          php
                        pha
                        phx
                        phy
                        phd
                        phb
                        lda   render_service_enabled
                        beq   render_service_done
                        jsl   renderer_platform_service
render_service_done     plb
                        pld
                        ply
                        plx
                        pla
                        plp
                        rts
render_service_enabled  ds    2
