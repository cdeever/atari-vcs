---
title: "Cycles & Timing"
weight: 40
---

# Cycles & Timing

On most computers an instruction's cycle count is trivia. On the VCS it is the **central fact of the craft**: every visible scanline is [76 CPU cycles]({{< relref "/docs/tia-racing-the-beam" >}}), and a kernel that needs 77 doesn't run slow — it tears the picture. This page is the reference for counting them.

A "machine cycle" is one tick of the 6507's ~1.19 MHz clock; the TIA runs at three times that, so **one CPU cycle = three color clocks (three pixels)**. You budget in CPU cycles and the picture pays out in pixels.

## How long instructions take

Cost is set mostly by the [addressing mode]({{< relref "addressing-modes" >}}), not the operation: an `LDA` and an `AND` from the same place cost the same. Representative counts:

| Instruction form | Cycles |
|------------------|--------|
| Immediate (`LDA #n`, `AND #n`) | 2 |
| Implied / transfer / flag (`INX`, `TAX`, `CLC`, `NOP`) | 2 |
| Accumulator shift (`ASL A`) | 2 |
| Zero-page read or write (`LDA $84`, `STA $84`) | 3 |
| Zero-page,X read/write (`LDA $80,X`) | 4 |
| Absolute read or write (`LDA $F2A0`, `STA $F2A0`) | 4 |
| Absolute,X/Y **read** (`LDA addr,X`) | 4 (**+1** if it crosses a page) |
| Absolute,X/Y **store** (`STA addr,X`) | 5 (flat) |
| `(zp),Y` read | 5 (**+1** if page crossed) |
| Branch | 2 not taken · 3 taken · 4 taken + page cross |
| `JMP` abs / `JMP` (ind) | 3 / 5 |
| `JSR` / `RTS` | 6 / 6 |
| `PHA` `PHP` / `PLA` `PLP` | 3 / 4 |
| Memory `INC`/`DEC`/`ASL` etc. (read-modify-write) | 5 zp · 6 zp,X · 6 abs · 7 abs,X |

A few rules explain most of the table:

- **Reads can cost +1 across a page; stores never do.** An indexed *read* whose effective address crosses a 256-byte boundary takes an extra cycle to fix up. An indexed *store* always does the fix-up, so it's a flat (and predictable) cost — sometimes a reason to prefer a store in tight code.
- **Branches are 2 / 3 / 4.** Not taken: 2. Taken: 3. Taken to a different page: 4. A loop's *back*-branch is usually the 3-cycle case.
- **Read-modify-write is expensive.** `INC $84` is 5 cycles, not 3, because the CPU reads the byte, changes it, and writes it back — three accesses. In a kernel, `LDA`/`CLC`/`ADC #1`/`STA` is often counted against `INC` for exactly this reason.

## `WSYNC`: spend the rest of the line for free

`STA WSYNC` is a 3-cycle store like any other — but writing that TIA address **halts the CPU until the start of the next scanline** ([memory-mapped strobe]({{< relref "/docs/prerequisites/memory-mapped" >}})). It is how you stop counting cycles and just *land on the next line*: whatever cycles you didn't use are discarded, and you resume at a known point.

That makes `WSYNC` the workhorse of timing you don't need to be precise about — wait out a blank region, pad a kernel line — while leaving the genuinely tight work (mid-line [playfield rewrites]({{< relref "/docs/playfield/asymmetric" >}}), sprite positioning) to be hand-counted. `WSYNC` gets you *to* a line; counting cycles gets you to the right place *within* one.

## Counting a line

To check a kernel line fits, add the cost of every instruction from one `WSYNC` to the next and confirm the total is ≤ 76. The assembler's listing file (`.lst`) shows the bytes each line produced, and tools like Stella's debugger display a live cycle/color-clock counter — but the habit worth building is doing the arithmetic in your head as you write, because that's what lets you *feel* whether a line has room left.

## In Practice

- **The exact numbers are worth memorizing for the common forms.** Load-3-or-4, store-3-or-4, branch-2-or-3, `INX`-2: those four cover most of a kernel, and knowing them cold is the difference between writing a kernel and debugging a rolling screen.
- **Page-crossing bugs hide until they don't.** A kernel that works moves one byte, a table crosses a page, and a line silently gains a cycle. If a stable kernel tears after an unrelated edit, suspect alignment first.
- **These techniques get their own chapter.** Cycle counting is the foundation; *spending* the budget well — burning exact time, multi-line kernels, front-loading — is [Kernel Techniques]({{< relref "/docs/kernel-techniques" >}}).
