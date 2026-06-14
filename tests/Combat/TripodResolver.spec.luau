-- TASK_Q4_03 acceptance: tripod modifiers applied to a copy, registry untouched.
require("../Harness.luau")
local TripodResolver = require("../../src/ServerScriptService/Combat/TripodResolver.luau")

local function skill()
	return {
		id = "heavy_strike",
		cooldown = 4.0,
		damageMultiplier = 1.5,
		tripod = {
			options = {
				{ id = "crushing_blow", type = "damage", value = 0.20 },
				{ id = "wide_arc", type = "aoe_radius", value = 0.30 },
				{ id = "rapid_recovery", type = "cooldown", value = -0.15 },
			},
		},
	}
end

return function()
	describe("TripodResolver", function()
		it("crushing_blow raises damage multiplier by 20%", function()
			local resolved = TripodResolver.resolve(skill(), "crushing_blow")
			expect(resolved.damageMultiplier).to.be.near(1.80, 1e-9)
		end)

		it("rapid_recovery shortens cooldown by 15%", function()
			local resolved = TripodResolver.resolve(skill(), "rapid_recovery")
			expect(resolved.cooldown).to.be.near(3.40, 1e-9)
		end)

		it("does not modify the original skill definition", function()
			local original = skill()
			TripodResolver.resolve(original, "crushing_blow")
			expect(original.damageMultiplier).to.be.near(1.5, 1e-9)
			expect(original.cooldown).to.be.near(4.0, 1e-9)
		end)

		it("returns the base definition unchanged with no tripod equipped", function()
			local s = skill()
			local resolved = TripodResolver.resolve(s, nil)
			expect(resolved.damageMultiplier).to.be.near(1.5, 1e-9)
		end)

		it("returns the base definition for an unknown tripod id", function()
			local resolved = TripodResolver.resolve(skill(), "does_not_exist")
			expect(resolved.damageMultiplier).to.be.near(1.5, 1e-9)
		end)
	end)
end
