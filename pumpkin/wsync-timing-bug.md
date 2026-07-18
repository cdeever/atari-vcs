# The one cycle that turned NTSC into PAL

A worked debugging story from `pumpkin.asm`: how a single misplaced CPU
cycle in a kernel loop **doubled every scanline in the pumpkin's face**,
ballooned the frame from 262 lines to ~349, and made the emulator render the
whole game in the wrong TV standard — plus the two-cycle fix.

The symptoms did not look like a timing bug at all:

- The pumpkin came up **green instead of orange**, the stem **blue instead of green**.
- Forcing the emulator to NTSC fixed the colors but introduced **constant flicker**.
- Everything *looked* stable frame-to-frame, and the code assembled clean.

None of that points at "a `sta WSYNC` is one cycle late." Here's the chain.

---

## 1. Why the face has a per-scanline kernel

The eyes, nose, and mouth are gaps in the playfield where the background
color (`COLUBK`) shows through. To make them *glow* (candle flicker when
idle, hard white strobe while laughing) you change `COLUBK`. But a scanline
has only **one** background color, and we need **three** regions across the
line: black sky at the edges, orange body, and a lit face in the middle.

Three colors from two means changing `COLUBK` **mid-scanline**, timed to the
beam. So the face isn't drawn with the simple `REPEAT n / WSYNC` bands the
rest of the pumpkin uses — it's a cycle-counted loop, one iteration per line:

```asm
    ldx #FACELINES-1
.faceLine:
    sta WSYNC              ; top of the line
    lda FacePF0,x
    sta PF0               ; ... per-scanline playfield from tables
    lda StrobeColor
    nop
    sta COLUBK            ; ~column 4:  glow ON, hidden under the body edge
    REPEAT 15
        nop               ; coast across the lit interior
    REPEND
    lda #0
    sta COLUBK            ; ~column 33: glow OFF, before the right-side sky
    inx                   ; <-- the bug lives in this tail
    cpx #FACELINES
    bne .faceLine
```

Each iteration must be **exactly one scanline**. That is the whole contract,
and it depends on where the loop's own `sta WSYNC` lands.

---

## 2. How a late `WSYNC` write costs a whole line

`WSYNC` halts the CPU until the **start of the next scanline**. Write it
anywhere inside the current 76-cycle line (cycles 0–75) and the CPU resumes at
cycle 0 of the next line: one scanline consumed, exactly as intended.

But `sta` writes its value on its **third cycle**. Trace the loop tail with
`inx` / `cpx` / `bne` (counting up), starting from the top `WSYNC` at cycle 0:

```
    ... sta COLUBK (black) ends at cyc 67
    inx             2  -> 69
    cpx #FACELINES  2  -> 71
    bne .faceLine   3  -> 74   (taken)
    sta WSYNC starts at cyc 74 -> writes on its 3rd cycle = cyc 76
```

Cycle 76 is cycle **0 of the next line**. The `WSYNC` write lands one line too
late, so it halts through that entire next line as well. **Every face line
became two scanlines.**

The face is 87 lines in the kernel; doubled, that's 174. The visible region
blew past 192, and the whole frame went from a clean **262 lines to ~349**.

---

## 3. Why that showed up as "wrong colors"

Emulators auto-detect NTSC vs PAL by **counting scanlines per frame**. A ~262
line frame is NTSC; a much longer one gets guessed as PAL. At 349 lines Stella
locked onto **PAL** — and here is the sting:

> The color bytes never changed. `$38` is orange in the NTSC palette and
> **green** in the PAL palette; `$D4` is green in NTSC and **blue** in PAL.

So "green pumpkin, blue stem" wasn't a color bug at all — it was the *correct*
NTSC color values being drawn with the *wrong* palette, because the frame was
the wrong length. Forcing the emulator back to NTSC then fought the 349-line
signal it was actually receiving, which is what produced the flicker. Two
scary-looking symptoms, one root cause, and neither of them says "cycle 76."

---

## 4. The fix: count down, save two cycles

The write needs to land by cycle 75. The tail was one cycle too long, so shave
it. Counting **down** with `dex` / `bne` needs no separate compare — `dex`
sets the zero flag itself — so it is **two cycles cheaper** than `inx` / `cpx`
/ `bne`, and those two cycles come *after* the color writes, leaving the strobe
timing untouched:

```
    ... sta COLUBK (black) ends at cyc 67
    dex             2  -> 69
    bpl .faceLine   3  -> 72   (taken)
    sta WSYNC starts at cyc 72 -> writes on its 3rd cycle = cyc 74   (in the line!)
```

Cycle 74 is inside the line, so `WSYNC` halts to the next line: **one scanline
per iteration**, frame back to 262, NTSC auto-detected, colors correct, flicker
gone. Counting down means the loop visits the table from the end, so the
`FacePF0/1/2` tables are simply **stored reversed** to compensate.

```asm
    ldx #FACELINES-1
.faceLine:
    sta WSYNC
    lda FacePF0,x     ; tables stored top-last to match X counting 85..0
    ...
    dex
    bpl .faceLine     ; 2 cycles cheaper -> WSYNC write lands in-line
```

---

## The scoreboard

| tail | cycles | `sta WSYNC` starts | write lands | lines/iter | frame | detected |
|------|-------:|-------------------:|------------:|:----------:|------:|:--------:|
| `inx` / `cpx` / `bne` | 7 | cyc 74 | cyc 76 (next line) | **2** | ~349 | PAL (green) |
| `dex` / `bpl`         | 5 | cyc 72 | cyc 74 (in line)   | 1 | 262 | NTSC (orange) |

## The takeaway

Three lessons from one cycle:

1. **When a kernel loop drives `WSYNC`, count from the top `WSYNC` to the next
   one — and remember `sta` writes on its third cycle.** The write must land by
   cycle 75. Land it on 76 and you silently get two lines instead of one.
2. **A wrong frame length disguises itself as a color bug.** Auto-detect uses
   scanline count, and NTSC vs PAL are *different palettes* for the same bytes.
   Green where you expected orange is a strong hint the frame isn't 262 lines.
3. **How you close a loop is a swappable, high-leverage decision.** `dex`/`bpl`
   vs `inx`/`cpx`/`bne` is normally a micro-optimization; here those two cycles
   were the difference between a working NTSC frame and a broken PAL one.
