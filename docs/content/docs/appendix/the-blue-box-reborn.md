---
title: "The Blue Box, Reborn"
weight: 10
---

# The Blue Box, Reborn

The rest of this book hands you a 2026 toolchain: write 6502 in a text editor, run [DASM]({{< relref "/docs/getting-started/toolchain" >}}), and watch the result in Stella a fraction of a second later. It works, it's free, and it would have looked like science fiction to the people who actually invented these games. In 1979 there was no Stella, no DASM, no PC on the desk. There was a refrigerator-sized minicomputer down the hall, a serial cable, and a blue sheet-metal box wired into the cartridge slot of a real console.

This page rebuilds that original chain link by link — and then shows how to assemble a working replica of it on hardware you can buy or breadboard today: a **PiDP-11** running **RT-11**, a genuine period 6502 cross-assembler, a serial download, and a cartridge that holds your program in **RAM the VCS reads as ROM**. It is slower, fiddlier, and far less practical than `make run`. That is the entire point. This is the workflow David Crane used to write *Pitfall!*, recreated closely enough that you can feel the shape of the constraints he was working inside.

## How they actually did it

There was no single machine that did everything. A 2600 program was born on one computer and run on another, with a deliberate, physical bridge between them.

**The minicomputer.** Source code was written and **cross-assembled on a DEC PDP-11** — Atari used a **PDP-11/20**. "Cross"-assembled because the PDP-11 is not a 6502; it ran an assembler that *emitted* 6502 machine code it could never execute itself. Atari's arcade division built its 6502 cross-assembler as a set of **MACRO-11 macros** — i.e. they taught the PDP-11's own macro assembler to speak 6502. The turnaround was brutal by modern standards: an early PDP-11 took **about 20 minutes to assemble a 2K game and 40 minutes for a 4K game**, and it couldn't time-share — while it churned on one programmer's build, *nobody else could edit or assemble.* You learned to think hard before you spent a build.

**The blue box.** Assembling code is only half the problem; you still have to *run* it on the actual hardware, and the actual hardware runs from a cartridge ROM you can't rewrite on the fly. Crane's solution at Activision was a small custom 6502 computer built from off-the-shelf parts, housed in a blue sheet-metal enclosure that everyone just called the **"blue box."** In his own description it had **"an umbilical to plug into the 2600's cartridge slot,"** and it let developers **"load game program data into RAM such that it looked like ROM to the 2600."** That sentence is the whole trick: the console cannot tell the difference between a ROM chip and a chunk of RAM holding the same bytes at the same addresses — so put the program in RAM you *can* rewrite, and you've made the cartridge editable.

> **Why RAM-as-ROM is the key idea.** The VCS fetches instructions and data by putting an address on the bus and reading back whatever answers. It has no idea what kind of part is answering. A blue box parks RAM in the cartridge's `$F000`–`$FFFF` slice; to the 6507 it is an ordinary cartridge. Every recreation below is just a modern way of doing this one thing.

The blue box was more than passive memory. It ran a **debug monitor** that could bootload a program, let you **read and modify memory locations by hand**, and **set breakpoints** to stop the running game and inspect it — an in-circuit debugger years before that was a product you could buy. For the truly nasty timing bugs, the bench also held an **HP-1600-series logic analyzer** to capture the bus and disassemble what the chips were *actually* doing, cycle by cycle.

**The loop.** Put together, the daily rhythm was: **edit** on the PDP-11 → **assemble** (and go get coffee) → **download** the object code over **RS-232** into the blue box → **playtest** on a real console → back to **edit**. Slow, serial, physical. Recreating that loop is what the rest of this page is about.

## The chain, rebuilt

Each link below maps one piece of the 1979 rig onto something you can stand up today. Build them in order; each one feeds the next.

### The minicomputer → a PiDP-11

You don't need to find a working PDP-11 (they weigh as much as a person and draw power like one). The **PiDP-11**, Oscar Vermeulen's replica kit, is a faithful scale reproduction of the **PDP-11/70 front panel** — the iconic wall of switches and blinkenlights — with a **Raspberry Pi** behind it running **SIMH**, the standard historical-computer simulator. SIMH emulates the PDP-11 accurately enough to boot the real **RT-11** operating system off a simulated disk pack. The blinking address lights aren't decoration: they're driven by the simulated CPU's actual bus activity, so when your assembler runs you can watch it think.

