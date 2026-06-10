---
title: "Getting Started"
weight: 10
bookCollapseSection: true
---

# Getting Started

Before any of the hardware concepts matter, you need a working toolchain and a mental model of what an Atari VCS ROM actually *is*: a small blob of 6502 machine code that the console maps into its address space and begins executing at a fixed reset vector.

This chapter covers the mental model you need before writing a line, the two tools you will use constantly — **DASM** to assemble source into a binary, and **Stella** to run and debug it — and walks through the smallest ROM that produces a stable picture.

- **[Prerequisite Knowledge: Bits & Memory-Mapped Hardware]({{< relref "prerequisites" >}})** — binary/hex, bit operations, and how registers are just memory addresses. Start here if you're new to low-level work.
- **[Toolchain: DASM & Stella]({{< relref "toolchain" >}})** — installing the assembler and emulator and the build/run loop.
- **[Anatomy of a Minimal ROM]({{< relref "minimal-rom" >}})** — the include files, the reset vector, and the frame loop skeleton.

> Everything in this book assembles with DASM and runs in Stella. The repository's `xmas/Makefile` is the canonical build invocation; the rest of the book builds on that loop.
