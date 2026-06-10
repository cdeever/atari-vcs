---
title: "Prerequisite Knowledge: Bits & Memory-Mapped Hardware"
weight: 10
---

# Prerequisite Knowledge: Bits & Memory-Mapped Hardware

Two ideas underpin everything else in this book, and neither is really "programming" in the usual sense:

1. **You think in bits.** Almost every hardware register is a bag of individual switches — one bit turns on playfield reflection, one bit is the fire button, a group of bits picks a sound waveform. There is no high-level API; you set and clear bits directly.
2. **You talk to hardware by reading and writing memory addresses.** The chips that make sound, draw pixels, and read the joystick live *in the same address space as RAM*. A `sta` to the right address isn't storing data — it's operating a chip.

This page is the short version of both. The rest of the book assumes them.

## Binary, hex, and the two notations

A byte is 8 bits, each `0` or `1`. The rightmost bit is bit 0 (value 1), then bit 1 (value 2), bit 2 (value 4), and so on up to bit 7 (value 128). The whole byte ranges 0–255.

**Hexadecimal** is just a compact way to write those 8 bits: each hex digit is exactly 4 bits (a *nibble*), so one byte is always two hex digits. This is why hex is everywhere in VCS code — `$1F` is easier to read and reason about than `00011111`, and the digit boundary lines up with the nibble boundary.

DASM gives you both notations directly:

| Notation | Means | Example |
|----------|-------|---------|
| `$` prefix | hexadecimal | `$F8` = 248 |
| `%` prefix | binary | `%11111000` = 248 |
| (no prefix) | decimal | `248` |

Use whichever makes the *intent* clearest. When a value is really a pattern of switches, write it in binary so the bits are visible:

```asm
    ldx #%00000001   ; clearly "just bit 0 set" — the CTRLPF reflect flag
    stx CTRLPF
```

When a value is an address or a number, hex or decimal reads better. The Christmas-tree kernel in `xmas.asm` uses exactly this habit: playfield patterns are written in binary (`%11000000`), the ROM origin in hex (`$f000`).

## Bits *are* the hardware

The reason this matters: a register's bits each mean something specific, and the datasheet/`vcs.h` tells you which. For example, `CTRLPF` bit 0 (`D0`) is the playfield reflect flag. Setting *just that bit* is how you mirror the playfield:

```asm
    ldx #%00000001   ; D0 = 1 -> reflect on; all other CTRLPF features off
    stx CTRLPF
```

So "set the reflect flag" becomes "write a byte whose bit 0 is 1." You are constantly translating between *a feature you want* and *the bit pattern that selects it*.

## The four bit operations

The 6502 gives you four ways to manipulate bits. Each maps to a common intent:

| Op | Instruction | Use it to… | Rule |
|----|-------------|-----------|------|
| AND | `AND` | **clear** bits / **test** bits | bit survives only if *both* are 1 |
| OR  | `ORA` | **set** bits | bit becomes 1 if *either* is 1 |
| XOR | `EOR` | **toggle** bits | bit flips where the mask is 1 |
| shift | `ASL` / `LSR` / `ROL` / `ROR` | **move** bits left/right (×2, ÷2) | a 0 (or carry) shifts in at the end |

A **mask** is just a byte you choose to select which bits an operation touches.

**Set bits** (turn on) — OR with a mask that has 1s where you want them on:

```asm
    lda VALUE
    ora #%00000100   ; force bit 2 on, leave the rest unchanged
    sta VALUE
```

**Clear bits** (turn off) — AND with the *complement* of the mask (1s everywhere except the bits to clear):

```asm
    lda VALUE
    and #%11111011   ; force bit 2 off, leave the rest unchanged
    sta VALUE
```

**Toggle bits** — EOR with a mask:

```asm
    lda VALUE
    eor #%00000100   ; flip bit 2
    sta VALUE
```

**Test bits** — AND (or `BIT`) with a mask, then branch on whether the result was zero:

```asm
    lda SWCHA
    and #%10000000   ; isolate bit 7 (player-0 right on the joystick)
    beq MoveRight    ; result 0 -> that bit was 0 -> direction is pressed
```

## Memory-mapped registers: how you talk to the hardware

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

### Writes can be commands, not storage

Because an address *is* a chip, writing to a hardware register is often a **command with a side effect**, not a value you can read back later:

- **Most TIA registers are write-only.** `sta COLUPF` sets the playfield color, but you cannot `lda COLUPF` to get it back — there's nothing there to read. If you need to know a register's current value, keep your own copy in RAM (a "shadow register") and write *that* to both.
- **Strobe registers ignore the value entirely.** For some addresses, the mere act of writing triggers an action and the byte you wrote is discarded. The most important is `WSYNC`: `sta WSYNC` **halts the CPU until the start of the next scanline** — the cornerstone of racing the beam. Others include `RESP0`/`RESP1` (latch a sprite's horizontal position at the moment of the write), `HMOVE` (apply fine motion), and `CXCLR` (clear the collision latches). The conventional idiom is to `sta` whatever's already in `A`; the value is irrelevant.

```asm
    sta WSYNC        ; the value of A doesn't matter — the *write* waits for the next line
```

### Reads pull live hardware state

Reading a memory-mapped address samples the chip *right now*: `lda SWCHA` gives the current joystick directions, `bit CXP0FB` gives this scanline's collision state. Some addresses are read-only, some write-only, and a few even mean different things when read vs. written — so reach for the `vcs.h` name and the register's documented direction rather than assuming an address behaves like RAM.

> The mental shift: a line like `sta WSYNC` *looks* identical to `sta $80` (storing a variable), but one pauses the processor and the other parks a byte in RAM. On the VCS you must always know **which addresses are RAM and which are hardware** — they share the same `lda`/`sta` instructions but behave completely differently.

## In Practice

Three places these two ideas show up together later in the book — each is a memory-mapped *read* whose result you pick apart bit by bit:

- **Reading the joystick** ([Input]({{< relref "/docs/input" >}})) — directions live in individual bits of `SWCHA`, and they are *active-low*: a pressed direction reads as `0`. You isolate the bit with `AND` (or `BIT`) and branch.
- **Collision detection** ([Collisions]({{< relref "/docs/collisions" >}})) — the TIA reports collisions in the top bits of its latch registers, so you test them with `BIT` and branch on the N/V flags rather than comparing numbers.
- **Sound and sizing** — `AUDC`, `NUSIZ`, and `CTRLPF` pack several independent settings into one register; changing one feature means modifying *some* bits while preserving the others, which is the set/clear pattern above.

## Tips & Caveats

- **Preserve the bits you don't own.** When a register holds several features, never blindly `lda #constant` / `sta` if other bits matter — read, modify with `ORA`/`AND`, write back. Stomping unrelated bits is a classic source of "why did the sound change when I moved the player?" bugs.
- **`%` makes intent visible; `$` makes it compact.** Write switch patterns in binary and numbers/addresses in hex. Future-you reading `%00100000` instantly sees "bit 5"; reading `$20` you have to decode it.
- **Active-low is everywhere.** Joystick and switch inputs read `0` when pressed. Don't test for a positive value — isolate the bit and branch on zero/non-zero.
- **Shifts are cheap multiply/divide by 2.** `ASL` doubles, `LSR` halves (unsigned). Handy for table indexing and fixed-point math when you have no multiply instruction — because the 6502 has none.
- **Write-only registers need a shadow.** Most TIA registers can't be read back. If your logic needs to know the current contents of a hardware register, keep the authoritative value in a RAM variable and write that variable to the register — never expect to `lda` it back.
