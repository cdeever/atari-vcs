---
title: "Color: Hue & Luminance"
weight: 32
---

# Color: Hue & Luminance

The TIA holds exactly four color registers, one for each thing it can draw:

| Register | Colors |
|----------|--------|
| `COLUBK` | the background |
| `COLUPF` | the playfield (and the ball, which borrows it) |
| `COLUP0` | player 0 (and missile 0) |
| `COLUP1` | player 1 (and missile 1) |

Each takes a single byte, and each is **latched** — write it once and it sticks until you overwrite it. Set `COLUBK` during startup and the background stays that color for the whole game without you ever touching it again. That, and the fact that you *can* rewrite a color register mid-frame, are the two facts the rest of this page rests on.

## What the color byte means

A color byte isn't an index into a list someone chose. Its two nibbles select two independent things:

- the **high nibble** picks the **hue** — one of 16 base colors (grey, gold, orange, red, ..., blue, green);
- the **low nibble** picks the **luminance** — how bright that hue is.

```
  $1C
   │└─ low nibble  = luminance (brightness)
   └── high nibble = hue
```

Only the **upper three bits** of the luminance nibble matter — the lowest bit is ignored — so the useful luminance values are the **even** numbers `$0, $2, $4 … $E`: eight brightness steps per hue. Sixteen hues times eight luminances is the VCS's roughly **128-color** NTSC palette. (You'll often see it quoted as 128; some hue rows repeat, so the count of *visually distinct* colors is a little lower.)

This is why so much VCS source writes colors as two clean hex digits: the first digit is "which color," the second is "how bright."

> **"Color clocks" are a different thing.** The 228 *color clocks* in a scanline are a measure of **time** across the line — see [How a Television Works]({{< relref "/docs/prerequisites/how-the-tv-works" >}}). They have nothing to do with the color *values* here, which select hue and brightness. The name collision is unfortunate; keep the two ideas apart.

## NTSC only

The same byte produces a **different hue on NTSC than on PAL** — the two standards encode color in incompatible ways, so a palette tuned for one looks wrong on the other. This book targets NTSC throughout (see [How a Television Works]({{< relref "/docs/prerequisites/how-the-tv-works" >}})), and the hue ordering above is the NTSC one.

## Finding the color you want

There is no neat RGB-style mapping to reason your way to a shade. The hues march around the spectrum in an order that's easy enough for golds, browns, and blues but frustrating elsewhere — a clean, saturated red is famously hard to land. The practical approach is empirical: open Stella's palette/color viewer, or write a quick kernel that paints `COLUBK` from a value you step with the joystick, and *look*. You'll memorize the dozen colors you actually use and look up the rest.

> For the full numeric NTSC hue/luminance chart — every value and the color it produces — see the [Stella Programmer's Guide]({{< relref "/docs/further-reading" >}}).

## The four-color machine

Count the registers again — background, playfield, player 0, player 1 — and you have the VCS's original promise: **four colors on screen at once.** That was the design expectation, and for a game built straight from the hardware's primitives it's the natural limit.

Programmers blew past it almost immediately by exploiting the one freedom the latches allow: a color register can be **rewritten between scanlines**, so the "background" can be a different color on every line, a player can shade from head to foot, and the playfield can run a gradient down the screen. The picture is still only four colors *on any single line* — but down the height of the frame it can show dozens. The technique for a sprite is [Coloring each row]({{< relref "/docs/sprites/drawing-a-player" >}}); the same idea drives the colored bands you see behind so many games' [playfields]({{< relref "/docs/playfield" >}}).

## In Practice

- **Set static colors once.** Because the registers latch, colors that never change (a fixed background, a steady score color) belong in your startup code, not your kernel — writing them every line just burns cycles from the [76-cycle budget]({{< relref "_index" >}}).
- **The ball and missiles have no color of their own.** The ball draws in `COLUPF`, missile 0 in `COLUP0`, missile 1 in `COLUP1` — change those and you move the object's color too. See [Missiles & the Ball]({{< relref "/docs/sprites/missiles-and-ball" >}}).
- **Even luminances only.** Odd low-nibble values waste a bit and look identical to the even value below them; stick to `$0, $2 … $E`.
