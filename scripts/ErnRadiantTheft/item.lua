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
local aux_util = require('openmw_aux.util')
local self = require("openmw.self")
local common = require("scripts.ErnRadiantTheft.common")

-- persistedState contains a copy of the job, at the time it was created.
local persistedState = {}

local function saveState()
    return persistedState
end

local function loadState(saved)
    if saved ~= nil then
        for k, v in pairs(saved) do
            if v ~= nil then
                persistedState[k] = v
            end
        end
    end
end

local function onInit(initData)
    for k, v in pairs(initData) do
        if v ~= nil then
            persistedState[k] = v
        end
    end
    settings.debugPrint("item init: " .. tostring(self.recordId) .. "(" .. tostring(self.id) .. "): " ..
                            aux_util.deepToString(persistedState, 3))
end

return {
    eventHandlers = {
    },
    engineHandlers = {
        onInit = onInit,
        onSave = saveState,
        onLoad = loadState
    }
}
