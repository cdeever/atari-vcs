---
title: "Building a Scoreboard"
weight: 43
---

# Building a Scoreboard

A two-player scoreboard is the textbook use of an [asymmetric playfield]({{< relref "asymmetric" >}}) — two *different* numbers, one on each half of the screen — and it pulls together nearly everything in this chapter: digit graphics drawn from the playfield, bit masking to pack two digits into a byte, the no-multiply [×5 index trick]({{< relref "/docs/prerequisites/numbers" >}}), and [BCD]({{< relref "/docs/prerequisites/numbers" >}}) arithmetic to keep the count in decimal.

> The code here is **illustrative** — the repository doesn't ship a scoreboard project yet. Treat the snippets as sketches of the technique, not a drop-in kernel.

## Digits drawn from the playfield

A readable digit is about three playfield pixels wide, plus a one-pixel gap to separate it from its neighbor — four pixels total. Since a byte is eight bits, **two digits fit side by side in a single byte.** So the digit font is stored *doubled*: each row of each digit occupies one byte, with the digit's shape in *both* nibbles.

```asm
DigitGfx:
    .byte $66, $66, $66, $66, $66   ; "6" — five rows, shape in both nibbles
    .byte $55, $55, $55, $55, $55   ; "5"
    ; ...one 5-byte block per digit, 0 through 9
```

Each digit is five rows tall here (the height is your choice — more rows, taller digits), so digit *d* starts at table offset `d × 5`.

## Picking a digit, and packing two together

Two problems: finding a digit's offset, and showing two *different* digits in one byte.

**The offset needs a multiply by 5 — which the 6502 can't do directly.** Build it from shifts and an add (see [Numbers & Arithmetic]({{< relref "/docs/prerequisites/numbers" >}})):

```asm
    lda Score
    and #$0F        ; isolate the ones digit (0–9)
    sta Temp
    asl             ; ×2
    asl             ; ×4
    clc
    adc Temp        ; ×5  → offset into DigitGfx
    tax             ; X now indexes the ones digit's rows
```

**Packing two digits** uses the masks from [Thinking in Bits]({{< relref "/docs/prerequisites/bits" >}}). Because each stored digit fills both nibbles, you keep the *half* you want and `ORA` the two together:

```asm
    lda DigitGfx,x  ; a row of the ones digit
    and #$0F        ; keep it in the right-hand nibble
    sta Temp
    lda DigitGfx,y  ; the same row of the tens digit (Y = its offset)
    and #$F0        ; keep it in the left-hand nibble
    ora Temp        ; tens | ones → one byte showing both digits
    sta PF1         ; draw it
```

That single `PF1` byte now shows a two-digit number on the left half of the screen.

## Two scores, two sides

So far that's one number, copied onto both halves. A *scoreboard* wants the left player's score on the left and the right player's on the right — two different two-digit numbers — and that is the [asymmetric playfield]({{< relref "asymmetric" >}}) trick run against the clock.

Walk one row of the score band the way the beam does:

1. **Player 0.** Fetch this row of player 0's tens and ones digits, mask each to its nibble, and `ORA` them into a single byte — tens in the high nibble, ones in the low. Write that byte to `PF1` while the beam is still in the **left** half, and player 0's score appears on the left.
2. **Player 1.** As the beam keeps moving across the *same* scanline, do it again for player 1 — fetch, mask, combine — and **rewrite that same `PF1`** before the beam reaches the **right** half, so player 1's score appears on the right.

One register, written twice per line, chasing the beam from one side to the other. Each row of the scoreboard's height repeats this on the [cycle schedule]({{< relref "asymmetric" >}}) from the previous page — which is *why* scoreboards are the canonical asymmetric-playfield exercise.

And the whole sequence has to land inside one scanline's [76 CPU cycles]({{< relref "/docs/tia-racing-the-beam" >}}). That budget is the reason the digit font is *pre-arranged* — each digit stored in both nibbles. Showing two digits side by side becomes an `AND` / `AND` / `ORA` of ready-made bytes — three fast instructions — instead of shifting bits into position at run time. The slow work was done once, in the shape of the table; the per-line work is only *fetch, mask, combine, store.*

## Two colors for free: score mode

A scoreboard usually wants each player's score in *that player's* color. You could swap `COLUPF` mid-line, but the TIA has a control made for exactly this: **bit 1 (D1) of `CTRLPF`**, *score mode*. Set it, and the playfield stops using `COLUPF` and instead draws its **left half in `COLUP0` and its right half in `COLUP1`** — the two players' colors, with no per-line color writes at all.

So the standard scoreboard kernel turns score mode on for the band of scanlines holding the digits and off again below: the left score comes out in player 0's color and the right in player 1's, while the [player objects themselves stay free]({{< relref "/docs/sprites/_index" >}}) for the game below. (Score mode is one of the bits packed into `CTRLPF` — see the [full register map]({{< relref "/docs/sprites/priority" >}}).)

The trade: score mode colors the **entire playfield** those two halves for as long as it's on, so switch it on only across the score band, not as a per-digit effect.

## Counting in decimal (BCD)

There's one more snag: a nibble holds 0–15, but a decimal digit only goes to 9. Set the 6502's **decimal mode** and arithmetic rolls each nibble over at 9 instead of 15, so the score stays a pair of clean decimal digits — already in the form the indexing code above expects:

```asm
    sed             ; decimal mode on
    lda Score
    clc
    adc #$01        ; 09 + 1 → 10  (not $0A)
    sta Score
    cld             ; decimal mode off
```

Mind the catch from [Numbers & Arithmetic]({{< relref "/docs/prerequisites/numbers" >}}): decimal mode only affects `ADC`/`SBC` (and needs `CLC` first), **not** `INC`/`DEC` — so score it with an add, never an increment.

## Tips & Caveats

- **Digit width is fixed.** Playfield pixels are 4 color clocks wide and can't be narrowed, so playfield digits are chunky. For finer or more numerous digits, games use the *player* (sprite) objects instead — a technique for the [Sprites]({{< relref "/docs/sprites" >}}) chapter.
- **Keep the score display-ready.** Storing the score in BCD means no run-time binary-to-decimal conversion — the nibbles *are* the digits. That trade (decimal math for free display) is why nearly every VCS score is BCD.
