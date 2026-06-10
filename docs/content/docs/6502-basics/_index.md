---
title: "6502 Basics"
weight: 20
bookCollapseSection: true
BookIcon: cpu
---

# 6502 Basics

The VCS is driven by a 6507 — a cost-reduced 6502 with a 13-bit address bus (so it can only see 8 KB) and no interrupt pins. Everything you write is 6502 machine code, and the defining constraint is *cycles*: the CPU runs at ~1.19 MHz and you get roughly 76 machine cycles per scanline. Knowing how many cycles each instruction costs is not an optimization detail here — it is how you keep the picture stable.

This chapter covers the programmer's model (the A, X, Y registers, the status flags, and the stack), the addressing modes, and the handful of instructions that do most of the work in VCS code: loads/stores, branches, and the `sta WSYNC` idiom that hands the rest of a scanline back to the hardware.

> If you are new to the 6502, the registers and addressing modes are worth internalizing before the TIA chapter — almost every drawing technique is expressed as tightly cycle-counted loads and stores.