RT-11 is the right OS to land on here. It's small, single-user, and disk-based — much closer in spirit to the spartan environment a 1979 programmer faced than a modern Unix would be. You'll edit source and run the assembler entirely inside it.

### The cross-assembler → MACXX on RT-11

This is the link that makes the whole exercise *authentic* rather than merely themed. **MACXX**, written by Dave Shepperd, is a macro assembler whose **first implementation was written in PDP-11 assembly for RT-11, with coding starting around early 1978** — and it was genuinely used to build old Atari game sources. It is, almost literally, the kind of tool Crane's contemporaries reached for. It was later rewritten in C (around 1982–83) and **still builds today on Linux, including on a Raspberry Pi**, so you have two honest options:

- **Most authentic:** build/run MACXX *inside* RT-11 on the simulated PDP-11, so the assembler executes on the (simulated) period hardware.
- **Pragmatic but still period-correct:** build the C version of MACXX natively on the PiDP-11's Raspberry Pi host. Same assembler lineage, far less yak-shaving.

MACXX is a two-step toolchain, not a one-shot like DASM. You **assemble** each source file to an object file, **link** the objects with its companion linker **`LLF`**, and then convert the linked output into a flat cartridge image with **`MIXIT`**. The end product is the same thing DASM's `-f3` gives you: a raw binary, 2K or 4K, with the 6507 **reset vectors at the very top** (`$FFFC/$FFFD` pointing at your entry label) and code based at **`$F000`**, exactly as described in [Preparing the Image]({{< relref "/docs/burning-eprom/preparing-the-image" >}}).

> **MACXX is not DASM.** Directive names, the macro syntax, and the comment character differ from the DASM dialect used throughout this book. Don't expect an `xmas.asm` to assemble unchanged — expect to port it. Translating a known-good DASM program to MACXX is, honestly, half the fun and a real test of how well you understand both the source and the assembler.

### The download → serial

In 1979 the bridge from minicomputer to blue box was **RS-232**: the assembled bytes were streamed down a serial cable. You recreate exactly that. SIMH can attach a simulated serial port to a real one on the Raspberry Pi (or to a TCP socket), so you copy the finished cartridge image off RT-11 and send it down a wire to the cartridge you're about to build. This is the modern umbilical — slower than copying a file, and that slowness is part of the experience you're reconstructing.

### The blue box → a Raspberry Pi Pico RAM cart

Here is the modern blue box. A **Raspberry Pi Pico** is small, cheap, and fast enough to *be* a cartridge. Wired into the VCS cartridge slot, it watches the console's bus and answers reads exactly as a ROM would. The whole job is a tight loop conceptually equal to:

```c
// the Pico's entire job, in one line:
put_data_on_bus(rom[get_requested_address()]);   // RAM answering as ROM
```

