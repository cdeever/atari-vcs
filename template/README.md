# Template — a Combat-style game starter

A reusable starting point for a two-player Atari VCS game written in 6502
assembly for DASM. It is **not** a copy of Combat — only the reusable
framework pieces are ported, cleaned up, and commented. Drop your own game
into the marked hooks and the boilerplate handles the rest.

## What you get for free

- **Two scores at the top** — left = player 0, right = player 1, each a
  two-digit BCD number, drawn with the playfield "score mode" trick.
- **A Combat-length round timer** — a round runs ~2 minutes, then ends.
- **End-of-game score blink** — the score flashes during the final ~16
  seconds to warn that time is almost up.
- **Game selection** — SELECT cycles through 16 placeholder variations.
- **Two distinct modes** — ATTRACT mode (cycling background, like Combat)
  versus GAME mode (steady background, timer running), entered with RESET.

## Build & run

```sh
cd template
make            # assembles template.asm -> template.bin (+ .sym, .lst)
make run        # launches Stella on template.bin (needs Stella installed)
```

The build is `dasm template.asm -I../include -f3 -v0 ...`. The `-I../include`
points DASM at the shared headers (`vcs.h`, `macro.h`). Assembling clean is
the only check; the `.lst` and `.sym` files are your debugging artifacts.

It assembles to a 4 KB cartridge (`org $f000`).

## The two modes

| | Attract mode | Game mode |
|---|---|---|
| `GameOn` | `$00` | `$FF` |
| Entered by | power-on / round ending | pressing **RESET** |
| Background | **cycles** colour | steady `BACK_COL` |
| Left score shows | selected variation (1–16) | player 0's score |
| Round timer | idle (free-runs, ignored) | counting down |

### Background cycling

In attract mode the **play-area** background cycles the way Combat cycles
its colours — by EOR-ing the base shade with `GameTimer`, which free-runs
about once per second when no game is on (the write lives in `PlayArea`):

```asm
    lda GameOn
    eor #$FF            ; $00 during play, $FF in attract
    and GameTimer       ; attract -> GameTimer, play -> 0
    eor #BACK_COL       ; fold in the fixed base shade
    sta COLUBK
```

During play the mask collapses to `0`, so the background sits steady at
`BACK_COL`. To cycle every frame for a faster shimmer instead of Combat's
slow once-per-second cadence, swap `GameTimer` for `Clock`.

The kernel writes `COLUBK` twice — once for the score band, once for the
play area — and **both** run the cycle in attract mode, so the whole screen
switches colour uniformly. During play each collapses to its own steady
shade: `SCORE_BACK_COL` behind the score band and `BACK_COL` below. Keep
`SCORE_BACK_COL == BACK_COL` for a uniform attract cycle; set them
differently only if you want the score band to have its own colour in game
mode.

## Where to put your code — the hooks

| Hook | When it runs | What to do there |
|---|---|---|
| `StartGame` | once, when RESET is pressed | reset per-round state (positions, lives, scores already cleared) |
| `GameLogic` | every frame, during VBLANK | move players, handle collisions, update scores |
| `PlayArea` | every frame, in the visible kernel | draw the game field below the score (currently a blank field) |

Do **all** game-state reads/writes in `GameLogic` (it runs during VBLANK,
off-screen). The visible kernel (`PlayArea`) is for drawing only — every
instruction there competes with the electron beam for cycles.

## Working with the framework

### Scores

`Score+0` is player 0 (left), `Score+1` is player 1 (right). Both are
**BCD** — add a point with decimal mode:

```asm
    sed
    clc
    lda Score           ; or Score+1
    adc #$01
    sta Score
    cld
```

`CalcScore` (called each frame) converts the BCD scores into offsets into
the `Numbers` graphics table; you don't call it yourself. Digits `0`–`9`
are supported (five bytes tall each).

### The round timer

`GameTimer` starts at `$80` when RESET is pressed and counts up about once
per second (one tick per 64 frames). The round ends when it rolls over
`$FF -> $00`, giving ~128 ticks ≈ a ~2-minute Combat-length game. When it
rolls over, `GameOn` is cleared and you return to attract mode.

To change the round length, change the starting value in `StartGame`
(higher start = shorter round). The blink threshold below scales with it.

### The end-of-game blink

During the final 1/8 of the timer (`GameTimer >= $F0`) the score blinks via
a `Clock & $30` duty cycle. This is handled in `Switches` by toggling
`KLskip` between `KL_SHOW` (draw the score) and `KL_HIDE` (skip it). The two
values differ by exactly the 12 score scanlines, so the play area always
starts on the same scanline whether or not the score is drawn.

### Game selection

SELECT advances `BinVar` through `0..15` (16 variations), with debounce and
auto-repeat (hold to keep advancing). `BinVar` is the variation number to
branch on in your `GameLogic`; the variations are placeholders, so wire up
what each one does. The current selection is shown as the left score in
attract mode (`BcdVar`, a BCD counter kept in step, displayed as 1–16).

## Tunable constants

Near the top of `template.asm`:

| Constant | Meaning |
|---|---|
| `NUM_VARIATIONS` | how many game-select variations exist (default 16) |
| `SCORE_COL0` / `SCORE_COL1` | left / right score colours |
| `BACK_COL` | play-area background colour (also the attract base shade) |
| `SCORE_BACK_COL` | steady backdrop behind the score band |
| `PLAY_LINES` | visible scanlines below the 14-line score band (192 − 14 = 178) |
| `KL_SHOW` / `KL_HIDE` | score-band line skips for shown vs. blinked-off score |

## Frame structure

Standard NTSC "racing the beam" layout, ~262 scanlines per frame:

1. 3 lines VSYNC
2. 37 lines VBLANK — `Switches`, `GameLogic`, `CalcScore` run here
3. 192 visible lines — `DrawScreen`: 14-line score band, then `PlayArea`
4. 30 lines overscan

Then `jmp StartFrame`. The score band is exactly 14 lines so the play area
always begins at the same place; if you change the score height, adjust
`PLAY_LINES`, `KL_SHOW`, and `KL_HIDE` to keep the visible total at 192.

## Console switches

| Switch | Effect |
|---|---|
| **RESET** | start a new round (enter game mode) |
| **SELECT** | cycle to the next variation (attract mode) |

Color/B&W and the difficulty switches are not wired up — add them in
`Switches` if your game needs them.
