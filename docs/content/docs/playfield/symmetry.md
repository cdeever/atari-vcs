---
title: "Symmetry: Reflection & Repetition"
weight: 41
---

# Symmetry: Reflection & Repetition

The [three registers]({{< relref "registers" >}}) gave you 20 bits — the **left 20 pixels** of a 40-pixel-wide screen. You never wrote the other 20. This page is where they come from.

The TIA **generates the right half automatically** from those same 20 bits, and a single flag decides whether it does so as a copy or a mirror. That is why the playfield is *inherently* symmetric: one write of `PF0`/`PF1`/`PF2` per line paints the whole 40-pixel width, but both halves are built from the same bits.

## Reflected vs. repeated (`CTRLPF` bit 0)

How the right half is generated is set by **bit 0 of `CTRLPF`**, the reflect flag:

- **Repeated (D0 = 0):** the right half draws the same 20 bits again, left to right — the left pattern simply copied across. The screen reads as two identical halves; good for tiled or repeating backgrounds.
- **Reflected (D0 = 1):** the right half draws the 20 bits *mirrored* — a left-right mirror image around screen center. Good for symmetric shapes: the Christmas tree, a centered logo, a symmetric maze, a bowl-shaped arena.

Either way, **both halves come from one set of register values.** That is the cheap deal: a single write of `PF0`/`PF1`/`PF2` per line paints the entire 40-pixel width. The cost is that with that one write you cannot show two *different* things on the two halves — only a pattern and its copy or mirror. (Breaking that limit is the [asymmetric playfield]({{< relref "asymmetric" >}}).)

## Choosing reflect or repeat

- **Reflect** when the content is naturally symmetric — which most playfields are, so reflection is the common default. A maze, an arena, a framed border, or a centered emblem all look right mirrored.
- **Repeat** when you want a horizontally tiling texture — a repeating brick course, a banded background — where the same motif twice is exactly the intent.

The reflect bit lives in `CTRLPF` alongside other playfield controls — [object priority]({{< relref "/docs/sprites/priority" >}}) and the [score-mode coloring]({{< relref "scoreboard" >}}) — and like any register it can be **rewritten between scanlines**, so one band of the screen can be reflected while another repeats.

## In Practice

- **Mind the center seam.** Under reflection the screen mirrors around the middle, so the last bit of `PF2` sits next to its own reflection — a lit pixel there reads as a 2-pixel-wide block straddling center. Plan shapes that meet in the middle with that doubling in mind.
- **The bit order still applies.** Even for a symmetric shape, you're laying out the *left* half into `PF0`/`PF1`/`PF2` with `PF0`'s half-nibble and `PF1` reversed; reflection only handles the right half for you, not the quirks of the left.
