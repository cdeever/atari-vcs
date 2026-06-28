---
title: "ARM Cartridges"
weight: 40
---

# ARM Cartridges

The [DPC]({{< relref "dpc" >}}) put one small custom chip on the cartridge and let it do a few jobs the 6507 couldn't spare cycles for. Modern homebrew takes that exact idea and pushes it as far as it will go.

Today's **Harmony** and **Melody** cartridges, together with the **DPC+** and **CDF** programming models, take exactly the same idea to its conclusion. Hidden behind the cartridge edge connector is a modern **ARM microcontroller** running at hundreds of megahertz. To the Atari, it still appears to be an ordinary ROM with a handful of special registers. Behind the scenes, however, the ARM is decompressing graphics, streaming music, copying data, calculating game logic, and emulating the original DPC hardware — all while **the humble 1.19 MHz 6507 remains blissfully unaware.**

## It still looks like a ROM

That last part is the trick that keeps it *legal* on an unmodified console. The cartridge connector exposes nothing but the [raw 6507 bus]({{< relref "/docs/burning-eprom/wiring-the-cartridge" >}}) — address lines in, data lines out. The ARM watches the address lines, and when the 6507 reads one of its "register" addresses it places the requested byte on the data lines, exactly the way a [plain ROM]({{< relref "/docs/architecture/rom" >}}) would. The 6507 can't tell the difference between a value baked into mask ROM in 1981 and one an ARM computed a microsecond ago. From the console's side, it is *still just reading the cartridge.*

## A computer that out-muscles the console

The mismatch is almost comic. The 6507 runs at **1.19 MHz** and executes one instruction at a time; the ARM on a Melody board runs at **tens of megahertz** (newer boards far faster), with hardware multiply, kilobytes of RAM, and room for code the 6507 could never hold. So the labor divides cleanly:

- The **6507** does the one thing only it can: [race the beam]({{< relref "/docs/tia-racing-the-beam" >}}), feeding the TIA the right byte at the right cycle to paint a picture.
- The **ARM** does everything behind it — unpacking compressed graphics, running the game's logic in C, mixing audio, and handing the 6507 finished data through those register addresses, just in time for the next line.

**DPC+** was the first of these models: an ARM re-creation of Crane's DPC, plus room to run your own C on the cartridge. **CDF** and **CDFJ** go further still, giving the ARM enough reach that studios like **Champ Games** have shipped arcade-faithful ports — *Galagon*, *Mappy*, *Wizard of Wor Arcade*, *Zoo Keeper* — that look impossible on a 2600 until you remember what's actually doing the work.

## In Practice

- **You write two programs at once.** A 6502 display kernel that races the beam, and an ARM-side program (usually C) that prepares everything it needs. The craft is in the *handoff* between them — the kernel reads exactly what the ARM has just finished computing.
- **It's still a 2600 game, on a 2600.** No console mod, no extra cables: the same edge connector, the same TIA making the same picture, the same beam. Everything new lives on the cart.
- **The tools are current.** The Harmony/Melody ecosystem, batari Basic's DPC+ kernel, and the CDFJ toolchains are all actively maintained — this is where a great deal of new 2600 homebrew is actually written today.

That power raises an honest question, and it's the one this chapter closes on: if the cartridge can carry a computer that dwarfs the console, **[should it?]({{< relref "should-you-extend" >}})**
