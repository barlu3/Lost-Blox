--!strict
-- Single source of truth for a character's combat stats. Sums base stats, all
-- equipped item contributions, and engraving modifiers into a CharacterStats
-- table that DamageCalculator reads. Pure and unit-testable.

local StatRecomputer = {}

local GEAR_SLOTS = { "weapon", "head", "chest", "legs" }
local ACCESSORY_SLOTS = { "accessory1", "accessory2" }

export type Item = { id: string, quality: number, iLvl: number }
export type Equipped = { [string]: Item? }
export type BaseStats = {
	baseAttack: number,
	critChance: number,
	critDamage: number,
	maxHealth: number,
	iLvl: number,
	resource: number?,
	resourceType: string?,
}
export type Mods = { critRate: number, critDamage: number, damageAdd: number, damageMul: number }

local NO_MODS: Mods = { critRate = 0, critDamage = 0, damageAdd = 0, damageMul = 0 }

local function itemAttack(item: Item): number
	-- Gear contributes mostly via item level, with quality as a finishing bonus.
	return item.iLvl * 0.5 + item.quality * 0.2
end

function StatRecomputer.recompute(base: BaseStats, equipped: Equipped, mods: Mods?): any
	local m = mods or NO_MODS
	local attack = base.baseAttack
	local totalGearILvl, gearCount = 0, 0

	for _, slot in GEAR_SLOTS do
		local item = equipped[slot]
		if item then
			attack += itemAttack(item)
			totalGearILvl += item.iLvl
			gearCount += 1
		end
	end
	-- Accessories add attack but do not count toward item level (LA convention).
	for _, slot in ACCESSORY_SLOTS do
		local item = equipped[slot]
		if item then
			attack += item.quality * 0.2
		end
	end

	local iLvl = if gearCount > 0 then totalGearILvl / gearCount else base.iLvl

	return {
		baseAttack = attack,
		critChance = base.critChance + m.critRate,
		critDamage = base.critDamage + m.critDamage,
		maxHealth = base.maxHealth,
		iLvl = iLvl,
		resource = base.resource or 0,
		resourceType = base.resourceType or "fury",
	}
end

return StatRecomputer
