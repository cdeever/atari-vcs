---
title: "Sprites: Players & Missiles"
weight: 50
bookCollapseSection: true
---

# Sprites: Players & Missiles

Beyond the playfield, the TIA gives you five movable objects: two **players** (8-bit bitmap sprites), two **missiles**, and one **ball**. These are what you move around the screen — the tank, the spaceship, the bullet. Unlike modern sprites they have no X coordinate register; horizontal position is set by *timing* a `RESP0`/`RESP1` write to the moment the beam reaches the desired column, then nudging by fractions of a pixel with the `HMxx` fine-motion registers and a `HMOVE`.

This chapter covers loading player bitmaps a scanline at a time, the strobe-and-fine-tune positioning technique, `NUSIZ` for size and copies, vertical delay (`VDEL`) for smoother motion, and the cycle-counting discipline that horizontal positioning demands.

> Horizontal positioning is the first place beginners hit the cycle wall: the column a player lands in depends on the exact cycle the `RESP0` store executes, so the positioning routine itself must be cycle-counted.
