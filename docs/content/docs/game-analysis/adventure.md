---
title: "Adventure (1980)"
weight: 30
---

# Adventure (1980)

*Adventure* — **Warren Robinett**, Atari — put an entire **explorable world** on the console: roughly thirty connected rooms, items you carry one at a time, three dragons that hunt you, a thieving bat, and locked castles opened with keys. It was the first action-adventure game on a home console, packing an astonishingly rich world into a 4 KB cartridge. It's also famous for its hidden **"Created by Warren Robinett" room** — widely regarded as the first *famous* Easter egg in a video game, and the one that popularized the tradition of hiding secrets for players to find.

It's the perfect foil to [Pitfall!]({{< relref "pitfall" >}}). Pitfall's 255 rooms are *computed* from a single byte; Adventure's thirty are *stored* as a hand-authored map — and on top of that map Robinett built a general **object system** that makes Adventure read less like a single program and more like a tiny world simulation.

## The shape of the program

The frame loop is familiar, but notice what it's steering: not a fixed scene, but a *world model* — a current room, a set of objects, and actors that move on their own.

{{< graphviz >}}
digraph adventure {
  rankdir=TB;
  bgcolor="transparent";
  node [shape=box, style="filled,rounded", fontsize=10, color="#808080", penwidth=1.1];
  edge [color="#808080", penwidth=1.2];

  start  [label="StartGame — init,\nload object layout for this game", fillcolor="#e2e2e2"];
  input  [label="CheckGameStart / CheckInput —\nread joystick & game state", fillcolor="#cfe0f5"];
  ball   [label="BallMovement — move the player;\nwalk off an edge -> next room", fillcolor="#cfe0f5"];
  actors [label="Move the actors — carried object,\nbat, castle gates, three dragons", fillcolor="#cfe0f5"];
  setup  [label="SetupRoomPrint + CacheObjects —\nfetch this room's walls + the\n<= 2 objects standing in it", fillcolor="#f6e0c6"];
  kernel [label="PrintDisplay (kernel) + VSYNC —\nwalls + player + up to two objects", fillcolor="#d2efd2"];

  start -> input -> ball -> actors -> setup -> kernel;
  kernel -> input [label="  next frame", constraint=false, fontsize=9, fontcolor="#808080"];
}
{{< /graphviz >}}

## A world you can draw on paper

Adventure's rooms are **data**. A `RoomDataTable` holds one small record per room, found by `RoomNumToAddress` (room number → a fixed-size offset). Each record is everything that room *is*: the [playfield]({{< relref "/docs/playfield" >}}) walls that draw its maze, its color, and which room lies in each direction. About thirty of these, hand-authored, wire together into a connected map you could literally print out and trace with a finger.

Movement between them is almost anticlimactic: `BallMovement` walks the player to a screen edge, and the game swaps the current-room number (`$8A`) for that edge's neighbor. Next frame, `SetupRoomPrint` fetches the new room's record and the kernel draws a different place.

This is the whole contrast with Pitfall, and it's a fundamental one. Two answers to "build a big world on a tiny machine":

- **Compute it** ([Pitfall]({{< relref "pitfall" >}})) — an [algorithm]({{< relref "/docs/prerequisites/numbers" >}}) generates rooms for almost no ROM, but you can't hand-design any single one.
- **Store it** (Adventure) — a [data table]({{< relref "/docs/kernel-techniques/front-loading-and-tables" >}}) costs more ROM but gives you authorial control over every wall and every connection.

Adventure spends the bytes to be *designed*.

## Objects as data: the first "object-oriented" game

Here's the part programmers still cite. The sword, the chalice, the keys, the bridge, the magnet, the three dragons, the bat, the castle gates — Adventure treats *all* of them as **objects** handled the same way. Parallel tables (`Store1`–`Store9`) hold each object's graphic, state pointers, color, and size; a separate array gives each object's *placement* — its room, X, and Y. And the routines that act on them are **generic**: `CacheObjects` finds which objects are standing in the current room, `SetupObjectPrint` readies one for the screen, `GetObjectState` walks its little state machine. There's no special code for "the sword" — there's code for "an object," run over a list.

Robinett built Adventure as a set of interacting objects governed by general rules — a structure later programmers would call *object-oriented*, invented here out of necessity on a 4 KB cart, years before the term reached games.

The hardware draws the famous line: two [players]({{< relref "/docs/sprites/drawing-a-player" >}}) means only **two objects visible per room** at once (the player avatar is the separate [ball]({{< relref "/docs/sprites/missiles-and-ball" >}})). When a room holds more — you, a dragon, *and* a dropped key — Adventure [flickers]({{< relref "/docs/hardware-quirks/more-quirks" >}}) them, the shimmer that's woven into the game's look.

## Dragons, a bat, and emergent chaos

The world's actors each get their own mover: `MoveRedDragon`, `MoveYellowDragon`, `MoveGreenDragon` run three small state machines that wander, chase, bite, and die; `MoveBat` sends the bat flitting about to steal and swap whatever objects it fancies (it will happily fly a dragon to your doorstep). Add the carry-one-thing mechanic (`$9D`) and the key-locked castle gates (`Portals`), and none of these systems *know* about each other — yet they collide into stories. That emergent, anything-can-happen quality is exactly what made Adventure feel alive, and it falls out of the uniform object model almost for free. (Game variation 3 even reshuffles every object's starting room, so no two playthroughs match.)

## The famous Easter egg

Hidden in the world is an **invisible one-pixel object** — the famous "gray dot." Find it (it sits unseen in a particular room), carry it to the right spot, and a wall that's always been solid lets you slip into a secret room displaying **"Created by Warren Robinett."** Atari didn't put programmers' names on boxes, so Robinett hid his in the game itself — and once players found it, it became the most celebrated secret in early gaming, the room that popularized the whole tradition of hiding "Easter eggs." The fitting part, for this teardown: the egg is *just another object* in the same table, with its own room and its own rules. The object model that built the world also smuggled in its signature. (Compare the signature-effects spirit of [Hardware Quirks]({{< relref "/docs/hardware-quirks" >}}).)

## Why read it

Adventure and Pitfall are the two great answers to putting a world on a 2600, and reading them back to back is the lesson: **compute vs. store**, algorithm vs. data. But Adventure's deeper gift is the *object engine* — a general, data-driven system for "things that exist somewhere and do something," running on a machine with 128 bytes of RAM. It's the first 2600 game that is really a little *world*, not a single hard-coded screen, and it's where data-driven game design shows up in the medium.

> **Read the source.** This analysis follows the publicly circulated Adventure disassembly (Warren Robinett's game, © 1980 Atari), on GitHub at [johnidm/asm-atari-2600 → `adventure.asm`](https://github.com/johnidm/asm-atari-2600/blob/master/adventure.asm).
