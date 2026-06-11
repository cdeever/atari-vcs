---
title: "Thinking in Bits"
weight: 20
---

# Thinking in Bits

On the VCS, almost every hardware register is a bag of individual switches — one bit turns on playfield reflection, one bit is the fire button, a group of bits picks a sound waveform. There is no high-level API; you set and clear bits directly. This page is the bit literacy the rest of the book assumes. Its companion, [The Memory-Mapped Interface]({{< relref "memory-mapped" >}}), covers *where* those bits live and how you reach them.

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

## Tips & Caveats

- **Preserve the bits you don't own.** When a register holds several features, never blindly `lda #constant` / `sta` if other bits matter — read, modify with `ORA`/`AND`, write back. Stomping unrelated bits is a classic source of "why did the sound change when I moved the player?" bugs.
- **`%` makes intent visible; `$` makes it compact.** Write switch patterns in binary and numbers/addresses in hex. Future-you reading `%00100000` instantly sees "bit 5"; reading `$20` you have to decode it.
- **Active-low is everywhere.** Joystick and switch inputs read `0` when pressed. Don't test for a positive value — isolate the bit and branch on zero/non-zero.
- **Shifts are cheap multiply/divide by 2.** `ASL` doubles, `LSR` halves (unsigned) — which matters because the 6502 has no multiply instruction at all. [Numbers & Arithmetic]({{< relref "numbers" >}}) picks up what that means for doing math.
