---
title: "Getting Started"
weight: 10
bookCollapseSection: true
BookIcon: getting-started
---

# Getting Started

With the [prerequisites]({{< relref "/docs/prerequisites" >}}) behind you — how a television works, thinking in bits, and the memory-mapped interface — you're ready to actually write a ROM. This short chapter is about the tools and the skeleton.

The toolchain is simply *how you reach the hardware*: **DASM** assembles your instructions into a ROM image, and **Stella** runs that image so you can watch the machine execute it, line by line. From there the chapter ends at the smallest ROM that produces a stable picture — the skeleton every later project is built on.

- **[Toolchain: DASM & Stella]({{< relref "toolchain" >}})** — installing the assembler and emulator and the build/run loop.
- **[Anatomy of a Minimal ROM]({{< relref "minimal-rom" >}})** — the include files, the reset vector, and the frame loop skeleton.

> Everything in this book assembles with DASM and runs in Stella. The repository's `xmas/Makefile` is the canonical build invocation; the rest of the book builds on that loop.
