-- Single point of contact for player persistence. All profile reads/writes
-- go through here; nothing else in the codebase touches ProfileService directly.
--
-- NOTE: Place the ProfileService module at src/ServerScriptService/Save/ProfileService.luau
-- (download from https://github.com/MadStudioRoblox/ProfileService).
local Players = game:GetService("Players")
local ProfileService = require(script.Parent.ProfileService)
local ProfileTemplate = require(script.Parent.ProfileTemplate)

local STORE_KEY = "PlayerData_v1"

local ProfileStore = ProfileService.GetProfileStore(STORE_KEY, ProfileTemplate)
local profiles: { [Player]: any } = {}

local function onPlayerAdded(player: Player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)

	if profile == nil then
		-- Another server holds the session lock, or DataStore is unavailable.
		player:Kick("Unable to load your save data. Please rejoin in a moment.")
		return
	end

	-- Guard: player left while LoadProfileAsync was yielding.
	if not player:IsDescendantOf(game) then
		profile:Release()
		return
	end

	profile:Reconcile()

	-- Set creation timestamp once on first ever load (template default is 0).
	if profile.Data.createdAt == 0 then
		profile.Data.createdAt = os.time()
	end

	profiles[player] = profile
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile ~= nil then
		profile:Save()
		profile:Release()
		profiles[player] = nil
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players who joined before this module was required.
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

local ProfileManager = {}

function ProfileManager.GetData(player: Player): any?
	local profile = profiles[player]
	return if profile ~= nil then profile.Data else nil
end

function ProfileManager.SetData(player: Player, key: string, value: any)
	local profile = profiles[player]
	if profile ~= nil then
		profile.Data[key] = value
	end
end

return ProfileManager
