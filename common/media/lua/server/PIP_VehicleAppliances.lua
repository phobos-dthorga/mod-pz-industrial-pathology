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
-- PIP_VehicleAppliances.lua
-- Server-side vehicle appliance system for PIP.
-- Handles dynamic part injection at OnGameBoot, temperature
-- control updates, battery drain, and container access.
--
-- Depends on: PhobosLib
---------------------------------------------------------------

require "PhobosLib"
require "Vehicles/Vehicles"

PIP_Vehicle = PIP_Vehicle or {}
PIP_Vehicle.Create = PIP_Vehicle.Create or {}
PIP_Vehicle.Update = PIP_Vehicle.Update or {}
PIP_Vehicle.ContainerAccess = PIP_Vehicle.ContainerAccess or {}

---------------------------------------------------------------
-- Constants
---------------------------------------------------------------

local TEMPLATE_NAME = "Base.PIPAppliances"

local FRIDGE_TEMP = 0.2
local FREEZER_TEMP = -0.2
local ROOM_TEMP = 1.0
local MIN_BATTERY = 0.01

local DEFAULT_FRIDGE_DRAIN = 0.0003
local DEFAULT_MICROWAVE_DRAIN = 0.001
local DEFAULT_MICROWAVE_TIMER = 300  -- 5 minutes in seconds


---------------------------------------------------------------
-- Sandbox helpers
---------------------------------------------------------------

local function isFeatureEnabled()
    return PhobosLib.getSandboxVar("PIP", "EnableVehicleAppliances", true) == true
end

local function getFridgeDrainRate()
    return PhobosLib.getSandboxVar("PIP", "FridgeBatteryDrainRate", DEFAULT_FRIDGE_DRAIN)
end

local function getMicrowaveDrainRate()
    return PhobosLib.getSandboxVar("PIP", "MicrowaveBatteryDrainRate", DEFAULT_MICROWAVE_DRAIN)
end


---------------------------------------------------------------
-- OnGameBoot: Dynamic part injection via copyPartsFrom
---------------------------------------------------------------

local function injectApplianceParts()
    if not isFeatureEnabled() then
        PhobosLib.debug("PIP", "VehicleInject", "Vehicle appliances disabled in sandbox")
        return
    end

    local scriptManager = getScriptManager()
    if not scriptManager then
        PhobosLib.debug("PIP", "VehicleInject", "ERROR: getScriptManager() returned nil")
        return
    end

    local pipTemplate = scriptManager:getVehicle(TEMPLATE_NAME)
    print("[PIP] getVehicle('" .. TEMPLATE_NAME .. "') = " .. tostring(pipTemplate))
    if not pipTemplate then
        print("[PIP] ERROR: Template not found. Aborting injection.")
        return
    end

    local allScripts = scriptManager:getAllVehicleScripts()
    if not allScripts then
        print("[PIP] ERROR: getAllVehicleScripts() returned nil")
        return
    end

    print("[PIP] Total vehicle scripts found: " .. allScripts:size())

    local injected = 0
    local skipped = 0
    local failed = 0

    for i = 0, allScripts:size() - 1 do
        local script = allScripts:get(i)
        if script then
            local scriptName = script:getName() or "unknown"
            local shouldSkip = false

            -- Skip our own template
            if scriptName == "PIPAppliances" then
                shouldSkip = true
            end

            -- Skip trailers (no battery)
            if not shouldSkip and string.match(string.lower(scriptName), "trailer") then
                skipped = skipped + 1
                shouldSkip = true
            end

            if not shouldSkip then
                local partsBefore = script:getPartCount()

                -- Attempt injection via copyPartsFrom (spec = part ID only, no "part/" prefix)
                local ok, err = pcall(function()
                    script:copyPartsFrom(pipTemplate, "PIPLabFridge")
                    script:copyPartsFrom(pipTemplate, "PIPLabMicrowave")
                end)

                local partsAfter = script:getPartCount()

                if ok then
                    injected = injected + 1
                    -- Log first few vehicles for diagnostics
                    if injected <= 3 then
                        print("[PIP] Injected into '" .. scriptName .. "': parts " .. partsBefore .. " -> " .. partsAfter)
                    end
                else
                    failed = failed + 1
                    print("[PIP] WARN: copyPartsFrom failed for " .. scriptName .. ": " .. tostring(err))
                end
            end
        end
    end

    print("[PIP] Injection complete: " .. injected .. " patched, "
        .. skipped .. " trailers skipped, " .. failed .. " failed")
end

Events.OnGameBoot.Add(injectApplianceParts)


---------------------------------------------------------------
-- Part callbacks: Create
---------------------------------------------------------------

function PIP_Vehicle.Create.Appliance(vehicle, part)
    if not part then return end
    local md = part:getModData()
    if not md.PIP_ApplianceData then
        md.PIP_ApplianceData = {
            active = false,
            isFreezer = false,
            timer = 0,
            maxTemp = 100,
        }
    end
end


---------------------------------------------------------------
-- Part callbacks: Update — Fridge
---------------------------------------------------------------

