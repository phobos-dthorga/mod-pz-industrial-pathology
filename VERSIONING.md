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

# Versioning Policy (Phobos' Industrial Pathways: Pathology)

This mod uses Semantic Versioning as an API contract for downstream dependents.

## Scheme
Use Semantic Versioning: **MAJOR.MINOR.PATCH**

- **MAJOR**: breaking changes to public identifiers
  - removing/renaming items, recipes, fluids, or Lua modules
  - changing sandbox option keys or defaults in incompatible ways
  - changing documented behavior in a way that breaks dependents
- **MINOR**: backward-compatible additions
  - new specimens, recipes, items, or pathways
  - new sandbox options with safe defaults
  - new cross-mod integrations
  - performance improvements that keep behavior
- **PATCH**: backward-compatible bug fixes
  - crash fixes, nil guards, pcall wrappers
  - documentation corrections
  - translation fixes
  - internal refactors that do not change behavior

## What counts as "public surface"
These identifiers are considered stable contracts:
- Item type names (e.g. `PhobosIndustrialPathology.SomeItem`)
- Recipe IDs
- Fluid names
- Module/namespace names (e.g. `PIP_Autopsy`, `PIP_RVBridge`)
- Sandbox option keys (e.g. `PIP.EnableProximityAutopsy`)
- Translation keys (e.g. `UI_PIP_*`, `Sandbox_PIP_*`)

If a feature is experimental, mark it clearly in docs as **EXPERIMENTAL**.

## Deprecation (recommended)
If you need to replace an API:
1) keep the old API for at least one MINOR release
2) add a deprecation note in CHANGELOG.md
3) optionally print a one-time warning (avoid spam)
4) remove in the next MAJOR release

## Tagging releases
- Tag GitHub releases as `vX.Y.Z`
- Include a concise changelog section for each release

## Version locations
PIP tracks version in 2 locations (kept in sync by CI + pre-commit hook):
1. `mod.info` (root)
2. `42/mod.info`
