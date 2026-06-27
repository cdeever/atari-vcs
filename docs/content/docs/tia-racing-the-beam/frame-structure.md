---
title: "The Frame Structure"
weight: 31
---

# The Frame Structure

The TIA produces no picture on its own — your code defines the frame by toggling the `VSYNC` and `VBLANK` signals at the right times and spending the right number of scanlines in each region. An NTSC frame is **262 scanlines**, conventionally divided as:

| Region | Lines | Purpose |
|--------|-------|---------|
| VSYNC | 3 | Tells the TV "new frame starts here." |
| VBLANK | 37 | Top blanking. The picture isn't visible yet — do game logic here. |
| Visible | 192 | The kernel. Everything the player sees is drawn here, one line at a time. |
| Overscan | 30 | Bottom blanking. Read input and collisions, update state. |

{{< vcsanim scene="beam" caption="The beam paints 262 lines top-to-bottom; only the 192 visible lines carry picture. Press play, then scrub to freeze any moment." >}}

## Vertical sync

A frame begins by turning on `VBLANK` and `VSYNC`, then holding `VSYNC` for exactly three scanlines:

```asm
StartFrame:
    lda #02
    sta VBLANK     ; turn VBLANK on
    sta VSYNC      ; turn VSYNC on

    REPEAT 3
        sta WSYNC  ; three VSYNC scanlines
    REPEND

    lda #0
    sta VSYNC      ; turn VSYNC off
```

`WSYNC` ("wait for sync") is the key instruction: storing to it halts the CPU until the beam reaches the start of the next scanline. It is how you spend time measured in *scanlines* without counting individual cycles. The `REPEAT n` / `REPEND` macro simply emits the enclosed instructions `n` times.

> **What if you skip it?** The TIA has no concept of a "frame" — left alone it just emits scanlines forever, with no top and no bottom. The 3-line vertical-sync pulse is the *only* "new frame starts here" marker the TV ever receives, and **your code is the only thing that produces it.** Forget it and the picture **rolls vertically forever**, because the TV's vertical hold has nothing to lock onto. (Horizontal sync is the exception: the TIA generates it automatically every line, so the screen stays horizontally stable on its own — you only ever *wait* for it, never create it.) And if your code runs off the end without looping back to emit the next frame, the CPU simply keeps executing whatever bytes follow as instructions — there is no operating system to catch the fall.

## Vertical blank

Hold `VBLANK` for the 37 blanking lines. In a real game this is where you'd run logic; the demo just waits:

```asm
    REPEAT 37
        sta WSYNC
    REPEND

    lda #0
    sta VBLANK     ; turn VBLANK off — picture begins
```

## The visible kernel

The 192 visible lines are where drawing happens. Whatever you write to TIA registers (`COLUBK`, `PF0`/`PF1`/`PF2`, the sprite registers) takes effect as the beam paints that line. In `xmas.asm` the kernel rewrites the playfield registers in blocks to grow a tree shape down the screen — see the [Christmas Tree walkthrough](https://github.com/cdeever/atari-vcs/blob/main/xmas/README.md). The line counts of all the blocks must sum to 192.

## Overscan

Re-enable `VBLANK` and spend the final 30 lines. This is the natural home for reading the joystick, checking collisions, and clearing the collision latches:

```asm
    lda #2
    sta VBLANK     ; blank again
    REPEAT 30
        sta WSYNC
    REPEND

    jmp StartFrame ; next frame
```

## In Practice

- **The line counts must add up.** `3 + 37 + 192 + 30 = 262`. If your visible region emits 191 or 193 `WSYNC`s, the frame is the wrong height and the TV picture rolls or the image is unstable.
- **`WSYNC` rounds *up* to a line boundary.** It's forgiving of how many cycles your code used *within* a line, but it cannot give cycles back — if a single line's work exceeds ~76 cycles before you hit `WSYNC`, you've overrun into the next line.
- **Do heavy logic in VBLANK/overscan, not the kernel.** During the 192 visible lines the CPU is busy feeding the beam; that's the wrong place for game-state math.

> Once this loop is stable, the rest of the book is about *what you write during the 192 visible lines*.
