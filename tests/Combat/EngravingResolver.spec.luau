-- TASK_Q2_03 acceptance: tier selection, multiplicative chaining, crit cap,
-- penalties, and skill filters.
require("../Harness.luau")
local EngravingResolver = require("../../src/ServerScriptService/Combat/EngravingResolver.luau")

local DEFS = {
	keen_blunt = {
		id = "keen_blunt",
		tiers = {
			{ threshold = 5, type = "crit_rate", value = 0.04 },
			{ threshold = 10, type = "crit_rate", value = 0.10 },
			{ threshold = 15, type = "crit_rate", value = 0.20 },
		},
	},
	adrenaline = {
		id = "adrenaline",
		tiers = { { threshold = 5, type = "damage_mul", value = 0.10 } },
	},
	precise = {
		id = "precise",
		tiers = { { threshold = 5, type = "damage_mul", value = 0.10 } },
	},
	cursed_doll = {
		id = "cursed_doll",
		tiers = { { threshold = 5, type = "damage_mul", value = -0.15 } },
	},
	fireblood = {
		id = "fireblood",
		tiers = { { threshold = 5, type = "damage_add", value = 100 } },
		filter = "fireball",
	},
}

return function()
	describe("EngravingResolver tiers", function()
		it("returns the tier-2 value at 10 points", function()
			local m = EngravingResolver.resolve({ keen_blunt = 10 }, "any_skill", DEFS)
			expect(m.critRate).to.be.near(0.10, 1e-9)
		end)

		it("returns only the highest activated tier at 15 points", function()
			local m = EngravingResolver.resolve({ keen_blunt = 15 }, "any_skill", DEFS)
			expect(m.critRate).to.be.near(0.20, 1e-9)
		end)

		it("returns no bonus below the first threshold", function()
			local m = EngravingResolver.resolve({ keen_blunt = 3 }, "any_skill", DEFS)
			expect(m.critRate).to.be.near(0, 1e-9)
		end)
	end)

	describe("EngravingResolver chaining", function()
		it("chains two damage_mul of 0.1 to 0.21, not 0.20", function()
			local m = EngravingResolver.resolve({ adrenaline = 5, precise = 5 }, "any_skill", DEFS)
			expect(m.damageMul).to.be.near(0.21, 1e-9)
		end)

		it("caps total crit_rate at 1.0", function()
			local big = {
				id = "big",
				tiers = { { threshold = 1, type = "crit_rate", value = 5.0 } },
			}
			local m = EngravingResolver.resolve({ big = 1 }, "any_skill", { big = big })
			expect(m.critRate).to.be.near(1.0, 1e-9)
		end)
	end)

	describe("EngravingResolver penalties", function()
		it("applies a negative engraving at and above its threshold", function()
			local m = EngravingResolver.resolve({ cursed_doll = 5 }, "any_skill", DEFS)
			expect(m.damageMul).to.be.near(-0.15, 1e-9)
		end)

		it("does not apply a penalty below its threshold", function()
			local m = EngravingResolver.resolve({ cursed_doll = 4 }, "any_skill", DEFS)
			expect(m.damageMul).to.be.near(0, 1e-9)
		end)
	end)

	describe("EngravingResolver filters", function()
		it("applies a filtered engraving only to the matching skill", function()
			local onSkill = EngravingResolver.resolve({ fireblood = 5 }, "fireball", DEFS)
			expect(onSkill.damageAdd).to.be.near(100, 1e-9)
			local offSkill = EngravingResolver.resolve({ fireblood = 5 }, "ice_lance", DEFS)
			expect(offSkill.damageAdd).to.be.near(0, 1e-9)
		end)
	end)
end
