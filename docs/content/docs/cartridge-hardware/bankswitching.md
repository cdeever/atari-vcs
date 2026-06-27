---
title: "Bankswitching"
weight: 10
---

# Bankswitching

The [6507]({{< relref "/docs/architecture/cpu" >}}) has 13 address lines, so it can see 8 KB at most — and only the upper 4 KB (`$F000`–`$FFFF`) is the [cartridge window]({{< relref "/docs/architecture/rom" >}}). That's the hard ceiling: **an unbanked cart is 4 KB, full stop.** Every larger game gets there the same way — extra hardware *on the cartridge* swaps which 4 KB is visible in the window.

This page is the **hardware**: how the cartridge pages ROM in and out, and the named schemes that do it. Writing code that survives those swaps — the matching stubs, the reset vectors, the traps — is the next page, [Programming Across Banks]({{< relref "programming-across-banks" >}}).

## One window, many banks

Picture a 16 KB ROM as four 4 KB **banks**. The console can only ever see one at a time, through its single 4 KB window. Cartridge logic decides which:

{{< graphviz >}}
digraph bank {
  rankdir=LR;
  bgcolor="transparent";
  node [shape=box, style="filled,rounded", fontsize=10, color="#808080", penwidth=1.2];
  edge [color="#808080", penwidth=1.3];
  b0 [label="Bank 0\n(4 KB)", fillcolor="#cfe0f5"];
  b1 [label="Bank 1\n(4 KB)", fillcolor="#cfe0f5"];
  sw [label="bank select\n(touch $1FF8 or $1FF9)", fillcolor="#f6e0c6"];
  win [label="$F000-$FFFF\n4 KB window", fillcolor="#d2efd2"];
  cpu [label="6507 sees\none bank", fillcolor="#e2e2e2"];
  b0 -> sw; b1 -> sw; sw -> win -> cpu;
}
{{< /graphviz >}}

## Hotspots: switching with no instruction

Here is the part that surprises everyone: **there is no "switch bank" instruction.** The 6502 doesn't know banks exist. Instead, the cartridge watches the address bus, and **accessing certain addresses — "hotspots" — triggers the swap as a pure side effect.** Just *touching* the address does it; the read or write itself is incidental. This is the whole reason the trick can work: the cartridge has nothing to go on *but* the addresses the CPU puts on the bus, so it makes a handful of those addresses mean "switch."

```asm
    bit $1FF9        ; the access to $1FF9 IS the switch — bank 1 is now live
    ; ...execution continues from here, but in bank 1's copy of this code
```

The standard Atari schemes are named for their hotspot addresses up near the top of the window:

| Scheme | ROM | Banks | Hotspots |
|--------|-----|-------|----------|
| **F8** | 8 KB | 2 | `$1FF8`, `$1FF9` |
| **F6** | 16 KB | 4 | `$1FF6`–`$1FF9` |
| **F4** | 32 KB | 8 | `$1FF4`–`$1FFB` |
| **3F** | up to 512 KB | many | a write to `$3F` (Tigervision) |

(Others exist — E0, FE, 3E, and more — but F8/F6/F4 cover most Atari-era carts.)

That the swap is invisible to the instruction set is a gift and a hazard in equal measure. It means a larger ROM needs no new opcodes — but it also means an innocent-looking access can pull the rug out from under your own running code. Both consequences belong to the software side: [Programming Across Banks]({{< relref "programming-across-banks" >}}).

## In Practice

- **Pick the scheme before you write much.** Bankswitching shapes how you lay out code (what lives in which bank, where the stubs go), so choosing F8 vs. F6 isn't a late decision — it's architecture. The physical side is in [Preparing the ROM Image]({{< relref "/docs/burning-eprom/preparing-the-image" >}}).
- **The hotspots are the same addresses in every bank.** Because the cartridge decodes the address no matter which bank is showing, a hotspot reaches the switch from anywhere — which is exactly what makes the matching-stub trick on the next page possible.
