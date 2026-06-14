-- Top-down camera controller. Takes over the Roblox camera, locking pitch at
-- -60° and tracking the character from a scroll-adjustable zoom distance.
-- Exposes enable()/disable() so cutscenes can take control.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraMath = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CameraMath"))

local TopDownCamera = {}

local camera = Workspace.CurrentCamera
local zoomStuds = 25
local boundCharacter: Model? = nil
local isBound = false
local zoomConnection: RBXScriptConnection? = nil
local savedCameraType: Enum.CameraType? = nil

local RENDER_NAME = "LostBlox_TopDownCamera"

local function onRender(dt: number)
	local character = boundCharacter
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local target = root.Position
	local offset = CameraMath.cameraOffset(zoomStuds)
	local desired = CFrame.new(target + offset) * CFrame.Angles(CameraMath.PITCH_RAD, 0, 0)

	local alpha = CameraMath.frameAlpha(dt)
	camera.CFrame = camera.CFrame:Lerp(desired, alpha)
end

local function onInput(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		zoomStuds = CameraMath.clampZoom(zoomStuds - input.Position.Z * CameraMath.ZOOM_STEP)
	end
end

function TopDownCamera.enable(character: Model)
	camera = Workspace.CurrentCamera
	boundCharacter = character

	if savedCameraType == nil then
		savedCameraType = camera.CameraType
	end
	camera.CameraType = Enum.CameraType.Scriptable

	if not isBound then
		RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value, onRender)
		zoomConnection = UserInputService.InputChanged:Connect(onInput)
		isBound = true
	end
end

function TopDownCamera.disable()
	if not isBound then
		return
	end
	isBound = false
	RunService:UnbindFromRenderStep(RENDER_NAME)
	if zoomConnection then
		zoomConnection:Disconnect()
		zoomConnection = nil
	end
	if savedCameraType ~= nil then
		camera.CameraType = savedCameraType
		savedCameraType = nil
	end
	boundCharacter = nil
end

function TopDownCamera.setZoom(studs: number)
	zoomStuds = CameraMath.clampZoom(studs)
end

-- Convenience: keep the camera bound to the local player's current/future character.
function TopDownCamera.bindLocalPlayer()
	local player = Players.LocalPlayer
	local function bind(character: Model)
		character:WaitForChild("HumanoidRootPart")
		TopDownCamera.enable(character)
	end
	if player.Character then
		bind(player.Character)
	end
	player.CharacterAdded:Connect(bind)
end

return TopDownCamera
