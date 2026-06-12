---
title: "River Raid (1982)"
weight: 40
---

# River Raid (1982)

*River Raid* — **Carol Shaw**, Activision — flies a jet up a winding river that never ends: shoot the ships, helicopters, and jets, blow the bridges, and watch the fuel gauge, because the banks keep narrowing. It was one of the best-selling and most acclaimed games of the era, and a landmark for another reason — Shaw was among the first women to design and program a commercial video game, and River Raid is her masterpiece. The disassembly here is Thomas Jentzsch's.

Its defining trick belongs to the same family as [Pitfall!]({{< relref "pitfall" >}}) — a world that's *generated*, not stored — but River Raid applies it to **continuously scrolling** terrain. Where Pitfall is a loop of discrete rooms, River Raid is an open road that paves itself ahead of you.

## The shape of the program

The frame loop is ordinary; the extraordinary step is the one that **builds the next slice of river** as the old slice scrolls off:

{{< graphviz >}}
digraph riverraid {
  rankdir=TB;
  bgcolor="transparent";
  node [shape=box, style="filled,rounded", fontsize=10, color="#808080", penwidth=1.1];
  edge [color="#808080", penwidth=1.2];

  init   [label="GameInit — clear RAM, set up,\nseed the river LFSR", fillcolor="#e2e2e2"];
  input  [label="Read joystick — move jet (P0),\nfire missile (M0)", fillcolor="#cfe0f5"];
  scroll [label="Scroll the river: when a block rolls off,\nGENERATE the next from the 16-bit LFSR\n(banks, island, bridge, fuel, enemies)", fillcolor="#f6e0c6"];
  logic  [label="Update enemies, collisions,\nfuel burn, score", fillcolor="#cfe0f5"];
  kernel [label="DisplayKernel (~160 lines) — riverbanks (PF)\n+ jet (P0) + shot (M0) + enemies (P1, multiplexed)\n+ fuel gauge (BL)", fillcolor="#d2efd2"];
  state  [label="DisplayState — score / fuel / lives bar", fillcolor="#d2efd2"];

  init -> input -> scroll -> logic -> kernel -> state;
  state -> input [label="  next frame", constraint=false, fontsize=9, fontcolor="#808080"];
}
{{< /graphviz >}}

## A river from a shift register

River Raid grows its world a block at a time from a **16-bit linear-feedback shift register** (`randomLo`/`randomHi`, advanced by `NextRandom16`). Each block of river — 32 scanlines tall — pulls everything it needs from that register: the [playfield]({{< relref "/docs/playfield" >}}) pattern that curves the banks, whether an island splits the channel, and which object (a fuel depot, a ship, a helicopter, a house) sits in it. Blocks are grouped into **sections of sixteen**, and the last block of every section is always a **bridge** — the river's checkpoints and score markers.

The clever finish: the seed is **saved per life** (`randomLoSave`/`randomHiSave`), so when you crash and restart, the LFSR replays *the exact same river*. It's reproducible without ever being stored — the whole endless waterway lives in two bytes of state and the math that advances them.

This is [Pitfall's]({{< relref "pitfall" >}}) idea, scaled and reshaped. Two procedural worlds, two shapes:

- **Pitfall** — an 8-bit register, 255 *discrete rooms* you step between; the world is a loop.
- **River Raid** — a 16-bit register feeding a *continuous scroll*, manufacturing fresh terrain forever; the world is a road.

## Scrolling by streaming blocks

The screen holds about **six 32-line blocks** of river at once. A scroll offset (`blockOffset`, plus a fractional accumulator `posYLo`) creeps the view upward each frame; when the offset crosses a block boundary, the oldest block drops off the bottom, the six slots all shift down, and a **brand-new block is generated at the top** from the LFSR. The world streams into existence one block ahead of the player — which is exactly how a 4 KB cartridge serves up a river that runs forever. It's [front-loading]({{< relref "/docs/kernel-techniques/front-loading-and-tables" >}}) at the scale of a whole landscape: always building the next piece just before it's needed.

## A full house of objects

River Raid is the book's cleanest example of *casting* the TIA's hardware — it puts **every** movable object to work, each with one clear job ([the five objects]({{< relref "/docs/sprites" >}})):

| Object | Role |
|--------|------|
| **Player 0** | your **jet** (fixed near the bottom; `REFP0` to bank left and right) |
| **Missile 0** | your **shot**, fired upward |
| **Player 1** | the **enemies** — *one* object [multiplexed]({{< relref "/docs/advanced/sprite-multiplexing" >}}) down the screen to show up to six at once |
| **Ball** | the **fuel-gauge** marker |
| **Playfield** | the **riverbanks** themselves — the curving walls and islands |

The enemy multiplexing is the engine room: parallel lists (`Shape1IdLst`, `XPos1Lst`, `State1Lst`) hold each block's enemy type, coarse position, and a packed byte of [`NUSIZ` size]({{< relref "/docs/sprites/size-and-copies" >}}), [`REFP` reflection]({{< relref "/docs/sprites/drawing-a-player" >}}), and [fine `HM` offset]({{< relref "/docs/sprites/horizontal-positioning" >}}) — so the single P1 object becomes a different enemy in each band as the kernel descends.

## Fuel, and a score that's already drawn

Fuel is a plain **16-bit counter** (`fuelHi`/`fuelLo`) that ticks down every frame and tops back up when you fly over a depot; run dry and the jet falls. The score, though, is a small surprise: it is **not** [BCD]({{< relref "/docs/prerequisites/numbers" >}}). River Raid stores the score as the **pointers into the digit graphics themselves** (`scorePtr…`), bumping them along with a wrap at `MaxOut`. The number is kept in the exact form it will be *drawn*, so [showing it]({{< relref "/docs/playfield/scoreboard" >}}) skips the usual value-to-graphic conversion entirely — a different, sneakier answer to scorekeeping than Combat's tidy BCD.

## Why read it

River Raid takes Pitfall's procedural insight and turns it on its side: a generated world, but **scrolling and endless** rather than a fixed loop of rooms. Read it for three things — the **streaming-block** technique that fits an infinite landscape in 4 KB, the **full-cast** use of every TIA object (the clearest in this book), and a **score kept pre-drawn**. And read it because it's Carol Shaw's: a high-water mark of the 2600 era, by one of the medium's true pioneers.

> **Read the source.** Thomas Jentzsch's River Raid disassembly (Carol Shaw's game, © 1982 Activision), on GitHub at [johnidm/asm-atari-2600 → `riverraid.asm`](https://github.com/johnidm/asm-atari-2600/blob/master/riverraid.asm).
