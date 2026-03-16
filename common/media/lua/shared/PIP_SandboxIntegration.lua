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
-- PIP_SandboxIntegration.lua
-- Sandbox variable getters for Phobos' Industrial Pathways: Pathology.
-- Part of PIP — depends on PhobosLib.
---------------------------------------------------------------

PIP_Sandbox = PIP_Sandbox or {}

--- Check if debug logging is enabled for PIP.
-- @return boolean  true if enabled (default false)
function PIP_Sandbox.isDebugLoggingEnabled()
    return PhobosLib.getSandboxVar("PIP", "EnableDebugLogging", false) == true
end
