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
-- PIP_VehicleApplianceUI.lua
-- Client-side UI handlers for PIP vehicle appliances.
-- Registers ISLootWindowContainerControls handlers for
-- power toggle and fridge/freezer mode switch.
--
-- Depends on: PhobosLib
---------------------------------------------------------------

require "PhobosLib"
require "ISUI/LootWindow/ISLootWindowContainerControls"


---------------------------------------------------------------
-- Helper: get vehicle and part from container
---------------------------------------------------------------

local function getVehicleAndPart(container, targetPartId)
    if not container then return nil, nil end
    local parent = container:getParent()
    if not parent or not instanceof(parent, "BaseVehicle") then return nil, nil end
    local vehicle = parent
    local part = vehicle:getPartById(targetPartId)
    if not part then return nil, nil end
    if part:getItemContainer() ~= container then return nil, nil end
    return vehicle, part
end

local function sendCommand(player, vehicle, partId, command)
    local args = {
        vehicleId = vehicle:getId(),
        partId = partId,
    }
    sendClientCommand(player, "PIP_Vehicle", command, args)
end


---------------------------------------------------------------
-- Fridge Power Toggle
---------------------------------------------------------------

local PIP_FridgePower = ISLootWindowContainerControls:derive("PIP_FridgePower")
PIP_FridgePower.TargetID = "PIPLabFridge"

function PIP_FridgePower:shouldBeVisible(container)
    local vehicle, part = getVehicleAndPart(container, self.TargetID)
    return vehicle ~= nil and part ~= nil
end

function PIP_FridgePower:getControl(container)
    local _, part = getVehicleAndPart(container, self.TargetID)
    if not part then return nil end
    local md = part:getModData()
    local sysData = md and md.PIP_ApplianceData
    local isActive = sysData and sysData.active
    return {
        label = isActive and getText("UI_PIP_TurnOff") or getText("UI_PIP_TurnOn"),
        icon = nil,
    }
end

function PIP_FridgePower:perform(container, player)
    local vehicle, _ = getVehicleAndPart(container, self.TargetID)
    if not vehicle then return end
    sendCommand(player, vehicle, self.TargetID, "TogglePower")
end

ISLootWindowContainerControls.AddHandler(PIP_FridgePower)


---------------------------------------------------------------
-- Fridge Mode Switch (Fridge / Freezer)
---------------------------------------------------------------

local PIP_FridgeMode = ISLootWindowContainerControls:derive("PIP_FridgeMode")
PIP_FridgeMode.TargetID = "PIPLabFridge"

function PIP_FridgeMode:shouldBeVisible(container)
    local vehicle, part = getVehicleAndPart(container, self.TargetID)
    if not vehicle or not part then return false end
    local md = part:getModData()
    local sysData = md and md.PIP_ApplianceData
    return sysData and sysData.active
end

function PIP_FridgeMode:getControl(container)
    local _, part = getVehicleAndPart(container, self.TargetID)
    if not part then return nil end
    local md = part:getModData()
    local sysData = md and md.PIP_ApplianceData
    local isFreezer = sysData and sysData.isFreezer
    return {
        label = isFreezer and getText("UI_PIP_SetFridge") or getText("UI_PIP_SetFreezer"),
        icon = nil,
    }
end

function PIP_FridgeMode:perform(container, player)
    local vehicle, _ = getVehicleAndPart(container, self.TargetID)
    if not vehicle then return end
    sendCommand(player, vehicle, self.TargetID, "ToggleMode")
end

ISLootWindowContainerControls.AddHandler(PIP_FridgeMode)


---------------------------------------------------------------
-- Microwave Power Toggle
---------------------------------------------------------------

local PIP_MicrowavePower = ISLootWindowContainerControls:derive("PIP_MicrowavePower")
PIP_MicrowavePower.TargetID = "PIPLabMicrowave"

function PIP_MicrowavePower:shouldBeVisible(container)
    local vehicle, part = getVehicleAndPart(container, self.TargetID)
    return vehicle ~= nil and part ~= nil
end

function PIP_MicrowavePower:getControl(container)
    local _, part = getVehicleAndPart(container, self.TargetID)
    if not part then return nil end
    local md = part:getModData()
    local sysData = md and md.PIP_ApplianceData
    local isActive = sysData and sysData.active
    return {
        label = isActive and getText("UI_PIP_TurnOff") or getText("UI_PIP_TurnOn"),
        icon = nil,
    }
end

function PIP_MicrowavePower:perform(container, player)
    local vehicle, _ = getVehicleAndPart(container, self.TargetID)
    if not vehicle then return end
    sendCommand(player, vehicle, self.TargetID, "TogglePower")
end

ISLootWindowContainerControls.AddHandler(PIP_MicrowavePower)
