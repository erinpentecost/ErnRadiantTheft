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
]] local interfaces = require("openmw.interfaces")
local storage = require("openmw.storage")
local types = require("openmw.types")

local MOD_NAME = "ErnRadiantTheft"

local SettingsGameplay = storage.globalSection("SettingsGameplay" .. MOD_NAME)

local function debugMode()
    return SettingsUI:get("debugMode")
end


local function debugPrint(str, ...)
    if debugMode() then
        local arg = {...}
        if arg ~= nil then
            print(string.format("DEBUG: " .. str, unpack(arg)))
        else
            print("DEBUG: " .. str)
        end
    end
end

local function registerPage()
    interfaces.Settings.registerPage {
        key = MOD_NAME,
        l10n = MOD_NAME,
        name = "name",
        description = "description"
    }
end

local function initSettings()
    interfaces.Settings.registerGroup {
        key = "SettingsGameplay" .. MOD_NAME,
        l10n = MOD_NAME,
        name = "modSettingsGameplayTitle",
        description = "modSettingsGameplayDesc",
        page = MOD_NAME,
        permanentStorage = false,
        settings = {{
            key = "bountyScale",
            name = "bountyScale_name",
            description = "bountyScale_description",
            default = 1,
            renderer = "number",
            argument = {
                integer = false,
                min = 0,
                max = 100
            }
        }, {
            key = "trespassFine",
            name = "trespassFine_name",
            description = "trespassFine_description",
            default = 0,
            renderer = "number",
            argument = {
                integer = true,
                min = 0,
                max = 1000
            }
        }, {
            key = "revertBounties",
            name = "revertBounties_name",
            description = "revertBounties_description",
            default = true,
            renderer = "checkbox"
        }, {
            key = "lenientFactions",
            name = "lenientFactions_name",
            description = "lenientFactions_description",
            default = true,
            renderer = "checkbox"
        }}
    }

    print("init settings")
end


return {
    initSettings = initSettings,
    MOD_NAME = MOD_NAME,

    registerPage = registerPage,

    debugMode = debugMode,
    debugPrint = debugPrint
}
