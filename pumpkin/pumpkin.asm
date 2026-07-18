    processor 6502

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Include required files with definitions and macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    include "vcs.h"
    include "macro.h"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; pumpkin.asm -- a jack-o'-lantern that cackles.
;;
;; SHAPE: the whole pumpkin is ONE reflected playfield (CTRLPF D0 = 1),
;; so the left 20 columns mirror to the right and the face is symmetric
;; for free.  Orange = playfield ON; the eyes, nose, and mouth are gaps
;; where the playfield is OFF and the background (COLUBK) shows through.
;; The body sits in from the screen edges with rounded caps and tapers.
;; The picture is drawn as a stack of "bands" -- each sets PF0/PF1/PF2 in
;; HBLANK then holds them for N scanlines.  Bands are generated from an
;; ASCII design (scratchpad/gen_pumpkin.py) -- edit the art, regenerate.
;;
;; SOUND: an "evil laugh" approximated on the TIA.  PCM playback would eat
;; 100% CPU (no video), so instead a frame-driven envelope player walks a
;; small (AUDF, AUDV, frames) table once per frame in VBLANK.  A laugh is
;; breathy RHYTHM, not melody -- so ch0 is NOISE (AUDC0 = 8) pulsed into
;; sharp "ha ha ha" bursts, with ch1 a fixed-pitch voice drone underneath
;; for throat.  Volume falls and the bursts slow across the ~1.5 s laugh.
;; It fires once at power-on, and again on RESET or the joystick button.
;;
;; STROBE: while the laugh plays, the face flashes black <-> hot white
;; (~7.5 Hz) like a strobe light inside the pumpkin.  Since a scanline has
;; only one background color, a cycle-counted per-line kernel (see the face
;; band below) switches COLUBK to white ONLY across the interior and back to
;; black at the screen edges, so the glow stays inside the outline -- the
;; sky beside the pumpkin never flashes.  Idle, COLUBK stays black.
;;
;; Column -> register-bit map for the left half (col 0 = screen-left edge,
;; col 19 = center):  PF0 = cols 0..3 (bits 4-7); PF1 = cols 4..11
;; (bits 7..0, MSB first); PF2 = cols 12..19 (bits 0..7, LSB first).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PUMPKIN_COLOR = $38            ; bright pumpkin orange (COLUPF)
STEM_COLOR    = $D4            ; green stem (COLUPF, stem band only)
BG_COLOR      = $00            ; black night sky (COLUBK)
LAUGH_NOISE   = $08            ; AUDC0: breathy noise -- the "h" of each "ha"
VOICE_TIMBRE  = $06            ; AUDC1: deep tone under the noise (throat)
VOICE_PITCH   = $0A            ; AUDF1: constant low voice pitch (no melody)
STROBE_ON     = $0E            ; hot-white face flash while laughing
FACELINES     = 86             ; scanlines in the face band (shoulders..chin-b)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uninitialized RAM (zeroed at boot by CLEAN_START)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg.u Variables
    org $80
LaughActive .byte      ; 0 = idle (face normal), nonzero = a laugh is playing
LaughPtr    .byte      ; byte offset into LaughData of the current row
RowTimer    .byte      ; frames remaining on the current data row
FrameCtr    .byte      ; free-running frame counter -> strobe parity
StrobeColor .byte      ; COLUBK for the face band this frame ($00 or STROBE_ON)
TrigPrev    .byte      ; last frame's FIRE|RESET state (for edge detection)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start our ROM code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg
    org $f800

Reset:
    CLEAN_START

    lda #BG_COLOR
    sta COLUBK             ; black background

    lda #%00000001         ; CTRLPF: reflect playfield (D0) -> symmetry
    sta CTRLPF

    lda #LAUGH_NOISE
    sta AUDC0              ; ch0 = breathy noise (rumble shade set per frame)
    lda #VOICE_TIMBRE
    sta AUDC1             ; ch1 = a low voice drone under the noise...
    lda #VOICE_PITCH
    sta AUDF1             ; ...at a fixed pitch, so it never forms a melody

    lda #1
    sta LaughActive        ; laugh once at power-on (Ptr/RowTimer already 0)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start a new frame: VSYNC + VBLANK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
