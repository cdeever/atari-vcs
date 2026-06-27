---
title: "Size & Copies (NUSIZ)"
weight: 30
---

# Size & Copies (NUSIZ)

There are only [two players]({{< relref "drawing-a-player" >}}), but a single register stretches what they can do. `NUSIZ0` and `NUSIZ1` (one per player) set a player's **width** *and* let the TIA stamp out **multiple copies** of it across the line — and the same register sizes that player's missile. It's the cheapest way to get more than two objects on screen at once.

## Player width and copies

The low three bits of `NUSIZ` choose one of eight modes:

| Value | Player drawn as |
|-------|-----------------|
| 0 | one copy, normal width (8 px) |
| 1 | two copies, close together |
| 2 | two copies, medium gap |
| 3 | three copies, close |
| 4 | two copies, wide gap |
| 5 | **double width** (one copy, 16 px) |
| 6 | three copies, medium gap |
| 7 | **quad width** (one copy, 32 px) |

Two ideas in one register: *scaling* (modes 5 and 7 stretch the same 8-bit bitmap to 2× or 4×) and *replication* (the copy modes draw the identical bitmap two or three times across the scanline, from one `GRP0` write).

The copies are the trick behind rows of identical objects — the marching aliens of *Space Invaders*, a line of bricks, a set of pips — all from a single player you'd otherwise be able to show only once. From a *single* `GRP0` write the copies are identical — each shares the player's graphics, color, and any [reflection]({{< relref "drawing-a-player" >}}). But because the copies sit at different points along the line, the beam reaches them at different moments, so rewriting `GRP0` in the cycle gap *between* copies gives each one its own bitmap (or a blank). That mid-line trick is how [Space Invaders]({{< relref "/docs/game-analysis/spaceinvaders" >}}) makes its six-across aliens differ, animate, and wink out individually when shot.

## Missile width

The same register sizes the matching missile through its high bits: missile *m* can be **1, 2, 4, or 8 color clocks** wide. A 1-clock missile is a thin bullet; an 8-clock one is a fat block. (More on missiles in [Missiles & the Ball]({{< relref "missiles-and-ball" >}}).)

## In Practice

- **Copies are the poor player's sprite multiplier.** Need three evenly-spaced identical shapes on a line? One player in a 3-copy mode beats juggling sprites. Their *graphics* can still differ via mid-line `GRP0` rewrites (above), but their **spacing and motion can't** — copies are locked to the fixed `NUSIZ` gaps and move as one. The instant the objects need independent positions or motion, you're back to two players plus [multiplexing]({{< relref "/docs/sprites/sprite-multiplexing" >}}).
- **Quad-width players make big, coarse shapes cheap.** A 4× player is 32 pixels wide from one bitmap — good for banners, title text built from [player-as-digit graphics]({{< relref "/docs/playfield/scoreboard" >}}), or a large boss, at the cost of chunky pixels.
- **`NUSIZ` changes can be timed mid-line**, like any register — advanced kernels switch sizes within a frame, though the retiming has its own quirks best left until you're comfortable with steady-state sprites.
