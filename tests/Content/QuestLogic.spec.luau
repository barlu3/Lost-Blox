-- TASK_Q3_03 acceptance: objective tracking, single completion, no overshoot,
-- and no restarting a completed quest.
require("../Harness.luau")
local QuestLogic = require("../../src/ServerScriptService/Content/QuestLogic.luau")

local QUEST = {
	id = "find_the_herald",
	name = "Find the Herald",
	objectives = {
		{ id = "kill_scouts", type = "kill", target = "void_scout", count = 5 },
		{ id = "reach_waypoint", type = "reach", target = "herald_shrine_zone" },
	},
	rewards = {},
}

return function()
	describe("QuestLogic progress", function()
		it("initializes counts at 0 and reach flags at false", function()
			local p = QuestLogic.initProgress(QUEST)
			expect(p.kill_scouts).to.equal(0)
			expect(p.reach_waypoint).to.equal(false)
		end)

		it("marks a kill objective met after the required count", function()
			local p = QuestLogic.initProgress(QUEST)
			for _ = 1, 5 do
				QuestLogic.incrementKill(QUEST, p, "void_scout")
			end
			expect(p.kill_scouts).to.equal(5)
			expect(QuestLogic.isObjectiveMet(QUEST.objectives[1], p.kill_scouts)).to.equal(true)
		end)

		it("does not overshoot the kill count on extra kills", function()
			local p = QuestLogic.initProgress(QUEST)
			for _ = 1, 8 do
				QuestLogic.incrementKill(QUEST, p, "void_scout")
			end
			expect(p.kill_scouts).to.equal(5)
		end)

		it("ignores kills of an unrelated mob", function()
			local p = QuestLogic.initProgress(QUEST)
			local changed = QuestLogic.incrementKill(QUEST, p, "goblin")
			expect(changed).to.equal(false)
			expect(p.kill_scouts).to.equal(0)
		end)
	end)

	describe("QuestLogic completion", function()
		it("is complete only when all objectives are met", function()
			local p = QuestLogic.initProgress(QUEST)
			for _ = 1, 5 do
				QuestLogic.incrementKill(QUEST, p, "void_scout")
			end
			expect(QuestLogic.isComplete(QUEST, p)).to.equal(false) -- reach still pending
			QuestLogic.markReach(QUEST, p, "herald_shrine_zone")
			expect(QuestLogic.isComplete(QUEST, p)).to.equal(true)
		end)
	end)

	describe("QuestLogic start gating", function()
		it("cannot start an active quest", function()
			expect(QuestLogic.canStart("find_the_herald", { find_the_herald = {} }, {})).to.equal(false)
		end)

		it("cannot start an already-completed quest", function()
			expect(QuestLogic.canStart("find_the_herald", {}, { "find_the_herald" })).to.equal(false)
		end)

		it("can start a fresh quest", function()
			expect(QuestLogic.canStart("find_the_herald", {}, {})).to.equal(true)
		end)
	end)
end
