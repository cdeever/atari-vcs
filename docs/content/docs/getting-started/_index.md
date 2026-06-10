---
title: "Getting Started"
weight: 10
bookCollapseSection: true
BookIcon: getting-started
---

# Getting Started

With the big picture from the [Introduction]({{< relref "introduction" >}}) in hand — a VCS program is real-time television, built from four chips you reach by reading and writing memory — this chapter gets you set up to actually write one.

The work starts with the medium itself — how a television actually paints a picture — and then the underlying ideas you'll lean on constantly: thinking in bits, and the memory-mapped model by which you control every chip. From there the toolchain stops being bookkeeping and becomes simply *how you reach the hardware* — **DASM** assembles your instructions into a ROM image, and **Stella** runs that image so you can watch the machine execute it, line by line. The chapter ends at the smallest ROM that produces a stable picture, the skeleton every later project is built on.

- **[How a Television Works]({{< relref "how-the-tv-works" >}})** — the beam, scanlines, frames, sync, and NTSC vs. PAL. The display medium that dictates everything else.
- **[Prerequisite Knowledge: Bits & Memory-Mapped Hardware]({{< relref "prerequisites" >}})** — binary/hex, bit operations, and how registers are just memory addresses. Start here if you're new to low-level work.
- **[Toolchain: DASM & Stella]({{< relref "toolchain" >}})** — installing the assembler and emulator and the build/run loop.
- **[Anatomy of a Minimal ROM]({{< relref "minimal-rom" >}})** — the include files, the reset vector, and the frame loop skeleton.

> Everything in this book assembles with DASM and runs in Stella. The repository's `xmas/Makefile` is the canonical build invocation; the rest of the book builds on that loop.
