---
title: "The Playfield"
weight: 40
bookCollapseSection: true
BookIcon: playfield
---

# The Playfield

If you come from almost any later machine, your instinct is a **frame buffer**: a grid of pixels at `(x, y)` that you poke to draw a background. The VCS playfield is *not that*, and the distance between what you expect and what you actually get is the whole story of this chapter.

There is no background bitmap. The playfield is **three registers** — `PF0`, `PF1`, `PF2` — holding **20 bits** that describe one chunky row of background, which the TIA paints in real time as the beam crosses each scanline. Those 20 bits stretch across a **40-pixel-wide** screen, and each "pixel" is a [virtual block]({{< relref "registers" >}}) 4 color clocks wide and one scanline tall. Nothing is stored; there are only register values the beam reads as it goes.

And those registers are quirky in three ways that trip up everyone:

- **`PF0` is half a register.** Only its high four bits (D4–D7) are used; the low nibble is ignored entirely.
- **The bit order isn't uniform.** `PF0` and `PF2` are read one direction, but **`PF1` is reversed** — so a pattern that looks continuous in your source has to be laid out with `PF1`'s bits flipped.
- **You only describe half the screen.** The 20 bits cover the left 20 pixels; the right 20 are generated automatically, as a mirror or a copy.

## Why so strange?

Because the obvious design was impossible in 1977. A true `(x, y)` bitmap of even this coarse 40×192 screen would need about **960 bytes** at one bit per pixel — and the VCS has **128 bytes of RAM, total.** And there would be no time to use it anyway: at [76 CPU cycles per scanline]({{< relref "/docs/tia-racing-the-beam" >}}), the processor cannot fetch and push a stream of pixels fast enough to fill a line. So Atari's designers traded resolution for cost: a handful of register bits, set once per line, that the TIA expands into a blocky background essentially for free. Every quirk above is a fingerprint of that bargain — each one saved chips, memory, or cycles.

For all that, it remains the **cheapest way to put graphics on screen** — one set of writes describes an entire line — which is why backgrounds, mazes, borders, and large static shapes are almost always built from the playfield.

## In this chapter

- **[The Three Registers]({{< relref "registers" >}})** — exactly which bit of `PF0`/`PF1`/`PF2` lights which pixel, with the half-nibble and reversed-`PF1` quirks laid out in a diagram. (Left half only.)
- **[Symmetry: Reflection & Repetition]({{< relref "symmetry" >}})** — where the right half of the screen comes from: mirrored or copied from the left.
- **[The Asymmetric Playfield]({{< relref "asymmetric" >}})** — escaping symmetry by rewriting the registers mid-scanline, and mixing symmetric and asymmetric bands down the screen.

> The playfield's defining quirk is its bit order. Getting a shape to look right means accounting for `PF0`'s half-nibble and `PF1` being reversed relative to `PF0` and `PF2`.
