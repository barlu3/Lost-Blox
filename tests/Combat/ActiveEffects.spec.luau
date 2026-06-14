-- TASK_Q2_02 support: Arcane Surge timed buff and its resolved modifiers.
require("../Harness.luau")
local ActiveEffects = require("../../src/ServerScriptService/Combat/ActiveEffects.luau")

return function()
	describe("ActiveEffects", function()
		it("an applied effect is active until it expires", function()
			local store = {}
			ActiveEffects.apply(store, "arcane_surge", 1000, 6)
			expect(ActiveEffects.isActive(store, "arcane_surge", 1003)).to.equal(true)
			expect(ActiveEffects.isActive(store, "arcane_surge", 1006.1)).to.equal(false)
		end)

		it("an unknown effect is never active", function()
			expect(ActiveEffects.isActive({}, "nothing", 1000)).to.equal(false)
		end)

		it("surge modifiers are +30% damage and -50% cooldown while active", function()
			local store = {}
			ActiveEffects.apply(store, "arcane_surge", 1000, 6)
			local mods = ActiveEffects.surgeModifiers(store, 1002)
			expect(mods.damageMul).to.be.near(0.30, 1e-9)
			expect(mods.cooldownMul).to.be.near(-0.50, 1e-9)
		end)

		it("surge modifiers are zero when inactive", function()
			local mods = ActiveEffects.surgeModifiers({}, 1000)
			expect(mods.damageMul).to.be.near(0, 1e-9)
			expect(mods.cooldownMul).to.be.near(0, 1e-9)
		end)
	end)
end
