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

The whole top-to-bottom pass is one **frame**. The set repaints the entire frame about **60 times a second**, far faster than the eye can follow — so by **persistence of vision**, the glowing phosphors and the rapid succession of frames fuse into one steady, full-motion picture, even though the beam is only ever lighting a single point at a time.

## Sync tells the TV where the beam should be

On its own, a television can't hold a perfectly stable picture. Inside the set are electronic timing circuits that drive the electron beam horizontally across the screen and then back to the top for the next frame. Those circuits are built to run at almost exactly the right speed — but "almost" isn't good enough. Like any analog oscillator, they slowly drift.

To understand why, imagine a runner trying to maintain an **8:00-minute-per-mile pace** with nothing — and no one — to help them hold it. A skilled runner might stay close for a while, but over the course of several miles they'll gradually speed up or slow down. Now imagine another runner — the official pacer — running exactly 8:00 pace. Every few seconds our runner glances over, notices they're a step ahead or behind, and makes a tiny correction. Most of the time the adjustment is so small you wouldn't even notice it.

A television works much the same way. It already knows roughly how fast to sweep the beam across the screen, but it constantly needs tiny corrections to keep the picture perfectly aligned. Those corrections come from **sync pulses** embedded in the video signal.

- A **horizontal sync pulse** arrives once per scanline and says, "This line starts here."
- A **vertical sync pulse** arrives once per frame and says, "This frame starts here."

The television isn't being told how to move the beam every instant. It's already doing that on its own. Instead, the sync pulses act like the runner's occasional glance at the pacer, gently correcting the timing before it has a chance to drift. The beam stays locked to the broadcaster's timing, line after line and frame after frame.

On a conventional analog television broadcast — the over-the-air signal that fed living-room sets for decades before digital television — these sync pulses were quietly embedded alongside the picture itself. Under normal conditions, the viewer never knew they were there. You only noticed them when something interrupted the timing: the picture would roll vertically, tear horizontally, or lose lock altogether.

### When the picture loses lock

If the sync was weak, mistimed, or missing — a fading antenna, a worn videotape, a marginal cable — the television's free-running oscillators had nothing solid to lock onto, and the picture broke in two telltale ways:

- **Vertical roll.** Without a clean vertical-sync pulse, the set couldn't find the top of the frame, so the whole image slid continuously up or down the screen — the black bar between frames tumbling past again and again.
- **Horizontal tearing.** With unstable horizontal sync, lines stopped beginning at the same place, and the picture sheared into diagonal slants or dissolved into a herringbone of broken lines.

Older sets handed the viewer direct control over those very oscillators, as two knobs usually on the back or side: **Vertical Hold** and **Horizontal Hold**. Each nudged the free-running frequency of one oscillator up or down. When the picture rolled, you turned Vertical Hold until the frame caught and snapped still; when it tore or skewed, Horizontal Hold did the same. You were, quite literally, hand-tuning the runner's natural pace until it fell back into step with the beat in the signal.

{{< vcsanim scene="crt-scan" caption="The beam scans line by line, refreshing a test pattern. Detune *Vertical Hold* and the frame rolls; detune *Horizontal Hold* and it tears. Center both to re-lock — just like the back-panel knobs." >}}

That is the medium the VCS must satisfy. Generating those sync pulses at exactly the right moments — so the television never has a reason to roll or tear in the first place — is the job of the console's video chip and your program, taken up in [The Video & Sound Chip (TIA)]({{< relref "/docs/architecture/programming-the-television" >}}) and [The Frame Structure]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}).

## Inside a single scanline

You've watched the beam march down the frame one line at a time. Now zoom in on a single line. A scanline is a continuous **left-to-right sweep**, not a row of pixels — there is no grid of dots underneath it, only a beam moving across. What sets the limit on how finely the picture can change along that sweep is the **color clock**.

A **color clock** is the smallest unit of horizontal timing on the signal — the finest grain at which the picture can change as the beam crosses the line, ticking at the TV's color reference rate (about 3.58 million times a second on NTSC).

A full scanline is **228 color clocks** wide, but not all of it is picture. About **160** carry the visible image; the other **68** are spent on the **horizontal blank** — the beam switched off, snapping back to the left for the next line (the HBLANK from earlier). So the horizontal "canvas" a single line offers is only about **160 steps** wide. There's no pixel grid and no resolution dial: how much horizontal detail you get is simply how finely those ~160 visible clocks are divided up.

## Frames per second, and the two standards

A TV redraws the whole frame many times a second to produce a steady image. How many — and how many scanlines make up a frame — depends on the regional broadcast standard the set was built for. Two dominate, with a third worth naming:

| | **NTSC** | **PAL** |
|---|---|---|
| Where | North America, Japan | much of Europe, Australia |
| Refresh rate | ~60 frames/sec | ~50 frames/sec |
| Scanlines per frame | **262** | **312** |
| Active (visible) lines | ~240 | ~288 |
| Color clocks per line | 228 (~160 visible) | 228 (~160 visible) |

Both standards build a line the same way — the **228 color clocks** from the previous section — so a single scanline takes exactly as long on either. What differs is the **number of lines** in a frame and the **refresh rate**: a PAL frame is taller (more scanlines) and arrives more slowly. And because the picture is only ever as tall as the **visible scanlines** drawn between the blanking margins, that line count *is* the vertical dimension — there's no separate vertical-resolution setting, just lines, and they must total the standard's count (262 for NTSC) or the set loses sync. PAL and NTSC also encode color completely differently, so the same color value shows as a different hue on each.

A third standard, **SECAM** (France, the former Soviet bloc, and parts of Africa and the Middle East), shares PAL's taller 50 Hz frame but encodes color differently again. It rarely enters into VCS work, so it's named here only for completeness — **this book targets NTSC throughout.**

So a television has no fixed resolution to dial in — its picture size simply *emerges* from the signal's timing: the width from how many color clocks a line spends on picture, the height from how many of the standard's lines it lights. How a VCS program decides those things — filling that width, choosing those lines — is the craft picked up in the [Playfield]({{< relref "/docs/playfield" >}}) and [Sprites]({{< relref "/docs/sprites" >}}) chapters. That's the mental shift this whole chapter is preparing you for: there is no buffer and no resolution dial — only a beam, a clock, and a signal deciding what to show at each tick.

## Tips & Caveats

- **Broadcast TV is interlaced; console signals usually aren't.** A broadcast frame interlaces two half-frames ("fields") for extra vertical detail — 525 lines on NTSC all told. A game console like the VCS skips interlacing and redraws the same ~262-line frame every time, a "240p-style" signal that sets accept happily — which is why that 262 looks low beside the 525 broadcast figure.
- **NTSC and PAL are not interchangeable.** The two standards differ in refresh rate, line count, and color encoding, so a program written for one will not simply work on the other — the different timing ripples all the way down into the code, which has to target a specific standard. Those consequences are taken up where the frame is built, in [The Frame Structure]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}).
- **The beam never waits.** A scanline lasts a fixed slice of time, and the beam moves on whether or not the source is ready — anything not delivered in time simply isn't drawn. On the VCS this hardens into a strict per-line cycle budget, the subject of [Racing the Beam]({{< relref "/docs/tia-racing-the-beam" >}}).
