---
title: "Programming the Atari VCS in Assembly"
type: docs
---

<div class="landing-hero">
<h1>Programming the Atari VCS in Assembly</h1>
<p class="subtitle">A hands-on guide to writing 6502 assembly games for the Atari Video Computer System — built around real, working code.</p>
</div>

The Atari Video Computer System — the **VCS** — has no framebuffer, almost no RAM, and a graphics chip that only renders a *single scanline at a time*. Programming it means thinking in CPU cycles and synchronizing your code to the electron beam as it sweeps down the screen — "Racing the Beam."

> **A note on the name.** The machine launched in 1977 simply as the *Video Computer System*. It only became the "Atari 2600" in 1982, when the Atari 5200 arrived and the product line suddenly needed distinguishing numbers — so Atari pressed the console's **CX2600** part number into service as a brand. The "2600" name is therefore a retronym; throughout this book the machine is called the **VCS**, the name it shipped with.

This notebook is a working reference for that craft. It is not a hardware datasheet and not a finished cookbook: it explains *why* the machine behaves the way it does, then shows the assembly patterns that make it do something useful. Every concept is tied to code that assembles with **DASM** and runs in the **Stella** emulator, drawn from the games in this repository.

**What lives here:**

- **Concepts grounded in code** — Each topic links back to working `.asm` from the repo's projects (`xmas/`, `music/`, and more), so you can read the explanation and then the source that proves it.
- **Cycle-level reasoning** — On the VCS, *when* an instruction runs matters as much as *what* it does. Pages call out the timing constraints that the hardware silently imposes.
- **Traps and gotchas** — The places where the machine surprises you: TIA write timing, the 2K/4K cartridge limit, the lack of a frame buffer, and the cycle budget you must hit every single scanline.

## How It's Organized

The chapters build from the toolchain up to whole games. Set up your tools, learn the 6502, then learn the TIA and how to draw by "Racing the Beam." Playfield, sprites, collisions, input, and sound each get their own chapter, followed by advanced cartridge techniques and complete project walkthroughs.

<div class="section-cards">

<div class="section-card">

### [Prerequisite Knowledge]({{< relref "/docs/prerequisites" >}})

How a television works, thinking in bits, and the memory-mapped interface — the mental model the VCS forces on you, before any code.

</div>

<div class="section-card">

### [Getting Started]({{< relref "/docs/getting-started" >}})

Installing DASM and Stella, the anatomy of a minimal ROM, and the build/run loop used throughout the book.

</div>

<div class="section-card">

### [VCS Architecture]({{< relref "/docs/architecture" >}})

The four chips that make up the machine — CPU, TIA, RIOT, and ROM — and the central idea that you are really programming the television.

</div>

<div class="section-card">

### [6502 Basics]({{< relref "/docs/6502-basics" >}})

The CPU at the heart of the VCS: registers, addressing modes, the instruction set, and the cycle counts that govern everything.

</div>

<div class="section-card">

### [The TIA & Racing the Beam]({{< relref "/docs/tia-racing-the-beam" >}})

The Television Interface Adapter, the frame structure (VSYNC / VBLANK / visible / overscan), and why you draw one scanline at a time.

</div>

<div class="section-card">

### [The Playfield]({{< relref "/docs/playfield" >}})

PF0/PF1/PF2 registers, reflection, mid-screen changes, and building backgrounds and large shapes from the 40-pixel playfield.

</div>

<div class="section-card">

### [Sprites: Players & Missiles]({{< relref "/docs/sprites" >}})

Player, missile, and ball objects: horizontal positioning, vertical delay, and drawing moving graphics.

</div>

<div class="section-card">

### [Collisions]({{< relref "/docs/collisions" >}})

The TIA collision latches, reading and clearing them, and turning hardware collision detection into game logic.

</div>

<div class="section-card">

### [Input]({{< relref "/docs/input" >}})

Reading joysticks, paddles, and the console switches through the RIOT's I/O ports.

</div>

<div class="section-card">

### [Sound]({{< relref "/docs/sound" >}})

The AUDC/AUDF/AUDV registers, the two audio channels, and driving frame-based music and effects.

</div>

<div class="section-card">

### [Kernel Techniques]({{< relref "/docs/kernel-techniques" >}})

Cycle counting, precise waiting, multi-line kernels, and front-loading — the craft of fitting a scanline's work into 76 cycles.

</div>

<div class="section-card">

### [Hardware Quirks as Features]({{< relref "/docs/hardware-quirks" >}})

How Cosmic Ark's starfield, Yars' Revenge's neutral zone, and sprite flicker turned bugs and limits into signature effects.

</div>

<div class="section-card">

### [Game Analysis]({{< relref "/docs/game-analysis" >}})

Block-diagram teardowns of classic games — starting with Combat, whose structure *is* the frame loop this book teaches.

</div>

<div class="section-card">

### [Burning to EPROM & Real Hardware]({{< relref "/docs/burning-eprom" >}})

Choosing a chip, preparing the ROM image, wiring the cartridge, and the bugs that only appear on a real console.

</div>

<div class="section-card">

### [Extending the Cartridge]({{< relref "/docs/cartridge-hardware" >}})

From bankswitching to ARM cartridges — the cartridge's evolution from dumb storage to smart silicon, and the closing debate over whether to extend at all.

</div>

</div>
