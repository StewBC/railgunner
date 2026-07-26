; RailGunner — root assembly unit
; Only this file is passed to c64masm / the c64m Assembler tab.
; Layout: agents/repo-layout.md
; Syntax:  agents/assembler-syntax.md

; ---------------------------------------------------------------------------
; Segments (addresses may be adjusted in sys/memory once that module lands)
; ---------------------------------------------------------------------------
.segdef "ZEROPAGE", $02, noemit
.segdef "BASIC", $0801
.segdef "CODE", $080d
.segdef "DATA", $2000

; ---------------------------------------------------------------------------
; BASIC stub: 10 SYS 2061  ($080d)
; ---------------------------------------------------------------------------
.segment "BASIC"

    .word basic_next
    .word 10
    .byte $9e
    .byte "2061"
    .byte 0
basic_next:
    .word 0

; ---------------------------------------------------------------------------
; Code — include modules here as they are added (order matters for readability;
; the assembler is two-pass so forward refs to labels are fine).
; ---------------------------------------------------------------------------
.segment "CODE"

start:
    ; TODO: .include "boot/init.asm"
    ; TODO: .include "sys/irq.asm"
    ; TODO: .include "sys/input.asm"
    ; TODO: frontend, render, sprite, game modules
    jmp *

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
.segment "DATA"

    ; TODO: .include "data/..."
