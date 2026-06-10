---
title: "Gotchas: Works in Stella, Dies on Hardware"
weight: 114
---

# Gotchas: Works in Stella, Dies on Hardware

This is the page worth bookmarking. The bugs here share a signature: **the game is perfect in the emulator and wrong on the console.** That signature is diagnostic — it means the fault is in an assumption the emulator papers over, not in your game logic.

## RAM is not zero on real hardware

Stella conveniently clears the 128 bytes of RAM at startup. **A real 6507 powers on with RAM full of random garbage.** If any of your code reads a variable before writing it — a counter, a flag, a sprite position — it works in Stella (where it read 0) and does something random on hardware.

The fix is the `CLEAN_START` macro at `Reset`, which every program in this book uses. If you removed it or rolled your own init, this is the first thing to suspect when a cart boots to chaos that Stella never showed.

## Marginal frame timing

Stella tolerates frames that are slightly the wrong length; a real TV — especially an old CRT — does not. If your visible kernel emits 191 or 193 scanlines instead of exactly 192, or your VSYNC/VBLANK counts are off, the emulator may still display a stable image while a real set **rolls, tears, or loses vertical lock.** Recount every region against [The Frame Structure]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}) and check the total is 262 lines. Stella's scanline counter and "jitter"/TV-emulation modes help flush these out *before* you burn.

## NTSC vs. PAL

Color values and frame timing are region-specific. A game written and tuned on an NTSC palette running on a PAL console (and TV) shows **wrong colors and a 50 Hz frame** — your 60-Hz-based timing and your `COLU*` values are both off. Decide your target region and test against it; "looks great in Stella's default NTSC" tells you nothing about a PAL console.

## Image / chip mistakes that mimic code bugs

When the screen is black or garbage, before you debug 6502 logic, rule out the cartridge:

- **Vectors not at the top of the chip** → CPU jumps to garbage. (See [Preparing the ROM Image]({{< relref "preparing-the-image" >}}).)
- **2K image not mirrored into a 4K chip** → half the address space reads erased `$FF`.
- **Wrong burn offset / load address** in the programmer → a perfect image placed at the wrong spot.
- **A failed/unverified bit** → intermittent crashes. Always *verify* after burning.
- **Floating high address lines** on an oversized chip → reads a random bank.

## Bus contention and analog reality

- **Enable polarity wrong** (ROM driving the bus when A12 = 0) → erratic, temperature- and timing-dependent failures that come and go. (See [Wiring the Cartridge]({{< relref "wiring-the-cartridge" >}}).)
- **Dirty edge connector / console slot** → identical black-screen symptom to a logic fault. Clean the contacts before assuming the worst.
- **Slow or marginal power** → a console that's fine with a stock cart may glitch with a hand-wired board that adds capacitance or draws more.

## A bring-up checklist

1. Re-verify the exact `.bin` in Stella (after any padding/mirroring).
2. Confirm file size is exactly 2048 or 4096 bytes (or your banked size).
3. Blank-check the chip, burn, then **verify**.
4. Confirm the programmer's load offset is 0.
5. Seat the chip in a socket; double-check orientation (pin 1).
6. Test in a console you know is good, with a TV you know is good.
7. Change **one** thing at a time when it doesn't work.

## Your gotchas go here

> You mentioned you've hit plenty of these. This page is the natural home for them — the failures *you* actually ran into, with the symptom you saw and what it turned out to be, are far more valuable than a generic list. Add them as bullet points under the relevant section above (or as new sections), and they'll become the part of this book you reach for most.
