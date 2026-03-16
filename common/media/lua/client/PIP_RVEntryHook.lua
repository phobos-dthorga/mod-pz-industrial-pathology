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
-- PIP_RVEntryHook.lua
-- Validates the autopsy table proxy registration every time
-- a player enters an RV Interior. If the registered table has
-- been removed, modified, or destroyed, the proxy is cleared
-- and the player is notified.
--
-- Detection: Polls player position on EveryTenMinutes. When
-- player transitions from outside to inside RV coordinates,
-- triggers validation. This avoids hooking RV Interior's
-- internal teleport functions directly (fragile).
--
-- Depends on: PhobosLib, PIP_RVAutopsyProxy, PIP_SandboxIntegration
---------------------------------------------------------------

require "PhobosLib"
require "PIP_RVAutopsyProxy"
require "PIP_SandboxIntegration"

--- Track per-player "was in RV" state for transition detection.
local playerWasInRV = {}


--- Called every game minute to detect RV entry transitions.
--- Using EveryOneMinute instead of OnPlayerUpdate to avoid per-frame cost.
local function onEveryOneMinute()
    if not PhobosLib.isExperimentalEnabled() then return end
    if not PIP_Sandbox.isRVAutopsyProxyEnabled() then return end
    if not PhobosLib.isModActive("ZVirusVaccine42BETA") then return end
    if not PhobosLib.isModActive("modPROJECTRVInterior") then return end

    local player = getSpecificPlayer(0)
    if not player then return end

    local playerKey = "p0"
    local isInRV = PIP_RV.isPlayerInRV(player)
    local wasInRV = playerWasInRV[playerKey] or false

    if isInRV and not wasInRV then
        -- Player just entered an RV — validate proxy
        PhobosLib.debug("PIP", "RVEntry", "Player entered RV Interior — validating proxy")

        -- Find which vehicle this player is in via RV Interior's ModData
        local rvModData = ModData.getOrCreate("modPROJECTRVInterior")
        if rvModData and rvModData.Players then
            local pKey = nil
            pcall(function() pKey = tostring(player:getOnlineID()) end)
            if not pKey then
                pcall(function() pKey = tostring(player:getUsername()) end)
            end

            if pKey and rvModData.Players[pKey] then
                local entry = rvModData.Players[pKey]
                if entry.VehicleId then
                    -- Find the vehicle object
                    local cell = getCell()
                    if cell then
                        local vehicles = nil
                        pcall(function() vehicles = cell:getVehicles() end)
                        if vehicles then
                            for i = 0, vehicles:size() - 1 do
                                local v = vehicles:get(i)
                                if v then
                                    local md = nil
                                    pcall(function() md = v:getModData() end)
                                    if md and md.projectRV_uniqueId == entry.VehicleId then
                                        local proxyData = PIP_RV.getProxyData(v)
                                        if proxyData then
                                            local valid = PIP_RV.validateProxy(v)
                                            if not valid then
                                                PhobosLib.say(player, getText("UI_PIP_ProxyInvalidated"))
                                            end
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    playerWasInRV[playerKey] = isInRV
end

Events.EveryOneMinute.Add(onEveryOneMinute)
