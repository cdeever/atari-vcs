---
title: "How a Television Works"
weight: 9
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

On a normal television broadcast, these sync pulses originate from the broadcast equipment. On the VCS, the TIA generates the pulses that become part of the composite video signal, and the television locks its sweep circuitry onto them. However, your program determines when the TIA should generate the critical timing events. At the start of each frame, you instruct the TIA when to assert and release vertical sync. During the frame, you pace your code to the beam, often using the `WSYNC` ("wait for sync") idiom to pause until the next scanline begins before preparing it.

The division of labor, at a glance:

| Component | Responsibility |
|-----------|----------------|
| **TV** | Keeps the beam moving and locks its sweep onto the incoming sync pulses |
| **TIA** | Generates the sync pulses and the video signal |
| **Your program** | Tells the TIA what to output and when — and when to wait for the beam (`WSYNC`) |

If this timing is wrong — if vertical sync is the wrong length, or if your code falls behind the beam — the television loses its place. The picture may roll, tear, jitter, or disappear entirely. This is why so much VCS programming is really about timing. The TV follows the TIA's signal, the TIA follows its internal timing circuits, and your program must stay synchronized with both. The mechanics of doing that in code are explored in [The Frame Structure]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}).

> **What if you skip it?** The TIA has no concept of a "frame" — left alone it just emits scanlines forever, with no top and no bottom. The 3-line vertical-sync pulse is the *only* "new frame starts here" marker the TV ever receives, and **your code is the only thing that produces it.** Forget it and the picture **rolls vertically forever**, because the TV's vertical hold has nothing to lock onto. (Horizontal sync is the exception: the TIA generates it automatically every line, so the screen stays horizontally stable on its own — you only ever *wait* for it, never create it.) And if your code runs off the end without looping back to emit the next frame, the CPU simply keeps executing whatever bytes follow as instructions — there is no operating system to catch the fall.

## Frames per second, and the two standards

A TV redraws the whole frame many times a second to produce a steady image. How many — and how many scanlines make up a frame — depends on the regional broadcast standard the set was built for. Two matter:

| | **NTSC** | **PAL** |
|---|---|---|
| Where | North America, Japan | much of Europe, Australia |
| Refresh rate | ~60 frames/sec | ~50 frames/sec |
| Scanlines per frame | **262** | **312** |
| Lines a game typically draws | ~192 visible | ~228 visible |
| Color-clocks per line | 228 (160 visible) | 228 (160 visible) |
| CPU cycles per line | 76 | 76 |

The two share the *same* horizontal timing — 228 color clocks and 76 CPU cycles per scanline — so the moment-to-moment "race" across a line is identical. What differs is the **number of lines** in a frame and the **refresh rate**: a PAL frame is taller and arrives more slowly. PAL and NTSC also encode color completely differently, so the same `COLU*` value is a different hue on each.

## "Resolution" isn't a setting — it's how you spend time

The VCS has no resolution register. The picture's dimensions are simply a consequence of timing:

- **Horizontally**, the TIA emits 160 visible "color clocks" per line (the other 68 fall in HBLANK). That 160 is your horizontal canvas — a playfield pixel is 4 color clocks wide (40 across), and a sprite is positioned to a specific color clock.
- **Vertically**, *you* decide how many scanlines to spend on the picture versus the blanking margins. Games conventionally use ~192 visible lines on NTSC, but nothing enforces it; the count is whatever your code produces, and it must add up to the standard's total (262 for NTSC) or the TV loses sync.

That's the mental shift this whole chapter is preparing you for: there is no buffer and no resolution dial, only a beam, a clock, and your code deciding what to show at each tick.

## Tips & Caveats

- **The VCS output is non-interlaced.** Broadcast TV interlaces two half-frames ("fields") for extra vertical detail; the VCS skips that and redraws the same ~262-line frame every time. Real TVs accept this "240p-style" signal, but it's why VCS line counts (262, not 525) look low next to broadcast figures.
- **Pick a target standard early.** Developing for NTSC and running on a PAL console means a slower 50 Hz game, extra scanlines to fill, and shifted colors. Decide up front and test against it; "looks right in [Stella]({{< relref "toolchain" >}})'s default NTSC" says nothing about PAL.
- **You can't get cycles back.** Because each scanline is a fixed 76 CPU cycles, work that overruns a line pushes into the next one and corrupts the picture. The beam sets the pace; your code keeps up or the image breaks. This is revisited in detail under [Racing the Beam]({{< relref "/docs/tia-racing-the-beam" >}}).