function PIP_Vehicle.Update.Fridge(vehicle, part, elapsedMinutes)
    if not vehicle or not part then return end

    local md = part:getModData()
    if not md.PIP_ApplianceData then return end

    local sysData = md.PIP_ApplianceData
    local container = part:getItemContainer()
    if not container then return end

    if sysData.active then
        -- Battery check
        local charge = vehicle:getBatteryCharge()
        if charge < MIN_BATTERY then
            sysData.active = false
            container:setCustomTemperature(ROOM_TEMP)
            PhobosLib.debug("PIP", "Fridge", "Auto-shutoff: battery depleted")
            return
        end

        -- Drain battery
        local drainRate = getFridgeDrainRate()
        VehicleUtils.chargeBattery(vehicle, -drainRate * elapsedMinutes)

        -- Set temperature
        local targetTemp = sysData.isFreezer and FREEZER_TEMP or FRIDGE_TEMP
        local containerType = sysData.isFreezer and "freezer" or "fridge"

        container:setType(containerType)
        container:setCustomTemperature(targetTemp)
        container:addItemsToProcessItems()

        -- Manual heat workaround (mirrors Transcontinental pattern)
        local items = container:getItems()
        if items then
            for j = 0, items:size() - 1 do
                local item = items:get(j)
                if item and instanceof(item, "Food") then
                    local heat = item:getHeat()
                    item:setHeat(heat - (elapsedMinutes * 0.05))

                    if sysData.isFreezer then
                        local ft = item:getFreezingTime()
                        item:setFreezingTime(ft + (elapsedMinutes * 5.0))
                    else
                        local ft = item:getFreezingTime()
                        if ft > 0 then
                            item:setFreezingTime(ft - (elapsedMinutes * 2.0))
                        end
                    end
                end
            end
        end
    else
        container:setCustomTemperature(ROOM_TEMP)
    end
end


---------------------------------------------------------------
-- Part callbacks: Update — Microwave
---------------------------------------------------------------

function PIP_Vehicle.Update.Microwave(vehicle, part, elapsedMinutes)
    if not vehicle or not part then return end

    local md = part:getModData()
    if not md.PIP_ApplianceData then return end

    local sysData = md.PIP_ApplianceData
    local container = part:getItemContainer()
    if not container then return end

    if sysData.active then
        -- Battery check
        local charge = vehicle:getBatteryCharge()
        if charge < MIN_BATTERY then
            sysData.active = false
            sysData.timer = 0
            container:setCustomTemperature(ROOM_TEMP)
            PhobosLib.debug("PIP", "Microwave", "Auto-shutoff: battery depleted")
            return
        end

        -- Timer countdown
        sysData.timer = sysData.timer - (elapsedMinutes * 60)

        if sysData.timer <= 0 then
            -- Timer expired — shut down
            sysData.active = false
            sysData.timer = 0
            container:setCustomTemperature(ROOM_TEMP)
            PhobosLib.debug("PIP", "Microwave", "Timer expired, shutting down")
            return
        end

        -- Drain battery (higher rate than fridge)
        local drainRate = getMicrowaveDrainRate()
        VehicleUtils.chargeBattery(vehicle, -drainRate * elapsedMinutes)

        -- Set heating temperature
        local rawTemp = sysData.maxTemp or 100
        container:setCustomTemperature(ROOM_TEMP + (rawTemp / 100.0))
        container:addItemsToProcessItems()
    else
        container:setCustomTemperature(ROOM_TEMP)
    end
end


---------------------------------------------------------------
-- Container access
---------------------------------------------------------------

--- Fridge container access: same rules as TruckBed.
function PIP_Vehicle.ContainerAccess.Fridge(vehicle, part, chr)
    if chr:getVehicle() then return false end
    if not vehicle:isInArea(part:getArea(), chr) then return false end
    local trunkDoor = vehicle:getPartById("TrunkDoor")
        or vehicle:getPartById("DoorRear")
        or vehicle:getPartById("TrunkDoorOpened")
    if trunkDoor and trunkDoor:getDoor() then
        if not trunkDoor:getInventoryItem() then return true end
        if not trunkDoor:getDoor():isOpen() then return false end
    end
    return true
end

--- Microwave container access: identical to fridge.
function PIP_Vehicle.ContainerAccess.Microwave(vehicle, part, chr)
    return PIP_Vehicle.ContainerAccess.Fridge(vehicle, part, chr)
end


---------------------------------------------------------------
-- Server command handling (for client UI toggles)
---------------------------------------------------------------

local function onClientCommand(module, command, player, args)
    if module ~= "PIP_Vehicle" then return end

    local vehicle = args and args.vehicleId and getVehicleById(args.vehicleId)
    if not vehicle then return end

    local partId = args and args.partId
    if not partId then return end

    local part = vehicle:getPartById(partId)
    if not part then return end

    local md = part:getModData()
    if not md.PIP_ApplianceData then
        md.PIP_ApplianceData = { active = false, isFreezer = false, timer = 0, maxTemp = 100 }
    end

    local sysData = md.PIP_ApplianceData

    if command == "TogglePower" then
        sysData.active = not sysData.active
        if sysData.active and partId == "PIPLabMicrowave" then
            sysData.timer = DEFAULT_MICROWAVE_TIMER
            sysData.maxTemp = 100
        end
        PhobosLib.debug("PIP", "Command", partId .. " power=" .. tostring(sysData.active))

    elseif command == "ToggleMode" then
        sysData.isFreezer = not sysData.isFreezer
        PhobosLib.debug("PIP", "Command", "Fridge mode: freezer=" .. tostring(sysData.isFreezer))
    end

    vehicle:transmitPartModData(part)
end

Events.OnClientCommand.Add(onClientCommand)
