---
title: "Waiting Precisely"
weight: 20
---

# Waiting Precisely

Half of kernel work is making things happen; the other half is making them happen *at the right cycle*. [`WSYNC`]({{< relref "/docs/6502-basics/cycles-and-timing" >}}) handles the coarse case — it parks you at the start of the next line — but it can only round *up* to a line boundary. When you need to land on an exact cycle *within* a line (positioning a sprite, [rewriting a playfield register mid-line]({{< relref "/docs/playfield/asymmetric" >}})), or to wait out a whole region of the frame, you need finer and coarser tools than `WSYNC`.

## Burning a few exact cycles

The smallest unit of doing-nothing is `NOP` — **2 cycles**, no registers or memory touched. Strings of `NOP`s pad out even cycle counts, and a couple of standard tricks cover the rest:

- **`NOP` → 2 cycles** each. Even amounts are just enough `NOP`s.
- **`JSR` to an `RTS` → 12 cycles.** Calling a subroutine that does nothing but return burns a tidy 12 (6 + 6), the cheapest way to kill a large fixed chunk.
- **The odd cycle** needs a 3-cycle filler. A `bit` of a scratch zero-page address wastes 3 and leaves A/X/Y alone (it does disturb the flags, so use it where flags don't matter).

In practice you don't hand-assemble these — a conventional **`SLEEP n`** macro (a staple of 2600 `macro.h` libraries) expands into exactly *n* cycles of delay using the building blocks above. You write `SLEEP 8` and trust it; the macro does the arithmetic.

```asm
    sta RESP0       ; strobe player-0 position
    SLEEP 4         ; wait the precise cycles before...
    sta RESP1       ; ...strobing player 1, so it lands where you want
```

## Waiting out a region: the RIOT timer

`NOP`s are for handfuls of cycles. To wait out **thousands** — the 37 lines of [VBLANK]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}), the 30 of overscan — counting `WSYNC`s by hand works but locks you into a fixed line count. The better tool is the [RIOT]({{< relref "/docs/architecture/riot" >}})'s **interval timer**, which counts down on its own while your code does other things.

You start it by writing a count to one of four registers, each with a different *prescaler* — the number of CPU cycles per tick:

| Write to | Each tick = |
|----------|-------------|
| `TIM1T` | 1 cycle |
| `TIM8T` | 8 cycles |
| `TIM64T` | 64 cycles |
| `T1024T` | 1024 cycles |

`TIM64T` is the natural choice for blanking, since 64 cycles is close to one [76-cycle scanline]({{< relref "/docs/6502-basics/cycles-and-timing" >}}). The pattern is always the same:

1. **At the top of the region, set the timer** so it expires near the region's end.
2. **Do your game logic** — movement, collisions, sound, whatever — without counting a single scanline.
3. **Poll `INTIM` until it reaches 0**, then `WSYNC` to snap back onto a line boundary.

```asm
    lda #43
    sta TIM64T      ; arm the timer for ~VBLANK's length
    ; ... run all your per-frame logic here, any length ...
WaitVBlank:
    lda INTIM
    bne WaitVBlank  ; spin until the timer expires
    sta WSYNC       ; align to the next line
```

This is what lets game logic take a *variable* number of cycles each frame without throwing off the display: the timer absorbs the difference. The `music/` project's `xmacro.h` wraps exactly this idea in its `TIMER_SETUP` / `TIMER_WAIT` macros.

## In Practice

- **`WSYNC` for lines, `SLEEP` for cycles, the timer for regions.** Three scales of waiting; reach for the one that matches the span. Counting `WSYNC`s to fill VBLANK works, but the timer frees you from a fixed line count.
- **`SLEEP` is precise; loops are not always.** A delay *loop* (`dey`/`bne`) costs different amounts on its last iteration (the branch falls through), and can hide a page-cross cycle. For exact mid-line timing, prefer straight-line `SLEEP`/`NOP` padding you can count instruction by instruction.
- **The timer keeps running after it hits 0.** `INTIM` underflows and continues counting, so read it *promptly* once it expires — poll in a tight loop rather than wandering off and checking later.
