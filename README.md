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

# Phobos' Industrial Pathways: Pathology

Biological specimen acquisition and processing for Project Zomboid Build 42. Core pillars: cadaver processing, specimen extractions, biohazard handling, laboratory analysis, and pathogen research. Focuses on virology and pathology rather than general chemistry.

## Status

**v0.1.0** — Initial release (proof-of-concept). Proximity autopsy and RV Bridge features.

## Requirements

| Dependency | Type | Notes |
|------------|------|-------|
| [PhobosLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3668598865) | Required | Shared utility library for all Phobos mods |
| [Zombie Virus Vaccine](https://steamcommunity.com/sharedfiles/filedetails/?id=3399491432) (ZVV) | Soft | Provides the autopsy system and morgue table |
| [PROJECT RV Interior](https://steamcommunity.com/sharedfiles/filedetails/?id=3371837498) | Soft | RV interior rooms for the RV Bridge feature |

## Features

### Proximity Autopsy Table (v0.1.0)
Right-click near corpses within range of a ZVV Autopsy Table to perform table-quality autopsies without manually placing corpses on the table. The context menu lists all nearby corpses with ZVV's full tooltip (freshness, zombie status, organs, equipment check).

### RV Bridge Remote Autopsy (v0.1.0)
If no local autopsy table is found but an RV with a morgue table is parked nearby, offers "Autopsy (RV Lab Table)" to relay the autopsy through the RV interior's table. Morgue table locations are cached when the player visits the RV interior, so the feature works even after exiting the RV.

## Modules

| Module | Side | Description |
|--------|------|-------------|
| `PIP_AutopsyProxy` | Shared | Morgue table detection and ZVV compatibility checks |
| `PIP_RVBridge` | Shared | RV Interior room detection, table caching, interior scanner |
| `PIP_SandboxIntegration` | Shared | Sandbox option accessors |
| `PIP_AutopsyContextMenu` | Client | Context menu hook for proximity and RV Bridge autopsy |
| `PIP_TimedActionRemoteAutopsy` | Client | Timed action for RV Bridge autopsy relay |

## Sandbox Options

| Option | Default | Description |
|--------|---------|-------------|
| Enable Debug Logging | false | PhobosLib debug output for PIP modules |
| Enable Proximity Autopsy | true | Toggle the proximity table context menu |
| Autopsy Table Range | 3 (1–6) | Tile radius for detecting nearby autopsy tables |
| Enable RV Bridge | true | Toggle the RV Bridge remote autopsy feature |
| RV Vehicle Search Range | 5 (1–10) | Tile radius for detecting nearby RV vehicles |

## Project Layout

```
mod-pz-industrial-pathology/
├── mod.info                          # Root metadata (versionMin=42.15.0)
├── common/
│   ├── media/
│   │   ├── lua/
│   │   │   ├── shared/               # Shared Lua modules
│   │   │   └── client/               # Client-only Lua (menus, actions)
│   │   ├── scripts/                  # Item/recipe/entity definitions
│   │   ├── textures/                 # Icons (128x128 RGBA PNG)
│   │   └── sandbox-options.txt       # Sandbox option definitions
├── 42/
│   ├── mod.info                      # Version-specific metadata
│   └── media/lua/shared/Translate/   # JSON translations (42.15+)
├── docs/                             # Documentation and Steam Workshop assets
├── scripts/                          # Utility scripts (version bumping)
└── .github/                          # CI workflows and issue templates
```

## Development

### Pre-commit hook
```bash
git config core.hooksPath .githooks
```

### Bump version
```bash
./scripts/bump-version.sh 0.2.0
```

### Run luacheck
```bash
luacheck common/media/lua/
```

## Licensing

- **Code**: [MIT License](LICENSE)
- **Assets** (textures, icons): [CC BY-NC-SA 4.0](LICENSE-CC-BY-NC-SA.txt)

## Links

- [CHANGELOG](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Versioning Policy](VERSIONING.md)
- [PhobosLib on Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3668598865)
- [Phobos' Industrial Pathways: Pathology on Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3686101131)
