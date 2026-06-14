--!strict
-- Pure Guardian Raid math: party HP scaling, wipe detection, and iLvl-based
-- party grouping. Matchmaking I/O (MemoryStore, TeleportService) lives in
-- GuardianMatchmaker; these helpers stay testable.

local GuardianRaid = {}

-- HP_final = HP_base * (1 + 0.875 * (n - 1)), n locked at teleport time (1..N).
-- NOTE(barlu3): the timeline's worked example claims 41250 for n=4/HP_base=10000,
-- but that contradicts the 0.875 coefficient it states (which gives 36250).
-- Implementing the stated formula; flag for design to reconcile the example.
GuardianRaid.HP_COEFFICIENT = 0.875

function GuardianRaid.scaledHp(hpBase: number, playerCount: number): number
	return hpBase * (1 + GuardianRaid.HP_COEFFICIENT * (playerCount - 1))
end

-- A wipe is every entered player dead. Boss HP is retained (not reset) on wipe;
-- that is the caller's responsibility — this only detects the condition.
function GuardianRaid.isWipe(players: { { alive: boolean } }): boolean
	if #players == 0 then
		return false
	end
	for _, p in players do
		if p.alive then
			return false
		end
	end
	return true
end

export type QueueEntry = { userId: number, iLvl: number, timestamp: number? }

-- Greedily groups queued players into parties of up to maxSize whose iLvl spread
-- stays within ilvlRange. Entries are sorted by iLvl first. Solo parties (size 1)
-- are valid, so a lone queuer never hangs waiting for a full group.
function GuardianRaid.groupByILvl(entries: { QueueEntry }, maxSize: number, ilvlRange: number): { { QueueEntry } }
	local sorted = table.clone(entries)
	table.sort(sorted, function(a, b)
		return a.iLvl < b.iLvl
	end)

	local parties: { { QueueEntry } } = {}
	local current: { QueueEntry } = {}

	for _, entry in sorted do
		if #current == 0 then
			table.insert(current, entry)
		elseif #current < maxSize and (entry.iLvl - current[1].iLvl) <= ilvlRange then
			table.insert(current, entry)
		else
			table.insert(parties, current)
			current = { entry }
		end
	end
	if #current > 0 then
		table.insert(parties, current)
	end
	return parties
end

return GuardianRaid
