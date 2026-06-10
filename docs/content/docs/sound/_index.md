---
title: "Sound"
weight: 80
bookCollapseSection: true
BookIcon: sound
---

# Sound

The TIA has two independent audio channels, each controlled by three registers: `AUDC` selects the tone/noise type (the waveform divider mode), `AUDF` sets the frequency (a 5-bit divisor — so pitch resolution is coarse and not evenly tempered), and `AUDV` sets the volume. Music and effects are produced by updating these registers over time, usually once per frame from a data-driven sequence.

This chapter covers the meaning of the `AUDC` modes, the frequency table problem (mapping musical notes onto the limited `AUDF` divisors), and a frame-counted note sequencer — the `Song` data table in `xmas/xmas.asm` is exactly this format: pairs of `(note, duration-in-frames)` terminated by a zero byte. For richer output, the `music/` project bypasses the tone generators entirely and drives the volume DAC directly.

- See the **[4-Voice Music Player]({{< relref "/docs/projects/music-player" >}})** walkthrough for the direct-DAC technique.

> The VCS's pitches are quantized to the `AUDF` divisors and are famously out of tune. Picking the closest available divisor per note — and sometimes switching `AUDC` mode — is part of writing music for it.
