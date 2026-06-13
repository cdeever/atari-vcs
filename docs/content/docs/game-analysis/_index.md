---
title: "Game Analysis"
weight: 105
bookCollapseSection: true
BookIcon: analysis
---

# Game Analysis

The fastest way to understand how all of this fits together is to read a *finished game* — a complete, shipped program where every technique in this book appears at once, working with the others, under real constraints. This section takes well-commented disassemblies of classic titles and maps out how they're built: the overall shape first, then the clever parts.

Each teardown opens with a **block diagram** of the program's major portions — what runs when, and how the pieces connect — and then walks the structure, pointing back to the chapters where each technique was introduced. The goal isn't to reproduce a line-by-line disassembly (those exist, and they're linked); it's to give you the *map* that makes reading one bearable.

The teardowns run roughly simplest to most elaborate — start with Pong to see the skeleton bare, then watch how much more the others hang on the same frame:

- **[Pong (a minimal teardown)]({{< relref "pong" >}})** — the irreducible minimum: two paddles, a ball, four screen regions, three collision latches. The bare frame loop with nothing else, and the best thing to read right after the basics.
- **[Combat (1977)]({{< relref "combat" >}})** — the launch pack-in, and one of the most-studied 2600 sources. Its structure *is* the frame loop this book teaches, and it's a tour of nearly every chapter in a single 2 KB ROM.
- **[Pitfall! (1982)]({{< relref "pitfall" >}})** — a 255-room jungle on a 4 KB cart, because the rooms aren't stored but *generated* from one byte by a linear-feedback shift register. The definitive "compute the world, don't store it" technique.
- **[Adventure (1980)]({{< relref "adventure" >}})** — Pitfall's mirror image: ~30 rooms *stored* as a hand-authored map, with a general object engine on top. The first action-adventure, the first Easter egg, and an early case of object-oriented, data-driven design.
- **[River Raid (1982)]({{< relref "riverraid" >}})** — Pitfall's idea turned on its side: a 16-bit shift register generates an *endless scrolling* river instead of a loop of rooms. The streaming-block technique, the cleanest full-cast use of the TIA's objects, and Carol Shaw's masterpiece.
- **[Space Invaders (1980)]({{< relref "spaceinvaders" >}})** — the killer app that sold the console, and the ultimate sprite-economy trick: a whole 36-alien formation conjured from just *two* player objects via `NUSIZ` copies and multiplexing. One 4 KB ROM, 112 different games.
- **[Video Chess (1979)]({{< relref "videochess" >}})** — the one that breaks the rule: a real look-ahead chess engine in 4 KB and 128 bytes that *turns the picture off to think*, holding `VBLANK` on and giving the whole CPU to the search. Racing the beam, inverted.
- **[Cosmic Ark (1982)]({{< relref "cosmicark" >}})** — the most famous "bug as feature" on the platform, in the actual code: a whole starfield smeared out of a *single* missile by strobing `HMOVE` and then poking `HMM0` mid-comb. Four instructions. The companion read to the [starfield quirk page]({{< relref "/docs/hardware-quirks/cosmic-ark-starfield" >}}).
- **[Breakout (1978)]({{< relref "breakout" >}})** — Space Invaders' mirror image: a complete game of ball, paddle, and bricks built almost entirely from the *playfield* (a RAM bitmap painted by an asymmetric kernel), with the two player sprites spared for nothing but the score. The Woz prototype, brought home.

> Reading other people's kernels is not cheating — it's the apprenticeship. The 2600 community has annotated many classic games precisely so the next generation can learn from them.
