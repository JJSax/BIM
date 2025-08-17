assert(turtle, "Requires a crafty turtle.")

local craftError = require "/BIM.Feedback.craftError"

--#region Locals--
local recipes = {}
local clickList = {}
local mainScreen = term.current()
local mainSize = { mainScreen.getSize() }
local screen = window.create(mainScreen, 1, 1, mainSize[1] - 1, mainSize[2] - 1)
local screenSize = { screen.getSize() }
local scrollBar = window.create(mainScreen, screenSize[1] + 1, 1, 1, screenSize[2])
local recipeMenu = window.create(mainScreen, 1, mainSize[2], mainSize[1], 1)

local colAmount
local scrollIndex = 0
local selected = -1

local workbenchInputSlots = { 1, 2, 3, 5, 6, 7, 9, 10, 11 }
--#endregion Locals--

--#region Function--
local function storeFile(name, value)
    if name == nil then
        printError("No file name given")
        return nil
    end
    local file = fs.open(name, 'w')
    if file then
        file.write(textutils.serialise(value))
        file.close()
    else
        error("Failed to open " .. name .. " for writing") -- in case of read only / disk full etc.
    end
end

local function getDisplayName(slot)
    local name = turtle.getItemDetail(slot).name
    Vs.setItemDetail(name, turtle, slot)
    local details = Vs.itemDetailsMap[name]
    return details.displayName
end

local function readRecipe()
    local basicResultDetails = turtle.getItemDetail(16)
    if basicResultDetails == nil then return craftError.noOutputToSave end
    local recipe = {
        name = basicResultDetails.name,
        input = {}
    }
    local filename = getDisplayName(16)
    local inputEmpty = true
    for _, v in ipairs(workbenchInputSlots) do
        if turtle.getItemCount(v) > 0 then
            inputEmpty = false
            local item = turtle.getItemDetail(v, true)
            assert(item, "Failed to getItemDetail")

            recipe.input[v] = item.name
        end
    end
    if inputEmpty then return craftError.noIngredients end

    storeFile(Vs.name .. "/Recipes/" .. filename, recipe)
    selected = 0
    recipes = fs.list(Vs.name .. "/Recipes")
    clickList = Um.Print(recipes, selected, scrollIndex, scrollBar, screen, colAmount)
    return false
end

local function loadFile(name)
    assert(name, "No file name given")
    assert(fs.exists(name), name .. " file not found")

    local file = fs.open(name, 'r')
    if file then
        local serialized = file.readAll()
        file.close()
        assert(serialized, name .. " recipe file malformed")
        local value = textutils.unserialise(serialized)
        return value or {}
    else
        error("Failed to open " .. name .. " for writing") -- in case of read only / disk full etc.
    end
end

local function deleteRecipe()
    if selected == -1 or not selected then return craftError.noSelection end
    if not fs.exists(Vs.name .. "/Recipes/" .. selected) then return craftError.noRecipe end
    fs.delete(Vs.name .. "/Recipes/" .. selected)
    selected = -1
    recipes = fs.list(Vs.name .. "/Recipes")
    clickList = Um.Print(recipes, selected, scrollIndex, scrollBar, screen, colAmount)
    return false
end

---Get if Storage has enough input items
---@param recipe table The recipe table
---@param n integer How many crafts to check quanities
---@return boolean HasEnoughItems
local function ensureStock(recipe, n)
    local itemRequirements = {}
    for _, item in pairs(recipe.input) do -- Find how many are needed in entire recipe
        itemRequirements[item] = itemRequirements[item] or 0
        itemRequirements[item] = itemRequirements[item] + 1 * (n or 1)
    end
    for item, needed in pairs(itemRequirements) do
        if not Storage:hasNItems(item, needed) then return false end
    end
    return true
end

local function getMinCraftsPerStack(recipe)
    local maxInput = 64
    for _, item in pairs(recipe.input) do
        local max = Vs.itemDetailsMap[item].maxCount
        if max < maxInput then
            maxInput = max
        end
    end
    return 64 / maxInput
end

local function craftOne()
    local workbench = peripheral.find("workbench")
    if not workbench then return craftError.noWorkbench end
    if selected == -1 or not selected then return craftError.noSelection end
    if not Storage.buffer then return craftError.noBuffer end
    if not fs.exists(Vs.name .. "/Recipes/" .. selected) then return craftError.noRecipe end
    local recipe = loadFile(Vs.name .. "/Recipes/" .. selected)
    if recipe == nil or Storage.chests == nil then return craftError.malformedRecipe end
    if not ensureStock(recipe, 1) then return craftError.insufficientStock end

    for slot, item in pairs(recipe.input) do
        os.queueEvent("turtle_inventory_ignore")
        Storage:retrieveItem(item, 0.015625)
        turtle.select(slot)
        turtle.suckDown()
    end

    workbench.craft()
    os.queueEvent("turtle_inventory_ignore")
    turtle.drop()
    os.queueEvent("turtle_inventory_start")
    os.queueEvent("Update_Env")
    return false
end

