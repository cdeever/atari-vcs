---
title: "Input"
weight: 70
bookCollapseSection: true
BookIcon: input
---

# Input

Player input arrives through two paths. The joystick directions and the console switches (Reset, Select, color/B&W, the difficulty switches) are read as digital bits from the RIOT chip's I/O ports `SWCHA` and `SWCHB`. The fire button and paddle/light-gun inputs come through the TIA's `INPT0`–`INPT5` registers. Reading them is just a load and a bit test — the work is in debouncing, edge detection, and mapping bits to game actions.

This chapter covers `SWCHA`'s nibble layout (one player per nibble, active-low), reading the fire button from `INPT4`/`INPT5`, polling the console switches in `SWCHB`, and the timing-capacitor trick used to read analog paddles.

> Joystick and switch bits are active-low: a pressed direction reads as `0`, not `1`. Test with `bit`/`bmi` against the right mask rather than comparing to a positive value.
