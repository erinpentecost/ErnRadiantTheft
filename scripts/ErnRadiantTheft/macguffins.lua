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
]]

local vfs = require('openmw.vfs')
local settings = require("scripts.ErnRadiantTheft.settings")
local world = require('openmw.world')
local types = require('openmw.types')

-- macguffins is a list of {category, type, record}.
local macguffins = {}

local function getRecord(itemtype, id)
    if itemtype == "Miscellaneous" then
        return types.Miscellaneous.records[id]
    end
    if itemtype == "Armor" then
        return types.Armor.records[id]
    end
    if itemtype == "Potion" then
        return types.Potion.records[id]
    end
    if itemtype == "Ingredient" then
        return types.Ingredient.records[id]
    end
    if itemtype == "Book" then
        return types.Book.records[id]
    end
    if itemtype == "Clothing" then
        return types.Clothing.records[id]
    end
    error("unknown type: "..itemtype)
    return nil
end

local function loadMacguffins()
    -- read allow list.
    -- this can contain cells that don't exist.
    -- this can consist of cell names or cell ids.
    local handle = nil
    local err = nil
    handle, err = vfs.open("scripts\\"..settings.MOD_NAME.."\\macguffins.txt")
    if handle == nil then
        error(err)
        return
    end

    for _, line in ipairs(handle:lines()) do
        -- there should be three fields: category, itemtype, itemrecordid.
        local split = string.gmatch(line, "[^,]+")
        if #split ~= 3 then
            error("line doesn't have 3 fields: "..line)
        else
            -- this line is ok. strip spaces.
            split[1] = string.gsub(split[1], "%s", "")
            split[2] = string.gsub(split[2], "%s", "")
            split[3] = string.gsub(split[3], "%s", "")
            
            local record = getRecord(split[2], split[3])
            if record == nil then
                error("couldn't find record for line: "..line)
            else
                table.insert(macguffins, {
                    category = split[1],
                    type = split[2],
                    record = record,
                })
            end
        end
    end

end

loadMacguffins()

return {
    macguffins = macguffins,
}