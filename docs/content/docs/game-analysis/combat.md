---
title: "Combat (1977)"
weight: 10
---

# Combat (1977)

*Combat* shipped in the box with the original console — for millions of people it *was* the Atari. Written by **Larry Wagner** with hardware help from **Joe DeCuir**, it packs **27 game variations** (tanks, tank-pong, invisible tanks, biplanes, jets) into a **2 KB** ROM. It's also one of the most thoroughly annotated programs in 2600 history: the commented disassembly this teardown follows runs from Harry Dodgson's original through Nick Bensema's notes (1997) to Roger Williams' full overhaul (2002).

It makes a perfect first teardown for one reason: **its structure is exactly the frame loop this book teaches.** Read Combat and you're watching the [TIA & Racing the Beam]({{< relref "/docs/tia-racing-the-beam" >}}) model run a real game.

## The shape of the program

Combat is a single loop. After a one-time `START`, every frame does the same three things — sync, think, draw — then jumps back:

{{< graphviz >}}
digraph combat {
  rankdir=TB;
  bgcolor="transparent";
  node [shape=box, style="filled,rounded", fontsize=10, color="#808080", penwidth=1.1];
  edge [color="#808080", penwidth=1.2];

  start  [label="START — init stack,\nclear RAM, set up", fillcolor="#e2e2e2"];
  vcntrl [label="VCNTRL — 3-line VSYNC,\narm VBLANK timer (TIM64T)", fillcolor="#f6c6cc"];

  subgraph cluster_logic {
    label="VBLANK  —  game logic"; fontsize=11; fontcolor="#808080"; color="#9aa6b2"; style="rounded";
    gsgrck [label="GSGRCK — read console switches\n(select / reset / difficulty)", fillcolor="#cfe0f5"];
    ldstel [label="LDSTEL — load TIA regs\n(sprite size, colors)", fillcolor="#cfe0f5"];
    chksw  [label="CHKSW — read joysticks,\nturn & move the tanks", fillcolor="#cfe0f5"];
    colis  [label="COLIS — read collisions,\napply hits & score", fillcolor="#cfe0f5"];
    stpmpl [label="STPMPL — apply player &\nmissile motion (HMOVE)", fillcolor="#cfe0f5"];
    rot    [label="ROT — build rotated\nsprite buffer (HIRES)", fillcolor="#cfe0f5"];
    scrot  [label="SCROT — BCD score ->\nscore-graphics offsets", fillcolor="#cfe0f5"];
    gsgrck -> ldstel -> chksw -> colis -> stpmpl -> rot -> scrot;
  }

  vout [label="VOUT — THE KERNEL\nscore + playfield + 2 players + 2 missiles", fillcolor="#d2efd2"];

  start -> vcntrl -> gsgrck;
  scrot -> vout;
  vout -> vcntrl [label="  jmp MLOOP\n  (next frame)", constraint=false, fontsize=9, fontcolor="#808080"];
}
{{< /graphviz >}}

`VCNTRL` emits the three [VSYNC lines]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}) and arms the [RIOT timer]({{< relref "/docs/kernel-techniques/waiting-precisely" >}}) (`TIM64T`) to mark the end of vertical blank. Then the seven game-logic routines run *during* that blank — all the thinking happens where the beam isn't drawing. Finally `VOUT`, the kernel, draws the whole screen, and `JMP MLOOP` begins again. The original Atari names for these top-level routines come from DeCuir's own presentation notes; the discipline of **"think in VBLANK, draw in the kernel"** is the book's frame model, named.

## The seven jobs of a frame

Each VBLANK routine is one chapter of this book at work:

