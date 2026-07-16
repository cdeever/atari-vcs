    processor 6502

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Include required files with definitions and macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    include "vcs.h"
    include "macro.h"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Build-time options
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SOUND_ENABLED = 0      ; 1 = play the music (+ RESET replays it), 0 = silent

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MLIGHT {1}, {2}, {3}: draw one blinking tree light as missile 0.
;; Unlike the ball/playfield, the missile has its OWN colour
;; register (COLUP0), so a bulb is a clean ~4x3 px dot in any colour
;; drawn on top of the tree -- no mid-line COLUPF trickery.
;;   {1} = nop count = HORIZONTAL POSITION (~pixel 6*{1}-60; each
;;         +1 nudges the bulb ~6 px right).  This positions missile 0
;;         via a timed RESM0 strobe.
;;   {2} = bulb colour (written to COLUP0).
;;   {3} = zero-page blink flag ($02 = lit this frame, $00 = dark).
;; Occupies 4 scanlines (1 to reposition + 3 showing the bulb).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    MAC MLIGHT
    sta WSYNC            ; align to a fresh line FIRST, so the RESM0
    lda #0              ;   strobe timing is identical for every bulb
    sta ENAM0           ;   (missile off while it is repositioned)
    REPEAT {1}
        nop
    REPEND
    sta RESM0            ; park missile 0 at this bulb's column
    lda #{2}
    sta COLUP0           ; this bulb's colour
    lda {3}
    sta ENAM0            ; blink: lit ($02) or dark ($00) this frame
    sta WSYNC            ; bulb row 1
    sta WSYNC            ; bulb row 2
    sta WSYNC            ; bulb row 3
    ENDM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uninitialized RAM variables (zeroed at boot by CLEAN_START)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg.u Variables
    org $80
SongPtr   .byte      ; offset into Song of the current note
NoteTimer .byte      ; frames remaining on the current note
FrameCtr  .byte      ; free-running frame counter (drives animation)
StarCol   .byte      ; this frame's twinkling star color
Light0On  .byte      ; per-frame blink flags for the 10 bulbs
Light1On  .byte      ;   ($02 = lit this frame, $00 = dark)
Light2On  .byte
Light3On  .byte
Light4On  .byte
Light5On  .byte
Light6On  .byte
Light7On  .byte
Light8On  .byte
Light9On  .byte

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start our ROM code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg
    org $f800

Reset:
    CLEAN_START

    IF SOUND_ENABLED
    lda #%00001100 ; AUDC0 = 12: pure tone, f = 5233/(AUDF+1) Hz
    sta AUDC0      ; (volume AUDV0 is set per-note by the player)
    ENDIF

    ldx #$42       ; red background color
    stx COLUBK

    lda #$C3       ; green playfield color
    sta COLUPF

    lda #%00100000 ; NUSIZ0: missile 0 = 4 px wide (the light bulbs)
    sta NUSIZ0

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
;; Music tick: advance the song by one frame (fits within one
;; scanline, so the WSYNC block below still yields 37 VBLANK lines).
;; Song is (pitch, duration) byte pairs.  pitch $00 = end of song
;; (mute and hold; RESET replays it), pitch $01 = rest (silence),
;; else pitch is an AUDF0 value.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    IF SOUND_ENABLED
    lda NoteTimer
    bne .tickDown          ; note still sounding -> just count down
    ldx SongPtr
    lda Song,x             ; fetch pitch of next note
    bne .notEnd
    sta AUDV0              ; $00 -> end of song: mute (A=0) and hold
    jmp .tickDone          ;   here until RESET rewinds SongPtr
.notEnd:
    cmp #1                 ; $01 -> rest: mute for the duration
    bne .playNote
    lda #0
    sta AUDV0
    jmp .setDur
.playNote:
    sta AUDF0              ; set pitch
    lda #8                 ; and (re)enable volume  (0-15)
    sta AUDV0
