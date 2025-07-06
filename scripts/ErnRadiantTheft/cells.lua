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

-- allowedCells contains the allowed exterior cells to search.
-- this is just a list of Cell objects.
local allowedCells = {}

local function loadAllowedCells()
    -- read allow list.
    -- this can contain cells that don't exist.
    -- this can consist of cell names or cell ids.
    local handle = nil
    local err = nil
    handle, err = vfs.open("scripts\\"..settings.MOD_NAME.."\\cells.txt")
    if handle == nil then
        error(err)
        return
    end
    local allowedNames = {}
    for _, line in ipairs(handle:lines()) do
        allowedNames[string.gsub(line, "%s", "")] = true
    end
    -- add cells in our allowlist
    for _, cell in ipairs(world.cells) do
        if allowedNames[cell.id] or allowedNames[cell.name] then
            table.insert(allowedCells, cell)
        end
    end
    settings.debugPrint("Loaded "..tostring(#allowedCells).." exterior cells into the allowlist.")
end

loadAllowedCells()

return {
    allowedCells = allowedCells,
}