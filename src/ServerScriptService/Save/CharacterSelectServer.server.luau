-- Server handler for character file-select and creation.
-- Creates RemoteEvents/Functions, validates all input server-side.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Must be false before any PlayerAdded fires so LoadCharacterAsync works.
Players.CharacterAutoLoads = false

local ProfileManager = require(script.Parent.ProfileManager)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MAX_SLOTS = 3
local NAME_MIN = 3
local NAME_MAX = 20
local VALID_CLASSES = { Ironclad = true }

-- ── Remote setup ──────────────────────────────────────────────────────────────

local function getOrCreate(className: string, name: string): any
	local existing = Remotes:FindFirstChild(name)
	if existing then return existing end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = Remotes
	return r
end

local getSlotData: RemoteFunction = getOrCreate("RemoteFunction", "GetSlotData")
local createChar: RemoteEvent = getOrCreate("RemoteEvent", "CreateCharacter")
local deleteChar: RemoteEvent = getOrCreate("RemoteEvent", "DeleteCharacter")
local selectChar: RemoteEvent = getOrCreate("RemoteEvent", "SelectCharacter")
local characterUpdated: RemoteEvent = getOrCreate("RemoteEvent", "CharacterUpdated")
local characterReady: RemoteEvent = getOrCreate("RemoteEvent", "CharacterReady")

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function waitForData(player: Player, timeout: number): any?
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local d = ProfileManager.GetData(player)
		if d then return d end
		task.wait(0.1)
	end
	return nil
end

local function buildSlotResponse(data: any): { any }
	local raw = data.slots or {}
	local out = {}
	for i = 1, MAX_SLOTS do
		local s = raw[i]
		if s and s.name then
			out[i] = { isEmpty = false, name = s.name, class = s.class, createdAt = s.createdAt }
		else
			out[i] = { isEmpty = true }
		end
	end
	return out
end

-- ── Handlers ──────────────────────────────────────────────────────────────────

getSlotData.OnServerInvoke = function(player: Player)
	local data = waitForData(player, 10)
	if not data then return nil end
	return buildSlotResponse(data)
end

createChar.OnServerEvent:Connect(function(player: Player, slotIndex: any, charName: any, charClass: any)
	if type(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > MAX_SLOTS then return end
	if type(charName) ~= "string" or type(charClass) ~= "string" then return end

	charName = charName:match("^%s*(.-)%s*$") -- trim whitespace
	if #charName < NAME_MIN or #charName > NAME_MAX then return end
	if not charName:match("^[%a%d ]+$") then return end
	if not VALID_CLASSES[charClass] then return end

	local data = waitForData(player, 5)
	if not data then return end

	local raw = data.slots or {}
	if raw[slotIndex] and raw[slotIndex].name then return end -- slot occupied

	raw[slotIndex] = { name = charName, class = charClass, createdAt = os.time() }
	ProfileManager.SetData(player, "slots", raw)

	characterUpdated:FireClient(player, buildSlotResponse(data))
end)

deleteChar.OnServerEvent:Connect(function(player: Player, slotIndex: any)
	if type(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > MAX_SLOTS then return end

	local data = waitForData(player, 5)
	if not data then return end

	local raw = data.slots or {}
	raw[slotIndex] = nil
	ProfileManager.SetData(player, "slots", raw)

	if data.characterSlot == slotIndex then
		ProfileManager.SetData(player, "characterSlot", nil)
	end

	characterUpdated:FireClient(player, buildSlotResponse(data))
end)

selectChar.OnServerEvent:Connect(function(player: Player, slotIndex: any)
	if type(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > MAX_SLOTS then return end

	local data = waitForData(player, 5)
	if not data then return end

	local raw = data.slots or {}
	if not raw[slotIndex] or not raw[slotIndex].name then return end

	ProfileManager.SetData(player, "characterSlot", slotIndex)

	-- Spawn the character now that a valid slot is confirmed. CharacterAutoLoads
	-- is false so this is the only place the character ever gets loaded.
	-- TODO(barlu3): apply saved inventory/stats onto character before firing (#TBD)
	player:LoadCharacterAsync()
	characterReady:FireClient(player)
end)
