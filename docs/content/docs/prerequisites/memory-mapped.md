---
title: "The Memory-Mapped Interface"
weight: 30
---

# The Memory-Mapped Interface

On the VCS you talk to hardware by reading and writing memory addresses. The chips that make sound, draw pixels, and read the joystick live *in the same address space as RAM*, so a `sta` to the right address isn't storing data — it's operating a chip. This page assumes the bit literacy from [Thinking in Bits]({{< relref "bits" >}}); here we cover *where* those bits go.

## Registers are just addresses

The 6502/6507 has exactly one kind of "talk to the outside world" instruction — the same loads and stores it uses for RAM. There is **no separate I/O instruction**. Instead, the TIA (graphics/sound), the RIOT (RAM, timer, and joystick/switch ports), and the cartridge ROM are all wired to *respond to specific addresses*. This is **memory-mapped I/O**: the chip behind an address decides what reading or writing it actually does.

`vcs.h` is nothing more than a list of names for those addresses:

```asm
COLUBK = $09     ; background color register (in the TIA)
WSYNC  = $02     ; "wait for sync" strobe       (in the TIA)
SWCHA  = $280    ; joystick/port A inputs        (in the RIOT)
```

So `sta COLUBK` assembles to "store A at address `$09`" — and because `$09` belongs to the TIA, the effect is *change the background color*, not *remember a number*.

A rough map of where things live in the 13-bit address space (use the `vcs.h` names, not the raw numbers):

| Range | Chip | What's there |
|-------|------|--------------|
| `$00`–`$3F` | TIA | Graphics, sound, collision, sync registers |
| `$80`–`$FF` | RIOT | The 128 bytes of **RAM** — your variables |
| `$280`–`$297` | RIOT | Joystick/switch ports and the interval timer |
| `$F000`–`$FFFF` | Cartridge | Your ROM (and the reset vectors at the top) |

> This is a rough map, not the register list. For the complete address-summary table — every TIA and RIOT register, its address, and whether it's read or write — see the [Stella Programmer's Guide]({{< relref "/docs/further-reading" >}}).

## Writes can be commands, not storage

Because an address *is* a chip, writing to a hardware register is often a **command with a side effect**, not a value you can read back later:

- **Most TIA registers are write-only.** `sta COLUPF` sets the playfield color, but you cannot `lda COLUPF` to get it back — there's nothing there to read. If you need to know a register's current value, keep your own copy in RAM (a "shadow register") and write *that* to both.
- **Strobe registers ignore the value entirely.** For some addresses, the mere act of writing triggers an action and the byte you wrote is discarded. The most important is `WSYNC`: `sta WSYNC` **halts the CPU until the start of the next scanline** — the cornerstone of "Racing the Beam." Others include `RESP0`/`RESP1` (latch a sprite's horizontal position at the moment of the write), `HMOVE` (apply fine motion), and `CXCLR` (clear the collision latches). The conventional idiom is to `sta` whatever's already in `A`; the value is irrelevant.

```asm
    sta WSYNC        ; the value of A doesn't matter — the *write* waits for the next line
```

## Reads pull live hardware state

Reading a memory-mapped address samples the chip *right now*: `lda SWCHA` gives the current joystick directions, `bit CXP0FB` gives this scanline's collision state. Some addresses are read-only, some write-only, and a few even mean different things when read vs. written — so reach for the `vcs.h` name and the register's documented direction rather than assuming an address behaves like RAM.

> The mental shift: a line like `sta WSYNC` *looks* identical to `sta $80` (storing a variable), but one pauses the processor and the other parks a byte in RAM. On the VCS you must always know **which addresses are RAM and which are hardware** — they share the same `lda`/`sta` instructions but behave completely differently.

## In Practice

Three places this combines with [thinking in bits]({{< relref "bits" >}}) later in the book — each is a memory-mapped *read* whose result you pick apart bit by bit:

- **Reading the joystick** ([Input]({{< relref "/docs/input" >}})) — directions live in individual bits of `SWCHA`, and they are *active-low*: a pressed direction reads as `0`. You isolate the bit with `AND` (or `BIT`) and branch.
- **Collision detection** ([Collisions]({{< relref "/docs/collisions" >}})) — the TIA reports collisions in the top bits of its latch registers, so you test them with `BIT` and branch on the N/V flags rather than comparing numbers.
- **Sound and sizing** — `AUDC`, `NUSIZ`, and `CTRLPF` pack several independent settings into one register; changing one feature means modifying *some* bits while preserving the others.

## Tips & Caveats

- **Write-only registers need a shadow.** Most TIA registers can't be read back. If your logic needs to know the current contents of a hardware register, keep the authoritative value in a RAM variable and write that variable to the register — never expect to `lda` it back.
- **Know which addresses are RAM and which are hardware.** They use the same `lda`/`sta` instructions but behave completely differently — one stores a value you can retrieve, the other commands a chip.
