-- Click-to-move controller. On left-click it raycasts to the world, computes a
-- navmesh path, and walks the character along it. WASD cancels the path. The
-- client path is cosmetic only — the server (MovementValidator) independently
-- validates movement speed and does not trust client waypoints.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local ClickToMove = {}

local AGENT_PARAMS = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = false,
}
local CACHE_TTL = 5 -- seconds a cached path stays valid for the same zone

local player = Players.LocalPlayer
local walkToken = 0 -- bumped to cancel an in-flight path walk
local currentZoneId = "overworld"
local pathCache: { [string]: { path: any, at: number } } = {}

local function getCharacter(): (Model?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return character, humanoid
end

function ClickToMove.cancelPath()
	walkToken += 1
	local _, humanoid = getCharacter()
	if humanoid then
		-- MoveTo to the current position stops further movement.
		local root = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
		if root then
			humanoid:MoveTo(root.Position)
		end
	end
end

local function raycastToWorld(): Vector3?
	local camera = Workspace.CurrentCamera
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	return hit and hit.Position or nil
end

local function computePath(fromPos: Vector3, toPos: Vector3): any?
	-- Reuse a recent path for the same zone to avoid redundant ComputeAsync.
	local cached = pathCache[currentZoneId]
	if cached and (os.clock() - cached.at) < CACHE_TTL then
		return cached.path
	end

	local path = PathfindingService:CreatePath(AGENT_PARAMS)
	local ok = pcall(function()
		path:ComputeAsync(fromPos, toPos)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil -- no navmesh / unreachable: do not walk through geometry
	end
	pathCache[currentZoneId] = { path = path, at = os.clock() }
	return path
end

local function walkPath(path: any)
	local character, humanoid = getCharacter()
	if not character or not humanoid then
		return
	end

	walkToken += 1
	local myToken = walkToken
	for _, waypoint in path:GetWaypoints() do
		if myToken ~= walkToken then
			return -- cancelled (WASD or a newer click)
		end
		humanoid:MoveTo(waypoint.Position)
		humanoid.MoveToFinished:Wait()
	end
end

local function onClick()
	local _, humanoid = getCharacter()
	local root = humanoid and humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local destination = raycastToWorld()
	if not destination then
		return
	end
	local path = computePath(root.Position, destination)
	if path then
		task.spawn(walkPath, path)
	end
end

-- Server fires this when zone geometry changes so the cosmetic path cache drops.
function ClickToMove.onZoneReloaded(zoneId: string)
	currentZoneId = zoneId
	pathCache[zoneId] = nil
end

function ClickToMove.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onClick()
		elseif input.KeyCode == Enum.KeyCode.W
			or input.KeyCode == Enum.KeyCode.A
			or input.KeyCode == Enum.KeyCode.S
			or input.KeyCode == Enum.KeyCode.D
		then
			ClickToMove.cancelPath()
		end
	end)
end

return ClickToMove