StartFrame:
    lda #2
    sta VBLANK             ; turn VBLANK on
    sta VSYNC              ; turn VSYNC on
    REPEAT 3
        sta WSYNC          ; three lines of VSYNC
    REPEND
    lda #0
    sta VSYNC              ; turn VSYNC off

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; VBLANK (37 lines).  Line 1 is blank (aligns the audio tick to the
;; start of line 2, so its worst-case path comfortably fits in one
;; scanline); line 2 runs the laugh tick + strobe pick; lines 3-37 idle.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    sta WSYNC              ; [line 1] blank, aligns the tick below

    ; --- laugh tick: advance one envelope row per frame ---
    lda LaughActive
    beq .laughIdle
    lda RowTimer
    beq .nextRow           ; current row finished -> fetch the next
    dec RowTimer
    jmp .laughIdle
.nextRow:
    ldx LaughPtr
    lda LaughData,x        ; AUDF value (or $FF = end of laugh)
    cmp #$FF
    bne .playRow
    lda #0
    sta AUDV0              ; end: silence both voices...
    sta AUDV1
    sta LaughActive        ; ...and stop (face returns to normal below)
    jmp .laughIdle
.playRow:
    sta AUDF0              ; noise "rumble shade" for this row
    inx
    lda LaughData,x
    sta AUDV0              ; envelope volume -> the noise...
    sta AUDV1              ; ...and the voice drone pulse together
    inx
    lda LaughData,x
    sta RowTimer           ; hold this row for N frames
    inx
    stx LaughPtr
.laughIdle:
    sta WSYNC              ; [line 2] closes the tick line

    ; --- strobe: pick this frame's face-glow color (its own line, so the
    ; audio tick above always fits comfortably in one scanline) ---
    inc FrameCtr           ; free-running -> drives the strobe cadence
    ldy #$00               ; idle, or the "dark" half of the strobe
    lda LaughActive
    beq .setStrobe
    lda FrameCtr
    and #%00000100         ; flip every 4 frames (~7.5 Hz) -> a calmer strobe
    beq .setStrobe
    ldy #STROBE_ON
.setStrobe:
    sty StrobeColor

    sta WSYNC              ; [line 3] closes the strobe line
    REPEAT 34
        sta WSYNC          ; [lines 4-37] idle out the rest of VBLANK
    REPEND
    lda #0
    sta VBLANK             ; turn VBLANK off -> visible region begins

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Draw the 192 visible scanlines: the pumpkin band table.
;; Each band sets PF0/PF1/PF2 in HBLANK, then holds for N lines.
;; The |...| art shows the full (mirrored) 40-px row for that band.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #PUMPKIN_COLOR
    sta COLUPF

    ; --- top black margin ---
    lda #0
    sta PF0
    sta PF1
    sta PF2
    REPEAT 22
        sta WSYNC
    REPEND

    ; stem                   |                 ██████                 |
    lda #STEM_COLOR
    sta COLUPF             ; green for the stem lines...
    lda #$00
    sta PF0
    lda #$00
    sta PF1
    lda #$E0
    sta PF2
    REPEAT 14
        sta WSYNC
    REPEND
    lda #PUMPKIN_COLOR
    sta COLUPF             ; ...orange for the rest of the pumpkin

    ; cap-a                  |          ████████████████████          |
    lda #$00
    sta PF0
    lda #$03
    sta PF1
    lda #$FF
    sta PF2
    REPEAT 5
        sta WSYNC
    REPEND
    ; cap-b                  |       ██████████████████████████       |
    lda #$00
    sta PF0
    lda #$1F
    sta PF1
    lda #$FF
    sta PF2
    REPEAT 5
        sta WSYNC
    REPEND
    ; cap-c                  |     ██████████████████████████████     |
    lda #$00
    sta PF0
    lda #$7F
    sta PF1
    lda #$FF
    sta PF2
    REPEAT 5
        sta WSYNC
    REPEND
    ; cap-d                  |    ████████████████████████████████    |
    lda #$00
    sta PF0
    lda #$FF
    sta PF1
    lda #$FF
    sta PF2
    REPEAT 4                ; 4 here; the face kernel's first WSYNC (below)
        sta WSYNC          ;   supplies cap-d's 5th line
    REPEND

    ; === face band (shoulders..chin-b): a per-scanline kernel ===
    ; COLUBK is pulsed white only across the interior (cols ~4..33) and left
    ; black at the screen edges, so the strobe glows through the eyes/nose/
    ; mouth cutouts while the sky beside the pumpkin never flashes.  Timing is
    ; cycle-counted so PF and COLUBK land at fixed beam positions every line;
    ; the body's edges are a constant col 3 / col 36, which makes that work.
    ; PF comes from the FacePF0/1/2 tables.  X counts DOWN 85..0 (dex/bpl is
    ; 2 cycles cheaper than inx/cpx/bne) so the loop's WSYNC write lands
    ; within the scanline -- one WSYNC start cycle too late and each line
    ; would eat TWO scanlines.  Tables are stored top-last to match X 85..0.
    ldx #FACELINES-1
