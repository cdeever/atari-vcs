---
title: "Collisions"
weight: 60
bookCollapseSection: true
BookIcon: collisions
---

# Collisions

The TIA detects collisions **in hardware**. As the beam draws each scanline, the chip notices whenever two objects are lit at the same pixel and latches a bit. You never compute overlaps yourself — and given how little of the [76-cycle line]({{< relref "/docs/6502-basics/cycles-and-timing" >}}) you'd have to spare for it, that's a gift. Your part is just to *read* the latches after the frame and *clear* them before the next.

That free, pixel-perfect detection is what turns the [playfield]({{< relref "/docs/playfield" >}}) and the [movable objects]({{< relref "/docs/sprites" >}}) into a *game*: the ball meets the wall, the missile meets the tank, the player meets the maze.

- **[The Collision Registers]({{< relref "the-collision-registers" >}})** — the six objects, the 15 pairs, and the eight registers that report them (with a lookup matrix).
- **[Reading & Clearing]({{< relref "reading-collisions" >}})** — the `BIT`/N–V idiom for testing a latch, and the once-a-frame `CXCLR` discipline.

> Collisions accumulate until cleared. Forgetting the `CXCLR` write each frame is a classic bug: a single touch appears to last forever.
