--!strict
-- Pure honing math: success probability with a pity system. attempt() never
-- mutates its input and never touches the profile, so a caller can compute the
-- outcome and then commit materials + result in a single atomic write.
--
-- The caller sets math.randomseed (or injects the roll) for determinism in tests;
-- this module never seeds RNG itself.

local HoningCalculator = {}

HoningCalculator.MAX_PITY = 10

-- Per-tier pity increment: higher tiers gain less per failure, so pity takes
-- longer to matter.
HoningCalculator.PITY_INCREMENT = { [0] = 0.05, [1] = 0.04, [2] = 0.03 }

-- P_BASE[tier][level] base success chance. Curves downward as level rises.
HoningCalculator.P_BASE = {
	[0] = { [1] = 0.80, [2] = 0.70, [3] = 0.60, [4] = 0.50, [5] = 0.40, [6] = 0.35, [7] = 0.30, [8] = 0.25, [9] = 0.20, [10] = 0.15 },
	[1] = { [1] = 0.60, [2] = 0.50, [3] = 0.40, [4] = 0.30, [5] = 0.25, [6] = 0.20, [7] = 0.18, [8] = 0.15, [9] = 0.12, [10] = 0.10 },
	[2] = { [1] = 0.40, [2] = 0.30, [3] = 0.22, [4] = 0.18, [5] = 0.15, [6] = 0.12, [7] = 0.10, [8] = 0.08, [9] = 0.07, [10] = 0.06 },
}

export type State = {
	tier: number,
	level: number,
	pityCounter: number,
	pityBonus: number,
}

export type Outcome = {
	success: boolean,
	newState: State,
}

-- Effective probability for the next attempt given the accumulated pity bonus.
function HoningCalculator.successProbability(pbase: number, pityBonus: number): number
	return math.min(pbase + pityBonus, 1.0)
end

-- Fully parameterized pure attempt. roll is in [0, 1). Returns success + the
-- next state; the input state is untouched.
function HoningCalculator.attempt(state: State, roll: number, pbase: number, pityIncrement: number, maxPity: number): Outcome
	local p = HoningCalculator.successProbability(pbase, state.pityBonus)
	local forced = state.pityCounter >= maxPity
	local success = forced or roll <= p

	if success then
		return {
			success = true,
			newState = { tier = state.tier, level = state.level + 1, pityCounter = 0, pityBonus = 0 },
		}
	end
	return {
		success = false,
		newState = {
			tier = state.tier,
			level = state.level,
			pityCounter = state.pityCounter + 1,
			pityBonus = state.pityBonus + pityIncrement,
		},
	}
end

-- Convenience wrapper that looks up pbase/pityIncrement from the design tables.
function HoningCalculator.attemptForItem(state: State, roll: number): Outcome
	local tierTable = HoningCalculator.P_BASE[state.tier]
	local pbase = (tierTable and tierTable[state.level]) or 0.05 -- floor for unmapped high levels
	local inc = HoningCalculator.PITY_INCREMENT[state.tier] or 0.03
	return HoningCalculator.attempt(state, roll, pbase, inc, HoningCalculator.MAX_PITY)
end

-- Pure material check: every required id is owned in sufficient quantity.
function HoningCalculator.canAfford(required: { [string]: number }, owned: { [string]: number }): boolean
	for id, qty in required do
		if (owned[id] or 0) < qty then
			return false
		end
	end
	return true
end

return HoningCalculator
