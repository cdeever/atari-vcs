---
title: "Numbers & Arithmetic"
weight: 25
---

# Numbers & Arithmetic

[Thinking in Bits]({{< relref "bits" >}}) covered a byte as a pattern of switches. This page is about a byte as a *number* — and the surprising limits of doing math on a 1977 processor. The big ones: there are only 256 possible values, negative numbers are a convention rather than a feature, and **the 6502 cannot multiply or divide at all.**

## A byte is 0–255 — or −128 to 127

An 8-bit byte holds 256 distinct values. Read as **unsigned**, that's 0 to 255. But the CPU has no separate "signed" type; instead, by convention, the **top bit is treated as a sign** using **two's complement**:

- Bit 7 clear → a positive value, 0 to 127.
- Bit 7 set → a negative value, −128 to −1.
- To negate a number, **invert every bit and add 1**. So `+1` is `%00000001`, and `−1` is `%11111111` (`$FF`).

The crucial point: the *bits are identical* either way. The byte `$FF` is "255" or "−1" depending only on how *your code* chooses to interpret it — the CPU doesn't know or care. `ADC` adds the same bits regardless; whether the result "means" 200 or −56 is your decision.

## Carrying beyond one byte

Add `200 + 100` and the true answer (300) doesn't fit in a byte. The 6502 keeps the low 8 bits and sets the **carry flag** to record the overflow. That flag is how you chain bytes together for bigger numbers:

- `CLC` then `ADC` — clear carry, then add (the standard add).
- `SEC` then `SBC` — set carry, then subtract.
- For 16-bit values (a position that exceeds 255, a score), add the low bytes, *then* add the high bytes with whatever carry came out of the first add.

The **overflow flag** (`V`) plays the same role for *signed* math, flagging when a result crossed the −128/+127 boundary.

## There is no multiply, and no divide

This is the one that reshapes how you write code: the 6502 has **no multiply or divide instruction.** You build them out of what you do have — shifts and additions ([Thinking in Bits]({{< relref "bits" >}}) covered the shifts):

- **×2 is `ASL`; ÷2 is `LSR`.** Each shift is a doubling or halving.
- **Multiply by a constant = a sum of shifts.** `x * 10` is `(x << 3) + (x << 1)` — i.e. `x*8 + x*2`.
- **Anything harder is usually a lookup table.** Rather than compute `x * y` at runtime, you precompute the results into a `.byte` table in ROM and read the answer with an indexed load. Cheap ROM beats expensive arithmetic.

## A note on decimal mode

The 6502 has a **decimal (BCD) mode**, toggled with `SED` / `CLD`, in which `ADC`/`SBC` operate on two decimal digits per byte. Its classic use is the **score**: keeping points in BCD means the value already reads as decimal digits, so displaying it is trivial. (The 6507 in the VCS supports this; the similar chip in the NES does not.)

Two things to remember: decimal mode only changes `ADC`/`SBC` — and, like any add, the `ADC` still wants a `CLC` first. The `INC`/`DEC` instructions **ignore decimal mode entirely**, so you bump a BCD score with an add (`CLC` / `ADC #$01`), never with an increment.

## Tips & Caveats

- **Velocities are just signed bytes.** Store a leftward speed as `$FF` (−1) and add it to a position; two's complement makes the subtraction "just work," wraparound and all.
- **Precompute, don't calculate.** With no multiply and a tight [cycle budget]({{< relref "/docs/6502-basics" >}}), the habit is to bake results into ROM tables ahead of time and look them up — trading scarce [RAM]({{< relref "memory-mapped" >}}) and cycles for plentiful ROM.
- **Decide signed vs. unsigned per value, and stay consistent.** The bits won't tell you which a byte is; only your code's treatment does. Mixing the two interpretations on the same value is a reliable source of "it counts up fine but breaks past 127" bugs.
