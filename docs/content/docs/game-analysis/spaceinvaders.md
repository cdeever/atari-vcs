---
title: "Space Invaders (1980)"
weight: 50
---

# Space Invaders (1980)

*Space Invaders* — **Rick Maurer**, Atari — was the first officially **licensed arcade game** to land on a home console, and it changed everything. It was the 2600's **killer app**: the cartridge people bought the *console* in order to play, widely credited with roughly quadrupling hardware sales in 1980 and turning the VCS from a curiosity into a phenomenon. Maurer's port is also a quiet masterclass in TIA economy — it fills the screen with marching aliens using astonishingly little hardware. The disassembly here was produced from the cartridge with [DiStella]({{< relref "/docs/getting-started/toolchain" >}}).

The headline trick isn't procedural worlds or scrolling terrain — it's **sprite arithmetic**: a whole formation of invaders conjured from just two player objects.

## The shape of the program

The frame loop is the ordinary one this book teaches. The remarkable part is the **kernel**, where two sprites become a battlefield:

{{< graphviz >}}
digraph spaceinv {
  rankdir=TB;
  bgcolor="transparent";
  node [shape=box, style="filled,rounded", fontsize=10, color="#808080", penwidth=1.1];
  edge [color="#808080", penwidth=1.2];

  start    [label="START — clear RAM,\ninit the invader formation & lives", fillcolor="#e2e2e2"];
  vsync    [label="VSYNC (3 lines) + arm VBLANK timer", fillcolor="#f6c6cc"];
  logic    [label="VBLANK — march the formation (BCD position),\nmove cannon / shots / bombs / mothership;\ncollisions, score; quicker as invaders die", fillcolor="#cfe0f5"];
  kernel   [label="KERNEL — P0 & P1 each TRIPLED via NUSIZ = 6\ninvaders per row, multiplexed down the formation\n(+ players reused for mothership & cannon);\nshields = playfield, shots = ball/missiles", fillcolor="#f6e0c6"];
  overscan [label="Overscan (timer)", fillcolor="#f6c6cc"];

  start -> vsync -> logic -> kernel -> overscan;
  overscan -> vsync [label="  next frame", constraint=false, fontsize=9, fontcolor="#808080"];
}
{{< /graphviz >}}

## 36 invaders from two sprites

A row in the arcade game is **six invaders** across. The 2600 has *two* player objects. So how does a single scanline band show six aliens?

The answer is [`NUSIZ`]({{< relref "/docs/sprites/size-and-copies" >}}). Maurer sets both `NUSIZ0` and `NUSIZ1` to `$05` — the **"three copies, medium spacing"** mode — so each player draws **three** evenly-spaced images instead of one. Three from P0 plus three from P1 makes **six invaders per row from two objects**, and it costs only the two register writes:

```
LF1F2: STA    NUSIZ1   ; $05 = three copies, medium → 3 invaders
LF1FA: STA    NUSIZ0   ; $05 = three copies, medium → 3 more
```

That handles one row *across*. To stack the rows *down* the screen, the kernel does [sprite multiplexing]({{< relref "/docs/advanced/sprite-multiplexing" >}}): as the beam descends, it reloads `GRP0`/`GRP1` from a fresh pair of [graphics pointers]({{< relref "/docs/kernel-techniques/front-loading-and-tables" >}}) for each band, so the same two players become a different rank of aliens every few scanlines. Six across × the rows down = the full formation — **36 invaders out of two sprites.** The two players are then reused yet again, in their own bands, for the **mothership** gliding across the top and your **cannon** at the bottom.

It is the single best demonstration in this book of [the sprite chapter's]({{< relref "/docs/sprites" >}}) two big multipliers stacked together: **copies** ([horizontal]({{< relref "/docs/sprites/size-and-copies" >}})) and **multiplexing** ([vertical]({{< relref "/docs/advanced/sprite-multiplexing" >}})).

## The whole cast, with two left over

With the players spoken for, the rest of the screen is built from the [remaining TIA objects]({{< relref "/docs/sprites/missiles-and-ball" >}}):

| Object | Role |
|--------|------|
| **Player 0 + Player 1** | the **invaders** — each tripled (`NUSIZ=$05`) and multiplexed down the rows; reused for the **mothership** and your **cannon** |
| **Ball / Missiles** | the **shots** — your laser climbing, the invaders' bombs falling (`ENABL`/`RESBL`/`HMBL` reposition them each frame) |
| **Playfield** | the **shields** — the destructible bunkers you hide behind, plus the ground line and score area (`PF0`/`PF1`/`PF2`) |

Every pixel on screen traces back to those few registers. Nothing is wasted.

## The march, counted in decimal

The formation's horizontal position lives in a **[BCD]({{< relref "/docs/prerequisites/numbers" >}}) accumulator** updated during [VBLANK]({{< relref "/docs/tia-racing-the-beam" >}}). Each step adds a small velocity to the position with the CPU in decimal mode:

```
       SED
LF4E1: LDA    $E8,X     ; formation position (low)
       CLC
       ADC    $F6,X     ; + velocity
       STA    $E8,X
       ...
       CLD
```

When the column reaches a screen edge, the velocity flips sign and the whole formation **drops a row** — the relentless left-right-down sweep that defines the game. Keeping the position in BCD makes the on-screen movement line up cleanly with the decimal bookkeeping the rest of the game uses (lives, score).

## Faster as they fall

The game's signature tension is that the aliens **speed up as you destroy them**. In the original arcade machine this was a famous *accident* — fewer invaders meant less for the draw loop to do, so the survivors were updated more often and appeared to accelerate. Maurer preserves the feel on the 2600: as the ranks thin, the formation's march quickens, so the last lonely invader skitters across the screen at a panic-inducing clip. It's [emergent difficulty]({{< relref "/docs/kernel-techniques/counting-cycles" >}}) — a curve that nobody had to design, falling straight out of "draw what's left."

## One cartridge, 112 games

Flip the **[Game Select switch]({{< relref "/docs/input/buttons-and-switches" >}})** and Space Invaders becomes something else. The cartridge holds **112 variations** off a single 4 KB ROM — moving shields, *invisible* invaders, zig-zagging bombs, fast bombs, and a full slate of **two-player** modes. The variation number simply gates a handful of feature flags that the one shared kernel reads while it runs; the display loop doesn't fork, it just consults a few bits. It's a lesson in **reuse**: one engine, a table of toggles, a hundred-plus distinct games.

## Why read it

Pitfall! and River Raid impress by *generating* a world. Space Invaders impresses by doing the opposite — taking the TIA's tiniest cast and making it look like a hundred things at once. Read it for the **`NUSIZ` copies + multiplexing** combination that turns two sprites into a 36-alien wall (there is no cleaner example), for the **BCD march** and its accidental **speed-up**, and for the **112-in-one** trick that wrings a hundred games from one kernel. And read it for what it *was*: the cartridge that sold the machine this whole book is about.

> **Read the source.** This teardown is drawn from a [DiStella]({{< relref "/docs/getting-started/toolchain" >}}) disassembly of the *Space Invaders* cartridge (Rick Maurer's game, © 1980 Atari). Disassemble your own copy with `distella -a -s` to follow along — see the [Toolchain]({{< relref "/docs/getting-started/toolchain" >}}) chapter.
