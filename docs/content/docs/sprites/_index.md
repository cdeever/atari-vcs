---
title: "Sprites: Players & Missiles"
weight: 50
bookCollapseSection: true
BookIcon: sprites
---

# Sprites: Players & Missiles

Beyond the [playfield]({{< relref "/docs/playfield" >}}), the TIA gives you **five movable objects** — the things you slide around the screen. Two are true bitmap sprites; three are single-bit colored blocks:

| Object | Graphic | Color | Width set by |
|--------|---------|-------|--------------|
| **Player 0 / Player 1** | 8-bit bitmap (`GRP0`/`GRP1`) | own (`COLUP0`/`COLUP1`) | `NUSIZ` (1×/2×/4× + copies) |
| **Missile 0 / Missile 1** | solid block | borrows its player's | `NUSIZ` (1/2/4/8 clocks) |
| **Ball** | solid block | borrows the playfield's (`COLUPF`) | `CTRLPF` (1/2/4/8 clocks) |

The defining difference from modern sprites: **there is no X-coordinate register.** Horizontal position is set by *timing* a strobe (`RESP0` and friends) to the moment the beam reaches the column you want, then nudging by a few pixels with the `HMxx` fine-motion registers and an `HMOVE`. Vertical position, meanwhile, is just *which scanlines you draw the object on*.

- **[Drawing a Player]({{< relref "drawing-a-player" >}})** — the `GRP0` bitmap, feeding it a row per scanline, vertical positioning, and reflection.
- **[Horizontal Positioning]({{< relref "horizontal-positioning" >}})** — the `RESP0` strobe + `HMOVE` technique, the comb, and why the routine's timing *is* its function.
- **[Size & Copies (NUSIZ)]({{< relref "size-and-copies" >}})** — stretching a player to 2×/4× and stamping out multiple copies from one bitmap.
- **[Missiles & the Ball]({{< relref "missiles-and-ball" >}})** — the single-bit objects, their borrowed colors, and firing a shot from a player.
- **[Object Priority]({{< relref "priority" >}})** — which object is drawn in front when two overlap, and the `CTRLPF` bit that sends sprites behind the playfield.
- **[Sprite Multiplexing]({{< relref "sprite-multiplexing" >}})** — reusing the two players down the screen, and across frames, to show many objects at once; the software answer to the two-sprite limit.

> Horizontal positioning is the first place beginners hit the cycle wall: the column a player lands in depends on the exact cycle the `RESP0` store executes, so the positioning routine itself must be cycle-counted.
