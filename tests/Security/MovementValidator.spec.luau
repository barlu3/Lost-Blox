-- TASK_Q1_03 acceptance (server portion): speed delta rejection with jitter
-- tolerance. Pathfinding feel requires a game session.
require("../Harness.luau")
local MovementValidator = require("../../src/ServerScriptService/Security/MovementValidator.luau")

return function()
	describe("MovementValidator.check", function()
		it("flags 100 studs in 0.5s on a 16 stud/s walker", function()
			local from = Vector3.new(0, 0, 0)
			local to = Vector3.new(100, 0, 0)
			local result = MovementValidator.check(from, to, 0.5, 16)
			-- 100 / 0.5 = 200 studs/s, far above 16 * 1.2
			expect(result.ok).to.equal(false)
			expect(result.speed).to.be.near(200, 1e-6)
		end)

		it("accepts normal walking within tolerance", function()
			local from = Vector3.new(0, 0, 0)
			local to = Vector3.new(8, 0, 0) -- 16 studs/s, exactly walk speed
			local result = MovementValidator.check(from, to, 0.5, 16)
			expect(result.ok).to.equal(true)
		end)

		it("allows up to 20% over walk speed (jitter)", function()
			-- 16 * 1.2 = 19.2 studs/s -> 9.6 studs in 0.5s
			local borderline = MovementValidator.check(Vector3.new(0, 0, 0), Vector3.new(9.5, 0, 0), 0.5, 16)
			expect(borderline.ok).to.equal(true)
			local over = MovementValidator.check(Vector3.new(0, 0, 0), Vector3.new(11, 0, 0), 0.5, 16)
			expect(over.ok).to.equal(false)
		end)

		it("respects an explicit tolerance argument", function()
			-- 30 studs/s with a generous 2.0x tolerance on a 16 walker is allowed.
			local result = MovementValidator.check(Vector3.new(0, 0, 0), Vector3.new(15, 0, 0), 0.5, 16, 2.0)
			expect(result.ok).to.equal(true)
		end)
	end)
end
