--!strict
-- Abyss mechanic: several pillars appear and must all be destroyed within
-- time_limit seconds, or the room wipes.

local PillarPhase = {}

-- world: { getPillarsRemaining(): number }. config: { time_limit, pillar_count }
function PillarPhase.run(world: any, config: any, onComplete: (boolean) -> ())
	task.delay(config.time_limit, function()
		onComplete(world.getPillarsRemaining() == 0)
	end)
end

return PillarPhase
