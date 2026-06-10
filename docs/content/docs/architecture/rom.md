---
title: "The Program ROM"
weight: 19
---

# The Program ROM — your cartridge

Three of the four chips are inside the console. The **ROM is the one you supply** — it's the cartridge — and it holds your program and all of its constant data: code, sprite bitmaps, lookup tables, music.

## Where it lives

The CPU maps the cartridge into the **top of the address space**, the `$F000`–`$FFFF` window, with the all-important **reset vectors at `$FFFC`**. When the console powers on, the 6507 reads that vector and jumps to it — so the very top of your ROM is where execution begins. The mechanics of that startup are in **[Anatomy of a Minimal ROM]({{< relref "/docs/getting-started/minimal-rom" >}})**.

## Size, and its hard ceiling

Unmodified, a cartridge is **2 KB or 4 KB** — 4 KB is the most the 6507 can address directly in the cart window, because it only has [13 address lines]({{< relref "cpu" >}}). Going beyond that doesn't mean a bigger flat ROM; it means **bankswitching hardware** on the cartridge that pages extra chunks of ROM into the same window. That's the subject of **[Advanced Techniques]({{< relref "/docs/advanced" >}})**, and getting any of it onto a physical chip is **[Burning to EPROM]({{< relref "/docs/burning-eprom" >}})**.

## Read-only, and why that matters

The ROM is exactly that — read-only. It is the home of everything *constant*: your instructions and your data tables (the `Song` table in the Christmas-tree demo, a sprite's bitmap, a sine lookup). Anything that *changes* at runtime must live in the 128 bytes of [RIOT RAM]({{< relref "riot" >}}). That ROM-versus-RAM split — fixed data in the cartridge, mutable state in RAM — is one of the first architectural distinctions to keep firmly in mind.

## In Practice

- When laying out a program you are constantly deciding what can be precomputed into a ROM table versus what must be calculated into RAM each frame. ROM is comparatively plentiful (kilobytes); RAM is brutally scarce (128 bytes), so the bias is to push work into ROM tables wherever you can.

> A cart that won't boot *at all* is almost always a ROM-layout problem — most often the reset vectors not sitting at the very top of the address space. Rule that out before you suspect your game logic.
