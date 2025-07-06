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
]] local function shuffle(collection)
    local randList = {}
    for _, item in pairs(collection) do
        -- get random index to insert into. 1 to size+1.
        -- # is a special op that gets size
        local insertAt = math.random(1, 1 + #randList)
        table.insert(randList, insertAt, item)
    end
    return randList
end

local questStage = {
    AVAILABLE = 5,
    STARTED = 10,
    STOLEN_GOOD = 20,
    STOLEN_GOOD_LOST = 21,
    STOLEN_BAD = 30,
    STOLEN_BAD_LOST = 31,
    EXPIRED = 40,
    COMPLETED = 50
}

return {
    shuffle = shuffle,
    questID = "ernradianttheft_quest",
    questStage = questStage
}
