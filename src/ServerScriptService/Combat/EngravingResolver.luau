--!strict
-- Resolves a player's engraving book into a ModifierTable that DamageCalculator
-- applies. Pure function, no side effects, no Roblox-instance requires — so it is
-- directly unit-testable. Engraving definitions are injected (or set once via
-- setDefinitions for runtime use).

local EngravingResolver = {}

export type Tier = {
	threshold: number,
	type: string, -- "damage_add" | "damage_mul" | "crit_rate" | "crit_damage"
	value: number,
}

export type Def = {
	id: string,
	tiers: { Tier },
	filter: string?, -- if set, the engraving only applies to this skillId
}

export type Modifiers = {
	damageAdd: number,
	damageMul: number,
	critRate: number,
	critDamage: number,
}

local definitions: { [string]: Def } = {}

function EngravingResolver.setDefinitions(defs: { [string]: Def })
	definitions = defs
end

-- Highest activated tier for a point total: the last tier whose threshold is met.
-- Thresholds may be negative (penalty engravings), so scan all and keep the max
-- threshold that is <= points.
local function activeTier(def: Def, points: number): Tier?
	local best: Tier? = nil
	for _, tier in def.tiers do
		if points >= tier.threshold then
			if best == nil or tier.threshold > best.threshold then
				best = tier
			end
		end
	end
	return best
end

-- engravingBook: { [engravingId]: points }. defs defaults to the registry.
function EngravingResolver.resolve(engravingBook: { [string]: number }, skillId: string?, defs: { [string]: Def }?): Modifiers
	local source = defs or definitions
	local damageAdd = 0
	local damageMulProduct = 1 -- chained: (1+a)*(1+b)... then subtract 1
	local critRate = 0
	local critDamage = 0

	for id, points in engravingBook do
		local def = source[id]
		if def and (def.filter == nil or def.filter == skillId) then
			local tier = activeTier(def, points)
			if tier then
				if tier.type == "damage_add" then
					damageAdd += tier.value
				elseif tier.type == "damage_mul" then
					damageMulProduct *= (1 + tier.value)
				elseif tier.type == "crit_rate" then
					critRate += tier.value
				elseif tier.type == "crit_damage" then
					critDamage += tier.value
				end
			end
		end
	end

	return {
		damageAdd = damageAdd,
		damageMul = damageMulProduct - 1,
		critRate = math.min(critRate, 1.0), -- crit_rate capped at 1.0 total
		critDamage = critDamage,
	}
end

return EngravingResolver
