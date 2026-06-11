---
title: "The Playfield"
weight: 40
bookCollapseSection: true
BookIcon: playfield
---

# The Playfield

The playfield is the TIA's coarse, blocky background layer: 20 bits spread across three registers (`PF0`, `PF1`, `PF2`) that cover the left half of the screen, optionally mirrored or repeated on the right via `CTRLPF`. It is the cheapest way to put graphics on screen — one set of register writes can describe a whole scanline — which is why backgrounds, mazes, borders, and large static shapes are usually built from it.

This chapter covers the bit ordering of the three registers (which is *not* uniform — `PF0` uses only its high nibble, and `PF1` runs the opposite direction from `PF0`/`PF2`), how the right half of the screen is derived from the left, and the techniques for shaping the playfield in both directions: rewriting the registers *between* scanlines to draw shapes that change down the screen (exactly how the Christmas tree in `xmas/xmas.asm` is rendered), and rewriting them *within* a scanline to escape symmetry altogether.

- **[Symmetry: Reflected, Repeated & Asymmetric]({{< relref "symmetry" >}})** — why the playfield is symmetric by default, and how cycle-timed mid-line register writes break that symmetry.

> The playfield's quirk is its bit order. Getting a symmetric shape to look right means accounting for `PF1` being reversed relative to `PF0` and `PF2`.
