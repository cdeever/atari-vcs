---
title: "Extending the Cartridge"
weight: 90
bookCollapseSection: true
BookIcon: advanced
---

# Extending the Cartridge

In 1984, *Pitfall II: Lost Caverns* did something no 2600 game had done before: it shipped with **a second chip inside the cartridge** — a custom coprocessor that streamed the game's graphics and played three voices of continuous music while it ran. The console hadn't changed at all. The *cartridge* had grown a brain.

That is the idea this whole chapter turns on. The console is fixed — a 4 KB [ROM window]({{< relref "/docs/architecture/rom" >}}), [128 bytes of RAM]({{< relref "/docs/architecture/riot" >}}), the [TIA's]({{< relref "/docs/architecture/programming-the-television" >}}) two players — and none of it can be upgraded. But the cartridge slot is wired straight to the [6507's]({{< relref "/docs/architecture/cpu" >}}) address and data buses, so whatever you put on the cart can *watch every address the CPU touches and answer back.* That single fact lets cartridge hardware lift the machine's ceilings from the outside, without changing the console at all.

The escalation runs in three steps — more memory, then more processing:

- **[Bankswitching]({{< relref "bankswitching" >}})** — the earliest and simplest cartridge hardware (Atari's *Asteroids*, 1981). Logic on the cart pages larger ROM through the single 4 KB window, breaking the **4 KB ceiling**. Its programming side — switching safely and living across banks — is **[Programming Across Banks]({{< relref "programming-across-banks" >}})**.
- **[Extra RAM]({{< relref "extra-ram" >}})** — the "Superchip" and its two-port read/write trick add cartridge **RAM**, breaking the **128-byte ceiling**.
- **[The DPC]({{< relref "dpc" >}})** — Pitfall II's coprocessor, the far horizon: not just more memory but a chip that *computes*, doing work the CPU couldn't spare.

Each escape costs something — a more complex cartridge, address space, or both — but each one buys a game room the bare console simply doesn't have.
