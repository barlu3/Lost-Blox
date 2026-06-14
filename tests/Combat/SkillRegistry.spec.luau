-- TASK_Q1_02 / TASK_Q2_01 support: registry stores and retrieves skill defs.
require("../Harness.luau")
local SkillRegistry = require("../../src/ServerScriptService/Combat/SkillRegistry.luau")

local function def(id: string, over: { [string]: any }?)
	local d = {
		id = id,
		cooldown = 4,
		range = 8,
		damageMultiplier = 1.8,
		resourceCost = 10,
		targetType = "single",
	}
	for k, v in over or {} do
		d[k] = v
	end
	return d
end

return function()
	describe("SkillRegistry", function()
		it("registers and retrieves a skill with its classId stamped", function()
			SkillRegistry.clear()
			SkillRegistry.register("ironclad", def("heavy_strike"))
			local got = SkillRegistry.get("heavy_strike")
			expect(got).to.be.ok()
			expect(got.classId).to.equal("ironclad")
			expect(got.damageMultiplier).to.be.near(1.8, 1e-9)
		end)

		it("getByClass returns only that class's skills", function()
			SkillRegistry.clear()
			SkillRegistry.register("ironclad", def("a"))
			SkillRegistry.register("ironclad", def("b"))
			SkillRegistry.register("stormcaller", def("c"))
			expect(#SkillRegistry.getByClass("ironclad")).to.equal(2)
			expect(#SkillRegistry.getByClass("stormcaller")).to.equal(1)
		end)

		it("re-registering an id overwrites (reload path)", function()
			SkillRegistry.clear()
			SkillRegistry.register("ironclad", def("x", { cooldown = 4 }))
			SkillRegistry.register("ironclad", def("x", { cooldown = 9 }))
			expect(SkillRegistry.count()).to.equal(1)
			expect(SkillRegistry.get("x").cooldown).to.equal(9)
		end)

		it("does not mutate the caller's table", function()
			SkillRegistry.clear()
			local original = def("y")
			SkillRegistry.register("ironclad", original)
			expect(original.classId).never.to.equal("ironclad")
		end)

		it("unknown skill returns nil", function()
			SkillRegistry.clear()
			expect(SkillRegistry.get("nope")).never.to.be.ok()
		end)
	end)
end
