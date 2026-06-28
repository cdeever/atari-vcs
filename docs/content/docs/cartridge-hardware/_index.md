---
title: "Extending the Cartridge"
weight: 112
bookCollapseSection: true
BookIcon: advanced
---

# Extending the Cartridge

The console is fixed. A 4 KB [ROM window]({{< relref "/docs/architecture/rom" >}}), [128 bytes of RAM]({{< relref "/docs/architecture/riot" >}}), the [TIA's]({{< relref "/docs/architecture/programming-the-television" >}}) two players — none of it can ever be upgraded. But the one part of the machine you actually *build* is the **cartridge**, and the cartridge slot is wired straight to the [6507's]({{< relref "/docs/architecture/cpu" >}}) address and data buses. Whatever you put on the cart can *watch every address the CPU touches and answer back* — so the cart, not the console, is where the machine's limits get pushed.

This closing chapter follows that push across four decades — from a plain slab of read-only memory to a cartridge with a far faster computer inside it than the console it plugs into:

- **[Bankswitching]({{< relref "bankswitching" >}})** — the first and simplest move (Atari's *Asteroids*, 1981): logic on the cart pages larger ROM through the single 4 KB window, breaking the **4 KB ceiling**. Its programming side — living across banks — is **[Programming Across Banks]({{< relref "programming-across-banks" >}})**.
- **[Extra RAM]({{< relref "extra-ram" >}})** — the "Superchip" and its two-port trick add cartridge **RAM**, breaking the **128-byte ceiling**.
- **[The DPC]({{< relref "dpc" >}})** — *Pitfall II*, 1984: the turning point, when the cartridge stopped merely *storing* and started *computing* — the first **smart cartridge**.
- **[ARM Cartridges]({{< relref "arm-cartridges" >}})** — the modern conclusion: a full ARM processor hidden behind the edge connector, running rings around a 6507 that never knows it's there.

Each step lifts a ceiling the bare console can't — but each also asks more of the cartridge, and blurs the line of what a "2600 game" even is. Which is why the chapter ends on the real question: with 4 KB enough for *Combat* and *Pitfall*, **[should you extend at all?]({{< relref "should-you-extend" >}})**
