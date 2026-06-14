-- TASK_Q2_05 support: StatRecomputer sums base + gear + engraving modifiers.
require("../Harness.luau")
local StatRecomputer = require("../../src/ServerScriptService/Combat/StatRecomputer.luau")

local function base()
	return { baseAttack = 100, critChance = 0.05, critDamage = 0.5, maxHealth = 1000, iLvl = 0, resourceType = "fury" }
end

return function()
	describe("StatRecomputer", function()
		it("adds a weapon's iLvl and quality contribution to attack", function()
			local stats = StatRecomputer.recompute(base(), { weapon = { id = "s", quality = 72, iLvl = 302 } })
			-- 100 + 302*0.5 + 72*0.2 = 100 + 151 + 14.4 = 265.4
			expect(stats.baseAttack).to.be.near(265.4, 1e-6)
		end)

		it("reports item level as the average of equipped gear", function()
			local stats = StatRecomputer.recompute(base(), {
				weapon = { id = "w", quality = 0, iLvl = 300 },
				chest = { id = "c", quality = 0, iLvl = 400 },
			})
			expect(stats.iLvl).to.be.near(350, 1e-6)
		end)

		it("applies engraving crit modifiers on top of base", function()
			local stats = StatRecomputer.recompute(base(), {}, { critRate = 0.10, critDamage = 0.20, damageAdd = 0, damageMul = 0 })
			expect(stats.critChance).to.be.near(0.15, 1e-9)
			expect(stats.critDamage).to.be.near(0.70, 1e-9)
		end)

		it("falls back to base iLvl with no gear equipped", function()
			local b = base()
			b.iLvl = 50
			local stats = StatRecomputer.recompute(b, {})
			expect(stats.iLvl).to.equal(50)
		end)
	end)
end
