---
title: "Buttons & Console Switches"
weight: 20
---

# Buttons & Console Switches

The [joystick directions]({{< relref "the-joystick" >}}) come from `SWCHA`, but the **fire buttons** and the **console switches** live elsewhere — and they introduce the one idea that separates "input that works" from "input that feels right": telling a *held* button from a *just-pressed* one.

## Fire buttons (INPT4 / INPT5)

A joystick's fire button is read not from the RIOT but from two **TIA** registers: `INPT4` for player 0, `INPT5` for player 1. The state is in **bit 7**, and like everything else it's [active-low]({{< relref "the-joystick" >}}) — pressed reads `0`. Because the flag is in bit 7, [`BIT`]({{< relref "/docs/6502-basics/registers" >}}) is the natural test:

```asm
    bit INPT4        ; P0 fire in bit 7 → N flag
    bpl FirePressed  ; N clear (bit 7 = 0) → button is down
```

By default these read the button's instantaneous state. The TIA can also **latch** them: setting bit 6 of `VBLANK` makes a press *stick* until you clear the latch (write `VBLANK` with bit 6 clear). That guarantees you won't miss a tap that happens and releases between two reads — handy when you only poll once a frame.

## Console switches (SWCHB)

The six switches on the console front are read from the RIOT port `SWCHB`:

| Bit | Switch | Type | Pressed / position |
|-----|--------|------|--------------------|
| 0 | **Reset** | momentary | `0` = pressed |
| 1 | **Select** | momentary | `0` = pressed |
| 3 | **Color / B&W** | toggle | `1` = color, `0` = B&W |
| 6 | **Left difficulty** (P0) | toggle | `0` = B (novice), `1` = A (pro) |
| 7 | **Right difficulty** (P1) | toggle | `0` = B, `1` = A |

Two kinds live here. **Reset** and **Select** are momentary push-buttons — you press them and they spring back — used to start/restart the game and to cycle through its variations. The **difficulty** and **Color/B&W** switches are slide toggles: you read their *position*, not a press. Games lean on them creatively — the difficulty switches often pick a game mode or handicap, and Color/B&W is sometimes repurposed as a pause.

## Held vs. just-pressed: edge detection

Polling tells you what's down *this instant*. But "Select cycles to the next game variation" must fire **once per press**, not sixty times a second while the switch is held. The fix is **edge detection**: remember last frame's reading, and act only when a bit changed from released to pressed.

```asm
    lda SWCHB
    eor Prev         ; bits that CHANGED since last frame
    and SWCHB        ; ...wait — keep only bits now 0 (newly pressed)
    ; (in practice: compare Prev vs current, act on the press transition)
    ...
    lda SWCHB
    sta Prev         ; remember for next frame
```

The principle matters more than any one snippet: a *held* state is a question you ask the port; a *press event* is something you detect by comparing two frames. Get this wrong and Select races through every variation in a fraction of a second.

## In Practice

- **Per-frame polling debounces for free.** Mechanical switches bounce for a few milliseconds; reading once per [60 Hz frame]({{< relref "/docs/prerequisites/how-the-tv-works" >}}) samples well after the bounce has settled, so you rarely need explicit debounce logic — the frame *is* the debounce.
- **Keep a "previous" byte for anything one-shot.** Fire-to-shoot, Reset-to-restart, Select-to-change-mode — each needs the edge, so each needs last frame's value stored in RAM.
- **Difficulty switches are free game-design knobs.** They cost no input slots and no buttons; many classic games use them for two difficulty levels, a one- vs. two-player toggle, or a hidden mode.
