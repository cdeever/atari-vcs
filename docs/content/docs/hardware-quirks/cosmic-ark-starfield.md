---
title: "Cosmic Ark's Star Field"
weight: 10
---

# Cosmic Ark's Star Field

Imagic's *Cosmic Ark* (1982) opens with a starfield so clean it looks impossible on a machine that can show [two sprites and a ball]({{< relref "/docs/sprites" >}}). Crisp white stars, evenly spaced, drifting smoothly — far more points of light than the TIA has objects to draw them with. The secret is the most celebrated **bug** in Atari history.

## A glitch nobody ordered

The effect is a single **missile** misbehaving. As [Horizontal Positioning]({{< relref "/docs/sprites/horizontal-positioning" >}}) explained, an object's position is retimed by strobing `HMOVE` — and that retiming is delicate, built on the TIA's and CPU's clocks lining up just so. Strobe `HMOVE` *the wrong way* — at the wrong point in the line, or an extra time — and the missile's position logic comes unglued: instead of moving once, the missile gets redrawn again and again across the scanline, scattering a row of evenly-spaced dots. Point that at the screen every frame and you have a starfield, conjured from one object the TIA never meant to clone.

Developer **Rob Fulop** stumbled onto it by accident while working on *Demon Attack*, watching the screen suddenly fill with stars. By his own account he never figured out *why* the player/missile registers "go crazy if diddled the wrong way" — he just wrote down the recipe and built a game around it. The underlying cause is two clock timings beating against each other, which is also why it is so hard to explain cleanly: it lives in the analog seams of the hardware, not in any documented behavior.

## The catch: it's not really *in* the spec

Because the effect depends on exact hardware timing, it is **not the same on every console.** Later revisions of the TIA tightened the behavior, so the stars can look different — or vanish — on different machines, and on some versions of the cartridge the TV Type switch flips the field on and off. It was a genuine headache for emulator authors, too: faithfully reproducing *Cosmic Ark*'s stars meant modeling the bug, not just the documented chip.

## Why it belongs here

This is the purest example of the chapter's theme. A behavior with no name in the manual, that even its discoverer couldn't fully explain, became a commercial game's signature visual — and a thing later programmers studied and reproduced on purpose. On a machine this constrained, the boundary between "defect" and "feature" was wherever someone clever decided to put it.

> The honest summary: *Cosmic Ark*'s stars are an [`HMOVE`]({{< relref "/docs/sprites/horizontal-positioning" >}}) glitch that repeats a missile across the line. It was found by accident, never fully understood, depends on the specific console, and is gorgeous — which is exactly why it's legendary. (Well documented on the [AtariAge forums](https://forums.atariage.com/topic/261596-cosmic-ark-star-field-revisited/) for the curious.)
