--!strict
-- Pure dialogue helpers (typewriter timing + voice-blip selection) shared by the
-- DialogueBox UI. Factored out so the reveal rate and blip rules are testable
-- without a live Sound or RenderStepped loop.

local DialogueLogic = {}

DialogueLogic.CHAR_DELAY = 0.025 -- seconds per character → 40 chars/sec
DialogueLogic.VOWEL_VOLUME = 1.1
DialogueLogic.CONSONANT_VOLUME = 1.0
DialogueLogic.PITCH_JITTER = 0.05

local VOWELS = { a = true, e = true, i = true, o = true, u = true }

function DialogueLogic.isVowel(char: string): boolean
	return VOWELS[char:lower()] == true
end

function DialogueLogic.revealDuration(text: string): number
	return #text * DialogueLogic.CHAR_DELAY
end

export type Blip = { volume: number, playbackSpeed: number }

-- Returns the blip parameters for one character, or nil for characters that make
-- no sound (punctuation, whitespace). rng defaults to math.random; inject for
-- deterministic tests. PlaybackSpeed is pitch ± PITCH_JITTER.
function DialogueLogic.blipFor(char: string, pitch: number, rng: (() -> number)?): Blip?
	if not char:match("%a") then
		return nil
	end
	local roll = (rng or math.random)()
	local jitter = (roll * 2 - 1) * DialogueLogic.PITCH_JITTER
	return {
		volume = if DialogueLogic.isVowel(char) then DialogueLogic.VOWEL_VOLUME else DialogueLogic.CONSONANT_VOLUME,
		playbackSpeed = pitch + jitter,
	}
end

return DialogueLogic
