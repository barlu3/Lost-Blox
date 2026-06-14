-- Live-ops metrics exporter. Every 60s the server collects CCU, active raids,
-- class distribution, honing success rate, and revenue, then POSTs one JSON
-- payload to the dashboard endpoint. In Studio it prints instead. A failed POST
-- must never crash the game server, so the network call is wrapped in pcall.
--
-- buildPayload is pure and unit-testable; start() runs the periodic loop.
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local DASHBOARD_URL = "https://dashboard.lostblox.gg/metrics"
local INTERVAL = 60

local Exporter = {}

-- stats fields map 1:1 to the documented dashboard schema.
function Exporter.buildPayload(stats: any): any
	return {
		timestamp = os.time(),
		server_id = stats.serverId,
		ccu = stats.ccu,
		active_raids = stats.activeRaids,
		top_classes = stats.topClasses,
		honing_success_rate_15min = stats.honingSuccessRate15min,
		revenue_session = stats.revenueSession, -- { bp, cosmetics, gamepasses }
	}
end

function Exporter.flush(stats: any)
	local payload = Exporter.buildPayload(stats)
	local json = HttpService:JSONEncode(payload)
	if RunService:IsStudio() then
		print("[Exporter] " .. json)
		return
	end
	-- pcall so dashboard downtime / network errors never take down the server.
	pcall(function()
		HttpService:PostAsync(DASHBOARD_URL, json, Enum.HttpContentType.ApplicationJson)
	end)
end

-- collectStats() returns the current metrics snapshot. Call once from a server
-- entry script.
function Exporter.start(collectStats: () -> any)
	task.spawn(function()
		while true do
			task.wait(INTERVAL)
			Exporter.flush(collectStats())
		end
	end)
end

return Exporter
