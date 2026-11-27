--!strict
-- Run with the Studio Command Bar:
-- require(game.ReplicatedStorage.CodeSentry.Tests.TestRunner).run()

local TestRunner = {}

local suites = {
	require(script.Parent:WaitForChild("DetectorTests")),
	require(script.Parent:WaitForChild("HistoryTests")),
	require(script.Parent:WaitForChild("IntegrationTests")),
}

function TestRunner.run()
	local report = {
		passed = 0,
		failed = 0,
		total = 0,
		results = {},
	}

	local function test(name: string, expected: string, callback: () -> string?)
		report.total += 1
		local ok, actual = pcall(callback)
		local status = ok and "PASS" or "FAIL"
		local result = {
			name = name,
			expected = expected,
			actual = ok and tostring(actual or "Assertions passed") or tostring(actual),
			status = status,
		}
		table.insert(report.results, result)
		if ok then
			report.passed += 1
			print(string.format("PASS | %02d | %s | expected: %s | actual: %s", report.total, name, expected, result.actual))
		else
			report.failed += 1
			warn(string.format("FAIL | %02d | %s | expected: %s | actual: %s", report.total, name, expected, result.actual))
		end
	end

	for suiteIndex, suite in ipairs(suites) do
		local ok, err = pcall(function()
			suite(test)
		end)
		if not ok then
			test("test suite " .. tostring(suiteIndex) .. " execution", "suite finishes without an uncaught error", function()
				error(tostring(err))
			end)
		end
	end

	print(string.rep("-", 72))
	print(string.format("CodeSentry tests: %d passed, %d failed, %d total", report.passed, report.failed, report.total))
	print(report.failed == 0 and "ALL TESTS PASSED" or "TESTS FAILED")
	return report
end

return TestRunner
