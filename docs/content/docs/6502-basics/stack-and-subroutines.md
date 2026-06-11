---
title: "The Stack & Subroutines"
weight: 50
---

# The Stack & Subroutines

The **stack** is the 6502's scratch area for return addresses and saved values, and subroutines (`JSR`/`RTS`) are built on it. On most 6502 systems it's an afterthought. On the VCS it deserves real care, because the stack and your variables **share the same 128 bytes of RAM** — and can run into each other.

## How the stack works

The stack pointer **S** is an 8-bit offset into a fixed region, and it grows *downward*:

- **Push** (`PHA`, `JSR`): write the byte at the current top, then decrement S.
- **Pull** (`PLA`, `RTS`): increment S, then read the byte.

`JSR` pushes the return address (two bytes) and jumps; `RTS` pulls it and resumes after the call. `PHA`/`PLA` save and restore A; `PHP`/`PLP` do the same for the [status register]({{< relref "registers" >}}). On a normal 6502 the stack lives in page 1 (`$0100`–`$01FF`), so `S = $FF` means the top is at `$01FF`.

## The VCS twist: the stack *is* your RAM

The VCS has only [128 bytes of RAM]({{< relref "/docs/architecture/riot" >}}), and through address mirroring those same 128 bytes answer to **two** ranges: the [zero page]({{< relref "addressing-modes" >}}) `$80`–`$FF`, where you put your variables, **and** the stack region `$0180`–`$01FF`, where pushes land. They are the *same physical bytes*.

So picture the 128 bytes as one shared space:

- Your **variables** are allocated from `$80` **upward**.
- The **stack** grows from the top (`$FF`) **downward** — `CLEAN_START` sets `S = $FF` to start it there.

They grow toward each other. Use too many variables *and* nest subroutines too deeply, and the stack's pushes will quietly overwrite your highest variables (or vice versa) — a corruption bug with no error message, just a game that misbehaves. With only 128 bytes total, that frontier is closer than you'd think.

## In Practice

- **Budget RAM as one pool.** There's no separate "stack memory." Every byte the stack uses is a byte your variables can't, and the collision is silent. Keep an eye on how high your variables reach and how deep your calls go.
- **Many kernels avoid the stack on purpose.** Because pushes cost RAM *and* cycles (`JSR`+`RTS` is 12 cycles before the routine does anything), tight display kernels often inline code or use `JMP` tables rather than subroutines, saving both.
- **`PHA`/`PLA` to "save" a register costs RAM too.** Spilling A to the stack mid-kernel uses a stack byte and 7 cycles round-trip. Often it's cheaper to keep the value in X or Y, or in a named zero-page variable, than to push it.

> The one-sentence version: on the VCS the stack and the zero page are the same 128 bytes seen through two windows — so a subroutine call and a variable write are competing for the same scarce memory, and nothing warns you when they meet.
