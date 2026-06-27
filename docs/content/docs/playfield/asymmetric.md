---
title: "The Asymmetric Playfield"
weight: 42
---

# The Asymmetric Playfield

[Symmetry]({{< relref "symmetry" >}}) is the playfield's default because its 20 bits describe only the left half and the TIA mirrors or copies them onto the right. To show two *different* things on the two halves — a genuinely **asymmetric playfield** — you have to break that deal. The escape hatch is timing.

## The TIA reads the registers as it goes

The crucial fact: the TIA does **not** snapshot `PF0`/`PF1`/`PF2` at the start of the line. It **reads them continuously as the beam sweeps across**, consulting each register at the exact moment the beam reaches the pixels it controls. So if you **rewrite the registers partway across the line** — after the beam has drawn the left half, but before it reaches the right half — the right half is built from the *new* values. The two halves now differ.

## Getting the clock cycle right

The catch is in the timing, and the window is narrow and unforgiving:

- A visible line is **76 CPU cycles**; the 160 visible color clocks consume about 53 of them, and the left half is gone in the first ~27.
- Your stores must land **after** the beam has passed each register's left-half region and **before** it reaches that register's right-half region.
- Miss the window — a store one cycle too late — and the change lands in the wrong column, smearing the seam where the halves meet.

So an asymmetric kernel is a cycle-counted dance: draw the left half, then race to rewrite the registers in the gap before the right half is drawn. Because the right half is drawn in reverse under reflection, even the *order* in which you rewrite the three registers depends on `CTRLPF`.

## When each register is safe to write

The number that matters is not *when a register is shown* but *when you may write it* — and that is several cycles earlier, for two reasons. First, the write itself takes time: a typical "fetch a graphic and store it" is a load (`LDA table,X`, 4 cycles) plus a store (`STA PF1`, 3 cycles). Second, the playfield registers are **buffered** — a write takes roughly two extra TIA clocks (about ⅔ of a machine cycle, and as much as a full cycle on some clone consoles) to actually take effect. So you must *start* the store a few cycles before the beam arrives.

Here is the shape of a single scanline. Cycles are counted from the start of horizontal blank, and the ~22 cycles of HBLANK come before `PF0` is drawn:

{{< graphviz >}}
digraph pftiming {
  bgcolor="transparent";
  node [shape=plaintext];
  t [label=<
<table border="0" cellborder="1" cellspacing="0" cellpadding="5">
<tr><td colspan="76" bgcolor="#3a3a3a"><font color="#ffffff"><b>One scanline = 76 machine cycles (not to scale)</b></font></td></tr>
<tr>
<td colspan="22" bgcolor="#cccccc">HBLANK<br/><font point-size="10">0&#8211;22</font></td>
<td colspan="6" bgcolor="#f6c6cc">PF0<br/><font point-size="10">22&#8211;28</font></td>
<td colspan="10" bgcolor="#cfe0f5">PF1<br/><font point-size="10">28&#8211;38</font></td>
<td colspan="11" bgcolor="#d2efd2">PF2<br/><font point-size="10">38&#8211;49</font></td>
<td colspan="5" bgcolor="#f6c6cc">PF0<br/><font point-size="10">49&#8211;54</font></td>
<td colspan="11" bgcolor="#cfe0f5">PF1<br/><font point-size="10">54&#8211;65</font></td>
<td colspan="11" bgcolor="#d2efd2">PF2<br/><font point-size="10">65&#8211;76</font></td>
</tr>
<tr>
<td colspan="22" bgcolor="#bbbbbb"><font point-size="10">beam off (retrace)</font></td>
<td colspan="27" bgcolor="#ececec"><font point-size="10"><b>LEFT half</b> drawn (cyc 22&#8211;49)</font></td>
<td colspan="27" bgcolor="#ececec"><font point-size="10"><b>RIGHT half</b> drawn (cyc 49&#8211;76)</font></td>
</tr>
</table>
>];
}
{{< /graphviz >}}

Because each register is read once for the left half and again for the right, an asymmetric kernel writes **all three registers twice — six writes — on every scanline**, even when a line's graphic is identical on both sides (the one address feeds both halves). The deadlines, in machine cycles since HBLANK began:

| Register | Drawn — left | Write by / safe to rewrite | Drawn — right | Write by / safe to rewrite |
|----------|--------------|----------------------------|---------------|----------------------------|
| `PF0` | 22–28 | **18** / 25 | 49–54 | **45** / 51 |
| `PF1` | 28–38 | **24** / 35 | 54–65 | **50** / 62 |
| `PF2` | 38–49 | **34** / 46 | 65–76 | **61** / 73 |

Read it as a relay: get `PF0`'s left value in before cycle 18, then `PF1`'s before 24, then `PF2`'s before 34 — and the instant each register's left half has finished drawing, you're free to overwrite it with the right-half value (`PF0` from cycle 25, `PF1` from 35, `PF2` from 46), which then has to land before that register's right window opens. Six writes, each in its own narrow slot, every line — miss one and the seam tears.

*(These figures come from the playfield timing diagram Andrew Davie published on the AtariAge forums — the reference kernel authors keep close at hand.)*

{{< vcsanim scene="asymmetric-pf" caption="The CPU runs ahead of the beam: it writes PF0/PF1/PF2 in HBLANK for the left half, then rewrites all three in the gap before the seam, so the two halves differ. Watch the cycle count stay well under 76." >}}

## Mixing symmetric and asymmetric bands

You don't have to choose one mode for the whole screen. Both the playfield registers and `CTRLPF` are just memory, rewritten line by line, so a single frame can freely **combine symmetric and asymmetric regions** down its height:

- A symmetric scoreboard or border at the top, drawn with one register write per line.
- An asymmetric play area in the middle, with the registers rewritten mid-line every scanline.
- A symmetric floor below, back to one write per line.

You spend the expensive mid-line technique only on the bands that actually need to differ left-to-right, and let the cheap symmetric path carry the rest — a typical VCS trade of cycles for exactly the visual you need, and nowhere else.

## Tips & Caveats

- **Six writes a line is the budget killer.** Two writes each to `PF0`/`PF1`/`PF2`, every scanline, on top of fetching the graphics — that eats a large slice of each line's [76-cycle budget]({{< relref "/docs/tia-racing-the-beam" >}}), leaving little for sprites or logic. That's the reason to confine asymmetry to the bands that need it.
- **Leave margin for clone consoles.** The extra buffering clock on some non-original TIAs can push a write that's "just in time" on a real VCS one cycle too late on a clone. Aim a cycle or two inside the deadline rather than right at it.
- **It's how asymmetric mazes are made.** A room in *Adventure* with a different wall on each side is exactly this: `PF` registers rewritten mid-line, every line, so left and right differ.

> The mental model: the playfield isn't a 40-pixel row you set once; it's 20 bits the beam reads twice. Symmetry is the default only because you usually leave those bits alone between the two halves. Change them in the gap, on exactly the right cycle, and the halves part ways.
