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

# Contributing to Phobos' Industrial Pathways: Pathology

Thanks for helping improve the project. This repo is intended to support collaboration, compatibility patches, and addon/dependency mods while keeping the official release cohesive.

## Quick rules (the short version)
- **Small, focused PRs** are best (one issue/feature per PR).
- **Don't re-upload unchanged releases**; forks must be clearly labeled "unofficial".
- **Code contributions** should be compatible with Build 42 and avoid hard-crashes.
- **No breaking changes** to public IDs unless there is a strong reason and a migration plan.

## What to contribute
Good contributions include:
- Bug fixes and crash fixes
- Performance improvements
- Build 42 API resilience (nil-guards, safe probing)
- Translation updates
- Compatibility patches with other mods (runtime-detected, optional)
- New specimen types or processing recipes (ideally behind sandbox options)

Please avoid:
- Large, opinionated rebalances without sandbox toggles
- Removing or renaming items/recipes/specimens that other mods may depend on
- Bundling third-party assets without clear licensing

## Project layout (Build 42)
This mod uses a Build 42 foldered layout. Keep changes in the correct directories and mirror existing conventions.

Typical locations:
- `common/media/lua/shared/` — Shared Lua modules (loaded on client + server)
- `common/media/lua/client/` — Client-only Lua (context menus, timed actions, UI)
- `common/media/lua/server/` — Server-only Lua (commands, migrations)
- `common/media/scripts/` — Item, recipe, and entity definitions
- `common/media/textures/` — Icons (PNG, transparent background)
- `common/media/sandbox-options.txt` — Sandbox option definitions
- `42/media/lua/shared/Translate/EN/` — Translation files (JSON)

## Compatibility & stability expectations
- Prefer **runtime detection** over hard dependencies where feasible.
- Use defensive coding patterns (pcall / nil checks) when touching game globals or mod hooks.
- Avoid assuming specific mods are installed unless the feature is explicitly "requires X".

Use PhobosLib helpers for:
- Sandbox var access (`PhobosLib.getSandboxVar()`)
- Mod-active detection (`PhobosLib.isModActive()`)
- Safe API probing (`PhobosLib.pcallMethod()`)
- Debug logging (`PhobosLib.debug()`)

## Versioning & public IDs
These identifiers are considered part of the public surface:
- Item type names
- Recipe IDs
- Module/namespace names (e.g. `PIP_Autopsy`, `PIP_RVBridge`)
- Sandbox option keys
- Translation keys

If you must change any of these:
1) explain why, 2) list downstream impact, 3) include migration notes.

## How to submit a PR
1. Fork the repository
2. Create a feature branch:
   - `fix/...` for bug fixes
   - `feat/...` for features
   - `compat/...` for compatibility patches
3. Keep commits descriptive (what + why)
4. Open a PR with:
   - the problem statement
   - what changed
   - how you tested (even basic "loaded into B42, autopsy menu works, no errors")

## Testing checklist (minimum)
Before submitting:
- Game launches to main menu without errors
- Context menus appear correctly near autopsy tables and corpses
- Sandbox options toggle features on/off as expected
- No console.txt errors or warnings from PIP modules
- If Lua changed: verify with luacheck (`luacheck common/media/lua/`)

## Licensing reminder
- Code contributions are accepted under the repository's code license (MIT).
- Asset contributions are under CC BY-NC-SA 4.0.
- Do not contribute assets you don't have rights to share.
- Forks must remain clearly labeled unofficial (see PROJECT_IDENTITY.md).

Thank you — and may your specimens be ever well-preserved.
