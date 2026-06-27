---
title: "A Grab Bag of Clever Abuses"
weight: 30
---

# A Grab Bag of Clever Abuses

Not every exploited quirk got its own legend like [Cosmic Ark]({{< relref "cosmic-ark-starfield" >}}) or [Yars' Revenge]({{< relref "yars-revenge-neutral-zone" >}}). Many became everyday tools — techniques born from a limitation that programmers simply learned to live inside. A sampler.

## Flicker: more objects than the hardware has

The TIA gives you exactly [two players]({{< relref "/docs/sprites" >}}). Plenty of games need to show three, four, or a dozen moving things — the ghosts chasing Pac-Man, a field of asteroids, a wall of *Warlords* bricks. The answer is **flicker**: draw some objects on even frames and the rest on odd frames, reusing the same two players for different things each pass. At 60 frames a second, each object appears only 30 times a second, and the eye mostly fuses them into a steady crowd.

"Mostly" is the catch — you can *see* the flicker, the tell-tale shimmer of a 2600 game punching above its object count. It's a limitation made visible, and an entire generation simply accepted it as the look of the machine. (Doing it *well* — spreading objects across frames to minimize the shimmer — is a [Kernel Techniques]({{< relref "/docs/kernel-techniques" >}}) and [sprite-multiplexing]({{< relref "/docs/sprites/sprite-multiplexing" >}}) art.)

## The HMOVE comb, worn proudly

[Strobing `HMOVE`]({{< relref "/docs/sprites/horizontal-positioning" >}}) every scanline blanks the leftmost eight pixels of each line — the "HMOVE comb," a row of black notches down the left edge. It's a side effect, not a feature, but plenty of games just **let it show**: once you know to look for those left-edge teeth, you'll spot them in title after title. Others hid it (Cosmic Ark famously papered over its comb with a black missile), and modern homebrew has tricks to cancel it — but for years it was simply part of how a moving-sprite game looked.

## Undocumented opcodes

The 6502 has [official instructions]({{< relref "/docs/6502-basics/instruction-set" >}}) — and a shadow set of **undocumented** ones, accidental combinations of the chip's internal signals that do useful things the designers never published (loading two registers at once, for instance). In a kernel scrounging for [a single cycle or byte]({{< relref "/docs/6502-basics/cycles-and-timing" >}}), those unofficial opcodes were too tempting to ignore, and some games used them. The risk: nothing guaranteed every chip would behave identically, so it was a bet on the silicon — usually a safe one, occasionally not.

## Borrowing objects for the wrong job

The gentlest quirk of all is just *using an object for something it wasn't named for*. The [ball]({{< relref "/docs/sprites/missiles-and-ball" >}}) becomes a wall, a divider, a status pip; a missile becomes a laser or a fence post; a [player copy]({{< relref "/docs/sprites/size-and-copies" >}}) becomes a row of identical enemies. None of these are bugs — but they come from the same instinct: the hardware gives you a handful of primitives, and the game is whatever you can talk them into being.

> The thread through all of it: on a machine this small, *every* feature was somebody refusing to accept a limit. Bug, side effect, or undocumented corner — if it put another pixel or saved another cycle, it was fair game.
