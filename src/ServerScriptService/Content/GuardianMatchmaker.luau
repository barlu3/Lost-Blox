-- Guardian Raid matchmaking. Queue entries live in a MemoryStore sorted map
-- (transient, with a TTL) so disconnected players expire instead of blocking
-- matches. A polling loop groups ready players (GuardianRaid.groupByILvl) and
-- teleports each party to the raid place.
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local GuardianRaid = require(script.Parent.GuardianRaid)

local GuardianMatchmaker = {}

local QUEUE_NAME = "guardian_queue"
local POLL_INTERVAL = 10
local ENTRY_TTL = 300 -- 5 min; expires disconnected queuers
local MAX_PARTY = 4
local ILVL_RANGE = 100
-- Published separately; store the id in a server config in production.
local RAID_PLACE_ID = 0

local queue = MemoryStoreService:GetSortedMap(QUEUE_NAME)

function GuardianMatchmaker.enqueue(player: Player, iLvl: number, bossId: string)
	pcall(function()
		queue:SetAsync(tostring(player.UserId), { userId = player.UserId, iLvl = iLvl, bossId = bossId }, ENTRY_TTL)
	end)
end

function GuardianMatchmaker.dequeue(userId: number)
	pcall(function()
		queue:RemoveAsync(tostring(userId))
	end)
end

local function readQueue(): { GuardianRaid.QueueEntry }
	local entries = {}
	local ok, items = pcall(function()
		return queue:GetRangeAsync(Enum.SortDirection.Ascending, 100)
	end)
	if ok and items then
		for _, item in items do
			table.insert(entries, item.value)
		end
	end
	return entries
end

local function teleportParty(party: { GuardianRaid.QueueEntry }, bossId: string)
	local players = {}
	for _, entry in party do
		local player = Players:GetPlayerByUserId(entry.userId)
		if player then
			table.insert(players, player)
			GuardianMatchmaker.dequeue(entry.userId)
		end
	end
	if #players == 0 then
		return
	end
	local options = Instance.new("TeleportOptions")
	-- player count is locked here so HP scaling uses the entered count.
	options:SetTeleportData({ bossId = bossId, playerCount = #players })
	pcall(function()
		TeleportService:TeleportAsync(RAID_PLACE_ID, players, options)
	end)
end

function GuardianMatchmaker.start()
	task.spawn(function()
		while true do
			task.wait(POLL_INTERVAL)
			local entries = readQueue()
			if #entries > 0 then
				local parties = GuardianRaid.groupByILvl(entries, MAX_PARTY, ILVL_RANGE)
				for _, party in parties do
					-- bossId carried on each entry; use the first member's.
					local bossId = (party[1] :: any).bossId or "default"
					teleportParty(party, bossId)
				end
			end
		end
	end)
end

return GuardianMatchmaker
