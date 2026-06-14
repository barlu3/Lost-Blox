--!strict
-- Applies a skill's equipped tripod to a copy of its definition. Pure: the
-- SkillRegistry definitions are immutable, so this never mutates the input — it
-- returns a modified clone (or the original when no tripod is equipped).

local TripodResolver = {}

export type Option = { id: string, type: "damage" | "cooldown" | "aoe_radius", value: number }
export type Tripod = { options: { Option } }
export type SkillDef = {
	cooldown: number,
	damageMultiplier: number,
	aoeRadius: number?,
	tripod: Tripod?,
	[string]: any,
}

local function findOption(tripod: Tripod, optionId: string): Option?
	for _, option in tripod.options do
		if option.id == optionId then
			return option
		end
	end
	return nil
end

function TripodResolver.resolve(skillDef: SkillDef, equippedTripodId: string?): SkillDef
	if equippedTripodId == nil or skillDef.tripod == nil then
		return skillDef
	end
	local option = findOption(skillDef.tripod, equippedTripodId)
	if option == nil then
		return skillDef
	end

	local copy = table.clone(skillDef)
	if option.type == "damage" then
		copy.damageMultiplier = skillDef.damageMultiplier * (1 + option.value)
	elseif option.type == "cooldown" then
		copy.cooldown = skillDef.cooldown * (1 + option.value)
	elseif option.type == "aoe_radius" then
		copy.aoeRadius = (skillDef.aoeRadius or 0) * (1 + option.value)
	end
	return copy
end

return TripodResolver
