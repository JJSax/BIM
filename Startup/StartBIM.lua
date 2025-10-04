local projectName = "BIM"
local programs = { "Inventory", "Crafter", "Settings" }
local Um = require('/' .. projectName .. "/Functions/UiManager")
local SS = require('/' .. projectName .. "/Functions/StorageSystem")
local Vs = require('/' .. projectName .. "/Functions/VariableStorage")
SS:init(Vs)
Um.setVs(Vs)

for _, value in ipairs(programs) do
    multishell.setTitle(
        multishell.launch(
            {
                Um = Um,
                Vs = Vs,
                Storage = SS,
                require = require,
                multishell = multishell
            },
            '/' .. projectName .. '/' .. value .. 'Manager.lua'),
        value
    )
end
