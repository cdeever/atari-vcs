---
title: "Introduction"
weight: 5
BookIcon: intro
---

# Introduction

If you arrive here from modern software development, much of your hard-won instinct will work *against* you. The things a career is built on — rich standard libraries, layers of hardware abstraction, portable code that runs anywhere — none of it exists on the VCS. There is no operating system to call, no driver sitting between you and the silicon, and nothing you write will run on any machine but this one. As a certain Jedi master would put it:

> *"You must unlearn what you have learned."*

What does that unlearning look like? Underneath, the whole Atari is just **four main chips** — four integrated circuits — plus the television they drive. Nearly every layer a modern program stands on simply isn't here; strike those out, and what's left is the bare metal:

<div class="center-table">

| Modern Programming | VCS/2600 Programming |
|---|---|
| ~~Cloud APIs~~ | **6507** — the CPU |
| ~~Containers~~ | **TIA** — Television Interface Adapter (video & sound) |
| ~~Frameworks~~ | **RIOT** — RAM, I/O & timer (a 6532) |
| ~~Standard Libraries~~ | **Program ROM** — your cartridge |
| ~~Drivers~~ | **CRT** — the television itself |
| ~~Operating System~~ | *four chips and a TV — that's the whole machine* |

</div>

<p style="text-align:center; color:var(--text-muted); font-size:0.9rem; margin-top:-0.5rem;"><em>Strip away the abstractions — on the VCS, your code talks directly to the hardware.</em></p>

Take that less as a warning than as an invitation. Stripped of the abstractions, you get to see exactly what the machine is doing on every cycle — and that directness is the whole appeal.

## The job is to generate a television signal

So what *is* the work? At its core, programming the VCS means writing software that **generates a television signal in real time** — and does it while simultaneously reading the joystick and responding to the player. There is no frame buffer to quietly draw into and hand off; your code and the electron beam travel down the screen together, in lockstep. Because of that, the *shape* of a VCS program mirrors the shape of a TV picture itself: an outer loop that repeats once per frame, and inside it the steady march of scanlines that compose that frame. You never call a "draw the screen" routine — your code, ticking line by line, *is* that routine. It's telling that in the 1970s these were sold as **TV games** rather than "video games": the television wasn't merely where the game showed up, it was the thing you were programming.

It helps to know what the machine was *for*. The VCS was conceived as a programmable home version of the arcade hits of its moment — *Tank* and *Pong* — a single box that could play many variations of both. That origin is stamped into the hardware: the graphics primitives it hands you are almost exactly what those two games need, and no more. That's why the chip gives you two movable players, two shots, a ball, and a simple walled background rather than anything more general — and why, ever since, getting it to draw something it *wasn't* designed for has been the whole sport. We'll meet those primitives one at a time; just know the oddly specific shape of the hardware is a fossil of the games it was built to play.

## The whole machine is four chips

And there isn't much machine to come to grips with. The whole console is essentially **four chips** sharing one bus:

- the **processor** (a 6507) that runs your code,
- the **video & sound chip** (the TIA) that generates the picture and audio,
- the **memory, I/O & timer chip** (the RIOT) that holds your variables, reads the controls, and keeps time, and
- the **program ROM** on your cartridge.

That's the entire cast. We'll meet each one properly in [VCS Architecture]({{< relref "/docs/architecture" >}}); for now it's enough to know the lineup is short and you will come to know every part of it intimately.

## How to read this book

You can't paint until you know your palette. The chapters move from that palette outward: first the hardware and the tools that reach it, then the CPU, then the TIA and the craft of drawing by "Racing the Beam," and finally sprites, input, sound, and getting a finished game onto real hardware. Each chapter is grounded in real, assembling code from this repository, so you can always read the explanation and then the source that proves it.

When you're ready, start with **[Prerequisite Knowledge]({{< relref "/docs/prerequisites" >}})**.
