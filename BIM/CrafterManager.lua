assert(turtle, "Requires a crafty turtle.")

--#region Locals--
local workbench = peripheral.find("workbench")
local recipes = {} -- array of recipe names
local clickList = {}
local mainScreen = term.current()
local mainSize = { mainScreen.getSize() }
local screen = window.create(mainScreen, 1, 1, mainSize[1] - 1, mainSize[2] - 1)
local screenSize = { screen.getSize() }
local scrollBar = window.create(mainScreen, screenSize[1] + 1, 1, 1, screenSize[2])
local recipeMenu = window.create(mainScreen, 1, mainSize[2], mainSize[1], 1)

local colAmount
local scrollIndex = 0
--todo look into separating selected string type and integer type
local selected = -1 ---@type integer|string string if valid item selected, otherwise which slot was selected

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
    if basicResultDetails == nil then return true end
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
    if inputEmpty then return true end

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
    if not selected then return true end
    if not fs.exists(Vs.name .. "/Recipes/" .. selected) then return true end
    fs.delete(Vs.name .. "/Recipes/" .. selected)
    selected = -1
    recipes = fs.list(Vs.name .. "/Recipes")
    clickList = Um.Print(recipes, selected, scrollIndex, scrollBar, screen, colAmount)
    return false
end

---common craft function that does some pre-checks before delegating craft to Storage
---@param selected number|string The name of the selected item
---@param count number|"stack" The number to craft, "stack" to craft a full stack of the item
---@return boolean _ True if the craft errored, false if successful
local function craft(selected, count)
    if not selected then return true end
    if not fs.exists(Vs.name .. "/Recipes/" .. selected) then return true end
    local recipe = loadFile(Vs.name .. "/Recipes/" .. selected)
    if count == "stack" then count = Vs.itemDetailsMap[recipe.name].maxCount end
    return Storage:craftN(recipe, count)
end
local function craftOne()   return craft(selected, 1) end
local function craftStack() return craft(selected, "stack") end

local buttons = { " Craft one ", " Craft stack ", " Save ", " Delete  " }
local function menu(selection, menuError)
    if not workbench then
        recipeMenu.setCursorPos(1, 1)
        recipeMenu.write("Requires Crafty Turtle")
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

    menu(buttonIndex) -- darken buttonIndex button
    if selectionFunctions[buttonIndex] then
        if selectionFunctions[buttonIndex]() then
            menu(buttonIndex, true)
            sleep(0.5)
        end
    end
    menu(0)
end

