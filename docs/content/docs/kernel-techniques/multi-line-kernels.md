---
title: "Multi-Line Kernels"
weight: 30
---

# Multi-Line Kernels

[Counting cycles]({{< relref "counting-cycles" >}}) eventually delivers bad news: there are jobs that simply don't fit in one [76-cycle line]({{< relref "/docs/6502-basics/cycles-and-timing" >}}). Updating *both* [players]({{< relref "/docs/sprites/drawing-a-player" >}}), fetching their colors, advancing their counters, and still leaving room for the draw — added up, it overflows. When a single line can't hold the work, you stop trying to do it in one.

## Spread the work across two lines

A **two-line kernel** runs its loop body once for every *two* scanlines. The TIA still draws every line — the beam doesn't slow down — but your code now has roughly **two lines' worth of cycles** to prepare what those lines show. You split the work: some on the first line, the rest on the second.

The price is vertical resolution. If the loop only refreshes a sprite's graphics every two scanlines, each row of sprite data is **two scanlines tall** — the sprite is drawn at half the vertical detail. For most VCS sprites that's an easy trade: a slightly chunkier character in exchange for the cycles to animate and move it at all. (It's also why so many 2600 sprites have that characteristic two-scanline-pixel look.)

```asm
TwoLineKernel:
    ; --- first scanline of the pair ---
    lda (P0Ptr),y     ; fetch player 0's row
    sta GRP0          ; (displays now)
    lda P0Color,y
    sta COLUP0
    sta WSYNC
    ; --- second scanline of the pair ---
    lda (P1Ptr),y     ; fetch player 1's row
    sta GRP1
    lda P1Color,y
    sta COLUP1
    dey               ; advance one 2-line row
    sta WSYNC
    bne TwoLineKernel
```

Player 0's work lands on the odd lines, player 1's on the even — each gets a full line of cycles instead of half of one.

## VDEL: keeping the two halves in sync

There's a subtlety: if you update `GRP0` and `GRP1` on *different* lines, their graphics can fall a line out of step with each other. The fix is **vertical delay** — `VDELP0`, `VDELP1`, `VDELBL` — the registers the [Sprites chapter]({{< relref "/docs/sprites/drawing-a-player" >}}) only hinted at.

With `VDEL` enabled, a graphics register is **double-buffered**: writing `GRP0` doesn't display immediately — it loads a buffer that only takes effect when you write `GRP1` (and vice versa). That coupling is exactly what a two-line kernel needs: it lets you write the two players on alternate lines while their updates *display* in lockstep, and it gives you scanline-accurate vertical positioning despite the two-line cadence. In short, **`VDEL` is the register that makes two-line kernels behave.**

## Going further: N-line kernels

The idea generalizes. A **three-** or more-line kernel buys even more cycles per loop, at even coarser vertical resolution — useful when the per-line work is heavy and the graphics can tolerate it (large, slow-moving objects, or backgrounds that don't need fine detail). The trade is always the same: **more scanlines per iteration = more time, less vertical resolution.** You pick the point on that curve your game can afford.

## In Practice

- **Two-line kernels are the default for real games.** A single-line kernel is mostly for backgrounds and demos; the moment you're moving two independent, animated sprites, you're almost certainly in a two-line kernel.
- **Keep the two halves balanced.** The win comes from *evenly* splitting work across the pair — if one line does everything and the other idles, you've gained nothing. Budget each of the two lines as carefully as you'd budget one.
- **`VDEL` is easy to forget and baffling to debug.** A two-line kernel where one sprite shimmers a line out of phase is almost always a missing `VDELP0`/`VDELP1`. Suspect it first.
