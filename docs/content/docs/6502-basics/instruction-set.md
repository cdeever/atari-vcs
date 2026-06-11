---
title: "The Instruction Set"
weight: 30
---

# The Instruction Set

The 6502's instruction set is small — about 56 mnemonics — and you can write whole games with maybe two dozen of them. This page is a grouped tour, not an exhaustive datasheet: enough to recognize what you read and reach for what you need. Cycle counts live in [Cycles & Timing]({{< relref "cycles-and-timing" >}}); flag effects are in [Registers & Status Flags]({{< relref "registers" >}}).

## Moving data

The most common instructions by far — nothing computes until data is in a register.

- **Load:** `LDA` `LDX` `LDY` — register ← memory (or an immediate). Sets N and Z.
- **Store:** `STA` `STX` `STY` — register → memory. Sets no flags. This is how you write every TIA/RIOT register.
- **Transfer:** `TAX` `TAY` `TXA` `TYA` — copy between A and an index register (2 cycles, sets N/Z). `TSX`/`TXS` move between X and the [stack pointer]({{< relref "stack-and-subroutines" >}}).

## Arithmetic and logic (through A)

All of these operate on the accumulator.

- **Add / subtract:** `ADC` (add with carry), `SBC` (subtract with carry). There is no plain add — the carry is always involved, so `CLC`/`ADC` and `SEC`/`SBC` are the idioms ([Numbers & Arithmetic]({{< relref "/docs/prerequisites/numbers" >}})).
- **Bitwise:** `AND` `ORA` `EOR` — clear, set, and toggle bits against a mask ([Thinking in Bits]({{< relref "/docs/prerequisites/bits" >}})).
- **`BIT`** — sets Z from `A AND memory`, and copies memory bits 7→N and 6→V. The standard way to test a register's top two bits (collisions, inputs) without touching A.

## Counting and shifting

- **Increment / decrement:** `INX` `DEX` `INY` `DEY` on the index registers (2 cycles); `INC` `DEC` on a memory location (read-modify-write, 5–7 cycles). *Note:* there is no `INA` — you can't increment A directly; use `CLC`/`ADC #1`.
- **Shift / rotate:** `ASL` `LSR` `ROL` `ROR` — move bits left/right by one, through the carry. `ASL`/`LSR` are your ×2 and ÷2 ([Numbers]({{< relref "/docs/prerequisites/numbers" >}})).

## Comparing

- **`CMP` `CPX` `CPY`** — subtract (register − memory) *without storing the result*, just to set the flags. Follow with a branch: `CMP #10` then `BCS` ("≥ 10"), `BEQ` ("= 10"), `BCC` ("< 10").

## Branching and jumping

- **Branches** test one flag and are *relative* (a short hop, ±127 bytes): `BEQ`/`BNE` (Z), `BCS`/`BCC` (C), `BMI`/`BPL` (N), `BVS`/`BVC` (V).
- **`JMP`** — unconditional jump (absolute or indirect).
- **`JSR` / `RTS`** — call and return from a subroutine, using the [stack]({{< relref "stack-and-subroutines" >}}).

## Stack and flags

- **Stack:** `PHA`/`PLA` push and pull A; `PHP`/`PLP` push and pull the status register.
- **Flag set/clear:** `CLC` `SEC` (carry), `CLD` `SED` (decimal), `CLV` (overflow), `CLI` `SEI` (interrupt — moot on the VCS).
- **`NOP`** — do nothing, for 2 cycles. Sounds useless; it's a precision tool for [burning exact time]({{< relref "/docs/kernel-techniques" >}}) in a kernel.

## In Practice

- **A handful does almost everything.** A typical kernel line is some mix of `LDA`/`LDX`/`STA`/`INX`/`DEX`/`BNE` and a `STA WSYNC`. Master those and most VCS source reads fluently.
- **Stores set no flags — loads do.** Because `LDA`/`AND`/`INX` already update Z and N, you can often branch immediately without a separate `CMP`. Recognizing when the flag is "already right" saves both bytes and cycles.
- **There's no multiply, divide, or `INA`.** The gaps in the set are as defining as its contents — they're why [shifts, tables, and BCD]({{< relref "/docs/prerequisites/numbers" >}}) carry so much weight in 6502 code.