.setDur:
    inx
    lda Song,x             ; fetch this note's duration (frames)
    sta NoteTimer
    inx
    stx SongPtr
    jmp .tickDone
.tickDown:
    dec NoteTimer
.tickDone:
    ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 37 lines of VBLANK.  We spend the first few doing per-frame
;; work (position the ball, pick this frame's animated colors),
;; one item per scanline so the line count stays exact.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    sta WSYNC              ; [line 1] ends the music-tick line

    ; [line 2] position the star sprite (player 0): the ldy loop +
    ; 3-cycle "bit" pad strobe RESP0 near cycle 46 (coarse, 3px steps);
    ; then HMP0 fine-nudges it by whole pixels on the HMOVE below.
    ldy #8
.posStar:
    dey
    bne .posStar
    bit FrameCtr           ; 3-cycle pad -> coarse strobe ~cycle 46
    sta RESP0
    lda #$20               ; HMP0 = +2 -> 2px LEFT (each $10 = 1px left;
    sta HMP0               ;   $F0/$E0 = 1/2px right; $00 = no nudge)
    sta WSYNC

    ; [line 3] apply the fine nudge (HMOVE must lead the line; its
    ; 8px left-comb lands on this blank VBLANK line), then twinkle
    sta HMOVE
    inc FrameCtr
    lda FrameCtr
    lsr
    lsr                    ; /4 -> color changes ~15x per second
    and #7
    tax
    lda TwinkleColors,x
    sta StarCol
    sta WSYNC

    ; [lines 4-8] blink each block's pair of bulbs (they share a flag).
    ; Bits 4-6 of FrameCtr give an 8-step, 128-frame cycle (16 frames
    ; each); a pair is LIT for 7 steps (~1.9 s on) and dark for just
    ; one (~0.27 s off), staggered so only a couple wink at once.
    ; (Widen the $70 mask toward $F0 for an even longer "on".)
    lda FrameCtr
    and #%01110000
    bne .l0lit             ; block 0 dark on step 0
    lda #0
    beq .l0set
.l0lit:
    lda #%00000010
.l0set:
    sta Light0On
    lda FrameCtr
    and #%01110000
    cmp #%00010000
    bne .l1lit             ; block 1 dark on step 1
    lda #0
    beq .l1set
.l1lit:
    lda #%00000010
.l1set:
    sta Light1On
    sta WSYNC

    lda FrameCtr
    and #%01110000
    cmp #%00100000
    bne .l2lit             ; block 2 dark on step 2
    lda #0
    beq .l2set
.l2lit:
    lda #%00000010
.l2set:
    sta Light2On
    lda FrameCtr
    and #%01110000
    cmp #%00110000
    bne .l3lit             ; block 3 dark on step 3
    lda #0
    beq .l3set
.l3lit:
    lda #%00000010
.l3set:
    sta Light3On
    sta WSYNC

    lda FrameCtr
    and #%01110000
    cmp #%01000000
    bne .l4lit             ; block 4 dark on step 4
    lda #0
    beq .l4set
.l4lit:
    lda #%00000010
.l4set:
    sta Light4On
    lda FrameCtr
    and #%01110000
    cmp #%01010000
    bne .l5lit             ; block 5 dark on step 5
    lda #0
    beq .l5set
.l5lit:
    lda #%00000010
.l5set:
    sta Light5On
    sta WSYNC

    lda FrameCtr
    and #%01110000
    cmp #%01100000
    bne .l6lit             ; block 6 dark on step 6
    lda #0
    beq .l6set
.l6lit:
    lda #%00000010
.l6set:
    sta Light6On
    lda FrameCtr
    and #%01110000
    cmp #%01110000
    bne .l7lit             ; block 7 dark on step 7
    lda #0
    beq .l7set
.l7lit:
    lda #%00000010
.l7set:
    sta Light7On
    sta WSYNC

    lda FrameCtr
    and #%01110000
    cmp #%00100000
    bne .l8lit             ; block 8 dark on step 2
    lda #0
    beq .l8set
