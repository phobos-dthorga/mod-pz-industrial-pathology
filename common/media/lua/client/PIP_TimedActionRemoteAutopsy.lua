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
-- PIP_TimedActionRemoteAutopsy.lua
-- Client-side ISBaseTimedAction for performing table-quality
-- autopsies via the RV Bridge. Player walks to the corpse
-- (not the remote table) and the action relays directly to
-- ZVV's server command channel on completion.
--
-- Depends on: PhobosLib, PIP_AutopsyProxy, PIP_RVBridge,
--             ZVV (LabSandboxOptions, LabActionMakeAutopsy,
--                  LabModEngine)
---------------------------------------------------------------

require "TimedActions/ISBaseTimedAction"
require "PhobosLib"
require "PIP_AutopsyProxy"
require "PIP_RVBridge"

PIP_TimedActionRemoteAutopsy = ISBaseTimedAction:derive("PIP_TimedActionRemoteAutopsy")


--- Calculate the action duration matching ZVV's table autopsy speed.
--- Mirrors ZVV's LabActionMakeAutopsy:getDuration() logic exactly.
---@param character any
---@return number  ticks
local function calculateDuration(character)
    local LabSandboxOptions = require "Util/LabSandboxOptions"

    -- Base autopsy speed from sandbox
    local duration = LabSandboxOptions.GetAutopsyBaseSpeed()

    -- Skill reduction: fewer ticks per Doctor perk level (ZVV skips level 0-1)
    if character then
        local doctorLevel = character:getPerkLevel(Perks.Doctor)
        if doctorLevel > 1 then
            local ticksPerLevel = LabSandboxOptions.GetTicksDecreasedByPerkLevel()
            duration = duration - ((doctorLevel - 1) * ticksPerLevel)
        end
    end

    -- Table speed bonus (GetTableSpeedBonusPercent already returns a percentage)
    local bonusPercent = LabSandboxOptions.GetTableSpeedBonusPercent()
    duration = math.floor(duration * (1.0 - bonusPercent / 100))

    -- RLP trait modifier (if Research Lab Intern Profession is installed)
    if _G.RLPTraitEffects and character then
        local rok, modified = pcall(function()
            return _G.RLPTraitEffects.ModifyAutopsyDuration(character, duration)
        end)
        if rok and modified then duration = modified end
    end

    return math.max(duration, 100)  -- minimum 100 ticks
end


--- Constructor.
---@param character any          IsoPlayer
---@param corpse any             IsoDeadBody
---@param corpseSquare any       IsoGridSquare where the corpse is
---@param remoteTableData table  From PIP_Autopsy.findRemoteTableViaRV()
---@return PIP_TimedActionRemoteAutopsy
function PIP_TimedActionRemoteAutopsy:new(character, corpse, corpseSquare, remoteTableData)
    local o = ISBaseTimedAction.new(self, character)
    o.corpse = corpse
    o.corpseSquare = corpseSquare
    o.remoteTableData = remoteTableData
    o.maxTime = calculateDuration(character)
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end


function PIP_TimedActionRemoteAutopsy:isValid()
    if not self.character or self.character:isDead() then return false end
    if not self.corpse then return false end
    -- Verify corpse still exists on its square
    local sq = self.corpseSquare
    if sq then
        local bodies = sq:getDeadBodys()
        if not bodies or bodies:size() == 0 then return false end
    end
    return true
end


function PIP_TimedActionRemoteAutopsy:waitToStart()
    self.character:faceThisObject(self.corpse)
    return self.character:shouldBeTurning()
end


function PIP_TimedActionRemoteAutopsy:update()
    self.character:faceThisObject(self.corpse)
    self.character:setMetabolicTarget(Metabolics.HeavyWork)
end


function PIP_TimedActionRemoteAutopsy:start()
    -- Play autopsy sound (same as ZVV's LabActionMakeAutopsy)
    self.sound = self.character:getEmitter():playSound("Mixing_C")
    self:setActionAnim("Loot")
    self.character:reportEvent("EventLootBody")
end


function PIP_TimedActionRemoteAutopsy:stop()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound)
        self.sound = nil
    end
    ISBaseTimedAction.stop(self)
end


function PIP_TimedActionRemoteAutopsy:perform()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound)
        self.sound = nil
    end
    ISBaseTimedAction.perform(self)
end


function PIP_TimedActionRemoteAutopsy:complete()
    local corpse = self.corpse
    local rd = self.remoteTableData
    if not corpse or not rd then return end

    -- Resolve corpse ID (OnlineID for MP, fallback to getID for SP)
    local corpseId = nil
    if corpse.getOnlineID then
        local ok, id = pcall(function() return corpse:getOnlineID() end)
        if ok and id then corpseId = id end
    end
    if not corpseId and corpse.getID then
        corpseId = corpse:getID()
    end

    -- Resolve corpse coordinates
    local corpseX, corpseY, corpseZ
    if corpse:getSquare() then
        corpseX = corpse:getSquare():getX()
        corpseY = corpse:getSquare():getY()
        corpseZ = corpse:getSquare():getZ()
    elseif self.corpseSquare then
        corpseX = self.corpseSquare:getX()
        corpseY = self.corpseSquare:getY()
        corpseZ = self.corpseSquare:getZ()
    end

    -- Relay directly to ZVV's server command channel.
    -- isOnTable=true gives table-quality specimens and XP.
    -- topX/Y/Z = remote table coords (for table sprite swap).
    -- corpseX/Y/Z = actual corpse location (for MarkCorpseAsAutopsied).
    sendClientCommand(
        self.character,
        "ZVirusVaccine42BETA",
        "MakeAutopsy",
        {
            isOnTable = true,
            corpseId  = corpseId,
            topX      = rd.remoteTopX,
            topY      = rd.remoteTopY,
            topZ      = rd.remoteTopZ,
            corpseX   = corpseX,
            corpseY   = corpseY,
            corpseZ   = corpseZ,
        }
    )

    -- Optimistic cache update: Empty → Remains
    if rd.rvData and rd.rvData.vehicleId then
        PIP_RVBridge.cacheTableLocation(self.character, rd.rvData.vehicleId, {
            topX   = rd.remoteTopX,
            topY   = rd.remoteTopY,
            topZ   = rd.remoteTopZ,
            status = "Remains",
        })
    end

    -- Update ZVV's client-side autopsy cache (prevents re-selecting this corpse)
    if not isServer() and corpseId and corpseX and corpseY and corpseZ then
        if LabModEngine and LabModEngine.autopsiedCorpsesCache then
            local corpseKey = string.format("%d_%d_%d_%d", corpseX, corpseY, corpseZ, corpseId)
            LabModEngine.autopsiedCorpsesCache[corpseKey] = true
        end
    end

    PhobosLib.debug("PIP", "RemoteAutopsy", "Relayed to ZVV: isOnTable=true"
        .. " table=" .. tostring(rd.remoteTopX) .. "," .. tostring(rd.remoteTopY)
        .. " corpse=" .. tostring(corpseX) .. "," .. tostring(corpseY))
end
