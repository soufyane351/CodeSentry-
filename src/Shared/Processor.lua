--!strict
-- Orchestrates parser + session history and maps outcomes to UI statuses.

local Detector = require(script.Parent.Detector)
local Processor = {}

export type ProcessResult = {
	status: string,
	code: string?,
	format: string?,
	timestamp: number?,
	reason: string?,
	message: string?,
}

function Processor.process(text: any, mode: any, config: any, history: any): ProcessResult
	local ok, detection = pcall(function()
		return Detector.detect(text, mode, config)
	end)
	if not ok then
		return { status = "ERROR", reason = "detector_exception", message = tostring(detection) }
	end
	if not detection.ok then
		local fatal = detection.reason == "invalid_config" or detection.reason == "invalid_mode"
		return {
			status = fatal and "ERROR" or "IGNORED",
			reason = detection.reason,
			message = detection.message,
		}
	end
	if type(history) ~= "table" or type(history.add) ~= "function" then
		return { status = "ERROR", reason = "invalid_history", message = "history service is unavailable" }
	end

	local historyOk, state, entry = pcall(function()
		return history:add(detection.code, detection.format)
	end)
	if not historyOk then
		return { status = "ERROR", reason = "history_exception", message = tostring(state) }
	end
	if state == "added" then
		return {
			status = "NEW",
			code = detection.code,
			format = detection.format,
			timestamp = entry.lastSeenTimestamp or entry.timestamp,
		}
	elseif state == "duplicate" then
		return {
			status = "DUPLICATE",
			code = detection.code,
			format = detection.format,
			timestamp = entry.lastSeenTimestamp or entry.timestamp,
		}
	end
	return {
		status = "ERROR",
		reason = "history_rejected",
		message = tostring(entry or "history could not record the code"),
	}
end

return Processor
