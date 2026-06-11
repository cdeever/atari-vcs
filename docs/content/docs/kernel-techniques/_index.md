---
title: "Kernel Techniques"
weight: 85
bookCollapseSection: true
BookIcon: kernel
---

# Kernel Techniques

Once you can draw — playfield, sprites, a stable frame — the binding constraint stops being *what* to draw and becomes *whether it fits*. Every visible scanline is [76 CPU cycles]({{< relref "/docs/tia-racing-the-beam" >}}), and a "kernel" is the loop that races down the screen spending them. This chapter is the craft of fitting a line's work into that budget and keeping the timing rock-solid.

You have already met the pressure in its rawest form: the [asymmetric playfield]({{< relref "/docs/playfield/asymmetric" >}}) demands six precisely-timed register writes per line, and the [scoreboard]({{< relref "/docs/playfield/scoreboard" >}}) crams digit-fetching in around them. The techniques below are the general tools for that kind of work.

Each technique here is a different answer to the same question — *how do I fit this line's work into 76 cycles?* — and they stack: count first, then wait, spread, or precompute whatever still won't fit.

- **[Counting Cycles]({{< relref "counting-cycles" >}})** — the budgeting discipline: tallying a line from `WSYNC` to `WSYNC`, leaving margin, and spending cycles where they are.
- **[Waiting Precisely]({{< relref "waiting-precisely" >}})** — landing on an exact cycle (`NOP`, the `SLEEP` macro) and waiting out whole regions with the [RIOT timer]({{< relref "/docs/architecture/riot" >}}).
- **[Multi-Line Kernels]({{< relref "multi-line-kernels" >}})** — buying time by spreading work across two (or more) scanlines per loop, and the `VDEL` register that keeps them in sync.
- **[Front-Loading & Tables]({{< relref "front-loading-and-tables" >}})** — doing the work *earlier* (before the line, or before the program runs) with prefetching and page-aligned lookup tables.

> The foundations these build on: instruction costs in [6502 Basics → Cycles & Timing]({{< relref "/docs/6502-basics/cycles-and-timing" >}}), and where the cycles go in a frame in [The Frame Structure]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}).
