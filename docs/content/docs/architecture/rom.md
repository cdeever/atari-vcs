---
title: "The Program ROM"
weight: 19
---

# The Program ROM — your cartridge

Three of the four chips are inside the console. The **ROM is the one you supply** — it's the cartridge — and it holds your program and all of its constant data: code, sprite bitmaps, lookup tables, music.

## Where it lives

The CPU maps the cartridge into the **top of the address space**, the `$F000`–`$FFFF` window, with the all-important **reset vectors at `$FFFC`**. When the console powers on, the 6507 reads that vector and jumps to it — so the very top of your ROM is where execution begins. The mechanics of that startup are in **[Anatomy of a Minimal ROM]({{< relref "/docs/getting-started/minimal-rom" >}})**.

## What an original cartridge actually was

Back in the day, a 2600 cartridge was almost nothing — **a single mask ROM chip** on a small board. "Mask" means the program was etched into the silicon at the factory, baked in as one of the photographic masks the chip is manufactured from: dirt-cheap to stamp out by the thousand, and permanently fixed. That chip could only ever hold that one game.

The board itself did no thinking. The ROM's address pins wired straight to the console's [address bus]({{< relref "cpu" >}}), its data pins to the data bus, and a chip-enable came off the cartridge-select line. Plug it in and the ROM simply *appears* in the `$F000`–`$FFFF` window; the 6507 reads it like any other memory. No latches, no logic, no power of its own — just a ROM on the bus.

That bare simplicity is also where the **2 KB vs. 4 KB** split comes from. A 4 KB ROM fills the window exactly. A 2 KB ROM has one fewer address line, so the console can't tell the window's two halves apart — the 2 KB image **mirrors**, appearing twice. It still boots, because the reset vectors land correctly in the upper copy; you just get a smaller game repeated across the window. (Reproducing that mirror on a modern chip is a step in [Preparing the ROM Image]({{< relref "/docs/burning-eprom/preparing-the-image" >}}).)

## The 4 KB ceiling, and the two ways past the cartridge

4 KB is the most the 6507 can address directly, because it has only [13 address lines]({{< relref "cpu" >}}) and just the top 4 KB reaches the cartridge. Going beyond that isn't a bigger flat ROM — it takes **extra hardware on the cartridge** to page more ROM through the same window, the subject of **[Extended Cartridge Hardware]({{< relref "/docs/cartridge-hardware" >}})**. And putting *any* image, banked or not, onto a physical chip you can plug into a real console is **[Burning to EPROM]({{< relref "/docs/burning-eprom" >}})** — which is really just swapping the factory's permanent mask ROM for one you can program yourself.

## Read-only, and why that matters

The ROM is exactly that — read-only. It is the home of everything *constant*: your instructions and your data tables (the `Song` table in the Christmas-tree demo, a sprite's bitmap, a sine lookup). Anything that *changes* at runtime must live in the 128 bytes of [RIOT RAM]({{< relref "riot" >}}). That ROM-versus-RAM split — fixed data in the cartridge, mutable state in RAM — is one of the first architectural distinctions to keep firmly in mind.

## In Practice

- When laying out a program you are constantly deciding what can be precomputed into a ROM table versus what must be calculated into RAM each frame. ROM is comparatively plentiful (kilobytes); RAM is brutally scarce (128 bytes), so the bias is to push work into ROM tables wherever you can.

> A cart that won't boot *at all* is almost always a ROM-layout problem — most often the reset vectors not sitting at the very top of the address space. Rule that out before you suspect your game logic.
