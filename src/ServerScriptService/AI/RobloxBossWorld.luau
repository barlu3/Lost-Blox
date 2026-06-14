-- Builds the live World interface for BossController from a Roblox boss model.
-- Danger zones are real BaseParts; players inside a zone's bounds take damage.
-- Kept separate from BossController so the controller's logic stays testable.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RobloxBossWorld = {}

local ZONE_COLORS: { [string]: Color3 } = {
	circle = Color3.fromRGB(220, 70, 70),
	square = Color3.fromRGB(220, 180, 60),
	ring = Color3.fromRGB(150, 70, 220),
}

local function livingPlayers(): { any }
	local out = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			table.insert(out, {
				player = player,
				position = root.Position,
				alive = true,
				humanoid = humanoid,
			})
		end
	end
	return out
end

-- model: the boss Model with a Humanoid + HumanoidRootPart.
function RobloxBossWorld.new(model: Model, zoneParent: Instance?)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local parent = zoneParent or Workspace

	return {
		getPlayers = livingPlayers,

		getBossPosition = function(): Vector3
			return root.Position
		end,

		moveBossTo = function(position: Vector3)
			humanoid:MoveTo(position)
		end,

		getHpFraction = function(): number
			return if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 0
		end,

		spawnDangerZone = function(mechanic, atPosition: Vector3): BasePart
			local zone = Instance.new("Part")
			zone.Name = "DangerZone_" .. mechanic.name
			zone.Anchored = true
			zone.CanCollide = false
			zone.Transparency = 0.5
			zone.Color = ZONE_COLORS[mechanic.shape] or Color3.new(1, 0, 0)
			local diameter = mechanic.radius * 2
			zone.Size = Vector3.new(diameter, 1, diameter)
			zone.Position = atPosition
			zone.Parent = parent
			return zone
		end,

		playersInZone = function(zone: BasePart): { any }
			local inside = {}
			local half = zone.Size.X / 2
			for _, p in livingPlayers() do
				if (p.position - zone.Position).Magnitude <= half then
					table.insert(inside, p)
				end
			end
			return inside
		end,

		applyDamage = function(p, amount: number)
			if p.humanoid then
				p.humanoid:TakeDamage(amount)
			end
		end,

		clearDangerZone = function(zone: BasePart?)
			if zone then
				zone:Destroy()
			end
		end,

		applyEnrage = function(moveMult: number, _damageMult: number)
			humanoid.WalkSpeed *= moveMult
			-- Damage multiplier is read by the damage pipeline from a boss attribute.
			model:SetAttribute("DamageMultiplier", (model:GetAttribute("DamageMultiplier") or 1) * _damageMult)
		end,
	}
end

return RobloxBossWorld
