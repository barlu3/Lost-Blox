--!strict
-- Server-side anomaly detection. Does not reverse-engineer exploits; it detects
-- impossible outcomes (teleport speed, damage above the theoretical max, casts
-- inside cooldown) and accumulates a severity score. Players are only actioned
-- on a score threshold, never a single flag — false positives are inevitable.
--
-- The check + scoring functions are pure and unit-testable; the per-heartbeat
-- loop, kicks, and ban-review DataStore writes are the thin runtime layer.

local BehavioralDetector = {}

BehavioralDetector.SPEED_TOLERANCE = 1.25
BehavioralDetector.DAMAGE_TOLERANCE = 1.10
BehavioralDetector.COOLDOWN_TOLERANCE = 0.80
BehavioralDetector.KICK_THRESHOLD = 10
BehavioralDetector.BAN_REVIEW_THRESHOLD = 30
BehavioralDetector.SCORE_WINDOW = 60

BehavioralDetector.FLAG_SCORE = {
	teleport = 3,
	damage_overflow = 5,
	cooldown_bypass = 2,
}

-- Effects that legitimately raise movement speed; skip teleport flagging if active.
BehavioralDetector.SPEED_WHITELIST = {
	launch_pad_boost = true,
	sprint_buff = true,
}

-- ── Pure checks (return a flag type, or nil when clean) ─────────────────────
function BehavioralDetector.checkPosition(
	lastPos: Vector3,
	currentPos: Vector3,
	dt: number,
	maxWalkSpeed: number,
	hasWhitelistedEffect: boolean?
): string?
	if hasWhitelistedEffect then
		return nil
	end
	local speed = (currentPos - lastPos).Magnitude / dt
	if speed > maxWalkSpeed * BehavioralDetector.SPEED_TOLERANCE then
		return "teleport"
	end
	return nil
end

function BehavioralDetector.checkDamage(dealt: number, theoreticalMax: number): string?
	if dealt > theoreticalMax * BehavioralDetector.DAMAGE_TOLERANCE then
		return "damage_overflow"
	end
	return nil
end

function BehavioralDetector.checkCooldown(now: number, lastCast: number, cooldown: number): string?
	if (now - lastCast) < cooldown * BehavioralDetector.COOLDOWN_TOLERANCE then
		return "cooldown_bypass"
	end
	return nil
end

-- ── Score window ────────────────────────────────────────────────────────────
export type DetectorState = {
	flags: { { type: string, score: number, time: number } },
	sessionScore: number,
}

function BehavioralDetector.newState(): DetectorState
	return { flags = {}, sessionScore = 0 }
end

function BehavioralDetector.addFlag(state: DetectorState, flagType: string, now: number)
	local score = BehavioralDetector.FLAG_SCORE[flagType] or 0
	table.insert(state.flags, { type = flagType, score = score, time = now })
	state.sessionScore += score
end

function BehavioralDetector.recentScore(state: DetectorState, now: number, window: number?): number
	local w = window or BehavioralDetector.SCORE_WINDOW
	local total = 0
	for _, flag in state.flags do
		if (now - flag.time) <= w then
			total += flag.score
		end
	end
	return total
end

function BehavioralDetector.shouldKick(state: DetectorState, now: number): boolean
	return BehavioralDetector.recentScore(state, now) >= BehavioralDetector.KICK_THRESHOLD
end

function BehavioralDetector.shouldBanReview(state: DetectorState): boolean
	return state.sessionScore >= BehavioralDetector.BAN_REVIEW_THRESHOLD
end

return BehavioralDetector
