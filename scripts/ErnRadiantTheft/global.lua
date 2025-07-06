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

local persistedState = {}

local function saveState()
    return persistedState
end

local function loadState(saved)
    if saved == nil then
        persistedState = {}
    else
        persistedState = saved
    end
end

local function newJob(data)
    if data == nil then
        error("data is nil")
    end
    -- quest giver doesn't matter; we'll let any rank 8 thieves guild
    -- member manage quests.
    -- `mark` is the target NPC that owns the macguffin
    -- `cell` is the cell that the item will spawn in.
    -- `macguffinRecordID` is the item record id for the macguffin.
    -- `macguffinInstanceID` is the instance id for the macguffin, once it is spawned.
    -- 
end

local function onCellChange(data)
    -- called when we enter a cell.
    -- used to place the macguffin.
    settings.debugPrint("entered "..data.newCellID)
end

interfaces.ErnBurglary.onCellChangeCallback(onCellChange)

local function onStolenCallback(data)
    -- called when we steal an item.
    -- used to confirm that we stole the macguffin.
    -- the `caught` field will be used to determine if we get the full reward or not.
    -- used to confirm that the player didn't cheat by getting the item 
    -- from somewhere else.
    settings.debugPrint("stole "..data.itemRecord.id.." from "..data.owner.recordId)
end

interfaces.ErnBurglary.onStolenCallback(onStolenCallback)


return {
    eventHandlers = {
    },
    engineHandlers = {
        onSave = saveState,
        onLoad = loadState,
    }
}
