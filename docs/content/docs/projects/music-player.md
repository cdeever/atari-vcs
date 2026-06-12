---
title: "4-Voice Music Player"
weight: 102
---

# 4-Voice Music Player

**Source:** `music/wavetable.a`

This project shows how far the VCS's audio can be pushed by *abandoning* its tone generators entirely. The TIA's normal `AUDC`/`AUDF`/`AUDV` path gives you two coarse, out-of-tune channels. Instead, this program treats the 4-bit volume register as a tiny **DAC** and computes the output sample by sample in software — summing four independent voices from a wavetable.

```asm
    processor 6502
    include "vcs.h"
    include "macro.h"
    include "xmacro.h"
```

Note the extra include, `xmacro.h`, which provides the `TIMER_SETUP` / `TIMER_WAIT` macros for spending a precise number of scanlines using the RIOT timer rather than counting `WSYNC`s by hand.

## Four voices in software

Each voice is a 16-bit phase accumulator (offset + delta) plus an 8-bit wavetable position, declared in zero page for fast access:

```asm
    seg.u   Variables
    org     $80

Cycle0Lo  byte      ; 16-bit wavetable offset, voice 0..3
Cycle1Lo  byte
...
Delta0Lo  byte      ; 16-bit phase increment (pitch), voice 0..3
...
WaveOfs0  byte      ; 8-bit wavetable position / volume, voice 0..3
```

Every output sample, the engine advances each voice's phase by its delta, looks up the wavetable, mixes the four results, and writes the combined value to the volume register. Pitch is set by the per-voice **delta**: a larger increment sweeps the wavetable faster, raising the note.

## The catch: no picture

The source comments say it plainly:

> *This example drives the VCS audio DAC directly to generate 4-voice music. Unfortunately, the CPU is 100% utilized so we can't display anything.*

Producing a clean audio sample stream requires the CPU's full attention on every scanline, leaving no cycles to feed the TIA's video registers. So while the demo is running, the screen is intentionally blank. This is the fundamental VCS tradeoff at its most extreme — **there is one CPU, and time spent on sound is time not spent on picture.**

## Tips & Caveats

- **This is the opposite end of the spectrum from the [Christmas tree]({{< relref "xmas-tree" >}}).** That demo spends nearly all its time on `WSYNC`s and none on computation; this one spends all of it computing audio. Most real games live in between, budgeting cycles across both.
- **Source is `wavetable.a`, not `.asm`.** `cd music && make` builds it; the underlying command names the `.a` source and the shared headers explicitly:
  ```sh
  dasm wavetable.a -I../include -f3 -v0 -omusic.bin -smusic.sym -lmusic.lst
  ```
- **Zero page matters.** All the per-voice state lives at `$80+` (zero page) because zero-page addressing is a cycle cheaper per access — and in an inner loop that runs every sample, those cycles are the difference between hitting the audio rate and not.

> The takeaway isn't the wavetable math — it's the *budget*. On the VCS every feature is paid for in CPU cycles drawn from the same 76-per-scanline pool, and this project spends the entire pool on a single feature.
