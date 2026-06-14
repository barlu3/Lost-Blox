-- TASK_Q4_01 acceptance: ColorMatch deals lethal damage to wrong-tile players
-- exactly at detonation_time (mocked task.delay).
local Harness = require("../Harness.luau")
local ColorMatch = require("../../src/ServerScriptService/Content/AbyssRunner/Mechanics/ColorMatch.luau")

return function()
	describe("ColorMatch", function()
		it("schedules detonation at detonation_time and kills only wrong-tile players", function()
			local safe = Harness.makeSignal and "red" or "red"
			local lethal = {}
			local world = {
				getSafeColor = function()
					return "red"
				end,
				getPlayers = function()
					return { "p_safe", "p_wrong" }
				end,
				getPlayerTile = function(p)
					return if p == "p_safe" then "red" else "blue"
				end,
				applyLethal = function(p)
					lethal[p] = true
				end,
			}

			local completed: boolean? = nil
			ColorMatch.run(world, { detonation_time = 6 }, function(success)
				completed = success
			end)

			-- Damage must not resolve before detonation.
			expect(#Harness.scheduled).to.equal(1)
			expect(Harness.scheduled[1].t).to.be.near(6, 0.1)
			expect(lethal.p_wrong).never.to.be.ok()

			Harness.flushDelays()
			expect(lethal.p_wrong).to.equal(true)
			expect(lethal.p_safe).never.to.be.ok()
			expect(completed).to.equal(true) -- one survivor -> not a wipe
			local _ = safe
		end)

		it("reports a wipe when no one is on the safe tile", function()
			local world = {
				getSafeColor = function()
					return "red"
				end,
				getPlayers = function()
					return { "a", "b" }
				end,
				getPlayerTile = function()
					return "blue"
				end,
				applyLethal = function() end,
			}
			local completed: boolean? = nil
			ColorMatch.run(world, { detonation_time = 4 }, function(success)
				completed = success
			end)
			Harness.flushDelays()
			expect(completed).to.equal(false)
		end)
	end)
end
