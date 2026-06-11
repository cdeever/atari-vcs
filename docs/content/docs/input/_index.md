---
title: "Input"
weight: 70
bookCollapseSection: true
BookIcon: input
---

# Input

Player input arrives through two chips. The joystick directions and the console switches come from the [RIOT]({{< relref "/docs/architecture/riot" >}})'s I/O ports `SWCHA` and `SWCHB`; the fire buttons and analog paddles come through the [TIA]({{< relref "/docs/architecture/programming-the-television" >}})'s `INPT0`–`INPT5` registers. Either way, reading input is a [memory-mapped load and a bit test]({{< relref "/docs/prerequisites/memory-mapped" >}}) — cheap. The craft is in *interpreting* those bits: active-low logic, telling a held button from a fresh press, and turning a paddle's analog knob into a number at all.

Paired with [Collisions]({{< relref "/docs/collisions" >}}), this is what closes the loop from "a picture on screen" to "a game the player controls."

- **[The Joystick]({{< relref "the-joystick" >}})** — `SWCHA`'s two-players-in-one-byte layout, and the active-low rule that trips up everyone.
- **[Buttons & Console Switches]({{< relref "buttons-and-switches" >}})** — the fire buttons (`INPT4`/`INPT5`), the `SWCHB` console switches, and held-vs-just-pressed edge detection.
- **[Paddles]({{< relref "paddles" >}})** — reading an analog knob with no ADC, by timing a charging capacitor across the frame.
- **[Driving & Keyboard Controllers]({{< relref "other-controllers" >}})** — the Indy 500 spinner (a digital encoder, not a paddle) and the keypad matrix scanned by turning the port into outputs.

> Joystick and switch bits are **active-low**: a pressed direction reads as `0`, not `1`. Isolate the bit with `AND`/`BIT` and branch on zero, rather than comparing to a positive value.
