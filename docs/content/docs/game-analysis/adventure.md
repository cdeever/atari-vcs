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

## The hard direction: knowing where you are sideways

Swapping rooms sounds symmetric — walk off any edge, load the neighbor — but the two axes are not equal on this machine, and in *Racing the Beam* Montfort and Bogost single out exactly this asymmetry as one of Robinett's real headaches. The VCS practically hands you the **vertical** coordinate: the kernel draws the screen top to bottom one line at a time, so a running tally of `WSYNC`s *is* your Y. Counting [scanlines]({{< relref "/docs/tia-racing-the-beam" >}}) is the natural unit of the whole machine, and "have I crossed the top or bottom of the room?" is just a comparison against a line number you already have.

**Horizontal** is the opposite, and it's a hardware fact, not a Robinett oversight: there is **no way to ask the TIA "where am I?" on the x-axis.** No register reports where the beam is across a scanline, and none holds a sprite's X. You [position a sprite by *timing*]({{< relref "/docs/sprites/horizontal-positioning" >}}) — strobing `RESBL`/`RESP0` to wherever the beam happens to be, then nudging with `HMOVE` — and the hardware never tells you afterward where it landed. The machine measures the vertical axis *for* you and leaves the horizontal axis entirely as the programmer's bookkeeping.

So the avatar's X lives in software. The man is just a three-byte record in RAM — `$8A` current room, `$8B` X, `$8C` Y — the *same* `{room, X, Y}` placement triple every object in the world uses (the disassembly even points at it with `LDX #$8A` / "*point to ball's coordinates*"). Robinett advances or retreats `$8B` himself each frame from the joystick, and every frame re-derives the timed strobe that draws the [ball]({{< relref "/docs/sprites/missiles-and-ball" >}}) at that column — there is no shortcut where the hardware "remembers" the player's horizontal place between frames. And the left/right room crossing that looks so casual in the diagram is really `$8B` reaching a hand-chosen edge value: with no horizontal counter to lean on, *every* sideways boundary in the world is a number Robinett had to maintain and test himself, where the vertical `$8C` comparisons largely ride along on the beam he was already counting.

This is the quiet cost behind "a world larger than the screen." Building rooms that connect *up and down* leans on the grain of the machine; building rooms that connect *left and right* meant simulating, in 128 bytes of RAM, the one measurement the TIA refuses to give back.

## Objects as data: the first "object-oriented" game

Here's the part programmers still cite. The sword, the chalice, the keys, the bridge, the magnet, the three dragons, the bat, the castle gates — Adventure treats *all* of them as **objects** handled the same way. Parallel tables (`Store1`–`Store9`) hold each object's graphic, state pointers, color, and size; a separate array gives each object's *placement* — its room, X, and Y. And the routines that act on them are **generic**: `CacheObjects` finds which objects are standing in the current room, `SetupObjectPrint` readies one for the screen, `GetObjectState` walks its little state machine. There's no special code for "the sword" — there's code for "an object," run over a list.

Robinett built Adventure as a set of interacting objects governed by general rules — a structure later programmers would call *object-oriented*, invented here out of necessity on a 4 KB cart, years before the term reached games.

Where does a game programmer in 1979 get that data-structure instinct, on a machine with no compiler and no operating system? Robinett has traced it to a specific classroom: as a Berkeley grad student around 1975 he took a course from **Ken Thompson** — the co-creator of Unix, then on sabbatical from Bell Labs — whose students were made to learn **C**. Not a line of C runs on the 2600; the cartridge is hand-written 6502 assembly to the last byte. What crossed over was the *way of thinking* — pointers, records, arrays of structures, treating memory as typed objects reached through their addresses. Adventure's `Store1`–`Store9` tables and per-object state pointers are that C mental model transliterated into assembly, on a machine with 128 bytes of RAM. The first action-adventure game is, in a real sense, a systems-programming idea smuggled onto a game console. (Robinett tells this story himself in his [*The Making of Adventure* talk](https://www.youtube.com/watch?v=YDsBu8ULWPU&t=1817s), Classic Gaming Expo 2002.)

The hardware draws the famous line: two [players]({{< relref "/docs/sprites/drawing-a-player" >}}) means only **two objects visible per room** at once (the player avatar is the separate [ball]({{< relref "/docs/sprites/missiles-and-ball" >}})). When a room holds more — you, a dragon, *and* a dropped key — Adventure [flickers]({{< relref "/docs/hardware-quirks/more-quirks" >}}) them, the shimmer that's woven into the game's look.

## Anatomy of an object: C structs in 6502

Here is the payoff, and it's worth going slow, because this *is* the trick. Every object in Adventure is a **nine-byte record**, and the objects sit in one big **array** of those records. What makes it read like C is that Robinett gave each *field* of the record its own label — the `Store1`–`Store9` from above are not nine separate tables, they're the **nine byte-offsets of one struct**, sitting one apart. Straight from the disassembly's own header:

```
;Offset 0 : low byte  ┐ pointer -> object info (room, x, y)
;Offset 1 : high byte ┘
;Offset 2 : low byte  ┐ pointer -> object's current state
;Offset 3 : high byte ┘
;Offset 4 : low byte  ┐ pointer -> list of states (the state machine)
;Offset 5 : high byte ┘
;Offset 6 : colour
;Offset 7 : colour in B&W
;Offset 8 : size (NUSIZ)
```

So an object isn't "number 0, 1, 2." It's addressed by the **byte offset of its record**, and stepping to the next object means adding the record size:

