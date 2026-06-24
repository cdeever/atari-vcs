    processor 6502

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; template.asm
;;
;; A reusable starting point for a Combat-style two-player game.
;; It is NOT a copy of Combat -- only the framework pieces are
;; ported, cleaned up, and commented:
;;
;;   * Two BCD scores drawn across the top (left = player 0,
;;     right = player 1) using the playfield "score mode" trick.
;;   * A master game timer that runs for the same length as a
;;     Combat round (~2 minutes), then ends the game.
;;   * The score blinks during the final ~16 seconds to warn
;;     the players that time is almost up.
;;   * GAME SELECT cycles through 16 game variations (the current
;;     selection is shown as the left score in attract mode).
;;     The variations are placeholders -- what each one *does* is
;;     left for you to fill in.
;;   * Two distinct modes: ATTRACT mode (before RESET) cycles the
;;     background colour like Combat; pressing RESET drops into GAME
;;     mode with a steady background and the round timer running.
;;
;; Drop your own game logic into the marked hooks:
;;   - StartGame   : reset per-round state when RESET is pressed
;;   - GameLogic   : per-frame play logic (runs during VBLANK)
;;   - PlayArea    : the visible kernel below the score
;;
;; Build:  cd template && make
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    include "vcs.h"
    include "macro.h"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RAM variables (zero page $80-$FF)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Clock     = $80  ; free-running frame counter, +1 every frame
GameOn    = $81  ; $00 = attract mode, $FF = game in progress
GameTimer = $82  ; master game timer: set to $80 at start, counts
                 ; up ~once/second, ends the game when it rolls $FF->$00
BinVar    = $83  ; selected variation, binary 0..15
BcdVar    = $84  ; selected variation as BCD 1..16 (for display)
SelDbnce  = $85  ; SELECT switch debounce flag (bit 7 = handled)

Score     = $86  ; two BCD scores: Score+0 = P0 (left), Score+1 = P1 (right)
;           $87
ScrOff    = $88  ; score graphic offsets, 4 bytes:
;           $89  ;   +0 P0 lo-nibble, +1 P1 lo-nibble,
;           $8A  ;   +2 P0 hi-nibble, +3 P1 hi-nibble
;           $8B
Numg0     = $8C  ; working byte: this scanline's left-score graphics
Numg1     = $8D  ; working byte: this scanline's right-score graphics
KLskip    = $8E  ; kernel lines to skip before the score; doubles as the
                 ; "draw / don't draw score" flag (used for blinking)
Temp      = $8F  ; scratch

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Tunable constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
NUM_VARIATIONS = 16          ; how many game-select variations exist

SCORE_COL0     = $1E         ; left score colour  (yellow)
SCORE_COL1     = $4E         ; right score colour (a different hue)
BACK_COL       = $00         ; play-area background colour (black)
SCORE_BACK_COL = $00         ; steady backdrop behind the score band

KL_SHOW        = $02         ; KLskip when the score IS drawn
KL_HIDE        = $0E         ; KLskip when the score is hidden (blink off);
                             ; KL_HIDE = KL_SHOW + 12 score lines, so the
                             ; play area always starts on the same scanline.

PLAY_LINES     = 178         ; visible scanlines below the 14-line score band
                             ; (192 total - 14 = 178)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ROM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg
    org $f000

Reset:
    CLEAN_START                 ; zero RAM, TIA, registers; SP = $FF

    ;; Start out in attract mode showing variation 1.
    lda #$00
    sta BinVar
    sta BcdVar
    jsr SetSelectionDisplay     ; Score = "01", right score = "00"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Main frame loop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Cycle column convention (in the beam-timed sections below):
;;   ; <cyc> (<total>)  -- <cyc> = cycles for this instruction,
;;   <total> = running cycles since the last `sta WSYNC`. A WSYNC ends
;;   the line and halts the CPU to the next line's start, so it resets
;;   the total ("-> line"). Branches show taken/not-taken (e.g. 3/2);
;;   totals follow the straight-line fall-through path. A scanline is
;;   76 cycles, so a total must stay under 76 before the next WSYNC.
StartFrame:
    inc Clock                   ; 5       master frame counter

    ;; ---- 3 lines of vertical sync ----
    lda #$02                    ; 2
    sta VSYNC                   ; 3       VSYNC on
    sta WSYNC                   ; 3   ->  vsync line 1
    sta WSYNC                   ; 3   ->  vsync line 2
    sta WSYNC                   ; 3   ->  vsync line 3
    lda #$00                    ; 2  (2)
    sta VSYNC                   ; 3  (5)  VSYNC off

    ;; ---- vertical blank: ~37 lines run free under the timer (no WSYNCs) ----
    lda #$02                    ; 2  (7)
    sta VBLANK                  ; 3  (10)
    lda #43                     ; 2  (12)
    sta TIM64T                  ; 4  (16) timer now counts ~37 lines

    jsr Switches                ; 6 +sub  RESET / SELECT / game-timer / blink
    jsr GameLogic               ; 6 +sub  <-- your per-frame play logic
    jsr CalcScore               ; 6 +sub  BCD scores -> graphic offsets

