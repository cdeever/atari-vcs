---
title: "Pong (a minimal teardown)"
weight: 5
---

# Pong (a minimal teardown)

Where [Combat]({{< relref "combat" >}}) and [Pitfall!]({{< relref "pitfall" >}}) are feats of *compression* — huge games squeezed into tiny ROMs — this Pong is the opposite lesson: the **irreducible minimum**, the smallest thing that is still a complete VCS game. It's a clean, modern implementation by **Lucas Avanço**, built on Kirk Israel's "thin red line" tutorial and the Stella Programmer's Guide — not Atari's 1977 cartridge, but all the better for reading, because there's nothing in it that isn't essential.

Strip a 2600 game down to the studs and this is what's left. It's the best possible thing to read right after the basics.

## The shape of the program

Pong's structure isn't *like* the frame loop this book teaches — it **is** that loop, with no embellishment at all:

{{< graphviz >}}
digraph pong {
  rankdir=TB;
  bgcolor="transparent";
  node [shape=box, style="filled,rounded", fontsize=10, color="#808080", penwidth=1.1];
  edge [color="#808080", penwidth=1.2];

  start    [label="Start — init", fillcolor="#e2e2e2"];
  vsync    [label="VSYNC — 3 lines", fillcolor="#f6c6cc"];
  vblank   [label="VBLANK — arm timer (TIM64T)\nmove ball, read paddles,\ncheck collisions & bounce", fillcolor="#cfe0f5"];
  kernel   [label="KERNEL — ScanLoop, 191 lines\ndraw paddles (GRP0/GRP1) + ball (ENABL)\nby comparing each line to object Y", fillcolor="#d2efd2"];
  overscan [label="Overscan — 30 lines (OverScanWait)", fillcolor="#f6c6cc"];

  start -> vsync -> vblank -> kernel -> overscan;
  overscan -> vsync [label="  next frame", constraint=false, fontsize=9, fontcolor="#808080"];
}
{{< /graphviz >}}

Three VSYNC lines, a VBLANK where the game thinks, a kernel where it draws, thirty overscan lines, repeat. That's the whole architecture — exactly the [frame structure]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}) chapter, running a real game. If you understand this diagram, you understand the spine of *every* game in the analysis section; the others just hang more on it.

## Two paddles and a ball

Pong is the game the TIA's [movable objects]({{< relref "/docs/sprites" >}}) were practically named for. The two **paddles are the two players** — drawn from `GRP0` and `GRP1`, each as a solid bar about 30 scanlines tall, their vertical positions in `Player0Pos` / `Player1Pos`. The **ball is the ball** — the TIA's [ball object]({{< relref "/docs/sprites/missiles-and-ball" >}}) (`ENABL`), nudged horizontally with `HMBL`. No multiplexing, no flicker, no copies: three objects, used for exactly what they're for.

## The kernel: draw by comparing

`ScanLoop` is a [single-line kernel]({{< relref "/docs/kernel-techniques/multi-line-kernels" >}}) — the simplest kind — running once per visible scanline for all 191 of them. Each line, it asks the only question a kernel ever asks: *is any object lit here?* It compares the current scanline to each paddle's vertical range to decide whether to draw its `GRP`, and to the ball's range to decide whether to enable it. That's the whole trick of putting a sprite at a vertical position — there is no Y register, only [which scanlines you choose to draw on]({{< relref "/docs/sprites/drawing-a-player" >}}), and this is that idea in its barest form.

## Ball physics in a handful of bytes

The entire ball simulation lives in a few [zero-page]({{< relref "/docs/prerequisites/memory-mapped" >}}) bytes:

- **Vertical:** `YPosBall` is the height; `DirectionBall` (up or down) flips when the ball reaches the `Top` or `Down` boundary — a bounce off the ceiling and floor.
- **Horizontal:** `BallLeftRight` holds the [fine-motion]({{< relref "/docs/sprites/horizontal-positioning" >}}) nibble fed to `HMBL` (`$10` one way, `$F0` the other), and it's flipped when the ball strikes a paddle.
- **Scoring the miss:** the [collision latches]({{< relref "/docs/collisions" >}}) do the refereeing — `CXP0FB` / `CXP1FB` for ball-meets-paddle (bounce), and `CXBLPF` for ball-meets-back-wall (a point against the player who missed).

A bouncing ball, in maybe a dozen bytes of state and three collision checks. This is where the [Collisions]({{< relref "/docs/collisions" >}}) chapter stops being abstract.

## No score, just lives

There's no scoreboard at all — instead each player has a stock of **lives** (`LifePlayer0` / `LifePlayer1`, starting at 30), and missing the ball costs one; reach zero and it's `EndGame`. It's a small reminder that a *score* is a design decision, not a hardware requirement — the very thought experiment the [Scoreboard]({{< relref "/docs/playfield/scoreboard" >}}) page opens with ("imagine Pong without a scoreboard"), here taken literally.

## Why read it

Pong is the floor. Two players, one ball, four screen regions, three collision latches — and a complete, playable game. Read it first to see the skeleton bare, or read it after Combat and Pitfall as a palate cleanser that reminds you what all that ingenuity is built *on*. Everything bigger is this loop, elaborated.

> **Read the source.** Lucas Avanço's Pong (after Kirk Israel's "thin red line"), on GitHub at [johnidm/asm-atari-2600 → `pong.asm`](https://github.com/johnidm/asm-atari-2600/blob/master/pong.asm).
