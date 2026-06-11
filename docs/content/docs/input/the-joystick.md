---
title: "The Joystick"
weight: 10
---

# The Joystick

The standard CX40 joystick is the simplest input on the system: five switches — four directions and a fire button — and nothing analog. The four *directions* of both joysticks are read from a single [RIOT]({{< relref "/docs/architecture/riot" >}}) port, `SWCHA`; the fire button comes in elsewhere (see [Buttons & Console Switches]({{< relref "buttons-and-switches" >}})).

## One byte, two joysticks

`SWCHA` packs both controllers into its eight bits — **player 0 in the high nibble, player 1 in the low nibble** — each nibble holding right/left/down/up:

{{< graphviz >}}
digraph swcha {
  bgcolor="transparent";
  node [shape=plaintext];
  t [label=<
<table border="0" cellborder="1" cellspacing="0" cellpadding="6">
<tr><td colspan="8" bgcolor="#3a3a3a"><font color="#ffffff"><b>SWCHA &#8212; joystick directions (0 = pressed)</b></font></td></tr>
<tr>
<td bgcolor="#cfe0f5">7<br/><font point-size="10">P0 right</font></td>
<td bgcolor="#cfe0f5">6<br/><font point-size="10">P0 left</font></td>
<td bgcolor="#cfe0f5">5<br/><font point-size="10">P0 down</font></td>
<td bgcolor="#cfe0f5">4<br/><font point-size="10">P0 up</font></td>
<td bgcolor="#f6e0c6">3<br/><font point-size="10">P1 right</font></td>
<td bgcolor="#f6e0c6">2<br/><font point-size="10">P1 left</font></td>
<td bgcolor="#f6e0c6">1<br/><font point-size="10">P1 down</font></td>
<td bgcolor="#f6e0c6">0<br/><font point-size="10">P1 up</font></td>
</tr>
<tr>
<td colspan="4" bgcolor="#2f5d8a"><font color="#ffffff"><b>Player 0 (high nibble)</b></font></td>
<td colspan="4" bgcolor="#9c6a2a"><font color="#ffffff"><b>Player 1 (low nibble)</b></font></td>
</tr>
</table>
>];
}
{{< /graphviz >}}

## Active-low: pressed reads as 0

The single most important thing about reading switches on the VCS: they are **active-low.** A direction that's *held* reads as `0`; a direction that's *released* reads as `1`. This inverts the intuition — you branch on the bit being **clear**, not set. To test whether player 0 is pushing up (bit 4):

```asm
    lda SWCHA
    and #%00010000   ; isolate bit 4 (P0 up)
    bne NotUp        ; non-zero → bit was 1 → up is NOT pressed
    ; ...fall through: up IS pressed, move the player up
NotUp:
```

The same shape reads any direction: load `SWCHA`, mask the one bit, and branch on zero (pressed) versus non-zero (released). Because the bits are independent, diagonals just work — up *and* right are simply two bits that both happen to be `0`.

## In Practice

- **Mask, don't compare.** There's no "is the value 16?" here; you isolate the bit you care about with `AND` (or [`BIT`]({{< relref "/docs/6502-basics/registers" >}})) and branch on zero. Comparing `SWCHA` to a constant breaks the moment a second switch is also pressed.
- **Read once, reuse.** `SWCHA` is live hardware ([a memory-mapped read]({{< relref "/docs/prerequisites/memory-mapped" >}})); load it into A or a variable once per frame and test that copy, rather than re-reading the port for every direction.
- **"Held" vs. "just pressed" are different questions.** The port tells you what's held *right now*. For a one-shot action — fire on the press, not every frame the button is down — you compare against last frame's reading and act only on the change. That edge-detection pattern is shared with the buttons, and it's covered next in [Buttons & Console Switches]({{< relref "buttons-and-switches" >}}).
