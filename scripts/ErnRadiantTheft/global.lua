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
local infrequent = require("scripts.ErnRadiantTheft.infrequent")
local cells = require("scripts.ErnRadiantTheft.cells")
local note = require("scripts.ErnRadiantTheft.note")
local macguffins = require("scripts.ErnRadiantTheft.macguffins")
local interfaces = require('openmw.interfaces')
local async = require('openmw.async')
local world = require('openmw.world')
local types = require("openmw.types")
local core = require("openmw.core")
local util = require('openmw.util')
local aux_util = require('openmw_aux.util')
local storage = require('openmw.storage')

if require("openmw.core").API_REVISION < 62 then
    error("OpenMW 0.49 or newer is required!")
end

-- Init settings first to init storage which is used everywhere.
settings.initSettings()

local persistedState = {
    -- currentJobID is kept to maintain globally unique ids
    currentJobID = 0,
    -- players is a map of player-specific state to track.
    -- the index is the player id.
    players = {}
}

local function saveState()
    return persistedState
end

local function loadState(saved)
    persistedState = saved
end

local function initPlayer(player)
    persistedState.players[player.id] = {
        -- each player has a list of jobs. lowest index is current one.
        jobs = {}
    }
end

local function getPlayerState(player)
    local state = persistedState.players[player.id]
    if state == nil then
        state = initPlayer(player)
    end
    return state
end

local function savePlayerState(player, state)
    persistedState.players[player.id] = state
end

local function getExteriorCell(cell)
    if cell.isExterior or cell:hasTag("QuasiExterior") then
        return cell
    end
    for _, door in ipairs(common.shuffle(cell:getAll(types.Door))) do
        local destCell = types.Door.destCell(door)
        if (destCell ~= nil) and (destCell.isExterior or destCell:hasTag("QuasiExterior")) then
            return destCell
        end
    end
    return nil
end

local function getXY(cell)
    local _,_, x, y = string.find(cell.id, "Esm3ExteriorCell:([-0-9]+):([-0-9]+)")
    return util.vector2(tonumber(x), tonumber(y))
end

local function getDistance(cellA, cellB)
    if cellA.worldSpaceId ~= cellB.worldSpaceId then
        settings.debugPrint("different worldspaces for "..cellA.name .." and "..cellB.name)
        return 100000
    end
    local dist = (getXY(cellA) - getXY(cellB)):length()
    settings.debugPrint("distance from "..cellA.name .." to "..cellB.name .. ": "..tostring(dist))
    return dist
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

local function randomMacguffinForNPC(npcRecordId, forbiddenCategory)
    local record = types.NPC.record(npcRecordId)
    if record == nil then
        error("no record for npc: " .. npcRecordId)
    end

    local macguffin = nil
    for _, potenialMacguffin in ipairs(common.shuffle(macguffins.macguffins)) do
        if (forbiddenCategory ~= nil) and (forbiddenCategory == potenialMacguffin.category) then
            settings.debugPrint("Skipping repeated macguffin category " .. forbiddenCategory)
        elseif macguffins.filter(potenialMacguffin, record) then
            return potenialMacguffin
        end
    end
    settings.debugPrint("no suitable macguffins for npc: " .. npcRecordId)
    return nil
end

local function containerHasItem(container, itemRecordId)
    settings.debugPrint("checking if " .. container.recordId .. " has a " .. tostring(itemRecordId))
    return container.type.inventory(container):find(itemRecordId) ~= nil
end

local function setupMacguffinInCell(cell, forbiddenCategory)
    if cell == nil then
        error("failed to find cell")
        return nil
    end

    -- now we have to load the cell so we can get all the doors.
    -- pick a suitable interior cell.
    -- there should be owned containers in it.
    local bannedNPCs = {}
    local targetContainer = nil
    local macguffin = nil
    local mark = nil
    for _, container in ipairs(common.shuffle(cell:getAll(types.Container))) do
        if (container.owner ~= nil) and (container.owner.recordId ~= nil) then
            local containerRecord = types.Container.record(container)
            if (containerRecord.isOrganic == false) and (containerRecord.isRespawning == false) and
                (bannedNPCs[container.owner.recordId] ~= true) then
                settings.debugPrint("Finding a macguffin for " .. container.owner.recordId .. "...")
                -- a stable container with an owner.
                macguffin = randomMacguffinForNPC(container.owner.recordId, forbiddenCategory)
                if macguffin ~= nil and (containerHasItem(container, macguffin.record.id) == false) then
                    local ownerRecord = types.NPC.record(container.owner.recordId)
                    if ownerRecord ~= nil then
                        settings.debugPrint("Found a macguffin for " .. container.owner.recordId .. ".")
                        mark = ownerRecord
                        targetContainer = container
                        break
                    else
                        bannedNPCs[container.owner.recordId] = true
                    end
                end
            end
        end
    end
    if macguffin == nil then
        settings.debugPrint("failed to find a macguffin in " .. cell.id)
        return nil
    end

    return {
        targetContainer = targetContainer,
        macguffin = macguffin,
        mark = mark
    }
