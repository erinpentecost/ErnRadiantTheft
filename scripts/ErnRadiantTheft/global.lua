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
local macguffins = require("scripts.ErnRadiantTheft.macguffins")
local interfaces = require('openmw.interfaces')
local async = require('openmw.async')
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
            -- currentJobID is kept to maintain globally unique ids
            currentJobID = 0,
            -- players is a map of player-specific state to track.
            -- the index is the player id.
            players = {}
        }
    else
        persistedState = saved
    end
end

local function initPlayer(player)
    persistedState.players[player.id] = {
        -- each player has a list of jobs. lowest index is current one.
        jobs = {},
        lastQuestStage = -1
    }
end

local function getState(player)
    local state = persistedState.players[player.id]
    if state == nil then
        state = initPlayer(player)
    end
    return state
end

local function saveState(player, state)
    persistedState.players[player.id] = state
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

local function randomMacguffinForNPC(npcRecordId, previousJob)
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

local expireCallback = async:registerTimerCallback(settings.MOD_NAME .. "_expire_quest_callback", function(data)
    if data.player == nil then
        error("no player for quest expiration")
        return
    end
    if data.jobID == nil then
        error("no jobID for quest expiration")
    end
    local state = persistedState.players[data.player.id]
    local currentJob = state.jobs[1]
    if (state ~= nil) and (currentJob.jobID == data.jobID) then
        -- only fail the quest if the item hasn't been stolen yet.
        local quest = types.Player.quests(data.player)[common.questID]
        if quest.stage == common.questStage.STARTED then
            settings.debugPrint("quest expired")
            -- fail the quest.
            quest:addJournalEntry(common.questStage.EXPIRED, data.player)
            -- delete the item.
            -- this won't always work (like if there's a stack that deleted the original)
            currentJob.itemInstance:remove(1)
        end
    end
end)

local function giveNoteToPlayer(player, job)
    -- TODO
end

local function newJob(player)
    if player == nil then
        error("player is nil")
        return
    elseif player.id == nil then
        error("player.id is nil")
        return
    end
    local state = getState(player)

    -- make sure we don't get duplicates back-to-back.
    local previousJob = state.jobs[1]

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
                    macguffin = randomMacguffinForNPC(container.owner.recordId, previousJob)
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
    local macguffinInstance = world.createObject(macguffin.record.id, 1)
    persistedState.currentJobID = persistedState.currentJobID + 1
    local job = {
        jobID = persistedState.currentJobID,
        playerID = player.id,
        ownerRecordId = mark,
        extCellID = parentCell.id,
        targetContainerId = targetContainer.id,
        category = macguffin.category,
        type = macguffin.type,
        recordId = macguffin.recordId,
        itemInstance = macguffinInstance
    }

    -- place the macguffin
    macguffinInstance:addScript("scripts\\" .. settings.MOD_NAME .. "\\item.lua", job)
    macguffinInstance:moveInto(targetContainer)

    -- update current job
    table.insert(state.jobs, 1, job)
    saveState(player, state)

    -- set the expiration for 5 in-game days from now.
    async:newSimulationTimer(60 * 60 * 24 * 5, expireCallback, {
        player,
        jobID = job.jobID
    })

    giveNoteToPlayer(player, job)
end

local function onStolenCallback(data)
    -- called when we steal an item.
    -- used to confirm that we stole the macguffin.
    -- the `caught` field will be used to determine if we get the full reward or not.
    -- used to confirm that the player didn't cheat by getting the item 
    -- from somewhere else.
    settings.debugPrint("stole " .. data.itemRecord.id .. " from " .. data.owner.recordId)

    local state = getState(data.player)

    local currentJob = state.jobs[1]
    if (currentJob == nil) or (currentJob.itemInstance.id ~= data.itemInstance) then
        return
    end
    local quest = types.Player.quests(data.player)[common.questID]
    if quest.stage ~= common.questStage.STARTED then
        -- this can happen if the player places the quest item in an owned container
        -- and pulls it back out again.
        settings.debugPrint("quest state is bad for job " .. currentJob.jobID .. ": " .. tostring(quest.stage))
        return
    end
    -- we stole the right item.
    if data.caught then
        settings.debugPrint("job " .. currentJob.jobID .. " entered stolen_good state")
        types.Player.quests(data.player)[common.questID]:addJournalEntry(common.questStage.STOLEN_BAD, data.player)
    else
        settings.debugPrint("job " .. currentJob.jobID .. " entered stolen_bad state")
        types.Player.quests(data.player)[common.questID]:addJournalEntry(common.questStage.STOLEN_GOOD, data.player)
    end
end

interfaces.ErnBurglary.onStolenCallback(onStolenCallback)

local function playerHasItemRecord(player, itemRecord)
    for _, item in ipairs(types.Actor.inventory(player):getAll()) do
        -- use recordId instead of instance id to work around stack shenanigans.
        if item.recordId == itemRecord then
            return true
        end
    end
    return false
end

local infrequentMap = infrequent.FunctionCollection:new()

local function onInfrequentUpdate(dt)
    for _, player in ipairs(world.players) do
        local state = getState(player)

        -- monitor for quest start.
        local quest = types.Player.quests(player)[common.questID]

        if quest.stage ~= state.lastQuestStage then
            settings.debugPrint("quest stage changed from " .. tostring(state.lastQuestStage) .. " to " ..
                                    tostring(quest.stage))
            -- quest stage changed somehow.
            local previousStage = state.lastQuestStage
            state.lastQuestStage = quest.stage
            saveState(state)
            if quest.stage == common.questStage.STARTED then
                -- start up the new job.
                -- this will modify state, so we should exit after this.
                newJob(player)
            end

            -- quit after we see a state change.
            return
        end

        -- monitor for inventory changes.
        -- use quest stage to bridge into mwscript, since mwscript doesn't
        -- know which item it is looking for.
        local currentJob = state.jobs[1]
        if currentJob ~= nil then
            local hasMacguffin = playerHasItemRecord(player, state.jobs[1].recordId)
            if (quest.stage == common.questStage.STOLEN_BAD) and (hasMacguffin == false) then
                quest.stage = common.questStage.STOLEN_BAD_LOST
                state.lastQuestStage = quest.stage
            elseif (quest.stage == common.questStage.STOLEN_GOOD) and (hasMacguffin == false) then
                quest.stage = common.questStage.STOLEN_GOOD_LOST
                state.lastQuestStage = quest.stage
            elseif (quest.stage == common.questStage.STOLEN_BAD_LOST) and (hasMacguffin) then
                quest.stage = common.questStage.STOLEN_BAD
                state.lastQuestStage = quest.stage
            elseif (quest.stage == common.questStage.STOLEN_GOOD_LOST) and (hasMacguffin) then
                quest.stage = common.questStage.STOLEN_GOOD
                state.lastQuestStage = quest.stage
            end
        end

        -- check for new membership into thieves guild
        if (quest.stage <= 0) or (quest.stage == false) then
            -- quest hasn't started. we need to get to first stage so the dialogue topic
            -- is available.
            local thievesRank = types.NPC.getFactionRank(player, "Thieves Guild")
            if thievesRank > 0 then
                quest:addJournalEntry(common.questStage.AVAILABLE, player)
            end
        end

        saveState(player, state)
    end
end

infrequentMap:addCallback("onInfrequentUpdate", 1.0, onInfrequentUpdate)

local function onUpdate(dt)
    infrequentMap:onUpdate(dt)
end

return {
    eventHandlers = {},
    engineHandlers = {
        onSave = saveState,
        onLoad = loadState
    }
}
