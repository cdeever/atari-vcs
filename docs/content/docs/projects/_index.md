---
title: "Project Walkthroughs"
weight: 100
bookCollapseSection: true
BookIcon: projects
---

# Project Walkthroughs

The concept chapters explain the hardware one feature at a time. These walkthroughs put the pieces together by reading real, complete programs from this repository end to end — how the frame loop, playfield, and data tables combine into something that runs.

- **[Christmas Tree Demo]({{< relref "xmas-tree" >}})** — `xmas/xmas.asm`: a playfield-only kernel that draws a tree by rewriting `PF0`/`PF1`/`PF2` down the screen, plus an embedded song data table.
- **[4-Voice Music Player]({{< relref "music-player" >}})** — `music/wavetable.a`: a CPU-saturating routine that drives the audio DAC directly for four-voice music (and therefore shows no picture).

> These are the same projects the repository's root `CLAUDE.md` describes. Read the walkthrough alongside the actual `.asm` to see how the book's concepts appear in working code.
