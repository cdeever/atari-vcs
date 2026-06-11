---
title: "Prerequisite Knowledge"
weight: 8
bookCollapseSection: true
BookIcon: prereq
---

# Prerequisite Knowledge

Before the toolchain and your first ROM, a handful of fundamentals make everything that follows legible. None of them is really "programming" in the usual sense — they are the mental model the VCS forces on you, and the rest of the book quietly assumes all of them. The throughline: you must understand the **display** you're driving, the **notation** the code is written in, and the way data is just **bits at addresses**.

Work through them in order, then head to [Getting Started]({{< relref "/docs/getting-started" >}}) to set up your tools and build a ROM.

- **[How a Television Works]({{< relref "how-the-tv-works" >}})** — the beam, scanlines, frames, sync, and NTSC vs. PAL. The display medium that dictates everything else.
- **[Reading 6502 Assembly]({{< relref "reading-assembly" >}})** — mnemonics, operands, labels, and directives: just enough to follow the code in every later chapter.
- **[Thinking in Bits]({{< relref "bits" >}})** — binary and hex, masks, and the four bit operations.
- **[Numbers & Arithmetic]({{< relref "numbers" >}})** — signed values via two's complement, carrying between bytes, and life on a chip with no multiply.
- **[The Memory-Mapped Interface]({{< relref "memory-mapped" >}})** — registers as addresses, write-only and strobe registers, and reading live hardware state.