.l8lit:
    lda #%00000010
.l8set:
    sta Light8On
    lda FrameCtr
    and #%01110000
    cmp #%01010000
    bne .l9lit             ; block 9 dark on step 5
    lda #0
    beq .l9set
.l9lit:
    lda #%00000010
.l9set:
    sta Light9On
    sta WSYNC

    ; [lines 9-37] idle out the rest of VBLANK
    REPEAT 29
        sta WSYNC
    REPEND

    lda #0
    sta VBLANK     ; turn VBLANK off

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set the CTRLPF register to allow playfield reflect
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ldx #%00000001 ; CTRLPF: playfield reflect (D0)
    stx CTRLPF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Draw the 192 visible scanlines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; --- Sky (44 lines) with a twinkling star sprite (player 0) ---
    ldx #0
    stx PF0
    stx PF1
    stx PF2
    stx GRP0               ; no star over the upper sky
    REPEAT 35
        sta WSYNC
    REPEND
    ; draw the 8-row starburst so its base meets the apex, coloured by
    ; the frame's twinkle (raise this REPEAT to lower the star further)
    lda StarCol
    sta COLUP0
    ldx #0
.starDraw:
    sta WSYNC
    lda StarBitmap,x
    sta GRP0               ; set this row in HBLANK -> shows this line
    inx
    cpx #8
    bne .starDraw          ; 8 rows -> 8 scanlines
    sta WSYNC              ; hold the last row for its full line...
    lda #0
    sta GRP0               ; ...then clear it as we roll into the tree

    ; --- Tree (green playfield; the bulbs are missile 0 on top) ---
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
    MLIGHT 19, $46, Light0On   ; red, center
    MLIGHT 20, $0E, Light0On   ; white, center
    lda #0
    sta ENAM0
    REPEAT 2
        sta WSYNC
    REPEND

    ldx #%11110000
    stx PF2
    MLIGHT 18, $2A, Light5On   ; orange, center
    MLIGHT 21, $B6, Light5On   ; cyan, right
    lda #0
    sta ENAM0
    REPEAT 2
        sta WSYNC
    REPEND

    ldx #%11111000
    stx PF2
    MLIGHT 20, $9A, Light1On   ; blue, center
    MLIGHT 17, $1C, Light1On   ; yellow, left
    lda #0
    sta ENAM0
    REPEAT 2
        sta WSYNC
    REPEND

    ldx #%11111100
    stx PF2
    MLIGHT 18, $0E, Light6On   ; white, center
    MLIGHT 22, $46, Light6On   ; red, right
    lda #0
    sta ENAM0
    REPEAT 2
        sta WSYNC
    REPEND
    ldx #%11111110
    stx PF2
    MLIGHT 20, $66, Light2On   ; magenta, center
    MLIGHT 16, $88, Light2On   ; azure, left
    lda #0
    sta ENAM0
    REPEAT 2
        sta WSYNC
    REPEND

    ldx #%11111111
    stx PF2
    MLIGHT 18, $56, Light7On   ; purple, center
    MLIGHT 23, $2A, Light7On   ; orange, right
    lda #0
    sta ENAM0
    REPEAT 2
        sta WSYNC
    REPEND

    ldx #%00000001
    stx PF1
    MLIGHT 20, $1A, Light8On   ; gold, center
    MLIGHT 15, $66, Light8On   ; magenta, left
    lda #0
    sta ENAM0
    REPEAT 2
        sta WSYNC
    REPEND

    ldx #%00000011
    stx PF1
    MLIGHT 18, $B6, Light3On   ; cyan, center
    MLIGHT 24, $1A, Light3On   ; gold, right
    lda #0
    sta ENAM0
    REPEAT 2
        sta WSYNC
    REPEND

    ldx #%00000111
    stx PF1
    MLIGHT 20, $88, Light9On   ; azure, center
    MLIGHT 14, $56, Light9On   ; purple, far left
    lda #0
    sta ENAM0
    REPEAT 2
        sta WSYNC
    REPEND

    ldx #%00001111
    stx PF1
    MLIGHT 18, $1C, Light4On   ; yellow, center
    MLIGHT 25, $9A, Light4On   ; blue, far right
    lda #0
    sta ENAM0
    REPEAT 2
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
    REPEAT 6
        sta WSYNC
    REPEND

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Output 30 more VBLANK overscan lines to complete our frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2
    sta VBLANK     ; enable VBLANK back again

    IF SOUND_ENABLED
    ; Restart the song when the player presses the RESET switch
    lda #%00000001
    bit SWCHB      ; SWCHB D0 = console RESET (0 = pressed)
    bne .noReset
    lda #0
    sta SongPtr    ; rewind to the first note...
    sta NoteTimer  ; ...so it retriggers on the next frame
