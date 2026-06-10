---
title: "Advanced Techniques"
weight: 90
bookCollapseSection: true
---

# Advanced Techniques

A bare VCS cartridge is 4 KB of ROM and the console has 128 bytes of RAM. Every commercial game larger than that — and most homebrew with ambition — reaches past those limits with cartridge hardware and software tricks. This chapter collects the techniques that come *after* you can draw a stable frame with sprites, sound, and input.

Topics include **bankswitching** (the standard schemes — F8, F6, F4, and 3F — that page extra ROM into the address space), cartridge **RAM** expansion, **sprite multiplexing** to show more than two players per frame, and display kernels that change behavior region-by-region down the screen.

> Bankswitching is invisible to the 6502 instruction set — it's triggered as a side effect of *accessing* specific cartridge addresses ("hotspots"). That means an innocent-looking `lda` of the wrong address can silently swap the code out from under you.
