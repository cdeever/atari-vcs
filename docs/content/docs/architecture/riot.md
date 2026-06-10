---
title: "Memory, I/O & Timer (RIOT)"
weight: 18
---

# The Memory, I/O & Timer chip (RIOT) — a 6532

The RIOT (the 6532) — sometimes called the PIA — is the unglamorous but essential housekeeping chip. While the [TIA]({{< relref "programming-the-television" >}}) gets the glory, the RIOT quietly provides the three things every program needs but the TIA doesn't supply. Its name is an inventory of those jobs: **R**AM, **I**/**O**, and **T**imer.

## RAM — your 128 bytes

The RIOT holds the VCS's *entire* read/write memory: **128 bytes**, at addresses `$80`–`$FF`. Every variable your game keeps — score, positions, velocities, game state — lives here, and nowhere else. Internalize how little that is: a single screen's worth of modern data structures would not come close to fitting. Tight memory discipline isn't an advanced topic on the VCS; it's the baseline.

## I/O — reading the player

Two 8-bit ports connect the outside world:

- **`SWCHA`** carries the **joystick directions** for both players.
- **`SWCHB`** carries the **console switches**: Reset, Select, the two difficulty switches, and color/B&W.

Both read **active-low** — a pressed direction or held switch reads as `0`. The full treatment is in **[Input]({{< relref "/docs/input" >}})**; the point here is simply that controls come in through the RIOT, not the CPU or TIA.

## Timer — keeping time without counting cycles

The RIOT contains a **programmable interval timer** that counts down on its own once set. It lets you wait out a span of time — the vertical-blank and overscan regions are the classic use — **without** hand-counting `WSYNC`s, which becomes invaluable as your per-frame logic grows too large to eyeball cycle-by-cycle.

And because the [6507 has no interrupts]({{< relref "cpu" >}}), this timer is the *only* hardware clock you get: you set it, run your code, and poll `INTIM` to see how much time is left.

## In Practice

- The RIOT is where the *mutable* half of your program lives. The constant half — code and data tables — sits in [ROM]({{< relref "rom" >}}). Keeping that split straight (what changes vs. what's fixed) is fundamental to VCS programming.

> A debugging reflex: if a value won't *persist* between frames, that's a RAM problem (RIOT). If a control won't *read*, that's an I/O-port problem (also RIOT). Sorting the symptom to the chip narrows the hunt immediately.
