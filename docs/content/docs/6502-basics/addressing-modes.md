---
title: "Addressing Modes"
weight: 20
---

# Addressing Modes

An instruction like `LDA` doesn't just load — it loads *from somewhere*, and the **addressing mode** is how that somewhere is specified. The same `LDA` comes in several forms, and they differ in both what they can reach and **how many cycles they cost** — which, on the VCS, is the part you care about most. [Reading 6502 Assembly]({{< relref "/docs/prerequisites/reading-assembly" >}}) introduced the `#`/`$`/`,X` notation; here is what each mode actually does.

## The modes you'll use

| Mode | Looks like | Means | Cycles (load) |
|------|-----------|-------|---------------|
| **Immediate** | `LDA #$05` | the literal value `$05` | 2 |
| **Zero page** | `LDA $84` | the byte at address `$0084` | **3** |
| **Zero page, X** | `LDA $80,X` | the byte at `$0080 + X` | 4 |
| **Absolute** | `LDA $F2A0` | the byte at a full 16-bit address | 4 |
| **Absolute, X / Y** | `LDA addr,X` | the byte at `addr + X` (or `+ Y`) | 4 (+1 if it crosses a page) |
| **Indirect, Y** | `LDA ($82),Y` | follow the pointer at `$82`, then add Y | 5 (+1 if page crossed) |
| **Implied / Accumulator** | `INX`, `ASL` | no operand, or A itself | 2 |
| **Relative** | `BNE loop` | a branch offset from the PC | 2 / 3 / 4 |

## Zero page is special — and cheap

Addresses `$00`–`$FF` are the **zero page**, and the 6502 has shorter, faster instructions for reaching them: a zero-page load is **3 cycles versus 4** for the same load from anywhere else, because the address is one byte instead of two. On a machine with a [76-cycle line]({{< relref "/docs/tia-racing-the-beam" >}}), that saved cycle per access is enormous.

This is doubly convenient on the VCS, because the console's [128 bytes of RAM live at `$80`–`$FF`]({{< relref "/docs/prerequisites/memory-mapped" >}}) — *inside* the zero page. So **all of your variables are zero-page variables automatically**, and every access to them is the cheap 3-cycle kind. Keeping hot values in zero page isn't an optimization you reach for; it's where they already are.

## The page-crossing penalty

When an indexed read (`LDA addr,X`) computes an address whose high byte differs from the base — it "crosses a page" (a 256-byte boundary) — the CPU needs **one extra cycle** to fix up the address. The same `+1` applies to a branch whose target is on a different page.

That single cycle is invisible until it isn't: in a kernel counting to 76, a table that straddles a page boundary can push a line one cycle over and tear the picture. The fix is alignment — placing time-critical tables so indexed reads stay within one page. (More in [Cycles & Timing]({{< relref "cycles-and-timing" >}}) and [Kernel Techniques]({{< relref "/docs/kernel-techniques" >}}).)

> Note: **stores never get the page-cross discount.** `STA addr,X` is always 5 cycles whether or not it crosses a page — the CPU does the fix-up every time. Only *reads* are sometimes-4-sometimes-5; writes are a flat, predictable cost, which is occasionally a reason to prefer them in tight timing.

## In Practice

- **Immediate vs. zero page is the `#` you can't forget.** `LDA #$84` loads the *number* `$84`; `LDA $84` loads the *contents* of address `$84`. Same instruction, completely different result — the single most common beginner bug.
- **Indexed modes are how you walk tables.** `LDX #0` … `LDA Digits,X` … `INX` is the shape of nearly every data-driven loop: graphics rows, sound sequences, lookup tables.
- **Prefer zero-page forms in kernels.** `LDA $84` over `LDA $1F84` when the value is in RAM — it's a cycle cheaper and the assembler will pick the short form automatically if the address fits in a byte.
