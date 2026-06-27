---
title: "Preparing the ROM Image"
weight: 112
---

# Preparing the ROM Image

The bytes you send to the programmer are not always the bytes DASM emitted. Two things have to be right: the **reset vectors** must land at the very top of the address the console fetches from, and the image must **fill the chip** in a way the cartridge wiring expects.

## The reset vectors must be at the top

When the console powers on, the 6507 reads its program-counter start address from the reset vector at `$FFFC`/`$FFFD`. On the cartridge that is the **last two bytes of ROM space**. Every ROM in this book ends with:

```asm
    org $fffc
    .word Reset
    .word Reset
```

If your image is laid out so those bytes are *not* the final bytes the console sees, it jumps to garbage and you get a black or garbage screen. For a plain 4K image built with `org $F000`, this is automatic — the last four bytes of the 4096-byte file are the two vectors. The trouble starts when the chip is bigger than the game.

## Matching image size to chip size

The cartridge expects ROM to occupy a specific window. If the chip is larger than the game, you must place and replicate the image so that window is filled and the vectors are reachable.

**A 2K game in a 4K (2732) chip.** Original 4K cartridge wiring drives address line A11; a 2K image only defines A0–A10. The standard fix is to **duplicate the 2K image into both halves** so the game appears identical whether A11 is 0 or 1:

```sh
# 2K binary -> 4K image (two identical copies)
cat game2k.bin game2k.bin > game4k.bin
```

**A 4K game in a larger chip (e.g. 27256 = 32K).** The console can only ever address 4K of an unbanked cart, so you replicate the 4K image to fill the chip, and you must **tie the chip's unused high address lines (A12 and up) to a fixed level** so it always presents the same 4K bank. Many programmers will pad/duplicate for you; otherwise replicate the 4K image as many times as needed to fill the part.

> **Pad with `$FF`, not `$00`.** `$FF` is the erased state of the cell, so padding to `$FF` means the programmer can skip those regions and there's nothing to "un-erase." More importantly, a stray jump into padding hits `$FF` = the `SBC`/illegal region rather than `BRK` (`$00`), which behaves differently — but really, you shouldn't be executing padding at all; treat it landing there as a bug.

## Anything over 4K needs bankswitch hardware

You cannot make a 5K or 8K *unbanked* cartridge — the 6507 has no address lines to reach it. Larger games use a **bankswitching scheme** (F8 = 8K, F6 = 16K, F4 = 32K, 3F, and others) where accessing special "hotspot" addresses pages a different 4K chunk of the chip into the `$F000` window. That requires:

1. Building the ROM with the matching bankswitch format and hotspot writes in your code.
2. A cartridge board with the **logic to perform the switch** (discrete 74-series glue, a dedicated mapper, or a programmable board).

The **power-on bank must contain the reset vectors.** By convention the last bank is active at reset, so put your startup code and the `$FFFC` vectors there. See [Bankswitching]({{< relref "/docs/cartridge-hardware/bankswitching" >}}) for the schemes themselves.

## In Practice

- **Check the file size before you burn.** A 4K game should be exactly 4096 bytes; a 2K game 2048. An off-by-one (e.g. an assembler emitting an extra trailing byte) shifts everything and moves your vectors.
- **Re-verify in Stella *after* any padding/mirroring step.** Stella will happily run the padded/mirrored `.bin`; if it doesn't boot there, it certainly won't on hardware.
- **Burn offset / "load address" in the programmer.** Make sure the programmer places byte 0 of your file at address 0 of the chip. A non-zero load offset is a classic way to get a perfectly-good image that boots to garbage.