It reads the **12 address lines** off its GPIO pins to learn which byte the 6507 wants, and drives the **8 data lines** with that byte from a buffer held in its own RAM. Because that buffer is RAM, you can **reload it over serial** from the PiDP-11 between runs without touching the console — the precise capability the blue box existed to provide. Hold the program in rewritable memory, present it to the console as ROM, and you've rebuilt Crane's umbilical with a £4 microcontroller. (The same family of cart can be taught a debug monitor and breakpoints too, if you want to chase the blue box's full feature set rather than just its core trick.)

### The target → a real VCS

The last link is the easy one and the whole reason for the other four: a **real Atari VCS**. Plug the Pico cart into the slot, power on, and the program you assembled on a simulated 1970s minicomputer is running on genuine 1977 silicon, painting a real picture on a real television. Spot a bug, and you run the loop again — **edit in RT-11 → assemble with MACXX → download over serial → playtest** — the 1979 cycle, rebuilt on your bench.

## Both chains, side by side

{{< graphviz >}}
digraph bluebox {
  rankdir=LR;
  bgcolor="transparent";
  node [shape=box, style="filled,rounded", fontsize=10, color="#808080", penwidth=1.1];
  edge [color="#808080", penwidth=1.2, fontsize=9, fontcolor="#808080"];

  subgraph cluster_then {
    label="1979"; fontsize=11; fontcolor="#808080"; color="#808080"; style=dashed;
    t_host [label="PDP-11/20\n(edit + MACRO-11 cross-assembler)", fillcolor="#cfe0f5"];
    t_box  [label="Blue box\n(RAM-as-ROM + debug monitor)", fillcolor="#f6e0c6"];
    t_vcs  [label="Real VCS", fillcolor="#d2efd2"];
    t_host -> t_box [label="  RS-232 download"];
    t_box  -> t_vcs [label="  umbilical → cart slot"];
  }

  subgraph cluster_now {
    label="Today"; fontsize=11; fontcolor="#808080"; color="#808080"; style=dashed;
    n_host [label="PiDP-11 / RT-11\n(edit + MACXX → LLF → MIXIT)", fillcolor="#cfe0f5"];
    n_box  [label="Pico RAM cart\n(RAM-as-ROM, serial-loadable)", fillcolor="#f6e0c6"];
    n_vcs  [label="Real VCS", fillcolor="#d2efd2"];
    n_host -> n_box [label="  serial download"];
    n_box  -> n_vcs [label="  cart slot"];
  }
}
{{< /graphviz >}}

## Tips & Caveats

- **This is the fun hard road, by choice.** If you only want your code on real hardware, the easy path is the rest of this book: assemble with DASM and load the `.bin` onto a flashable cart (a Harmony/Melody or UnoCart) or [burn an EPROM]({{< relref "/docs/burning-eprom" >}}). The blue-box recreation is for the journey, not the shortcut.
- **SIMH is not a real PDP-11.** A simulator booting RT-11 gives you the software experience and the front-panel theatre, but it runs at modern speeds on a Raspberry Pi — you won't suffer the literal 40-minute assemble (and you needn't pretend to).
- **Serial is slow, and that's authentic.** Don't expect USB-stick transfer times. Streaming a 4K image down a serial link is part of the period feel; pick a baud rate you can live with for many iterations.
- **Mind the bus timing on the cart.** The hard part of a Pico (or any MCU) cartridge is answering the bus *fast enough and at the right moment* — the 6507 won't wait for you. Budget your effort here, not on the assembler.
- **A simple RAM cart is unbanked.** Plan for a **2K or 4K** image with no bankswitching unless you specifically add it; that's plenty for a first program and matches what the original blue box targeted.
- **MACXX ≠ DASM.** Porting a DASM source to MACXX's dialect is real work. Start from a tiny, known-good program (a solid-color frame) so that when something breaks you know it's the toolchain, not your game.

## Going further

- **[PiDP-11](https://obsolescence.dev/pdp11)** — Oscar Vermeulen's kit: the replica PDP-11/70 panel plus the Raspberry Pi / SIMH software that boots RT-11.
- **[MACXX](https://github.com/DaveShepperd/macxx)** — Dave Shepperd's RT-11-origin 6502 cross-assembler, with the `LLF` linker and `MIXIT` image tool; build instructions for Linux and Raspberry Pi.
- **[Atari 2600 Program Development](https://www.atariarchives.org/dev/CGEXPO01.ppt)** — Joe Decuir's talk on the original dev rig: the PDP-11 cross-assembler, the RAM-in-code-space emulator, the debug monitor, and the HP-1600 logic analyzer.
- **[The Blue Box: David Crane On Early Atari](https://www.gamingalexandria.com/wp/2019/05/the-blue-box-david-crane-on-early-atari-inc/)** — Crane's first-hand account of the blue box and the day-to-day workflow.
- **[Atari 2600 Cartridge Emulation](https://emalliab.wordpress.com/2025/12/18/atari-2600-cartridge-emulation-part-2/)** — a practical write-up of using a Raspberry Pi Pico to serve the VCS bus as RAM-presented-as-ROM.

For where the cartridge story continues with permanent media rather than live RAM, see **[Burning an EPROM]({{< relref "/docs/burning-eprom" >}})**, and for the wider reference shelf, **[Further Reading]({{< relref "/docs/further-reading" >}})**.
