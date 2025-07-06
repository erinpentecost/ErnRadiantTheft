--[[
ErnRadiantTheft for OpenMW.
Copyright (C) 2025 Erin Pentecost

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
]] local settings = require("scripts.ErnRadiantTheft.settings")
local common = require("scripts.ErnRadiantTheft.common")
local cells = require("scripts.ErnRadiantTheft.cells")
local macguffins = require("scripts.ErnRadiantTheft.macguffins")
local interfaces = require('openmw.interfaces')
local world = require('openmw.world')
local types = require("openmw.types")
local core = require("openmw.core")
local aux_util = require('openmw_aux.util')
local storage = require('openmw.storage')

if require("openmw.core").API_REVISION < 62 then
    error("OpenMW 0.49 or newer is required!")
end

-- Init settings first to init storage which is used everywhere.
settings.initSettings()

local persistedState = nil

local function saveState()
    return persistedState
end

local function loadState(saved)
    if saved == nil then
        persistedState = {
            currentJobID = 0
        }
    else
        persistedState = saved
    end
end

local function getDoors(cell)
    local doors = {}
    for _, door in ipairs(common.shuffle(cell:getAll(types.Door))) do
        local destCell = types.Door.destCell(door)
        if types.Door.isTeleport(door) and (destCell ~= nil) and (destCell.isExterior == false) and
            (destCell:hasTag("QuasiExterior") == false) then
            table.insert(doors, door)
        end
    end
    return doors
end

local function randomMacguffinForNPC(npcRecordId)
    local previousJob = persistedState["previousJob"]
    local record = types.NPC.record(npcRecordId)
    if record == nil then
        error("no record for npc: " .. npcRecordId)
    end

    local macguffin = nil
    for _, potenialMacguffin in ipairs(common.shuffle(macguffins.macguffins)) do
        if (previousJob ~= nil) and (previousJob.category == potenialMacguffin.category) then
            settings.debugPrint("Skipping repeated macguffin category " .. previousJob.category)
        elseif macguffins.filter(potenialMacguffin, record) then
            return potenialMacguffin
        end
    end
    settings.debugPrint("no suitable macguffins for npc: " .. npcRecordId)
    return nil
end

local function randomJob()
    -- make sure we don't get duplicates back-to-back.
    local previousJob = persistedState["previousJob"]

    -- determine parent cell.
    local parentCell = nil
    for _, cell in ipairs(common.shuffle(cells.allowedCells)) do
        if (previousJob ~= nil) and (previousJob.extCellID == cell.id) then
            settings.debugPrint("Skipping repeated cell " .. cell.id)
        else
            parentCell = cell
            break
        end
    end
    if parentCell == nil then
        error("failed to find a parent cell")
        return
    end

    -- now we have to load the cell so we can get all the doors.
    -- pick a suitable interior cell.
    -- there should be owned containers in it.
    local targetContainer = nil
    local macguffin = nil
    local mark = nil
    for _, door in ipairs(getDoors(parentCell)) do
        for _, container in ipairs(common.shuffle(door.destCell:getAll(types.Container))) do
            if (container.owner ~= nil) and (container.owner.recordId ~= nil) then
                local containerRecord = container.record(container)
                if (containerRecord.isOrganic == false) and (containerRecord.isRespawning == false) then
                    -- a stable container with an owner.
                    macguffin = randomMacguffinForNPC(container.owner.recordId)
                    if macguffin ~= nil then
                        targetContainer = container
                        mark = container.owner.recordId
                        break
                    end
                end
            end
        end
    end
    if macguffin == nil then
        error("failed to find a macguffin")
        return
    end

    -- make the new job (with a unique id)
    persistedState.currentJobID = persistedState.currentJobID + 1
    local job = {
        jobID = persistedState.currentJobID,
        ownerRecordId = mark,
        extCellID = parentCell.id,
        targetContainerId = targetContainer.id,
        category = macguffin.category,
        type = macguffin.type,
        recordId = macguffin.recordId
    }

    -- place the macguffin
    local macguffinInstance = world.createObject(macguffin.record.id, 1)
    macguffinInstance:addScript("scripts\\" .. settings.MOD_NAME .. "\\item.lua", job)
    macguffinInstance:moveInto(targetContainer)
end

local function newJob(data)
    if data == nil then
        error("data is nil")
    end
    -- quest giver doesn't matter; we'll let any rank 7 thieves guild
    -- member manage quests.
    -- `actorInstanceID` is the target NPC that owns the macguffin
    -- `cellID` is the cell that the item will spawn in.
    -- `extCellID` is the parent cell.
    -- `category` is the category of the theft.
    -- `macguffinRecordID` is the item record id for the macguffin.
    -- `macguffinInstanceID` is the instance id for the macguffin, once it is spawned.
    -- 
end

local function onCellChange(data)
    -- called when we enter a cell.
    -- used to place the macguffin.
    settings.debugPrint("entered " .. data.newCellID)
end

interfaces.ErnBurglary.onCellChangeCallback(onCellChange)

local function onStolenCallback(data)
    -- called when we steal an item.
    -- used to confirm that we stole the macguffin.
    -- the `caught` field will be used to determine if we get the full reward or not.
    -- used to confirm that the player didn't cheat by getting the item 
    -- from somewhere else.
    settings.debugPrint("stole " .. data.itemRecord.id .. " from " .. data.owner.recordId)
end

interfaces.ErnBurglary.onStolenCallback(onStolenCallback)

return {
    eventHandlers = {},
    engineHandlers = {
        onSave = saveState,
        onLoad = loadState
    }
}
