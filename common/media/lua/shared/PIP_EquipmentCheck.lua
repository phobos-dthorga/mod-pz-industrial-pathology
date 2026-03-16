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
-- PIP_EquipmentCheck.lua
-- Equipment detection and tooltip helpers for autopsy operations.
-- Uses PhobosLib generic inventory helpers with ZVV LabConst
-- fallback item lists.
--
-- Depends on: PhobosLib (findItemFromTypeList, countItemsFromTypeList,
--             findFluidContainerWithMin)
-- Soft dep:   ZVV LabConst (item type lists)
---------------------------------------------------------------

require "PhobosLib"

PIP_EquipmentCheck = PIP_EquipmentCheck or {}


---------------------------------------------------------------
-- Item type lists (use ZVV LabConst if available, else fallback)
---------------------------------------------------------------

--- Get the sack type list from LabConst or hardcoded fallback.
---@return table  Array of fullType strings
function PIP_EquipmentCheck.getSackTypes()
    if LabConst and LabConst.SACKS then
        local result = {}
        for _, name in ipairs(LabConst.SACKS) do
            table.insert(result, "Base." .. name)
        end
        return result
    end
    return { "Base.Garbagebag", "Base.Bag_TrashBag" }
end

--- Get the plastic bag type list from LabConst or hardcoded fallback.
---@return table  Array of fullType strings
function PIP_EquipmentCheck.getPlasticTypes()
    if LabConst and LabConst.PLASTICS then
        local result = {}
        for _, name in ipairs(LabConst.PLASTICS) do
            table.insert(result, "Base." .. name)
        end
        return result
    end
    return { "Base.Plasticbag", "Base.Plasticbag_Bags", "Base.Plasticbag_Clothing" }
end

--- Get the cleaning tool type list from LabConst or hardcoded fallback.
---@return table  Array of fullType strings
function PIP_EquipmentCheck.getCleaningToolTypes()
    if LabConst and LabConst.TOOLS_CLEAN then
        local result = {}
        for _, name in ipairs(LabConst.TOOLS_CLEAN) do
            table.insert(result, "Base." .. name)
        end
        return result
    end
    return { "Base.DishCloth", "Base.BathTowel" }
end


---------------------------------------------------------------
-- Inventory checks
---------------------------------------------------------------

--- Check if the player has a sack OR at least 2 plastic bags.
---@param inv any  ItemContainer
---@return boolean hasSack
---@return boolean hasTwoPlastics
---@return boolean anyOk  true if either condition met
function PIP_EquipmentCheck.hasSackOrPlastics(inv)
    if not inv then return false, false, false end
    local hasSack = PhobosLib.findItemFromTypeList(inv, PIP_EquipmentCheck.getSackTypes()) ~= nil
    local plasticCount = PhobosLib.countItemsFromTypeList(inv, PIP_EquipmentCheck.getPlasticTypes())
    local hasTwoPlastics = plasticCount >= 2
    return hasSack, hasTwoPlastics, (hasSack or hasTwoPlastics)
end

--- Check if the player has a non-broken scalpel.
---@param inv any  ItemContainer
---@return boolean
function PIP_EquipmentCheck.hasScalpel(inv)
    if not inv then return false end
    local item = PhobosLib.findItemByFullType(inv, "Base.Scalpel")
    if not item then return false end
    local cond = PhobosLib.getItemCondition(item)
    return cond and cond > 0
end

--- Check if the player has a non-broken saw.
---@param inv any  ItemContainer
---@return boolean
function PIP_EquipmentCheck.hasSaw(inv)
    if not inv then return false end
    local item = PhobosLib.findItemByFullType(inv, "Base.Saw")
    if not item then return false end
    local cond = PhobosLib.getItemCondition(item)
    return cond and cond > 0
end

--- Check if the player has bleach or cleaning liquid (≥0.2 litres).
---@param inv any  ItemContainer
---@return boolean
function PIP_EquipmentCheck.hasBleach(inv)
    if not inv then return false end
    return PhobosLib.findFluidContainerWithMin(inv, {"Bleach", "CleaningLiquid"}, 0.2) ~= nil
end

--- Check if the player has a cleaning rag (dish cloth or bath towel).
---@param inv any  ItemContainer
---@return boolean
function PIP_EquipmentCheck.hasRag(inv)
    if not inv then return false end
    return PhobosLib.findItemFromTypeList(inv, PIP_EquipmentCheck.getCleaningToolTypes()) ~= nil
end


---------------------------------------------------------------
-- Composite checks for each operation
---------------------------------------------------------------

