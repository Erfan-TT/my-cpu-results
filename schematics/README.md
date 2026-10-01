# DLX architecture schematics

The structural sheets document the common pipeline organization used throughout
the optimization study. The edited SVG exports are used for Markdown and screen
viewing, with editable draw.io sources beside them. The decode sheet retains its
existing light export.

The drawings principally trace the baseline/common structure; version-specific
changes are described in [`../doc/revisions.md`](../doc/revisions.md) and should
not be inferred solely from these sheets.

| Sheet | Scope | Preferred source | Status |
|---|---|---|---|
| 01 | top-level DLX and memory interfaces | edited SVG | overview |
| 02 | five-stage datapath and inter-stage signals | edited A3 SVG + draw.io | complete |
| 03 | fetch, PC selection, BTB and IF/ID registers | edited A3 SVG + draw.io | complete |
| 04 | control pipeline, hazards and forwarding | edited A3 SVG + draw.io | complete |
| 05 | decode, register files, branch correction and exceptions | normal light SVG + draw.io | complete |
| 06 | execute, forwarding muxes, functional units and EX/MEM state | edited A3 SVG + draw.io | complete |
| 07 | memory access, exceptions, stores, loads and MEM/WB state | edited A3 SVG + draw.io | complete |
| 08 | write-back | represented in the datapath overview; dedicated sheet pending |

## 01 — system overview

![DLX system overview](01_dlx.svg)

## 02 — complete datapath

![Five-stage datapath](02_datapath.svg)

## 03 — fetch and branch prediction

![Fetch stage](03_fetch.svg)

## 04 — control path

![Control pipeline, hazards and forwarding](04_controlpath.svg)

## 05 — decode

![Decode, register files, branch correction and exceptions](05_decode.svg)

## 06 — execute

![Execute stage](06_execute.svg)

## 07 — memory access

![Memory stage](07_memory.svg)

The SVG files are the canonical screen versions used by the READMEs; editable
draw.io sources are retained for the detailed sheets.
