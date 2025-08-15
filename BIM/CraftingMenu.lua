
local CM = {}
CM.__index = CM

local function drawCharButton(viewport, button, flash)
	if not flash and  button.bc then
		viewport.setBackgroundColour(button.bc)
	end
	if not flash and  button.tc then
		viewport.setTextColor(button.tc)
	end
	for cy = button.y, button.y + button.h - 1 do
		viewport.setCursorPos(button.x, cy)
		viewport.write((' '):rep(button.w))
	end
	viewport.setCursorPos(button.x + button.w / 2, button.y + button.h / 2)
	viewport.write(button.char)
end

--!D.R.Y
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

---@param itemName string The display name of the item clicked
function CM.open(storageSystem, screen, recipeMenu, itemName)
	if not itemName then return false end
	local self = setmetatable({}, CM)

	self.screen = screen
	self.craftNum = 1
	self.cButtons = {}
	self.recipeMenu = recipeMenu

	self.screenWidth, self.screenHeight = screen.getSize()
	self.Storage = storageSystem

	self:craftingMenu(itemName)
end

function CM:write(t, x, y, tc, bc)
	self.screen.setCursorPos(x, y)
	self.screen.blit(t, tc:rep(#t), bc:rep(#t))
end

function CM:drawCraftNum()
	self:write((' '):rep(5), 9, 6, 'f', '8')
	local numberLength = string.len(self.craftNum)
	self:write(tostring(self.craftNum), 12 + (-numberLength + numberLength / 2), 6, 'f', '8')
end

function CM:createCharButton(viewport, char, x, y, w, h, callback, tc, bc)
	table.insert(self.cButtons, { char = char, x = x, y = y, w = w, h = h, callback = callback, tc = tc, bc = bc })
	drawCharButton(viewport, self.cButtons[#self.cButtons])
end

function CM:drawItemLabel(itemName, x)
	-- Show item title being requested
	self.screen.setBackgroundColor(colors.lightGray)
	for i = 1, 3 do
		self.screen.setCursorPos(1, i)
		self.screen.clearLine()
	end

	-- Draw fancy border around item display name
	self:write(itemName, x, 2, 'f', '8')
	self:write(string.char(0x8C):rep(#itemName), x, 1, '9', '8') -- top
	self:write(string.char(0x83):rep(#itemName), x, 3, '9', '8') -- bottom
	self:write(string.char(0x95), x - 1, 2, '9', '8')         -- left
	self:write(string.char(0x95), x + #itemName, 2, '8', '9') -- right
	self:write(string.char(0x9C), x - 1, 1, '9', '8')         -- tl corner
	self:write(string.char(0x93), x + #itemName, 1, '8', '9') -- tr corner
	self:write(string.char(0x83), x - 1, 3, '9', '8')         -- bl corner
	self:write(string.char(0x83), x + #itemName, 3, '9', '8') -- br corner
end

-- draw the crafting menu
-- This will draw a menu that will allow the user to decide how much to craft, and if they want to recursively craft
---@param itemName string The display name of the item clicked
function CM:craftingMenu(itemName)
	if not itemName then return false end
	do
		self.recipeMenu.clear() -- normal buttons should not be shown; they aren't used here
		local craftText = " Craft "
		self.recipeMenu.setCursorPos(1, 1)
		self.recipeMenu.blit(craftText, ('f'):rep(#craftText), ('7'):rep(#craftText))

		local text = " Return "
		self.recipeMenu.setCursorPos(self.recipeMenu:getSize() - #text + 1, 1) -- adjust to the right
		self.recipeMenu.blit(text, string.rep('f', #text), string.rep('7', #text))
	end

	local recurse = true

	self.screen.clear()
	-- Show item title being requested
	self.screen.setBackgroundColor(colors.lightGray)
	for i = 1, 3 do
		self.screen.setCursorPos(1, i)
		self.screen.clearLine()
	end

	-- Draw fancy border around item display name
	local x = math.floor(self.screenWidth / 2 - #itemName / 2)
	self:write(itemName, x, 2, 'f', '8')
	self:write(string.char(0x8C):rep(#itemName), x, 1, '9', '8') -- top
	self:write(string.char(0x83):rep(#itemName), x, 3, '9', '8') -- bottom
	self:write(string.char(0x95), x - 1, 2, '9', '8')            -- left
	self:write(string.char(0x95), x + #itemName, 2, '8', '9')    -- right
	self:write(string.char(0x9C), x - 1, 1, '9', '8')            -- tl corner
	self:write(string.char(0x93), x + #itemName, 1, '8', '9')    -- tr corner
	self:write(string.char(0x83), x - 1, 3, '9', '8')            -- bl corner
	self:write(string.char(0x83), x + #itemName, 3, '9', '8')    -- br corner

	local function sub64() self.craftNum = self.craftNum - 64 end
	local function sub1() self.craftNum = self.craftNum - 1 end
	local function add1() self.craftNum = self.craftNum + 1 end
	local function add64() self.craftNum = self.craftNum == 1 and 64 or self.craftNum + 64 end

	-- draw amount changing buttons
	self:createCharButton(self.screen, string.char(0xAB), 2, 5, 3, 3, sub64, colors.white, colors.gray) -- "«"
	self:createCharButton(self.screen, string.char(0x2D), 5, 5, 3, 3, sub1, colors.white, colors.gray)  -- "-"
	self:createCharButton(self.screen, string.char(0x2B), 15, 5, 3, 3, add1, colors.white, colors.gray) -- "+"
	self:createCharButton(self.screen, string.char(0xBB), 18, 5, 3, 3, add64, colors.white, colors.gray) -- "»"

	-- draw number to craft
	drawCharButton(self.screen, { char = ' ', x = 8, y = 5, w = 7, h = 3, bc = colors.lightGray, tc = colors.black })
	self:drawCraftNum()

	-- self:createCharButton(
	-- 	self.screen,
	-- 	recurse and string.char(0x04) or ' ',
	-- 	2, 9, 1, 1, function(self)
	-- 		recurse = not recurse
	-- 		self.char = recurse and string.char(0x04) or ' '
	-- 	end,
	-- 	colors.lime, colors.gray
	-- )

	-- self.screen.setBackgroundColor(colors.black)
	-- self.screen.setTextColor(colors.white)
	-- self.screen.write(" Craft dependencies?")

	while true do
		local _, _, x, y = os.pullEvent("mouse_click")

		if y > self.screenHeight then
			if x > self.recipeMenu:getSize() - 8 then -- if clicked on return button
				break
			elseif x <= 7 then
				--todo recursive crafting
				if not fs.exists(Vs.name .. "/Recipes/" .. itemName) then return true end
				local recipe = loadFile(Vs.name .. "/Recipes/" .. itemName)
				if recipe and self.Storage:craftN(recipe, self.craftNum) then
					local craftText = " Error "
					self.recipeMenu.setCursorPos(1, 1)
					self.recipeMenu.blit(craftText, ('f'):rep(#craftText), ('e'):rep(#craftText))
					sleep(0.4)
				end
				break
			end
		else
			for _, v in ipairs(self.cButtons) do
				if x >= v.x and x < v.x + v.w and y >= v.y and y < v.y + v.h then
					v.callback(v)
					if self.craftNum < 1 then self.craftNum = 1 end
					self.screen.setBackgroundColor(colors.lightBlue)
					self.screen.setTextColor(colors.white)
					drawCharButton(self.screen, v, true) -- flash button
					sleep(0.05)
					self.screen.setBackgroundColor(colors.gray)
					drawCharButton(self.screen, v)
					self:drawCraftNum()
				end
			end
		end
	end
end

return CM