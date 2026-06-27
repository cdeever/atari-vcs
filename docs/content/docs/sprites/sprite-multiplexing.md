---
title: "Sprite Multiplexing"
weight: 60
---

# Sprite Multiplexing

The TIA gives you **two [players]({{< relref "drawing-a-player" >}})**, and — unlike ROM or RAM — *no [cartridge hardware]({{< relref "/docs/cartridge-hardware" >}}) adds more.* The two-sprite limit is one you beat in **software**. Yet games routinely show a screen full of enemies, shots, and characters; they do it by **time-sharing** the two players — reusing each one to be several different things, either down the screen or across frames.

## Reuse down the screen

The key realization: a player only occupies the scanlines you actually draw it on. If two objects never share a scanline, **one player can be both of them** — enemy A in the top third of the screen, enemy B in the middle, enemy C at the bottom, all drawn by the *same* player 0 in a single kernel.

The kernel does it by **repositioning and reloading at each band boundary**: when the beam reaches the next object, restrobe the player's [horizontal position]({{< relref "/docs/sprites/horizontal-positioning" >}}) (`RESP0` + `HMOVE`) and point its graphics at the new object's bitmap. Down the screen, the one player object becomes a column of different sprites.

This is **vertical multiplexing**, and it's the workhorse behind most busy 2600 screens. The setup work is real: each frame you **sort the objects by vertical position** and assign them to the two player slots so that no two objects assigned to the *same* player overlap vertically. Then the kernel walks down the screen, swapping each player's identity at the right scanlines.

## When objects share a line: flicker

Vertical multiplexing fails the moment **more than two objects land on the same scanline** — there are only two players, and they can't be in two places on one line. The escape is the [flicker]({{< relref "/docs/hardware-quirks/more-quirks" >}}) technique: show some of the crowd this frame and the rest next frame, alternating fast enough that the eye blends them. Doing it *well* means rotating which objects get the two slots so the flicker is spread evenly and no single object vanishes for long.

So the full toolkit for "more than two objects" is three layers:

- **[`NUSIZ` copies]({{< relref "/docs/sprites/size-and-copies" >}})** — multiple *identical* objects on the same line, free, from one player.
- **Vertical multiplexing** — *different* objects on *different* lines, one player reused down the screen.
- **Flicker** — *too many* objects on the same line, spread across alternating frames.

Real games layer all three: copies for a row of identical aliens, multiplexing for the different rows, flicker when a moment gets too crowded.

## It's a kernel problem

None of this is free — it's some of the most demanding [kernel]({{< relref "/docs/kernel-techniques" >}}) work on the machine. Repositioning a player mid-screen costs the same cycle-counted [strobe-and-`HMOVE`]({{< relref "/docs/sprites/horizontal-positioning" >}}) as positioning it before the frame, except now it happens *inside* the visible kernel, between rows, under the [76-cycle gun]({{< relref "/docs/kernel-techniques/counting-cycles" >}}). The per-frame sorting runs in [VBLANK]({{< relref "/docs/tia-racing-the-beam/frame-structure" >}}); the reloading runs in the kernel. A good sprite multiplexer is where everything in this book comes together.

## In Practice

- **Sort in the blank, draw in the kernel.** Decide *which player is which object where* during VBLANK, building a tidy list the kernel can stream; never sort inside the visible region.
- **Flicker is a fallback, not a goal.** Reach for vertical multiplexing first — it's rock-steady. Flicker only when objects genuinely collide on a line, and then spread it as evenly as you can.
- **This is the summit.** Bankswitching and extra RAM expand what the hardware *has*; multiplexing expands what it can *show*, and it leans on cycle counting, positioning, and `VDEL` all at once. If you can write a solid multiplexed kernel, you've mastered the VCS.
