---
title: "Video Chess (1979)"
weight: 60
---

# Video Chess (1979)

*Video Chess* — **Larry Wagner** (the chess engine) and **Bob Whitehead** (the kernel and display), Atari — is the one that shouldn't fit. It is a **real chess program**: it knows the legal moves, it looks ahead, it plays a whole game against you at eight levels of strength. And it does all of that in **4 KB of ROM and 128 bytes of RAM** — less working memory than a single line of this paragraph. By legend it almost didn't ship: Atari had advertised a chess cartridge in its earliest VCS catalog, couldn't deliver for a year or two, and — the often-told story goes — a customer's threatened lawsuit over the no-show product is what finally pushed it out the door in 1979.

Every other teardown in this section is about *drawing*. This one is about *thinking* — and about the moment the VCS does something no other game here dares: it **stops drawing entirely** so it can compute.

## The shape of the program

The loop has a fork the others don't have — *show the board*, or *go dark and think*:

{{< graphviz >}}
digraph vidchess {
  rankdir=TB;
  bgcolor="transparent";
  node [shape=box, style="filled,rounded", fontsize=10, color="#808080", penwidth=1.1];
  edge [color="#808080", penwidth=1.2];

  init  [label="Power-up — place the pieces,\nbuild the 64-byte board ($80–$BF)", fillcolor="#e2e2e2"];
  show  [label="Show the board — normal frame loop:\nVSYNC / VBLANK, kernel draws the squares +\npieces (P0 & P1 multiplexed across each rank),\noverscan — and reads your joystick", fillcolor="#d2efd2"];
  your  [label="Your move applied to the board", fillcolor="#cfe0f5"];
  think [label="Computer's turn — STOP racing the beam:\nhold VBLANK on (screen goes dark), abandon\nthe kernel, spend 100% of the CPU on the\ndepth-limited look-ahead search", fillcolor="#f6e0c6"];
  comp  [label="Computer's move applied to the board", fillcolor="#cfe0f5"];

  init -> show -> your -> think -> comp;
  comp -> show [label="  your turn again", constraint=false, fontsize=9, fontcolor="#808080"];
}
{{< /graphviz >}}

## It stops racing the beam to think

Everything this book has taught is about the iron rule of the VCS: the CPU must serve the beam, every scanline, 60 times a second, forever. Video Chess **breaks the rule on purpose.**

When it's the computer's move, the program sets a "thinking" flag (`$F3`) and the frame loop takes a different path: it **leaves [`VBLANK`]({{< relref "/docs/tia-racing-the-beam" >}}) turned on and never runs the visible kernel.** The blanking signal stays high, the television shows nothing, and the entire 6507 — every last cycle that used to be spent positioning sprites and writing color registers — is handed to the search instead:

```asm
       LDY    $F3        ; thinking?
       BMI    LF075      ; yes → skip the whole visible kernel
       ...
LF0CA: ...
       STA    VBLANK     ; keep the screen blanked while we think
```

This is the same bargain as the book's [4-voice audio experiment]({{< relref "/docs/sound/playing-music" >}}), which spends 100% of the CPU on sound and so **renders no video at all**. Video Chess makes that trade *temporarily*: it goes dark for the duration of a move, then snaps the picture back the instant it has decided. At the gentle levels that's a flicker; crank the level up and the screen can sit black for **minutes** while the machine grinds through the tree — at the very top, famously, for far longer than anyone has the patience to wait.

It's the perfect inversion of the whole book. Racing the beam is what you do when you have spare cycles to spend on the picture. When you need *all* of them to think, you stop racing — and the dark screen is not a bug, it's the CPU telling you it's busy.

## A chessboard in 64 bytes

With only 128 bytes of RAM, the board can't be elaborate — and it isn't. It's a flat **64-byte array** living at `$80–$BF`: one byte per square, file 0–7 × rank 0–7. The kernel and the move generator pull a square apart with the cheapest possible arithmetic — [`AND #$07`]({{< relref "/docs/prerequisites/bits" >}}) for the file, the high three bits (`AND #$38`) for the rank:

