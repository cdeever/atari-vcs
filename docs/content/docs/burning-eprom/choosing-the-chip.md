---
title: "Choosing the Chip"
weight: 111
---

# Choosing the Chip

"EPROM" is the traditional name, but you have a few families to pick from, and the choice mostly comes down to *how painful it is to reprogram when you find a bug* — and you will find bugs.

## The three families

| Family | Examples | Erase method | Reusable? | Notes |
|--------|----------|--------------|-----------|-------|
| **UV EPROM (windowed)** | 2716, 2732, 2764, 27256, 27512 | UV light (~15–20 min in a UV eraser box) | Yes, many times | The classic. The quartz window over the die lets a UV eraser box wipe it clean for reuse. Just keep the window covered with a sticker in normal use, or ambient UV slowly corrupts it. |
| **OTP EPROM (no window)** | same part numbers, plastic package | — | **No — one shot** | Electrically identical die, but the plastic package has *no window*, so there's no way to get UV to it. Programs once, then it's permanent. Cheap for production; avoid while iterating. |
| **EEPROM** | 28C16, 28C64, 28C256 | Electrically, in the programmer | Yes, instantly | No UV lamp. Slightly pricier, sometimes slower write, very convenient for iteration. |
| **Flash / "electrically-erasable EPROM"** | W27C512, W27C020 (Winbond), SST39SF | Electrically, in the programmer | Yes, instantly | Cheap, reusable, no UV — the modern homebrew favorite. The Winbond W27C512 is a drop-in-ish 27512 replacement that erases in the programmer. |

**For iterating on a game, pick something electrically erasable** (EEPROM or a Winbond/SST flash part). Reserve UV EPROMs for when you specifically want the vintage experience or already own a stack of them — the burn → test → "oops" → 20-minute-erase cycle gets old fast.

## Matching size to your game

Cartridge size is dictated by the 6507's address space, not by the biggest chip you own:

- **2K game** → fits a 2716. Built with `org $F800`.
- **4K game** → fits a 2732. Built with `org $F000`. This is the largest *unbanked* size the console can address directly.
- **More than 4K** → requires **bankswitching** hardware (see [Preparing the ROM Image]({{< relref "preparing-the-image" >}}) and [Advanced Techniques]({{< relref "/docs/advanced" >}})). The console only has 13 address lines; the upper address lines of an 8K/16K/32K chip must be driven by bankswitch logic, *not* by the console.

You can absolutely burn a 2K or 4K game into a physically larger chip (e.g. a 4K game into a 27256) — you just have to place and mirror the image correctly and tie the unused high address lines to a defined level. More on that next.

## Programmer

A modern USB programmer — the **XGecu TL866II Plus** or **T48** is the de-facto homebrew standard — handles all of the above and auto-selects the correct programming voltage (V<sub>PP</sub>) when you tell it the *exact* part number.

## Tips & Caveats

- **V<sub>PP</sub> varies and matters.** Vintage parts may want 12.5 V, 21 V, or 25 V to program. The suffix on the part number encodes it. Selecting the wrong chip in the programmer can under-program (flaky bits) or over-volt (dead chip). Always select the exact marking on the package.
- **OTP parts are one-shot.** A plastic-package 27C256 with no window is One-Time Programmable. Confirm your image is *right* — verify it in Stella again — before burning an OTP part.
- **Always blank-check, then verify.** Blank-check before writing; verify after. A single bit that didn't take reads fine to the eye but crashes intermittently on real hardware in a way Stella will never show you.
- **Access time is a non-issue.** Even a slow 450 ns EPROM is comfortably fast for the ~838 ns 6507 cycle. Don't pay extra for fast parts.
