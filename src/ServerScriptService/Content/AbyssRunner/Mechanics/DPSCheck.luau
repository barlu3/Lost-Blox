--!strict
-- Abyss mechanic: the boss must be pushed to a HP threshold within time_limit,
-- or the room wipes with a "Raid Enrage" message.

local DPSCheck = {}

-- world: { getBossHpFraction(): number }. config: { threshold, time_limit }
function DPSCheck.run(world: any, config: any, onComplete: (boolean) -> ())
	task.delay(config.time_limit, function()
		onComplete(world.getBossHpFraction() <= config.threshold)
	end)
end

return DPSCheck