.faceLine:
    sta WSYNC              ; [cyc 0] new line (iter 1 also finishes cap-d)
    lda FacePF0,x
    sta PF0
    lda FacePF1,x
    sta PF1
    lda FacePF2,x
    sta PF2                ; [~cyc 21] playfield for this scanline
    lda StrobeColor        ; white on a flash frame, else black
    nop
    sta COLUBK             ; [~col 4]  glow ON, just inside the body edge
    REPEAT 15
        nop                ; coast across the lit interior
    REPEND
    bit StrobeColor        ; (timing pad)
    lda #0
    sta COLUBK             ; [~col 33] glow OFF, before the right-side sky
    dex
    bpl .faceLine          ; WSYNC write now lands by cyc 74 -> 1 line/iter
    sta WSYNC              ; close the final face line


    ; taper-a                |    ████████████████████████████████    |
    lda #$00
    sta PF0
    lda #$FF
    sta PF1
    lda #$FF
    sta PF2
    REPEAT 6
        sta WSYNC
    REPEND
    ; taper-b                |     ██████████████████████████████     |
    lda #$00
    sta PF0
    lda #$7F
    sta PF1
    lda #$FF
    sta PF2
    REPEAT 6
        sta WSYNC
    REPEND
    ; taper-c                |       ██████████████████████████       |
    lda #$00
    sta PF0
    lda #$1F
    sta PF1
    lda #$FF
    sta PF2
    REPEAT 6
        sta WSYNC
    REPEND
    ; taper-d                |          ████████████████████          |
    lda #$00
    sta PF0
    lda #$03
    sta PF1
    lda #$FF
    sta PF2
    REPEAT 5
        sta WSYNC
    REPEND
    ; taper-e                |             ██████████████             |
    lda #$00
    sta PF0
    lda #$00
    sta PF1
    lda #$FE
    sta PF2
    REPEAT 5
        sta WSYNC
    REPEND

    ; --- bottom black margin ---
    lda #0
    sta PF0
    sta PF1
    sta PF2
    REPEAT 22
        sta WSYNC
    REPEND

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Overscan (30 lines).  Poll the two laugh triggers here (edge-
;; detected, so one press = one laugh) then idle out the frame.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2
    sta VBLANK             ; VBLANK back on

    ; Y = 1 if FIRE or RESET is pressed this frame, else 0
    ldy #0
    bit INPT4              ; FIRE: bit 7, 0 = pressed -> N clear
    bmi .fireUp
    ldy #1
.fireUp:
    lda #%00000001
    bit SWCHB              ; RESET: bit 0, 0 = pressed -> Z set
    bne .resetUp
    ldy #1
.resetUp:
    lda TrigPrev           ; A = last frame's state (sets Z)
    sty TrigPrev           ; remember this frame's state
    bne .noTrig            ; was pressed last frame -> not a fresh press
    cpy #1
    bne .noTrig            ; not pressed this frame -> nothing to do
    lda #1                 ; rising edge -> (re)start the laugh
    sta LaughActive
    lda #0
    sta LaughPtr
    sta RowTimer
