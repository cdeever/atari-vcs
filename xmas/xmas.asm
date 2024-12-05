    processor 6502

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Include required files with definitions and macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    include "vcs.h"
    include "macro.h"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start our ROM code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg
    org $f000

Reset:
    CLEAN_START

    ldx #$42       ; red background color
    stx COLUBK

    lda #$C3       ; green playfield color
    sta COLUPF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start a new frame by configuring VBLANK and VSYNC
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
StartFrame:
    lda #02
    sta VBLANK     ; turn VBLANK on
    sta VSYNC      ; turn VSYNC on

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Generate the three lines of VSYNC
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    REPEAT 3
        sta WSYNC  ; three VSYNC scanlines
    REPEND

    lda #0
    sta VSYNC      ; turn VSYNC off

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Let the TIA output the 37 recommended lines of VBLANK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    REPEAT 37
        sta WSYNC
    REPEND

    lda #0
    sta VBLANK     ; turn VBLANK off

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set the CTRLPF register to allow playfield reflect
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ldx #%00000001 ; CTRLPF register (D0 is the reflect flag)
    stx CTRLPF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Draw the 192 visible scanlines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; Skip 7 scanlines with no PF set
    ldx #0
    stx PF0
    stx PF1
    stx PF2
    REPEAT 44
        sta WSYNC
    REPEND

    ldx #%10000000
    stx PF2
    REPEAT 10
        sta WSYNC
    REPEND

    ldx #%11000000
    stx PF2
    REPEAT 10
        sta WSYNC
    REPEND

    ldx #%11100000
    stx PF2
    REPEAT 10
        sta WSYNC
    REPEND

    ldx #%11110000
    stx PF2
    REPEAT 10
        sta WSYNC
    REPEND

    ldx #%11111000
    stx PF2
    REPEAT 10
        sta WSYNC
    REPEND

    ldx #%11111100
    stx PF2
    REPEAT 10
        sta WSYNC
    REPEND
    ldx #%11111110
    stx PF2
    REPEAT 10
        sta WSYNC
    REPEND

    ldx #%11111111
    stx PF2
    REPEAT 10
        sta WSYNC
    REPEND

    ldx #%00000001
    stx PF1
    REPEAT 10
        sta WSYNC
    REPEND

    ldx #%00000011
    stx PF1
    REPEAT 10
        sta WSYNC
    REPEND

    ldx #%00000111
    stx PF1
    REPEAT 10
        sta WSYNC
    REPEND

    ldx #%00001111
    stx PF1
    REPEAT 10
        sta WSYNC
    REPEND

    ; Start trunk
    ldx #%10000000
    stx PF2
    ldx #0
    stx PF1
    REPEAT 14
        sta WSYNC
    REPEND

    ; Set the next 164 lines only with PF0 third bit enabled
;    ldx #%00000000
;   stx PF0
;    stx PF1 
;   stx PF2
;    REPEAT 53
;       sta WSYNC
;    REPEND

    ; Set the PF0 to 1110 (LSB first) and PF1-PF2 as 1111 1111
    ldx #%11101111
    stx PF0
    ldx #%11111111
    stx PF1
    stx PF2
    REPEAT 7
       sta WSYNC   ; repeat PF config for 7 scanlines
    REPEND

    ; Skip 7 vertical lines with no PF set
    ldx #0
    stx PF0
    stx PF1
    stx PF2
    REPEAT 7
        sta WSYNC
    REPEND

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Output 30 more VBLANK overscan lines to complete our frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2
    sta VBLANK     ; enable VBLANK back again
    REPEAT 30
       sta WSYNC   ; output the 30 recommended overscan lines
    REPEND

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Loop to next frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    jmp StartFrame


Song:
    .byte $02, $10 ; Note: C6 (1046.5 Hz), Duration: 16 frames (1 beat)
    .byte $05, $08 ; Note: F4 (349.2 Hz), Duration: 8 frames (1/2 beat)
    .byte $07, $08 ; Note: C4 (261.6 Hz), Duration: 8 frames (1/2 beat)
    .byte $05, $08 ; Note: F4 (349.2 Hz), Duration: 8 frames (1/2 beat)
    .byte $07, $10 ; Note: C4 (261.6 Hz), Duration: 16 frames (1 beat)
    .byte $08, $10 ; Note: A#3 (233.1 Hz), Duration: 16 frames (1 beat)
    .byte $05, $10 ; Note: F4 (349.2 Hz), Duration: 16 frames (1 beat)
    .byte $09, $08 ; Note: G#3 (207.7 Hz), Duration: 8 frames (1/2 beat)
    .byte $05, $08 ; Note: F4 (349.2 Hz), Duration: 8 frames (1/2 beat)
    .byte $02, $10 ; Note: C6 (1046.5 Hz), Duration: 16 frames (1 beat)
    .byte $05, $08 ; Note: F4 (349.2 Hz), Duration: 8 frames (1/2 beat)
    .byte $07, $08 ; Note: C4 (261.6 Hz), Duration: 8 frames (1/2 beat)
    .byte $05, $08 ; Note: F4 (349.2 Hz), Duration: 8 frames (1/2 beat)
    .byte $07, $10 ; Note: C4 (261.6 Hz), Duration: 16 frames (1 beat)
    .byte $09, $10 ; Note: G#3 (207.7 Hz), Duration: 16 frames (1 beat)
    .byte $08, $10 ; Note: A#3 (233.1 Hz), Duration: 16 frames (1 beat)
    .byte $0D, $20 ; Note: D3 (146.8 Hz), Duration: 32 frames (2 beats)
    .byte $00       ; End of Data



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Complete ROM size
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $fffc
    .word Reset
    .word Reset
