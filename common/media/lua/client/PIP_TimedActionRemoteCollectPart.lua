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
-- PIP_TimedActionRemoteCollectPart.lua
-- Client-side ISBaseTimedAction for collecting a body part
-- from a remote morgue table via the RV Bridge.
-- Relays ZVV's "CollectBodyPart" server command on completion.
--
-- Depends on: PhobosLib, PIP_RVBridge, PIP_EquipmentCheck
---------------------------------------------------------------

require "TimedActions/ISBaseTimedAction"
require "PhobosLib"
require "PIP_RVBridge"
require "PIP_EquipmentCheck"

PIP_TimedActionRemoteCollectPart = ISBaseTimedAction:derive("PIP_TimedActionRemoteCollectPart")


--- Constructor.
---@param character any          IsoPlayer
---@param remoteTableData table  From PIP_Autopsy.findRemoteTableViaRV()
---@param itemType string        Body part type key (e.g. "RANDOM_BRAIN", "LabItems.LabHumanBoneLargeWP")
---@return PIP_TimedActionRemoteCollectPart
function PIP_TimedActionRemoteCollectPart:new(character, remoteTableData, itemType)
    local o = ISBaseTimedAction.new(self, character)
    o.remoteTableData = remoteTableData
    o.itemType = itemType
    o.maxTime = 220  -- matches ZVV's LabActionMorgueTableCollectPart
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end


function PIP_TimedActionRemoteCollectPart:isValid()
    if not self.character or self.character:isDead() then return false end
    if not self.itemType then return false end
    local inv = self.character:getInventory()
    local ok = PIP_EquipmentCheck.checkCollectPart(inv)
    return ok
end


function PIP_TimedActionRemoteCollectPart:waitToStart()
    return false
end


function PIP_TimedActionRemoteCollectPart:update()
    self.character:setMetabolicTarget(Metabolics.HeavyWork)
end


function PIP_TimedActionRemoteCollectPart:start()
    self.sound = self.character:getEmitter():playSound("Sawing")
    self:setActionAnim("SawSmallItemMetal")
end


function PIP_TimedActionRemoteCollectPart:stop()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound)
        self.sound = nil
    end
    ISBaseTimedAction.stop(self)
end


function PIP_TimedActionRemoteCollectPart:perform()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound)
        self.sound = nil
    end
    ISBaseTimedAction.perform(self)
end


function PIP_TimedActionRemoteCollectPart:complete()
    local rd = self.remoteTableData
    if not rd then return end

    local inv = self.character:getInventory()
    local hasSack, hasTwoPlastics = PIP_EquipmentCheck.hasSackOrPlastics(inv)

    sendClientCommand(
        self.character,
        "ZVirusVaccine42BETA",
        "CollectBodyPart",
        {
            hasSack        = hasSack,
            hasTwoPlastics = hasTwoPlastics,
            topX           = rd.remoteTopX,
            topY           = rd.remoteTopY,
            topZ           = rd.remoteTopZ,
            itemType       = self.itemType,
        }
    )

    -- Optimistic cache update: Remains → Dirty
    if rd.rvData and rd.rvData.vehicleId then
        PIP_RVBridge.cacheTableLocation(self.character, rd.rvData.vehicleId, {
            topX   = rd.remoteTopX,
            topY   = rd.remoteTopY,
            topZ   = rd.remoteTopZ,
            status = "Dirty",
        })
    end

    PhobosLib.debug("PIP", "RemoteCollectPart", "Relayed CollectBodyPart to ZVV"
        .. " itemType=" .. tostring(self.itemType)
        .. " sack=" .. tostring(hasSack) .. " plastics=" .. tostring(hasTwoPlastics))
end
