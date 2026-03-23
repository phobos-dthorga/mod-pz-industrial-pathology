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

# Troubleshooting

## PIP items or recipes are not appearing

1. **Check dependencies** -- Ensure **PhobosLib** is installed and enabled in the mod manager
2. **Check load order** -- PhobosLib must load **before** PIP. Verify this in the mod manager's load order panel
3. **Restart the game** -- Some mod changes require a full game restart (not just returning to the main menu)

## Lua errors in the console mentioning PIP

1. **Update PhobosLib** -- PIP requires a recent version of PhobosLib. Make sure both mods are up to date via the Steam Workshop
2. **Check for mod conflicts** -- Disable other mods one at a time to identify if another mod is causing the issue
3. **Report the error** -- Copy the full error message from the console and report it on [GitHub Issues](https://github.com/phobos-dthorga/mod-pz-industrial-pathology/issues) or the Steam Workshop page

## Cross-mod features are not working

- Cross-mod integrations (PCP, ZScienceSkill, EHR, Dynamic Trading) only activate when **both** mods are installed and enabled
- Verify the companion mod is listed as active in the mod manager
- Check the PZ console for any error messages related to mod detection

## Where are the PZ logs?

PZ log files are located at:

- **Windows**: `%USERPROFILE%\Zomboid\console.txt`
- **Linux**: `~/Zomboid/console.txt`

The in-game debug console can also be opened (if enabled in options) for real-time error viewing.

## Still stuck?

If none of the above resolves your issue, please open a report with:

1. Your PZ build version
2. The full list of active mods
3. The relevant section of `console.txt`
4. Steps to reproduce the problem