| Routine | Does | Chapter |
|---------|------|---------|
| `GSGRCK` | reads Select/Reset/difficulty, debounces, cycles variations | [Buttons & Switches]({{< relref "/docs/input/buttons-and-switches" >}}) |
| `LDSTEL` | sets `NUSIZ` widths and the color registers | [Size & Copies]({{< relref "/docs/sprites/size-and-copies" >}}) |
| `CHKSW` | reads joysticks, turns and accelerates the tanks | [The Joystick]({{< relref "/docs/input/the-joystick" >}}) |
| `COLIS` | reads the collision latches, scores hits, bounces missiles | [Collisions]({{< relref "/docs/collisions" >}}) |
| `STPMPL` | turns headings into `HMOVE` motion for players and missiles | [Horizontal Positioning]({{< relref "/docs/sprites/horizontal-positioning" >}}) |
| `ROT` | builds the rotated sprite buffer for this frame | [Sprites]({{< relref "/docs/sprites" >}}) |
| `SCROT` | converts the BCD score into score-graphics offsets | [Numbers]({{< relref "/docs/prerequisites/numbers" >}}), [Scoreboard]({{< relref "/docs/playfield/scoreboard" >}}) |

`VOUT` then draws a two-line kernel: the score up top (an [asymmetric playfield]({{< relref "/docs/playfield/asymmetric" >}}) showing two different numbers by rewriting `PF1` mid-line), then the reflected maze and both tanks and missiles down the screen.

## Three clever bits worth the price of admission

**27 games from 27 bytes.** Every variation is one byte in the `VARMAP` table — a [bit-packed]({{< relref "/docs/prerequisites/bits" >}}) descriptor of features (tank vs. plane, guided vs. straight missiles, maze type, invisibility, billiard-hit…). At game-select those bits are unpacked into a few flag variables tested all over the code with `BIT`. The entire 27-game matrix is a lookup table and some bit masks.

**The "Combat Stack Trick."** In the kernel, Combat needs to enable or disable each missile on the right scanline, fast. So it points the **stack pointer at the missile registers** (`LDX #$1E` / `TXS`) and uses `PHP` to write them — because a push stores the [processor-status byte]({{< relref "/docs/6502-basics/registers" >}}), and the Z flag sits in *exactly* the bit `ENAM0`/`ENAM1` reads for enable. Set up the zero flag to mean "missile on," `PHP`, and the missile toggles — no load, no store, just a push landing on a hardware register through [address mirroring]({{< relref "/docs/prerequisites/memory-mapped" >}}). It's a famous hack, and a vivid lesson in [counting cycles]({{< relref "/docs/kernel-techniques/counting-cycles" >}}).

**Mirror the artwork, don't store it.** `ROT` only keeps the first 180° of each tank's rotation in ROM. The other half-circle it generates on the fly: set the TIA's [reflect bit]({{< relref "/docs/sprites/drawing-a-player" >}}) (`REFP`) for the horizontal flip, and copy the sprite bytes *last-to-first* for the vertical flip. Half the rotation art, for free — and it interleaves the two players' shapes into even/odd bytes so the [two-line kernel]({{< relref "/docs/kernel-techniques/multi-line-kernels" >}}) can stream both.

## Why Combat is worth reading

Combat is this whole book compressed into 2 KB: a [VBLANK/kernel frame loop]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}), [sprite positioning]({{< relref "/docs/sprites/horizontal-positioning" >}}) and reflection, an [asymmetric score]({{< relref "/docs/playfield/scoreboard" >}}), [hardware collisions]({{< relref "/docs/collisions" >}}), [BCD]({{< relref "/docs/prerequisites/numbers" >}}), [bit-packed]({{< relref "/docs/prerequisites/bits" >}}) game data, [engine and bounce sounds]({{< relref "/docs/sound" >}}), even an elaborate momentum system you barely notice while playing — all cooperating inside one tight loop. You can read every chapter here and still not *feel* how the parts combine until you watch a real game do it. Combat is where they combine.

> **Read the source.** This analysis follows the publicly circulated Combat disassembly — Larry Wagner's game, disassembled by Harry Dodgson, commented by Nick Bensema (1997), and overhauled by Roger Williams (2002). A copy is on GitHub at [johnidm/asm-atari-2600 → `combat.asm`](https://github.com/johnidm/asm-atari-2600/blob/master/combat.asm). It's well worth reading in full once the map above makes its shape legible.
