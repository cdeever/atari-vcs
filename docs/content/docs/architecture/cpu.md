---
title: "The Processor (CPU)"
weight: 16
---

# The Processor (CPU) — a 6507

The CPU runs your program. On most computers that makes it the star; on the VCS it's deliberately the *least* special of the four chips — a small, ordinary processor whose whole job is to operate the other three at exactly the right moments.

## A 6502 with its wings clipped

The 6507 is a cost-reduced version of the well-known [6502]({{< relref "/docs/6502-basics" >}}): the same instruction set, the same registers, the same programming model — but in a cheaper package with two consequential omissions:

- **Only 13 address lines.** It can address just **8 KB** of memory, total. That single limit is why the VCS has 128 bytes of RAM and why an unbanked cartridge tops out at 4 KB — there simply are no address lines to reach more.
- **No interrupt pins.** The IRQ and NMI lines aren't brought out, so there are no hardware interrupts. Your program is one uninterrupted flow of control; nothing preempts it, and you keep time by *polling* rather than by interrupt service routines.

It runs at roughly **1.19 MHz**, which works out to about **76 machine cycles per scanline** — the budget you are always spending against. Knowing the cycle cost of each instruction isn't an optimization nicety here; it's how you keep the picture stable.

## It has no powers of its own

The CPU is the orchestrator, but note what it *cannot* do: it has no video output, no sound output, and almost no storage of its own. Everything it accomplishes, it accomplishes by reading and writing the other three chips at exactly the right instants. On the VCS, "the program" is mostly the CPU choreographing the [TIA]({{< relref "programming-the-television" >}}) in time with the electron beam.

## In Practice

- The instruction-level detail — registers, addressing modes, the `WSYNC` idiom, and per-instruction cycle counts — lives in **[6502 Basics]({{< relref "/docs/6502-basics" >}})**. How those cycles map onto a frame is in **[The Frame Structure]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}})**.
- Because there are no interrupts, the only hardware clock you have is the [RIOT]({{< relref "riot" >}})'s interval timer. Long waits are done by setting that timer and polling it, or by counting scanlines with `WSYNC`.

> The mindset: don't think of the 6507 as "the computer that draws the game." Think of it as a fast, dumb hand that must reach over and flip the right switch on the TIA every few cycles, forever. The skill is in the timing, not the arithmetic.
