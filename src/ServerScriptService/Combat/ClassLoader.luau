-- Loads every class JSON from ReplicatedStorage/Configs/Classes at server start
-- and registers each skill into SkillRegistry. This is the bridge between the
-- designer-authored JSON (snake_case) and the runtime registry (camelCase).
--
-- Rojo maps each *.json to a ModuleScript that returns the decoded table.
-- "Hot reload" means class data is fresh whenever a new server starts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillRegistry = require(script.Parent.SkillRegistry)

local ClassLoader = {}
ClassLoader._classes = {} :: { [string]: any }

local function mapSkill(skill: any)
	return {
		id = skill.id,
		cooldown = skill.cooldown,
		range = skill.range,
		damageMultiplier = skill.damage_multiplier,
		resourceCost = skill.resource_cost,
		targetType = skill.target_type,
		aoeRadius = skill.aoe_radius,
		key = skill.key,
		tripod = skill.tripod, -- carried through for TripodResolver
	}
end

function ClassLoader.loadAll()
	local configs = ReplicatedStorage:WaitForChild("Configs")
	local classesFolder = configs:WaitForChild("Classes")

	for _, module in classesFolder:GetChildren() do
		if module:IsA("ModuleScript") then
			local ok, classDef = pcall(require, module)
			if ok and type(classDef) == "table" and classDef.id then
				ClassLoader._classes[classDef.id] = classDef
				for _, skill in classDef.skills do
					SkillRegistry.register(classDef.id, mapSkill(skill))
				end
			else
				warn("ClassLoader: failed to load class module: " .. module.Name)
			end
		end
	end
end

function ClassLoader.getClass(classId: string): any?
	return ClassLoader._classes[classId]
end

function ClassLoader.getResourceType(classId: string): string?
	local class = ClassLoader._classes[classId]
	return class and class.resource_type
end

function ClassLoader.getResourceMax(classId: string): number?
	local class = ClassLoader._classes[classId]
	return class and class.resource_max
end

return ClassLoader
