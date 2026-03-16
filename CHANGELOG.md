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

# Changelog

All notable changes to Phobos' Industrial Pathways: Pathology will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [0.1.0] — 2026-03-17

### Added
- **Proximity Autopsy Table**: Right-click near corpses within range of a ZVV Autopsy Table to perform table-quality autopsies without manual corpse placement
- **RV Bridge Remote Autopsy**: Use a morgue table inside an RV interior from outside the vehicle, relaying through ZVV's server command channel
- **Morgue Table Caching**: Automatically detects and caches morgue table locations when entering the RV interior; persists in player save data
- **Table Status Indicator**: Colour-coded tooltip showing real-time table status (Ready / Occupied / Needs Cleaning)
- 5 sandbox options: debug logging, proximity autopsy toggle, table range, RV bridge toggle, RV vehicle search range
- Full CI pipeline (9 checks: syntax, luacheck, version consistency, sandbox translations, icon coverage, OnCreate modules, recipe/item translations, prefix guard, UTF-8 encoding)
- Pre-commit hook for version consistency and luacheck validation
