---
title: "The TIA & Racing the Beam"
weight: 30
bookCollapseSection: true
BookIcon: tv
---

# The TIA & Racing the Beam

The Television Interface Adapter (TIA) is the chip that makes the VCS unusual. It has no frame buffer — it generates the video signal one scanline at a time, in real time, as the electron beam sweeps across the screen. Your code must feed it the right register values *before the beam reaches the pixels they affect*. This is "Racing the Beam," and it shapes the structure of every VCS program.

> **A Star Trek aside.** In the *Original Series* episode "Wink of an Eye," a dose of Scalosian water accelerates a person into hyper-speed — so fast they vanish from normal view, heard only as an insect-like buzz, free to dart about and rearrange the world while everyone on ordinary time stands frozen and none the wiser. Programming the TIA feels much the same, with one cruel twist: *you* are the accelerated one, doing all your work in the slivers of time the viewer can't perceive — but where the Scalosians had all the time in the world inside those gaps, you have almost none. The job is the same, though: get everything in place in the wink of an eye, before the beam reveals the line to an audience that never sees you work.

So where does the *game* live — the movement, the collisions, the AI, the scorekeeping? Almost none of it happens while the picture is on screen. It hides in the crevices: the 37 lines of vertical blank up top, the 30 lines of overscan at the bottom, and the brief horizontal-blank gap that opens every line — the off-screen intervals where the beam is dark. Exactly like the Scalosians darting through a frozen world, your logic runs in the slivers the viewer never sees, and the finished picture is all that's left behind.

And the budget that governs every one of those lines — on screen or off — comes down to one exact ratio. The TIA paints the picture in "color clocks" at about **3.58 MHz**, while the 6507 CPU is clocked at exactly one-third of that — about **1.19 MHz**. So **the TIA lays down three pixels for every single cycle the CPU gets** — an exact three to one. A whole scanline is 228 color clocks but only 76 CPU cycles, and the visible stretch (160 pixels) leaves you barely 53 cycles while the beam is actually exposing the line.

Hold onto that number. **76 CPU cycles per scanline is the single most important figure in VCS programming** — the entire craft of writing a kernel is the art of fitting everything a line needs into it. That forces a discipline no higher-level platform demands: knowing, cold, exactly how many cycles every instruction costs (a load from zero page is 3, from elsewhere 4; a taken branch is 3; and so on) and arranging your code so a line's total never spills past 76. When 76 isn't enough — and it often isn't — you get inventive: computing the *next* line's values during the slack of the current one, leaning on the faster zero-page addressing modes, unrolling loops to shed the branch. Those techniques get their own chapter in [Kernel Techniques]({{< relref "/docs/kernel-techniques" >}}), built on the instruction costs from [6502 Basics]({{< relref "/docs/6502-basics" >}}) and the frame anatomy in [The Frame Structure]({{< relref "frame-structure" >}}); for now, just register that the 76-cycle line is the drumbeat everything else marches to.

This chapter explains the anatomy of an NTSC frame — 3 lines of VSYNC, 37 lines of VBLANK, 192 visible lines, and 30 lines of overscan — and how `WSYNC` and the `REPEAT`/`REPEND` macros let you spend exactly the right number of scanlines in each region.

- **[The Frame Structure]({{< relref "frame-structure" >}})** — VSYNC, VBLANK, the visible kernel, and overscan, with the loop from `xmas.asm`.
- **[Color: Hue & Luminance]({{< relref "color" >}})** — the four color registers, how a color byte splits into hue and brightness, and the "four-color machine" you escape by rewriting colors per line.

> The frame loop is the backbone of every game in this book. Once you can produce a stable, correctly-timed frame, the playfield and sprite chapters are about *what* you write during the visible scanlines.
