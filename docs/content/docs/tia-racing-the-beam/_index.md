---
title: "The TIA & Racing the Beam"
weight: 30
bookCollapseSection: true
---

# The TIA & Racing the Beam

The Television Interface Adapter (TIA) is the chip that makes the VCS unusual. It has no frame buffer — it generates the video signal one scanline at a time, in real time, as the electron beam sweeps across the screen. Your code must feed it the right register values *before the beam reaches the pixels they affect*. This is "racing the beam," and it shapes the structure of every VCS program.

This chapter explains the anatomy of an NTSC frame — 3 lines of VSYNC, 37 lines of VBLANK, 192 visible lines, and 30 lines of overscan — and how `WSYNC` and the `REPEAT`/`REPEND` macros let you spend exactly the right number of scanlines in each region.

- **[The Frame Structure]({{< relref "frame-structure" >}})** — VSYNC, VBLANK, the visible kernel, and overscan, with the loop from `xmas.asm`.

> The frame loop is the backbone of every game in this book. Once you can produce a stable, correctly-timed frame, the playfield and sprite chapters are about *what* you write during the visible scanlines.
