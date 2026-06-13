---
title: "Further Reading"
weight: 120
---

# Further Reading

This book aims to be the *accessible* path into the VCS — the explanation you read first. For exhaustive, bit-level reference, and for the wider community that keeps this machine alive, these are the sources to reach for next.

## The Stella Programmer's Guide

The definitive low-level reference: Atari's own internal manual for the TIA and RIOT, written by **Steve Wright in 1979** ("Stella" was the VCS's development codename). It is the primary source behind the hardware behavior described throughout this book — and where to turn when you need the things a how-to deliberately leaves out: the complete register address-summary table, the exact `AUDC` waveform values, the numeric color/luminance chart, and PAL/SECAM conversion details.

- Read it at the **[Internet Archive](https://archive.org/details/StellaProgrammersGuide)** (a durable, freely accessible copy), or via the long-standing **[atarihq.com mirror](https://atarihq.com/danb/files/stella.pdf)**.

> The guide is a copyrighted Atari document; this book links to it rather than redistributing a copy. Where a page here says "see the Stella guide," it means the section of that manual covering the same register.

## Learning the machine

- **[Pikuma — "Atari 2600 Assembly"](https://pikuma.com/courses/learn-assembly-language-programming-atari-2600)** — Gustavo Pezzi's course; the structured, from-first-principles approach this repository follows.
- **[8bitworkshop](https://8bitworkshop.com/)** — Steve Hugg's in-browser IDE (edit 6502 assembly and watch the beam draw in real time) and the companion book *Making Games for the Atari 2600*. The fastest way to experiment without a local toolchain.
- **[AtariAge](https://atariage.com/)** — the homebrew community's hub: forums where current VCS developers gather, plus classic tutorial series (Andrew Davie's "Programming for Newbies" among them). The place to ask questions and see active projects.

## 6502 reference

- **[masswerk 6502 Instruction Set](https://www.masswerk.at/6502/6502_instruction_set.html)** — a clean opcode-and-cycle reference for the [6502 basics]({{< relref "/docs/6502-basics" >}}) the VCS's CPU shares.
