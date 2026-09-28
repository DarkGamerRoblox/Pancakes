--!strict
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
	maxBufferBytes: number,
	maxSequenceKeypoints: number,
	maxInstancePathDepth: number,
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
	maxBufferBytes = 16 * 1024 * 1024,
	maxSequenceKeypoints = 31,
	maxInstancePathDepth = 270,

	commonKeys = DEFAULT_COMMON_KEYS,
}

return Settings
