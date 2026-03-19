--  ________________________________________________________________________
-- / Copyright (c) 2026 Phobos A. D'thorga                                \
-- |                                                                        |
-- |           /\_/\                                                         |
-- |         =/ o o \=    Phobos' PZ Modding                                |
-- |          (  V  )     All rights reserved.                              |
-- |     /\  / \   / \                                                      |
-- |    /  \/   '-'   \   This source code is part of the Phobos            |
-- |   /  /  \  ^  /\  \  mod suite for Project Zomboid (Build 42).         |
-- |  (__/    \_/ \/  \__)                                                  |
-- |     |   | |  | |     Unauthorised copying, modification, or            |
-- |     |___|_|  |_|     distribution of this file is prohibited.          |
-- |                                                                        |
-- \________________________________________________________________________/
--

---------------------------------------------------------------
-- PIP_Constants.lua
-- Shared constants for PhobosIndustrialPathology.
--
-- Centralises table status keys, action durations, and other
-- magic values used across client and shared modules.
---------------------------------------------------------------

PIP_Constants = PIP_Constants or {}

---------------------------------------------------------------
-- Morgue table status keys (matches ZVV's LabRecipes_GetBedObjects)
---------------------------------------------------------------

PIP_Constants.TABLE_EMPTY    = "Empty"
PIP_Constants.TABLE_CORPSE   = "Corpse"
PIP_Constants.TABLE_REMAINS  = "Remains"
PIP_Constants.TABLE_DIRTY    = "Dirty"

---------------------------------------------------------------
-- Timed action durations (ticks, matching ZVV equivalents)
---------------------------------------------------------------

PIP_Constants.ACTION_TIME_CLEAR_TABLE  = 150
PIP_Constants.ACTION_TIME_GET_REMAINS  = 160
PIP_Constants.ACTION_TIME_COLLECT_PART = 220

---------------------------------------------------------------
-- Scanning and resource constants
---------------------------------------------------------------

PIP_Constants.RV_INTERIOR_SCAN_RADIUS = 8
PIP_Constants.BLEACH_DRAIN_AMOUNT     = 0.2
