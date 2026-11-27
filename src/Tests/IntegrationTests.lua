--!strict
-- Integration checks for Detector + History + Processor result mapping.

local Shared = script.Parent.Parent:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local History = require(Shared:WaitForChild("History"))
local Processor = require(Shared:WaitForChild("Processor"))

return function(test: (string, string, () -> string?) -> ())
	test("processor NEW result", "valid unseen code returns NEW and is recorded", function()
		local history = assert(History.new())
		local result = Processor.process("New code: ALPHA BETA GAMMA", "auto", Config.copy(), history)
		assert(result.status == "NEW" and history:count() == 1)
		return result.status .. " / " .. result.code
	end)

	test("processor DUPLICATE result", "repeated code returns DUPLICATE", function()
		local history = assert(History.new())
		Processor.process("Code: 0042", "auto", Config.copy(), history)
		local result = Processor.process("code: 0042", "auto", Config.copy(), history)
		assert(result.status == "DUPLICATE" and history:count() == 1)
		return result.status
	end)

	test("processor IGNORED result", "unrecognized text maps to IGNORED", function()
		local result = Processor.process("Welcome to the server", "auto", Config.copy(), assert(History.new()))
		assert(result.status == "IGNORED" and result.reason == "no_prefix")
		return result.status .. " / " .. result.reason
	end)

	test("processor ERROR result", "invalid mode maps to ERROR", function()
		local result = Processor.process("Code: 0042", "9", Config.copy(), assert(History.new()))
		assert(result.status == "ERROR" and result.reason == "invalid_mode")
		return result.status .. " / " .. result.reason
	end)

	test("processor history separation", "both formats are tracked independently", function()
		local history = assert(History.new())
		local digits = Processor.process("Code: 0042", "auto", Config.copy(), history)
		local words = Processor.process("Code: ALPHA BETA GAMMA", "auto", Config.copy(), history)
		assert(digits.status == "NEW" and words.status == "NEW" and history:count() == 2)
		return tostring(history:count()) .. " entries"
	end)

	test("processor invalid input is UI-safe", "nil input returns IGNORED and does not throw", function()
		local ok, result = pcall(function()
			return Processor.process(nil, "auto", Config.copy(), assert(History.new()))
		end)
		assert(ok and result.status == "IGNORED")
		return result.status
	end)

	test("processor malformed history service", "missing history dependency returns ERROR", function()
		local result = Processor.process("Code: 0042", "auto", Config.copy(), nil)
		assert(result.status == "ERROR" and result.reason == "invalid_history")
		return result.reason
	end)

	test("processor history exception handling", "unexpected history errors are converted to ERROR", function()
		local brokenHistory = {
			add = function()
				error("simulated history failure")
			end,
		}
		local result = Processor.process("Code: 0042", "auto", Config.copy(), brokenHistory)
		assert(result.status == "ERROR" and result.reason == "history_exception")
		return result.reason
	end)

	test("processor ambiguous announcement", "ambiguous pasted text is ignored and not recorded", function()
		local history = assert(History.new())
		local result = Processor.process("Code: 0042\nCode: 0043", "auto", Config.copy(), history)
		assert(result.status == "IGNORED" and result.reason == "ambiguous_announcement" and history:count() == 0)
		return result.reason
	end)
end
