---
title: "VCS Architecture"
weight: 15
bookCollapseSection: true
BookIcon: architecture
---

# VCS Architecture

The VCS is not a general-purpose computer with a graphics card bolted on. It is **four chips sharing a single bus**, designed in 1977 to be as cheap as possible — and the consequences of that design decide how every game is written. Before learning the CPU or the TIA in detail, it pays to see the whole machine at once: what the four chips are, how they divide the work, and — most importantly — which one is really in charge of what the player experiences.

## The four chips

| Function | Chip | Role |
|----------|------|------|
| **Processor** | CPU — a 6507 | Runs your program. The orchestrator — but it has no display hardware of its own. |
| **Video & sound** | TIA (Television Interface Adapter) | The **special sauce.** Generates the picture and audio in real time, line by line. |
| **Memory, I/O & timer** | RIOT — a 6532 | The 128 bytes of RAM, an interval timer, and the I/O ports for joysticks and switches. |
| **Program storage** | ROM (your cartridge) | Holds the program and its data; mapped into the top of the address space. |

That's the entire computer. There is no video memory, no operating system, no BIOS to call — just these four parts wired to a shared address/data bus.

## One bus, one address space

The CPU talks to the other three chips the only way it can: by **reading and writing memory addresses**. The TIA, the RIOT, and the cartridge each respond to their own slice of the 6507's 13-bit address space, so a `sta` to one address changes a color while a `sta` to another stores a variable. This is the [memory-mapped model]({{< relref "/docs/prerequisites/memory-mapped" >}}) introduced in the prerequisites, and it is the glue that makes four separate chips behave as one machine:

| Range | Chip | Contents |
|-------|------|----------|
| `$00`–`$3F` | TIA | Graphics, sound, collision, and sync registers (mostly write-only) |
| `$80`–`$FF` | RIOT | The 128 bytes of RAM — your variables |
| `$280`–`$297` | RIOT | The I/O ports (`SWCHA`/`SWCHB`) and the interval timer |
| `$F000`–`$FFFF` | Cartridge | Program ROM, with the reset vectors at the very top |

Because the CPU only has 13 address lines, these ranges (and their mirrors) are *all* it can see — there is no room for more, which is exactly why RAM is 128 bytes and an unbanked cart tops out at 4 KB. You never need to memorize the raw addresses; the names in `vcs.h` stand in for them.

## The thesis: you are programming the television

Here is the idea that reframes everything else in this book.

On a modern system you draw into a frame buffer and the hardware displays it for you whenever it's ready. **The VCS has no frame buffer.** The TIA generates the television signal *as the electron beam sweeps across the screen*, and it only knows what to output because your code is feeding it registers in that exact instant. There is nothing between your program and the picture tube.

So although the television is nominally just the "output device," in practice **the TV's scan is the platform you are programming against.** Your real, moment-to-moment job is to emit a valid TV signal sixty times a second — correct sync, correct colors at the correct horizontal positions — and the *game* is what emerges when you do that job well. Get the timing wrong and you don't get a buggy game; you get no picture at all.

This is why VCS programming feels inverted compared to other platforms, and why the [TIA gets its own treatment]({{< relref "programming-the-television" >}}) as the chip that defines the whole experience.

## In this section

A page on each of the four chips — what it is, what it does, and where its detailed treatment continues later in the book:

- **[The Processor (CPU)]({{< relref "cpu" >}})** — the 6507: a clipped-down 6502 whose only real job is timing.
- **[The Video & Sound Chip (TIA)]({{< relref "programming-the-television" >}})** — the special sauce, and why the TV (not the CPU) sets the terms of the work.
- **[Memory, I/O & Timer (RIOT)]({{< relref "riot" >}})** — your 128 bytes of RAM, the controls, and the only clock you get.
- **[The Program ROM]({{< relref "rom" >}})** — the cartridge you supply: where code and constant data live, and its size limits.
