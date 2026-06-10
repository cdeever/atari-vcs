---
title: "Collisions"
weight: 60
bookCollapseSection: true
---

# Collisions

The TIA detects collisions in hardware. As the beam draws each scanline, the chip notices whenever two objects are lit at the same pixel and sets a bit in one of its collision latch registers (`CXM0P`, `CXM1P`, `CXP0FB`, `CXP1FB`, `CXM0FB`, `CXM1FB`, `CXBLPF`, `CXPPMM`). You don't compute overlaps yourself — you *read* these latches, typically during overscan, and act on them.

This chapter covers which register reports which pair of objects, reading the latches (the result is in the top bits, so you test with `bit` and branch on N/V), and the essential discipline of clearing them every frame with a write to `CXCLR` so last frame's collisions don't linger.

> Collisions accumulate until cleared. Forgetting the `CXCLR` write each frame is a classic bug: a single touch appears to last forever.