--- Check requirements for GetRemains: sack OR 2 plastics.
---@param inv any  ItemContainer
---@return boolean ok
---@return boolean hasSack
---@return boolean hasTwoPlastics
function PIP_EquipmentCheck.checkGetRemains(inv)
    local hasSack, hasTwoPlastics, ok = PIP_EquipmentCheck.hasSackOrPlastics(inv)
    return ok, hasSack, hasTwoPlastics
end

--- Check requirements for CollectBodyPart: scalpel + saw + (sack OR 2 plastics).
---@param inv any  ItemContainer
---@return boolean ok  true if all requirements met
---@return boolean hasScalpel
---@return boolean hasSaw
---@return boolean hasSack
---@return boolean hasTwoPlastics
function PIP_EquipmentCheck.checkCollectPart(inv)
    local hasScalpel = PIP_EquipmentCheck.hasScalpel(inv)
    local hasSaw = PIP_EquipmentCheck.hasSaw(inv)
    local hasSack, hasTwoPlastics, containerOk = PIP_EquipmentCheck.hasSackOrPlastics(inv)
    return (hasScalpel and hasSaw and containerOk), hasScalpel, hasSaw, hasSack, hasTwoPlastics
end

--- Check requirements for ClearTable: bleach/cleaning liquid + rag/towel.
---@param inv any  ItemContainer
---@return boolean ok
---@return boolean hasBleach
---@return boolean hasRag
function PIP_EquipmentCheck.checkClearTable(inv)
    local hasBleach = PIP_EquipmentCheck.hasBleach(inv)
    local hasRag = PIP_EquipmentCheck.hasRag(inv)
    return (hasBleach and hasRag), hasBleach, hasRag
end


---------------------------------------------------------------
-- Tooltip builders
---------------------------------------------------------------

local function colorTag(ok)
    return ok and "<GREEN>" or "<RED>"
end

--- Build tooltip lines for container requirements (sack OR 2 plastics).
---@param tooltip any     ISToolTip
---@param hasSack boolean
---@param hasTwoPlastics boolean
function PIP_EquipmentCheck.appendContainerTooltip(tooltip, hasSack, hasTwoPlastics)
    if not tooltip then return end
    local desc = tooltip.description or ""
    desc = desc .. getText("UI_PIP_RequiresItem") .. " <LINE> "
    desc = desc .. colorTag(hasSack) .. " " .. getText("UI_PIP_Sack") .. " <RGB:1,1,1> <LINE> "
    desc = desc .. getText("UI_PIP_RequiresOr") .. " <LINE> "
    desc = desc .. colorTag(hasTwoPlastics) .. " " .. getText("UI_PIP_Plastics") .. " <RGB:1,1,1> "
    tooltip.description = desc
end

--- Build tooltip lines for body part collection requirements.
---@param tooltip any        ISToolTip
---@param hasScalpel boolean
---@param hasSaw boolean
---@param hasSack boolean
---@param hasTwoPlastics boolean
function PIP_EquipmentCheck.appendCollectPartTooltip(tooltip, hasScalpel, hasSaw, hasSack, hasTwoPlastics)
    if not tooltip then return end
    local desc = tooltip.description or ""
    desc = desc .. getText("UI_PIP_RequiresItem") .. " <LINE> "
    desc = desc .. colorTag(hasScalpel) .. " " .. getText("UI_PIP_Scalpel") .. " <RGB:1,1,1> <LINE> "
    desc = desc .. colorTag(hasSaw) .. " " .. getText("UI_PIP_Saw") .. " <RGB:1,1,1> <LINE> "
    desc = desc .. colorTag(hasSack) .. " " .. getText("UI_PIP_Sack") .. " <RGB:1,1,1> <LINE> "
    desc = desc .. getText("UI_PIP_RequiresOr") .. " <LINE> "
    desc = desc .. colorTag(hasTwoPlastics) .. " " .. getText("UI_PIP_Plastics") .. " <RGB:1,1,1> "
    tooltip.description = desc
end

--- Build tooltip lines for clear table requirements.
---@param tooltip any       ISToolTip
---@param hasBleach boolean
---@param hasRag boolean
function PIP_EquipmentCheck.appendClearTableTooltip(tooltip, hasBleach, hasRag)
    if not tooltip then return end
    local desc = tooltip.description or ""
    desc = desc .. getText("UI_PIP_RequiresItem") .. " <LINE> "
    desc = desc .. colorTag(hasBleach) .. " " .. getText("UI_PIP_BleachOrCleaner") .. " <RGB:1,1,1> <LINE> "
    desc = desc .. colorTag(hasRag) .. " " .. getText("UI_PIP_Rag") .. " <RGB:1,1,1> "
    tooltip.description = desc
end
