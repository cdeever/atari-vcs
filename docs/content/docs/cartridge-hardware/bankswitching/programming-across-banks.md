---
title: "Programming Across Banks"
weight: 10
---

# Programming Across Banks

[Bankswitching]({{< relref "bankswitching" >}}) hands you the hardware: several 4 KB banks and a few hotspot addresses that swap which one the [window]({{< relref "/docs/architecture/rom" >}}) shows. That much is simple. The hard part is *living* there — writing code that keeps working while the bytes underneath it change. Because the swap is a silent side effect of touching an address, the program counter doesn't move when a bank flips; only the contents under it do. Two facts follow, and both shape how you lay out a banked game.

## Living across banks

- **Code keeps running where it left off — in the new bank.** A swap doesn't jump anywhere; the program counter is unchanged, but the bytes under it just changed. So the universal trick is to put **identical switching stubs at the same address in every bank**: when the swap happens, execution continues at the same address, now in the new bank's copy of that stub, which then jumps where you intended. Calling a routine in another bank means *switch, then land on matching code*.
- **The reset vectors live in the window's top, in every bank.** At power-on the console reads `$FFFC` from whichever bank is active by default (commonly the last). Your startup code must establish a known bank immediately, and every bank needs valid vectors because any of them might be the one showing at reset.

## The hotspot trap

Because *any* access to a hotspot switches the bank, an innocent instruction can pull the rug out from under itself. An `lda` whose operand address, or even an instruction fetch, lands on `$1FF8` will swap the bank mid-stride — and now you're executing different bytes than you wrote. So the top of each bank, around the hotspots and vectors, is treated as **off-limits for ordinary code and data**; you keep tables and routines clear of it.

## In Practice

- **Keep cross-bank calls rare and ritualized.** Each one is a switch-and-land dance with a stub on both sides; design so that hot loops stay *within* a bank and bank changes happen at coarse boundaries (a new game state, a new screen).
- **Mind what you put near the top of a bank.** The hotspots and reset vectors share the highest addresses, so a lookup table or a routine that drifts up into them is a latent bank-swap waiting to fire. Leave that region clear.
- **Emulators and the `.lst` are your safety net.** A stray hotspot access is invisible in the source and instant in effect; Stella's debugger showing an unexpected bank change is often the fastest way to find one.
