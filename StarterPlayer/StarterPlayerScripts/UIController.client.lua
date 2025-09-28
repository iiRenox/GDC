-- File: StarterPlayer/StarterPlayerScripts/UIController.client.lua
-- Summary: Redesigned radial build UI; opens on plot interaction and sends purchase for BitWell.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RE_Open = Remotes:WaitForChild("RE_Build_RequestOpen")
local RE_Buy = Remotes:WaitForChild("RE_Build_RequestPurchase")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local IconAssetIds = require(ReplicatedStorage:WaitForChild("IconAssetIds"))
local IconTables = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("IconTables"))

local gui
local currentContext -- { coreId, plotLetter, categories, buildings }

-- UI Elements
local radialMenu -- The main circular frame
local centralFrame -- The inner frame for context (icon/name)
local centerIcon
local centerLabel
local categoriesContainer -- Holds category buttons
local itemsContainer -- Holds item buttons
local backButton -- Not visible; navigation handled via B/Escape

-- Constants for UI sizing/positioning
local MENU_SIZE = 400 -- Overall width/height of the radial menu
local CENTRAL_FRAME_SIZE = 120 -- Size of the inner central frame
local BUTTON_SIZE = 72 -- +20% size for icons/buttons
local BUTTON_RADIUS = (MENU_SIZE / 2) - (BUTTON_SIZE / 2) - 20 -- Distance from center for buttons
local ANGLE_OFFSET = -math.pi/2 -- Start angle (points upwards)

-- Forward declarations for showing UI states
local showCategories
local showItems

-- Helper to safely destroy children GuiObjects
local function clearChildren(container)
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

-- Blur effect control
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local blurEffect

local function createBlurEffect()
	if blurEffect and blurEffect.Parent then return end

	local effect = Instance.new("BlurEffect")
	effect.Name = "RadialMenuBlur"
	effect.Size = 0 -- Start with no blur
	effect.Parent = game.Workspace.CurrentCamera
	blurEffect = effect
end

local function toggleBlur(enable)
	if not blurEffect or not blurEffect.Parent then createBlurEffect() end

	local targetSize = enable and 24 or 0
	TweenService:Create(blurEffect, TweenInfo.new(0.3), {Size = targetSize}):Play()
end

