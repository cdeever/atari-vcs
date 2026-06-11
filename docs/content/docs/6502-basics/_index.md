---
title: "6502 Basics"
weight: 20
bookCollapseSection: true
BookIcon: cpu
---

# 6502 Basics

The VCS is driven by a 6507 — a cost-reduced 6502 with a 13-bit address bus (so it can only see 8 KB) and no interrupt pins. Everything you write is 6502 machine code, and the defining constraint is *cycles*: the CPU runs at ~1.19 MHz and you get roughly 76 machine cycles per scanline. Knowing how many cycles each instruction costs is not an optimization detail here — it is how you keep the picture stable.

This is the programmer's reference the rest of the book leans on. [Reading 6502 Assembly]({{< relref "/docs/prerequisites/reading-assembly" >}}) covered the *notation*; this chapter covers the machine the notation drives — its registers, the ways instructions reach memory, the instruction set itself, and (the part that matters most on the VCS) exactly **how many cycles everything costs**. For where this CPU sits in the system, see the [Architecture CPU page]({{< relref "/docs/architecture/cpu" >}}).

- **[Registers & Status Flags]({{< relref "registers" >}})** — the three working registers, the stack pointer and program counter, and the status flags branches test.
- **[Addressing Modes]({{< relref "addressing-modes" >}})** — how an instruction names its operand, why zero page is cheaper, and the page-crossing penalty.
- **[The Instruction Set]({{< relref "instruction-set" >}})** — a grouped tour of the ~56 mnemonics, and the few that do most of the work.
- **[Cycles & Timing]({{< relref "cycles-and-timing" >}})** — the cycle cost of every common instruction, and `WSYNC`. The reference [Kernel Techniques]({{< relref "/docs/kernel-techniques" >}}) builds on.
- **[The Stack & Subroutines]({{< relref "stack-and-subroutines" >}})** — `JSR`/`RTS`, push and pull, and the VCS quirk that the stack shares your 128 bytes of RAM.

> If you are new to the 6502, the registers and addressing modes are worth internalizing before the TIA chapter — almost every drawing technique is expressed as tightly cycle-counted loads and stores.
