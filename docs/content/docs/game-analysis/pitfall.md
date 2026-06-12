---
title: "Pitfall! (1982)"
weight: 20
---

# Pitfall! (1982)

*Pitfall!* — **David Crane**, Activision, 1982 — sent Pitfall Harry running through a **255-room jungle** of logs, vines, crocodiles, scorpions, and quicksand, and became one of the best-selling games on the system. It did all that on a **4 KB** cartridge, which raises an obvious question: where do 255 rooms *fit*? The answer is the most famous idea in 2600 programming, and it's the reason this game is worth taking apart. (The disassembly here is Thomas Jentzsch's.)

## The shape of the program

Underneath, Pitfall runs the same skeleton as every game in this book — a one-time `InitGame`, then a frame loop that sets up, draws, and updates, forever:

{{< graphviz >}}
digraph pitfall {
  rankdir=TB;
  bgcolor="transparent";
  node [shape=box, style="filled,rounded", fontsize=10, color="#808080", penwidth=1.1];
  edge [color="#808080", penwidth=1.2];

  init   [label="InitGame — clear RAM, set up", fillcolor="#e2e2e2"];
  decode [label="Decode THIS ROOM from the\nLFSR seed (random): object /\nscene / tree type, wall & pit positions", fillcolor="#f6e0c6"];
  pos    [label="Position objects,\ncompute X-coords (CalcPosX)", fillcolor="#cfe0f5"];
  kernel [label="KERNEL — nine stacked sub-kernels\ntrees -> vine -> Harry ->\nground/pits -> ladder -> underground", fillcolor="#d2efd2"];
  digits [label="ShowDigits — score +\ncountdown timer (BCD)", fillcolor="#cfe0f5"];
  harry  [label="ProcessHarry — run / jump /\nclimb / swing", fillcolor="#cfe0f5"];
  objects[label="ProcessObjects —\nhazards & treasures", fillcolor="#cfe0f5"];
  logic  [label="Game logic — collisions, room\ntransition (step the LFSR), timer", fillcolor="#cfe0f5"];

  init -> decode -> pos -> kernel -> digits -> harry -> objects -> logic;
  logic -> decode [label="  next frame", constraint=false, fontsize=9, fontcolor="#808080"];
}
{{< /graphviz >}}

The tell is the very first step inside the loop. Where [Combat]({{< relref "combat" >}}) reads its current game out of a table, Pitfall **computes its current room from a single byte** before it can draw anything. That byte is the whole jungle.

## Rooms from one byte: the LFSR

Pitfall keeps a single variable, `random`, and **that variable *is* the room.** It's run through a **linear-feedback shift register** (a "polynomial counter"): shift the byte right, and feed a fresh top bit in as the XOR of a few existing bits —

```
random' = random >> 1  |  (bit4 ^ bit5 ^ bit6 ^ bit0) * $80
```

Run that step repeatedly and the byte walks through **255 distinct values before repeating** — never hitting zero, which is why it's 255 rooms and not 256. The magic is that it's **reversible**: walking right runs the LFSR forward, walking left runs it backward, so the jungle is perfectly consistent in both directions even though no map of it exists anywhere.

And each room's *contents* are just the [bits]({{< relref "/docs/prerequisites/bits" >}}) of that byte, unpacked:

- **bits 0–2** → `objectType` (the log, fire, cobra, or treasure on the ground)
- **bits 3–5** → `sceneType` (the arrangement of pits, holes, and crocodiles)
- **bits 6–7** → `treePat` (which canopy pattern)
- **bit 7** → which side the underground wall sits on

So a complete room — its hazard, its layout, its trees, its wall — costs **one byte you don't even store**, generated on the fly. Instead of 255 room maps eating the cartridge, Pitfall spends a shift register and a few [lookup tables]({{< relref "/docs/kernel-techniques/front-loading-and-tables" >}}), and hands the entire 4 KB back to the *game*. (Crane reportedly tuned the seed by hand until the generated sequence played well.) It is the definitive answer to "how do you fit a huge world on a tiny cart": **you don't store the world — you compute it.**

## A kernel in nine acts

Drawing a Pitfall screen is not one kernel but **nine**, stacked down the display. The roughly-900-byte routine hands each vertical band to its own bespoke, cycle-counted loop: the tree canopy and branches, the swinging vine, Pitfall Harry, the ground with its pits and holes, the ladder dropping into the earth, and the underground tunnel with its scorpion. Each band shows different objects, so each gets different code.

This is the **region-by-region display kernel** — the idea behind [mixing bands in the playfield]({{< relref "/docs/playfield/asymmetric" >}}) and [multi-line kernels]({{< relref "/docs/kernel-techniques/multi-line-kernels" >}}) — scaled up about as far as it goes on a 2600. Reading those nine loops back to back is a graduate course in [kernel construction]({{< relref "/docs/kernel-techniques" >}}).

## The score and the clock

`ShowDigits` draws two [BCD]({{< relref "/docs/prerequisites/numbers" >}}) readouts: the score and a **counting-down timer**. That clock — twenty minutes to find all the treasure — is the whole game's tension, and it's the same digit-drawing and [scorekeeping]({{< relref "/docs/playfield/scoreboard" >}}) technique Combat uses, pointed at a number that falls instead of rises.

## Harry's moves

`ProcessHarry` is the player physics — running, jumping, climbing ladders, and swinging on the vine — while `ProcessObjects` animates the world's hazards and treasures (the rolling logs, the fire, the cobra, the crocodiles whose mouths you leap across). The [collision latches]({{< relref "/docs/collisions" >}}) decide each frame whether Harry grabbed a treasure, cleared a log, or fell.

## Why read it

Combat and Pitfall answer the same question — *how do you fit a big game in a tiny ROM?* — two different ways: Combat with a **table** of 27 variations, Pitfall with an **algorithm** that conjures 255 rooms from a byte. The LFSR jungle is one of the most elegant ideas the medium produced, and the nine-act kernel shows the region-by-region approach pushed to its limit. If Combat is the book's *structure* made real, Pitfall is its *ingenuity*.

> **Read the source.** This analysis follows Thomas Jentzsch's Pitfall! disassembly (David Crane's game, © 1982 Activision), on GitHub at [johnidm/asm-atari-2600 → `pitfall.asm`](https://github.com/johnidm/asm-atari-2600/blob/master/pitfall.asm).
