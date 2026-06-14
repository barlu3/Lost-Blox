-- TASK_Q1_02 acceptance: cast validation ordering — cooldown, range, target,
-- resource — cannot be bypassed by the client.
require("../Harness.luau")
local CastValidator = require("../../src/ServerScriptService/Combat/CastValidator.luau")

local function skill(over: { [string]: any }?)
	local s = {
		id = "heavy_strike",
		cooldown = 4,
		range = 20,
		resourceCost = 10,
		targetType = "single",
	}
	for k, v in over or {} do
		s[k] = v
	end
	return s
end

local function caster(over: { [string]: any }?)
	local c = {
		position = Vector3.new(0, 0, 0),
		resource = 100,
		lastCast = {},
	}
	for k, v in over or {} do
		c[k] = v
	end
	return c
end

local function targetAt(x: number)
	return { position = Vector3.new(x, 0, 0), alive = true }
end

return function()
	describe("CastValidator", function()
		it("nil skill is rejected", function()
			expect(CastValidator.validate(nil, caster(), targetAt(5), 1000)).to.equal("no_skill")
		end)

		it("passes a valid in-range cast off cooldown with resource", function()
			expect(CastValidator.validate(skill(), caster(), targetAt(10), 1000)).to.equal("ok")
		end)

		it("rejects a second cast inside the cooldown window", function()
			local c = caster({ lastCast = { heavy_strike = 1000 } })
			-- 1002 - 1000 = 2 < cooldown 4
			expect(CastValidator.validate(skill(), c, targetAt(5), 1002)).to.equal("cooldown")
		end)

		it("allows the cast once the cooldown has elapsed", function()
			local c = caster({ lastCast = { heavy_strike = 1000 } })
			expect(CastValidator.validate(skill(), c, targetAt(5), 1004.1)).to.equal("ok")
		end)

		it("rejects a target beyond skill range", function()
			-- range 20, target 200 studs away
			expect(CastValidator.validate(skill(), caster(), targetAt(200), 1000)).to.equal("out_of_range")
		end)

		it("rejects when there is no living target", function()
			expect(CastValidator.validate(skill(), caster(), nil, 1000)).to.equal("no_target")
			local dead = { position = Vector3.new(1, 0, 0), alive = false }
			expect(CastValidator.validate(skill(), caster(), dead, 1000)).to.equal("no_target")
		end)

		it("rejects when resource is insufficient", function()
			expect(CastValidator.validate(skill(), caster({ resource = 5 }), targetAt(5), 1000)).to.equal("insufficient_resource")
		end)

		it("self-target skills ignore target and range checks", function()
			local s = skill({ targetType = "self", range = 0 })
			expect(CastValidator.validate(s, caster(), nil, 1000)).to.equal("ok")
		end)
	end)
end