-- Ensure GUI elements are created or returned if they already exist
local function ensureGui()
	if gui and gui.Parent then return gui end

	gui = Instance.new("ScreenGui")
	gui.Name = "BuildMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = playerGui

	-- Main Radial Container
	radialMenu = Instance.new("Frame")
	radialMenu.Name = "RadialMenu"
	radialMenu.Size = UDim2.new(0, MENU_SIZE, 0, MENU_SIZE)
	radialMenu.Position = UDim2.new(0.5, -MENU_SIZE/2, 0.5, -MENU_SIZE/2)
	radialMenu.BackgroundColor3 = Color3.fromRGB(15,15,15)
	radialMenu.BackgroundTransparency = 0.8
	radialMenu.BorderSizePixel = 0
	radialMenu.ClipsDescendants = false
	radialMenu.Parent = gui

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(1, 0)
	uiCorner.Parent = radialMenu

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(50,50,50)
	uiStroke.Thickness = 2
	uiStroke.Transparency = 0.5
	uiStroke.Parent = radialMenu

	-- Central information area (icon + label)
	centralFrame = Instance.new("Frame")
	centralFrame.Name = "CentralFrame"
	centralFrame.Size = UDim2.new(0, CENTRAL_FRAME_SIZE, 0, CENTRAL_FRAME_SIZE)
	centralFrame.Position = UDim2.new(0.5, -CENTRAL_FRAME_SIZE/2, 0.5, -CENTRAL_FRAME_SIZE/2)
	centralFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
	centralFrame.BackgroundTransparency = 0.6
	centralFrame.BorderSizePixel = 0
	centralFrame.Parent = radialMenu

	local centralCorner = Instance.new("UICorner")
	centralCorner.CornerRadius = UDim.new(1,0)
	centralCorner.Parent = centralFrame

	-- Center icon
	centerIcon = Instance.new("ImageLabel")
	centerIcon.Name = "CenterIcon"
	centerIcon.Size = UDim2.new(0, 64, 0, 64)
	centerIcon.Position = UDim2.new(0.5, -32, 0.5, -54)
	centerIcon.BackgroundTransparency = 1
	centerIcon.Image = "rbxassetid://0"
	centerIcon.ImageColor3 = Color3.fromRGB(220,220,220)
	centerIcon.Parent = centralFrame

	centerLabel = Instance.new("TextLabel")
	centerLabel.Name = "CenterLabel"
	centerLabel.Size = UDim2.new(0, CENTRAL_FRAME_SIZE, 0, 18)
	centerLabel.Position = UDim2.new(0.5, -CENTRAL_FRAME_SIZE/2, 0.5, 18)
	centerLabel.BackgroundTransparency = 1
	centerLabel.Font = Enum.Font.GothamBold
	centerLabel.TextSize = 14
	centerLabel.TextColor3 = Color3.fromRGB(230,230,230)
	centerLabel.Text = ""
	centerLabel.Parent = centralFrame

	-- Categories Container
	categoriesContainer = Instance.new("Frame")
	categoriesContainer.Name = "Categories"
	categoriesContainer.Size = UDim2.new(1, 0, 1, 0)
	categoriesContainer.Position = UDim2.new(0, 0, 0, 0)
	categoriesContainer.BackgroundTransparency = 1
	categoriesContainer.Parent = radialMenu

	-- Items Container
	itemsContainer = Instance.new("Frame")
	itemsContainer.Name = "Items"
	itemsContainer.Size = UDim2.new(1, 0, 1, 0)
	itemsContainer.Position = UDim2.new(0, 0, 0, 0)
	itemsContainer.BackgroundTransparency = 1
	itemsContainer.Visible = false
	itemsContainer.Parent = radialMenu

	-- Info box for hovered item
	local infoBox = Instance.new("Frame")
	infoBox.Name = "InfoBox"
	infoBox.Size = UDim2.new(0, 220, 0, 64)
	infoBox.Position = UDim2.new(1, 12, 0.5, -32)
	infoBox.BackgroundColor3 = Color3.fromRGB(20,20,20)
	infoBox.BackgroundTransparency = 0.15
	infoBox.Visible = false
	infoBox.Parent = radialMenu

	local infoCorner = Instance.new("UICorner")
	infoCorner.CornerRadius = UDim.new(0, 8)
	infoCorner.Parent = infoBox

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -12, 1, -12)
	infoLabel.Position = UDim2.new(0, 6, 0, 6)
	infoLabel.BackgroundTransparency = 1
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.TextYAlignment = Enum.TextYAlignment.Top
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextSize = 14
	infoLabel.TextColor3 = Color3.fromRGB(230,230,230)
	infoLabel.TextWrapped = true
	infoLabel.Text = ""
	infoLabel.Parent = infoBox

	-- No explicit back/close buttons; navigation via keyboard/controller

	-- Simple fade-in tween for the whole menu
	radialMenu.BackgroundTransparency = 0.95
	TweenService:Create(radialMenu, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.8 }):Play()

	-- Radial button creation helper
	local function createRadialButton(parentContainer, index, totalCount, labelText, iconAssetId, fillColor, textColor, activateCallback, ringColor)
		local angle = (index-1)/totalCount * math.pi*2 + ANGLE_OFFSET
		local centerX = parentContainer.AbsoluteSize.X/2
		local centerY = parentContainer.AbsoluteSize.Y/2

		local btn = Instance.new("ImageButton")
		btn.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
		btn.Position = UDim2.new(0, math.floor(centerX + math.cos(angle)*BUTTON_RADIUS - BUTTON_SIZE/2),
			0, math.floor(centerY + math.sin(angle)*BUTTON_RADIUS - BUTTON_SIZE/2))
		btn.BackgroundTransparency = 1
		btn.Image = iconAssetId or "rbxassetid://0"
		btn.ImageColor3 = Color3.fromRGB(255,255,255) -- remove tint
		btn.AutoButtonColor = false
		btn.Parent = parentContainer

		local buttonUICorner = Instance.new("UICorner")
		buttonUICorner.CornerRadius = UDim.new(1,0)
		buttonUICorner.Parent = btn

		local buttonUIStroke = Instance.new("UIStroke")
		buttonUIStroke.Color = ringColor or Color3.fromRGB(255,0,0)
		buttonUIStroke.Thickness = 3
		buttonUIStroke.Transparency = 0.7
		buttonUIStroke.Parent = btn

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 16)
		label.Position = UDim2.new(0, 0, 1, -12)
		label.BackgroundTransparency = 1
		label.Text = labelText
		label.TextSize = 12
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = textColor
		label.Parent = btn

		local initialColor = fillColor
		btn.MouseEnter:Connect(function()
			if not activateCallback then return end
			TweenService:Create(btn.UIStroke, TweenInfo.new(0.1), {Thickness = 4, Color = Color3.fromRGB(180,180,180)}):Play()
		end)
		btn.MouseLeave:Connect(function()
			if not activateCallback then return end
			TweenService:Create(btn.UIStroke, TweenInfo.new(0.1), {Thickness = 3, Color = ringColor or Color3.fromRGB(255,0,0)}):Play()
		end)

		if activateCallback then
			btn.Activated:Connect(activateCallback)
		end
		return btn
	end

	showCategories = function()
		centralFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
		itemsContainer.Visible = false
		categoriesContainer.Visible = true
		clearChildren(categoriesContainer)

		local cats = currentContext and currentContext.categories
		if type(cats) ~= "table" then return end

		local count = #cats
		for i = 1, count do
			local unlocked = cats[i]
			local label = GameConfig.CATEGORIES[i] or ("Category " .. i)
			if i == 2 then label = (Players.LocalPlayer.Team and Players.LocalPlayer.Team.Name == GameConfig.Teams[2].Name) and "AT-RT" or "Droid Spider" end
			if i == 4 then label = (Players.LocalPlayer.Team and Players.LocalPlayer.Team.Name == GameConfig.Teams[2].Name) and "AT-ST / LaserTank / AT-TE" or "Supertank / AAT / Homing / Hailfire" end
			-- Team-specific icons for categories (prefer IconTables)
			local team = Players.LocalPlayer.Team and Players.LocalPlayer.Team.Name or ""
			local iconKey
			local fromTable = IconTables and IconTables.Category and IconTables.Category[i]
			if fromTable then
				if team == GameConfig.Teams[2].Name and fromTable.rep then iconKey = fromTable.rep
				elseif team == GameConfig.Teams[1].Name and fromTable.cis then iconKey = fromTable.cis
				else iconKey = fromTable.generic end
			end
			if not unlocked then
				iconKey = "Images/Unknown"
			elseif not iconKey then
				if i == 1 then
					iconKey = "Images/Ground"
				elseif i == 2 then
					iconKey = (team == GameConfig.Teams[2].Name) and "Images/Rep_Support_SmallAir" or (team == GameConfig.Teams[1].Name) and "Images/CIS_Support_SmallAir" or "Images/Unknown"
				elseif i == 3 then
					iconKey = (team == GameConfig.Teams[2].Name) and "Images/Rep_Barracks" or (team == GameConfig.Teams[1].Name) and "Images/CIS_Barracks" or "Images/Unknown"
				elseif i == 4 then
					iconKey = (team == GameConfig.Teams[2].Name) and "Images/Rep_Support_Air" or (team == GameConfig.Teams[1].Name) and "Images/CIS_Support_Air" or "Images/Unknown"
				elseif i == 5 then
					iconKey = "Images/Shield"
				elseif i == 6 then
					iconKey = "Images/RayShieldGen"
				elseif i == 7 then
					iconKey = "Torpedo"
				elseif i == 8 then
					iconKey = "Images/Extra"
				else
					iconKey = "Images/Unknown"
				end
			end
			local iconId = (iconKey and IconAssetIds[iconKey]) and ("rbxassetid://" .. tostring(IconAssetIds[iconKey])) or "rbxassetid://0"

			-- Background fill = team color when unlocked, muted when locked
			local teamId = (Players.LocalPlayer.Team and ((Players.LocalPlayer.Team.Name == GameConfig.Teams[2].Name) and GameConfig.TEAM.REP or (Players.LocalPlayer.Team.Name == GameConfig.Teams[1].Name) and GameConfig.TEAM.CIS or nil))
			local fillColor = Color3.fromRGB(90, 40, 40)
			if unlocked then
				if teamId == GameConfig.TEAM.REP then fillColor = Color3.fromRGB(0, 112, 255) else fillColor = Color3.fromRGB(255, 30, 30) end
			end
			local textColor = unlocked and Color3.new(1,1,1) or Color3.fromRGB(150,150,150)

			local callback = nil
			if unlocked then
				local idx = i
				callback = function()
					centerLabel.Text = label
					centerIcon.Image = iconId
					showItems(idx)
				end
			end

			createRadialButton(categoriesContainer, i, count, label, iconId, fillColor, textColor, callback)
		end
		centerLabel.Text = ""
		centerIcon.Image = "rbxassetid://0"
	end

	showItems = function(catIndex)
		centralFrame.BackgroundColor3 = Color3.fromRGB(40,40,40)
		categoriesContainer.Visible = false
		itemsContainer.Visible = true
		clearChildren(itemsContainer)

		local buildingsByCat = currentContext and currentContext.buildings
		local list = (type(buildingsByCat) == "table") and buildingsByCat[catIndex] or {}

		local typeCounts = (currentContext and currentContext.typeCounts) or {}
		local typeLimits = (currentContext and currentContext.typeLimits) or {}
		local costs = (currentContext and currentContext.costs) or {}
		local nameToType = (currentContext and currentContext.nameToType) or {}
		local nameToBuilt = (currentContext and currentContext.nameToBuilt) or {}
		local nameToLimit = (currentContext and currentContext.nameToLimit) or {}
		local currency = (currentContext and currentContext.currency) or "Bits"

		local count = #list
		for idx, name in ipairs(list) do
			-- Per-faction icon resolution
			local team = Players.LocalPlayer.Team and Players.LocalPlayer.Team.Name or ""
			local factionPrefix = (team == GameConfig.Teams[2].Name) and "Images/Rep_" or (team == GameConfig.Teams[1].Name) and "Images/CIS_" or "Images/"
			local iconKey = (IconTables and IconTables.Building and IconTables.Building[name]) or (factionPrefix .. name)
			if not IconAssetIds[iconKey] then iconKey = "Images/" .. name end
			if not IconAssetIds[iconKey] then
				-- Special fallbacks by typeKey
				local tk = nameToType[name]
				if tk == "RayShield_Normal" or tk == "RayShield_Silver" then
					iconKey = "Images/RayShieldGen"
				elseif tk == "RayShield_Gold" then
					iconKey = "Images/RayShieldGen"
				elseif tk == "Shield_Gold" or tk == "Shield_Silver" or tk == "Shield_Normal" then
					iconKey = (team == GameConfig.Teams[2].Name) and "Images/Rep_ShieldGen_" .. (tk:match("_(%w+)$") or "Normal") or "Images/CIS_ShieldGen_" .. (tk:match("_(%w+)$") or "Normal")
				elseif tk == "Torpedo_Normal" then
					iconKey = "Torpedo"
				elseif name:find("BitWell") then
					iconKey = "Images/BitWell"
				end
			end
			local iconId = IconAssetIds[iconKey] and ("rbxassetid://" .. tostring(IconAssetIds[iconKey])) or "rbxassetid://0"

			local typeKey = nameToType[name]
			local built = nameToBuilt[name]
			if built == nil then built = (typeKey and typeCounts[typeKey]) or 0 end
			local limit = nameToLimit[name]
			if limit == nil then limit = (typeKey and typeLimits[typeKey]) or 0 end
			local cost = (costs[name] or 0)

			-- Tier ring color
			local ringColor = nil
			if name:find("_Gold") then ringColor = Color3.fromRGB(212, 175, 55)
			elseif name:find("_Silver") then ringColor = Color3.fromRGB(180, 180, 180)
			else
				if Players.LocalPlayer.Team and Players.LocalPlayer.Team.Name == GameConfig.Teams[2].Name then
					ringColor = Color3.fromRGB(0, 112, 255)
				else
					ringColor = Color3.fromRGB(255, 30, 30)
				end
			end

			local btn = createRadialButton(
				itemsContainer, idx, math.max(count, 1), string.format("%s (%d %s) %s", name, cost, currency, (limit>0 and string.format("%d/%d", built, limit) or "")), iconId,
				Color3.fromRGB(60, 120, 200), Color3.new(1,1,1),
				function()
					-- Determine variant for shared-model categories
					local variant = nil
					if catIndex == 3 then
						-- Barracks: Rocket vs Normal by name
						if string.find(name, "Rocket") then variant = "Rocket" else variant = "Normal" end
					elseif catIndex == 4 then
						-- Air support variants (CIS: Supertank/AAT/HomingSpider/Hailfire; REP: ATST/LaserTank/ATTE)
						local map = { Supertank=true, AAT=true, HomingSpider=true, Hailfire=true, ATST=true, ["AT-ST"]=true, LaserTank=true, ATTE=true, ["AT-TE"]=true }
						for key,_ in pairs(map) do if string.find(name, key) then variant = key break end end
					end
					RE_Buy:FireServer({ coreId = currentContext.coreId, plotLetter = currentContext.plotLetter, buildingName = name, variant = variant })
					gui.Enabled = false
				end,
				ringColor
			)
			if btn then
				btn.MouseEnter:Connect(function()
					infoLabel.Text = string.format("%s\nCost: %d %s\nBuilt: %d/%s", name, cost, currency, built, (limit>0 and tostring(limit) or "∞"))
					infoBox.Visible = true
				end)
				btn.MouseLeave:Connect(function()
					infoBox.Visible = false
				end)
			end
		end
	end

	-- Navigation via keyboard/controller only

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe or not gui.Enabled then return end
		if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape then
			if itemsContainer.Visible then
				showCategories()
			else
				gui.Enabled = false
			end
		end
	end)

	-- << MOVED HERE! >> Connect events that depend on the gui object *after* it's created.
	-- NOTE: ProximityPromptService already defined at top of file
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			-- Menu opened: hide prompts
			ProximityPromptService.Enabled = false
		else
			-- Menu closed: show prompts and clear blur
			ProximityPromptService.Enabled = true
			toggleBlur(false)
		end
	end)

	gui.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			-- UI is being destroyed: clean up blur and re-enable prompts
			if blurEffect and blurEffect.Parent then
				blurEffect:Destroy()
				blurEffect = nil
			end
			ProximityPromptService.Enabled = true
		end
	end)

	return gui
end

-- Server tells us to open the build menu with data payload
RE_Open.OnClientEvent:Connect(function(payload)
	currentContext = {
		coreId = payload.coreId,
		plotLetter = payload.plotLetter,
		categories = payload.categories or {},
		buildings = payload.buildings or {},
		typeCounts = payload.typeCounts or {},
		typeLimits = payload.typeLimits or {},
		costs = payload.costs or {},
		nameToType = payload.nameToType or {},
		nameToBuilt = payload.nameToBuilt or {},
		nameToLimit = payload.nameToLimit or {},
		currency = payload.currency or "Bits",
	}

	local g = ensureGui()
	if g then
		g.Enabled = true
		ProximityPromptService.Enabled = false
		toggleBlur(true)
		showCategories()
	end
end)