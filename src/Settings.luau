--!strict
--[[
	Pancakes runtime configuration

	These values are loaded when Pancakes is required. They can also be changed
	at runtime with Pancakes.Configure(), but changing wire-sensitive settings
	while messages are in flight can make otherwise-valid buffers undecodable.

	WIRE-SENSITIVE SETTINGS
		commonKeys and stringCacheMinLength must have identical values on every
		writer and reader. This includes the order of entries in commonKeys.

	RECOMMENDED NETWORK DEFAULTS
		Keep schemaValidationEnabled and strictBoundsChecking enabled when data
		can originate from clients. Disable validation only for measured, trusted
		hot paths after schemas are stable.

	PERFORMANCE NOTES
		The defaults favor predictable performance and safe decoding. Settings
		that trade correctness guarantees for speed are explicitly marked unsafe.
]]

export type SerializerConfig = {
	poolingEnabled: boolean,
	writerPoolMaxPerBucket: number,
	readerPoolMax: number,
	rleThreshold: number,
	sortedKeysCacheEnabled: boolean,
	commonKeys: {string},
	patternKeysEnabled: boolean,
	sortedKeysCacheTrustMode: boolean,
	stringCacheMinLength: number,
	schemaValidationEnabled: boolean,
	strictBoundsChecking: boolean,
	maxDeclaredCountBytes: number,
	debugAsserts: boolean,
}

local DEFAULT_COMMON_KEYS: {string} = {}

local Settings: SerializerConfig = {
	poolingEnabled = true,
	sortedKeysCacheEnabled = true,
	schemaValidationEnabled = true,
	strictBoundsChecking = true,
	patternKeysEnabled = false,
	sortedKeysCacheTrustMode = false,
	debugAsserts = false,
	writerPoolMaxPerBucket = 8,
	readerPoolMax = 16,
	rleThreshold = 0.3,
	stringCacheMinLength = 16,
	maxDeclaredCountBytes = 1,

	commonKeys = DEFAULT_COMMON_KEYS,
}

return Settings
