---
title: "Drawing a Player"
weight: 10
---

# Drawing a Player

The two **players** (P0 and P1) are the TIA's real sprites: 8-pixel-wide bitmaps you can move anywhere and color independently. A player is how you draw the tank, the spaceship, the character. Drawing one is, like everything on the VCS, a matter of feeding the right register at the right scanline.

## One byte, one row

A player's shape lives in a single register — `GRP0` for player 0, `GRP1` for player 1. Its **8 bits are 8 pixels**: a `1` lights a pixel in the player's color ([`COLUP0` / `COLUP1`]({{< relref "/docs/tia-racing-the-beam/color" >}})), a `0` is transparent. But a register holds only *one row*, so — exactly like the [playfield kernel]({{< relref "/docs/playfield/symmetry" >}}) — you rewrite `GRP0` on each scanline the sprite occupies, walking down a bitmap table:

```asm
SpriteGfx:
    .byte %00111100   ; one byte per row, top to bottom
    .byte %01111110
    .byte %11011011
    .byte %11111111
    ; ...
```

Unlike the playfield, a player's pixels are **one color clock wide** (not four), so sprites are far finer than playfield graphics — which is why scoreboards and detailed shapes often use players rather than the [chunky playfield]({{< relref "/docs/playfield" >}}).

## Vertical position is *when*, not *where*

There is no Y register for a player. A sprite appears on the scanlines where you actually write its graphics — so "vertical position" means **counting scanlines** in your kernel and only feeding `GRP0` real bytes while the beam is inside the sprite's rows; above and below, you write `0` (or simply don't enable it).

The usual kernel keeps a counter: each line, check whether the beam is within `[spriteY, spriteY + height)`; if so, load the right bitmap row (indexed by `beam − spriteY`) into `GRP0`; if not, store `0`. Moving the sprite up or down is just changing `spriteY` — no graphics move, the *window* in which you draw them does.

## Coloring each row

A player has only one color register (`COLUP0`), so a player is "one color" — *on any single scanline*. But the register is latched and can be rewritten between lines (see [Color: Hue & Luminance]({{< relref "/docs/tia-racing-the-beam/color" >}})), so the loop that already walks a bitmap row per line can walk a **parallel color table** with the same index and give every row its own color:

```asm
SpriteGfx:
    .byte %00111100   ; row 0 shape
    .byte %01111110
    ; ...
SpriteCol:
    .byte $1C         ; row 0 color  (hue $1, luminance $C)
    .byte $36
    ; ...
```

```asm
    ; inside the kernel, Y = beam − spriteY (the current sprite row)
    lda SpriteGfx,Y
    sta GRP0
    lda SpriteCol,Y
    sta COLUP0
```

That's how a sprite shows a head-to-foot gradient or a striped, multi-colored body despite the "one color per player" rule. It isn't free — the extra `lda`/`sta` spend cycles from the [76-cycle line budget]({{< relref "/docs/tia-racing-the-beam" >}}), which is exactly why color tables are usually [page-aligned and pre-indexed]({{< relref "/docs/kernel-techniques/front-loading-and-tables" >}}) so the lookup costs as little as possible.

## Reflection

`REFP0` / `REFP1` mirror a player left-to-right. Set it and the same bitmap faces the other way — so a character walking left and right needs only **one** set of graphics, reflected, rather than two. (Bit 3 of the register is the flag.)

## Vertical delay (a first mention)

`VDELP0` / `VDELP1` hold a player's graphics update back by one scanline. It exists for **two-line kernels** — kernels that spend two scanlines per loop to buy time — and for positioning a sprite on an odd vs. even line. The mechanics belong with [Kernel Techniques]({{< relref "/docs/kernel-techniques" >}}); for now, just know `VDEL` is the knob that makes a sprite update on the "other" line.

## Tips & Caveats

- **Off-screen means write zero.** A common bug is a sprite that smears down the whole screen — usually because `GRP0` is never cleared outside the sprite's rows. Every line that isn't drawing the sprite must write `0`.
- **Bitmap order follows your loop, not gravity.** The table above is written top row first, but many kernels count scanlines from the *bottom* up — so you'll often see sprite data stored bottom-row-first ("upside down"). Neither is more correct; the byte order just has to match the direction your kernel walks the table. Author it whichever way your counter runs.
- **Two players, and that's it.** There are only P0 and P1. Showing three or more independent shapes on one line needs the copy tricks in [Size & Copies]({{< relref "size-and-copies" >}}) or sprite [*multiplexing*]({{< relref "/docs/sprites/sprite-multiplexing" >}}) (reusing a player on different lines).
- **Players collide in hardware.** Whether two players (or a player and the playfield) overlap is tracked for you — see [Collisions]({{< relref "/docs/collisions" >}}).
