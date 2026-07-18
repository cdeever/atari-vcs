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
;; small (voice-pitch, volume, frames) table once per frame in VBLANK.  A
;; laugh sits between song and drum: ch1 is a pitched voice (AUDC1 = 6) that
;; BENDS DOWN through each "ha" (the falling bark that reads as laughing),
;; and ch0 is breath noise at half volume for the "h".  Pitch and volume
;; descend across the ~1.5 s laugh for the classic "MWA-ha-ha-ha..." fade.
;; It fires once at power-on, and again on RESET or the joystick button.
;;
;; GLOW: the face cutouts are lit from within.  Idle, they flicker through
;; warm ambers (CandleColors) like a candle; while the laugh plays they
;; flash hard white like a strobe.  Since a scanline has only one background
;; color, a cycle-counted per-line kernel (see the face band below) switches
;; COLUBK to the glow color ONLY across the interior and back to black at the
;; screen edges, so the light stays inside the outline -- the sky beside the
;; pumpkin never lights up.
;;
;; Column -> register-bit map for the left half (col 0 = screen-left edge,
;; col 19 = center):  PF0 = cols 0..3 (bits 4-7); PF1 = cols 4..11
;; (bits 7..0, MSB first); PF2 = cols 12..19 (bits 0..7, LSB first).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PUMPKIN_COLOR = $38            ; bright pumpkin orange (COLUPF)
STEM_COLOR    = $D4            ; green stem (COLUPF, stem band only)
BG_COLOR      = $00            ; black night sky (COLUBK)
VOICE_TIMBRE  = $06            ; AUDC1: pitched tone -- the "vowel" of each "ha"
BREATH_NOISE  = $08            ; AUDC0: noise -- the breathy "h" (half volume)
BREATH_SHADE  = $06            ; AUDF0: fixed noise darkness for the breath
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
Rand        .byte      ; LFSR -> candle glow flicker + laugh voice warble
CandleCol   .byte      ; current idle candle shade, held between random picks
VoicePitch  .byte      ; current laugh row's base AUDF1 (before per-frame warble)

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

    lda #BREATH_NOISE
    sta AUDC0             ; ch0 = breath noise (fixed shade; volume pulses)
    lda #BREATH_SHADE
    sta AUDF0
    lda #VOICE_TIMBRE
    sta AUDC1             ; ch1 = the voice tone; its pitch AUDF1 bends per row

    lda #$C5
    sta Rand               ; seed the LFSR non-zero (0 would lock it up)

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
    jmp .laughIdle         ; hold this row (pitch is warbled on line 3)
.nextRow:
    ldx LaughPtr
    lda LaughData,x        ; voice pitch AUDF1 (or $FF = end of laugh)
    cmp #$FF
    bne .playRow
    lda #0
    sta AUDV0              ; end: silence both voices...
    sta AUDV1
    sta LaughActive        ; ...and stop (face returns to normal below)
    jmp .laughIdle
.playRow:
    sta VoicePitch         ; base pitch -- sweeps down across each syllable
    inx
    lda LaughData,x        ; packed volume: voice (high nybble) | breath (low)
    tay
    and #$0F
    sta AUDV0              ; breath noise = low nybble (can lead -> the "h")
    tya
    lsr
    lsr
    lsr
    lsr
    sta AUDV1              ; voice = high nybble
    inx
    lda LaughData,x
    sta RowTimer           ; hold this row for N frames
    inx
    stx LaughPtr
.laughIdle:
    sta WSYNC              ; [line 2] closes the tick line

    ; --- pick this frame's face-glow color (its own line, so the audio
    ; tick above always fits comfortably in one scanline).  While laughing:
    ; a hard white strobe.  Idle: a soft candle glow that wavers through
    ; warm ambers, so the face looks lit from within. ---
    inc FrameCtr           ; free-running -> drives both cadences

    lda Rand               ; advance the LFSR every frame (candle randomness)
    lsr
    bcc .noEor
    eor #$B4               ; tap -> pseudo-random 8-bit sequence
