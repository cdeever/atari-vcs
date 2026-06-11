---
title: "Missiles & the Ball"
weight: 40
---

# Missiles & the Ball

The other three movable objects — two **missiles** and one **ball** — are the TIA's single-bit shapes. They have no bitmap; each is just a solid colored rectangle whose only graphic choice is its [width]({{< relref "size-and-copies" >}}). That makes them cheap to position and toggle, which is exactly what you want for bullets, balls, and small markers.

## The missiles

Missile 0 and missile 1 are turned on by `ENAM0` / `ENAM1` and positioned with the same [strobe-and-`HMOVE`]({{< relref "horizontal-positioning" >}}) dance as the players (`RESM0`/`RESM1`, `HMM0`/`HMM1`). The catch — and the convenience — is **color**: a missile has none of its own. **M0 always draws in player 0's color (`COLUP0`), M1 in player 1's.** A missile is, by design, *this player's* projectile.

One special register ties them together: `RESMP0` / `RESMP1` — "reset missile to player." While its bit is set, the missile is hidden and locked to the **center of its player**; clear it, and the missile is released exactly there. That's the standard way to **fire a shot from a character's position**: lock the missile to the player, then unlock it the frame the trigger is pulled, and the bullet starts dead-center on the sprite.

## The ball

The ball (`ENABL` to enable, `RESBL`/`HMBL` to position) works the same way, with one difference in where it borrows its color: **the ball uses the *playfield* color, `COLUPF`.** That's why the ball in *Pong*, *Combat*, and *Breakout* matches the walls — and why the ball is so often repurposed as a piece of *playfield*: a center divider, a moving wall segment, a status pip. It's a fifth colored block you can put anywhere.

Its width is set by `CTRLPF` (the same [playfield control register]({{< relref "/docs/playfield/symmetry" >}})) rather than `NUSIZ`, in the same 1/2/4/8-clock steps as a missile. `VDELBL` gives it the same one-line [vertical delay]({{< relref "drawing-a-player" >}}) the players have.

## In Practice

- **Borrowed colors are a feature, not a limit.** Because missiles inherit player colors and the ball inherits the playfield color, you rarely have to think about coloring them — and you can lean on it: a missile *reads* as belonging to its player, a ball *reads* as part of the wall.
- **The ball is a free movable object.** Out of bullets to fire but need one more thing that moves? The ball is a general-purpose colored rectangle — many games use it for something that has nothing to do with a "ball."
- **They collide too.** Missile-to-player, ball-to-playfield, missile-to-missile — every overlap is latched in hardware, which is what turns "the bullet reached the tank" into a game event. That's the [Collisions]({{< relref "/docs/collisions" >}}) chapter.
