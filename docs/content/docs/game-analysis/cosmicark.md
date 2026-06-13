---
title: "Cosmic Ark (1982)"
weight: 70
---

# Cosmic Ark (1982)

*Cosmic Ark* — **Rob Fulop**, Imagic — casts you as a sort of Noah in orbit: a great ark sweeping the galaxy to rescue pairs of animals from dying worlds. It plays in two alternating acts — fend off a meteor storm from the center of the screen, then drop to a planet and lift creatures aboard with a tractor beam. It's a fine game. But it is *remembered* for four instructions.

Cosmic Ark opens on the most famous starfield on the platform — crisp, even, drifting stars, far more points of light than the TIA has objects to draw. The book's [Hardware Quirks chapter]({{< relref "/docs/hardware-quirks/cosmic-ark-starfield" >}}) tells the story of *why* it works (an `HMOVE` glitch Fulop found by accident and never fully explained, living in the analog seams of the chip). Here we get to do the thing that page can't: **read the actual code that pulls it off.**

## The shape of the program

An ordinary frame, with one extraordinary pass — the stars get smeared on *before* the foreground:

{{< graphviz >}}
digraph cosmcark {
  rankdir=TB;
  bgcolor="transparent";
  node [shape=box, style="filled,rounded", fontsize=10, color="#808080", penwidth=1.1];
  edge [color="#808080", penwidth=1.2];

  init  [label="Power-up / new wave — set up the Ark", fillcolor="#e2e2e2"];
  logic [label="VSYNC + VBLANK — move the Ark; the meteors\n(defense phase) or the animals & beam (rescue phase)", fillcolor="#cfe0f5"];
  star  [label="Starfield pass — ONE missile (M0) smeared across\neach line: strobe HMOVE, then write HMM0 *during\nthe comb* so the missile takes extra motion and\nrepeats — the deliberate TIA \"HMOVE bug\"", fillcolor="#f6e0c6"];
  kernel[label="Kernel — draw the Ark, the meteors / animals,\nthe laser, the playfield (foreground over the stars)", fillcolor="#d2efd2"];
  over  [label="Overscan", fillcolor="#f6c6cc"];

  init -> logic -> star -> kernel -> over;
  over -> logic [label="  next frame", constraint=false, fontsize=9, fontcolor="#808080"];
}
{{< /graphviz >}}

## The starfield, in four instructions

The whole galaxy is **one missile.** It's enabled once, as an ordinary object:

```asm
       LDA    #$02
       STA    ENAM0      ; turn missile 0 on — this is "the stars"
```

A missile can be drawn in exactly *one* place per scanline. To get a whole row of stars out of it, Cosmic Ark abuses [horizontal positioning]({{< relref "/docs/sprites/horizontal-positioning" >}}). Normally you set a motion value in `HMM0` and *then* strobe `HMOVE`, and the object slides over once during the next blanking interval. Fulop does it **backwards and badly on purpose** — strobe `HMOVE` first, then write `HMM0` while the TIA is still in the middle of applying the motion:

```asm
       STA    WSYNC
       STA    HMOVE      ; (1) start the horizontal-move "comb"
       JSR    L1BDC      ; (2) wait an exact number of cycles…
       STA    HMM0       ; (3) …then poke the motion register MID-COMB
```

That middle step is the trick, and it's the reason there's a subroutine call in the hottest part of the kernel. `L1BDC` isn't doing arithmetic — it's a **cycle-precise delay** that also hands back the motion value in one move:

```asm
L1BDC: NOP              ; burn 2
       NOP              ; burn 2  — land the next STA exactly inside the comb
       LDA    #$60      ; the motion value to drop into HMM0
       RTS
```

`HMOVE` works by sending a burst of "move" pulses to each object during the extended blank after the strobe. Change `HMM0` while that burst is still being delivered and the missile's position logic comes unglued — instead of moving once, it gets retriggered again and again across the line, painting a string of evenly-spaced dots. Do it every scanline, nudge the value frame to frame, and the dots become a smoothly drifting starfield. (The deep electrical *why* — two clocks beating against each other, why it differs between consoles — is the [quirk page's]({{< relref "/docs/hardware-quirks/cosmic-ark-starfield" >}}) story; the four instructions above are *how*.)

It's the mirror image of [Space Invaders]({{< relref "spaceinvaders" >}}). There, the TIA's repeat feature (`NUSIZ` copies) was used exactly as documented to clone an object on purpose. Here, the *undocumented* repeat — a positioning glitch the manual never mentions — is used to clone an object the chip never agreed to clone. Same instinct (one object, many copies), opposite side of the spec.

## Two phases sharing one ark

Behind the stars, a bit flag (`$B8`) splits the game into its two acts, and the same kernel and objects serve both:

- **Defense.** The Ark holds the center of the screen while meteors streak in; you swivel and fire to clear them. The starfield scrolls behind the whole fight.
- **Rescue.** The Ark descends and tracks across a planet; you drop a tractor beam to scoop up pairs of animals and haul them back up, dodging the hazards that rise to meet you.

The Ark itself is a [player sprite]({{< relref "/docs/sprites" >}}), the laser and tractor beam lean on the [ball and the other missile]({{< relref "/docs/sprites/missiles-and-ball" >}}), and the planet surface and HUD come from the [playfield]({{< relref "/docs/playfield" >}}) — leaving missile 0 free to spend its entire life being the heavens. That division of labor is the quiet design decision that makes the loud trick possible: the stars get a dedicated object precisely because everything else is covered.

## Why read it

Read Cosmic Ark for the rare chance to put a fingertip on the single most famous "bug as feature" in the VCS canon and find it's only **four instructions** — a strobe, a counted delay, and a mistimed register write. The [Hardware Quirks]({{< relref "/docs/hardware-quirks/cosmic-ark-starfield" >}}) page explains why it shimmers; this one shows you the few bytes that do it. It's the best illustration in the book of a truth the 2600 keeps teaching: on hardware this bare, the line between *defect* and *effect* is wherever a clever programmer decides to draw it.

> **Read the source.** This teardown is drawn from a [DiStella]({{< relref "/docs/getting-started/toolchain" >}}) disassembly of the *Cosmic Ark* cartridge (Rob Fulop's game, © 1982 Imagic). For the history and the hardware explanation of the starfield, see [Cosmic Ark's Star Field]({{< relref "/docs/hardware-quirks/cosmic-ark-starfield" >}}) and the [AtariAge deep-dive](https://forums.atariage.com/topic/261596-cosmic-ark-star-field-revisited/).