.noEor:
    sta Rand
    lda FrameCtr           ; every 8 frames (~7.5x/sec) pick a new warm shade
    and #$07
    bne .haveCandle
    lda Rand
    and #$0F
    tax
    lda CandleColors,x
    sta CandleCol          ; ...and hold it until the next pick
.haveCandle:

    lda LaughActive
    bne .laughStrobe
    ldy CandleCol          ; idle -> the current candle shade
    jmp .setStrobe
.laughStrobe:
    ldy #$00               ; the "dark" half of the strobe
    lda FrameCtr
    and #%00000100         ; flip every 4 frames -> hard white flash
    beq .setStrobe
    ldy #STROBE_ON
.setStrobe:
    sty StrobeColor

    ; --- laugh voice warble: nudge AUDF1 +/- a step each frame for a rough,
    ; gravelly growl instead of a clean tone (uses this frame's fresh LFSR) ---
    lda LaughActive
    beq .noWarble
    lda Rand
    and #1
    clc
    adc VoicePitch
    sta AUDF1
.noWarble:

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
;; Evil-laugh envelope.  Rows are (AUDF1 voice-pitch, packed-volume, frames);
;; AUDF1 $FF ends.  The volume byte packs BOTH voices: voice = high nybble
;; (AUDV1), breath-noise = low nybble (AUDV0).  So each "ha" leads with a
;; breath frame (voice off, noise on = the aspirated "h") before the voice
;; swells in -- otherwise the tone slams on and sounds like a plosive "B".
;; The voice is a ROUGH poly-tone (AUDC 6, the Adventure "eaten" timbre),
;; each "ha" a big DOWNWARD pitch sweep (AUDF ramps up = pitch falls) with a
;; per-frame +/-1 warble for grit; start pitches are jittered off any scale.
;; It opens with a breathed-in "MWAAA" wail, then a staccato train that
;; tightens and trails into low "huh" chuckles.  AUDC6 /31: AUDF ~5..16 =
;; ~155..57 Hz.  (Generated by scratchpad/gen_laugh.py -- DEEPEN sets pitch.)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LaughData:
    .byte  7,$0A,2,   7,$88,1,   8,$D5,1   ; MWAAA (breathe in -> falling wail)
    .byte  9,$F3,2,  11,$E2,2,  13,$B1,2
    .byte 12,$00,2,   5,$09,1,   5,$F3,1
    .byte  9,$60,1,   9,$00,2,   7,$09,1
    .byte  7,$E3,1,  10,$50,1,  10,$00,2
    .byte  6,$09,1,   6,$F3,1,  10,$60,1
    .byte 10,$00,2,   8,$09,1,   8,$D3,1
    .byte 12,$50,1,  12,$00,2,   6,$09,1
    .byte  6,$E3,1,  11,$50,1,  11,$00,2
    .byte  9,$09,1,   9,$D3,1,  12,$50,1
    .byte 12,$00,3,   7,$09,1,   7,$C3,1
    .byte 11,$40,1,  11,$00,3,  10,$09,1
    .byte 10,$B3,1,  14,$40,1,  14,$00,3
    .byte 11,$09,1,  11,$A3,1,  14,$40,1
    .byte 14,$00,4,  12,$09,1,  12,$83,1
    .byte 15,$30,1,  15,$00,5,  13,$09,1
    .byte 13,$63,1,  15,$20,1,  15,$00,6
    .byte 14,$09,1,  14,$43,1,  16,$10,1
    .byte 16,$00,7
    .byte  $FF                             ; end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Candle-glow palette: the warm shades the face cutouts flicker through when
;; idle.  A new one is chosen at random (via the LFSR) every 8 frames, so it
;; flickers like the Christmas-tree star's twinkle but without a fixed pattern.
;; All are yellow-gold or BRIGHT orange (luminance >= A) -- deliberately never
;; the body orange ($38) or dimmer, so the eyes/nose/mouth never blend into
;; the pumpkin.  Add/repeat entries to bias the mix (more $1x = more yellow).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CandleColors:
    .byte $1E,$1C,$1A,$2E,$2C,$1C,$1E,$1A
    .byte $2E,$1C,$1A,$2C,$1E,$1C,$1A,$2E

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