local function craftStack()
    local workbench = peripheral.find("workbench")
    if not workbench then return craftError.noWorkbench end
    if selected == -1 or not selected then return craftError.noSelection end
    if not Storage.buffer then return craftError.noBuffer end
    if not fs.exists(Vs.name .. "/Recipes/" .. selected) then return craftError.noRecipe end
    local recipe = loadFile(Vs.name .. "/Recipes/" .. selected)
    if recipe == nil or Storage.chests == nil then return craftError.malformedRecipe end
    local detailMap = Vs.itemDetailsMap[recipe.name]
    if not detailMap then return craftError.unmappedOutput end
    if not ensureStock(recipe, detailMap.maxCount) then return craftError.insufficientStock end

    -- Find the minimum stack size among output and all inputs
    local minStack = detailMap.maxCount
    for _, item in pairs(recipe.input) do
        local inputItemDetails = Vs.itemDetailsMap[item]
        if not inputItemDetails then
            -- Clear turtle and put items into storage
            for slot in pairs(recipe.input) do
                if turtle.getItemCount(slot) > 0 then
                    turtle.dropDown()
                end
            end
            Storage:storeBuffer()
            return craftError.unmappedInput
        end
        local stackSize = inputItemDetails.maxCount
        if stackSize < minStack then
            minStack = stackSize
        end
    end

    local nCrafts = getMinCraftsPerStack(recipe)
    for _ = 1, nCrafts do
        -- Pull the correct amount for each ingredient
        for slot, item in pairs(recipe.input) do
            os.queueEvent("turtle_inventory_ignore")
            local ingredientStack = Vs.itemDetailsMap[item].maxCount
            local percent = minStack / ingredientStack
            Storage:retrieveItem(item, percent)
            turtle.select(slot)
            turtle.suckDown()
        end
        workbench.craft()
        os.queueEvent("turtle_inventory_ignore")
        turtle.drop()
    end

    os.queueEvent("turtle_inventory_start")
    os.queueEvent("Update_Env")
    return false
end

local function recipeError(msg)
    recipeMenu.setBackgroundColor(colors.red)
    local mLen = #msg
    local pad = (" "):rep(math.ceil((recipeMenu.getSize() - mLen) / 2))
    recipeMenu.setCursorPos(1, 1)
    recipeMenu.write(pad .. msg .. pad)
end

local buttons = { " Craft one ", " Craft stack ", " Save ", " Delete  " }
local function menu(selection, menuError)
    while not peripheral.find("workbench") do
        recipeError(craftError.noWorkbench)
        os.pullEvent("peripheral")
    end

    if menuError then
        recipeError(menuError)
        return
    end

    recipeMenu.setCursorPos(1, 1)
    for i, text in ipairs(buttons) do
        local bgColor = selection == i and (menuError and 'e' or '7') or '8'
        recipeMenu.blit(text, string.rep('f', #text), string.rep(bgColor, #text))
    end
end

local selectionFunctions = { craftOne, craftStack, readRecipe, deleteRecipe }
local function clickedMenu(x)
    local xPos = 0
    local buttonIndex
    for i, s in ipairs(buttons) do
        if x > xPos and x <= xPos + #s then
            buttonIndex = i
            break
        end
        xPos = xPos + #s
    end


    if selectionFunctions[buttonIndex] then
        local msg = selectionFunctions[buttonIndex]()
        if msg then
            menu(buttonIndex, msg)
            sleep(0.75)
        else
            menu(buttonIndex) -- darken buttonIndex button
            sleep(0.5)
        end
    end
    menu(0)
end

local function loopPrint()
    while true do
        local event = { os.pullEvent() }
        if event[1] == "mouse_scroll" and scrollIndex ~= math.min(math.max(scrollIndex + event[2], 0), math.max(math.ceil(#recipes / colAmount) - screenSize[2], 0)) then
            scrollIndex = scrollIndex + event[2]
            clickList = Um.Print(recipes, selected, scrollIndex, scrollBar, screen, colAmount)
        elseif event[1] == "mouse_click" then
            if event[4] > screenSize[2] then
                clickedMenu(event[3])
            else
                selected = recipes[Um.Click(clickList, event[3], event[4])]
                Um.Print(recipes, selected, scrollIndex, scrollBar, screen, colAmount)
            end
        elseif event[1] == "click_ignore" then
            os.pullEvent("click_start")
        elseif event[1] == "peripheral_detach" then
            menu(-1) -- Instantly show no workbench message.
        end
    end
end

local function loadEnv()
    colAmount = tonumber(Vs.getEnv("Columns"))
end

local function loopEnv()
    while true do
        os.pullEvent("Update_Env")
        loadEnv()
        selected = -1
        scrollIndex = 0
        Um.Print(recipes, selected, scrollIndex, scrollBar, screen, colAmount)
    end
end

--#endregion Function--

--#region Main--
repeat
    sleep(0.1)
until Vs.getEnv() ~= nil
loadEnv()

scrollBar.setBackgroundColor(colors.gray)
recipeMenu.setBackgroundColor(colors.lightGray)
screen.clear()
scrollBar.clear()
recipeMenu.clear()
if not fs.exists(Vs.name .. "/Recipes/") then
    fs.makeDir(Vs.name .. "/Recipes")
end

menu(0)
screen.setCursorPos(1, 1)
recipes = fs.list(Vs.name .. "/Recipes")
clickList = Um.Print(recipes, selected, scrollIndex, scrollBar, screen, colAmount)

local success, result = pcall(function()
    parallel.waitForAll(loopPrint, loopEnv)
end)

if not success then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.white)
    print(success)
    print(result)
    print(debug.traceback())
    os.pullEvent("key")
end
--#endregion Main--
