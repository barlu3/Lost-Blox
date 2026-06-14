-- TASK_Q5_03 acceptance: teleport/damage/cooldown flags, whitelist, and the
-- score-threshold kick.
require("../Harness.luau")
local BD = require("../../src/ServerScriptService/Security/BehavioralDetector.luau")

return function()
	describe("BehavioralDetector position", function()
		it("flags 100 studs in 0.5s on a 16 stud/s character", function()
			local flag = BD.checkPosition(Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), 0.5, 16)
			expect(flag).to.equal("teleport")
		end)

		it("does not flag normal movement", function()
			local flag = BD.checkPosition(Vector3.new(0, 0, 0), Vector3.new(8, 0, 0), 0.5, 16)
			expect(flag).never.to.be.ok()
		end)

		it("does not flag a player with a whitelisted speed effect", function()
			local flag = BD.checkPosition(Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), 0.5, 16, true)
			expect(flag).never.to.be.ok()
		end)
	end)

	describe("BehavioralDetector damage", function()
		it("does not flag damage within 10% of theoretical max", function()
			expect(BD.checkDamage(105, 100)).never.to.be.ok()
		end)
		it("flags damage above 110% of theoretical max", function()
			expect(BD.checkDamage(115, 100)).to.equal("damage_overflow")
		end)
	end)

	describe("BehavioralDetector cooldown", function()
		it("flags a cast inside 80% of the cooldown", function()
			-- cooldown 4, last cast at 1000, now 1003 -> 3 < 3.2
			expect(BD.checkCooldown(1003, 1000, 4)).to.equal("cooldown_bypass")
		end)
		it("does not flag a cast past 80% of the cooldown", function()
			expect(BD.checkCooldown(1003.5, 1000, 4)).never.to.be.ok()
		end)
	end)

	describe("BehavioralDetector scoring", function()
		it("kicks after 5 cooldown bypasses (score 10) within 60s", function()
			local state = BD.newState()
			for i = 1, 5 do
				BD.addFlag(state, "cooldown_bypass", 1000 + i)
			end
			expect(BD.recentScore(state, 1005)).to.equal(10)
			expect(BD.shouldKick(state, 1005)).to.equal(true)
		end)

		it("does not kick on 4 cooldown bypasses (score 8)", function()
			local state = BD.newState()
			for i = 1, 4 do
				BD.addFlag(state, "cooldown_bypass", 1000 + i)
			end
			expect(BD.shouldKick(state, 1004)).to.equal(false)
		end)

		it("drops flags outside the 60-second window from the recent score", function()
			local state = BD.newState()
			BD.addFlag(state, "damage_overflow", 1000) -- 5
			BD.addFlag(state, "damage_overflow", 1100) -- 5, 100s later
			expect(BD.recentScore(state, 1100)).to.equal(5) -- first one aged out
		end)

		it("queues a ban review once the session score reaches 30", function()
			local state = BD.newState()
			for i = 1, 6 do
				BD.addFlag(state, "damage_overflow", 1000 + i) -- 6 * 5 = 30
			end
			expect(BD.shouldBanReview(state)).to.equal(true)
		end)
	end)
end
