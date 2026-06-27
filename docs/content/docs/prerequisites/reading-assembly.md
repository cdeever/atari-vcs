---
title: "Reading 6502 Assembly"
weight: 15
---

# Reading 6502 Assembly

Every line of code in this book is **6502 assembly language** — human-readable names for the numeric machine code the 6507 actually executes. [DASM]({{< relref "/docs/getting-started/toolchain" >}}) translates it into the bytes that go on the cartridge. You don't need to *write* it fluently yet, but you do need to *read* it, because every concept here is demonstrated in it. This page is just enough to follow along; the CPU's full instruction set and addressing modes are the [6502 Basics]({{< relref "/docs/6502-basics" >}}) chapter.

## One line, one instruction

Assembly is close to the metal: as a rule, **each line is a single CPU instruction**, and the lines run top to bottom unless something jumps. A line has up to four parts, most of them optional:

```asm
Label:   mnemonic   operand    ; comment
```

```asm
StartFrame:              ; a label — a name for this address
    lda #02              ; load A with the value 2
    sta VSYNC            ; store A into the VSYNC register
```

## Mnemonics — the verbs

A **mnemonic** is a three-letter name for an operation. A handful do most of the work in VCS code:

| Mnemonic | Does |
|----------|------|
| `lda` / `ldx` / `ldy` | **load** a value into register A, X, or Y |
| `sta` / `stx` / `sty` | **store** a register into memory |
| `jmp` | jump to a label |
| `beq` / `bne` | branch if the last result was zero / not zero |
| `inx` / `dex` | increment / decrement X |

A, X, and Y are the 6502's three 8-bit **registers** — the scratch values the CPU works with. More on them in [6502 Basics]({{< relref "/docs/6502-basics" >}}).

## Operands — and the symbols that change their meaning

The **operand** is what the instruction acts on, and a couple of punctuation marks completely change what it means — this trips up every newcomer:

- **`#` means "the literal value."** `lda #02` loads the *number* 2.
- **No `#` means "the value at this address."** `lda VSYNC` loads whatever is *stored at* `VSYNC`.

That one symbol is the difference between *the number 9* and *the contents of address 9*. Two more you'll see constantly:

- **`$`** marks a hexadecimal number, **`%`** a binary one (see [Thinking in Bits]({{< relref "bits" >}})). No prefix means decimal.
- **`,X` or `,Y`** after an address means "add register X (or Y) to it first" — indexed access, used to walk through tables.

## Labels — names for addresses

A **label** (a name followed by `:`) marks a location in the code. The assembler remembers its address so you can refer to it by name — as a jump target (`jmp StartFrame`), a branch target, or the address of a variable or data table. You never compute raw addresses by hand; you name things and let DASM track where they land.

## Directives — instructions to the assembler, not the CPU

Some lines aren't CPU instructions at all; they're **directives** that tell DASM how to build the ROM. They're easy to spot once you know the common ones:

| Directive | Means |
|-----------|-------|
| `processor 6502` | assemble for the 6502 family |
| `include "vcs.h"` | pull in another file (here, the register names) |
| `seg` / `seg.u` | begin a segment (`.u` = uninitialized, i.e. RAM) |
| `org $f000` | place the following code/data at this address |
| `COLUBK = $09` | define a constant name for a value |
| `.byte` / `.word` | lay down raw data bytes / 2-byte words |
| `REPEAT n` … `REPEND` | emit the enclosed lines `n` times |

`vcs.h` and `macro.h` are nothing but directives — equates that name every hardware register, and macros like `CLEAN_START` that expand into several instructions.

## Putting it together

You now have enough to read a real fragment. From the Christmas-tree kernel:

```asm
    ldx #0          ; X = 0
    stx PF1         ; clear playfield register PF1 (store X into it)
    REPEAT 7
        sta WSYNC   ; spend 7 scanlines
    REPEND
```

*Set X to zero, write that zero into the `PF1` register to blank it, then wait seven scanlines.* Once the symbols (`#`, `$`, labels, directives) stop being noise, the rest of the book reads as plain instructions.

## In Practice

- **`#` is the most important character on the line.** Forgetting it — `lda COLUBK` when you meant `lda #COLUBK` — is the single most common beginner bug: you load the *contents* of an address instead of the address (or value) itself.
- **Directives have no cost at runtime.** `org`, `=`, `REPEAT`, and `.byte` shape the ROM at assembly time; only mnemonics become executable bytes. Counting cycles? Count instructions, not directives.
- **Indentation is just style.** DASM keys off the *first column*: a name starting in column 1 is a label; instructions are conventionally indented. The whitespace itself carries no meaning.
