-- Structured telemetry for Gate G1 measurement (retention, skill/death patterns).
-- Events buffer in a module-level queue and flush out-of-band so logging never
-- blocks gameplay. Every event shares the envelope { event, userId, timestamp, data }.
--
-- Call SessionLogger.start() exactly once from a server entry script to begin the
-- periodic flush loop. Requiring the module does NOT start the loop, so it stays
-- side-effect-free for tests.
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- External ingest endpoint. Only used on live servers; Studio prints instead.
local DASHBOARD_URL = "https://telemetry.lostblox.gg/ingest"
local FLUSH_INTERVAL = 60

local SessionLogger = {}

-- Module-level queue (not per-player) so a player table cleaned up before flush
-- never strands its events.
SessionLogger._queue = {} :: { { event: string, userId: number, timestamp: number, data: { [string]: any } } }

local function enqueue(event: string, userId: number, data: { [string]: any }?)
	table.insert(SessionLogger._queue, {
		event = event,
		userId = userId,
		timestamp = os.time(),
		data = data or {},
	})
end

-- Generic event entry point for systems that emit their own event types
-- (e.g. MovementValidator's teleport_flag). Same envelope as the named helpers.
function SessionLogger.log(event: string, userId: number, data: { [string]: any }?)
	enqueue(event, userId, data)
end

-- ── Event API (one function per event type; only userId is logged, no PII) ──
function SessionLogger.logSessionStart(userId: number, class: string, iLvl: number)
	enqueue("session_start", userId, { class = class, iLvl = iLvl })
end

function SessionLogger.logSessionEnd(userId: number, durationSeconds: number, cause: string)
	enqueue("session_end", userId, { duration_seconds = durationSeconds, cause = cause })
	-- Flush immediately so the session's tail isn't lost if the server drains.
	SessionLogger.flush()
end

function SessionLogger.logDeath(userId: number, killer: string, zone: string, sessionElapsed: number)
	enqueue("death", userId, { killer = killer, zone = zone, session_elapsed = sessionElapsed })
end

function SessionLogger.logBossKill(userId: number, bossId: string, timeToKill: number, partySize: number)
	enqueue("boss_kill", userId, { boss_id = bossId, time_to_kill = timeToKill, party_size = partySize })
end

function SessionLogger.logSkillUsed(userId: number, skillId: string, hit: boolean, damage: number)
	enqueue("skill_used", userId, { skill_id = skillId, hit = hit, damage = damage })
end

function SessionLogger.getQueueSize(): number
	return #SessionLogger._queue
end

-- Encodes the whole queue as a single JSON array and sends one POST (or prints
-- in Studio). Clearing the queue before the I/O means a failed POST drops a
-- batch rather than double-sending; telemetry loss is acceptable, gameplay stalls are not.
function SessionLogger.flush()
	if #SessionLogger._queue == 0 then
		return
	end
	local batch = SessionLogger._queue
	SessionLogger._queue = {}

	local json = HttpService:JSONEncode(batch)
	if RunService:IsStudio() then
		print("[SessionLogger] " .. json)
	else
		pcall(function()
			HttpService:PostAsync(DASHBOARD_URL, json, Enum.HttpContentType.ApplicationJson)
		end)
	end
end

function SessionLogger.start()
	task.spawn(function()
		while true do
			task.wait(FLUSH_INTERVAL)
			SessionLogger.flush()
		end
	end)
end

return SessionLogger
