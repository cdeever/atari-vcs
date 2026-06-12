---
title: "Anatomy of a Minimal ROM"
weight: 12
---

# Anatomy of a Minimal ROM

Every program in this book shares the same skeleton. Understanding these few lines means understanding what a VCS ROM fundamentally *is*.

## The header

```asm
    processor 6502

    include "vcs.h"     ; TIA / RIOT register names (COLUBK, PF0, WSYNC, ...)
    include "macro.h"   ; helper macros, e.g. CLEAN_START
```

`vcs.h` gives readable names to the hardware registers so you can write `sta COLUBK` instead of `sta $09`. `macro.h` provides convenience macros. In this repository both live in a shared top-level `include/` directory that every game reaches via DASM's [`-I../include`]({{< relref "toolchain" >}}) flag — a single source of truth rather than a copy per game.

## The origin and reset entry point

```asm
    seg
    org $f800           ; a 2K cart lives at $f800; a 4K cart at $f000

Reset:
    CLEAN_START         ; zero RAM and all registers, set the stack pointer
```

`org` tells DASM where in the address space this code lives. A 2K cartridge is mapped at `$f800`; a 4K cartridge at `$f000`. **Match the `org` to your cartridge size** — it determines where the reset vector must point.

`CLEAN_START` is a standard macro that clears the 128 bytes of RAM and the TIA registers to a known state, so you don't start from garbage.

## The frame loop

The body is an infinite loop, one iteration per video frame:

```asm
StartFrame:
    ; ... VSYNC, VBLANK, draw 192 visible lines, overscan ...
    jmp StartFrame
```

The [next chapter]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}) breaks this loop down line by line.

## The reset vectors

The 6502 starts executing at the address stored in the **reset vector** at `$fffc`. Every ROM ends by placing that vector:

```asm
    org $fffc
    .word Reset         ; reset vector  -> start of our code
    .word Reset         ; IRQ/BRK vector (unused on the VCS, point it anywhere safe)
```

When the console powers on, it reads `$fffc`, jumps to `Reset`, and `CLEAN_START` takes over.

> **Why two `.word Reset`?** The 6507 has no usable interrupt lines, so the IRQ/BRK vector at `$fffe` is never taken in normal play. Pointing it at `Reset` is a harmless, conventional default.

## In Practice

This skeleton — `processor`/`include`, `org`, `Reset`/`CLEAN_START`, frame loop, reset vectors — is visible in full in `xmas/xmas.asm`. Read it top to bottom and you have seen the shape of every VCS program; everything else is *what you do during the visible scanlines*.
