-- TASK_Q1_04 acceptance (math portion): zoom clamp, pitch lock, frame-rate-
-- independent lerp. Camera feel itself requires a game session.
require("../Harness.luau")
local CameraMath = require("../../src/ReplicatedStorage/Modules/CameraMath.luau")

return function()
	describe("CameraMath zoom clamp", function()
		it("keeps zoom inside [18, 35]", function()
			expect(CameraMath.clampZoom(25)).to.equal(25)
		end)
		it("clamps below the minimum", function()
			expect(CameraMath.clampZoom(5)).to.equal(18)
		end)
		it("clamps above the maximum", function()
			expect(CameraMath.clampZoom(99)).to.equal(35)
		end)
	end)

	describe("CameraMath pitch", function()
		it("locks pitch at -60 degrees", function()
			expect(CameraMath.PITCH_RAD).to.be.near(-math.rad(60), 1e-9)
		end)
	end)

	describe("CameraMath frameAlpha", function()
		it("equals base alpha at 60fps", function()
			expect(CameraMath.frameAlpha(1 / 60, 0.15)).to.be.near(0.15, 1e-9)
		end)
		it("is larger at 30fps so the camera keeps up", function()
			local a30 = CameraMath.frameAlpha(1 / 30, 0.15)
			expect(a30 > 0.15).to.equal(true)
			-- two 1/60 steps compose to one 1/30 step
			local composed = 1 - (1 - CameraMath.frameAlpha(1 / 60, 0.15)) ^ 2
			expect(a30).to.be.near(composed, 1e-9)
		end)
	end)

	describe("CameraMath cameraOffset", function()
		it("has no horizontal X component (camera stays behind on Y/Z)", function()
			expect(CameraMath.cameraOffset(25).X).to.be.near(0, 1e-9)
		end)
		it("offset magnitude equals the zoom distance", function()
			local o = CameraMath.cameraOffset(25)
			expect(o.Magnitude).to.be.near(25, 1e-6)
		end)
	end)
end
