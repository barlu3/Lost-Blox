-- TASK_Q1_07 acceptance: event envelopes, immediate flush on session_end,
-- valid JSON batching, and timestamp-ordered events.
local Harness = require("../Harness.luau")
local SessionLogger = require("../../src/ServerScriptService/Analytics/SessionLogger.luau")

local function reset()
	SessionLogger._queue = {}
	Harness.httpPosts = {}
	Harness.services.HttpService.PostAsync = function(_, url, body)
		table.insert(Harness.httpPosts, { url = url, body = body })
		return ""
	end
end

return function()
	describe("SessionLogger envelopes", function()
		it("session_start carries class and iLvl", function()
			reset()
			SessionLogger.logSessionStart(42, "ironclad", 302)
			local e = SessionLogger._queue[1]
			expect(e.event).to.equal("session_start")
			expect(e.userId).to.equal(42)
			expect(e.data.class).to.equal("ironclad")
			expect(e.data.iLvl).to.equal(302)
			expect(e.timestamp).to.be.a("number")
		end)

		it("all five event types enqueue with the shared envelope", function()
			reset()
			SessionLogger.logSessionStart(1, "ironclad", 100)
			SessionLogger.logDeath(1, "void_scout", "prologue", 30)
			SessionLogger.logBossKill(1, "warden", 88, 4)
			SessionLogger.logSkillUsed(1, "heavy_strike", true, 250)
			-- four enqueued; session_end will be the fifth and triggers a flush.
			expect(SessionLogger.getQueueSize()).to.equal(4)
			for _, e in SessionLogger._queue do
				expect(e.event).to.be.a("string")
				expect(e.userId).to.be.a("number")
				expect(e.timestamp).to.be.a("number")
				expect(e.data).to.be.a("table")
			end
		end)
	end)

	describe("SessionLogger flush", function()
		it("session_end flushes the whole batch in one POST on a live server", function()
			reset()
			Harness.isStudio = false
			SessionLogger.logSkillUsed(7, "jab", true, 10)
			SessionLogger.logSessionEnd(7, 3600, "voluntary")

			expect(#Harness.httpPosts).to.equal(1)
			expect(SessionLogger.getQueueSize()).to.equal(0)

			local batch = Harness.services.HttpService:JSONDecode(Harness.httpPosts[1].body)
			expect(#batch).to.equal(2)
			expect(batch[1].event).to.equal("skill_used")
			expect(batch[2].event).to.equal("session_end")
			Harness.isStudio = true
		end)

		it("studio mode produces a valid JSON batch and clears the queue", function()
			reset()
			Harness.isStudio = true
			SessionLogger.logSessionStart(9, "stormcaller", 600)
			-- Round-trip the queue through the encoder to prove it is valid JSON.
			local json = Harness.services.HttpService:JSONEncode(SessionLogger._queue)
			local decoded = Harness.services.HttpService:JSONDecode(json)
			expect(decoded[1].data.class).to.equal("stormcaller")
			SessionLogger.flush()
			expect(SessionLogger.getQueueSize()).to.equal(0)
			-- Studio path must not POST.
			expect(#Harness.httpPosts).to.equal(0)
		end)

		it("flush on an empty queue is a no-op", function()
			reset()
			SessionLogger.flush()
			expect(#Harness.httpPosts).to.equal(0)
		end)
	end)

	describe("SessionLogger ordering", function()
		it("preserves enqueue order within a batch", function()
			reset()
			Harness.isStudio = false
			SessionLogger.logSessionStart(3, "skystrike", 150)
			SessionLogger.logSkillUsed(3, "palm", true, 40)
			SessionLogger.logSessionEnd(3, 120, "kick")
			local batch = Harness.services.HttpService:JSONDecode(Harness.httpPosts[1].body)
			expect(batch[1].event).to.equal("session_start")
			expect(batch[2].event).to.equal("skill_used")
			expect(batch[3].event).to.equal("session_end")
			Harness.isStudio = true
		end)
	end)
end
