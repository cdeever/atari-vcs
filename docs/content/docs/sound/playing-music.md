---
title: "Playing Music"
weight: 30
---

# Playing Music

A steady tone is just six registers holding their values. **Music** is what happens when you change them on a schedule — and the schedule is the [frame]({{< relref "/docs/prerequisites/how-the-tv-works" >}}). A small routine, run once per frame, reads a song out of a data table and updates the [audio registers]({{< relref "the-audio-registers" >}}); that routine is a *sound engine*, and even a tiny one carries a whole tune.

## A song is a data table

The simplest useful format is a list of **(note, duration)** pairs — which is exactly what the `Song` table in `xmas/xmas.asm` is: a note index and a length in frames, terminated by a zero:

```asm
Song:
    .byte $02, $10   ; note index $02, hold for $10 = 16 frames
    .byte $05, $08   ; note index $05, hold for 8 frames
    ; ...
    .byte $00        ; 0 = end of song
```

The note byte isn't a frequency — it's an index into the [note → `AUDF` table]({{< relref "tones-noise-and-pitch" >}}). The duration is counted in frames, so 16 frames ≈ a quar-second beat at 60 Hz. Separating "the tune" (this data) from "the player" (the code below) is what lets one routine play any song.

## The per-frame player

The engine keeps two pieces of state in RAM: a pointer into the song, and a countdown of frames left on the current note. Once per frame:

```asm
    dec NoteTimer        ; one frame closer to the next note
    bne SoundDone        ; still holding the current note → nothing to do

    ; time for the next note: read the song
    ldy SongIndex
    lda Song,y           ; note index
    beq RestartSong      ; 0 = end → loop (or silence)
    tax
    lda NoteTable,x      ; look up this note's AUDF
    sta AUDF0
    iny
    lda Song,y           ; duration in frames
    sta NoteTimer
    iny
    sty SongIndex
SoundDone:
```

That's the entire idea: count down, and when the timer expires, advance to the next entry and load its pitch. Set `AUDC0` and `AUDV0` once at startup (or per note for changing timbres) and the channel sings. A second channel running the same loop over a second table gives you bass or harmony.

## Making it expressive: envelopes

A note that snaps on at full volume and snaps off sounds mechanical. Because `AUDV` is just a number you can rewrite every frame, you can shape a crude **envelope** — most usefully a *decay*, fading the volume down across the note's frames for a plucked, percussive feel:

```asm
    lda NoteTimer        ; frames left on this note
    cmp #16
    bcc UseTimer
    lda #15              ; cap at max volume
UseTimer:
    sta AUDV0            ; volume tracks frames remaining → fades out
```

The same trick builds sound effects: a laser is a tone with `AUDF` sliding upward each frame; an explosion is [noise]({{< relref "tones-noise-and-pitch" >}}) with `AUDF` sliding down and `AUDV` fading to zero. A sound effect is just a tiny, one-shot song.

## Beyond two voices

Frame-rate updates and two channels are plenty for melody-plus-bass, but the ceiling is real. To go further you leave the tone generators behind entirely and drive `AUDV` itself as a **4-bit DAC**, computing the waveform sample by sample — the technique the repository's [4-Voice Music Player]({{< relref "/docs/projects/music-player" >}}) uses to get four voices, at the price of the *entire* CPU (it shows no picture while it plays).

## In Practice

- **Run the engine in [VBLANK or overscan]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}).** Music updates are per-frame logic, not kernel work — do them in the blank regions, never in the visible scanlines.
- **One engine, many songs.** Keep the player generic and the music in data tables; adding a tune should mean adding bytes, not code.
- **Silence is a note too.** Reserve a note index (or `AUDV 0`) for rests, so the table can encode gaps as cleanly as pitches.
