--!strict
-- Seasonal Battle Pass: XP accrual, tier calculation, reward-claim tracking, and
-- season rollover. Pure core (tier math, claim bookkeeping) is unit-testable; the
-- runtime layer wires XP sources and gamepass-gated premium grants.

local BattlePass = {}

export type Data = {
	season: string,
	xp: number,
	tier: number,
	premiumUnlocked: boolean,
	claimedTiers: { number },
}

-- Current tier = count of cumulative thresholds the total XP has reached. A
-- linear scan (correctness first), as the timeline specifies.
function BattlePass.tierForXp(thresholds: { number }, totalXp: number): number
	local tier = 0
	for _, threshold in thresholds do
		if totalXp >= threshold then
			tier += 1
		else
			break
		end
	end
	return tier
end

-- Adds XP and recomputes tier. Returns the new tier.
function BattlePass.addXp(data: Data, amount: number, thresholds: { number }): number
	data.xp += amount
	data.tier = BattlePass.tierForXp(thresholds, data.xp)
	return data.tier
end

local function isClaimed(claimedTiers: { number }, tier: number): boolean
	for _, t in claimedTiers do
		if t == tier then
			return true
		end
	end
	return false
end

-- Tiers 1..currentTier that have not been granted yet (prevents re-granting on
-- profile reload).
function BattlePass.unclaimedTiers(data: Data): { number }
	local out = {}
	for tier = 1, data.tier do
		if not isClaimed(data.claimedTiers, tier) then
			table.insert(out, tier)
		end
	end
	return out
end

function BattlePass.claimTier(data: Data, tier: number)
	if not isClaimed(data.claimedTiers, tier) then
		table.insert(data.claimedTiers, tier)
	end
end

-- Premium-track rewards require the gamepass; free-track rewards always grant.
function BattlePass.canGrant(reward: { track: string? }, data: Data): boolean
	if reward.track == "premium" then
		return data.premiumUnlocked
	end
	return true
end

-- Archives the current season and returns fresh data for the next one. A new
-- season is a new pass: premium must be re-purchased.
function BattlePass.rollover(data: Data, nextSeason: string): { archive: any, newData: Data }
	return {
		archive = { season = data.season, xp = data.xp, tier = data.tier, claimedTiers = data.claimedTiers },
		newData = {
			season = nextSeason,
			xp = 0,
			tier = 0,
			premiumUnlocked = false,
			claimedTiers = {},
		},
	}
end

function BattlePass.newData(season: string): Data
	return { season = season, xp = 0, tier = 0, premiumUnlocked = false, claimedTiers = {} }
end

return BattlePass
