---
title: "Paddles"
weight: 30
---

# Paddles

Everything so far has been a switch: on or off, one bit. **Paddles** are different — they're *analog*, a knob that turns through a continuous range — and the VCS has no analog-to-digital converter. Reading one is a small, clever piece of analog timing, and it's the most unusual input on the machine.

## Reading time, not voltage

A paddle is a **potentiometer**: turning the knob changes a resistance. The TIA reads it by charging a capacitor *through* that resistance and **timing how long the charge takes** — a low resistance charges fast, a high resistance slowly. The charge time is the knob position.

The four paddle lines are `INPT0`–`INPT3` (two paddles per controller port). Each works the same way, and the read spans a whole frame:

1. **Dump.** Set bit 7 of `VBLANK` to ground the capacitors and hold them fully discharged. `INPTx` bit 7 reads `0`.
2. **Release.** Clear that bit — usually at the top of the frame — and the capacitor begins charging through the paddle's resistance.
3. **Count.** On each scanline, check `INPTx` bit 7. It stays `0` until the capacitor crosses the input threshold, then snaps to `1`. **Count the scanlines until it flips** — that count *is* the paddle value.

A knob turned one way charges in a handful of lines; turned the other way it may take most of the frame (or longer). So a paddle position arrives as "how many scanlines did it take," accumulated across the frame and read out for the next one.

## The trigger lives elsewhere

A paddle also has a fire button, and — confusingly — it does **not** come in through `INPTx`. The paddle triggers are wired to the [`SWCHA`]({{< relref "the-joystick" >}}) port, on the same lines the joystick uses for left/right. So a paddle game reads the *knob* from `INPT0`–`INPT3` and the *button* from `SWCHA`, [active-low]({{< relref "the-joystick" >}}) as always.

## In Practice

- **A paddle read costs a frame.** You start the charge at the top of the frame and harvest the count by the bottom, using it next frame. That's fine at 60 Hz, but it means paddle input is inherently one frame behind — plan for it.
- **The response is nonlinear and needs scaling.** The RC charge curve isn't a straight line, and the usable scanline count is limited, so raw paddle values are coarse and uneven across the knob's travel. Games map the count through a table or a bit of math to get smooth, calibrated control — exactly the kind of [precompute-with-a-table]({{< relref "/docs/prerequisites/numbers" >}}) trick the rest of the book favors.
- **Up to four paddles, two per port.** `INPT0`/`INPT1` are the two paddles on the left port, `INPT2`/`INPT3` the right — which is how four-player paddle games like *Warlords* read everyone at once.
- **Not every knob is a paddle.** The *Indy 500* "driving controller" looks identical but is a digital encoder, not an analog pot — read it like a paddle and you get nothing. It's covered in [Driving & Keyboard Controllers]({{< relref "other-controllers" >}}).

> The mental model: the joystick hands you a bit; the paddle hands you a *stopwatch reading*. You don't measure the knob — you race the capacitor and count how long it took.