```
       TYA
       CLC
       ADC    #$09        ; next object = this record + 9 bytes
       CMP    #$A2        ; past the last? ($A2 = 18 objects × 9)
       BCC    GetObjectsInfo
```

With that offset in an index register (`CacheObjects` keeps it in `Y` while it hunts; `SetupObjectPrint` loads it into `X` to draw), `LDA Store1,X` reads field 0 of *this* object and `LDA Store3,X` reads field 2 — the index register holds the object's base address and the `StoreN` labels are the field offsets. That is exactly the code a C compiler emits for `obj->field`, written out by hand.

**Three of those fields are pointers.** Fields 0–1, 2–3, and 4–5 are 16-bit addresses stored low-byte-then-high, each pointing at *another* record. To follow one, the code copies it into a zero-page slot (`$93/$94`) and dereferences it with the 6502's indirect-indexed mode:

```
       LDA    Store1,X     ; obj->info   (low byte of the pointer)
       STA    $93
       LDA    Store2,X     ;             (high byte)
       STA    $94
       LDY    #$01
       LDA    ($93),Y      ; info->x   → the object's X coordinate
       STA    $86
       LDY    #$02
       LDA    ($93),Y      ; info->y   → the object's Y coordinate
```

`LDA ($93),Y` **is** `p->field`: `$93/$94` holds the pointer, `Y` is the offset into the record it points at, and the CPU fetches that byte. Offset 0 of that same record is the room — comparing it against the current room (`$8A`) is the whole test inside `CacheObjects`: *is this object standing in the room I'm about to draw?* And note the shape of the record it points to — `{room, X, Y}` — is identical to the player's own `$8A`/`$8B`/`$8C`. The avatar really is just object number zero.

The last pointer is the elegant one: it runs the object's **state machine**. Field 2–3 points at a single byte — the current state; field 4–5 points at a **list of states**, three bytes per entry: `[state value, graphic-pointer-low, graphic-pointer-high]`. `GetObjectState` walks that list until it finds the current state…

```
GetObjectState_1:
       CMP    ($93),Y      ; is this entry the current state?
       BEQ    GetObjectState_2
       BCC    GetObjectState_2
       INY
       INY
       INY                  ; no → skip to the next 3-byte entry
       JMP    GetObjectState_1
```

…and the two bytes immediately after the match are a **pointer to the bitmap** for that state — which the kernel then dereferences a *third* time, once per scanline, to draw the shape. Follow the whole chain: an array of structs → a pointer to the object's info → a pointer to its state list → a pointer to the right bitmap. Pointers to pointers to graphics, three levels deep, on a machine with 128 bytes of RAM.

That is the C course showing through. `LDA ($93),Y` — indirect, indexed — is the instruction Thompson's language leans on for every `p->field` and `array[i]`, and Adventure's object engine is built almost entirely out of it.

## Dragons, a bat, and emergent chaos

The world's actors each get their own mover: `MoveRedDragon`, `MoveYellowDragon`, `MoveGreenDragon` run three small state machines that wander, chase, bite, and die; `MoveBat` sends the bat flitting about to steal and swap whatever objects it fancies (it will happily fly a dragon to your doorstep). Add the carry-one-thing mechanic (`$9D`) and the key-locked castle gates (`Portals`), and none of these systems *know* about each other — yet they collide into stories. That emergent, anything-can-happen quality is exactly what made Adventure feel alive, and it falls out of the uniform object model almost for free. (Game variation 3 even reshuffles every object's starting room, so no two playthroughs match.)

The same model even absorbed a *bug*. Robinett found a player could drop an item somewhere unreachable — buried in a wall, stranded past a gate — leaving the game unwinnable. Rather than rewrite the drop logic to forbid it, he did the cheaper and more Adventure-like thing: he added **another object**. The **magnet** pulls loose items back toward itself, so a stranded sword or key can always be fished free. What fans read as a clever gameplay element was, underneath, a debugging tool in costume — and the reason it cost so little to bolt on is exactly the uniform object engine. When everything is "an object with a room, an X, and a Y," the fix for a stuck object is just *one more object*. (Robinett recounts this in [the same 2002 talk](https://www.youtube.com/watch?v=YDsBu8ULWPU).)

## The famous Easter egg

Hidden in the world is an **invisible one-pixel object** — the famous "gray dot." Find it (it sits unseen in a particular room), carry it to the right spot, and a wall that's always been solid lets you slip into a secret room displaying **"Created by Warren Robinett."** Atari didn't put programmers' names on boxes, so Robinett hid his in the game itself — and once players found it, it became the most celebrated secret in early gaming, the room that popularized the whole tradition of hiding "Easter eggs." The fitting part, for this teardown: the egg is *just another object* in the same table, with its own room and its own rules. The object model that built the world also smuggled in its signature. (Compare the signature-effects spirit of [Hardware Quirks]({{< relref "/docs/hardware-quirks" >}}).)

## Why read it

Adventure and Pitfall are the two great answers to putting a world on a 2600, and reading them back to back is the lesson: **compute vs. store**, algorithm vs. data. But Adventure's deeper gift is the *object engine* — a general, data-driven system for "things that exist somewhere and do something," running on a machine with 128 bytes of RAM. It's the first 2600 game that is really a little *world*, not a single hard-coded screen, and it's where data-driven game design shows up in the medium.

> **Read the source.** This analysis follows the publicly circulated Adventure disassembly (Warren Robinett's game, © 1980 Atari), on GitHub at [johnidm/asm-atari-2600 → `adventure.asm`](https://github.com/johnidm/asm-atari-2600/blob/master/adventure.asm).
