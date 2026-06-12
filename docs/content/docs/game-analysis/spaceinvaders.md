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

## Starting — and restarting

`START` is the only place the *hardware* acts on its own, and it does exactly one thing. On power-up (or whenever the 6507's RESET line is pulled), the CPU's built-in reset sequence reads a 16-bit address from the **reset vector at `$FFFC/$FFFD`** and jumps there — that's the `98 FE` at the very end of the ROM, pointing at `START` (`$FE98`). That is *all* it does: it does **not** clear RAM, set the stack, or zero the TIA. Power-up memory is garbage, so the first job — in code — is to make the machine known:

```asm
START: CLD
       SEI
       LDX    #$00
       TXA
LFE9D: STA    VSYNC,X    ; X wraps $00→$FF: zero all 128 bytes of RAM (and the TIA)
       INX
       BNE    LFE9D
       DEX               ; X = $FF
       TXS               ; stack pointer = $FF
       JSR    LFEB2      ; build the formation, lives, score…
```

The console **"Game Reset" button is a different animal — it is *not* a hardware reset.** It never vectors through `$FFFC` and never interrupts the CPU; it is simply bit D0 of the [`SWCHB`]({{< relref "/docs/input/buttons-and-switches" >}}) register. The running program has to *notice* it. Space Invaders polls the switch in its main loop and, on a press, calls the **same** init routine power-up used:

```asm
LF694: LDA    SWCHB
       AND    #$03        ; Reset = D0, Select = D1 (both active-low)
       CMP    #$02        ; %10 = Reset pressed, Select up
       BNE    LF6A3
       JSR    LFEB2       ; → restart the game
```

So the split is clean: the power-up **jump** is hardware (read two bytes at `$FFFC`, go); **everything after it — clearing memory, *and the Reset button itself* — is software.** Leave out the `SWCHB` poll and the Reset button does nothing at all. (The 6507 also exposes no NMI or IRQ pins, so the other two vectors are dead weight — which is why all three simply point at `$FE98`.)

## 36 invaders from two sprites

A row in the arcade game is **six invaders** across. The 2600 has *two* player objects. So how does a single scanline band show six aliens?

The answer is [`NUSIZ`]({{< relref "/docs/sprites/size-and-copies" >}}). Maurer sets both `NUSIZ0` and `NUSIZ1` to `$05` — the **"three copies, medium spacing"** mode — so each player draws **three** evenly-spaced images instead of one. Three from P0 plus three from P1 makes **six invaders per row from two objects**, and it costs only the two register writes:

```
LF1F2: STA    NUSIZ1   ; $05 = three copies, medium → 3 invaders
LF1FA: STA    NUSIZ0   ; $05 = three copies, medium → 3 more
```

That handles one row *across*. To stack the rows *down* the screen, the kernel does [sprite multiplexing]({{< relref "/docs/advanced/sprite-multiplexing" >}}) — and here is the part worth sitting with. **The TIA has only two player objects in the entire machine.** There is never a frame where 36 invaders exist in hardware. At any single instant the beam is painting **one scanline**, and on that line the chip holds just P0 and P1 (tripled by `NUSIZ`) — six sprites, no more. The rows above are already painted and gone; the rows below haven't happened yet. The formation only *looks* simultaneous because your eye fuses a frame the beam draws one line at a time.

So the same two objects are reused for **every** rank. As the beam falls past each row, the kernel re-arms `GRP0`/`GRP1` with that row's [graphics]({{< relref "/docs/kernel-techniques/front-loading-and-tables" >}}) and marches on. And because the formation is a rigid grid that moves as a block, the two players are positioned horizontally **once per frame** — between rows the kernel swaps only the *pictures*, never the positions. Same two sprites, re-dressed on the fly. Six across × the rows down = the full formation — **36 invaders out of two objects.** Those same two players are then reused *yet again*, in their own bands, for the **mothership** gliding across the top and your **cannon** at the bottom.

There's a second sleight-of-hand inside the row itself. The three copies of a player would normally be *identical* — same graphics, repeated. But the kernel rewrites `GRP0`/`GRP1` **mid-scanline**, six times, landing each write just before the beam reaches the next copy:

```
LDA ($EE),Y → GRP0     ; column 1's picture
LDA ($F0),Y → GRP1     ; column 2's
LDA ($F2),Y → GRP0     ; column 3's
LDA ($F4),Y → GRP1     ; column 4's
LDA ($F6),Y → GRP0     ; column 5's
TXA         → GRP1/GRP0; column 6's
```

So `NUSIZ` sets the *slots* and the just-in-time rewrites give each slot its own *bitmap* — that's how all six aliens in a row can differ (and animate). It is the single best demonstration in this book of [the sprite chapter's]({{< relref "/docs/sprites" >}}) two big multipliers stacked together: **copies** ([horizontal]({{< relref "/docs/sprites/size-and-copies" >}})) and **multiplexing** ([vertical]({{< relref "/docs/advanced/sprite-multiplexing" >}})).

## How a hit invader disappears

When you shoot an invader, it can't simply be *recolored* away: the three copies of a player share **one color register** per scanline, so there's no way to tint just one of them into the background. Instead, the game hides it at the **graphics** level — and reuses the very same mid-line rewrite machinery above.

Each row carries a **6-bit "alive" bitmap** (one bit per column, stored at `$92–$97` and initialized to `$3F` = `00111111`, all six present). When a shot connects, the game clears that invader's bit. Then, just before drawing the row, the kernel walks the six bits and builds the six column graphics-pointers — alive → the invader bitmap, **dead → a pointer to blank `$00` graphics**:

```
LF0A5: LDA.w  $0092,Y    ; this row's alive bitmap → $F8
       STA    $F8
       LDX    #$F4
LF0AE: LSR    $F8         ; shift out one invader's bit
       BCC    LF0B9       ; bit = 0 (destroyed) → blank it
       LDA    LFCD6,Y     ; bit = 1 (alive) → real graphics pointer
       ...
LF0B9: LDA    #$00        ; destroyed → point this slot at blank graphics
LF0BD: STA    $FA,X       ; store this column's pointer (fills $EE…$F8)
```

The destroyed invader's **slot is still there** — `NUSIZ` faithfully manufactures all three copies of the player every line — but that slot is now fed an **empty bitmap**, so it paints all-zero pixels and shows nothing. Gone, mechanically, is just "still drawn, drawing nothing." It's the same trick as the per-column rewrite, with the degenerate case (blank) standing in for a dead alien.

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
