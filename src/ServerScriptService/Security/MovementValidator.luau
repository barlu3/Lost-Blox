-- Server-side anti-teleport speed validation. The client moves freely along its
-- computed path; the server samples position periodically and rejects movement
-- that exceeds the character's walk speed (plus jitter tolerance).
--
-- check() is pure and unit-testable; start() runs the per-player sampling loop.
local Players = game:GetService("Players")

local MovementValidator = {}

local SAMPLE_INTERVAL = 0.5
local DEFAULT_TOLERANCE = 1.2 -- 20% over walk speed allowed for network jitter

export type CheckResult = {
	ok: boolean,
	speed: number,
}

-- Returns whether the move from lastPos to currentPos over dt seconds is within
-- maxSpeed * tolerance. Speed is studs/second.
function MovementValidator.check(
	lastPos: Vector3,
	currentPos: Vector3,
	dt: number,
	maxSpeed: number,
	tolerance: number?
): CheckResult
	local tol = tolerance or DEFAULT_TOLERANCE
	local speed = (currentPos - lastPos).Magnitude / dt
	return {
		ok = speed <= maxSpeed * tol,
		speed = speed,
	}
end

-- Per-player sampling loop. logger is optional (SessionLogger) so the flag is
-- recorded; on a violation the player is returned to their last valid position.
function MovementValidator.start(logger: any?)
	local lastValid: { [Player]: Vector3 } = {}

	local function sample(player: Player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then
			lastValid[player] = nil
			return
		end

		local prev = lastValid[player]
		if prev then
			local result = MovementValidator.check(prev, root.Position, SAMPLE_INTERVAL, humanoid.WalkSpeed)
			if not result.ok then
				if logger then
					logger.log("teleport_flag", player.UserId, { speed = result.speed, walkSpeed = humanoid.WalkSpeed })
				end
				root.CFrame = CFrame.new(prev)
				return
			end
		end
		lastValid[player] = root.Position
	end

	task.spawn(function()
		while true do
			task.wait(SAMPLE_INTERVAL)
			for _, player in Players:GetPlayers() do
				sample(player)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastValid[player] = nil
	end)
end

return MovementValidator