```asm
LDA $D4 / AND #$07     ; file  (0–7)
LDA $D4 / AND #$38     ; rank  (0–7, in the high bits)
```

Each byte packs a **piece into its low nibble** (`AND #$0F`) and **color/state into the high nibble** (`AND #$F0`) — so a square is just a number, and an empty square is zero. The piece codes are easy to read straight out of the setup table at `LFEF2`, which seeds one back rank:

```asm
LFEF2: .byte $05,$04,$03,$02,$01,$03,$04,$05
;             R   N   B   Q   K   B   N   R
```

That's `$01`=King, `$02`=Queen, `$03`=Bishop, `$04`=Knight, `$05`=Rook — the standard opening row, **R N B Q K B N R**, copied into `$80–$87` at startup. The entire state of a chess game — 32 pieces, who's where, whose move — fits in those 64 bytes with room to spare for the search's scratch variables. It has to: there's nowhere else to put it.

## Thinking in 128 bytes

The engine does what every chess program does — **look ahead**: try a move, imagine the reply, score the resulting position, and back up the best line. Move generation (around `LFB91`) walks a piece's legal destinations from a per-type offset table (`LFFE8`), and positions are scored with a small piece-value table (`LFEC6`) using [BCD]({{< relref "/docs/prerequisites/numbers" >}}) arithmetic (`SED … ADC … CLD`). A depth counter in `$D8` is decremented as the search descends and bottoms out when it goes negative:

```asm
       DEC    $D8        ; one ply deeper
       BMI    LFA9D      ; depth exhausted → stop and evaluate
```

The **skill level** (read from the console switches) governs how deep and how long that search is allowed to run — which is exactly why the higher levels darken the screen for so long: more plies, exponentially more positions, all of them computed on a 1.19 MHz processor with 128 bytes to think in. There is no opening book, no endgame tables, no memory to *cache* anything — just the move generator, the evaluator, and the depth counter, run over and over until the clock (and your patience) runs out. That a credible game of chess comes out the other end is the small miracle of the cartridge.

## Drawing the pieces

When it *is* drawing, the display problem rhymes with [Space Invaders]({{< relref "spaceinvaders" >}}): show a grid of objects with only two player sprites. But chess pieces aren't six identical aliens — every square can hold a *different* piece — so Video Chess can't lean on `NUSIZ` copies. Instead it [multiplexes]({{< relref "/docs/advanced/sprite-multiplexing" >}}) P0 and P1 hard: as the beam crosses each rank it re-arms `GRP0`/`GRP1` from per-square graphics pointers and nudges the players across with `HMP0`/`HMP1` + `HMOVE`, painting the pieces a couple at a time, rank by rank down the board ([`VDELP0`]({{< relref "/docs/sprites/drawing-a-player" >}}) helps stagger them cleanly). The checkered squares and grid come from the [playfield]({{< relref "/docs/playfield" >}}) and background, with the missiles and ball drafted in for alignment and accents. It's a competent kernel — but here it's the *supporting* act.

## Why read it

Read Video Chess for the one thing nothing else in this section does: it **turns the picture off to think.** Every other program treats racing the beam as the job; this one treats it as a luxury it can't always afford, and the blank screen during a hard search is the most honest picture of the 6507's limits in the whole library. Read it, too, for the sheer audacity of fitting a look-ahead chess engine — board, move generator, evaluator, search — into **4 KB and 128 bytes**, and for the reminder that the VCS was never *only* a game machine. Sometimes it was a very small computer being asked to do a very large think.

> **Read the source.** This teardown is drawn from a [DiStella]({{< relref "/docs/getting-started/toolchain" >}}) disassembly of the *Video Chess* cartridge (Larry Wagner & Bob Whitehead's program, © 1979 Atari). The chess-engine internals above are read from the code and are necessarily a sketch — the move generator and evaluator repay much closer study than a teardown can give them.