end

local function setupMacguffinInCells(parentCell, forbiddenCategory)
    settings.debugPrint("Building a job somewhere in " .. parentCell.name .. "...")
    -- recurse down to depth of 3.
    -- add all cells to a list
    -- randomly select from list.
    -- this lets us get into cantons and under-skarr.

    local cells = {}
    table.insert(cells, parentCell)
    for _, door in ipairs(getDoors(parentCell)) do
        local childCell = types.Door.destCell(door)
        table.insert(cells, childCell)
        for _, door in ipairs(getDoors(childCell)) do
            table.insert(cells, types.Door.destCell(door))
        end
    end

    for _, cell in ipairs(common.shuffle(cells)) do
        settings.debugPrint("Building a job in " .. cell.name .. "...")
        local setup = setupMacguffinInCell(cell, forbiddenCategory)
        if setup ~= nil then
            settings.debugPrint("Built a job in " .. cell.name .. "!")
            return setup
        end
    end
    return nil
end

local function newJob(player)
    if player == nil then
        error("player is nil")
        return
    elseif player.id == nil then
        error("player.id is nil")
        return
    end
    local state = getPlayerState(player)

    -- make sure we don't get duplicates back-to-back.
    local previousJob = state.jobs[1]

    local forbiddenCategory = nil
    if previousJob ~= nil then
        forbiddenCategory = previousJob.category
    end

    local myCell = getExteriorCell(player.cell)
    local maxDistance = 10

    -- determine parent cell.
    local parentCell = nil
    local setup = nil
    for _, cell in ipairs(common.shuffle(cells.allowedCells)) do
        if getDistance(myCell, cell) > maxDistance then
            settings.debugPrint("Skipping distant cell " .. cell.id)
        else
            -- this is a potentially valid cell.
            parentCell = cell

            setup = setupMacguffinInCells(parentCell, forbiddenCategory)
            if setup ~= nil then
                -- success
                break
            end
        end
    end
    if parentCell == nil then
        error("failed to find a parent cell")
        return
    end
    if setup == nil then
        error("failed to setup job")
        return
    end

    local targetContainer = setup.targetContainer
    local macguffin = setup.macguffin
    local mark = setup.mark

    -- make the new job (with a unique id)
    local macguffinInstance = world.createObject(macguffin.record.id, 1)
    persistedState.currentJobID = persistedState.currentJobID + 1
    local job = {
        jobID = persistedState.currentJobID,
        playerID = player.id,
        ownerRecordId = mark.id,
        extCellID = parentCell.id,
        targetContainerId = targetContainer.id,
        category = macguffin.category,
        type = macguffin.type,
        recordId = macguffin.record.id,
        itemInstance = macguffinInstance
    }

    -- place the macguffin
    macguffinInstance:moveInto(targetContainer)

    -- update current job
    table.insert(state.jobs, 1, job)
    savePlayerState(player, state)

    note.giveNote(player, #state.jobs, job.category, macguffin.record, mark, parentCell)
end

local function onStolenCallback(stolenItemsData)
    settings.debugPrint("onStolenCallback(" .. aux_util.deepToString(stolenItemsData, 4) .. ")")

    for _, data in ipairs(stolenItemsData) do
        -- called when we steal an item.
        -- used to confirm that we stole the macguffin.
        -- the `caught` field will be used to determine if we get the full reward or not.
        -- used to confirm that the player didn't cheat by getting the item 
        -- from somewhere else.
        -- settings.debugPrint("stole " .. tostring(data.itemRecord.id) .. " from " .. tostring(data.owner.recordId))

        local state = getPlayerState(data.player)

        local currentJob = state.jobs[1]
        -- settings.debugPrint("job: " .. aux_util.deepToString(currentJob, 4))
        if (currentJob == nil) or (currentJob.itemInstance.id ~= data.itemInstance.id) then
            return
        end
        settings.debugPrint("stole a macguffin")
        local quest = types.Player.quests(data.player)[common.questID]
        if quest.stage ~= common.questStage.STARTED then
            -- this can happen if the player places the quest item in an owned container
            -- and pulls it back out again.
            settings.debugPrint("quest state is bad for job " .. currentJob.jobID .. ": " .. tostring(quest.stage))
            return
        end
        -- we stole the right item.
        if data.caught then
            settings.debugPrint("job " .. currentJob.jobID .. " entered stolen_bad state")
            types.Player.quests(data.player)[common.questID]:addJournalEntry(common.questStage.STOLEN_BAD, data.player)
        else
            settings.debugPrint("job " .. currentJob.jobID .. " entered stolen_good state")
            types.Player.quests(data.player)[common.questID]:addJournalEntry(common.questStage.STOLEN_GOOD, data.player)
        end
    end
end

interfaces.ErnBurglary.onStolenCallback(onStolenCallback)

local restartCallback = async:registerTimerCallback(settings.MOD_NAME .. "_restart_quest_callback", function(data)
    if data.player == nil then
        error("no player for quest expiration")
        return
    end
    local quest = types.Player.quests(data.player)[common.questID]
    if quest.stage == common.questStage.RESTARTING then
        settings.debugPrint("restarting quest")
    else
        error("quest in bad state")
        return
    end
    -- try to reset journal since engine only accepts increasing numbers
    -- when modifying journal. these don't work.
    quest.finished = false
    quest.stage = common.questStage.AVAILABLE - 1
    quest:addJournalEntry(common.questStage.AVAILABLE, data.player)
    data.player:sendEvent(settings.MOD_NAME .. 'onQuestAvailable', data)
end)

local function onQuestUpdate(data)
    local quest = types.Player.quests(data.player)[common.questID]
    if data.stage == common.questStage.STARTED then
        settings.debugPrint("initializing new job")
        -- start up the new job.
        -- this will modify state, so we should exit after this.
        newJob(data.player)
    elseif quest.stage == common.questStage.COMPLETED or quest.stage == common.questStage.QUIT then
        -- RESTARTING exists so we don't double-spawn the restartCallback.
        settings.debugPrint("setting up timer for job restart")
        quest.stage = common.questStage.RESTARTING
        local waitTime = 60 * 60
        if quest.stage == common.questStage.QUIT then
            waitTime = waitTime * 24 * 3
        else
            waitTime = waitTime * 3
        end

        quest.finished = true

        async:newGameTimer(waitTime, restartCallback, {
            player = data.player
        })
    end
end

local function syncPlayer(player)
    local quest = types.Player.quests(player)[common.questID]
    if quest.stage < 1 then
        settings.debugPrint("quest not started")
        return
    end

    local state = getPlayerState(player)

    -- monitor for inventory changes.
    -- use quest stage to bridge into mwscript, since mwscript doesn't
    -- know which item it is looking for.

    local currentJob = state.jobs[1]
    settings.debugPrint("checking player status. quest: " .. tostring(quest.stage) .. ". job: " ..
                            aux_util.deepToString(currentJob, 4))

    if currentJob ~= nil then
        local hasMacguffin = containerHasItem(player, state.jobs[1].recordId)
        if (quest.stage == common.questStage.STOLEN_BAD) and (hasMacguffin == false) then
            quest.stage = common.questStage.STOLEN_BAD_LOST
            settings.debugPrint("lost the macguffin. " .. tostring(quest.stage))
        elseif (quest.stage == common.questStage.STOLEN_GOOD) and (hasMacguffin == false) then
            settings.debugPrint("lost the macguffin. " .. tostring(quest.stage))
            quest.stage = common.questStage.STOLEN_GOOD_LOST
        elseif (quest.stage == common.questStage.STOLEN_BAD_LOST) and (hasMacguffin) then
            settings.debugPrint("found the macguffin. " .. tostring(quest.stage))
            quest.stage = common.questStage.STOLEN_BAD
        elseif (quest.stage == common.questStage.STOLEN_GOOD_LOST) and (hasMacguffin) then
            settings.debugPrint("found the macguffin. " .. tostring(quest.stage))
            quest.stage = common.questStage.STOLEN_GOOD
        end
    end

    savePlayerState(player, state)
end

local function onActivate(object, actor)
    -- this is called before dialogue begins with an NPC.
    if types.NPC.objectIsInstance(object) then
        syncPlayer(actor)
    end
end

return {
    eventHandlers = {
        [settings.MOD_NAME .. "onQuestUpdate"] = onQuestUpdate
    },
    engineHandlers = {
        onSave = saveState,
        onLoad = loadState,
        onActivate = onActivate
    }
}