WaitVBlank:
    lda INTIM                   ; 4       poll the VBLANK timer
    bne WaitVBlank              ; 3/2     spin until it expires

    jsr DrawScreen              ; 6 +sub  192 visible scanlines

    ;; ---- 30 lines of overscan ----
    lda #$02                    ; 2
    sta VBLANK                  ; 3
    ldx #30                     ; 2
OverScan:
    sta WSYNC                   ; 3   ->  one overscan line (x30)
    dex                         ; 2  (2)
    bne OverScan                ; 3/2 (4) loop back to WSYNC

    jmp StartFrame              ; 3       next frame

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Switches -- console logic, run once per frame during VBLANK.
;;
;; Handles RESET (start a game), the game timer, the end-of-game
;; score blink, and SELECT (cycle through the 16 variations).
;; Ported and cleaned from Combat's GSGRCK routine.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Switches:
    lda SWCHB
    lsr                         ; RESET (bit 0) -> carry
    bcs NoReset                 ; carry set => not pressed
    jsr StartGame               ; RESET pressed: begin a new game
    rts

NoReset:
    ;; Decide whether the score is drawn this frame.
    ;; Always draw it, EXCEPT during the off phase of the
    ;; end-of-game blink (last 1/8 of the timer).
    ldy #KL_SHOW
    lda GameTimer
    and GameOn                  ; only blink while a game is actually running
    cmp #$F0                    ; in the final 1/8 of the timer?
    bcc ScoreVisible            ; no -> always draw
    lda Clock
    and #$30                    ; blink duty cycle off Clock
    bne ScoreVisible            ; on phase -> draw
    ldy #KL_HIDE                ; off phase -> hide the score
ScoreVisible:
    sty KLskip

    ;; Advance the game timer about once per second
    ;; (1 frame in 64 -> ~128 ticks from $80 to rollover = ~2 minutes).
    lda Clock
    and #$3F
    bne ChkSelect
    sta SelDbnce                ; periodically clear debounce (SELECT auto-repeat)
    inc GameTimer
    bne ChkSelect
    sta GameOn                  ; timer rolled over -> game over (A = 0)

    ;; ---- SELECT: cycle to the next variation ----
ChkSelect:
    lda SWCHB
    and #$02                    ; SELECT (bit 1)
    beq SelDown
    sta SelDbnce                ; released (A = $02, bit7 clear): re-arm
    rts
SelDown:
    bit SelDbnce
    bmi SwDone                  ; already handled this press -> ignore
    lda #$FF
    sta SelDbnce                ; mark this press handled

    inc BinVar                  ; next variation
    lda BinVar
    cmp #NUM_VARIATIONS
    bcc SetSelectionDisplay     ; still in range 0..15
    lda #$00                    ; wrap back to variation 0
    sta BinVar
    sta BcdVar                  ; reset the BCD display counter too

SetSelectionDisplay:
    ;; Keep BcdVar in step with BinVar in BCD, and show it as the
    ;; left score (1..16) so the player can see the current selection.
    sed
    clc
    lda BcdVar
    adc #$01
    sta BcdVar
    cld
    sta Score                   ; left score = selected variation (1..16)
    lda #$00
    sta Score+1                 ; right score blank (00) while selecting
