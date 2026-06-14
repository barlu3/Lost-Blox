--!strict
-- Pure camera math, factored out of TopDownCamera so zoom clamping, the
-- frame-rate-independent lerp alpha, and the pitch offset are unit-testable
-- without a live RenderStepped loop.

local CameraMath = {}

CameraMath.PITCH_RAD = -math.rad(60) -- looking down 60°
CameraMath.ZOOM_MIN = 18
CameraMath.ZOOM_MAX = 35
CameraMath.BASE_ALPHA = 0.15
CameraMath.ZOOM_STEP = 1.5

function CameraMath.clampZoom(studs: number): number
	return math.clamp(studs, CameraMath.ZOOM_MIN, CameraMath.ZOOM_MAX)
end

-- Frame-rate-independent lerp factor: equals BASE_ALPHA at 60fps and rises as
-- frame time grows so the camera keeps up at low fps. alpha = 1 - (1-base)^(dt*60).
function CameraMath.frameAlpha(dt: number, baseAlpha: number?): number
	local base = baseAlpha or CameraMath.BASE_ALPHA
	return 1 - (1 - base) ^ (dt * 60)
end

-- Positional offset from the character to the camera for a given zoom distance,
-- along the fixed pitch. Pitch is constant, so the camera angle never depends on
-- character orientation.
function CameraMath.cameraOffset(zoomStuds: number): Vector3
	local pitch = CameraMath.PITCH_RAD
	-- Camera sits up and back from the target; -pitch because we look downward.
	return Vector3.new(0, zoomStuds * math.sin(-pitch), zoomStuds * math.cos(-pitch))
end

return CameraMath
