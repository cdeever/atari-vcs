---
title: "Advanced Techniques"
weight: 90
bookCollapseSection: true
BookIcon: advanced
---

# Advanced Techniques

By now you can draw a stable frame with sprites, sound, and input — and you've felt the machine's three hard ceilings press in: **4 KB of ROM**, **128 bytes of RAM**, and **two sprites**. This chapter is how ambitious games push past each one. Every escape costs something (cartridge hardware, address space, or cycles), but each lifts a limit that would otherwise cap what a game can be.

Three ceilings, three escapes:

- **[Bankswitching]({{< relref "bankswitching" >}})** — break the 4 KB ROM ceiling by paging larger ROM into the cart window via hardware "hotspots."
- **[Extra RAM]({{< relref "extra-ram" >}})** — break the 128-byte RAM ceiling with cartridge RAM and its two-port read/write trick.
- **[Sprite Multiplexing]({{< relref "sprite-multiplexing" >}})** — break the two-sprite ceiling by time-sharing the players down the screen and across frames.

> Bankswitching is invisible to the 6502 instruction set — it's triggered as a side effect of *accessing* specific cartridge addresses ("hotspots"). That means an innocent-looking `lda` of the wrong address can silently swap the code out from under you.
