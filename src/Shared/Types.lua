--!strict
-- Shared type definitions for editor autocomplete and static checking.

export type DetectionMode = "3" | "4" | "auto"
export type CodeFormat = "three-word" | "four-digit"
export type Status = "NEW" | "DUPLICATE" | "IGNORED" | "ERROR"

export type Config = {
	defaultMode: DetectionMode,
	requirePrefix: boolean,
	prefixes: {string},
	maxInputLength: number,
	maxHistoryEntries: number,
	theme: "dark" | "light",
}

export type DetectionResult = {
	ok: boolean,
	code: string?,
	mode: DetectionMode?,
	format: CodeFormat?,
	reason: string?,
	message: string?,
}

export type HistoryEntry = {
	code: string,
	format: CodeFormat,
	timestamp: number,
	lastSeenTimestamp: number,
	lastStatus: "NEW" | "DUPLICATE",
	duplicateCount: number,
}

export type ProcessResult = {
	status: Status,
	code: string?,
	format: CodeFormat?,
	timestamp: number?,
	reason: string?,
	message: string?,
}

return {}
