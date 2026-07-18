# Techniques used in `xmas.asm`

An inventory of the VCS techniques this ROM leans on, grouped by system, with
where each lives in the source. The [README](README.md) walks the picture; the
[light-optimization writeup](light-optimization.md) is the deep-dive on the
blinking bulbs. This is the parts list.

## Graphics — the tree

- **Reflected playfield as a symmetric shape.** `CTRLPF` D0 (reflect) mirrors
  the left 20 columns into the right, so the tree is symmetric and you only
  describe half of it (`xmas.asm:283`).
- **Playfield-only kernel.** The tree body uses *no sprites at all* — the whole
  triangle is written into `PF0/PF1/PF2` as the beam scans down.
- **Growing a triangle by widening bits.** Each band lights one more bit of
  `PF2` and holds it for ~10 scanlines (`REPEAT 10 / WSYNC`), so the lit region
  widens one playfield pixel every band; reflection turns that into a triangle.
  Lower bands cross into `PF1`, then a narrow `PF2` band forms the trunk and a
  full-width `PF0+PF1+PF2` band draws the ground line.
- **Minding the irregular bit order.** `PF0` uses only its high nibble and reads
  MSB-first; `PF1` reads in the *opposite* direction from `PF0`/`PF2`. The tidy
  widening masks work because the body stays in `PF2`; the ground line has to
  account for the reversal (`#%11101111` on `PF0`, `#%11111111` on `PF1`).

## Graphics — sprites

- **Missile 0 as 20 blinking bulbs.** There is only one missile, re-parked at a
  different column for each bulb as the beam descends. Its position is *timed*:
  after a `WSYNC`, burn cycles, then strobe `RESM0` — later strobe, further
  right (`NUSIZ0` sets the 4-px width, `xmas.asm:67`).
- **Comb-free positioning via a shared nop-sled.** Rather than 19 `nop`s per
  bulb or a `HMOVE` (which combs the left edge), all bulbs `jmp` into *one*
  shared run of `nop`s at a different offset — the nop count *is* the column,
  timed purely by the missile. Full story in
  [light-optimization.md](light-optimization.md).
- **Data-driven bulbs.** `DrawBulb` is called with `jsr` per bulb; all variety
  lives in the `BulbX` / `BulbColor` tables. Position is data, not code.
- **A twinkling star (player 0).** An 8-row starburst bitmap (`StarBitmap`)
  drawn at the tree's apex, coarse-positioned with a delay loop + `RESP0`, then
  fine-nudged with `HMP0` on an `HMOVE` — and the `HMOVE`'s 8-px left comb is
  deliberately parked on a blank VBLANK line so it never shows (`xmas.asm:134`).

## Sound — a frame-driven music player

- **Once-per-frame sequencer.** The tune advances one frame's worth per frame
  in VBLANK, so it costs a handful of cycles and leaves the picture intact.
- **`(pitch, duration)` song table.** `Song` is byte pairs; `$00` = end (mute
  and hold until RESET), `$01` = rest, else the pitch is an `AUDF0` value.
  `AUDC0 = 12` (pure tone) is set once; `AUDV0` is set per note.
- **`SongPtr` / `NoteTimer` state machine.** A tiny VBLANK routine counts the
  current note down, then fetches the next `(pitch, duration)` pair.
- **RESET replays the song.** Reading `SWCHB` bit 0 (console RESET, active-low)
  rewinds `SongPtr`/`NoteTimer` so the tune retriggers (`xmas.asm:460`).

## Animation & control

- **One free-running frame counter drives everything.** `FrameCtr` increments
  each frame; its bits pick the star's twinkle color, stagger the bulb blink,
  and nudge the star's position.
- **Bulb blink from counter bits.** Bits 4–6 of `FrameCtr` give an 8-step,
  128-frame cycle; each block's pair of bulbs is lit for most of it and winks
  dark on one step, the steps staggered so only a couple blink at once
  (`Light0On..Light9On`, indexed by bulb/2).
- **Star twinkle palette.** `TwinkleColors` is cycled by `FrameCtr` (divided
  down to ~15 changes/sec) for a Pitfall-treasure shimmer.
- **Build-time `SOUND_ENABLED` flag** (`xmas.asm:12`) compiles the music in or
  out for silent testing.

## Cross-cutting

- **Repetition and padding are data in disguise.** The bulbs' evolution — from
  826 bytes of unrolled `nop` padding to a ~150-byte routine plus two 20-byte
  tables — is the through-line of the [optimization writeup](light-optimization.md):
  when you see the same shape unrolled, find the single number that varies.
- **Exact frame budget.** The visible bands' `REPEAT` counts must sum to 192;
  VSYNC 3 + VBLANK 37 + visible 192 + overscan 30 = 262 lines.
