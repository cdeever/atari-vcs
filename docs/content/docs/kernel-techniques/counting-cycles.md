---
title: "Counting Cycles"
weight: 10
---

# Counting Cycles

Every other platform lets you write code and measure it later. On the VCS you must know the cost *before* you run it, because a [visible scanline is 76 CPU cycles]({{< relref "/docs/6502-basics/cycles-and-timing" >}}) and there is no "a little slow" — a kernel line that needs 77 doesn't lag, it corrupts the picture. Counting cycles is the habit that makes everything else in this chapter possible.

## Budget from WSYNC to WSYNC

A kernel is a loop, and the unit you budget is **one pass: the cycles between one `STA WSYNC` and the next.** Add up the cost of every instruction in that span — using the [per-instruction costs]({{< relref "/docs/6502-basics/cycles-and-timing" >}}) — and confirm the total fits under 76 (minus whatever the visible drawing already spends).

```asm
KernelLine:
    lda (SpritePtr),y   ; 5   fetch this line's sprite row
    sta GRP0            ; 3   draw it
    lda BgColor,y       ; 4   fetch background color
    sta COLUBK          ; 3   set it
    dey                 ; 2   next row
    sta WSYNC           ; 3   wait for the next line
    bne KernelLine      ; 3   loop  → 23 cycles, comfortably under 76
```

The point isn't this exact line — it's the *practice* of tallying the right-hand column as you write, so you always know how much room is left before the beam runs out.

## Leave margin

Aim to finish with cycles to spare, not exactly at 76. A kernel that's perfectly full is *fragile*: one extra instruction, a table that drifts across a [page boundary]({{< relref "/docs/6502-basics/addressing-modes" >}}), a branch that starts taking an extra cycle, and it tips over. Headroom is what lets you add a feature later without the whole kernel collapsing.

## Tools beat arithmetic — but only just

You don't have to count entirely in your head:

- **The assembler's listing (`.lst`)** shows the exact bytes each line produced, so you can see instruction boundaries and catch a long-form addressing mode you didn't intend.
- **Stella's debugger** displays a live cycle and color-clock counter and can step a scanline at a time, so you can *watch* where a line's budget goes.

But the habit worth building is doing the tally *as you write*. Tools tell you a line overran after the fact; cycle-sense tells you it will before you've typed it, which is the difference between composing a kernel and debugging a rolling screen.

## Spend cycles where the cycles are

Counting reveals where to be frugal, and the [6502]({{< relref "/docs/6502-basics" >}}) rewards a few habits in the hot path:

- **Keep hot data in [zero page]({{< relref "/docs/6502-basics/addressing-modes" >}}).** A zero-page load is 3 cycles to absolute's 4 — and on the VCS your [RAM is already zero page]({{< relref "/docs/prerequisites/memory-mapped" >}}), so this is free to take advantage of.
- **Reuse what's in A, X, and Y.** Re-loading a value you already had in a register is pure waste; arrange the work so the value you need next is often already where you need it.
- **Watch for page-crossing reads.** An indexed read that crosses a 256-byte boundary silently costs +1; a table positioned to stay within a page keeps the cost flat (more in [Front-Loading & Tables]({{< relref "front-loading-and-tables" >}})).

## In Practice

- **Count the worst case, not the typical one.** A line with a conditional must fit on the branch that costs the *most* — the picture tears on the expensive path, not the average.
- **`WSYNC` ends the line, so cycles before it are what matter.** Work *after* the last `WSYNC` of a line spills into the next one. The 76 you're counting is from `WSYNC` to `WSYNC`, not from the top of your source.
- **When you can't make it fit, change the shape, not just the instructions.** If a line genuinely needs more than 76 cycles of work, no amount of shaving helps — you move work off the line entirely, which is what the rest of this chapter is about: [waiting]({{< relref "waiting-precisely" >}}), [spreading across lines]({{< relref "multi-line-kernels" >}}), and [precomputing]({{< relref "front-loading-and-tables" >}}).
