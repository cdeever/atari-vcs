---
title: "The Asymmetric Playfield"
weight: 42
---

# The Asymmetric Playfield

[Symmetry]({{< relref "symmetry" >}}) is the playfield's default because its 20 bits describe only the left half and the TIA mirrors or copies them onto the right. To show two *different* things on the two halves — a genuinely **asymmetric playfield** — you have to break that deal. The escape hatch is timing.

## The TIA reads the registers as it goes

The crucial fact: the TIA does **not** snapshot `PF0`/`PF1`/`PF2` at the start of the line. It **reads them continuously as the beam sweeps across**, consulting each register at the exact moment the beam reaches the pixels it controls. So if you **rewrite the registers partway across the line** — after the beam has drawn the left half, but before it reaches the right half — the right half is built from the *new* values. The two halves now differ.

## Getting the clock cycle right

The catch is in the timing, and the window is narrow and unforgiving:

- A visible line is **76 CPU cycles**; the 160 visible color clocks consume about 53 of them, and the left half is gone in the first ~27.
- Your stores must land **after** the beam has passed each register's left-half region and **before** it reaches that register's right-half region.
- Miss the window — a store one cycle too late — and the change lands in the wrong column, smearing the seam where the halves meet.

So an asymmetric kernel is a cycle-counted dance: draw the left half, then race to rewrite the registers in the gap before the right half is drawn. Because the right half is drawn in reverse under reflection, even the *order* in which you rewrite the three registers depends on `CTRLPF`.

## Mixing symmetric and asymmetric bands

You don't have to choose one mode for the whole screen. Both the playfield registers and `CTRLPF` are just memory, rewritten line by line, so a single frame can freely **combine symmetric and asymmetric regions** down its height:

- A symmetric scoreboard or border at the top, drawn with one register write per line.
- An asymmetric play area in the middle, with the registers rewritten mid-line every scanline.
- A symmetric floor below, back to one write per line.

You spend the expensive mid-line technique only on the bands that actually need to differ left-to-right, and let the cheap symmetric path carry the rest — a typical VCS trade of cycles for exactly the visual you need, and nowhere else.

## Tips & Caveats

- **Asymmetry costs cycles, every line it's used.** Those mid-line stores eat a large slice of each scanline's [76-cycle budget]({{< relref "/docs/tia-racing-the-beam" >}}), leaving less for sprite positioning and game logic. That's the reason to confine it to the bands that need it.
- **It's how asymmetric mazes are made.** A room in *Adventure* with a different wall on each side is exactly this: `PF` registers rewritten mid-line, every line, so left and right differ.

> The mental model: the playfield isn't a 40-pixel row you set once; it's 20 bits the beam reads twice. Symmetry is the default only because you usually leave those bits alone between the two halves. Change them in the gap, on exactly the right cycle, and the halves part ways.
