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
-- PIP_TimedActionRemoteGetRemains.lua
-- Client-side ISBaseTimedAction for collecting autopsy remains
-- from a remote morgue table via the RV Bridge.
-- Relays ZVV's "GetRemains" server command on completion.
--
-- Depends on: PhobosLib, PIP_RVBridge, PIP_EquipmentCheck
---------------------------------------------------------------

require "TimedActions/ISBaseTimedAction"
require "PhobosLib"
require "PIP_Constants"
require "PIP_RVBridge"
require "PIP_EquipmentCheck"

PIP_TimedActionRemoteGetRemains = ISBaseTimedAction:derive("PIP_TimedActionRemoteGetRemains")


--- Constructor.
---@param character any          IsoPlayer
---@param remoteTableData table  From PIP_Autopsy.findRemoteTableViaRV()
---@return PIP_TimedActionRemoteGetRemains
function PIP_TimedActionRemoteGetRemains:new(character, remoteTableData)
    local o = ISBaseTimedAction.new(self, character)
    o.remoteTableData = remoteTableData
    o.maxTime = PIP_Constants.ACTION_TIME_GET_REMAINS
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end


function PIP_TimedActionRemoteGetRemains:isValid()
    if not self.character or self.character:isDead() then return false end
    if not PhobosLib.isAreaSafe(self.character) then return false end
    local inv = self.character:getInventory()
    local ok = PIP_EquipmentCheck.checkGetRemains(inv)
    return ok
end


function PIP_TimedActionRemoteGetRemains:waitToStart()
    return false
end


function PIP_TimedActionRemoteGetRemains:update()
    self.character:setMetabolicTarget(Metabolics.LightWork)
end


function PIP_TimedActionRemoteGetRemains:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
end


function PIP_TimedActionRemoteGetRemains:stop()
    ISBaseTimedAction.stop(self)
end


function PIP_TimedActionRemoteGetRemains:perform()
    ISBaseTimedAction.perform(self)
end


function PIP_TimedActionRemoteGetRemains:complete()
    local rd = self.remoteTableData
    if not rd then return end

    local inv = self.character:getInventory()
    local hasSack, hasTwoPlastics = PIP_EquipmentCheck.hasSackOrPlastics(inv)

    sendClientCommand(
        self.character,
        "ZVirusVaccine42BETA",
        "GetRemains",
        {
            hasSack        = hasSack,
            hasTwoPlastics = hasTwoPlastics,
            topX           = rd.remoteTopX,
            topY           = rd.remoteTopY,
            topZ           = rd.remoteTopZ,
        }
    )

    -- Optimistic cache update: Remains → Dirty
    PIP_RVBridge.optimisticCacheUpdate(self.character, rd, PIP_Constants.TABLE_DIRTY)

    PhobosLib.debug("PIP", "RemoteGetRemains", "Relayed GetRemains to ZVV"
        .. " sack=" .. tostring(hasSack) .. " plastics=" .. tostring(hasTwoPlastics))
end
