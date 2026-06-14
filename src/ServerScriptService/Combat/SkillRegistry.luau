--!strict
-- In-memory registry of all skill definitions, keyed by skillId. Populated at
-- server start by ClassLoader (TASK_Q2_01) from the class JSON files. Pure data
-- store with no Roblox-instance requires, so it is unit-testable directly.

local SkillRegistry = {}

export type SkillDef = {
	id: string,
	cooldown: number,
	range: number,
	damageMultiplier: number,
	resourceCost: number,
	targetType: "single" | "aoe" | "self",
	aoeRadius: number?,
	key: string?,
	classId: string?,
}

local skills: { [string]: SkillDef } = {}

-- Registers one skill under a class. Later registrations of the same id overwrite
-- (server start is a clean slate, so this is the reload path, not a merge).
function SkillRegistry.register(classId: string, def: SkillDef)
	assert(type(def.id) == "string" and def.id ~= "", "skill def needs a non-empty id")
	local copy: SkillDef = table.clone(def)
	copy.classId = classId
	skills[def.id] = copy
end

function SkillRegistry.get(skillId: string): SkillDef?
	return skills[skillId]
end

function SkillRegistry.getByClass(classId: string): { SkillDef }
	local out = {}
	for _, def in skills do
		if def.classId == classId then
			table.insert(out, def)
		end
	end
	return out
end

function SkillRegistry.count(): number
	local n = 0
	for _ in skills do
		n += 1
	end
	return n
end

-- Test/reload helper: drops all registered skills.
function SkillRegistry.clear()
	table.clear(skills)
end

return SkillRegistry
