# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A collection of homebrew Atari 2600 (VCS) games and experiments written in 6502 assembly for the DASM assembler. It follows the approach taught in Gustavo Pezzi's Pikuma "Atari 2600 Assembly" course. ROMs are tested in the Stella emulator.

## Repository layout

Each top-level directory is a **self-contained, independent project** with its own copy of `vcs.h` (TIA/RIOT register definitions) and `macro.h` (DASM helper macros like `CLEAN_START`). These header copies are byte-identical across projects — when editing one, consider whether the others need the same change.

- `xmas/` — a Christmas-tree playfield demo (`xmas.asm`), the most actively developed project. Has a working `Makefile`.
- `combat-src/` — work based on a disassembly of the original *Combat* cartridge (`dicombat2.asm`, ~70KB). Has a `Makefile` (note: its `run` target mistakenly points at `xmas.bin`).
- `music/` — a 4-voice direct-DAC audio experiment (`wavetable.a`) that consumes 100% CPU, so it renders no video. Adds `xmacro.h` (TIMER_SETUP/TIMER_WAIT scanline-timing macros). **No Makefile** — build manually (see below).

## Build & run

DASM is installed (`/opt/homebrew/bin/dasm`). Stella is **not** currently installed (`brew install --cask stella` to add it).

Build from inside a project directory:

```sh
cd xmas && make          # assembles *.asm -> xmas.bin (+ .sym, .lst)
make run                 # launches Stella on the .bin
```

The underlying DASM invocation (use this for `music/`, which has no Makefile, or to build a specific file):

```sh
dasm wavetable.a -f3 -v0 -omusic.bin -smusic.sym -lmusic.lst
```

Flags: `-f3` = raw cartridge output format, `-v0` = quiet, `-o` = binary out, `-s` = symbol table, `-l` = listing file. There is no separate lint or test step — assembling clean *is* the check, and the `.lst`/`.sym` outputs are the debugging artifacts.

Build outputs (`*.bin`, `*.lst`, `*.sym`, `*.a26`, `*.a78`) are git-ignored, but some are currently committed in the tree.

## Working with the 2600 hardware model

Programs are **"racing the beam"**: the CPU must emit output in lockstep with the TV's electron beam, one scanline at a time. The canonical frame structure (see `xmas/xmas.asm` for a clean example) is:

1. **VSYNC** — 3 scanlines, signal start of frame.
2. **VBLANK** — 37 scanlines, top blanking; do game logic here.
3. **Visible** — 192 scanlines; write TIA registers (`COLUBK`, `COLUPF`, `PF0/PF1/PF2`, etc.) and `sta WSYNC` to advance exactly one scanline at a time.
4. **Overscan** — 30 scanlines, bottom blanking.

Then `jmp` back to the frame start. Cycle counting matters: every TIA write must land in the right horizontal position, so `WSYNC` (wait-for-sync) and the `REPEAT n / REPEND` macro are used heavily to burn precise numbers of scanlines.

Every ROM ends with the 6502 reset vectors:

```asm
    org $fffc
    .word Reset
    .word Reset
```

`org` for code is typically `$f800` (2K cart) or `$f000` (4K cart) — match the existing `org` in the file you're editing.

## Conventions

- `.gitattributes` marks `*.h` and `Makefile` as non-detectable so GitHub reports the repo as Assembly; `*.asm` and `*.h` are tagged as Assembly language.
- `.asm` and `.a` are both used as assembly source extensions (`.a` only in `music/`).
