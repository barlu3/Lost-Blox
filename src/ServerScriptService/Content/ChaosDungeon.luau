--!strict
-- Pure Chaos Dungeon scoring, kill-chain, phase, and iLvl-gate logic. Phase
-- spawning, timers, and loot I/O live in ChaosDungeonRunner; these helpers stay
-- testable.

local ChaosDungeon = {}

ChaosDungeon.TIME_BONUS_PER_SEC = 10
ChaosDungeon.KILL_CHAIN_BONUS = 50
ChaosDungeon.CHAIN_WINDOW = 5 -- seconds within which kills chain

export type TierConfig = { tier: number, ilvl_min: number, ilvl_max: number }

-- iLvl gate enforced on entry (not just on loot). Inclusive band.
function ChaosDungeon.canEnter(playerILvl: number, config: TierConfig): boolean
	return playerILvl >= config.ilvl_min and playerILvl <= config.ilvl_max
end

function ChaosDungeon.timeBonus(remainingSeconds: number): number
	return math.max(0, remainingSeconds) * ChaosDungeon.TIME_BONUS_PER_SEC
end

-- Phase 1 ends the instant the last mob dies (the runner fires this off an
-- event, not a poll).
function ChaosDungeon.isPhaseComplete(mobCount: number): boolean
	return mobCount <= 0
end

-- ── Kill-chain score tracker ────────────────────────────────────────────────
export type ScoreState = {
	score: number,
	chainBonus: number,
	lastKillTime: number?,
}

function ChaosDungeon.newScore(base: number?): ScoreState
	return { score = base or 0, chainBonus = 0, lastKillTime = nil }
end

-- Registers a kill at time `now`. A kill within CHAIN_WINDOW of the previous one
-- adds KILL_CHAIN_BONUS; a longer gap resets the chain bonus to 0.
function ChaosDungeon.registerKill(state: ScoreState, now: number)
	if state.lastKillTime ~= nil and (now - state.lastKillTime) <= ChaosDungeon.CHAIN_WINDOW then
		state.chainBonus += ChaosDungeon.KILL_CHAIN_BONUS
		state.score += ChaosDungeon.KILL_CHAIN_BONUS
	else
		state.chainBonus = 0
	end
	state.lastKillTime = now
end

-- Adds the end-of-phase time bonus into the running score.
function ChaosDungeon.addTimeBonus(state: ScoreState, remainingSeconds: number)
	state.score += ChaosDungeon.timeBonus(remainingSeconds)
end

return ChaosDungeon
