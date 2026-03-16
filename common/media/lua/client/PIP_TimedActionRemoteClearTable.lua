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
-- PIP_TimedActionRemoteClearTable.lua
-- Client-side ISBaseTimedAction for clearing (cleaning) a
-- remote morgue table via the RV Bridge.
-- Relays ZVV's "ClearTable" server command on completion.
-- Consumes bleach client-side to avoid double-drain.
--
-- Depends on: PhobosLib, PIP_RVBridge, PIP_EquipmentCheck
---------------------------------------------------------------

require "TimedActions/ISBaseTimedAction"
require "PhobosLib"
require "PIP_RVBridge"
require "PIP_EquipmentCheck"

PIP_TimedActionRemoteClearTable = ISBaseTimedAction:derive("PIP_TimedActionRemoteClearTable")


--- Constructor.
---@param character any          IsoPlayer
---@param remoteTableData table  From PIP_Autopsy.findRemoteTableViaRV()
---@return PIP_TimedActionRemoteClearTable
function PIP_TimedActionRemoteClearTable:new(character, remoteTableData)
    local o = ISBaseTimedAction.new(self, character)
    o.remoteTableData = remoteTableData
    o.maxTime = 150  -- matches ZVV's LabActionMorgueTableClear
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end


function PIP_TimedActionRemoteClearTable:isValid()
    if not self.character or self.character:isDead() then return false end
    local inv = self.character:getInventory()
    local ok = PIP_EquipmentCheck.checkClearTable(inv)
    return ok
end


function PIP_TimedActionRemoteClearTable:waitToStart()
    return false
end


function PIP_TimedActionRemoteClearTable:update()
    self.character:setMetabolicTarget(Metabolics.LightWork)
end


function PIP_TimedActionRemoteClearTable:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
end


function PIP_TimedActionRemoteClearTable:stop()
    ISBaseTimedAction.stop(self)
end


function PIP_TimedActionRemoteClearTable:perform()
    ISBaseTimedAction.perform(self)
end


function PIP_TimedActionRemoteClearTable:complete()
    local rd = self.remoteTableData
    if not rd then return end

    -- Consume bleach client-side (0.2L) — server handler won't double-drain
    -- if we don't pass bleachType in args
    local inv = self.character:getInventory()
    local bleachItem = PhobosLib.findFluidContainerWithMin(inv, {"Bleach", "CleaningLiquid"}, 0.2)
    if bleachItem then
        local fc = PhobosLib.tryGetFluidContainer(bleachItem)
        if fc then
            PhobosLib.tryDrainFluid(fc, 0.2)
        end
    end

    sendClientCommand(
        self.character,
        "ZVirusVaccine42BETA",
        "ClearTable",
        {
            topX = rd.remoteTopX,
            topY = rd.remoteTopY,
            topZ = rd.remoteTopZ,
        }
    )

    -- Optimistic cache update: Dirty → Empty
    if rd.rvData and rd.rvData.vehicleId then
        PIP_RVBridge.cacheTableLocation(self.character, rd.rvData.vehicleId, {
            topX   = rd.remoteTopX,
            topY   = rd.remoteTopY,
            topZ   = rd.remoteTopZ,
            status = "Empty",
        })
    end

    PhobosLib.debug("PIP", "RemoteClearTable", "Relayed ClearTable to ZVV")
end
