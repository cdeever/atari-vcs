---
title: "Wiring the Cartridge"
weight: 113
---

# Wiring the Cartridge

Once the chip is programmed it has to be wired into something the console's cartridge slot can read. This is where the project leaves software and becomes electronics — and where the mistakes stop being syntax errors and start being *bus contention* and *floating address lines*.

> **Strong recommendation:** copy the connections from a **proven, published cartridge schematic or reproduction PCB** (AtariAge has well-documented designs) rather than improvising them. The pin-level details below are to help you *understand and verify* such a design, not to reverse-engineer one from scratch. This is the one part of the pipeline where "close enough" produces hardware that intermittently works, which is worse than hardware that never works.

## What the cartridge connector carries

The Atari VCS cartridge edge connector exposes essentially the raw 6507 bus:

- **A0–A12** — 13 address lines. That's the whole reason a single cartridge can address at most 8K, of which the upper 4K is the cart window.
- **D0–D7** — 8 data lines, read by the CPU.
- **+5 V** and **GND**.

**A12 is the cartridge select.** The cart's 4K window lives in the upper half of the 6507's 8K space (mirrored to `$F000`–`$FFFF`), so A12 = 1 means "the CPU is reading the cartridge right now." For a 4K cart, A0–A11 address the ROM directly and A12 gates whether the ROM is allowed to drive the data bus.

## Chip-enable polarity — the conceptual trap

EPROM `/CE` (chip enable) and `/OE` (output enable) are **active-low**: the chip drives data only when they're held low. But the cartridge is selected when A12 is **high**. Those polarities are opposite, and they matter for a reason that never shows up in an emulator:

- If the ROM's outputs are enabled when A12 = 0 (i.e. when the CPU is talking to RAM/TIA/RIOT at low addresses), the ROM **fights those chips for the data bus** — *bus contention*. The symptom is erratic, heat- and timing-dependent misbehavior.
- So the design must ensure the ROM drives the bus **only** when A12 = 1.

A correct board reconciles this (gating an enable from A12 with the right polarity). Exactly *how* is a property of the board you copy — get it from the reference schematic and then confirm with a meter that the ROM outputs are tri-stated when A12 is low.

## Pinout differences that bite everyone

The 27-series is **not** pin-compatible across sizes. The classic, repeatedly-rediscovered example is the 24-pin 2716 vs. 2732:

| Pin | 2716 (2K) | 2732 (4K) |
|-----|-----------|-----------|
| 18  | /CE       | /CE       |
| 20  | /OE       | /OE // V<sub>PP</sub> (combined) |
| **21** | **V<sub>PP</sub>** | **A11** |

Pin 21 is the programming voltage on a 2716 but the **A11 address line** on a 2732. A socket wired for one chip will mis-feed the other — at best nothing works, at worst you put programming voltage where an address line expects logic levels.

The same theme repeats in the 28-pin parts (2764 → 27128 → 27256 → 27512): each larger chip **repurposes former V<sub>PP</sub>/`/PGM` pins as new high address lines** (for example the 27512 turns pin 1 into A15 and combines `/OE`//V<sub>PP</sub> on pin 22). So you cannot drop a 27512 into a socket wired for a 2764 and expect it to work.

## Tips & Caveats

- **Tie unused high address lines to a defined level.** If you burn a small image into a big chip, A12+ (whatever the console doesn't drive) must be strapped high or low to select your bank — a *floating* CMOS address input drifts and the chip reads from a random region. See [Preparing the ROM Image]({{< relref "preparing-the-image" >}}).
- **Verify enable behavior with a meter, not by assumption.** Confirm the ROM's data pins go high-impedance when A12 is low before trusting the cart in a console.
- **Socket everything during bring-up.** Use a ZIF or machined-pin socket so you can pull the chip to re-burn it without desoldering — you *will* re-burn it.
- **Mind the contacts.** A real edge connector and 40-year-old console slot are an analog interface: oxidized cartridge fingers and dirty slots cause exactly the same black-screen symptom as a wiring error. Clean contacts before blaming the burn.
