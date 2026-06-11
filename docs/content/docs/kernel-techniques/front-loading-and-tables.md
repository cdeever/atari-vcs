---
title: "Front-Loading & Tables"
weight: 40
---

# Front-Loading & Tables

The last way to fit work into a [76-cycle line]({{< relref "/docs/6502-basics/cycles-and-timing" >}}) is to **not do it on that line.** Two habits push work out of the hot path: *front-loading* — computing a line's data before the line needs it — and *tables* — computing it before the program even runs. Both trade something plentiful (earlier time, ROM) for something scarce (cycles in the critical window).

## Front-loading: be early

In the moment the beam reaches a sprite, you have just a few cycles to put the right byte in `GRP0`. If those cycles are also spent *deciding* which byte — fetching a pointer, adding an offset, looking up a color — you'll overflow. So you do that deciding **earlier**, during the slack of the *previous* line, and leave only a fast store for the critical instant.

```asm
    ; ...near the end of the current line, with cycles to spare:
    lda (P0Ptr),y    ; fetch NEXT line's sprite row now
    sta NextRow      ; stash it in a zero-page variable
    sta WSYNC
    ; ...top of the next line: the value is already in hand:
    lda NextRow      ; (or it's already in a register)
    sta GRP0         ; just a store at the critical moment
```

The principle generalizes to registers: get the value you'll need into A, X, or Y *before* the tight window, so the window itself contains only the unavoidable store. A kernel that's "always one step ahead of the beam" is the goal.

## Tables: compute it before the program runs

The ultimate front-loading is doing the work at *assembly* time. Any value you can precompute, you bake into a ROM `.byte` table and fetch with a single indexed load — turning arithmetic into a lookup:

```asm
    ldx Angle
    lda SineTable,x   ; the sine — no multiply, no loop, one 4-cycle read
```

This is the [Numbers & Arithmetic]({{< relref "/docs/prerequisites/numbers" >}}) habit at kernel scale: with no multiply instruction and no spare cycles, you precompute multiplication tables, sine/cosine for motion, the [note→`AUDF` table]({{< relref "/docs/sound/tones-noise-and-pitch" >}}), the [×5 digit offsets]({{< relref "/docs/playfield/scoreboard" >}}), and sprite-row pointers — then *read* the answer. [ROM]({{< relref "/docs/architecture/rom" >}}) is measured in kilobytes; cycles and [RAM]({{< relref "/docs/architecture/riot" >}}) are desperately scarce. Spend the plentiful resource.

## Page-align the hot tables

There's a sharp edge here, and it's the [page-crossing penalty]({{< relref "/docs/6502-basics/addressing-modes" >}}): an indexed read whose address crosses a 256-byte boundary silently costs **+1 cycle** — and in a kernel counting to 76, one stray cycle tears the picture. The fix is to **align a time-critical table to a page boundary** so the index can never cross it:

```asm
    align 256          ; (or  org $Fx00) — start the table on a page
SpriteRows:
    .byte ...          ; now SpriteRows,Y never crosses a page → always 4 cycles
```

A table that lives entirely within one 256-byte page makes its indexed reads a flat, predictable cost — which is the whole game when you're counting cycles. It's a common reason a kernel mysteriously tears after an edit *nowhere near it*: an earlier change shifted a table across a page line.

## In Practice

- **Front-loading turns a tight line into two roomy halves.** The work didn't shrink — it moved to where the cycles were. Always ask whether a computation *has* to happen now, or could have happened a line ago.
- **If you can precompute it, precompute it.** The most VCS-native optimization is refusing to calculate at run time anything you could have calculated at build time.
- **Align tables you read inside the kernel; don't bother for the rest.** Page alignment costs ROM (padding to the boundary), so spend it only on the tables whose reads happen under the [cycle gun]({{< relref "counting-cycles" >}}) — not on data you read once in overscan.
