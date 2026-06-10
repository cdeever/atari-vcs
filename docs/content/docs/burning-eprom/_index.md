---
title: "Burning to EPROM & Real Hardware"
weight: 110
bookCollapseSection: true
BookIcon: eprom
---

# Burning to EPROM & Real Hardware

A `.bin` that runs flawlessly in Stella is only *probably* a working game. The emulator is forgiving in ways a real Atari is not: it zeroes RAM for you, it never has a marginal solder joint, and it doesn't care whether your ROM image is the right size for the chip you're about to program. Getting your code onto a cartridge that plugs into a real console exposes a second category of bugs that have nothing to do with 6502 logic — they live in chip selection, address wiring, image layout, and the analog reality of 40-year-old hardware.

This chapter walks the path from `.bin` to a working cartridge:

- **[Choosing the Chip]({{< relref "choosing-the-chip" >}})** — EPROM vs. EEPROM vs. flash, sizes, and what programmer to use.
- **[Preparing the ROM Image]({{< relref "preparing-the-image" >}})** — `org`, padding, mirroring a 2K game, and where the reset vectors must land.
- **[Wiring the Cartridge]({{< relref "wiring-the-cartridge" >}})** — the cartridge edge connector, chip-enable polarity, and the pinout differences that bite everyone.
- **[Gotchas: Works in Stella, Dies on Hardware]({{< relref "gotchas" >}})** — the failures the emulator never reproduces.

> The single most useful habit: **change one variable at a time.** When a freshly burned cart shows a black screen, it could be the image, the chip, the wiring, or the console. Build on a known-good board with a known-good chip so that when something breaks, only one thing changed.
