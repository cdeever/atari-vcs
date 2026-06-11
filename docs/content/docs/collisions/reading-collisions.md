---
title: "Reading & Clearing"
weight: 20
---

# Reading & Clearing

The TIA does the detecting; your job is two small, regular acts: **read** the [latches]({{< relref "the-collision-registers" >}}) once the frame has been drawn, and **clear** them before the next one. Get that rhythm right and collisions are nearly free; get it wrong and they either never fire or never stop.

## Testing a latch with `BIT`

Each collision flag sits in bit 7 (and bit 6) of its register, which is exactly where `BIT` is most useful: it copies a memory location's bit 7 into the **N** flag and bit 6 into the **V** flag, without changing any register ([see Registers & Flags]({{< relref "/docs/6502-basics/registers" >}})). So one `BIT` tests both pairs at once:

```asm
    bit CXP0FB      ; P0–PF in bit 7 (→N), P0–BL in bit 6 (→V)
    bmi P0HitWall   ; N set → player 0 touched the playfield
    bvs P0HitBall   ; V set → player 0 touched the ball
```

When you only want one bit, an `AND` with a mask works too — `lda CXM0P` / `and #$80` / `bne …` — but `BIT` is the idiom precisely because it leaves A alone and gets you two flags for one read.

## Clearing with `CXCLR`, every frame

Collision latches are **sticky**: once set, a bit stays set until you reset it. There is no per-bit clear — writing to the strobe `CXCLR` wipes **all** of them at once. You do this once per frame, and the standard place is the bottom of the frame:

```asm
    ; ... overscan ...
    sta CXCLR       ; clear every collision latch for the next frame
```

This is the discipline the chapter overview warns about. **Forget `CXCLR` and the first collision of the game appears to last forever** — the latch never resets, so "ball is touching wall" reads true on every frame thereafter.

## Where in the frame to read

Because a latch records collisions *as the beam draws them*, a register only reflects everything that happened this frame **after the whole visible region is drawn**. So the natural shape is:

1. **Visible kernel** — draw the frame; the TIA latches any overlaps automatically.
2. **Overscan** — read the collision registers you care about and turn them into game events; then `CXCLR`.
3. **Next frame** — react (bounce the ball, score the hit, end the life) with a clean slate.

Read too early — mid-kernel — and you only see collisions from the lines drawn *so far*, which is occasionally useful but usually a bug.

## In Practice

- **A latch says *that*, not *where*.** You learn the ball hit the playfield, not which wall or at what pixel. Games recover the "where" from what they already know — the ball's tracked position — not from the TIA.
- **Detection follows the lit pixels.** Overlap in a transparent part of a sprite doesn't count, so collision is as precise as the artwork. That's usually a gift (pixel-perfect hits for free), occasionally a surprise (a one-pixel gap that never triggers).
- **Mind objects left enabled off-screen.** A missile or ball still enabled during [VBLANK or overscan]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}) can latch stray collisions. If a hit fires that shouldn't, check what's still drawing outside the visible region.

> The whole chapter in one loop: draw the frame, read the few latches you care about in overscan, act on them, `CXCLR`, repeat. The TIA found the overlaps; you just decide what they *mean*.
