---
title: "The DPC: A Chip in the Cartridge"
weight: 30
---

# The DPC: A Chip in the Cartridge

[Bankswitching]({{< relref "bankswitching" >}}) adds ROM and the [Superchip]({{< relref "extra-ram" >}}) adds RAM, but both are still just *memory* — passive storage the CPU does all the work against. *Pitfall II: Lost Caverns* (1984) took the idea to its conclusion: **David Crane** designed a custom chip, the **DPC** — officially the *Display Processor Chip*, though the initials are also his own (David Patrick Crane) — and built it into the cartridge. It was the first — and in the commercial 2600 era, essentially the only — game cartridge with a coprocessor of its own. The console did nothing new; the cart did the new thing.

## Data fetchers: streaming graphics without the CPU

Recall what an ordinary kernel spends its [76 cycles]({{< relref "/docs/kernel-techniques/counting-cycles" >}}) on: a great deal of it is *pointer bookkeeping* — `lda (ptr),y`, decrement, check, repeat — just to walk through a [graphics table]({{< relref "/docs/kernel-techniques/front-loading-and-tables" >}}) one byte per scanline, per object. That overhead is the ceiling on how much a kernel can draw.

The DPC's headline feature is **eight "data fetchers"** that do this walking *in hardware*. Each fetcher is an address counter pointing into a block of graphics ROM on the cartridge. The program reads a fixed fetcher register; the DPC hands back the byte the counter currently points at **and advances the counter on its own.** The CPU no longer maintains the pointer — it just reads the next byte, already served up. Some fetchers can also *increment by a fraction* each step, so a shape can be smoothly scaled or scrolled with no CPU arithmetic, and others carry a windowing mask that draws only across a chosen band of scanlines. The net effect is a kernel freed of its housekeeping, with cycles left over to put far more on screen than the bare machine allows.

## Three voices of music, in parallel with the game

The [TIA]({{< relref "/docs/architecture/programming-the-television" >}}) has [two audio channels]({{< relref "/docs/sound" >}}), and a busy game can rarely spare the cycles to drive them as continuous music while everything else races the beam. The DPC sidesteps that entirely. Three of its data fetchers can be switched into a **music mode**, where they're clocked by an oscillator *on the chip* — independent of the CPU — and act as three programmable frequency dividers, i.e. three square-wave voices. The program samples their combined output and pours it into the TIA's volume register, so Pitfall II's well-known three-part theme plays on, steady, while the kernel gets on with the picture. The cartridge is, in effect, keeping the beat the console couldn't hold.

(The DPC still uses [bankswitching]({{< relref "bankswitching" >}}) underneath for its ROM — the coprocessor sits alongside the paging logic, not instead of it.)

## Why it belongs at the end of this chapter

Every other escape in this chapter expands what the hardware *has* — more ROM, more RAM. The DPC expands what the cartridge *does*: it offloads computation, the one thing a passive chip never could. That makes it the natural horizon of "put hardware on the cart," and the bridge to the modern era — today's homebrew carts (the Harmony/Melody boards and their **DPC+**/CDF formats) carry a full ARM processor that emulates the original DPC and goes much further, running game logic the 6507 never touches.

## In Practice

- **You will almost certainly never write for the original DPC.** One commercial game used it, its display ROM and registers are specific to that design, and there's no assembler-level "DPC mode" you reach for. It's here as the idea's furthest point, not a technique to adopt.
- **Stella emulates it.** If you want to *see* the data fetchers and music engine at work, the DPC is a supported cartridge type in the emulator — load Pitfall II and watch the audio run free of the kernel.
- **The lesson generalizes.** Whenever a per-line cost is the thing capping your kernel, "move the bookkeeping off the CPU" is the instinct the DPC distilled — and it's exactly what modern enhancement chips do at scale.
