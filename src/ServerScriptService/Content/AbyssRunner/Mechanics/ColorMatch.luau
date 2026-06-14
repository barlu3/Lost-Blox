--!strict
-- Abyss mechanic: floor tiles light up; one color is safe. Players not on the
-- safe tile at detonation take lethal damage. Timing uses task.delay for
-- precision (mockable in tests). run() resolves success via onComplete.

local ColorMatch = {}

-- world: { getPlayers, getPlayerTile(player), getSafeColor, applyLethal(player) }
-- config: { detonation_time: number }
function ColorMatch.run(world: any, config: any, onComplete: (boolean) -> ())
	task.delay(config.detonation_time, function()
		local safe = world.getSafeColor()
		local survivors = 0
		for _, player in world.getPlayers() do
			if world.getPlayerTile(player) == safe then
				survivors += 1
			else
				world.applyLethal(player)
			end
		end
		onComplete(survivors > 0)
	end)
end

return ColorMatch
