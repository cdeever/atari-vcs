---
title: "Object Priority"
weight: 50
---

# Object Priority

When two objects cover the same pixel, one of them has to win — and which one shows in front is **object priority**. This is a separate question from [collisions]({{< relref "/docs/collisions" >}}): collision detection only tells you *that* two objects overlapped, never which was drawn on top. Priority is what decides the picture.

## The default order

The TIA ranks the six things it can draw in a fixed order. Highest priority is drawn in front:

| Priority | Objects |
|----------|---------|
| 1 (front) | `P0`, `M0` |
| 2 | `P1`, `M1` |
| 3 | `BL`, `PF` |
| 4 (back) | background |

Two pairings fall straight out of the [missile and ball color-borrowing]({{< relref "missiles-and-ball" >}}): a **missile shares its player's priority**, and the **ball shares the playfield's**. So missile 0 is always exactly as "in front" as player 0, and the ball sits at the same level as the walls it's usually colored like.

The practical upshot of the default order: **players and missiles pass in front of the playfield.** A sprite walking across a wall is drawn over it.

## Putting the playfield in front (`CTRLPF` bit 2)

Set **bit 2 (D2) of `CTRLPF`** and the playfield and ball jump ahead of the players:

| Priority | Objects |
|----------|---------|
| 1 (front) | `PF`, `BL` |
| 2 | `P0`, `M0` |
| 3 | `P1`, `M1` |
| 4 (back) | background |

Now a sprite slides *behind* the playfield. That's how you get a character disappearing into a tunnel, walking behind a pillar or bridge, or threading a maze whose walls are drawn over it — the effect in *Pitfall!*'s underground and many maze games.

> Note there's no per-object switch: priority is a single global ordering, flipped as a whole by D2. Layering one specific sprite behind the walls while another stays in front means changing D2 mid-frame, on the scanlines where you want the other rule.

## `CTRLPF` at a glance

Priority is one of several controls packed into the single `CTRLPF` register. The whole register, and where each part is covered:

| Bit | Field | Covered in |
|-----|-------|------------|
| D0 | playfield reflect / repeat | [Symmetry]({{< relref "/docs/playfield/symmetry" >}}) |
| D1 | score mode (color halves in player colors) | [Building a Scoreboard]({{< relref "/docs/playfield/scoreboard" >}}) |
| D2 | playfield/ball priority (this page) | here |
| D4–D5 | ball width (1/2/4/8 clocks) | [Missiles & the Ball]({{< relref "missiles-and-ball" >}}) |

Like any TIA register, `CTRLPF` can be [rewritten between scanlines]({{< relref "/docs/playfield/asymmetric" >}}), so all four of these can differ from one band of the screen to the next.

## In Practice

- **Priority decides the picture; collisions decide the rules.** They're independent — a hit is registered whether or not the object that hit was the one drawn on top. Reach for [Collisions]({{< relref "/docs/collisions" >}}) for the latter.
- **The two players are not equal.** P0 (and M0) always beat P1 (and M1). If two characters can overlap and you care who looks "nearer," assign the front one to player 0.
- **D2 is all-or-nothing per line.** Because it reorders everything at once, getting "this wall in front but that sprite still on top" usually means toggling D2 across scanlines rather than per object.
