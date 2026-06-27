---
title: "Horizontal Positioning"
weight: 20
---

# Horizontal Positioning

This is the technique that defines VCS sprite work, and the first place every beginner hits the cycle wall. A player has **no X-coordinate register.** You cannot write "put P0 at column 40." Instead you position it by *timing* — and then nudge it into place.

## Step one: strobe to a coarse position

Writing to `RESP0` is a [strobe]({{< relref "/docs/prerequisites/memory-mapped" >}}): the value doesn't matter, the *act* of writing does. It snaps player 0's horizontal position to **wherever the beam happens to be** at the moment the store executes. So you move a sprite by choosing *when* in the scanline to run `STA RESP0`.

But the resolution is coarse. The CPU ticks once for every [three color clocks]({{< relref "/docs/6502-basics/cycles-and-timing" >}}), and the tightest positioning loop costs five cycles per iteration — so a timed strobe can only land the sprite on roughly **every 15th pixel**. That gets you close, never exact.

{{< graphviz >}}
digraph pos {
  rankdir=LR;
  bgcolor="transparent";
  node [shape=box, style="filled,rounded", fontsize=11, color="#808080", penwidth=1.2];
  edge [color="#808080", penwidth=1.4];
  a [label="desired\ncolumn", fillcolor="#e2e2e2"];
  b [label="RESP0 strobe\n(coarse: lands near\nevery ~15th clock)", fillcolor="#f6c6cc"];
  c [label="HMP0 + HMOVE\n(fine nudge:\n+7 to -8 clocks)", fillcolor="#cfe0f5"];
  d [label="exact pixel", fillcolor="#d2efd2"];
  a -> b -> c -> d;
}
{{< /graphviz >}}

## Step two: fine-tune with HMOVE

The gap between those coarse landing spots is closed by the **fine-motion** registers. `HMP0` holds a signed 4-bit value in its high nibble — a nudge of **+7 to −8 color clocks** — and writing to `HMOVE` applies the fine offsets of *all* the movable objects at once, shifting each by its `HMxx` amount.

So the full move is two steps: strobe `RESP0` to the nearest coarse slot, set `HMP0` to the leftover distance, then `STA HMOVE` to slide the sprite the final few pixels. The classic routine computes both at once — a divide-by-15 of the target column gives the coarse strobe timing, and the remainder becomes the `HMP0` fine value.

{{< vcsanim scene="resp0-hmove" caption="Move *Strobe cycle* and the sprite snaps to the nearest coarse slot; then *HMP0* nudges it the last few clocks (positive = left). Any nudge lights up the HMOVE comb at the left edge." >}}

> **The sign is the single most-flipped detail in VCS programming.** By the usual convention a *positive* `HMxx` value moves the object **left** and a *negative* value moves it **right** (`$70` = +7 left, `$80` = −8 right). It's worth confirming the direction against your `vcs.h` constants and watching it in Stella rather than trusting memory.

## The HMOVE comb, and clearing

`HMOVE` has two things to know about:

- **It must be strobed at the very start of the line** (right after `WSYNC`, during horizontal blank), because it works by briefly extending the blank to retime the objects.
- **That extension blanks the leftmost 8 pixels** of any line where you use it — the "**HMOVE comb**," a row of black notches down the left edge if you move sprites every scanline. Games hide it under a border or simply accept it.

`HMCLR` zeroes all five fine-motion registers in one write — handy at the top of a frame so last frame's offsets don't reapply. (The `HMxx` values persist and reapply on every `HMOVE`, so motion you don't want must be cleared.)

## In Practice

- **Position during blank, draw during the visible lines.** Coarse-positioning loops burn a whole scanline, so they're done in [VBLANK]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}) before the kernel, not in the middle of it.
- **The positioning routine itself must be cycle-counted.** Where the sprite lands depends on the exact cycle `STA RESP0` runs, so this is the textbook example of code whose *timing is its function* — the deep version lives in [Kernel Techniques]({{< relref "/docs/kernel-techniques" >}}).
- **Smooth motion = HMOVE every frame.** To move a sprite by one pixel, you don't re-strobe `RESP0`; you set `HMP0` to ±1 and `HMOVE`. Re-strobing is for jumps; fine motion is for gliding.
