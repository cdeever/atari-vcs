---
title: "Driving & Keyboard Controllers"
weight: 40
---

# Driving & Keyboard Controllers

The joystick, paddle, and console switches are the common cases — but the same controller ports accept stranger devices, and two are worth knowing because they show how flexible the VCS's I/O really is. The **driving controller** is a paddle look-alike that isn't analog at all, and the **keyboard controller** is a twelve-key matrix. Both are built entirely from the `SWCHA` and `INPT` registers you've already met.

## The driving controller (Indy 500)

Packaged with *Indy 500* (1977), the CX20 driving controller has a knob just like a [paddle]({{< relref "paddles" >}}) — but it works on a completely different principle. A paddle is an analog potentiometer reporting an **absolute** position. The driving controller is a **quadrature encoder**: it spins a full 360° with no stops and reports only **relative** motion. And it's read **digitally**, through `SWCHA`, like a joystick — never through the analog `INPT` lines.

As the wheel turns, two of that player's [`SWCHA` direction bits]({{< relref "the-joystick" >}}) cycle through a 2-bit **gray code** — the sequence `00 → 01 → 11 → 10 → 00`, in which only one bit changes at each step. The *direction* the sequence runs tells you which way the wheel turned; the *rate* it changes tells you how fast. So you don't ask "what position is the knob in"; you **compare this frame's two bits to last frame's and step a tracked value up or down** — the [edge-tracking]({{< relref "buttons-and-switches" >}}) habit again, applied to rotation. (Its trigger is the ordinary fire button on `INPT4`/`INPT5`.)

That's why two controllers near-identical to the eye are programmed nothing alike: a paddle you **sample**, a driving controller you **integrate**.

## The keyboard controller

The keyboard (keypad) controller is a **4×3 matrix of twelve keys** — `1`–`9`, plus `*`, `0`, `#` — used by titles like *Star Raiders*, *BASIC Programming*, and *Codebreaker*. Twelve keys won't fit in a few input bits, so it's **scanned** like any keypad — and the scan reveals something the joystick hid: **the controller port is bidirectional.**

The four directional lines of `SWCHA` are normally *inputs* (that's how you read a joystick). But the RIOT has a **data-direction register, `SWACNT`**, that can flip them to *outputs*. The keyboard controller relies on exactly that:

1. **Make the rows outputs.** Write `SWACNT` to turn a player's four `SWCHA` lines into outputs — these are the four matrix **rows**.
2. **Energize one row** by driving it low through `SWCHA`, then wait briefly — the paddle-line capacitors need a few hundred microseconds to settle.
3. **Read the three columns** on the input lines: the fire button (`INPT4`/`INPT5`) and the two paddle lines (`INPT0`/`INPT1`). A pressed key in the energized row pulls its column **low**.
4. **Repeat for all four rows**, one per pass, to read the whole keypad.

A keypress is found at the intersection of "which row am I driving" and "which column reads low" — a textbook matrix scan, assembled from registers you already know, with `SWCHA` simply wearing its output hat.

## The bigger point

- **The "joystick port" is a general I/O port.** `SWACNT` (and its `SWCHB` counterpart `SWBCNT`) make the directional lines inputs *or* outputs. A joystick uses them as inputs; the keyboard controller drives them as outputs; homebrew uses the same trick to talk to all kinds of custom hardware.
- **Look-alikes aren't work-alikes.** The driving controller is a digital encoder, not an analog paddle — read it like a paddle and you get nothing. Program to how a controller *works*, never how it looks.
- **Scanning costs time.** Four rows, each with a settle delay, means a full keypad read is spread across several passes — paced over the frame, like everything else on the VCS.

> Two controllers, one lesson: the VCS doesn't really have a "joystick port" and a "paddle port." It has a flexible bidirectional interface, and a joystick, a paddle, a spinner, and a keypad are just different things to wire to the same pins — and different code to make sense of them.
