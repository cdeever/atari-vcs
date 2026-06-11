---
title: "Kernel Techniques"
weight: 85
bookCollapseSection: true
BookIcon: kernel
---

# Kernel Techniques

Once you can draw — playfield, sprites, a stable frame — the binding constraint stops being *what* to draw and becomes *whether it fits*. Every visible scanline is [76 CPU cycles]({{< relref "/docs/tia-racing-the-beam" >}}), and a "kernel" is the loop that races down the screen spending them. This chapter is the craft of fitting a line's work into that budget and keeping the timing rock-solid.

You have already met the pressure in its rawest form: the [asymmetric playfield]({{< relref "/docs/playfield/asymmetric" >}}) demands six precisely-timed register writes per line, and the [scoreboard]({{< relref "/docs/playfield/scoreboard" >}}) crams digit-fetching in around them. The techniques below are the general tools for that kind of work.

## What this chapter covers

- **Counting cycles.** Knowing, cold, what each instruction costs (a zero-page load is 3, an absolute load 4, a taken branch 3, a page-crossing read +1) and adding them up so a line never overruns 76.
- **Waiting precisely.** `WSYNC` parks you at the next line boundary, but mid-line you often need to burn an *exact* number of cycles — `NOP`s, the conventional "sleep" macro, and the [RIOT timer]({{< relref "/docs/architecture/riot" >}}) for longer spans.
- **Multi-line kernels.** Two-line (and N-line) kernels output several scanlines per loop iteration, doing one line's setup while the previous line is still being drawn.
- **Front-loading.** Computing the *next* line's values during the current line's slack, so the data is ready the instant the beam needs it.
- **Tables over arithmetic.** Trading plentiful ROM for scarce cycles: precompute results into `.byte` tables and look them up instead of calculating at run time (see [Numbers & Arithmetic]({{< relref "/docs/prerequisites/numbers" >}})).
- **Register and addressing discipline.** Reusing A/X/Y, keeping hot variables in zero page, and avoiding page-cross penalties to shave cycles where it counts.

> This chapter is being built out. For now it collects the techniques in one place and names them; the detailed, worked treatments arrive page by page. The foundational ideas live in [6502 Basics]({{< relref "/docs/6502-basics" >}}) (instruction costs) and [The Frame Structure]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}) (where the cycles go in a frame).
