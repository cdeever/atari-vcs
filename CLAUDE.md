# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A collection of homebrew Atari 2600 (VCS) games and experiments written in 6502 assembly for the DASM assembler. It follows the approach taught in Gustavo Pezzi's Pikuma "Atari 2600 Assembly" course. ROMs are tested in the Stella emulator.

## Repository layout

Shared headers live in a top-level **`include/`** directory — `vcs.h` (TIA/RIOT register definitions), `macro.h` (DASM helper macros like `CLEAN_START`), and `xmacro.h` (TIMER_SETUP/TIMER_WAIT timer macros). Each game references them through DASM's include path (`-I../include`), so they are a single source of truth rather than per-project copies. Each game directory holds only its own source and data.

- `xmas/` — a Christmas-tree playfield demo (`xmas.asm`), the most actively developed project. Has a `Makefile`.
- `combat-src/` — work based on a disassembly of the original *Combat* cartridge (`dicombat2.asm`, ~70KB). Has a `Makefile`. (Git-ignored.)
- `music/` — a 4-voice direct-DAC audio experiment (`wavetable.a`) that consumes 100% CPU, so it renders no video. Uses `include/xmacro.h` for its scanline timing. Has a `Makefile`.

## Build & run

DASM is installed (`/opt/homebrew/bin/dasm`). Stella is **not** currently installed (`brew install --cask stella` to add it).

Build from inside a project directory:

```sh
cd xmas && make          # assembles xmas.asm -> xmas.bin (+ .sym, .lst)
make run                 # launches Stella on the .bin
```

The underlying DASM invocation — note `-I../include`, which points DASM at the shared headers:

```sh
dasm xmas.asm -I../include -f3 -v0 -oxmas.bin -sxmas.sym -lxmas.lst
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
