# Christmas Tree Demo

**Source:** `xmas.asm`

This is the repository's most developed program and a clean example of a **playfield-only kernel**: there are no sprites at all. The entire picture — a green tree on a red background — is drawn by rewriting the playfield registers as the beam moves down the screen.

**See also:** [Techniques used](techniques.md) (the parts list) · [Optimizing the tree lights](light-optimization.md) (a ROM-footprint deep-dive).

## Build & run

```sh
cd xmas
make            # assembles xmas.asm -> xmas.bin (+ .sym, .lst)
make run        # launches Stella on xmas.bin (needs Stella installed)
```

The build is `dasm xmas.asm -I../include -f3 -v0 ...`; `-I../include` points DASM at the shared headers (`vcs.h`, `macro.h`). It assembles to a 4 KB cartridge.

## Setup

After `CLEAN_START`, the demo sets the two colors it uses and enables playfield reflection so the left-half playfield is mirrored into a symmetric tree:

```asm
    ldx #$42       ; red background color
    stx COLUBK
    lda #$C3       ; green playfield color
    sta COLUPF
    ...
    ldx #%00000001 ; CTRLPF D0 = reflect
    stx CTRLPF
```

`CTRLPF` bit 0 (the reflect flag) makes the right half of the screen a mirror image of the left — essential for a symmetric shape, and it halves the work since you only describe the left 20 pixels.

## Drawing the tree

The kernel grows the tree by writing progressively wider `PF2` values, each held for 10 scanlines:

```asm
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
    ; ... widening through %11111111 ...
```

Each block lights one more bit of `PF2`, so the lit region widens by one playfield pixel every 10 lines — and reflection mirrors it, producing a triangle. Lower bands move on to `PF1` to widen the tree further, then a narrow `PF2` band forms the trunk, and finally a full-width `PF0`+`PF1`+`PF2` band draws the ground line.

## Tips & Caveats

- **The playfield bit order is not uniform.** `PF0` uses only its high nibble (bits 4–7) and is read MSB-first; `PF1` is read in the *opposite* direction from `PF0` and `PF2`. The widening masks above only look intuitive because the demo stays within `PF2` for the tree body. Crossing into `PF1` (as the ground line does with `#%11101111` on `PF0` and `#%11111111` on `PF1`) requires accounting for that reversal.
- **Every band's line count is part of the 192-line budget.** Sum the `REPEAT` counts in the visible region; they must total 192 or the frame destabilizes. See [The Frame Structure](https://cdeever.github.io/atari-vcs/docs/tia-racing-the-beam/frame-structure/) in the book.

## The song table

At the end of the file is a `Song` data table — the format used by the book's [Sound chapter](https://cdeever.github.io/atari-vcs/docs/sound/) sequencer. It is a list of `(note, duration)` byte pairs terminated by `$00`:

```asm
Song:
    .byte $02, $10 ; C6, 16 frames (1 beat)
    .byte $05, $08 ; F4, 8 frames (1/2 beat)
    ...
    .byte $00      ; end of data
```

Each pair is a note index and a duration in *frames* (the VCS has no clock but the 60 Hz frame, so durations are counted in frames). The table is present as data here; wiring it to the audio registers is the exercise the Sound chapter walks through.

> Read `xmas.asm` top to bottom alongside this page — it is short, and it demonstrates the frame loop, playfield reflection, mid-screen register changes, and a data table all in one file.
