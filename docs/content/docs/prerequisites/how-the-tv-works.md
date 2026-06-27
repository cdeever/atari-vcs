---
title: "How a Television Works"
weight: 10
---

# How a Television Works

Before the VCS makes sense, the *television* has to. Every concept in this book — the frame loop, sync signals, "Racing the Beam," the cycle budget — is a direct consequence of how a cathode-ray-tube TV paints a picture. You don't need a broadcast-engineering course; you need the handful of facts the hardware forces you to care about.

## The beam paints one line at a time

A CRT television draws its image with a single **electron beam** that sweeps across the screen from behind. It moves in a fixed pattern:

1. Starting at the top-left, it sweeps **left to right**, lighting the phosphors as it goes — that's one **scanline**.
2. At the right edge it switches off and snaps back to the left, ready for the next line down. This return trip is the **horizontal blank** (HBLANK); nothing is drawn during it.
3. It repeats line by line down the screen until it reaches the bottom.
4. Then it switches off and snaps back up to the top-left to begin the next image. This return is the **vertical blank** (VBLANK).

The whole top-to-bottom pass is one **frame**. The beam never stops moving; your only control over the picture is *what the beam is told to output at each instant as it travels.*

## Sync tells the TV where the beam should be

The television has no idea where a "line" or a "frame" begins on its own — it has to be told, by **sync** pulses buried in the video signal:

- A **horizontal sync** pulse marks the start of each new scanline.
- A **vertical sync** pulse marks the start of each new frame.

It helps to picture the TV not as passive but as a runner in a race trying to lock in on a perfect 8:00-minute-per-mile pace. The set's sweep circuitry has its own internal oscillators that already move the beam at *very nearly* the right speed — like a trained runner who can hold close to that pace from memory. Close, but not perfect: left alone, the timing slowly drifts. The sync pulses are the beat the runner locks onto, a metronome embedded in the signal. Each **horizontal** pulse is a tick that keeps every line on tempo; each **vertical** pulse is the downbeat that says *back to the top, a new frame begins.* The pulses don't drag the beam around from scratch — they keep an already-moving beam **locked** to the exact timing, the way a runner holds a perfect pace by matching a beat instead of guessing.

On a conventional analog television broadcast — the over-the-air signal that fed living-room sets for decades, before digital transmission took over — these sync pulses arrive embedded in the incoming signal, and a healthy set re-locks to them line after line, frame after frame, with no one the wiser. You only learned they were there when something went wrong with them.

### When the picture loses lock

If the sync was weak, mistimed, or missing — a fading antenna, a worn videotape, a marginal cable — the television's free-running oscillators had nothing solid to lock onto, and the picture broke in two telltale ways:

- **Vertical roll.** Without a clean vertical-sync pulse, the set couldn't find the top of the frame, so the whole image slid continuously up or down the screen — the black bar between frames tumbling past again and again.
- **Horizontal tearing.** With unstable horizontal sync, lines stopped beginning at the same place, and the picture sheared into diagonal slants or dissolved into a herringbone of broken lines.

Older sets handed the viewer direct control over those very oscillators, as two knobs usually on the back or side: **Vertical Hold** and **Horizontal Hold**. Each nudged the free-running frequency of one oscillator up or down. When the picture rolled, you turned Vertical Hold until the frame caught and snapped still; when it tore or skewed, Horizontal Hold did the same. You were, quite literally, hand-tuning the runner's natural pace until it fell back into step with the beat in the signal.

{{< vcsanim scene="crt-scan" caption="The beam scans line by line, refreshing a test pattern. Detune *Vertical Hold* and the frame rolls; detune *Horizontal Hold* and it tears. Center both to re-lock — just like the back-panel knobs." >}}

That is the medium the VCS must satisfy. Generating those sync pulses at exactly the right moments — so the television never has a reason to roll or tear in the first place — is the job of the console's video chip and your program, taken up in [The Video & Sound Chip (TIA)]({{< relref "/docs/architecture/programming-the-television" >}}) and [The Frame Structure]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}).

## Frames per second, and the two standards

A TV redraws the whole frame many times a second to produce a steady image. How many — and how many scanlines make up a frame — depends on the regional broadcast standard the set was built for. Two dominate, with a third worth naming:

| | **NTSC** | **PAL** |
|---|---|---|
| Where | North America, Japan | much of Europe, Australia |
| Refresh rate | ~60 frames/sec | ~50 frames/sec |
| Scanlines per frame | **262** | **312** |
| Active (visible) lines | ~240 | ~288 |
| Color clocks per line | 228 (~160 visible) | 228 (~160 visible) |

The two share the *same* horizontal timing — 228 color clocks per scanline — so a single line takes exactly as long on either standard. What differs is the **number of lines** in a frame and the **refresh rate**: a PAL frame is taller and arrives more slowly. PAL and NTSC also encode color completely differently, so the same color value shows as a different hue on each.

A third standard, **SECAM** (France, the former Soviet bloc, and parts of Africa and the Middle East), shares PAL's taller 50 Hz frame but encodes color differently again. It rarely enters into VCS work, so it's named here only for completeness — **this book targets NTSC throughout.**

## "Resolution" isn't a setting — it's how you spend time

An analog television has no fixed grid of pixels and no resolution dial. The picture's dimensions are just a consequence of the signal's timing:

- **Horizontally**, a scanline is a continuous sweep, not a row of pixels — but the color subcarrier limits how finely detail can change across it. In practice a line resolves on the order of **160 distinct steps** of visible width (the full line spans 228 "color clocks," with the remaining 68 lost to the horizontal-blank retrace). That is roughly the horizontal canvas a single line offers.
- **Vertically**, the picture is simply as tall as the **number of visible scanlines** drawn between the blanking margins — there is no separate vertical-resolution setting, only lines, and they must add up to the standard's total (262 for NTSC) or the set loses sync.

So on a television, "resolution" isn't a number you select; it emerges from how the signal spends its color clocks along each line and how many of the standard's lines it lights. How a VCS program decides those things — filling that width, choosing those lines — is the craft picked up in the [Playfield]({{< relref "/docs/playfield" >}}) and [Sprites]({{< relref "/docs/sprites" >}}) chapters.

That's the mental shift this whole chapter is preparing you for: there is no buffer and no resolution dial — only a beam, a clock, and a signal deciding what to show at each tick.

## Tips & Caveats

- **Broadcast TV is interlaced; console signals usually aren't.** A broadcast frame interlaces two half-frames ("fields") for extra vertical detail — 525 lines on NTSC all told. A game console like the VCS skips interlacing and redraws the same ~262-line frame every time, a "240p-style" signal that sets accept happily — which is why that 262 looks low beside the 525 broadcast figure.
- **NTSC and PAL are not interchangeable.** The two standards differ in refresh rate, line count, and color encoding, so a program written for one will not simply work on the other — the different timing ripples all the way down into the code, which has to target a specific standard. Those consequences are taken up where the frame is built, in [The Frame Structure]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}).
- **The beam never waits.** A scanline lasts a fixed slice of time, and the beam moves on whether or not the source is ready — anything not delivered in time simply isn't drawn. On the VCS this hardens into a strict per-line cycle budget, the subject of [Racing the Beam]({{< relref "/docs/tia-racing-the-beam" >}}).
