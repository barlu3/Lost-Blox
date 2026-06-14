--!strict
-- Pure cast-validation logic, factored out of SkillExecutor so the ordering rules
-- are unit-testable without RemoteEvents or a live character. Returns "ok" on a
-- valid cast or a failure reason code. The reason is for server logging only —
-- SkillExecutor never sends it to the client (don't leak validation logic).

local CastValidator = {}

export type Skill = {
	id: string,
	cooldown: number,
	range: number,
	resourceCost: number,
	targetType: "single" | "aoe" | "self",
}

export type CasterState = {
	position: Vector3,
	resource: number,
	-- Map of skillId -> os.clock() timestamp of last successful cast.
	lastCast: { [string]: number },
}

export type TargetState = {
	position: Vector3,
	alive: boolean,
}

export type Reason = "ok" | "no_skill" | "cooldown" | "no_target" | "out_of_range" | "insufficient_resource"

-- Checks run in the spec's order: existence → cooldown → target → range → resource.
function CastValidator.validate(skill: Skill?, caster: CasterState, target: TargetState?, now: number): Reason
	if skill == nil then
		return "no_skill"
	end

	local last = caster.lastCast[skill.id]
	if last ~= nil and (now - last) < skill.cooldown then
		return "cooldown"
	end

	if skill.targetType ~= "self" then
		if target == nil or not target.alive then
			return "no_target"
		end
		local distance = (target.position - caster.position).Magnitude
		if distance > skill.range then
			return "out_of_range"
		end
	end

	if caster.resource < skill.resourceCost then
		return "insufficient_resource"
	end

	return "ok"
end

return CastValidator
