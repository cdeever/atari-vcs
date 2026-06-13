---
title: "Breakout (1978)"
weight: 80
---

# Breakout (1978)

*Breakout* is where the VCS came from. The 1976 arcade machine was conceived by **Nolan Bushnell** and **Steve Bristow** as a one-player *Pong* with a wall to chip away at, and the prototype was built — famously, over a few sleepless nights — by **Steve Wozniak**, with **Steve Jobs** handling the deal with Atari (and, the story goes, the bonus). The 1978 cartridge brought it home. It is *Pong*'s child: a ball, a paddle, and a wall of bricks.

And where [Space Invaders]({{< relref "spaceinvaders" >}}) is the game that does *everything* with the two player sprites, Breakout is its mirror image — the game that does almost everything **without them.**

## The shape of the program

Nearly the whole screen is one layer — the [playfield]({{< relref "/docs/playfield" >}}):

{{< graphviz >}}
digraph breakout {
  rankdir=TB;
  bgcolor="transparent";
  node [shape=box, style="filled,rounded", fontsize=10, color="#808080", penwidth=1.1];
  edge [color="#808080", penwidth=1.2];

  init  [label="Power-up — build the brick wall as a\nbitmap in RAM ($80–$A3)", fillcolor="#e2e2e2"];
  logic [label="VBLANK — read the paddle pot (INPT0); move the\npaddle and ball blocks in the RAM bitmap; test the\nball against the bricks, clear the ones it hits; score", fillcolor="#cfe0f5"];
  kernel[label="Kernel — paint the whole field from RAM as an\nASYMMETRIC PLAYFIELD: bricks + ball + paddle + walls,\nrewriting PF0/PF1/PF2 several times per line, with\nCOLUPF per band for the colored rows", fillcolor="#f6e0c6"];
  score [label="Score — drawn with the two players (P0/P1),\nthe only sprites in the game", fillcolor="#d2efd2"];
  over  [label="Overscan", fillcolor="#f6c6cc"];

  init -> logic -> kernel -> score -> over;
  over -> logic [label="  next frame", constraint=false, fontsize=9, fontcolor="#808080"];
}
{{< /graphviz >}}

## Everything is the playfield

Here is the thing you discover the moment you read the disassembly: **Breakout never positions a sprite.** Search the entire 2 KB ROM and there is not a single `RESP0`, `RESM0`, `RESBL`, or any `HMP`/`HMM`/`HMBL` motion write — just one lone `HMOVE`. On a machine whose whole sprite system is built on those strobes, that's astonishing. It means the bricks, the ball, the paddle, *and* the side walls cannot be sprites. They're all the **playfield**.

The display kernel makes it concrete. Each band, it pulls the wall straight out of RAM and rewrites the playfield registers several times across the line — an [asymmetric playfield]({{< relref "/docs/playfield/asymmetric" >}}), so the left and right halves differ — while changing `COLUPF` per band to color the rows:

```asm
LF040: LDA    $C0,X      ; this row's color
       STA    COLUPF     ; → the red / orange / green / yellow brick rows
       LDA    $9E,X / STA PF0
       LDA    $98,X / STA PF1
       LDA    $92,X / STA PF2     ; left half of the wall, from RAM
       LDA    $8C,X / STA PF0
       LDA    $86,X / STA PF1
       LDA    $80,X / STA PF2     ; …rewritten mid-line for the right half
```

The whole wall is a **bitmap held in RAM** (the arrays at `$80–$A3`). That's the same insight as the [Space Invaders shields]({{< relref "spaceinvaders" >}}) and [Cosmic Ark]({{< relref "cosmicark" >}})'s tiles: a playfield sourced from mutable memory is a *destructible* playfield. Knock out a brick and the game clears its bits in the array; next frame the kernel simply paints the gap. The chunky, low-res playfield "pixel" — four color-clocks wide — is not a limitation here, it's the **art style**: a brick *is* exactly one fat playfield block, and the blocky ball and stubby paddle are just a few more bits set into the same bitmap, moved each frame by editing RAM.

This is the cleanest answer in the whole section to "what was the playfield *for*?" Combat used it for walls, Pitfall for a skyline, Space Invaders for shields — but Breakout builds the *entire game* out of it, and looks completely natural doing so. The wall, the ball, the paddle, the borders: one bitmap, repainted 60 times a second.

## The only two sprites: the score

So what are the TIA's player objects doing? Exactly one job — the **score**. At the top of the frame the kernel loads the digit graphics into `GRP0`/`GRP1` with their own colors (`COLUP0`/`COLUP1`) and leaves them at their power-on position (which is why there's no `RESP0` to be found — the score never needs to move). Two sprites, two digits, and not a pixel more. Everything that *plays* is below them, in the playfield.

It's worth holding the two games side by side:

| | drives the gameplay | uses sprites for |
|---|---|---|
| **Space Invaders** | the two **players** (multiplexed + `NUSIZ` copies) | *everything* — aliens, ship, mothership |
| **Breakout** | the **playfield** (RAM bitmap, asymmetric kernel) | *only the score* |

Same five-object chip, opposite ends of it.

## The paddle, by knob

Breakout is one of the headline games for the **[paddle controller]({{< relref "/docs/input/paddles" >}})** — the analog knob, not the joystick. The program reads it the standard way, through the `INPT0` dump line (here via its `$30` mirror, `INPT0|$30`):

```asm
       LDA    INPT0|$30,X    ; sample the paddle pot
       BMI    LF0C5
       STY    $C6            ; latch the paddle position
```

The pot's charge time is converted into a position that the game stores in RAM and then renders as the paddle block in the playfield bitmap — so turning the knob slides a clump of playfield bits left and right along the bottom. The ball's bounce angle then depends on *where* on that block it lands, which is the entire game of Breakout in one sentence.

## Why read it

Read Breakout for the surprise of opening a famous action game and finding **no sprites running the show at all** — a complete game of ball, paddle, and a hundred bricks built almost entirely from the playfield, with the two players spared for the scoreboard. It's the perfect bookend to [Space Invaders]({{< relref "spaceinvaders" >}}): hold them together and you can see the TIA's two halves — the movable objects and the playfield — each pushed to carry a whole game on its own. And read it because it's *Breakout*: the Woz prototype that became the arcade hit that became the template every block-and-ball game still copies.

> **Read the source.** This teardown is drawn from a [DiStella]({{< relref "/docs/getting-started/toolchain" >}}) disassembly of the *Breakout* cartridge (© 1978 Atari). The "everything is playfield" structure — no sprite-positioning strobes, a RAM-backed asymmetric kernel, the score on the two players — is read directly from the code. The ball-versus-brick collision bookkeeping (the ROM also pokes the hardware collision latches, read through their `$30` mirrors) is subtler than a teardown can fully trace, and rewards closer study.