.noTrig:

    REPEAT 30
        sta WSYNC
    REPEND

    jmp StartFrame

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Evil-laugh envelope.  Rows are (AUDF, AUDV, frames); AUDF $FF ends the
;; laugh (mute + stop).  Each syllable is 3 rows -- a sharp attack, a quick
;; decay, then a silent (AUDV=0) gap -- which chops the noise into a punchy
;; "ha".  AUDF here shades the NOISE (ch0) rather than picking a pitch, so
;; nothing forms a melody; it rises across the laugh so the rumble darkens.
;; Volume falls and the gaps widen so the cackle slows as it dies off.
;; (Generated by scratchpad/gen_laugh.py -- edit the syllable list there.)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LaughData:
    .byte   5,15,1, 5, 6,2, 0, 0,2   ; HA  (loud, bright, fast)
    .byte   5,15,1, 5, 6,2, 0, 0,2   ; HA
    .byte   6,14,1, 6, 6,2, 0, 0,2   ; HA
    .byte   7,13,1, 7, 5,2, 0, 0,2   ; ha  (run begins, darkening)
    .byte   8,12,1, 8, 5,2, 0, 0,3   ; ha
    .byte   9,12,1, 9, 5,2, 0, 0,2   ; ha
    .byte   8,11,1, 8, 4,2, 0, 0,3   ; ha
    .byte  10,11,1,10, 4,2, 0, 0,2   ; ha
    .byte  11,10,1,11, 4,2, 0, 0,3   ; ha
    .byte  12, 9,1,12, 4,2, 0, 0,3   ; ha
    .byte  14, 7,1,14, 3,2, 0, 0,4   ; huh (chuckles: slower, quieter)
    .byte  16, 6,1,16, 2,2, 0, 0,4   ; huh
    .byte  18, 5,1,18, 2,2, 0, 0,4   ; huh
    .byte  20, 4,1,20, 2,2, 0, 0,5   ; huh
    .byte  22, 3,1,22, 1,2, 0, 0,5   ; huh (final, lowest, sparsest)
    .byte  $FF                        ; end -> mute both voices, stop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Per-scanline playfield for the face band, one byte per line.  The kernel
;; counts X DOWN (ldx #FACELINES; dex/bne) reading FacePFn-1,X, so it visits
;; the last entry first -- the tables are stored REVERSED (last entry = the
;; top scanline).  Page-aligned so the indexed reads stay cheap/consistent.
;; Generated by scratchpad/gen_face.py -- edit the band art there.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    align 256
FacePF0:
    .byte $80,$80,$80,$80,$80,$80,$80,$80
    .byte $80,$80,$80,$80,$80,$80,$80,$80
    .byte $80,$80,$80,$80,$80,$80,$80,$80
    .byte $80,$80,$80,$80,$80,$80,$80,$80
    .byte $80,$80,$80,$80,$80,$80,$80,$80
    .byte $80,$80,$80,$80,$80,$80,$80,$80
    .byte $80,$80,$80,$80,$80,$80,$80,$80
    .byte $80,$80,$80,$80,$80,$80,$80,$80
    .byte $80,$80,$80,$80,$80,$80,$80,$80
    .byte $80,$80,$80,$80,$80,$80,$80,$80
    .byte $80,$80,$80,$80,$80,$80
FacePF1:
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$E0,$E0
    .byte $E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0
    .byte $E0,$E0,$E3,$E3,$E3,$E3,$E3,$E3
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $FF,$FF,$FF,$FF,$FF,$FD,$FD,$FD
    .byte $FD,$FD,$F8,$F8,$F8,$F8,$F8,$F8
    .byte $F0,$F0,$F0,$F0,$F0,$F0,$FF,$FF
    .byte $FF,$FF,$FF,$FF,$FF,$FF
FacePF2:
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$80,$80
    .byte $80,$80,$80,$80,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $1F,$1F,$1F,$1F,$1F,$3F,$3F,$3F
    .byte $3F,$7F,$7F,$7F,$7F,$FF,$FF,$FF
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $FE,$FE,$FE,$FE,$FE,$FE,$FF,$FF
    .byte $FF,$FF,$FF,$FF,$FF,$FF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reset vectors
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $fffc
    .word Reset
    .word Reset
    rorg $ffff