.noReset:
    ENDIF

    REPEAT 30
       sta WSYNC   ; output the 30 recommended overscan lines
    REPEND

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Loop to next frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    jmp StartFrame


; "We Wish You a Merry Christmas" (key of G), then a happy new year.
; Format: (AUDF pitch, duration in frames).  ~60 fps, so beat = 24
; frames.  AUDF pitches (AUDC0 = 12):  D4=$11 E4=$0F F#4=$0D G4=$0C
; A4=$0B B4=$0A C5=$09.  pitch $01 = rest, pitch $00 = end.
; Star twinkle palette: gold / orange / white / silver, cycled by
; the frame counter for that Pitfall-treasure shimmer.
TwinkleColors:
    .byte $1E, $1C, $1A, $2E, $0E, $28, $0C, $1C

; 8-point starburst, one byte per scanline (top row first).  GRP0
; shows bit 7 on the left, so each byte reads left-to-right on screen:
;   $18 = ...##...   $99 = #..##..#   $7E = .######.   $FF = ########
StarBitmap:
    .byte $18, $99, $7E, $FF, $FF, $7E, $99, $18

Song:
    ; -- "We wish you a merry Christmas" --
    .byte $11, $18 ; D4  We
    .byte $0C, $18 ; G4  wish
    .byte $0C, $18 ; G4  you
    .byte $0B, $18 ; A4  a
    .byte $0C, $0C ; G4  mer-
    .byte $0D, $0C ; F#4 -ry
    .byte $0F, $18 ; E4  Christ-
    .byte $0F, $18 ; E4  -mas
    ; -- "We wish you a merry Christmas" (up a step) --
    .byte $0F, $18 ; E4  We
    .byte $0B, $18 ; A4  wish
    .byte $0B, $18 ; A4  you
    .byte $0A, $18 ; B4  a
    .byte $0B, $0C ; A4  mer-
    .byte $0C, $0C ; G4  -ry
    .byte $0D, $18 ; F#4 Christ-
    .byte $11, $18 ; D4  -mas
    ; -- "We wish you a merry Christmas" (up again) --
    .byte $11, $18 ; D4  We
    .byte $0A, $18 ; B4  wish
    .byte $0A, $18 ; B4  you
    .byte $09, $18 ; C5  a
    .byte $0A, $0C ; B4  mer-
    .byte $0B, $0C ; A4  -ry
    .byte $0C, $18 ; G4  Christ-
    .byte $0F, $18 ; E4  -mas
    ; -- "and a happy new year" --
    .byte $11, $0C ; D4  and
    .byte $11, $0C ; D4  a
    .byte $0F, $18 ; E4  hap-
    .byte $0B, $18 ; A4  -py
    .byte $0D, $18 ; F#4 new
    .byte $0C, $3C ; G4  year (held ~1 s)
    ; -- play once, then wait for a RESET press to replay --
    .byte $00      ; End of Data -> stop (press RESET to play again)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Complete ROM size
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $fffc
    .word Reset
    .word Reset
    rorg $ffff