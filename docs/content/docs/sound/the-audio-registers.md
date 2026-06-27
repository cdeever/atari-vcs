---
title: "The Audio Registers"
weight: 10
---

# The Audio Registers

The TIA gives you **two independent audio channels**, and that's the whole orchestra — two voices, no more. Each channel is described by exactly **three registers**, and a sound is whatever you get by setting them and changing them over time.

| Register | Width | Sets |
|----------|-------|------|
| **`AUDC0` / `AUDC1`** | 4 bits | the **waveform** — which tone or noise shape this channel makes |
| **`AUDF0` / `AUDF1`** | 5 bits | the **frequency** — a divisor, so 32 steps, higher value = lower pitch |
| **`AUDV0` / `AUDV1`** | 4 bits | the **volume** — 0 (silent) to 15 (loudest) |

The three combine in a fixed signal path: `AUDC` and `AUDF` feed a tone/noise generator, whose output is scaled by `AUDV`, and the two channels mix to the single output:

{{< graphviz >}}
digraph aud {
  rankdir=LR;
  bgcolor="transparent";
  node [shape=box, style="filled,rounded", fontsize=10, color="#808080", penwidth=1.2];
  edge [color="#808080", penwidth=1.3];

  subgraph cluster0 {
    style=invis;
    c0 [label="AUDC0\nwaveform", fillcolor="#cfe0f5"];
    f0 [label="AUDF0\npitch", fillcolor="#cfe0f5"];
    g0 [label="tone / noise\ngenerator", fillcolor="#f6e0c6"];
    v0 [label="x AUDV0\nvolume", fillcolor="#d2efd2"];
    c0 -> g0; f0 -> g0; g0 -> v0;
  }
  subgraph cluster1 {
    style=invis;
    c1 [label="AUDC1\nwaveform", fillcolor="#cfe0f5"];
    f1 [label="AUDF1\npitch", fillcolor="#cfe0f5"];
    g1 [label="tone / noise\ngenerator", fillcolor="#f6e0c6"];
    v1 [label="x AUDV1\nvolume", fillcolor="#d2efd2"];
    c1 -> g1; f1 -> g1; g1 -> v1;
  }
  out [label="mixed\noutput", fillcolor="#e2e2e2"];
  v0 -> out; v1 -> out;
}
{{< /graphviz >}}

## What a "sound" is

There is no sound memory, no samples, no envelopes — just six registers holding their values until you change them. Write `AUDV0 = 8`, `AUDC0 = 4`, `AUDF0 = 20` and channel 0 holds a steady tone *forever*, until you touch the registers again. Everything expressive — a note that ends, a pitch that slides, a volume that fades, a drum hit — is you **rewriting these registers over time**, almost always once per [frame]({{< relref "/docs/prerequisites/how-the-tv-works" >}}).

That's the same "race against time" the rest of the machine demands, just slower: where graphics are paced to the scanline, sound is paced to the 60-per-second frame. A frame is the natural tick of VCS music.

## Two voices, and how to stretch them

Two channels means two simultaneous notes — so a melody on one channel and a bass line or drum on the other is the typical split. Want a third voice? You do what you do everywhere else on this machine: **fake it in software**, by rapidly switching one channel between two notes (an arpeggio that reads as a chord), or — at the extreme — by driving the volume register itself as a [DAC](https://github.com/cdeever/atari-vcs/blob/main/music/README.md) to synthesize richer sound, at the cost of the entire CPU.

## In Practice

- **Silence is `AUDV = 0`.** To stop a channel, zero its volume; you don't need to touch `AUDC`/`AUDF`. Many sound bugs are just a channel whose volume was never cleared, droning under everything.
- **The registers are write-only like the rest of the TIA.** If your music engine needs to know a channel's current note or volume, keep it in a [RAM variable]({{< relref "/docs/prerequisites/memory-mapped" >}}) — you can't read `AUDF` back.
- **Two channels is a real constraint.** Planning music for the VCS starts with "which two voices, this moment?" — melody and bass, or melody and percussion. The arrangement is a budgeting problem, like everything else here.