SwDone:
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; StartGame -- called when RESET is pressed. Set up a fresh round.
;;
;; GameTimer starts at $80 and counts up to its $FF->$00 rollover,
;; one tick per ~second, giving a Combat-length game of ~2 minutes.
;; Add your own per-round initialisation where marked.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
StartGame:
    lda #$FF
    sta GameOn                  ; game is now in progress
    lda #$80
    sta GameTimer               ; ~2 minute countdown begins
    lda #$00
    sta Score                   ; reset both scores to 0
    sta Score+1
    ;; --- your per-round setup goes here (positions, lives, etc.) ---
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GameLogic -- your per-frame play logic. Runs during VBLANK,
;; so do all reads/writes of game state here, not in the kernel.
;; The variation is in BinVar (0..15); branch on it to change rules.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GameLogic:
    lda GameOn
    beq GLdone                  ; nothing to do in attract mode
    ;; --- move players, handle collisions, update Score/Score+1 ---
    ;;     (Scores are BCD: use SED/CLC/ADC #1/CLD to add a point.)
GLdone:
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CalcScore -- convert the two BCD scores into offsets into the
;; Numbers graphics table. Each digit is 5 bytes tall, so the
;; offset is (digit * 5); the *5 falls out cheaply from BCD.
;; Ported from Combat's SCROT.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CalcScore:
    ldx #$01                    ; do player 1, then player 0
CalcLoop:
    lda Score,x
    and #$0F                    ; low (ones) digit
    sta Temp
    asl                         ; *2
    asl                         ; *4
    clc
    adc Temp                    ; + *1 = *5
    sta ScrOff,x

    lda Score,x
    and #$F0                    ; high (tens) digit, currently *16
    lsr                         ; *8
    lsr                         ; *4
    sta Temp
    lsr                         ; *2
    lsr                         ; *1
    clc
    adc Temp                    ; *4 + *1 = *5
    sta ScrOff+2,x

    dex
    bpl CalcLoop
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DrawScreen -- the visible kernel (192 scanlines).
;;
;; First the two-score band, then the play area. The scores use the
;; playfield "score mode" (CTRLPF bit 1): the left half of the screen
;; is coloured with COLUP0 and the right half with COLUP1, and a single
;; PF1 register is rewritten mid-line so the left and right halves show
;; different digits. This score loop is Combat's, kept verbatim because
;; its mid-line timing is what makes the trick land correctly.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DrawScreen:
    sta WSYNC                   ; 3   ->  end last VBLANK line (reset)
    lda #$00                    ; 2  (2)
    sta VBLANK                  ; 3  (5)  end vertical blank -> picture begins

    lda #$02                    ; 2  (7)
    sta CTRLPF                  ; 3  (10) score mode: left=COLUP0, right=COLUP1
    lda #SCORE_COL0             ; 2  (12)
    sta COLUP0                  ; 3  (15) left score colour
    lda #SCORE_COL1             ; 2  (17)
    sta COLUP1                  ; 3  (20) right score colour

    ;; Score-band background. In ATTRACT mode it runs the same Combat
    ;; colour cycle as the play area below, so the whole screen switches
    ;; colour uniformly; during play it sits steady at SCORE_BACK_COL.
    lda GameOn                  ; 3  (23)
    eor #$FF                    ; 2  (25) $00 during play, $FF in attract
    and GameTimer               ; 3  (28) attract -> GameTimer, play -> 0
    eor #SCORE_BACK_COL         ; 2  (30) fold in the steady base shade
    sta COLUBK                  ; 3  (33)

    ldx KLskip                  ; 3  (36) skip a few lines before the score
SkipTop:
    sta WSYNC                   ; 3   ->  skip line (x KLskip, reset)
    dex                         ; 2  (2)
    bne SkipTop                 ; 3/2 (4) loop, or fall through

    lda KLskip                  ; 3  (7)
    cmp #KL_HIDE                ; 2  (9)  score hidden this frame (blink off)?
    beq PlayArea                ; 3/2     taken when hidden (+1 page cross)

    ;; ---- draw the two scores (5 rows, 2 scanlines each) ----
    ;; (still on the line after the skips; beq above fell through at 11)
    ldx #$05                    ; 2  (13) score is five bytes tall
    lda #$00                    ; 2  (15)
    sta Numg0                   ; 3  (18) first pass draws blanks; real
    sta Numg1                   ; 3  (21) graphics are computed one line ahead
ScoreLoop:
    sta WSYNC                   ; 3   ->  row line A (reset)
    lda Numg0                   ; 3  (3)
    sta PF1                     ; 3  (6)  recycle last line's left score
    ldy ScrOff+2                ; 3  (9)
    lda Numbers,y               ; 4  (13) P0 tens digit (left 4 px)
    and #$F0                    ; 2  (15)
    sta Numg0                   ; 3  (18)
    ldy ScrOff                  ; 3  (21)
    lda Numbers,y               ; 4  (25) P0 ones digit (right 4 px)
    and #$0F                    ; 2  (27)
    ora Numg0                   ; 3  (30)
    sta Numg0                   ; 3  (33) left score ready for next line
    lda Numg1                   ; 3  (36)
    sta PF1                     ; 3  (39) recycle last line's right score
    ldy ScrOff+3                ; 3  (42)
    lda Numbers,y               ; 4  (46) P1 tens digit
    and #$F0                    ; 2  (48)
    sta Numg1                   ; 3  (51)
    ldy ScrOff+1                ; 3  (54)
    lda Numbers,y               ; 4  (58) P1 ones digit
    and #$0F                    ; 2  (60)
    sta WSYNC                   ; 3   ->  row line B (reset); 60 used above
    ora Numg1                   ; 3  (3)  finish right score
    sta Numg1                   ; 3  (6)
    lda Numg0                   ; 3  (9)
    sta PF1                     ; 3  (12) left score lands in left half
    dex                         ; 2  (14)
    bmi PlayArea                ; 3/2 (16) taken on last row -> PlayArea
    inc ScrOff                  ; 5  (21) advance every offset to the
    inc ScrOff+2                ; 5  (26) next graphics row
    inc ScrOff+1                ; 5  (31)
    inc ScrOff+3                ; 5  (36)
    lda Numg1                   ; 3  (39)
    sta PF1                     ; 3  (42) right score lands in right half
    jmp ScoreLoop               ; 3  (45) -> top WSYNC ends row line B

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PlayArea -- the rest of the visible frame below the score.
;; This is just a blank, coloured field. Replace it with your own
;; kernel (players, missiles, playfield, etc.).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Totals below assume entry from the score loop's bmi (last row),
    ;; which lands here at ~17 cycles into the line. The setup finishes
    ;; well before the first PlayLoop WSYNC. (The score-hidden beq path
    ;; enters a little earlier; either way it fits in one line.)
PlayArea:
    lda #$00                    ; 2  (19)
    sta PF0                     ; 3  (22)
    sta PF1                     ; 3  (25)
    sta PF2                     ; 3  (28)
    sta CTRLPF                  ; 3  (31) back to a normal playfield

    ;; Play-area background. A fixed shade while a game is in progress,
    ;; but in ATTRACT mode cycle it the way Combat cycles its colours:
    ;; EOR the base shade with GameTimer, which free-runs ~once/second
    ;; when no game is on. (Swap GameTimer for Clock to cycle every
    ;; frame instead, for a faster shimmer.) The score band above keeps
    ;; its own steady backdrop.
    lda GameOn                  ; 3  (34)
    eor #$FF                    ; 2  (36) $00 during play, $FF in attract
    and GameTimer               ; 3  (39) attract -> GameTimer, play -> 0
    eor #BACK_COL               ; 2  (41) fold in the fixed base shade
    sta COLUBK                  ; 3  (44)
    ldx #PLAY_LINES             ; 2  (46)
PlayLoop:
    sta WSYNC                   ; 3   ->  one play line (x PLAY_LINES, reset)
    ;; --- draw one scanline of your game here ---
    dex                         ; 2  (2)
    bne PlayLoop                ; 3/2 (4) loop back to WSYNC
    rts                         ; 6       back to the frame loop (overscan)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Numbers -- digit graphics, 0..9, five bytes each. Each byte holds
;; the digit twice (high nibble and low nibble) so one PF1 write can
;; serve either the left or right four-pixel column of a score.
;; (Leading-zero blanking is left as an exercise.)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Numbers:
    .byte $0E ; |    XXX |   0
    .byte $0A ; |    X X |
    .byte $0A ; |    X X |
    .byte $0A ; |    X X |
    .byte $0E ; |    XXX |

    .byte $22 ; |  X   X |   1
    .byte $22 ; |  X   X |
    .byte $22 ; |  X   X |
    .byte $22 ; |  X   X |
    .byte $22 ; |  X   X |

    .byte $EE ; |XXX XXX |   2
    .byte $22 ; |  X   X |
    .byte $EE ; |XXX XXX |
    .byte $88 ; |X   X   |
    .byte $EE ; |XXX XXX |

    .byte $EE ; |XXX XXX |   3
    .byte $22 ; |  X   X |
    .byte $66 ; | XX  XX |
    .byte $22 ; |  X   X |
    .byte $EE ; |XXX XXX |

    .byte $AA ; |X X X X |   4
    .byte $AA ; |X X X X |
    .byte $EE ; |XXX XXX |
    .byte $22 ; |  X   X |
    .byte $22 ; |  X   X |

    .byte $EE ; |XXX XXX |   5
    .byte $88 ; |X   X   |
    .byte $EE ; |XXX XXX |
    .byte $22 ; |  X   X |
    .byte $EE ; |XXX XXX |

    .byte $EE ; |XXX XXX |   6
    .byte $88 ; |X   X   |
    .byte $EE ; |XXX XXX |
    .byte $AA ; |X X X X |
    .byte $EE ; |XXX XXX |

    .byte $EE ; |XXX XXX |   7
    .byte $22 ; |  X   X |
    .byte $22 ; |  X   X |
    .byte $22 ; |  X   X |
    .byte $22 ; |  X   X |

    .byte $EE ; |XXX XXX |   8
    .byte $AA ; |X X X X |
    .byte $EE ; |XXX XXX |
    .byte $AA ; |X X X X |
    .byte $EE ; |XXX XXX |

    .byte $EE ; |XXX XXX |   9
    .byte $AA ; |X X X X |
    .byte $EE ; |XXX XXX |
    .byte $22 ; |  X   X |
    .byte $EE ; |XXX XXX |

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reset vectors
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $fffc
    .word Reset
    .word Reset
