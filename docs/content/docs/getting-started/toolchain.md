---
title: "Toolchain: DASM & Stella"
weight: 11
---

# Toolchain: DASM & Stella

Two tools cover the entire development loop for this book: **DASM** assembles your `.asm` source into a cartridge image, and **Stella** runs that image as if it were a real console.

## Installing

On macOS with Homebrew:

```sh
brew install dasm
brew install --cask stella
```

DASM is the de-facto assembler for the VCS; Stella is the reference emulator and an excellent debugger.

## Assembling a ROM

The canonical build command (from the repository's `xmas/Makefile`) is:

```sh
dasm xmas.asm -f3 -v0 -oxmas.bin -sxmas.sym -lxmas.lst
```

| Flag | Meaning |
|------|---------|
| `-f3` | Output format 3: a raw cartridge image with no header — what the VCS expects. |
| `-v0` | Verbosity 0: quiet unless there's an error. |
| `-o`  | Output binary (`.bin`). |
| `-s`  | Emit a **symbol table** (`.sym`) — every label and its address. |
| `-l`  | Emit a **listing** (`.lst`) — source interleaved with the bytes and addresses it produced. |

The `.sym` and `.lst` files are your primary debugging aids: the listing shows exactly what each line assembled to, and the symbol table lets Stella's debugger show your label names.

## Running

```sh
stella xmas.bin
```

In this repository each project directory has a `Makefile` wrapping these two commands:

```sh
cd xmas
make        # assemble -> xmas.bin
make run    # launch Stella on the .bin
```

> **There is no separate "lint" or "test" step.** On the VCS, assembling cleanly is the first check and watching the picture in Stella is the second. The `.lst` file is where you confirm a routine fits its cycle budget.

## In Practice

If a change makes the screen roll, tear, or go black, the cause is almost always *timing* — a scanline region with the wrong number of `WSYNC`s — not a syntax error. Stella's TV mode and its debugger's scanline counter are the fastest way to find which region drifted. See [The Frame Structure]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}) for the line counts every frame must hit.
