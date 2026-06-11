---
title: "The Collision Registers"
weight: 10
---

# The Collision Registers

The TIA tracks collisions between its six drawable objects — the two [players]({{< relref "/docs/sprites/drawing-a-player" >}}), two [missiles, the ball]({{< relref "/docs/sprites/missiles-and-ball" >}}), and the [playfield]({{< relref "/docs/playfield" >}}). Six objects make **15 possible pairs**, and the chip reports them across **eight read-only registers**.

## Detection is geometric, and it latches

As the beam paints each visible pixel, the TIA asks a simple question: are two objects *both lit here*? If so, it sets the corresponding collision bit. Two things follow from that:

- **It's purely geometric.** Collision depends only on whether both objects have a pixel turned on at the same spot — not their colors, not their [drawing priority]({{< relref "/docs/playfield/symmetry" >}}). Transparent parts of a sprite don't collide, so detection matches the *visible shape* — effectively pixel-perfect.
- **It latches.** The bit records that the overlap happened *at least once* during the frame and stays set. It does **not** tell you where, or how many times — just yes/no, and it remains yes until you clear it ([next page]({{< relref "reading-collisions" >}})).

## Which register reports which pair

Each register devotes its **top two bits** to two collision pairs: bit 7 and bit 6. The full map:

{{< graphviz >}}
digraph cx {
  bgcolor="transparent";
  node [shape=plaintext];
  t [label=<
<table border="0" cellborder="1" cellspacing="0" cellpadding="6">
<tr><td colspan="6" bgcolor="#3a3a3a"><font color="#ffffff"><b>Which register reports each pair</b></font></td></tr>
<tr>
<td bgcolor="#3a3a3a"><font color="#ffffff"> </font></td>
<td bgcolor="#3a3a3a"><font color="#ffffff"><b>P1</b></font></td>
<td bgcolor="#3a3a3a"><font color="#ffffff"><b>M0</b></font></td>
<td bgcolor="#3a3a3a"><font color="#ffffff"><b>M1</b></font></td>
<td bgcolor="#3a3a3a"><font color="#ffffff"><b>BL</b></font></td>
<td bgcolor="#3a3a3a"><font color="#ffffff"><b>PF</b></font></td>
</tr>
<tr>
<td bgcolor="#3a3a3a"><font color="#ffffff"><b>P0</b></font></td>
<td bgcolor="#cfe0f5"><font point-size="9">CXPPMM</font></td>
<td bgcolor="#f6e0c6"><font point-size="9">CXM0P</font></td>
<td bgcolor="#f6e0c6"><font point-size="9">CXM1P</font></td>
<td bgcolor="#d2efd2"><font point-size="9">CXP0FB</font></td>
<td bgcolor="#d2efd2"><font point-size="9">CXP0FB</font></td>
</tr>
<tr>
<td bgcolor="#3a3a3a"><font color="#ffffff"><b>P1</b></font></td>
<td bgcolor="#d8d8d8"> </td>
<td bgcolor="#f6e0c6"><font point-size="9">CXM0P</font></td>
<td bgcolor="#f6e0c6"><font point-size="9">CXM1P</font></td>
<td bgcolor="#d2efd2"><font point-size="9">CXP1FB</font></td>
<td bgcolor="#d2efd2"><font point-size="9">CXP1FB</font></td>
</tr>
<tr>
<td bgcolor="#3a3a3a"><font color="#ffffff"><b>M0</b></font></td>
<td bgcolor="#d8d8d8"> </td>
<td bgcolor="#d8d8d8"> </td>
<td bgcolor="#cfe0f5"><font point-size="9">CXPPMM</font></td>
<td bgcolor="#f6c6cc"><font point-size="9">CXM0FB</font></td>
<td bgcolor="#f6c6cc"><font point-size="9">CXM0FB</font></td>
</tr>
<tr>
<td bgcolor="#3a3a3a"><font color="#ffffff"><b>M1</b></font></td>
<td bgcolor="#d8d8d8"> </td>
<td bgcolor="#d8d8d8"> </td>
<td bgcolor="#d8d8d8"> </td>
<td bgcolor="#f6c6cc"><font point-size="9">CXM1FB</font></td>
<td bgcolor="#f6c6cc"><font point-size="9">CXM1FB</font></td>
</tr>
<tr>
<td bgcolor="#3a3a3a"><font color="#ffffff"><b>BL</b></font></td>
<td bgcolor="#d8d8d8"> </td>
<td bgcolor="#d8d8d8"> </td>
<td bgcolor="#d8d8d8"> </td>
<td bgcolor="#d8d8d8"> </td>
<td bgcolor="#e8e0c0"><font point-size="9">CXBLPF</font></td>
</tr>
</table>
>];
}
{{< /graphviz >}}

Spelled out, bit 7 / bit 6 of each register:

| Register | bit 7 | bit 6 |
|----------|-------|-------|
| `CXM0P`  | M0–P1 | M0–P0 |
| `CXM1P`  | M1–P0 | M1–P1 |
| `CXP0FB` | P0–PF | P0–BL |
| `CXP1FB` | P1–PF | P1–BL |
| `CXM0FB` | M0–PF | M0–BL |
| `CXM1FB` | M1–PF | M1–BL |
| `CXBLPF` | BL–PF | *(unused)* |
| `CXPPMM` | P0–P1 | M0–M1 |

You don't need to memorize this — you need to know it *exists*, and to look up the one or two pairs your game actually cares about. A `Pong` clone watches `CXBLPF` (ball hits wall) and the ball-versus-player bits; a shooter watches the missile-versus-player registers.

> The bits live in **7 and 6** for a reason: it makes them cheap to test. Reading a register with `BIT` drops bit 7 into the N flag and bit 6 into the V flag, so a single `BIT` plus a branch checks a collision without disturbing any register — the subject of the [next page]({{< relref "reading-collisions" >}}).
