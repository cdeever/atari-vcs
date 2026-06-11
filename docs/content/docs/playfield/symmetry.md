---
title: "Symmetry: Reflected, Repeated & Asymmetric"
weight: 41
---

# Symmetry: Reflected, Repeated & Asymmetric

The playfield's three registers describe only **half the screen**. What happens on the other half — and how you escape the symmetry it imposes — is one of the defining puzzles of the playfield, and the answer comes down to timing.

## Twenty bits, half the screen

`PF0` (4 used bits) + `PF1` (8) + `PF2` (8) = **20 bits**, one per playfield pixel across the **left 20 pixels** of the screen. Each playfield pixel is 4 color clocks wide, so those 20 bits fill the left 80 color clocks — exactly the left half of the 160-wide visible line.

The TIA then **generates the right half automatically** from those same 20 bits. You never write the right half directly; by default you can't. That single fact is why the playfield is *inherently* symmetric.

## Reflected vs. repeated (`CTRLPF` bit 0)

How the right half is generated is set by **bit 0 of `CTRLPF`**, the reflect flag:

- **Repeated (D0 = 0):** the right half draws the same 20 bits again, left to right — the left pattern simply copied across. Good for tiled, repeating backgrounds.
- **Reflected (D0 = 1):** the right half draws the 20 bits *mirrored* — a left-right mirror image around screen center. Good for symmetric shapes: the Christmas tree, a centered logo, a symmetric maze.

Either way, **both halves come from one set of register values.** With a single write of `PF0`/`PF1`/`PF2` per line, you cannot show two different things on the two halves — only a pattern and its copy or mirror.

## Breaking the symmetry: the asymmetric playfield

The escape hatch is timing. The TIA does **not** snapshot the playfield registers at the start of the line; it **reads them continuously as the beam sweeps across**, consulting each register at the moment the beam reaches the pixels it controls. So if you **rewrite `PF0`/`PF1`/`PF2` partway across the line** — after the beam has drawn the left half, but before it reaches the right half — the right half is built from the *new* values. The two halves now differ. That is an **asymmetric playfield.**

The catch is getting the clock cycle right. The window is narrow and unforgiving:

- A visible line is **76 CPU cycles**; the 160 visible color clocks consume about 53 of them, and the left half is gone in the first ~27.
- Your stores must land **after** the beam has passed each register's left-half region and **before** it reaches that register's right-half region.
- Miss the window — a store one cycle too late — and the change lands in the wrong column, smearing the seam where the halves meet.

So an asymmetric kernel is a cycle-counted dance: draw the left half, then race to rewrite the registers in the gap before the right half is drawn. (Because the right half is drawn in reverse under reflection, even the *order* you rewrite them in depends on `CTRLPF`.)

## Tips & Caveats

- **Asymmetry costs cycles, every line.** Those mid-line stores eat a large slice of each scanline's budget, leaving less for sprite positioning and game logic. Plenty of games accept symmetry or repetition precisely to buy those cycles back.
- **It's how asymmetric mazes are made.** A room in *Adventure* with a different wall on each side is exactly this: `PF` registers rewritten mid-line, every line, so left and right differ.
- **Mind the bit order while you're at it.** `PF0` uses only its high nibble, and `PF1` is drawn in the opposite direction from `PF0`/`PF2` — so the bit patterns for a clean seam take some working out. (Covered in the chapter overview.)

> The mental model: the playfield isn't a 40-pixel row you set once; it's 20 bits the beam reads twice. Symmetry is the default only because you usually leave those bits alone between the two halves. Change them in the gap, on exactly the right cycle, and the halves part ways.
