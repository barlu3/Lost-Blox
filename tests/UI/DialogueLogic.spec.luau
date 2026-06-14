-- TASK_Q3_04 acceptance (logic portion): reveal duration and voice-blip rules.
-- Audio feel and visual timing need a game session.
require("../Harness.luau")
local DialogueLogic = require("../../src/ReplicatedStorage/Modules/DialogueLogic.luau")

return function()
	describe("DialogueLogic reveal", function()
		it("a 40-character line reveals in 1.0s", function()
			local text = string.rep("a", 40)
			expect(DialogueLogic.revealDuration(text)).to.be.near(1.0, 0.05)
		end)
	end)

	describe("DialogueLogic blips", function()
		it("vowels blip at volume 1.1", function()
			local blip = DialogueLogic.blipFor("a", 1.2, function()
				return 0.5
			end)
			expect(blip).to.be.ok()
			expect(blip.volume).to.be.near(1.1, 1e-9)
		end)

		it("consonants blip at volume 1.0", function()
			local blip = DialogueLogic.blipFor("b", 1.2, function()
				return 0.5
			end)
			expect(blip.volume).to.be.near(1.0, 1e-9)
		end)

		it("spaces and punctuation make no sound", function()
			expect(DialogueLogic.blipFor(" ", 1.2)).never.to.be.ok()
			expect(DialogueLogic.blipFor(".", 1.2)).never.to.be.ok()
			expect(DialogueLogic.blipFor("!", 1.2)).never.to.be.ok()
		end)

		it("playback speed stays within pitch +/- jitter", function()
			-- roll 0.5 -> jitter 0, so playbackSpeed == pitch exactly
			local mid = DialogueLogic.blipFor("e", 1.2, function()
				return 0.5
			end)
			expect(mid.playbackSpeed).to.be.near(1.2, 1e-9)
			-- roll 1.0 -> +0.05, roll 0.0 -> -0.05
			local high = DialogueLogic.blipFor("e", 1.2, function()
				return 1.0
			end)
			expect(high.playbackSpeed).to.be.near(1.25, 1e-9)
			local low = DialogueLogic.blipFor("e", 1.2, function()
				return 0.0
			end)
			expect(low.playbackSpeed).to.be.near(1.15, 1e-9)
		end)

		it("is case-insensitive for vowels", function()
			expect(DialogueLogic.isVowel("A")).to.equal(true)
			expect(DialogueLogic.isVowel("E")).to.equal(true)
			expect(DialogueLogic.isVowel("z")).to.equal(false)
		end)
	end)
end
