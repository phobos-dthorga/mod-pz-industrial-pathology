<!--
  ________________________________________________________________________
 / Copyright (c) 2026 Phobos A. D'thorga                                \
 |                                                                        |
 |           /\_/\                                                         |
 |         =/ o o \=    Phobos' PZ Modding                                |
 |          (  V  )     All rights reserved.                              |
 |     /\  / \   / \                                                      |
 |    /  \/   '-'   \   This source code is part of the Phobos            |
 |   /  /  \  ^  /\  \  mod suite for Project Zomboid (Build 42).         |
 |  (__/    \_/ \/  \__)                                                  |
 |     |   | |  | |     Unauthorised copying, modification, or            |
 |     |___|_|  |_|     distribution of this file is prohibited.          |
 |                                                                        |
 \________________________________________________________________________/
-->

# Getting Started with PhobosIndustrialPathology

## What is PIP?

PhobosIndustrialPathology (PIP) is a Project Zomboid mod focused on **biological specimen acquisition and processing**. It adds virology and pathology mechanics, allowing players to collect, analyse, and research biological specimens in the post-apocalyptic world.

## Status

PIP is in **early development** (v0.1.0 scaffold). Core systems are being designed and implemented. Expect significant changes as the mod grows.

## Requirements

- **Project Zomboid** Build 42 (versionMin 42.14.0)
- **PhobosLib** (required) -- shared utility library for all Phobos mods

## Installation

1. Subscribe to **PhobosLib** on the Steam Workshop
2. Subscribe to **PhobosIndustrialPathology** on the Steam Workshop
3. Enable both mods in the Project Zomboid mod manager
4. Ensure PhobosLib loads before PIP in the load order

## Getting Started

Once the mod is installed and active:

1. **Find specimens** -- Biological specimens can be discovered through exploration and scavenging
2. **Process specimens** -- Use lab equipment to prepare and analyse your findings
3. **Research pathology** -- Build knowledge of virology and pathology through hands-on work

Detailed gameplay guides will be added as features are implemented.

## Cross-Mod Compatibility

PIP is designed to work alongside other Phobos mods and community mods. All cross-mod features are **optional** -- they activate only when both mods are detected at runtime.

| Mod | Integration |
|-----|-------------|
| **PhobosChemistryPathways** (PCP) | Chemistry reagents and lab equipment for specimen processing |
| **ZScienceSkill** | Specimen research contributes to science skill progression |
| **Expanded Helicopter Events** (EHR) | Potential specimen sources from helicopter events |
| **Dynamic Trading** | Specimens and processed materials available in the trading economy |

## Further Reading

- [FAQ](faq.md) -- Common questions about PIP
- [Troubleshooting](troubleshooting.md) -- Solutions to common issues
- [Architecture](../architecture/README.md) -- Technical documentation