-- draw the crafting menu
-- This will draw a menu that will allow the user to decide how much to craft, and if they want to recursively craft
---@param itemName string The display name of the item clicked
local function craftingMenu(itemName)
    if not itemName then return false end
    do
        recipeMenu.clear() -- normal buttons should not be shown; they aren't used here
        local craftText = " Craft "
        recipeMenu.setCursorPos(1, 1)
        recipeMenu.blit(craftText, ('f'):rep(#craftText), ('7'):rep(#craftText))

        local text = " Return "
        recipeMenu.setCursorPos(recipeMenu:getSize() - #text + 1, 1) -- adjust to the right
        recipeMenu.blit(text, string.rep('f', #text), string.rep('7', #text))
    end

    local screenWidth = screenSize[1]
    local craftNum = 1
    -- local recurse = true
    local cButtons = {}

    local function drawCharButton(viewport, button)
        if button.bc then
            viewport.setBackgroundColor(button.bc)
        end
        if button.tc then
            viewport.setTextColor(button.tc)
        end
        for cy = button.y, button.y + button.h - 1 do
            viewport.setCursorPos(button.x, cy)
            viewport.write((' '):rep(button.w))
        end
        viewport.setCursorPos(button.x + button.w / 2, button.y + button.h / 2)
        viewport.write(button.char)
    end

    local function write(t, x, y, tc, bc)
        screen.setCursorPos(x, y)
        screen.blit(t, tc:rep(#t), bc:rep(#t))
    end

    local function drawCraftNum()
        write((' '):rep(5), 9, 6, 'f', '8')
        local numberLength = string.len(craftNum)
        write(tostring(craftNum), 12 + (-numberLength + numberLength / 2), 6, 'f', '8')
    end

    screen.clear()
    -- Show item title being requested
    screen.setBackgroundColor(colors.lightGray)
    for i = 1, 3 do
        screen.setCursorPos(1, i)
        screen.clearLine()
    end

    -- Draw fancy border around item display name
    local x = math.floor(screenWidth / 2 - #itemName/2)
    write(itemName, x, 2, 'f', '8')
    write(string.char(0x8C):rep(#itemName), x, 1, '9', '8') -- top
    write(string.char(0x83):rep(#itemName), x, 3, '9', '8') -- bottom
    write(string.char(0x95), x - 1, 2, '9', '8') -- left
    write(string.char(0x95), x + #itemName, 2, '8', '9') -- right
    write(string.char(0x9C), x - 1, 1, '9', '8') -- tl corner
    write(string.char(0x93), x + #itemName, 1, '8', '9') -- tr corner
    write(string.char(0x83), x - 1, 3, '9', '8') -- bl corner
    write(string.char(0x83), x + #itemName, 3, '9', '8') -- br corner

    local function createCharButton(viewport, char, x, y, w, h, callback, tc, bc)
        table.insert(cButtons, {char = char, x = x, y = y, w = w, h = h, callback = callback, tc = tc, bc = bc})
        drawCharButton(viewport, cButtons[#cButtons])
    end

    local function sub64() craftNum = craftNum - 64 end
    local function sub1()  craftNum = craftNum - 1 end
    local function add1()  craftNum = craftNum + 1 end
    local function add64() craftNum = craftNum == 1 and 64 or craftNum + 64 end

    -- draw amount changing buttons
    createCharButton(screen, string.char(0xAB), 2, 5, 3, 3, sub64, colors.white, colors.gray) -- "«"
    createCharButton(screen, string.char(0x2D), 5, 5, 3, 3, sub1, colors.white, colors.gray) -- "-"
    createCharButton(screen, string.char(0x2B), 15,5, 3, 3, add1, colors.white, colors.gray) -- "+"
    createCharButton(screen, string.char(0xBB), 18,5, 3, 3, add64, colors.white, colors.gray) -- "»"

    -- draw number to craft
    drawCharButton(screen, {char = ' ', x = 8, y = 5, w = 7, h = 3, bc = colors.lightGray, tc = colors.black})
    drawCraftNum()

    while true do
        local _, _, x, y = os.pullEvent("mouse_click")

        if y > screenSize[2] then
            if x > recipeMenu:getSize() - 8 then -- if clicked on return button
                break
            elseif x <= 7 then
                --todo recursive crafting
                if craft(itemName, craftNum) then
                    local craftText = " Error "
                    recipeMenu.setCursorPos(1, 1)
                    recipeMenu.blit(craftText, ('f'):rep(#craftText), ('e'):rep(#craftText))
                    sleep(0.4)
                end
                break
            end
        else
            for _, v in ipairs(cButtons) do
                if x >= v.x and x < v.x + v.w and y >= v.y and y < v.y + v.h then
                    v.callback(v)
                    if craftNum < 1 then craftNum = 1 end
                    screen.setBackgroundColor(colors.lightBlue)
                    screen.setTextColor(colors.white)
                    drawCharButton(screen, v)
                    sleep(0.05)
                    screen.setBackgroundColor(colors.gray)
                    drawCharButton(screen, v)
                    drawCraftNum()
                end
            end
        end
    end
end

local function loopPrint()
    while true do
        local event = { os.pullEvent() }
        if event[1] == "mouse_scroll" and scrollIndex ~= math.min(math.max(scrollIndex + event[2], 0), math.max(math.ceil(#recipes / colAmount) - screenSize[2], 0)) then
            scrollIndex = scrollIndex + event[2]
            clickList = Um.Print(recipes, selected, scrollIndex, scrollBar, screen, colAmount)
        elseif event[1] == "mouse_click" then
            if event[4] > screenSize[2] then -- if clicked on bottom buttons.  Aka the crafts, save, delete buttons
                clickedMenu(event[3])
            else
                local itemClicked = Um.Click(clickList, event[3], event[4])
                selected = recipes[itemClicked]
                if event[2] == 3 then -- middle click
                    craftingMenu(selected)
                    screen.setBackgroundColor(colors.black)
                    screen.setTextColor(colors.white)
                    clickList = Um.Print(recipes, selected, scrollIndex, scrollBar, screen, colAmount)
                    clickedMenu(-1)
                else
                    Um.Print(recipes, selected, scrollIndex, scrollBar, screen, colAmount)
                end
            end
        elseif event[1] == "click_ignore" then
            os.pullEvent("click_start")
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
    os.pullEvent("key")
end
--#endregion Main--
