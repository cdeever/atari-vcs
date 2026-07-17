# Optimizing the tree lights — a 2600 ROM story

A worked example from `xmas.asm`: how the 20 blinking tree bulbs went from
eating **half the cartridge** to a small routine plus a data table — and the
one visible glitch that optimization introduced, and how it was fixed.

The whole thing is three git commits, so `git diff` between them is the lesson:

| commit | state |
|--------|-------|
| `684e356` | features done — bulbs positioned with hand-tuned `nop` padding |
| `0d66337` | optimized (divide-by-15 + `HMOVE`) — **but a comb appears** |
| `a7af64c` | comb fixed (shared nop-sled), sound switched on |

---

## 1. Where we started: 20 bulbs, and what they cost

The cart is a **2K ROM** (2048 bytes). Each bulb is TIA **missile 0**,
re-parked at a different column for every bulb as the beam scans down the tree.
There's only one missile, so its horizontal position has to be *timed*: after a
`WSYNC`, you burn a precise number of cycles, then strobe `RESM0`. The later the
strobe, the further right the bulb.

The original code did that timing with literal `nop` instructions, one bulb per
macro invocation:

```asm
    MLIGHT 19, $46, Light0On   ; -> emits 19 nops, then STA RESM0, colour, blink
    MLIGHT 20, $0E, Light0On
```

Twenty of those, unrolled. The damage:

- **~826 bytes** for the 20 bulbs
- **386 of those bytes were literally `nop`** — pure padding whose only job was
  to waste time
- Cart total: **1,634 / 2,048 used, 414 free**

Half the ROM was the lights, and a fifth of the *whole cart* was do-nothing
`nop`s. That's the "extra" worth reclaiming.

---

## 2. The optimization: make position data, not code

The insight: a bulb's column is just **one number**. It doesn't need 19 bytes of
`nop` — it needs one data byte and a *shared* routine that turns that byte into a
missile position. That's the classic 2600 **divide-by-15** positioning idiom:

```asm
DrawBulb:
    ldx BulbIdx
    lda BulbX,x            ; A = target column (0-159), ONE data byte
    sta WSYNC
    sec
.d15:
    sbc #15                ; loop until negative; the loop's runtime IS
    bcs .d15               ;   the coarse position (15px per pass)
    eor #$07               ; leftover remainder -> a fine HMOVE nudge
    asl
    asl
    asl
    asl
    sta HMM0               ; fine motion for missile 0
    sta RESM0              ; coarse strobe
    sta WSYNC
    sta HMOVE              ; <-- apply the fine adjust
    ...
```

Now every bulb is `jsr DrawBulb`, and all the per-bulb variety lives in two
20-byte tables (`BulbX`, `BulbColor`). The 386 bytes of padding and the
20-times-repeated body collapse into ~150 bytes.

- Lights: **~826 → ~150 bytes**
- Cart total: **961 / 2,048 used, 1,087 free**
- **~673 bytes freed** — more than a quarter of the whole cart

Same 20 bulbs, same scattered layout, same blink. Just far less ROM.

---

## 3. The catch: the comb

Flip it on and there's a new artifact — a column of little **black notches down
the far-left edge of the screen**, one on each line where a bulb is drawn. A
"comb."

That's `HMOVE`, and it's not a bug in our code — it's how `HMOVE` works:

- The divide-by-15 loop only positions to the nearest **15 pixels** (coarse).
  The `HMM0` + `HMOVE` step supplies the **fine** adjustment (the last 0–14 px).
- To do that fine motion, the TIA needs extra time, so **strobing `HMOVE`
  extends that scanline's horizontal blank by 8 color clocks**.
- Those 8 clocks eat the **leftmost 8 pixels** of the visible line, blanking
  them to black — the comb "teeth."

We strobe `HMOVE` once per bulb (to place the missile), so ~20 scanlines each get
an 8px black notch on the left. Stack them vertically and you get the comb. It's
in the background margin, well left of the tree — and real TVs often hide it in
overscan — but in an emulator it's right there. It is, in fact, the visual
fingerprint of a *lot* of classic 2600 games.

---

## 4. The fix: position without `HMOVE` (a shared nop-sled)

The comb comes entirely from `HMOVE`. And `HMOVE` was only there for
*sub-15-pixel* precision — which the original `nop` version never had anyway (it
stepped in ~6px units and looked fine). So: drop `HMOVE`, keep 6px steps, but
**still don't pay 19 bytes per bulb**.

The trick is one shared run of `nop`s — a "sled" — that every bulb **jumps into
at a different offset**. Enter near the end and few nops run (early strobe, left
bulb); enter near the start and many run (late strobe, right bulb):

```asm
MAXNOPS = 30

DrawBulb:
    ldx BulbIdx
    lda #MAXNOPS
    sec
    sbc BulbX,x            ; entry = MAXNOPS - nopcount
    clc
    adc #<Sled
    sta SledPtr
    lda #>Sled
    adc #0
    sta SledPtrH          ; SledPtr -> Sled + entry
    sta WSYNC
    ldy #0
    sty ENAM0
    jmp (SledPtr)          ; run exactly BulbX[i] nops...
Sled:
    REPEAT MAXNOPS
        nop
    REPEND
    sta RESM0              ; ...then strobe. No HMOVE anywhere.
    ...
```

Position is now timed **purely by the missile** — no `HMOVE`, so **no comb** —
and the sled is written *once* and shared by all 20 bulbs. Everything else (the
tables, the `jsr DrawBulb` block callers, the blink logic) is untouched; only the
~15-line positioning primitive inside `DrawBulb` changed.

The cost of going comb-free: the shared sled is ~30 bytes the divide-by-15
version didn't need, so it's **~32 bytes larger** than the comb version — a great
trade to delete a visible artifact.

---

## The scoreboard

| version | lights | cart used | free | comb? |
|---------|-------:|----------:|-----:|:-----:|
| hand-tuned `nop` padding | ~826 B | 1,634 | 414 | no |
| divide-by-15 + `HMOVE`   | ~150 B |   961 | 1,087 | **yes** |
| nop-sled (comb-free)     | ~185 B |   993 | 1,055 | no |

*(all measured with sound off, for an apples-to-apples comparison; the shipped
ROM then enables the music, ending at 1,057 used / 991 free.)*

## The takeaway

Two lessons, one small kernel:

1. **Repetition and padding are data in disguise.** 386 bytes of `nop` + a body
   repeated 20× became one routine + a 40-byte table. When you see the same
   shape unrolled, ask what single number distinguishes each copy.
2. **How you position is an isolated, swappable decision.** The divide-by-15 and
   the nop-sled produce identical bulbs; the *only* difference is the primitive
   buried in `DrawBulb`. That's why the comb fix was a ~15-line swap, not a
   rewrite — and why the comb (and its cause) is worth understanding before you
   reach for `HMOVE`.
