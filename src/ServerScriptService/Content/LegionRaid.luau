--!strict
-- Pure Legion Raid logic: weekly lockout keys, entry gating, and mechanic timer
-- drift measurement. Gate orchestration and TeleportService live in
-- RaidController; HP scaling reuses GuardianRaid.scaledHp (extended to 8).

local LegionRaid = {}

LegionRaid.SECONDS_PER_WEEK = 604800
LegionRaid.MAX_PARTY = 8
LegionRaid.DRIFT_THRESHOLD = 0.05 -- 50ms

-- Weekly bucket aligned to Monday (epoch 1970-01-01 was a Thursday, +4 days).
function LegionRaid.weekIndex(timestamp: number): number
	return math.floor((timestamp + 4 * 86400) / LegionRaid.SECONDS_PER_WEEK)
end

function LegionRaid.lockoutKey(weekIndex: number, raidId: string, gate: number): string
	return string.format("W%d:%s:%d", weekIndex, raidId, gate)
end

function LegionRaid.isLocked(weeklyLockout: { [string]: boolean }, weekIndex: number, raidId: string, gate: number): boolean
	return weeklyLockout[LegionRaid.lockoutKey(weekIndex, raidId, gate)] == true
end

-- Records a gate clear for the week. Locked players may still enter to assist;
-- the caller withholds loot when isLocked is true.
function LegionRaid.recordClear(weeklyLockout: { [string]: boolean }, weekIndex: number, raidId: string, gate: number)
	weeklyLockout[LegionRaid.lockoutKey(weekIndex, raidId, gate)] = true
end

-- Solo entry is allowed (n = 1); HP scales down. No forced 8-player requirement.
function LegionRaid.canEnter(partySize: number): boolean
	return partySize >= 1 and partySize <= LegionRaid.MAX_PARTY
end

-- Mechanic timers use os.clock(); drift = actual fire time - scheduled fire time.
function LegionRaid.timerDrift(scheduledTime: number, actualTime: number): number
	return actualTime - scheduledTime
end

function LegionRaid.isDriftHigh(drift: number, threshold: number?): boolean
	return math.abs(drift) > (threshold or LegionRaid.DRIFT_THRESHOLD)
end

return LegionRaid
