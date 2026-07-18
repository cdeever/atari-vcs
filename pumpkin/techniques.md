# Techniques used in `pumpkin.asm`

An inventory of the VCS techniques this ROM leans on, grouped by system, with
where each lives in the source. The [README](README.md) tells the story;
this is the parts list. For the deep-dive on the one that bit us, see
[The one cycle that turned NTSC into PAL](wsync-timing-bug.md).

## Graphics — the shape

- **Reflected playfield as a symmetric shape.** `CTRLPF` D0 (reflect) mirrors
  the left 20 columns into the right, so the pumpkin is symmetric for free and
  you only describe half of it. Same idea as the [xmas](../xmas/README.md) tree.
- **The face is holes, not ink.** Orange is playfield-ON; the eyes/nose/mouth
  are playfield-OFF gaps where the background shows through — carving a
  jack-o'-lantern is literally cutting holes, which is what an OFF bit does.
- **Reflection-aware feature design.** The mouth's teeth fall out of the
  mirror: two top teeth are one tooth per half; the single bottom tooth is
  `PF2` bit 7, mirrored to a 4-px tooth exactly on the centerline seam.
- **Bands generated from ASCII art.** The playfield bit order is irregular
  (`PF0` high-nibble MSB-first, `PF1` reversed, `PF2` LSB-first), so the bands
  are emitted from an ASCII design by `scratchpad/gen_pumpkin.py` rather than
  hand-computed. The generator is the source of truth; edit art, regenerate.

## Graphics — the light (mid-scanline color)

- **Three colors from two, via a per-scanline kernel.** A scanline has one
  background color, but the scene needs black sky + orange body + a lit face.
  The face band is a cycle-counted loop that switches `COLUBK` to the glow
  color across the interior only and back to black at the edges, so the light
  stays inside the outline. This is the ROM's trickiest kernel.
- **Per-scanline playfield from page-aligned tables.** `FacePF0/1/2` hold one
  byte per face line; the kernel reads them indexed by the line counter. They
  are page-aligned (and stored reversed) so the indexed reads keep the strobe
  timing consistent — see the [WSYNC writeup](wsync-timing-bug.md) for why the
  loop counts *down* with `dex`/`bpl`.

## Sound — a frame-driven "evil laugh"

- **Once-per-frame envelope player.** PCM playback is 100% CPU (no picture), so
  the laugh is a table walked one row per frame in VBLANK — a few register
  writes, leaving the whole scanline budget for video. (See `../music/` for the
  opposite, video-less DAC approach.)
- **Voice-forward timbre.** The voice is a rough poly-tone (`AUDC 6`, the
  *Adventure* death sound), not a pure tone — pure tones read as melody.
- **Per-syllable downward pitch sweeps, off-scale.** Each "ha" ramps `AUDF`
  (a divider, so up = down in pitch) with jittered start pitches that never
  land on a scale — a wide, non-musical pitch range is what reads as menacing.
- **Packed-nibble volumes for an aspirated onset.** One volume byte carries
  voice (high nibble) and breath-noise (low nibble) independently, so a
  syllable can lead with a breath-only frame ("h") before the voice swells
  ("ah") — otherwise the tone slams on as a plosive "B".
- **Per-frame `AUDF` warble.** A ±1 pitch jitter each frame turns a clean tone
  into a gravelly growl.
- **Data table + generator.** `LaughData` is emitted by `scratchpad/gen_laugh.py`
  (a `DEEPEN` knob transposes the whole laugh).

## Randomness & animation

- **8-bit LFSR as a shared PRNG.** One `lda / lsr / bcc / eor #$B4 / sta`
  register (seeded non-zero at reset, or it locks at 0) drives both the candle
  flicker and the voice warble.
- **Candle glow.** Idle, the face cutouts flicker through a warm palette
  (`CandleColors`) picked at random every 8 frames and held between picks —
  kept brighter than the body orange so the features never blend in.
- **Free-running frame counter** (`FrameCtr`) drives the strobe cadence and the
  candle's step rate.

## Input & control flow

- **Edge-detected triggers.** The laugh fires on power-on, on console `RESET`
  (`SWCHB` bit 0), and on the joystick `FIRE` (`INPT4` bit 7), all active-low.
  A one-frame latch (`TrigPrev`) makes one press equal one laugh.
- **Exact frame budget.** VSYNC 3 + VBLANK 37 + visible 192 + overscan 30 = 262.
  The audio tick and strobe pick are split across separate VBLANK scanlines so
  each stays inside its 76-cycle line.

## Cross-cutting

- **Generators as source of truth.** The band table, per-scanline face tables,
  candle palette, and laugh table are all emitted by small Python scripts in
  `scratchpad/` — design there, regenerate, paste. Hand-editing hex is a trap.
- **Sprites left on the table (literally).** The pumpkin is playfield-only, so
  all five movable objects (2 players, 2 missiles, ball) are unused and free for
  future scenery (a moon/stars sky was prototyped on player 0 + reflected PF).
