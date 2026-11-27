--!strict
-- Detector unit tests. Executed by TestRunner from Roblox Studio.

local Shared = script.Parent.Parent:WaitForChild("Shared")
local Detector = require(Shared:WaitForChild("Detector"))
local Config = require(Shared:WaitForChild("Config"))

return function(test: (string, string, () -> string?) -> ())
	local config = Config.copy()

	test("valid three-word code", "Code: Alpha Beta Gamma returns normalized three-word code", function()
		local result = Detector.detect("Code: Alpha Beta Gamma", "3", config)
		assert(result.ok and result.code == "ALPHA BETA GAMMA" and result.format == "three-word")
		return result.code
	end)

	test("valid four-digit code", "Code: 1234 returns a four-digit string", function()
		local result = Detector.detect("Code: 1234", "4", config)
		assert(result.ok and result.code == "1234" and result.format == "four-digit")
		return result.code
	end)

	test("auto mode", "Auto identifies both supported formats", function()
		local words = Detector.detect("New code: alpha beta gamma", "auto", config)
		local digits = Detector.detect("Code: 0007", "auto", config)
		assert(words.ok and words.mode == "3")
		assert(digits.ok and digits.mode == "4")
		return words.format .. " + " .. digits.format
	end)

	test("leading-zero preservation", "0007 remains a four-character string", function()
		local result = Detector.detect("Code: 0007", "4", config)
		assert(result.ok and result.code == "0007" and type(result.code) == "string")
		return result.code
	end)

	test("lowercase prefix", "lowercase prefix is accepted", function()
		local result = Detector.detect("new code: sun moon star", "3", config)
		assert(result.ok and result.code == "SUN MOON STAR")
		return result.code
	end)

	test("uppercase prefix", "uppercase prefix is accepted", function()
		local result = Detector.detect("NEW CODE: red green blue", "3", config)
		assert(result.ok and result.code == "RED GREEN BLUE")
		return result.code
	end)

	test("mixed-case prefix", "mixed-case prefix is accepted", function()
		local result = Detector.detect("ReDeEm CoDe: fire water earth", "3", config)
		assert(result.ok and result.code == "FIRE WATER EARTH")
		return result.code
	end)

	test("extra whitespace", "tabs and repeated spaces normalize consistently", function()
		local result = Detector.detect("  NEW   CODE:   alpha\t\tbeta   gamma  ", "3", config)
		assert(result.ok and result.code == "ALPHA BETA GAMMA")
		return result.code
	end)

	test("empty input", "empty input returns empty_input", function()
		local result = Detector.detect("", "auto", config)
		assert(not result.ok and result.reason == "empty_input")
		return result.reason
	end)

	test("nil input", "nil input returns invalid_input without throwing", function()
		local result = Detector.detect(nil, "auto", config)
		assert(not result.ok and result.reason == "invalid_input")
		return result.reason
	end)

	test("non-string input", "number input returns invalid_input", function()
		local result = Detector.detect(1234, "4", config)
		assert(not result.ok and result.reason == "invalid_input")
		return result.reason
	end)

	test("invalid word count", "two or four words are rejected", function()
		local two = Detector.detect("Code: alpha beta", "3", config)
		local four = Detector.detect("Code: alpha beta gamma delta", "3", config)
		assert(not two.ok and two.reason == "invalid_word_count")
		assert(not four.ok and four.reason == "invalid_word_count")
		return two.reason .. " + " .. four.reason
	end)

	test("invalid digit count", "three-digit and five-digit candidates are rejected", function()
		local short = Detector.detect("Code: 123", "4", config)
		local long = Detector.detect("Code: 12345", "4", config)
		assert(not short.ok and short.reason == "invalid_digit_count")
		assert(not long.ok and long.reason == "invalid_digit_count")
		return short.reason .. " + " .. long.reason
	end)

	test("invalid characters", "punctuation and embedded digits are not valid code words", function()
		local comma = Detector.detect("Code: ALPHA, BETA, GAMMA", "3", config)
		local embedded = Detector.detect("Code: ALPHA BE7A GAMMA", "3", config)
		local repeated = Detector.detect("Code: ICE--CREAM TOP HAT", "3", config)
		assert(not comma.ok and not embedded.ok and not repeated.ok)
		return comma.reason .. ", " .. embedded.reason .. ", " .. repeated.reason
	end)

	test("internal apostrophe and hyphen", "O'NEIL and ICE-CREAM are accepted", function()
		local result = Detector.detect("Code: O'NEIL ICE-CREAM TOP", "3", config)
		assert(result.ok and result.code == "O'NEIL ICE-CREAM TOP")
		return result.code
	end)

	test("markdown wrappers", "bold prefix and inline-code wrappers do not change the code", function()
		local words = Detector.detect("**Code:** **ALPHA BETA GAMMA**", "3", config)
		local digits = Detector.detect("**Code:** `0042`", "4", config)
		assert(words.ok and words.code == "ALPHA BETA GAMMA")
		assert(digits.ok and digits.code == "0042")
		return words.code .. " + " .. digits.code
	end)

	test("standalone malformed token", "decoration-only token is not silently ignored", function()
		local result = Detector.detect("Code: ALPHA BETA GAMMA ***", "3", config)
		assert(not result.ok)
		return result.reason
	end)

	test("missing prefix", "bare code is rejected by default", function()
		local result = Detector.detect("ALPHA BETA GAMMA", "3", config)
		assert(not result.ok and result.reason == "no_prefix")
		return result.reason
	end)

	test("unknown prefix", "unrecognized prefix is rejected", function()
		local result = Detector.detect("promo: ALPHA BETA GAMMA", "3", config)
		assert(not result.ok and result.reason == "no_prefix")
		return result.reason
	end)

	test("custom prefix configuration", "a custom prefix is recognized", function()
		local custom = Config.copy({ prefixes = { "promo:" } })
		local result = Detector.detect("PROMO: ALPHA BETA GAMMA", "3", custom)
		assert(result.ok and result.code == "ALPHA BETA GAMMA")
		return result.code
	end)

	test("multiple announcements", "two recognized prefixes return ambiguous_announcement", function()
		local result = Detector.detect("Code: 0042\nNew code: ALPHA BETA GAMMA", "auto", config)
		assert(not result.ok and result.reason == "ambiguous_announcement")
		return result.reason
	end)

	test("malformed announcement", "a code interrupted by a sentence delimiter is rejected", function()
		local result = Detector.detect("Code: ALPHA, BETA, GAMMA", "3", config)
		assert(not result.ok and result.reason == "invalid_word_count")
		return result.reason
	end)

	test("invalid configuration", "malformed prefixes return invalid_config", function()
		local bad = { prefixes = { "" }, requirePrefix = true }
		local result = Detector.detect("Code: 1234", "4", bad)
		assert(not result.ok and result.reason == "invalid_config")
		return result.reason
	end)

	test("newline in prefix configuration", "prefixes cannot span announcement lines", function()
		local bad = Config.copy({ prefixes = { "new\ncode:" } })
		local result = Detector.detect("Code: 1234", "4", bad)
		assert(not result.ok and result.reason == "invalid_config")
		return result.reason
	end)

	test("valid mode helper", "the detector recognizes 3, 4 and auto only", function()
		assert(Detector.isValidMode("3") and Detector.isValidMode("4") and Detector.isValidMode("auto"))
		assert(not Detector.isValidMode("5") and not Detector.isValidMode("words"))
		return "3 / 4 / auto accepted"
	end)

	test("invalid mode", "unknown detection mode returns invalid_mode", function()
		local result = Detector.detect("Code: 1234", "five", config)
		assert(not result.ok and result.reason == "invalid_mode")
		return result.reason
	end)

	test("large input handling", "input beyond maxInputLength returns input_too_large", function()
		local smallLimit = Config.copy({ maxInputLength = 32 })
		local result = Detector.detect("Code: " .. string.rep("x", 40), "3", smallLimit)
		assert(not result.ok and result.reason == "input_too_large")
		return result.reason
	end)

	test("multiple code-like tokens", "mode 4 does not skip leading text to capture a later number", function()
		local result = Detector.detect("Code: reward 0042", "4", config)
		assert(not result.ok and result.reason == "no_digits")
		return result.reason
	end)

	test("bare mode is opt-in", "requirePrefix=false accepts a message containing only a code", function()
		local bare = Config.copy({ requirePrefix = false })
		local result = Detector.detect("0042", "4", bare)
		assert(result.ok and result.code == "0042")
		return result.code
	end)
end
