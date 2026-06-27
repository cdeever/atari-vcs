---
title: "Sound"
weight: 80
bookCollapseSection: true
BookIcon: sound
---

# Sound

The TIA has **two independent audio channels** — the whole orchestra — each described by three registers: `AUDC` (waveform), `AUDF` (pitch), and `AUDV` (volume). A sound is whatever you make by setting those registers and changing them over time, almost always once per [frame]({{< relref "/docs/prerequisites/how-the-tv-works" >}}). There's no sample memory and no envelopes; expressiveness is rewriting six registers on a schedule.

The chapter's recurring theme is *scarcity met with ingenuity*, sound edition: only two voices, a famously out-of-tune pitch ladder, and yet a library full of memorable music.

- **[The Audio Registers]({{< relref "the-audio-registers" >}})** — the two channels, what `AUDC`/`AUDF`/`AUDV` each do, and the signal path.
- **[Tones, Noise & Pitch]({{< relref "tones-noise-and-pitch" >}})** — the `AUDC` waveform families, and why the `AUDF` divisor leaves the VCS unable to play in tune.
- **[Playing Music]({{< relref "playing-music" >}})** — a frame-counted sequencer driving a `(note, duration)` song table, plus envelopes and sound effects.

> The VCS's pitches are quantized to the `AUDF` divisors and are famously out of tune. Picking the closest available divisor per note — and sometimes switching `AUDC` mode — is part of writing music for it. For richer output, the [4-Voice Music Player](https://github.com/cdeever/atari-vcs/blob/main/music/README.md) bypasses the tone generators and drives the volume DAC directly.
