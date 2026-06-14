--!strict
-- Pure server-side damage resolution. No Roblox-instance requires so it stays
-- unit-testable. The caller injects all state (stats, skill, modifiers, roll fn);
-- this module reads nothing from the client and holds no state of its own.

local DamageCalculator = {}

export type Stats = {
	baseAttack: number,
	critChance: number,
	critDamage: number,
}

export type Skill = {
	damageMultiplier: number,
}

-- Engraving/tripod output. Defaults to no-op so Q1 (no engravings) needs nothing.
export type Modifiers = {
	damageAdd: number,
	damageMul: number,
	critRate: number,
	critDamage: number,
}

export type Result = {
	damage: number,
	didCrit: boolean,
}

local NO_MODIFIERS: Modifiers = { damageAdd = 0, damageMul = 0, critRate = 0, critDamage = 0 }
DamageCalculator.NO_MODIFIERS = NO_MODIFIERS

-- damage = (base_attack * skill.damageMultiplier * (1 + damageMul) + damageAdd) * crit_modifier
-- crit_modifier = if roll < crit_chance then (1 + crit_damage) else 1
-- rollFn returns a value in [0, 1); inject a seeded Random for deterministic tests.
function DamageCalculator.calculate(
	stats: Stats,
	skill: Skill,
	modifiers: Modifiers?,
	rollFn: (() -> number)?
): Result
	local mod = modifiers or NO_MODIFIERS
	local roll = rollFn or math.random

	local critChance = math.clamp(stats.critChance + mod.critRate, 0, 1)
	local critDamage = stats.critDamage + mod.critDamage

	local didCrit = roll() < critChance
	local critModifier = if didCrit then (1 + critDamage) else 1

	local base = stats.baseAttack * skill.damageMultiplier * (1 + mod.damageMul) + mod.damageAdd
	return {
		damage = base * critModifier,
		didCrit = didCrit,
	}
end

return DamageCalculator
