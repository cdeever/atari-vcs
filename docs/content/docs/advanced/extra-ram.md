---
title: "Extra RAM"
weight: 20
---

# Extra RAM

The console gives you **128 bytes** of [RAM]({{< relref "/docs/architecture/riot" >}}), and that pool is shared with the [stack]({{< relref "/docs/6502-basics/stack-and-subroutines" >}}). It is brutally little — a few sprite positions, a score, some counters, and it's gone. The way past it is the same as for [ROM]({{< relref "bankswitching" >}}): put more memory *on the cartridge.*

## Cartridge RAM, and the two-port trick

The best-known add-on is the **"Superchip"** — 128 extra bytes (some carts more) of RAM riding on the cartridge, mapped into the bottom of the [cart window]({{< relref "/docs/architecture/rom" >}}). But cartridge RAM has a wrinkle the console RAM doesn't: the cartridge connector has **no clean read/write signal** the chip can use to tell a load from a store in time. So cartridge RAM is split across **two address ranges — a write port and a read port:**

- **Write** a byte by storing to the *write-port* address.
- **Read** it back from the *read-port* address, a fixed offset higher.

For the classic 128-byte chip, the write port is the first 128 bytes of the window and the read port the next 128:

```asm
RAMWrite = $F000        ; write port  (store here)
RAMRead  = $F080        ; read port   (load here — 128 bytes higher)

    lda Score
    sta RAMWrite + 4    ; save into cart-RAM byte 4
    ; ...later...
    lda RAMRead + 4     ; read it back — note the DIFFERENT address
    sta AUDF0
```

The same physical byte answers to two addresses. Store to the low one; load from the high one. Mixing them up is the signature bug: **a load from the write port returns garbage**, and a store to the read port does nothing.

## What the headroom buys

128 extra bytes doesn't sound like much, but on this machine it's transformative. It's enough to hold a **display buffer** — a chunk of graphics you compute once and stream out during the kernel — instead of generating everything on the fly. Games use it for bigger playfield bitmaps, smoother multi-object motion, more elaborate game state, and arithmetic scratch that the console's 128 bytes simply couldn't spare. (Larger [banked]({{< relref "bankswitching" >}}) cartridges can carry far more, and modern homebrew carts pack kilobytes.)

## In Practice

- **The two ports are a discipline, not a difficulty.** Pick clear names (`RAMWrite`/`RAMRead`) and the offset becomes routine. Nearly every cartridge-RAM bug is a store and a load that didn't use the matching port.
- **Cart RAM eats ROM addresses.** The RAM ports overlay the bottom of the cart window, so those addresses aren't available for code or tables — budget your [bank]({{< relref "bankswitching" >}}) layout around them.
- **It's still not much — design lean first.** Extra RAM rewards a game that already respects memory. The habits from the [128-byte world]({{< relref "/docs/architecture/riot" >}}) — pack state into bits, precompute into [ROM tables]({{< relref "/docs/kernel-techniques/front-loading-and-tables" >}}) — don't go away; they just stretch further.
