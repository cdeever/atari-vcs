---
title: "Registers & Status Flags"
weight: 10
---

# Registers & Status Flags

The 6502 has astonishingly few places to keep data — **three 8-bit working registers**, and that scarcity shapes how every program is written. You can't spread work across a bank of registers the way you would on a bigger CPU; values are constantly shuttled between these three and [memory]({{< relref "/docs/prerequisites/memory-mapped" >}}).

| Register | Width | Role |
|----------|-------|------|
| **A** (accumulator) | 8-bit | The workhorse. The *only* register that does arithmetic and logic (`ADC`, `SBC`, `AND`, `ORA`, `EOR`). Almost all data flows through it. |
| **X** | 8-bit | Index/counter. Used to offset addresses (`LDA table,X`) and to count loops. Also the bridge to the stack pointer (`TXS`/`TSX`). |
| **Y** | 8-bit | The other index/counter. Similar to X, with its own indexed modes. |
| **S** (stack pointer) | 8-bit | Points at the top of the [stack]({{< relref "stack-and-subroutines" >}}). |
| **PC** (program counter) | 16-bit | Address of the next instruction to execute. |
| **P** (status) | 8-bit | The processor flags — see below. |

A, X, and Y are *not* interchangeable: only A computes, only X and Y index, and each has instructions the others lack. Choosing which value lives in which register is a real part of writing tight 6502 code.

## The status register (P)

After most instructions, the CPU records a few facts about the result in the **P** register's individual bits. You rarely read P directly; instead you act on its flags with **branch** instructions.

{{< graphviz >}}
digraph pflags {
  bgcolor="transparent";
  node [shape=plaintext];
  t [label=<
<table border="0" cellborder="1" cellspacing="0" cellpadding="6">
<tr><td colspan="8" bgcolor="#3a3a3a"><font color="#ffffff"><b>P &#8212; processor status (bit 7 &#8594; 0)</b></font></td></tr>
<tr>
<td bgcolor="#f6c6cc">N<br/><font point-size="10">7 &#183; negative</font></td>
<td bgcolor="#f6c6cc">V<br/><font point-size="10">6 &#183; overflow</font></td>
<td bgcolor="#e2e2e2">&#8211;<br/><font point-size="10">5 &#183; unused</font></td>
<td bgcolor="#cfe0f5">B<br/><font point-size="10">4 &#183; break</font></td>
<td bgcolor="#cfe0f5">D<br/><font point-size="10">3 &#183; decimal</font></td>
<td bgcolor="#cfe0f5">I<br/><font point-size="10">2 &#183; irq off</font></td>
<td bgcolor="#d2efd2">Z<br/><font point-size="10">1 &#183; zero</font></td>
<td bgcolor="#d2efd2">C<br/><font point-size="10">0 &#183; carry</font></td>
</tr>
</table>
>];
}
{{< /graphviz >}}

- **Z — zero.** Set when the last result was `0`. Tested by `BEQ` (branch if equal/zero) and `BNE`. The most-used flag: every loop counter and equality check rides on it.
- **C — carry.** The 9th bit of an add, the borrow of a subtract, and the bit shifted out of `ASL`/`LSR`. Tested by `BCC`/`BCS`. You clear it (`CLC`) before an `ADC` and set it (`SEC`) before an `SBC` — see [Numbers & Arithmetic]({{< relref "/docs/prerequisites/numbers" >}}).
- **N — negative.** A copy of bit 7 of the result (the sign bit). Tested by `BMI`/`BPL`.
- **V — overflow.** Set when a *signed* add/subtract crossed the −128/+127 boundary. Tested by `BVC`/`BVS`. On the VCS it's most often read not from math but from the TIA collision latches via `BIT` (see [Collisions]({{< relref "/docs/collisions" >}})).
- **D — decimal.** When set (`SED`), `ADC`/`SBC` work in [BCD]({{< relref "/docs/prerequisites/numbers" >}}); clear it with `CLD`. Used for scorekeeping.
- **I — interrupt disable** and **B — break.** Largely irrelevant on the VCS: the 6507 has [no interrupt lines]({{< relref "/docs/architecture/cpu" >}}), so there are no IRQs to mask.

## In Practice

- **`BIT` is the flag-setter you'll reach for constantly.** It sets Z from `A AND memory` *and* copies the memory's bits 7 and 6 straight into N and V — which is exactly why reading a TIA collision or input register with `BIT` then `BMI`/`BVS` is the idiom for testing those top two bits without disturbing A.
- **Loads and transfers set flags too.** `LDA #0` sets Z; `LDX`, `TAY`, `AND`, `INX`, and most data ops update N and Z. So you often don't need a separate compare — the load itself already set the flag you want to branch on.

> The mental model: you have three registers and a scratchpad of flags. Everything else is memory. Good 6502 code is largely about keeping the *right* value in A, X, or Y at the moment you need it — because getting it there again costs cycles you may not have.
