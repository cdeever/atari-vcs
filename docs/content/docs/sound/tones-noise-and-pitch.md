---
title: "Tones, Noise & Pitch"
weight: 20
---

# Tones, Noise & Pitch

Two registers shape *what a channel sounds like*: `AUDC` picks the waveform, and `AUDF` picks the pitch. Together they're the source of both the VCS's distinctive voice and its most infamous flaw — it can't play in tune.

## AUDC: pick a voice

`AUDC` is a 4-bit selector (0–15) that routes the channel through different internal divider and polynomial-counter combinations. The result isn't 16 evenly-graded timbres but a handful of distinct *families* — pure tones, buzzy/reedy tones, and noise. The ones you'll reach for most:

| `AUDC` | Character | Typical use |
|--------|-----------|-------------|
| 4, 5 | **pure tone** (square-ish) | melodies — the cleanest pitched sound |
| 12, 13 | pure tone, lower base range | bass lines |
| 6, 10 | low pure tone | deep rumble, foghorn |
| 1, 3 | buzzy / motor-like | engines, gritty effects |
| 7, 9 | reedy buzz | voices, harsh leads |
| 8 | **white noise** | explosions, percussion, engine hiss |
| 0 | silent | (a channel set to make no tone) |

The exact character of all sixteen is genuinely best learned **by ear in [Stella]({{< relref "/docs/getting-started/toolchain" >}})** — sweep `AUDC` through its values with a fixed `AUDF` and listen. But two anchors carry most games: **4 for a melody tone** and **8 for noise.**

## AUDF: pick a pitch — sort of

`AUDF` is a 5-bit **divisor**, 0–31. The channel's frequency is the fixed audio clock divided by `AUDF + 1` (and by the waveform's own divider). Two consequences fall out of that:

- **Only 32 steps.** Each waveform can produce just 32 base pitches. That's it.
- **The steps are wildly uneven.** Because frequency is `clock ÷ (AUDF + 1)`, the available pitches follow a *harmonic series*, not a musical scale. Near the top (`AUDF` = 0, 1, 2…) consecutive steps are nearly an **octave** apart — you simply cannot get most notes up there. Near the bottom (`AUDF` = 29, 30, 31) the steps are a few cents apart — far finer than you need. All the resolution is in the bass; the treble is a coarse ladder.

Musical notes, by contrast, are spaced in equal *ratios* — every semitone is the same multiplier. Those ratios almost never line up with the integer divisors, so most notes land audibly **sharp or flat**. This is why VCS music has its unmistakable slightly-wrong charm: the hardware physically can't hit a tempered scale.

## Living with the out-of-tune problem

You don't compute pitches at run time; you build a **note → `AUDF` lookup table**, choosing for each musical note the divisor (and sometimes the `AUDC` mode) whose frequency lands closest:

```asm
NoteTable:          ; AUDF value for each note your song uses
    .byte 31        ; a low note — lands close, lots of resolution here
    .byte 23
    .byte 16
    ; ...
```

A song then refers to notes by *index* into this table — which is exactly what the `Song` data in `xmas/xmas.asm` does, and what the [next page]({{< relref "playing-music" >}}) plays back. Composers either lean into the detuning as part of the sound, or write melodies that favor the notes the hardware happens to hit cleanly.

## In Practice

- **Build the note table by ear, not by formula.** A computed equal-tempered table will be *uniformly* a little off; hand-picking the nearest divisor per note (and auditioning it) usually sounds better than the math.
- **Switching `AUDC` can rescue a note.** A pitch that's badly off in one waveform's range may land closer in another's. Bass notes especially benefit from the lower-base modes (12/13).
- **Noise has "pitch" too.** `AUDF` still applies under `AUDC` 8 — a low `AUDF` gives a deep rumble, a high one a thin hiss. An explosion is often noise with `AUDF` ramped downward over a few frames.
