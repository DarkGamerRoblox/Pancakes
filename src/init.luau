--!strict
--!native
--!optimize 2
--[[
   _____             _      ______                                           _    
  |  __ \           | |    |  ____|                                         | |   
  | |  | | __ _ _ __| | __ | |__ _ __ __ _ _ __ ___   _____      _____  _ __| | __
  | |  | |/ _` | '__| |/ / |  __| '__/ _` | '_ ` _ \ / _ \ \ /\ / / _ \| '__| |/ /
  | |__| | (_| | |  |   <  | |  | | | (_| | | | | | |  __/\ V  V / (_) | |  |   < 
  |_____/ \__,_|_|  |_|\_\ |_|  |_|  \__,_|_| |_| |_|\___| \_/\_/ \___/|_|  |_|\_\

                        	 Author: @DarkGamer
                      	  Roblox User: lol_GG1HACKE
			            Pancakes binary serialization library.
		   	 Last updated: 09/07/2026 | BUILD_ID "1.0.0-pancakes"
       	                    License: MIT License

    A high-performance binary serialization library for Roblox that efficiently
    encodes Lua values and Roblox data types into compact byte buffers.
]]
local Pancakes = {}

local mathAbs        = math.abs
local mathFloor      = math.floor
local mathRound      = math.round
local mathMin        = math.min
local mathMax        = math.max
local mathHuge       = math.huge
local mathClamp      = math.clamp
local mathSqrt       = math.sqrt
local mathCeil       = math.ceil
local bit32band      = bit32.band
local bit32bor       = bit32.bor
local bit32lshift    = bit32.lshift
local bit32rshift    = bit32.rshift
local bit32arshift   = bit32.arshift
local bit32bxor      = bit32.bxor
local tableCreate    = table.create
local tableInsert    = table.insert
local tableConcat    = table.concat
local tableSort      = table.sort
local tableClear     = table.clear
local tableClone     = table.clone
local tableIsFrozen  = table.isfrozen
local bufferCreate   = buffer.create
local bufferCopy     = buffer.copy
local bufferReadU8   = buffer.readu8
local bufferWriteU8  = buffer.writeu8
local bufferReadU16  = buffer.readu16
local bufferWriteU16 = buffer.writeu16
local bufferReadU32  = buffer.readu32
local bufferWriteU32 = buffer.writeu32
local bufferReadI8   = buffer.readi8
local bufferWriteI8  = buffer.writei8
local bufferReadI16  = buffer.readi16
local bufferWriteI16 = buffer.writei16
local bufferReadF32  = buffer.readf32
local bufferWriteF32 = buffer.writef32
local bufferReadF64  = buffer.readf64
local bufferWriteF64 = buffer.writef64
local bufferReadStr  = buffer.readstring
local bufferWriteStr = buffer.writestring
local bufferLen      = buffer.len
local bufferToString = buffer.tostring
local stringSub      = string.sub
local stringFind     = string.find
local stringFormat   = string.format
local stringMatch    = string.match
local typeofFn       = typeof

local HttpService = game:GetService("HttpService")
local SerializerSettings = require(script.Settings)

local TYPE_NIL               = 0
local TYPE_BOOLEAN_FALSE      = 1
local TYPE_BOOLEAN_TRUE       = 2
local TYPE_NUMBER_ZERO        = 3
local TYPE_NUMBER_ONE         = 4
local TYPE_NUMBER_I8          = 5
local TYPE_NUMBER_I16         = 6
local TYPE_NUMBER_F32         = 7
local TYPE_NUMBER_F64         = 8
local TYPE_STRING_EMPTY       = 9
local TYPE_STRING_TINY        = 10
local TYPE_STRING_SHORT       = 11
local TYPE_TABLE_TINY         = 12
local TYPE_TABLE              = 13
local TYPE_ARRAY_DELTA        = 14
local TYPE_ARRAY_RLE          = 15
local TYPE_VECTOR3            = 16
local TYPE_VECTOR3_INT        = 17
local TYPE_VECTOR2            = 18
local TYPE_VECTOR2_INT        = 19
local TYPE_CFRAME             = 20
local TYPE_CFRAME_SIMPLE      = 21
local TYPE_COLOR3             = 22
local TYPE_UDIM               = 23
local TYPE_UDIM2              = 24
local TYPE_INSTANCE           = 25
local TYPE_ENUM               = 26
local TYPE_DATETIME           = 27
local TYPE_NUMBER_U32         = 28
local TYPE_NUMBER_ZIGZAG      = 29
local TYPE_TABLE_SEQUENTIAL   = 30
local TYPE_SPECIAL            = 31

local SUBTYPE_VECTOR3INT16        = 0
local SUBTYPE_VECTOR2INT16        = 1
local SUBTYPE_BRICKCOLOR          = 2
local SUBTYPE_NUMBER_SEQUENCE     = 3
local SUBTYPE_COLOR_SEQUENCE      = 4
local SUBTYPE_NUMBER_RANGE        = 5
local SUBTYPE_NUMBER_NIBBLE       = 6
local SUBTYPE_STRING_COMMON       = 7
local SUBTYPE_VECTOR3_QUANTIZED   = 8
local SUBTYPE_BOOLEAN_ARRAY       = 9
local SUBTYPE_CUSTOM              = 10
local SUBTYPE_DENSE_ARRAY         = 11
local SUBTYPE_KEY_REFERENCE       = 12
local SUBTYPE_TABLE_SHAPE         = 13
local SUBTYPE_TYPED_TABLE_SHAPE   = 14
local SUBTYPE_TYPED_RECORD_ARRAY  = 15

local ADAPT_ZERO     = 0
local ADAPT_ONE      = 1
local ADAPT_NIBBLE   = 2
local ADAPT_I8       = 3
local ADAPT_I16      = 4
local ADAPT_U32      = 5
local ADAPT_ZIGZAG32 = 6
local ADAPT_F32      = 7
local ADAPT_F64      = 8

export type SerializerConfig = SerializerSettings.SerializerConfig
local Config: SerializerConfig = SerializerSettings :: SerializerConfig

local INSTANCE_PATH_SCRATCH: {string} = {}

local F32_PROBE = bufferCreate(4)
local function isExactF32(value: number): boolean
	bufferWriteF32(F32_PROBE, 0, value)
	return bufferReadF32(F32_PROBE, 0) == value
end

local COMMON_KEY_MAP: {[string]: number} = {}
local function rebuildCommonKeyMap(): ()
	table.clear(COMMON_KEY_MAP)
	for i, key in ipairs(Config.commonKeys) do
		COMMON_KEY_MAP[key] = i - 1
	end
end
rebuildCommonKeyMap()

function Pancakes.Configure(overrides: {
	poolingEnabled: boolean?,
	writerPoolMaxPerBucket: number?,
	readerPoolMax: number?,
	rleThreshold: number?,
	sortedKeysCacheEnabled: boolean?,
	commonKeys: {string}?,
	patternKeysEnabled: boolean?,
	sortedKeysCacheTrustMode: boolean?,
	stringCacheMinLength: number?,
	schemaValidationEnabled: boolean?,
	strictBoundsChecking: boolean?,
	maxDeclaredCountBytes: number?,
	debugAsserts: boolean?,
	}): ()
	if overrides.poolingEnabled ~= nil then
		Config.poolingEnabled = overrides.poolingEnabled
	end
	if overrides.writerPoolMaxPerBucket ~= nil then
		assert(overrides.writerPoolMaxPerBucket >= 0, "[Pancakes] writerPoolMaxPerBucket must be >= 0")
		Config.writerPoolMaxPerBucket = overrides.writerPoolMaxPerBucket
	end
	if overrides.readerPoolMax ~= nil then
		assert(overrides.readerPoolMax >= 0, "[Pancakes] readerPoolMax must be >= 0")
		Config.readerPoolMax = overrides.readerPoolMax
	end
	if overrides.rleThreshold ~= nil then
		assert(overrides.rleThreshold >= 0 and overrides.rleThreshold <= 1, "[Pancakes] rleThreshold must be between 0 and 1")
		Config.rleThreshold = overrides.rleThreshold
	end
	if overrides.sortedKeysCacheEnabled ~= nil then
		Config.sortedKeysCacheEnabled = overrides.sortedKeysCacheEnabled
	end
	if overrides.commonKeys ~= nil then
		assert(#overrides.commonKeys <= 32, "[Pancakes] commonKeys supports at most 32 entries (5-bit index)")
		Config.commonKeys = overrides.commonKeys
		rebuildCommonKeyMap()
	end
	if overrides.patternKeysEnabled ~= nil then
		Config.patternKeysEnabled = overrides.patternKeysEnabled
	end
	if overrides.sortedKeysCacheTrustMode ~= nil then
		Config.sortedKeysCacheTrustMode = overrides.sortedKeysCacheTrustMode
	end
	if overrides.stringCacheMinLength ~= nil then
		assert(overrides.stringCacheMinLength >= 0, "[Pancakes] stringCacheMinLength must be >= 0")
		Config.stringCacheMinLength = overrides.stringCacheMinLength
	end
	if overrides.schemaValidationEnabled ~= nil then
		Config.schemaValidationEnabled = overrides.schemaValidationEnabled
	end
	if overrides.strictBoundsChecking ~= nil then
		Config.strictBoundsChecking = overrides.strictBoundsChecking
	end
	if overrides.maxDeclaredCountBytes ~= nil then
		assert(overrides.maxDeclaredCountBytes >= 1, "[Pancakes] maxDeclaredCountBytes must be >= 1")
		Config.maxDeclaredCountBytes = overrides.maxDeclaredCountBytes
	end
	if overrides.debugAsserts ~= nil then
		Config.debugAsserts = overrides.debugAsserts
	end
end

function Pancakes.GetConfig(): SerializerConfig
	return {
		poolingEnabled           = Config.poolingEnabled,
		writerPoolMaxPerBucket   = Config.writerPoolMaxPerBucket,
		readerPoolMax            = Config.readerPoolMax,
		rleThreshold             = Config.rleThreshold,
		sortedKeysCacheEnabled   = Config.sortedKeysCacheEnabled,
		commonKeys               = table.clone(Config.commonKeys),
		patternKeysEnabled       = Config.patternKeysEnabled,
		sortedKeysCacheTrustMode = Config.sortedKeysCacheTrustMode,
		stringCacheMinLength     = Config.stringCacheMinLength,
		schemaValidationEnabled  = Config.schemaValidationEnabled,
		strictBoundsChecking     = Config.strictBoundsChecking,
		maxDeclaredCountBytes    = Config.maxDeclaredCountBytes,
		debugAsserts             = Config.debugAsserts,
	}
end

local BIT_MASK: {number} = tableCreate(32, 0)
for i = 0, 31 do
	BIT_MASK[i] = bit32lshift(1, i) - 1
end

type StringCache = {
	forward: {[string]: number},
	reverse: {[number]: string},
	index:   number,
}

local stringCache: StringCache = {forward = {}, reverse = {}, index = 0}
local function resetStringCache(): ()
	table.clear(stringCache.forward)
	table.clear(stringCache.reverse)
	stringCache.index = 0
end

type AutoShapeEntry = {
	id: number,
	keys: {string},
	kinds: {number},
}

type AutoRecordPlan = {
	count: number,
	keys: {string},
	optional: {boolean},
	keyLookup: {[string]: boolean},
	kinds: {number},
	children: {[number]: AutoRecordPlan},
	staticOnly: boolean,
	dynamicValues: boolean,
	layout: number,
}

type StaticSchemaPlan = {
	headerCount: number,
	headerKeys: {string},
	headerOptional: {boolean},
	valueCount: number,
	valueKeys: {string},
	valueOptional: {boolean},
	optionalCount: number,
	kinds: {number},
	children: {[number]: StaticSchemaPlan},
	layout: number,
}

type StaticSchemaRootPlan = {
	arrayKey: string,
	tailU16Key: string,
	tailU32Key: string,
	elementPlan: StaticSchemaPlan,
}

type AutoRuntimeState = {
	keyForward: {[string]: number},
	keyReverse: {[number]: string},
	keyIndex: number,
	shapeBuckets: {[number]: {AutoShapeEntry}},
	shapeBucketCounts: {[number]: number},
	shapesById: {[number]: AutoShapeEntry},
	shapeIndex: number,
	recordPlanCache: {[any]: AutoRecordPlan},
	structuralKeyBuckets: {[number]: {{string}}},
	lastLayoutOffsets: {number},
	lastLayoutCount: number,
	lastLayoutValid: boolean,
	captureLayoutOffsets: boolean,
	decodePlanPool: {AutoRecordPlan},
	decodePlanIndex: number,
	lastDecodedRecordArray: {any}?,
	lastDecodedRecordPlan: AutoRecordPlan?,
	decodeBitBudget: number,
	schemaCompactWire: boolean,
	reset: () -> (),
	cacheKey: (str: string) -> (),
	findShape: (keys: {any}, count: number) -> (AutoShapeEntry?, boolean),
	registerShape: (keys: {any}, count: number, values: {[any]: any}) -> (),
	serializeKey: (writer: Writer, key: any) -> (),
	serializePlanKey: (writer: Writer, key: string) -> (),
	deserializeKey: (reader: Reader) -> any,
	deserializePlanKey: (reader: Reader) -> string,
	beginDecode: (buf: buffer) -> (),
	readCountChecked: (reader: Reader, minBitsPerEntry: number) -> number,
	readCountCheckedBits: (reader: Reader) -> number,
	buildRecordPlan: (value: {[any]: any}, depth: number) -> AutoRecordPlan?,
	buildArrayRecordPlan: (values: {any}, count: number) -> AutoRecordPlan?,
	recordMatchesPlan: (value: any, plan: AutoRecordPlan) -> boolean,
	recordValuesMatchPlan: (value: any, plan: AutoRecordPlan) -> boolean,
	writeRecordDataChecked: (writer: Writer, value: any, plan: AutoRecordPlan) -> boolean,
	writeRecordPlan: (writer: Writer, plan: AutoRecordPlan) -> (),
	readRecordPlan: (reader: Reader, depth: number) -> AutoRecordPlan,
	writeRecordData: (writer: Writer, value: {[any]: any}, plan: AutoRecordPlan) -> (),
	readRecordData: (reader: Reader, plan: AutoRecordPlan) -> {[string]: any},
	writeRecordColumns: (writer: Writer, values: {any}, count: number, plan: AutoRecordPlan) -> (),
	readRecordColumns: (reader: Reader, count: number, plan: AutoRecordPlan) -> {any},
	classifyDenseDatatype: (values: {any}, count: number) -> number,
	writeDenseDatatype: (writer: Writer, values: {any}, count: number, mode: number) -> (),
	readDenseDatatype: (reader: Reader, count: number, mode: number) -> {any},
	serializeRecordArray: (writer: Writer, values: {any}, count: number) -> boolean,
	deserializeRecordArray: (reader: Reader) -> {any},
}

local AutoRuntime: AutoRuntimeState = {
	keyForward = {},
	keyReverse = {},
	keyIndex = 0,
	shapeBuckets = {},
	shapeBucketCounts = {},
	shapesById = {},
	shapeIndex = 0,
	recordPlanCache = setmetatable({}, {__mode = "k"}),
	structuralKeyBuckets = {},
	lastLayoutOffsets = {},
	lastLayoutCount = 0,
	lastLayoutValid = false,
	captureLayoutOffsets = false,
	decodePlanPool = {},
	decodePlanIndex = 0,
	lastDecodedRecordArray = nil,
	lastDecodedRecordPlan = nil,
	decodeBitBudget = 0,
	schemaCompactWire = false,
} :: any

function AutoRuntime.reset(): ()
	table.clear(AutoRuntime.keyForward)
	table.clear(AutoRuntime.keyReverse)
	AutoRuntime.keyIndex = 0
	table.clear(AutoRuntime.shapeBucketCounts)
	table.clear(AutoRuntime.shapesById)
	AutoRuntime.shapeIndex = 0
	AutoRuntime.decodePlanIndex = 0
	AutoRuntime.lastDecodedRecordArray = nil
	AutoRuntime.lastDecodedRecordPlan = nil
	AutoRuntime.lastLayoutCount = 0
	AutoRuntime.lastLayoutValid = false
	AutoRuntime.captureLayoutOffsets = false
end

function AutoRuntime.cacheKey(str: string): ()
	if AutoRuntime.keyForward[str] ~= nil or AutoRuntime.keyIndex >= 255 then
		return
	end
	AutoRuntime.keyIndex += 1
	AutoRuntime.keyForward[str] = AutoRuntime.keyIndex
	AutoRuntime.keyReverse[AutoRuntime.keyIndex] = str
end

export type SerializedData = buffer
type WriteFn = (writer: Writer, value: any) -> ()
type ReadFn  = (reader: Reader) -> any

local KIND_BOOL_ARRAY        = 0
local KIND_NUM_ARRAY         = 1
local KIND_SEQ_NUMERIC       = 2
local KIND_SEQ_PATTERN       = 3
local KIND_GENERIC           = 4
local KIND_GENERIC_DENSE     = 5

local SEQ_STARTKEY_MIN = -32768
local SEQ_STARTKEY_MAX = 32767

local keyArena: {{any}} = {}
local arenaTop = 0

local function acquireKeyArray(): {any}
	arenaTop += 1
	local arr = keyArena[arenaTop]
	if arr == nil then
		arr = {}
		keyArena[arenaTop] = arr
	end
	tableClear(arr)
	return arr
end

local function releaseKeyArray(): ()
	arenaTop -= 1
end

local function resetKeyArena(): ()
	arenaTop = 0
end

local sortedKeysCache = setmetatable({}, {__mode = "k"}) :: {[any]: {sortedKeys: {any}, count: number}}
local function classifyTable(tbl: {any}): (number, number, number?, string?, {any}?)
	local n = #tbl
	if n > 0 and tbl[n] ~= nil then
		local denseCount = 0
		local dense = true
		local allBool, allNumber = true, true
		for key, value in tbl do
			denseCount += 1
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > n then
				dense = false
				break
			end
			local valueType = type(value)
			if valueType ~= "boolean" then allBool = false end
			if valueType ~= "number" then allNumber = false end
		end
		if dense and denseCount == n then
			if allBool and n >= 8 then
				return KIND_BOOL_ARRAY, n, nil, nil, nil
			end
			if allNumber and n >= 4 then
				local repeats = 0
				local allSmallDelta = true
				local previous = tbl[1]
				for i = 2, n do
					local value = tbl[i]
					local delta = value - previous
					if delta == 0 then repeats += 1 end
					if delta % 1 ~= 0 or delta < -7 or delta > 7 then allSmallDelta = false end
					previous = value
				end
				return KIND_NUM_ARRAY, n, repeats, if allSmallDelta then "small" else nil, nil
			end
			return KIND_GENERIC_DENSE, n, nil, nil, nil
		end
	end

	if Config.sortedKeysCacheEnabled then
		local cached = sortedKeysCache[tbl]
		if cached then
			if Config.sortedKeysCacheTrustMode then
				return KIND_GENERIC, cached.count, nil, nil, cached.sortedKeys
			end

			local count = 0
			for _ in tbl do
				count += 1
			end
			if count == cached.count then
				local valid = true
				for i = 1, count do
					if tbl[cached.sortedKeys[i]] == nil then
						valid = false
						break
					end
				end
				if valid then
					return KIND_GENERIC, count, nil, nil, cached.sortedKeys
				end
			end
		end
	end

	local count = 0
	local allNumericInt = true
	local allBool = true
	local allNumber = true
	local minKey: number = mathHuge
	local maxKey: number = -mathHuge
	local firstKey: any = nil
	local keys = acquireKeyArray()

	for k, v in tbl do
		count += 1
		keys[count] = k
		if firstKey == nil then firstKey = k end

		local kt = type(k)
		local vt = type(v)

		if kt ~= "number" or k % 1 ~= 0 or k < 1 then
			allNumericInt = false
		else
			if k < minKey then minKey = k end
			if k > maxKey then maxKey = k end
		end

		if vt ~= "boolean" then allBool = false end
		if vt ~= "number"  then allNumber = false end
	end

	if allBool and allNumericInt and count >= 8 and maxKey == count then
		releaseKeyArray()
		return KIND_BOOL_ARRAY, count, nil, nil, nil
	end

	if allNumber and allNumericInt and count >= 4 and maxKey == count then
		releaseKeyArray()
		return KIND_NUM_ARRAY, count, nil, nil, nil
	end

	if allNumericInt and count >= 4 and maxKey - minKey + 1 == count
		and minKey >= SEQ_STARTKEY_MIN and minKey <= SEQ_STARTKEY_MAX then
		releaseKeyArray()
		return KIND_SEQ_NUMERIC, count, minKey, nil, nil
	end

	if Config.patternKeysEnabled and count >= 4 and type(firstKey) == "string" then
		local pat = stringMatch(firstKey, "^(.-)%d+$")
		if pat and #pat > 0 then
			local isPattern = true
			for i = 1, count do
				if tbl[pat .. i] == nil then
					isPattern = false
					break
				end
			end
			if isPattern then
				releaseKeyArray()
				return KIND_SEQ_PATTERN, count, nil, pat, nil
			end
		end
	end

	return KIND_GENERIC, count, nil, nil, keys
end

local function shouldUseRLE(tbl: {any}, count: number): boolean
	if count < 4 then return false end
	local repeats = 0
	for i = 2, count do
		if tbl[i] == tbl[i - 1] then repeats += 1 end
	end
	return repeats > count * Config.rleThreshold
end

export type Writer = {
	EnsureCapacity: (self: Writer, additionalBytes: number) -> (),
	Reserve: (self: Writer, additionalBytes: number) -> (),
	FlushBits: (self: Writer) -> (),
	WriteBits: (self: Writer, value: number, bits: number) -> (),
	WriteU8: (self: Writer, value: number) -> (),
	WriteU16: (self: Writer, value: number) -> (),
	WriteU32: (self: Writer, value: number) -> (),
	WriteU64: (self: Writer, value: number) -> (),
	WriteI64: (self: Writer, value: number) -> (),
	WriteI8: (self: Writer, value: number) -> (),
	WriteI16: (self: Writer, value: number) -> (),
	WriteF32: (self: Writer, value: number) -> (),
	WriteF64: (self: Writer, value: number) -> (),
	WriteVarint: (self: Writer, value: number) -> (),
	WriteZigZag: (self: Writer, value: number) -> (),
	WriteAdaptiveNumber: (self: Writer, value: number) -> (),
	WriteStringRaw: (self: Writer, str: string) -> (),
	WriteStringCached: (self: Writer, str: string) -> (),
	GetBuffer: (self: Writer) -> buffer,
	_EnsureCapacity: (additionalBytes: number) -> (),
	_Reserve: (additionalBytes: number) -> (),
	_FlushBits: () -> (),
	_WriteBits: (value: number, bits: number) -> (),
	_WriteU8: (value: number) -> (),
	_WriteU16: (value: number) -> (),
	_WriteU32: (value: number) -> (),
	_WriteU64: (value: number) -> (),
	_WriteI64: (value: number) -> (),
	_WriteI8: (value: number) -> (),
	_WriteI16: (value: number) -> (),
	_WriteF32: (value: number) -> (),
	_WriteF64: (value: number) -> (),
	_WriteVarint: (value: number) -> (),
	_WriteZigZag: (value: number) -> (),
	_WriteAdaptiveNumber: (value: number) -> (),
	_WriteStringRaw: (str: string) -> (),
	_WriteStringCached: (str: string) -> (),
	_WriteU16Array: (values: {number}, count: number) -> (),
	_WriteBooleanArray: (values: {boolean}, count: number) -> (),
	_WriteSmallDeltaArray: (values: {number}, count: number) -> (),
	_WriteStaticRecordArrayChecked: (values: {any}, count: number, plan: AutoRecordPlan, builtNow: boolean, trustCache: boolean) -> boolean,
	_WriteStaticSchemaArray: (values: {any}, count: number, plan: StaticSchemaPlan, validate: boolean) -> (),
	_WriteStaticSchemaRootLayout1: (data: {[string]: any}, plan: StaticSchemaRootPlan, validate: boolean) -> (),
	_Checkpoint: () -> (number, number, number),
	_Restore: (offset: number, bitBuffer: number, bitCount: number) -> (),
	_GetBuffer: () -> buffer,
}

local converterByMetatable: {[any]: any} = {}
local converterCount = 0

local function hasRegisteredConverter(value: any): boolean
	if converterCount == 0 then return false end
	local mt = getmetatable(value)
	return mt ~= nil and (converterByMetatable[mt] ~= nil
		or (mt.__type ~= nil and converterByMetatable[mt.__type] ~= nil))
end

local writerPool: {[number]: {Writer}} = {}
local largestWriterPoolBucket = 0

local function writerSizeBucket(sz: number): number
	local bucket = 64
	while bucket < sz do
		bucket *= 2
	end
	return bucket
end

local releaseWriterInstance: (w: Writer, size: number) -> ()
local function newWriterInstance(size: number): Writer
	local buf: buffer = bufferCreate(size)
	local offset = 0
	local bufSize = size
	local bitBuffer = 0
	local bitCount = 0

	local function ensureCapacity(additionalBytes: number): ()
		local required = offset + additionalBytes
		if required <= bufSize then return end
		local newSize = writerSizeBucket(mathMax(required, bufSize * 2))
		local newBuf  = bufferCreate(newSize)
		bufferCopy(newBuf, 0, buf, 0, offset)
		buf     = newBuf
		bufSize = newSize
	end

	local function flushBits(): ()
		if bitCount == 0 then return end
		if offset >= bufSize then ensureCapacity(1) end
		bufferWriteU8(buf, offset, bitBuffer)
		offset    += 1
		bitBuffer  = 0
		bitCount   = 0
	end

	local function writeBits(value: number, bits: number): ()
		bitBuffer = bit32bor(bitBuffer, bit32lshift(value, bitCount))
		bitCount += bits
		while bitCount >= 8 do
			if offset >= bufSize then ensureCapacity(1) end
			bufferWriteU8(buf, offset, bit32band(bitBuffer, 0xFF))
			offset    += 1
			bitBuffer  = bit32rshift(bitBuffer, 8)
			bitCount  -= 8
		end
	end

	local function writeU8(value: number): ()
		if bitCount ~= 0 then
			if offset >= bufSize then ensureCapacity(1) end
			bufferWriteU8(buf, offset, bitBuffer)
			offset += 1
			bitBuffer, bitCount = 0, 0
		end
		if offset >= bufSize then ensureCapacity(1) end
		bufferWriteU8(buf, offset, value)
		offset += 1
	end

	local function writeU16(value: number): ()
		if bitCount ~= 0 then
			if offset >= bufSize then ensureCapacity(1) end
			bufferWriteU8(buf, offset, bitBuffer)
			offset += 1
			bitBuffer, bitCount = 0, 0
		end
		if offset + 2 > bufSize then ensureCapacity(2) end
		bufferWriteU16(buf, offset, value)
		offset += 2
	end

	local function writeU32(value: number): ()
		if bitCount ~= 0 then
			if offset >= bufSize then ensureCapacity(1) end
			bufferWriteU8(buf, offset, bitBuffer)
			offset += 1
			bitBuffer, bitCount = 0, 0
		end
		if offset + 4 > bufSize then ensureCapacity(4) end
		bufferWriteU32(buf, offset, value)
		offset += 4
	end

	local function writeU64(value: number): ()
		if bitCount ~= 0 then
			if offset >= bufSize then ensureCapacity(1) end
			bufferWriteU8(buf, offset, bitBuffer)
			offset += 1
			bitBuffer, bitCount = 0, 0
		end
		if value < 0 or value > 9007199254740991 then
			error(`[Pancakes] WriteU64: {value} is outside the safe integer range (0 to 2^53-1)`)
		end
		local hi = mathFloor(value / 4294967296)
		local lo = value % 4294967296
		if offset + 8 > bufSize then ensureCapacity(8) end
		bufferWriteU32(buf, offset, lo)
		bufferWriteU32(buf, offset + 4, hi)
		offset += 8
	end

	local function writeI64(value: number): ()
		local encoded = value >= 0 and (value * 2) or (-value * 2 - 1)
		writeU64(encoded)
	end

	local function writeI8(value: number): ()
		if bitCount ~= 0 then
			if offset >= bufSize then ensureCapacity(1) end
			bufferWriteU8(buf, offset, bitBuffer)
			offset += 1
			bitBuffer, bitCount = 0, 0
		end
		if offset >= bufSize then ensureCapacity(1) end
		bufferWriteI8(buf, offset, value)
		offset += 1
	end

	local function writeI16(value: number): ()
		if bitCount ~= 0 then
			if offset >= bufSize then ensureCapacity(1) end
			bufferWriteU8(buf, offset, bitBuffer)
			offset += 1
			bitBuffer, bitCount = 0, 0
		end
		if offset + 2 > bufSize then ensureCapacity(2) end
		bufferWriteI16(buf, offset, value)
		offset += 2
	end

	local function writeF32(value: number): ()
		if bitCount ~= 0 then
			if offset >= bufSize then ensureCapacity(1) end
			bufferWriteU8(buf, offset, bitBuffer)
			offset += 1
			bitBuffer, bitCount = 0, 0
		end
		if offset + 4 > bufSize then ensureCapacity(4) end
		bufferWriteF32(buf, offset, value)
		offset += 4
	end

	local function writeF64(value: number): ()
		if bitCount ~= 0 then
			if offset >= bufSize then ensureCapacity(1) end
			bufferWriteU8(buf, offset, bitBuffer)
			offset += 1
			bitBuffer, bitCount = 0, 0
		end
		if offset + 8 > bufSize then ensureCapacity(8) end
		bufferWriteF64(buf, offset, value)
		offset += 8
	end

	local function writeVarint(value: number): ()
		if bitCount ~= 0 then
			if offset >= bufSize then ensureCapacity(1) end
			bufferWriteU8(buf, offset, bitBuffer)
			offset += 1
			bitBuffer, bitCount = 0, 0
		end
		local abs = mathAbs(value)
		while abs >= 128 do
			if offset >= bufSize then ensureCapacity(1) end
			bufferWriteU8(buf, offset, bit32bor(bit32band(abs, 0x7F), 0x80))
			offset += 1
			abs = mathFloor(abs / 128)
		end
		if offset >= bufSize then ensureCapacity(1) end
		bufferWriteU8(buf, offset, abs)
		offset += 1
	end

	local function writeZigZag(value: number): ()
		local encoded = bit32bxor(bit32lshift(value, 1), bit32arshift(value, 31))
		writeVarint(encoded)
	end

	local function writeStringRaw(str: string): ()
		local len = #str
		if offset + len > bufSize then ensureCapacity(len) end
		bufferWriteStr(buf, offset, str)
		offset += len
	end

	local function writeAdaptiveNumber(value: number): ()
		if Config.debugAsserts and type(value) ~= "number" then
			warn(value, typeofFn(value), debug.traceback())
		end

		if value == 0 then
			writeBits(ADAPT_ZERO, 4)
		elseif value == 1 then
			writeBits(ADAPT_ONE, 4)
		elseif value % 1 == 0 and value >= 2 and value <= 15 then
			writeBits(ADAPT_NIBBLE, 4)
			writeBits(value, 4)
		elseif value % 1 == 0 and mathAbs(value) < 9007199254740992 then
			if value >= -127 and value <= 127 then
				writeBits(ADAPT_I8, 4)
				writeI8(value)
			elseif value >= -32768 and value <= 32767 then
				writeBits(ADAPT_I16, 4)
				writeI16(value)
			elseif value >= 0 and value <= 4294967295 then
				writeBits(ADAPT_U32, 4)
				writeU32(value)
			elseif value >= -2147483648 and value < 0 then
				writeBits(ADAPT_ZIGZAG32, 4)
				writeZigZag(value)
			else
				writeBits(ADAPT_F64, 4)
				writeF64(value)
			end
		else
			if isExactF32(value) then
				writeBits(ADAPT_F32, 4)
				writeF32(value)
			else
				writeBits(ADAPT_F64, 4)
				writeF64(value)
			end
		end
	end

	local writerInstance: Writer

	local function writeStringCached(str: string): ()
		local len = #str
		local sc = stringCache
		if len >= Config.stringCacheMinLength then
			local cached = sc.forward[str]
			if cached then
				writeBits(1, 1)
				writeBits(cached, 16)
				return
			end
		end

		writeBits(0, 1)

		if len == 0 then
			writeBits(0, 8)
		else
			if len < 255 then
				writeBits(len, 8)
			else
				writeBits(255, 8)
				writeU32(len)
			end
			flushBits()
			writeStringRaw(str)
		end

		if len >= Config.stringCacheMinLength and sc.index < 65535 then
			sc.index += 1
			sc.forward[str]      = sc.index
			sc.reverse[sc.index] = str
		end
	end

	local function writeStaticRecordChecked(value: any, plan: AutoRecordPlan, validateKeys: boolean): boolean
		local RECORD_VALUE_STRING, RECORD_VALUE_BOOLEAN = 1, 2
		local RECORD_VALUE_U16, RECORD_VALUE_I16, RECORD_VALUE_U32 = 3, 4, 5
		local RECORD_VALUE_I32, RECORD_VALUE_F32, RECORD_VALUE_F64, RECORD_VALUE_NESTED = 6, 7, 8, 9
		if type(value) ~= "table" or hasRegisteredConverter(value) then return false end
		if validateKeys then
			local actualCount = 0
			for _ in value do
				actualCount += 1
				if actualCount > plan.count then return false end
			end
			if actualCount ~= plan.count then return false end
		end

		local keys = plan.keys
		local kinds = plan.kinds
		for i = 1, plan.count do
			local fieldValue = value[keys[i]]
			if fieldValue == nil then return false end
			local kind = kinds[i]
			if kind == RECORD_VALUE_STRING then
				if type(fieldValue) ~= "string" then return false end
				local len = #fieldValue
				local prefixBytes = if len < 255 then 1 else 5
				local flushByte = if bitCount ~= 0 then 1 else 0
				if offset + flushByte + prefixBytes + len > bufSize then
					ensureCapacity(flushByte + prefixBytes + len)
				end
				if bitCount ~= 0 then
					bufferWriteU8(buf, offset, bitBuffer)
					offset += 1
					bitBuffer, bitCount = 0, 0
				end
				if len < 255 then
					bufferWriteU8(buf, offset, len)
					offset += 1
				else
					bufferWriteU8(buf, offset, 255)
					bufferWriteU32(buf, offset + 1, len)
					offset += 5
				end
				bufferWriteStr(buf, offset, fieldValue)
				offset += len
			elseif kind == RECORD_VALUE_BOOLEAN then
				if type(fieldValue) ~= "boolean" then return false end
				writeBits(fieldValue and 1 or 0, 1)
			elseif kind == RECORD_VALUE_U16 then
				if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0
					or fieldValue < 0 or fieldValue > 65535 then return false end
				if bitCount ~= 0 then
					if offset >= bufSize then ensureCapacity(4) end
					bufferWriteU8(buf, offset, bitBuffer); offset += 1; bitBuffer, bitCount = 0, 0
				end
				if offset + 3 > bufSize then ensureCapacity(3) end
				if fieldValue < 255 then
					bufferWriteU8(buf, offset, fieldValue); offset += 1
				else
					bufferWriteU8(buf, offset, 255)
					bufferWriteU16(buf, offset + 1, fieldValue)
					offset += 3
				end
			elseif kind == RECORD_VALUE_I16 then
				if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0
					or fieldValue < -32768 or fieldValue > 32767 then return false end
				if bitCount ~= 0 then
					if offset >= bufSize then ensureCapacity(3) end
					bufferWriteU8(buf, offset, bitBuffer); offset += 1; bitBuffer, bitCount = 0, 0
				end
				if offset + 2 > bufSize then ensureCapacity(2) end
				bufferWriteI16(buf, offset, fieldValue); offset += 2
			elseif kind == RECORD_VALUE_U32 then
				if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0
					or fieldValue < 0 or fieldValue > 4294967295 then return false end
				if bitCount ~= 0 then
					if offset >= bufSize then ensureCapacity(5) end
					bufferWriteU8(buf, offset, bitBuffer); offset += 1; bitBuffer, bitCount = 0, 0
				end
				if offset + 4 > bufSize then ensureCapacity(4) end
				bufferWriteU32(buf, offset, fieldValue); offset += 4
			elseif kind == RECORD_VALUE_I32 then
				if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0
					or fieldValue < -2147483648 or fieldValue > 2147483647 then return false end
				writeZigZag(fieldValue)
			elseif kind == RECORD_VALUE_F32 then
				if type(fieldValue) ~= "number" or not isExactF32(fieldValue) then return false end
				if bitCount ~= 0 then
					if offset >= bufSize then ensureCapacity(5) end
					bufferWriteU8(buf, offset, bitBuffer); offset += 1; bitBuffer, bitCount = 0, 0
				end
				if offset + 4 > bufSize then ensureCapacity(4) end
				bufferWriteF32(buf, offset, fieldValue); offset += 4
			elseif kind == RECORD_VALUE_F64 then
				if type(fieldValue) ~= "number" then return false end
				if bitCount ~= 0 then
					if offset >= bufSize then ensureCapacity(9) end
					bufferWriteU8(buf, offset, bitBuffer); offset += 1; bitBuffer, bitCount = 0, 0
				end
				if offset + 8 > bufSize then ensureCapacity(8) end
				bufferWriteF64(buf, offset, fieldValue); offset += 8
			elseif kind == RECORD_VALUE_NESTED then
				if not writeStaticRecordChecked(fieldValue, plan.children[i], validateKeys) then return false end
			else
				return false
			end
		end
		return true
	end

	local function writeStaticAutoLayout2ArrayChecked(
		values: {any}, count: number, plan: AutoRecordPlan, builtNow: boolean, trustCache: boolean
	): boolean
		local captureOffsets = AutoRuntime.captureLayoutOffsets
		local patchOffsets = AutoRuntime.lastLayoutOffsets
		if captureOffsets then tableClear(patchOffsets); AutoRuntime.lastLayoutCount = count end
		AutoRuntime.lastLayoutValid = false
		local keys = plan.keys
		local flagsKeys = plan.children[3].keys
		local statsKeys = plan.children[9].keys
		local k1, k2, k3, k4, k5, k6, k7, k8, k9 =
			keys[1], keys[2], keys[3], keys[4], keys[5], keys[6], keys[7], keys[8], keys[9]
		local f1, f2, f3 = flagsKeys[1], flagsKeys[2], flagsKeys[3]
		local s1, s2, s3 = statsKeys[1], statsKeys[2], statsKeys[3]
		local cachePlans = Config.sortedKeysCacheEnabled
		local planCache = AutoRuntime.recordPlanCache
		flushBits()
		for i = 1, count do
			local row = values[i]
			if type(row) ~= "table" then return false end
			if hasRegisteredConverter(row) then return false end
			local flags = row[k3]
			if type(flags) ~= "table" then return false end
			if hasRegisteredConverter(flags) then return false end
			local b1, b2, b3 = row[k1], row[k2], row[k5]
			local fv1, fv2, fv3 = flags[f1], flags[f2], flags[f3]
			if type(b1) ~= "boolean" or type(b2) ~= "boolean" or type(b3) ~= "boolean"
				or type(fv1) ~= "boolean" or type(fv2) ~= "boolean" or type(fv3) ~= "boolean" then return false end
			local patchBase = (i - 1) * 12
			if captureOffsets then patchOffsets[patchBase + 1], patchOffsets[patchBase + 2] = offset, bitCount end
			writeBits((if b1 then 1 else 0) + (if b2 then 2 else 0)
				+ (if fv1 then 4 else 0) + (if fv2 then 8 else 0) + (if fv3 then 16 else 0)
				+ (if b3 then 32 else 0), 6)
		end
		flushBits()
		for i = 1, count do
			local row = values[i]
			if type(row) ~= "table" then return false end
			local validateKeys = not (i == 1 and builtNow)
			if trustCache and planCache[row] == plan then validateKeys = false end
			if validateKeys then
				local actualCount = 0
				for _ in row do actualCount += 1; if actualCount > 9 then return false end end
				if actualCount ~= 9 then return false end
			end

			local b1, b2, flags = row[k1], row[k2], row[k3]
			local id, b3, name, orderIndex, rarity, stats = row[k4], row[k5], row[k6], row[k7], row[k8], row[k9]
			if type(b1) ~= "boolean" or type(b2) ~= "boolean" or type(b3) ~= "boolean"
				or type(flags) ~= "table" or type(stats) ~= "table"
				or type(id) ~= "number" or id ~= bit32band(id, 65535)
				or type(orderIndex) ~= "number" or orderIndex ~= bit32band(orderIndex, 65535)
				or type(name) ~= "string" or type(rarity) ~= "string" then return false end
			if hasRegisteredConverter(stats) then return false end
			if validateKeys then
				local flagsCount, statsCount = 0, 0
				for _ in flags do flagsCount += 1; if flagsCount > 3 then return false end end
				for _ in stats do statsCount += 1; if statsCount > 3 then return false end end
				if flagsCount ~= 3 or statsCount ~= 3 then return false end
			end
			local fv1, fv2, fv3 = flags[f1], flags[f2], flags[f3]
			local sv1, sv2, sv3 = stats[s1], stats[s2], stats[s3]
			if type(fv1) ~= "boolean" or type(fv2) ~= "boolean" or type(fv3) ~= "boolean"
				or type(sv1) ~= "number" or sv1 ~= bit32band(sv1, 65535)
				or type(sv2) ~= "number" or sv2 ~= bit32band(sv2, 65535)
				or type(sv3) ~= "number" or sv3 ~= bit32band(sv3, 65535) then return false end

			local nameLen, rarityLen = #name, #rarity
			local idWidth = if id < 255 then 1 else 3
			local orderWidth = if orderIndex < 255 then 1 else 3
			local stat1Width = if sv1 < 255 then 1 else 3
			local stat2Width = if sv2 < 255 then 1 else 3
			local stat3Width = if sv3 < 255 then 1 else 3
			local needed = idWidth + orderWidth + stat1Width + stat2Width + stat3Width
				+ (if nameLen < 255 then 1 else 5) + nameLen
				+ (if rarityLen < 255 then 1 else 5) + rarityLen
			if offset + needed > bufSize then ensureCapacity(needed) end
			local patchBase = (i - 1) * 12
			if captureOffsets then patchOffsets[patchBase + 3] = offset end
			if id < 255 then bufferWriteU8(buf, offset, id); offset += 1
			else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, id); offset += 3 end
			if nameLen < 255 then bufferWriteU8(buf, offset, nameLen); offset += 1
			else bufferWriteU8(buf, offset, 255); bufferWriteU32(buf, offset + 1, nameLen); offset += 5 end
			if captureOffsets then patchOffsets[patchBase + 5], patchOffsets[patchBase + 6] = offset, nameLen end
			bufferWriteStr(buf, offset, name); offset += nameLen
			if captureOffsets then patchOffsets[patchBase + 7] = offset end
			if orderIndex < 255 then bufferWriteU8(buf, offset, orderIndex); offset += 1
			else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, orderIndex); offset += 3 end
			if rarityLen < 255 then bufferWriteU8(buf, offset, rarityLen); offset += 1
			else bufferWriteU8(buf, offset, 255); bufferWriteU32(buf, offset + 1, rarityLen); offset += 5 end
			if captureOffsets then patchOffsets[patchBase + 8], patchOffsets[patchBase + 9] = offset, rarityLen end
			bufferWriteStr(buf, offset, rarity); offset += rarityLen
			if captureOffsets then patchOffsets[patchBase + 10] = offset end
			if sv1 < 255 then bufferWriteU8(buf, offset, sv1); offset += 1
			else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, sv1); offset += 3 end
			if captureOffsets then patchOffsets[patchBase + 11] = offset end
			if sv2 < 255 then bufferWriteU8(buf, offset, sv2); offset += 1
			else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, sv2); offset += 3 end
			if captureOffsets then patchOffsets[patchBase + 12] = offset end
			if sv3 < 255 then bufferWriteU8(buf, offset, sv3); offset += 1
			else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, sv3); offset += 3 end
			if cachePlans then planCache[row] = plan end
		end
		AutoRuntime.lastLayoutValid = captureOffsets
		return true
	end

	local function writeStaticRecordArrayChecked(
		values: {any},
		count: number,
		plan: AutoRecordPlan,
		builtNow: boolean,
		trustCache: boolean
	): boolean
		local cachePlans = Config.sortedKeysCacheEnabled
		local planCache = AutoRuntime.recordPlanCache
		if plan.layout == 1 then
			local captureOffsets = AutoRuntime.captureLayoutOffsets
			local patchOffsets = AutoRuntime.lastLayoutOffsets
			if captureOffsets then tableClear(patchOffsets); AutoRuntime.lastLayoutCount = count end
			AutoRuntime.lastLayoutValid = false
			local keys = plan.keys
			local childKeys = plan.children[5].keys
			local k1, k2, k3, k4, k5 = keys[1], keys[2], keys[3], keys[4], keys[5]
			local c1, c2, c3 = childKeys[1], childKeys[2], childKeys[3]
			flushBits()
			for i = 1, count do
				local row = values[i]
				if type(row) ~= "table" then return false end
				if hasRegisteredConverter(row) then return false end
				local value = row[k1]
				if type(value) ~= "boolean" then return false end
				local patchBase = (i - 1) * 10
				if captureOffsets then
					patchOffsets[patchBase + 1], patchOffsets[patchBase + 2] = offset, bitCount
				end
				writeBits(value and 1 or 0, 1)
			end
			flushBits()
			for i = 1, count do
				local row = values[i]
				if type(row) ~= "table" then return false end
				local validateKeys = not (i == 1 and builtNow)
				if trustCache and planCache[row] == plan then validateKeys = false end
				if validateKeys then
					local actualCount = 0
					for _ in row do
						actualCount += 1
						if actualCount > 5 then return false end
					end
					if actualCount ~= 5 then return false end
				end

				local v1, v2, v3, v4, nested = row[k1], row[k2], row[k3], row[k4], row[k5]
				if type(v1) ~= "boolean"
					or type(v2) ~= "number" or v2 ~= bit32band(v2, 65535)
					or type(v3) ~= "string" or type(v4) ~= "string"
					or type(nested) ~= "table" then return false end
				if hasRegisteredConverter(nested) then return false end
				if validateKeys then
					local actualCount = 0
					for _ in nested do
						actualCount += 1
						if actualCount > 3 then return false end
					end
					if actualCount ~= 3 then return false end
				end
				local n1, n2, n3 = nested[c1], nested[c2], nested[c3]
				if type(n1) ~= "number" or n1 ~= bit32band(n1, 65535)
					or type(n2) ~= "number" or n2 ~= bit32band(n2, 65535)
					or type(n3) ~= "number" or n3 ~= bit32band(n3, 65535) then return false end

				local len3, len4 = #v3, #v4
				local width2 = if v2 < 255 then 1 else 3
				local widthN1 = if n1 < 255 then 1 else 3
				local widthN2 = if n2 < 255 then 1 else 3
				local widthN3 = if n3 < 255 then 1 else 3
				local numericBytes = width2 + widthN1 + widthN2 + widthN3
				local shortStrings = len3 < 255 and len4 < 255
				local needed = if shortStrings then 2 + numericBytes + len3 + len4
					else numericBytes + (if len3 < 255 then 1 else 5) + len3 + (if len4 < 255 then 1 else 5) + len4
				if offset + needed > bufSize then ensureCapacity(needed) end
				local patchBase = (i - 1) * 10
				if captureOffsets then patchOffsets[patchBase + 3] = offset end
				if v2 < 255 then bufferWriteU8(buf, offset, v2); offset += 1
				else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, v2); offset += 3 end
				if shortStrings then
					bufferWriteU8(buf, offset, len3); offset += 1
					if captureOffsets then patchOffsets[patchBase + 4], patchOffsets[patchBase + 5] = offset, len3 end
					bufferWriteStr(buf, offset, v3); offset += len3
					bufferWriteU8(buf, offset, len4); offset += 1
					if captureOffsets then patchOffsets[patchBase + 6], patchOffsets[patchBase + 7] = offset, len4 end
					bufferWriteStr(buf, offset, v4); offset += len4
				else
					if len3 < 255 then
						bufferWriteU8(buf, offset, len3); offset += 1
					else
						bufferWriteU8(buf, offset, 255); bufferWriteU32(buf, offset + 1, len3); offset += 5
					end
					if captureOffsets then patchOffsets[patchBase + 4], patchOffsets[patchBase + 5] = offset, len3 end
					bufferWriteStr(buf, offset, v3); offset += len3
					if len4 < 255 then
						bufferWriteU8(buf, offset, len4); offset += 1
					else
						bufferWriteU8(buf, offset, 255); bufferWriteU32(buf, offset + 1, len4); offset += 5
					end
					if captureOffsets then patchOffsets[patchBase + 6], patchOffsets[patchBase + 7] = offset, len4 end
					bufferWriteStr(buf, offset, v4); offset += len4
				end
				if captureOffsets then patchOffsets[patchBase + 8] = offset end
				if n1 < 255 then bufferWriteU8(buf, offset, n1); offset += 1
				else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, n1); offset += 3 end
				if captureOffsets then patchOffsets[patchBase + 9] = offset end
				if n2 < 255 then bufferWriteU8(buf, offset, n2); offset += 1
				else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, n2); offset += 3 end
				if captureOffsets then patchOffsets[patchBase + 10] = offset end
				if n3 < 255 then bufferWriteU8(buf, offset, n3); offset += 1
				else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, n3); offset += 3 end
				if cachePlans then planCache[row] = plan end
			end
			AutoRuntime.lastLayoutValid = captureOffsets
			return true
		elseif plan.layout == 2 then
			return writeStaticAutoLayout2ArrayChecked(values, count, plan, builtNow, trustCache)
		end

		for i = 1, count do
			local row = values[i]
			local validateKeys = not (i == 1 and builtNow)
			if trustCache and planCache[row] == plan then
				validateKeys = false
			end
			if not writeStaticRecordChecked(row, plan, validateKeys) then
				return false
			end
			if cachePlans then
				planCache[row] = plan
			end
		end
		return true
	end

	local function writeStaticSchemaRecord(data: {[string]: any}, plan: StaticSchemaPlan, validate: boolean): ()
		local headerKeys = plan.headerKeys
		local headerOptional = plan.headerOptional
		for i = 1, plan.headerCount do
			local key = headerKeys[i]
			local value = data[key]
			if headerOptional[i] then
				local present = value ~= nil
				writeBits(present and 1 or 0, 1)
				if present then writeBits(value and 1 or 0, 1) end
			elseif validate and value == nil then
				error(`[Pancakes] Required field "{key}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
			else
				writeBits(value and 1 or 0, 1)
			end
		end

		local keys = plan.valueKeys
		local optional = plan.valueOptional
		local kinds = plan.kinds
		for i = 1, plan.valueCount do
			local key = keys[i]
			local value = data[key]
			local isOptional = optional[i]
			if isOptional then
				local present = value ~= nil
				writeBits(present and 1 or 0, 1)
				if not present then continue end
			elseif validate and value == nil then
				error(`[Pancakes] Required field "{key}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
			end
			local kind = kinds[i]
			if kind == 1 then writeU8(value)
			elseif kind == 2 then writeI8(value)
			elseif kind == 3 then
				if AutoRuntime.schemaCompactWire then
					if value < 255 then writeU8(value) else writeU8(255); writeU16(value) end
				else writeU16(value) end
			elseif kind == 4 then writeI16(value)
			elseif kind == 5 then writeU32(value)
			elseif kind == 6 then writeZigZag(value)
			elseif kind == 7 then writeU64(value)
			elseif kind == 8 then writeI64(value)
			elseif kind == 9 then writeF32(value)
			elseif kind == 10 then writeF64(value)
			elseif kind == 11 then
				local len = #value
				if AutoRuntime.schemaCompactWire then
					if len < 255 then writeU8(len) else writeU8(255); writeU32(len) end
				elseif len < 65535 then writeU16(len) else writeU16(65535); writeU32(len) end
				writeStringRaw(value)
			else
				writeStaticSchemaRecord(value, plan.children[i], validate)
			end
		end
	end

	local function writeStaticSchemaLayout2Array(values: {any}, count: number, plan: StaticSchemaPlan, validate: boolean): ()
		local hk, keys = plan.headerKeys, plan.valueKeys
		local statsKeys = plan.children[4].valueKeys
		local flagsKeys = plan.children[5].headerKeys
		local h1, h2, h3 = hk[1], hk[2], hk[3]
		local k1, k2, k3, k4, k5, k6 = keys[1], keys[2], keys[3], keys[4], keys[5], keys[6]
		local s1, s2, s3 = statsKeys[1], statsKeys[2], statsKeys[3]
		local f1, f2, f3 = flagsKeys[1], flagsKeys[2], flagsKeys[3]
		if AutoRuntime.schemaCompactWire then
			for i = 1, count do
				local row = values[i]
				local flags = row[k5]
				local hv1, hv2, hv3 = row[h1], row[h2], row[h3]
				if validate and (hv1 == nil or hv2 == nil or hv3 == nil or flags == nil) then
					if hv1 == nil then error(`[Pancakes] Required field "{h1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if hv2 == nil then error(`[Pancakes] Required field "{h2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if hv3 == nil then error(`[Pancakes] Required field "{h3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					error(`[Pancakes] Required field "{k5}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
				end
				local fv1, fv2, fv3 = flags[f1], flags[f2], flags[f3]
				if validate and (fv1 == nil or fv2 == nil or fv3 == nil) then
					if fv1 == nil then error(`[Pancakes] Required field "{f1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if fv2 == nil then error(`[Pancakes] Required field "{f2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					error(`[Pancakes] Required field "{f3}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
				end
				writeBits((if hv1 then 1 else 0) + (if hv2 then 2 else 0) + (if hv3 then 4 else 0)
					+ (if fv1 then 8 else 0) + (if fv2 then 16 else 0) + (if fv3 then 32 else 0), 6)
			end
			flushBits()

			for i = 1, count do
				local row = values[i]
				local v1, v2, v3, stats, v6 = row[k1], row[k2], row[k3], row[k4], row[k6]
				if validate and (v1 == nil or v2 == nil or v3 == nil or stats == nil or v6 == nil) then
					if v1 == nil then error(`[Pancakes] Required field "{k1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v2 == nil then error(`[Pancakes] Required field "{k2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v3 == nil then error(`[Pancakes] Required field "{k3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if stats == nil then error(`[Pancakes] Required field "{k4}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					error(`[Pancakes] Required field "{k6}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
				end
				local sv1, sv2, sv3 = stats[s1], stats[s2], stats[s3]
				if validate and (sv1 == nil or sv2 == nil or sv3 == nil) then
					if sv1 == nil then error(`[Pancakes] Required field "{s1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if sv2 == nil then error(`[Pancakes] Required field "{s2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					error(`[Pancakes] Required field "{s3}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
				end
				local len2, len3 = #v2, #v3
				local needed = 1 + (if v1 < 255 then 1 else 3)
					+ (if sv1 < 255 then 1 else 3) + (if sv2 < 255 then 1 else 3)
					+ (if v6 < 255 then 1 else 3)
					+ (if len2 < 255 then 1 else 5) + len2 + (if len3 < 255 then 1 else 5) + len3
				if offset + needed > bufSize then ensureCapacity(needed) end
				if v1 < 255 then bufferWriteU8(buf, offset, v1); offset += 1
				else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, v1); offset += 3 end
				if len2 < 255 then bufferWriteU8(buf, offset, len2); offset += 1
				else bufferWriteU8(buf, offset, 255); bufferWriteU32(buf, offset + 1, len2); offset += 5 end
				bufferWriteStr(buf, offset, v2); offset += len2
				if len3 < 255 then bufferWriteU8(buf, offset, len3); offset += 1
				else bufferWriteU8(buf, offset, 255); bufferWriteU32(buf, offset + 1, len3); offset += 5 end
				bufferWriteStr(buf, offset, v3); offset += len3
				if sv1 < 255 then bufferWriteU8(buf, offset, sv1); offset += 1
				else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, sv1); offset += 3 end
				if sv2 < 255 then bufferWriteU8(buf, offset, sv2); offset += 1
				else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, sv2); offset += 3 end
				bufferWriteU8(buf, offset, sv3); offset += 1
				if v6 < 255 then bufferWriteU8(buf, offset, v6); offset += 1
				else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, v6); offset += 3 end
			end
			return
		end
		for i = 1, count do
			local row = values[i]
			local hv1, hv2, hv3 = row[h1], row[h2], row[h3]
			local v1, v2, v3, stats, flags, v6 = row[k1], row[k2], row[k3], row[k4], row[k5], row[k6]
			if validate then
				if hv1 == nil then error(`[Pancakes] Required field "{h1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				if hv2 == nil then error(`[Pancakes] Required field "{h2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				if hv3 == nil then error(`[Pancakes] Required field "{h3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				if v1 == nil then error(`[Pancakes] Required field "{k1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				if v2 == nil then error(`[Pancakes] Required field "{k2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				if v3 == nil then error(`[Pancakes] Required field "{k3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				if stats == nil then error(`[Pancakes] Required field "{k4}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				if flags == nil then error(`[Pancakes] Required field "{k5}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				if v6 == nil then error(`[Pancakes] Required field "{k6}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
			end
			local sv1, sv2, sv3 = stats[s1], stats[s2], stats[s3]
			local fv1, fv2, fv3 = flags[f1], flags[f2], flags[f3]
			if validate then
				if sv1 == nil then error(`[Pancakes] Required field "{s1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				if sv2 == nil then error(`[Pancakes] Required field "{s2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				if sv3 == nil then error(`[Pancakes] Required field "{s3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				if fv1 == nil then error(`[Pancakes] Required field "{f1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				if fv2 == nil then error(`[Pancakes] Required field "{f2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				if fv3 == nil then error(`[Pancakes] Required field "{f3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
			end

			local len2, len3 = #v2, #v3
			local compact = AutoRuntime.schemaCompactWire
			local needed = 11 + (if compact then (if len2 < 255 then 1 else 5) else (if len2 < 65535 then 2 else 6)) + len2
				+ (if compact then (if len3 < 255 then 1 else 5) else (if len3 < 65535 then 2 else 6)) + len3
			if offset + needed > bufSize then ensureCapacity(needed) end
			local header = (if hv1 then 1 else 0) + (if hv2 then 2 else 0) + (if hv3 then 4 else 0)
			bufferWriteU8(buf, offset, header); offset += 1
			bufferWriteU16(buf, offset, v1); offset += 2
			if compact then
				if len2 < 255 then bufferWriteU8(buf, offset, len2); offset += 1
				else bufferWriteU8(buf, offset, 255); bufferWriteU32(buf, offset + 1, len2); offset += 5 end
			elseif len2 < 65535 then bufferWriteU16(buf, offset, len2); offset += 2
			else bufferWriteU16(buf, offset, 65535); bufferWriteU32(buf, offset + 2, len2); offset += 6 end
			bufferWriteStr(buf, offset, v2); offset += len2
			if compact then
				if len3 < 255 then bufferWriteU8(buf, offset, len3); offset += 1
				else bufferWriteU8(buf, offset, 255); bufferWriteU32(buf, offset + 1, len3); offset += 5 end
			elseif len3 < 65535 then bufferWriteU16(buf, offset, len3); offset += 2
			else bufferWriteU16(buf, offset, 65535); bufferWriteU32(buf, offset + 2, len3); offset += 6 end
			bufferWriteStr(buf, offset, v3); offset += len3
			bufferWriteU16(buf, offset, sv1)
			bufferWriteU16(buf, offset + 2, sv2)
			bufferWriteU8(buf, offset + 4, sv3)
			offset += 5
			local flagByte = (if fv1 then 1 else 0) + (if fv2 then 2 else 0) + (if fv3 then 4 else 0)
			bufferWriteU8(buf, offset, flagByte)
			bufferWriteU16(buf, offset + 1, v6)
			offset += 3
		end
		bitBuffer, bitCount = 0, 0
	end

	local function writeStaticSchemaArray(values: {any}, count: number, plan: StaticSchemaPlan, validate: boolean): ()
		if plan.optionalCount > 0 then
			local headerKeys, headerOptional = plan.headerKeys, plan.headerOptional
			local valueKeys, valueOptional = plan.valueKeys, plan.valueOptional
			for rowIndex = 1, count do
				local row = values[rowIndex]
				for fieldIndex = 1, plan.headerCount do
					local key, value = headerKeys[fieldIndex], row[headerKeys[fieldIndex]]
					if headerOptional[fieldIndex] then
						local present = value ~= nil
						writeBits(present and 1 or 0, 1)
						if present then writeBits(value and 1 or 0, 1) end
					elseif validate and value == nil then
						error(`[Pancakes] Required field "{key}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
					else
						writeBits(value and 1 or 0, 1)
					end
				end
				for fieldIndex = 1, plan.valueCount do
					if valueOptional[fieldIndex] then writeBits(row[valueKeys[fieldIndex]] ~= nil and 1 or 0, 1) end
				end
			end
			flushBits()
			local kinds, children = plan.kinds, plan.children
			for rowIndex = 1, count do
				local row = values[rowIndex]
				for fieldIndex = 1, plan.valueCount do
					local key, value = valueKeys[fieldIndex], row[valueKeys[fieldIndex]]
					if valueOptional[fieldIndex] and value == nil then continue end
					if validate and value == nil then
						error(`[Pancakes] Required field "{key}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
					end
					local kind = kinds[fieldIndex]
					if kind == 1 then writeU8(value)
					elseif kind == 2 then writeI8(value)
					elseif kind == 3 then
						if AutoRuntime.schemaCompactWire then
							if value < 255 then writeU8(value) else writeU8(255); writeU16(value) end
						else writeU16(value) end
					elseif kind == 4 then writeI16(value)
					elseif kind == 5 then writeU32(value)
					elseif kind == 6 then writeZigZag(value)
					elseif kind == 7 then writeU64(value)
					elseif kind == 8 then writeI64(value)
					elseif kind == 9 then writeF32(value)
					elseif kind == 10 then writeF64(value)
					elseif kind == 11 then
						local len = #value
						if AutoRuntime.schemaCompactWire then
							if len < 255 then writeU8(len) else writeU8(255); writeU32(len) end
						elseif len < 65535 then writeU16(len) else writeU16(65535); writeU32(len) end
						writeStringRaw(value)
					else writeStaticSchemaRecord(value, children[fieldIndex], validate) end
				end
			end
			return
		elseif plan.layout == 1 then
			local h1 = plan.headerKeys[1]
			local keys = plan.valueKeys
			local childKeys = plan.children[4].valueKeys
			local k1, k2, k3, k4 = keys[1], keys[2], keys[3], keys[4]
			local c1, c2, c3 = childKeys[1], childKeys[2], childKeys[3]
			for i = 1, count do
				local row = values[i]
				local hv, v1, v2, v3, nested = row[h1], row[k1], row[k2], row[k3], row[k4]
				if validate and (hv == nil or v1 == nil or v2 == nil or v3 == nil or nested == nil) then
					if hv == nil then error(`[Pancakes] Required field "{h1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v1 == nil then error(`[Pancakes] Required field "{k1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v2 == nil then error(`[Pancakes] Required field "{k2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v3 == nil then error(`[Pancakes] Required field "{k3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if nested == nil then error(`[Pancakes] Required field "{k4}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				end
				local n1, n2, n3 = nested[c1], nested[c2], nested[c3]
				if validate and (n1 == nil or n2 == nil or n3 == nil) then
					if n1 == nil then error(`[Pancakes] Required field "{c1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if n2 == nil then error(`[Pancakes] Required field "{c2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if n3 == nil then error(`[Pancakes] Required field "{c3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				end

				local len2, len3 = #v2, #v3
				local compact = AutoRuntime.schemaCompactWire
				local shortStrings = if compact then len2 < 255 and len3 < 255 else len2 < 65535 and len3 < 65535
				local needed = if compact then 4
					+ (if v1 < 255 then 1 else 3) + (if n1 < 255 then 1 else 3) + (if n2 < 255 then 1 else 3)
					+ (if len2 < 255 then 1 else 5) + len2 + (if len3 < 255 then 1 else 5) + len3
					else (if shortStrings then 12 + len2 + len3 else 8
						+ (if len2 < 65535 then 2 else 6) + len2 + (if len3 < 65535 then 2 else 6) + len3)
				if offset + needed > bufSize then ensureCapacity(needed) end
				if bitCount ~= 0 then
					bitBuffer = bit32bor(bitBuffer, bit32lshift(hv and 1 or 0, bitCount))
					bufferWriteU8(buf, offset, bitBuffer)
				else
					bufferWriteU8(buf, offset, hv and 1 or 0)
				end
				offset += 1; bitBuffer, bitCount = 0, 0
				if compact then
					if v1 < 255 then bufferWriteU8(buf, offset, v1); offset += 1
					else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, v1); offset += 3 end
				else bufferWriteU16(buf, offset, v1); offset += 2 end
				if shortStrings then
					if compact then bufferWriteU8(buf, offset, len2); offset += 1
					else bufferWriteU16(buf, offset, len2); offset += 2 end
					bufferWriteStr(buf, offset, v2); offset += len2
					if compact then bufferWriteU8(buf, offset, len3); offset += 1
					else bufferWriteU16(buf, offset, len3); offset += 2 end
					bufferWriteStr(buf, offset, v3); offset += len3
				else
					if compact then
						if len2 < 255 then bufferWriteU8(buf, offset, len2); offset += 1
						else bufferWriteU8(buf, offset, 255); bufferWriteU32(buf, offset + 1, len2); offset += 5 end
					elseif len2 < 65535 then
						bufferWriteU16(buf, offset, len2); offset += 2
					else
						bufferWriteU16(buf, offset, 65535); bufferWriteU32(buf, offset + 2, len2); offset += 6
					end
					bufferWriteStr(buf, offset, v2); offset += len2
					if compact then
						if len3 < 255 then bufferWriteU8(buf, offset, len3); offset += 1
						else bufferWriteU8(buf, offset, 255); bufferWriteU32(buf, offset + 1, len3); offset += 5 end
					elseif len3 < 65535 then
						bufferWriteU16(buf, offset, len3); offset += 2
					else
						bufferWriteU16(buf, offset, 65535); bufferWriteU32(buf, offset + 2, len3); offset += 6
					end
					bufferWriteStr(buf, offset, v3); offset += len3
				end
				if compact then
					if n1 < 255 then bufferWriteU8(buf, offset, n1); offset += 1
					else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, n1); offset += 3 end
					if n2 < 255 then bufferWriteU8(buf, offset, n2); offset += 1
					else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, n2); offset += 3 end
					bufferWriteU8(buf, offset, n3); offset += 1
				else
					bufferWriteU16(buf, offset, n1)
					bufferWriteU16(buf, offset + 2, n2)
					bufferWriteU8(buf, offset + 4, n3)
					offset += 5
				end
			end
			return
		elseif plan.layout == 2 then
			writeStaticSchemaLayout2Array(values, count, plan, validate)
			return
		end
		for i = 1, count do
			writeStaticSchemaRecord(values[i], plan, validate)
		end
	end

	local function writeU16Array(values: {number}, count: number): ()
		flushBits()
		ensureCapacity(count * (if AutoRuntime.schemaCompactWire then 3 else 2))
		if AutoRuntime.schemaCompactWire then
			for i = 1, count do
				local value = values[i]
				if value < 255 then bufferWriteU8(buf, offset, value); offset += 1
				else bufferWriteU8(buf, offset, 255); bufferWriteU16(buf, offset + 1, value); offset += 3 end
			end
		else
			for i = 1, count do bufferWriteU16(buf, offset, values[i]); offset += 2 end
		end
	end

	local function writeSmallDeltaArray(values: {number}, count: number): ()
		for i = 2, count do
			local delta = values[i] - values[i - 1]
			if delta == 0 then
				writeBits(0, 2)
			else
				writeBits(1, 2)
				writeBits(delta + 7, 4)
			end
		end
	end

	local function writeBooleanArray(values: {boolean}, count: number): ()
		flushBits()
		ensureCapacity(mathFloor((count + 7) / 8))
		local index = 1
		local fullBytes = mathFloor(count / 8)
		for _ = 1, fullBytes do
			local packed = 0
			for bit = 0, 7 do
				if values[index] then packed = bit32bor(packed, bit32lshift(1, bit)) end
				index += 1
			end
			bufferWriteU8(buf, offset, packed)
			offset += 1
		end
		local remaining = count - fullBytes * 8
		if remaining ~= 0 then
			local packed = 0
			for bit = 0, remaining - 1 do
				if values[index] then packed = bit32bor(packed, bit32lshift(1, bit)) end
				index += 1
			end
			bitBuffer = packed
			bitCount = remaining
		end
	end

	local function writeStaticSchemaRootLayout1(
		data: {[string]: any},
		plan: StaticSchemaRootPlan,
		validate: boolean): ()
		local arrayKey, u16Key, u32Key = plan.arrayKey, plan.tailU16Key, plan.tailU32Key
		local values, tailU16, tailU32 = data[arrayKey], data[u16Key], data[u32Key]
		if validate then
			if values == nil then error(`[Pancakes] Required field "{arrayKey}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
			if tailU16 == nil then error(`[Pancakes] Required field "{u16Key}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
			if tailU32 == nil then error(`[Pancakes] Required field "{u32Key}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
		end
		local count = #values
		if AutoRuntime.schemaCompactWire then
			if count < 255 then writeU8(count) else writeU8(255); writeU32(count) end
		elseif count < 65535 then
			writeU16(count)
		else
			writeU16(65535)
			writeU32(count)
		end
		writeStaticSchemaArray(values, count, plan.elementPlan, validate)
		writeU16(tailU16)
		writeU32(tailU32)
	end

	local function getBuffer(): buffer
		flushBits()
		local result = bufferCreate(offset)
		bufferCopy(result, 0, buf, 0, offset)
		releaseWriterInstance(writerInstance, bufSize)
		return result
	end

	local function reset(): ()
		offset, bitBuffer, bitCount = 0, 0, 0
	end

	writerInstance = ({
		EnsureCapacity      = function(_self, n) ensureCapacity(n) end,
		Reserve             = function(_self, n) ensureCapacity(n) end,
		FlushBits           = function(_self) flushBits() end,
		WriteBits           = function(_self, value, bits) writeBits(value, bits) end,
		WriteU8             = function(_self, value) writeU8(value) end,
		WriteU16            = function(_self, value) writeU16(value) end,
		WriteU32            = function(_self, value) writeU32(value) end,
		WriteU64            = function(_self, value) writeU64(value) end,
		WriteI64            = function(_self, value) writeI64(value) end,
		WriteI8             = function(_self, value) writeI8(value) end,
		WriteI16            = function(_self, value) writeI16(value) end,
		WriteF32            = function(_self, value) writeF32(value) end,
		WriteF64            = function(_self, value) writeF64(value) end,
		WriteVarint         = function(_self, value) writeVarint(value) end,
		WriteZigZag         = function(_self, value) writeZigZag(value) end,
		WriteAdaptiveNumber = function(_self, value) writeAdaptiveNumber(value) end,
		WriteStringRaw      = function(_self, str) writeStringRaw(str) end,
		WriteStringCached   = function(_self, str) writeStringCached(str) end,
		GetBuffer           = function(_self) return getBuffer() end,

		_EnsureCapacity      = ensureCapacity,
		_Reserve             = ensureCapacity,
		_FlushBits           = flushBits,
		_WriteBits           = writeBits,
		_WriteU8             = writeU8,
		_WriteU16            = writeU16,
		_WriteU32            = writeU32,
		_WriteU64            = writeU64,
		_WriteI64            = writeI64,
		_WriteI8             = writeI8,
		_WriteI16            = writeI16,
		_WriteF32            = writeF32,
		_WriteF64            = writeF64,
		_WriteVarint         = writeVarint,
		_WriteZigZag         = writeZigZag,
		_WriteAdaptiveNumber = writeAdaptiveNumber,
		_WriteStringRaw      = writeStringRaw,
		_WriteStringCached   = writeStringCached,
		_WriteU16Array       = writeU16Array,
		_WriteBooleanArray   = writeBooleanArray,
		_WriteSmallDeltaArray = writeSmallDeltaArray,
		_WriteStaticRecordArrayChecked = writeStaticRecordArrayChecked,
		_WriteStaticSchemaArray = writeStaticSchemaArray,
		_WriteStaticSchemaRootLayout1 = writeStaticSchemaRootLayout1,
		_Checkpoint          = function() return offset, bitBuffer, bitCount end,
		_Restore             = function(savedOffset, savedBitBuffer, savedBitCount)
			offset, bitBuffer, bitCount = savedOffset, savedBitBuffer, savedBitCount
		end,
		_GetBuffer           = getBuffer,
	} :: any) :: Writer
	(writerInstance :: any)._reset = reset

	return writerInstance
end

releaseWriterInstance = function(w: Writer, size: number): ()
	if not Config.poolingEnabled then
		return
	end
	local bucket = writerSizeBucket(size)
	if bucket > largestWriterPoolBucket then
		largestWriterPoolBucket = bucket
	end
	local pool   = writerPool[bucket]
	if not pool then
		pool = {}
		writerPool[bucket] = pool
	end
	if #pool < Config.writerPoolMaxPerBucket then
		pool[#pool + 1] = w
	end
end

local WriterModule = {}

function WriterModule.new(initialSize: number?): Writer
	local bucket = writerSizeBucket(initialSize or 1024)
	if Config.poolingEnabled then
		local searchBucket = bucket
		while searchBucket <= largestWriterPoolBucket do
			local pool = writerPool[searchBucket]
			if pool and #pool > 0 then
				local w = pool[#pool]
				pool[#pool] = nil
				(w :: any)._reset()
				return w
			end
			searchBucket *= 2
		end
	end
	return newWriterInstance(bucket)
end

export type Reader = {
	ReadBits: (self: Reader, bits: number) -> number,
	FlushBits: (self: Reader) -> (),
	ReadU8: (self: Reader) -> number,
	ReadU16: (self: Reader) -> number,
	ReadU32: (self: Reader) -> number,
	ReadU64: (self: Reader) -> number,
	ReadI8: (self: Reader) -> number,
	ReadI16: (self: Reader) -> number,
	ReadI64: (self: Reader) -> number,
	ReadF32: (self: Reader) -> number,
	ReadF64: (self: Reader) -> number,
	ReadVarint: (self: Reader) -> number,
	ReadZigZag: (self: Reader) -> number,
	ReadAdaptiveNumber: (self: Reader) -> number,
	ReadStringRaw: (self: Reader, len: number) -> string,
	ReadStringCached: (self: Reader) -> string,
	Release: (self: Reader) -> (),

	_ReadBits: (bits: number) -> number,
	_FlushBits: () -> (),
	_ReadU8: () -> number,
	_ReadU16: () -> number,
	_ReadU32: () -> number,
	_ReadU64: () -> number,
	_ReadI8: () -> number,
	_ReadI16: () -> number,
	_ReadI64: () -> number,
	_ReadF32: () -> number,
	_ReadF64: () -> number,
	_ReadVarint: () -> number,
	_ReadZigZag: () -> number,
	_ReadAdaptiveNumber: () -> number,
	_ReadStringRaw: (len: number) -> string,
	_ReadStringCached: () -> string,
	_ReadU16Array: (count: number) -> {number},
	_ReadBooleanArray: (count: number) -> {boolean},
	_ReadDeltaArray: (count: number, readDynamic: () -> number) -> {number},
	_ReadStaticRecordArray: (count: number, plan: AutoRecordPlan) -> {any},
	_ReadStaticSchemaArray: (count: number, plan: StaticSchemaPlan) -> {any},
	_ReadStaticSchemaLayout1Array: (count: number, plan: StaticSchemaPlan) -> {any},
	_ReadStaticSchemaRootLayout1: (plan: StaticSchemaRootPlan) -> {[string]: any},
	_AvailableBits: () -> number,
	_Release: () -> (),
}

local readerPool: {Reader} = {}

local function newReaderInstance(buf: buffer): Reader
	local offset = 0
	local size = bufferLen(buf)
	local bitBuffer = 0
	local bitCount = 0

	local function flushReaderBits(): ()
		bitBuffer = 0
		bitCount  = 0
	end

	local function readBits(bits: number): number
		while bitCount < bits do
			if offset >= size then
				if Config.strictBoundsChecking then
					error("[Pancakes] Bit read out of bounds", 2)
				end
				return 0
			end
			bitBuffer = bit32bor(bitBuffer, bit32lshift(bufferReadU8(buf, offset), bitCount))
			offset   += 1
			bitCount += 8
		end
		local value = bit32band(bitBuffer, BIT_MASK[bits])
		bitBuffer = bit32rshift(bitBuffer, bits)
		bitCount -= bits
		return value
	end

	local function readU8(): number
		if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
		local val = bufferReadU8(buf, offset)
		offset += 1
		return val
	end

	local function readU16(): number
		if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
		local val = bufferReadU16(buf, offset)
		offset += 2
		return val
	end

	local function readU32(): number
		if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
		local val = bufferReadU32(buf, offset)
		offset += 4
		return val
	end

	local function readU64(): number
		flushReaderBits()
		local lo = readU32()
		local hi = readU32()
		return hi * 4294967296 + lo
	end

	local function readI8(): number
		if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
		local val = bufferReadI8(buf, offset)
		offset += 1
		return val
	end

	local function readI16(): number
		if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
		local val = bufferReadI16(buf, offset)
		offset += 2
		return val
	end

	local function readI64(): number
		local encoded = readU64()
		if encoded % 2 == 0 then
			return encoded / 2
		else
			return -(encoded + 1) / 2
		end
	end

	local function readF32(): number
		if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
		local val = bufferReadF32(buf, offset)
		offset += 4
		return val
	end

	local function readF64(): number
		if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
		local val = bufferReadF64(buf, offset)
		offset += 8
		return val
	end

	local function readVarint(): number
		if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
		local result = 0
		local shift  = 0
		while true do
			if offset >= size then break end
			local byte = bufferReadU8(buf, offset)
			offset  += 1
			local bits = bit32band(byte, 0x7F)
			if shift < 32 then
				result = result + bit32lshift(bits, shift)
			else
				result = result + bits * (2 ^ shift)
			end
			if bit32band(byte, 0x80) == 0 then break end
			shift += 7
		end
		return result
	end

	local function readZigZag(): number
		local encoded = readVarint()
		local decoded = bit32bxor(bit32rshift(encoded, 1), -bit32band(encoded, 1))
		if decoded >= 2147483648 then
			decoded -= 4294967296
		end
		return decoded
	end

	local function readAdaptiveNumber(): number
		local tag = readBits(4)
		if tag == ADAPT_ZERO         then return 0
		elseif tag == ADAPT_ONE      then return 1
		elseif tag == ADAPT_NIBBLE   then return readBits(4)
		elseif tag == ADAPT_I8       then return readI8()
		elseif tag == ADAPT_I16      then return readI16()
		elseif tag == ADAPT_U32      then return readU32()
		elseif tag == ADAPT_ZIGZAG32 then return readZigZag()
		elseif tag == ADAPT_F32      then return readF32()
		elseif tag == ADAPT_F64      then return readF64()
		else
			error(`[Pancakes] Unknown adaptive number tag: {tag}`)
		end
	end

	local function readStringRaw(len: number): string
		if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
		local str = bufferReadStr(buf, offset, len)
		offset += len
		return str
	end

	local function readStringCached(): string
		local isCached = readBits(1)
		if isCached == 1 then
			local idx = readBits(16)
			local cachedStr = stringCache.reverse[idx]
			if cachedStr == nil then
				if Config.strictBoundsChecking then
					error(`[Pancakes] Unknown string cache index: {idx}`, 2)
				end
				return ""
			end
			return cachedStr
		end

		local len = readBits(8)
		if len == 0 then return "" end
		if len == 255 then len = readU32() end

		local str = readStringRaw(len)
		local sc  = stringCache
		if len >= Config.stringCacheMinLength and sc.index < 65535 then
			sc.index += 1
			sc.forward[str]      = sc.index
			sc.reverse[sc.index] = str
		end
		return str
	end

	local function readU16Array(count: number): {number}
		flushReaderBits()
		local result = tableCreate(count) :: {number}
		if AutoRuntime.schemaCompactWire then
			for i = 1, count do
				local value = bufferReadU8(buf, offset); offset += 1
				if value == 255 then value = bufferReadU16(buf, offset); offset += 2 end
				result[i] = value
			end
		else
			for i = 1, count do result[i] = bufferReadU16(buf, offset); offset += 2 end
		end
		return result
	end

	local function readBooleanArray(count: number): {boolean}
		flushReaderBits()
		local result = tableCreate(count) :: {boolean}
		local index = 1
		local fullBytes = mathFloor(count / 8)
		for _ = 1, fullBytes do
			local packed = bufferReadU8(buf, offset)
			offset += 1
			for bit = 0, 7 do
				result[index] = bit32band(packed, bit32lshift(1, bit)) ~= 0
				index += 1
			end
		end
		local remaining = count - fullBytes * 8
		if remaining ~= 0 then
			local packed = bufferReadU8(buf, offset)
			offset += 1
			for bit = 0, remaining - 1 do
				result[index] = bit32band(packed, bit32lshift(1, bit)) ~= 0
				index += 1
			end
			bitBuffer = bit32rshift(packed, remaining)
			bitCount = 8 - remaining
		end
		return result
	end

	local function readDeltaArray(count: number, readDynamic: () -> number): {number}
		local result = tableCreate(count) :: {number}
		result[1] = readDynamic()
		for i = 2, count do
			local deltaType = readBits(2)
			if deltaType == 0 then
				result[i] = result[i - 1]
			elseif deltaType == 1 then
				result[i] = result[i - 1] + readBits(4) - 7
			elseif deltaType == 2 then
				result[i] = result[i - 1] + readI8()
			else
				result[i] = readDynamic()
			end
		end
		return result
	end

	local function readStaticRecord(plan: AutoRecordPlan): {[string]: any}
		local RECORD_VALUE_STRING, RECORD_VALUE_BOOLEAN = 1, 2
		local RECORD_VALUE_U16, RECORD_VALUE_I16, RECORD_VALUE_U32 = 3, 4, 5
		local RECORD_VALUE_I32, RECORD_VALUE_F32, RECORD_VALUE_F64, RECORD_VALUE_NESTED = 6, 7, 8, 9
		local result: {[string]: any} = {}
		local keys = plan.keys
		local kinds = plan.kinds
		for i = 1, plan.count do
			local kind = kinds[i]
			if kind == RECORD_VALUE_STRING then
				if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
				local len = bufferReadU8(buf, offset)
				offset += 1
				if len == 255 then
					len = bufferReadU32(buf, offset)
					offset += 4
				end
				result[keys[i]] = bufferReadStr(buf, offset, len)
				offset += len
			elseif kind == RECORD_VALUE_BOOLEAN then
				result[keys[i]] = readBits(1) == 1
			elseif kind == RECORD_VALUE_U16 then
				if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
				local value = bufferReadU8(buf, offset); offset += 1
				if value == 255 then value = bufferReadU16(buf, offset); offset += 2 end
				result[keys[i]] = value
			elseif kind == RECORD_VALUE_I16 then
				if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
				result[keys[i]] = bufferReadI16(buf, offset); offset += 2
			elseif kind == RECORD_VALUE_U32 then
				if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
				result[keys[i]] = bufferReadU32(buf, offset); offset += 4
			elseif kind == RECORD_VALUE_I32 then
				result[keys[i]] = readZigZag()
			elseif kind == RECORD_VALUE_F32 then
				if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
				result[keys[i]] = bufferReadF32(buf, offset); offset += 4
			elseif kind == RECORD_VALUE_F64 then
				if bitCount ~= 0 then bitBuffer, bitCount = 0, 0 end
				result[keys[i]] = bufferReadF64(buf, offset); offset += 8
			elseif kind == RECORD_VALUE_NESTED then
				result[keys[i]] = readStaticRecord(plan.children[i])
			else
				error(`[Pancakes] Non-static field kind {kind} reached the static record reader`, 2)
			end
		end
		return result
	end

	local function readStaticAutoLayout2Array(count: number, plan: AutoRecordPlan): {any}
		local result = tableCreate(count)
		local keys = plan.keys
		local flagsKeys = plan.children[3].keys
		local statsKeys = plan.children[9].keys
		local k1, k2, k3, k4, k5, k6, k7, k8, k9 =
			keys[1], keys[2], keys[3], keys[4], keys[5], keys[6], keys[7], keys[8], keys[9]
		local f1, f2, f3 = flagsKeys[1], flagsKeys[2], flagsKeys[3]
		local s1, s2, s3 = statsKeys[1], statsKeys[2], statsKeys[3]
		bitBuffer, bitCount = 0, 0
		local headerOffset = offset
		offset += mathCeil(count * 6 / 8)
		for i = 1, count do
			local bitPosition = (i - 1) * 6
			local bytePosition = headerOffset + mathFloor(bitPosition / 8)
			local shift = bitPosition % 8
			local packed = bufferReadU8(buf, bytePosition)
			if shift > 2 then packed = bit32bor(packed, bit32lshift(bufferReadU8(buf, bytePosition + 1), 8)) end
			local header = bit32band(bit32rshift(packed, shift), 63)
			local id = bufferReadU8(buf, offset); offset += 1
			if id == 255 then id = bufferReadU16(buf, offset); offset += 2 end
			local nameLen = bufferReadU8(buf, offset); offset += 1
			if nameLen == 255 then nameLen = bufferReadU32(buf, offset); offset += 4 end
			local name = bufferReadStr(buf, offset, nameLen); offset += nameLen
			local orderIndex = bufferReadU8(buf, offset); offset += 1
			if orderIndex == 255 then orderIndex = bufferReadU16(buf, offset); offset += 2 end
			local rarityLen = bufferReadU8(buf, offset); offset += 1
			if rarityLen == 255 then rarityLen = bufferReadU32(buf, offset); offset += 4 end
			local rarity = bufferReadStr(buf, offset, rarityLen); offset += rarityLen
			local sv1 = bufferReadU8(buf, offset); offset += 1
			if sv1 == 255 then sv1 = bufferReadU16(buf, offset); offset += 2 end
			local sv2 = bufferReadU8(buf, offset); offset += 1
			if sv2 == 255 then sv2 = bufferReadU16(buf, offset); offset += 2 end
			local sv3 = bufferReadU8(buf, offset); offset += 1
			if sv3 == 255 then sv3 = bufferReadU16(buf, offset); offset += 2 end
			result[i] = {
				[k1] = bit32band(header, 1) ~= 0,
				[k2] = bit32band(header, 2) ~= 0,
				[k3] = {
					[f1] = bit32band(header, 4) ~= 0,
					[f2] = bit32band(header, 8) ~= 0,
					[f3] = bit32band(header, 16) ~= 0,
				},
				[k4] = id,
				[k5] = bit32band(header, 32) ~= 0,
				[k6] = name,
				[k7] = orderIndex,
				[k8] = rarity,
				[k9] = {[s1] = sv1, [s2] = sv2, [s3] = sv3},
			}
		end
		return result
	end

	local function readStaticRecordArray(count: number, plan: AutoRecordPlan): {any}
		local result = tableCreate(count)
		if plan.layout == 1 then
			local keys = plan.keys
			local childKeys = plan.children[5].keys
			local k1, k2, k3, k4, k5 = keys[1], keys[2], keys[3], keys[4], keys[5]
			local c1, c2, c3 = childKeys[1], childKeys[2], childKeys[3]
			bitBuffer, bitCount = 0, 0
			local headerOffset = offset
			offset += mathCeil(count / 8)
			for i = 1, count do
				local bitIndex = i - 1
				local v1 = bit32band(bufferReadU8(buf, headerOffset + mathFloor(bitIndex / 8)), bit32lshift(1, bitIndex % 8)) ~= 0
				local v2 = bufferReadU8(buf, offset); offset += 1
				if v2 == 255 then v2 = bufferReadU16(buf, offset); offset += 2 end
				local len3 = bufferReadU8(buf, offset); offset += 1
				if len3 == 255 then len3 = bufferReadU32(buf, offset); offset += 4 end
				local v3 = bufferReadStr(buf, offset, len3); offset += len3
				local len4 = bufferReadU8(buf, offset); offset += 1
				if len4 == 255 then len4 = bufferReadU32(buf, offset); offset += 4 end
				local v4 = bufferReadStr(buf, offset, len4); offset += len4
				local n1 = bufferReadU8(buf, offset); offset += 1
				if n1 == 255 then n1 = bufferReadU16(buf, offset); offset += 2 end
				local n2 = bufferReadU8(buf, offset); offset += 1
				if n2 == 255 then n2 = bufferReadU16(buf, offset); offset += 2 end
				local n3 = bufferReadU8(buf, offset); offset += 1
				if n3 == 255 then n3 = bufferReadU16(buf, offset); offset += 2 end
				result[i] = {
					[k1] = v1,
					[k2] = v2,
					[k3] = v3,
					[k4] = v4,
					[k5] = {[c1] = n1, [c2] = n2, [c3] = n3},
				}
			end
			return result
		elseif plan.layout == 2 then
			return readStaticAutoLayout2Array(count, plan)
		end
		for i = 1, count do
			result[i] = readStaticRecord(plan)
		end
		return result
	end

	local function readStaticSchemaLayout1Array(count: number, plan: StaticSchemaPlan): {any}
		local result = tableCreate(count)
		local h1 = plan.headerKeys[1]
		local keys = plan.valueKeys
		local childKeys = plan.children[4].valueKeys
		local k1, k2, k3, k4 = keys[1], keys[2], keys[3], keys[4]
		local c1, c2, c3 = childKeys[1], childKeys[2], childKeys[3]
		for i = 1, count do
			local hv: boolean
			if bitCount ~= 0 then
				hv = bit32band(bitBuffer, 1) == 1
			else
				hv = bit32band(bufferReadU8(buf, offset), 1) == 1
				offset += 1
			end
			bitBuffer, bitCount = 0, 0
			local v1: number
			if AutoRuntime.schemaCompactWire then v1 = bufferReadU8(buf, offset); offset += 1; if v1 == 255 then v1 = bufferReadU16(buf, offset); offset += 2 end
			else v1 = bufferReadU16(buf, offset); offset += 2 end
			local len2: number
			if AutoRuntime.schemaCompactWire then len2 = bufferReadU8(buf, offset); offset += 1; if len2 == 255 then len2 = bufferReadU32(buf, offset); offset += 4 end
			else len2 = bufferReadU16(buf, offset); offset += 2; if len2 == 65535 then len2 = bufferReadU32(buf, offset); offset += 4 end end
			local v2 = bufferReadStr(buf, offset, len2); offset += len2
			local len3: number
			if AutoRuntime.schemaCompactWire then len3 = bufferReadU8(buf, offset); offset += 1; if len3 == 255 then len3 = bufferReadU32(buf, offset); offset += 4 end
			else len3 = bufferReadU16(buf, offset); offset += 2; if len3 == 65535 then len3 = bufferReadU32(buf, offset); offset += 4 end end
			local v3 = bufferReadStr(buf, offset, len3); offset += len3
			local n1: number
			local n2: number
			local n3: number
			if AutoRuntime.schemaCompactWire then
				n1 = bufferReadU8(buf, offset); offset += 1
				if n1 == 255 then n1 = bufferReadU16(buf, offset); offset += 2 end
				n2 = bufferReadU8(buf, offset); offset += 1
				if n2 == 255 then n2 = bufferReadU16(buf, offset); offset += 2 end
				n3 = bufferReadU8(buf, offset); offset += 1
			else
				n1 = bufferReadU16(buf, offset)
				n2 = bufferReadU16(buf, offset + 2)
				n3 = bufferReadU8(buf, offset + 4)
				offset += 5
			end
			result[i] = {
				[h1] = hv,
				[k1] = v1,
				[k2] = v2,
				[k3] = v3,
				[k4] = {[c1] = n1, [c2] = n2, [c3] = n3},
			}
		end
		return result
	end

	local function readStaticSchemaLayout2Array(count: number, plan: StaticSchemaPlan): {any}
		local result = tableCreate(count)
		local hk, keys = plan.headerKeys, plan.valueKeys
		local statsKeys = plan.children[4].valueKeys
		local flagsKeys = plan.children[5].headerKeys
		local h1, h2, h3 = hk[1], hk[2], hk[3]
		local k1, k2, k3, k4, k5, k6 = keys[1], keys[2], keys[3], keys[4], keys[5], keys[6]
		local s1, s2, s3 = statsKeys[1], statsKeys[2], statsKeys[3]
		local f1, f2, f3 = flagsKeys[1], flagsKeys[2], flagsKeys[3]
		bitBuffer, bitCount = 0, 0
		if AutoRuntime.schemaCompactWire then
			local headerOffset = offset
			offset += mathCeil(count * 6 / 8)
			for i = 1, count do
				local bitPosition = (i - 1) * 6
				local bytePosition = headerOffset + mathFloor(bitPosition / 8)
				local shift = bitPosition % 8
				local packed = bufferReadU8(buf, bytePosition)
				if shift > 2 then packed = bit32bor(packed, bit32lshift(bufferReadU8(buf, bytePosition + 1), 8)) end
				local header = bit32band(bit32rshift(packed, shift), 63)
				local v1 = bufferReadU8(buf, offset); offset += 1
				if v1 == 255 then v1 = bufferReadU16(buf, offset); offset += 2 end
				local len2 = bufferReadU8(buf, offset); offset += 1
				if len2 == 255 then len2 = bufferReadU32(buf, offset); offset += 4 end
				local v2 = bufferReadStr(buf, offset, len2); offset += len2
				local len3 = bufferReadU8(buf, offset); offset += 1
				if len3 == 255 then len3 = bufferReadU32(buf, offset); offset += 4 end
				local v3 = bufferReadStr(buf, offset, len3); offset += len3
				local sv1 = bufferReadU8(buf, offset); offset += 1
				if sv1 == 255 then sv1 = bufferReadU16(buf, offset); offset += 2 end
				local sv2 = bufferReadU8(buf, offset); offset += 1
				if sv2 == 255 then sv2 = bufferReadU16(buf, offset); offset += 2 end
				local sv3 = bufferReadU8(buf, offset); offset += 1
				local v6 = bufferReadU8(buf, offset); offset += 1
				if v6 == 255 then v6 = bufferReadU16(buf, offset); offset += 2 end
				result[i] = {
					[h1] = bit32band(header, 1) ~= 0,
					[h2] = bit32band(header, 2) ~= 0,
					[h3] = bit32band(header, 4) ~= 0,
					[k1] = v1, [k2] = v2, [k3] = v3,
					[k4] = {[s1] = sv1, [s2] = sv2, [s3] = sv3},
					[k5] = {
						[f1] = bit32band(header, 8) ~= 0,
						[f2] = bit32band(header, 16) ~= 0,
						[f3] = bit32band(header, 32) ~= 0,
					},
					[k6] = v6,
				}
			end
			return result
		end
		for i = 1, count do
			local header = bufferReadU8(buf, offset)
			local v1 = bufferReadU16(buf, offset + 1)
			offset += 3
			local len2: number
			if AutoRuntime.schemaCompactWire then len2 = bufferReadU8(buf, offset); offset += 1; if len2 == 255 then len2 = bufferReadU32(buf, offset); offset += 4 end
			else len2 = bufferReadU16(buf, offset); offset += 2; if len2 == 65535 then len2 = bufferReadU32(buf, offset); offset += 4 end end
			local v2 = bufferReadStr(buf, offset, len2); offset += len2
			local len3: number
			if AutoRuntime.schemaCompactWire then len3 = bufferReadU8(buf, offset); offset += 1; if len3 == 255 then len3 = bufferReadU32(buf, offset); offset += 4 end
			else len3 = bufferReadU16(buf, offset); offset += 2; if len3 == 65535 then len3 = bufferReadU32(buf, offset); offset += 4 end end
			local v3 = bufferReadStr(buf, offset, len3); offset += len3
			local sv1 = bufferReadU16(buf, offset)
			local sv2 = bufferReadU16(buf, offset + 2)
			local sv3 = bufferReadU8(buf, offset + 4)
			local flagByte = bufferReadU8(buf, offset + 5)
			local v6 = bufferReadU16(buf, offset + 6)
			offset += 8
			result[i] = {
				[h1] = bit32band(header, 1) ~= 0,
				[h2] = bit32band(header, 2) ~= 0,
				[h3] = bit32band(header, 4) ~= 0,
				[k1] = v1,
				[k2] = v2,
				[k3] = v3,
				[k4] = {[s1] = sv1, [s2] = sv2, [s3] = sv3},
				[k5] = {
					[f1] = bit32band(flagByte, 1) ~= 0,
					[f2] = bit32band(flagByte, 2) ~= 0,
					[f3] = bit32band(flagByte, 4) ~= 0,
				},
				[k6] = v6,
			}
		end
		return result
	end

	local function readStaticSchemaRecord(plan: StaticSchemaPlan): {[string]: any}
		local result: {[string]: any} = {}
		local headerKeys = plan.headerKeys
		local headerOptional = plan.headerOptional
		for i = 1, plan.headerCount do
			if headerOptional[i] then
				if readBits(1) == 1 then result[headerKeys[i]] = readBits(1) == 1 end
			else
				result[headerKeys[i]] = readBits(1) == 1
			end
		end

		local keys = plan.valueKeys
		local optional = plan.valueOptional
		local kinds = plan.kinds
		for i = 1, plan.valueCount do
			if optional[i] and readBits(1) == 0 then continue end
			local kind = kinds[i]
			local value: any
			if kind == 1 then value = readU8()
			elseif kind == 2 then value = readI8()
			elseif kind == 3 then
				if AutoRuntime.schemaCompactWire then value = readU8(); if value == 255 then value = readU16() end
				else value = readU16() end
			elseif kind == 4 then value = readI16()
			elseif kind == 5 then value = readU32()
			elseif kind == 6 then value = readZigZag()
			elseif kind == 7 then value = readU64()
			elseif kind == 8 then value = readI64()
			elseif kind == 9 then value = readF32()
			elseif kind == 10 then value = readF64()
			elseif kind == 11 then
				local len: number
				if AutoRuntime.schemaCompactWire then len = readU8(); if len == 255 then len = readU32() end
				else len = readU16(); if len == 65535 then len = readU32() end end
				value = readStringRaw(len)
			else
				value = readStaticSchemaRecord(plan.children[i])
			end
			result[keys[i]] = value
		end
		return result
	end

	local function readStaticSchemaArray(count: number, plan: StaticSchemaPlan): {any}
		if plan.optionalCount > 0 then
			local result = tableCreate(count)
			local headerKeys, headerOptional = plan.headerKeys, plan.headerOptional
			local valueKeys, valueOptional = plan.valueKeys, plan.valueOptional
			for rowIndex = 1, count do
				local row: {[string]: any} = {}
				result[rowIndex] = row
				for fieldIndex = 1, plan.headerCount do
					local key = headerKeys[fieldIndex]
					if headerOptional[fieldIndex] then
						if readBits(1) == 1 then row[key] = readBits(1) == 1 end
					else row[key] = readBits(1) == 1 end
				end
				for fieldIndex = 1, plan.valueCount do
					if valueOptional[fieldIndex] and readBits(1) == 1 then row[valueKeys[fieldIndex]] = true end
				end
			end
			flushReaderBits()
			local kinds, children = plan.kinds, plan.children
			for rowIndex = 1, count do
				local row = result[rowIndex]
				for fieldIndex = 1, plan.valueCount do
					local key = valueKeys[fieldIndex]
					if valueOptional[fieldIndex] and row[key] == nil then continue end
					local kind, value = kinds[fieldIndex], nil
					if kind == 1 then value = readU8()
					elseif kind == 2 then value = readI8()
					elseif kind == 3 then
						if AutoRuntime.schemaCompactWire then value = readU8(); if value == 255 then value = readU16() end
						else value = readU16() end
					elseif kind == 4 then value = readI16()
					elseif kind == 5 then value = readU32()
					elseif kind == 6 then value = readZigZag()
					elseif kind == 7 then value = readU64()
					elseif kind == 8 then value = readI64()
					elseif kind == 9 then value = readF32()
					elseif kind == 10 then value = readF64()
					elseif kind == 11 then
						local len: number
						if AutoRuntime.schemaCompactWire then len = readU8(); if len == 255 then len = readU32() end
						else len = readU16(); if len == 65535 then len = readU32() end end
						value = readStringRaw(len)
					else value = readStaticSchemaRecord(children[fieldIndex]) end
					row[key] = value
				end
			end
			return result
		elseif plan.layout == 1 then
			return readStaticSchemaLayout1Array(count, plan)
		elseif plan.layout == 2 then
			return readStaticSchemaLayout2Array(count, plan)
		end
		local result = tableCreate(count)
		for i = 1, count do
			result[i] = readStaticSchemaRecord(plan)
		end
		return result
	end

	local function readStaticSchemaRootLayout1(plan: StaticSchemaRootPlan): {[string]: any}
		local count: number
		if AutoRuntime.schemaCompactWire then count = readU8(); if count == 255 then count = readU32() end
		else count = readU16(); if count == 65535 then count = readU32() end end
		if Config.strictBoundsChecking and count > AutoRuntime.decodeBitBudget then
			error(`[Pancakes] "{plan.arrayKey}": declared array length {count} exceeds the decode safety budget ({AutoRuntime.decodeBitBudget} bits)`, 2)
		end
		local values = readStaticSchemaLayout1Array(count, plan.elementPlan)
		local tailU16 = readU16()
		local tailU32 = readU32()
		return {
			[plan.arrayKey] = values,
			[plan.tailU16Key] = tailU16,
			[plan.tailU32Key] = tailU32,
		}
	end

	local function availableBits(): number
		return (size - offset) * 8 + bitCount
	end

	local readerInstance: Reader

	local function release(): ()
		if not Config.poolingEnabled then
			return
		end
		if #readerPool < Config.readerPoolMax then
			readerPool[#readerPool + 1] = readerInstance
		end
	end

	readerInstance = ({
		ReadBits           = function(_self, bits) return readBits(bits) end,
		FlushBits          = function(_self) flushReaderBits() end,
		ReadU8             = function(_self) return readU8() end,
		ReadU16            = function(_self) return readU16() end,
		ReadU32            = function(_self) return readU32() end,
		ReadU64            = function(_self) return readU64() end,
		ReadI8             = function(_self) return readI8() end,
		ReadI16            = function(_self) return readI16() end,
		ReadI64            = function(_self) return readI64() end,
		ReadF32            = function(_self) return readF32() end,
		ReadF64            = function(_self) return readF64() end,
		ReadVarint         = function(_self) return readVarint() end,
		ReadZigZag         = function(_self) return readZigZag() end,
		ReadAdaptiveNumber = function(_self) return readAdaptiveNumber() end,
		ReadStringRaw      = function(_self, len) return readStringRaw(len) end,
		ReadStringCached   = function(_self) return readStringCached() end,
		Release            = function(_self) release() end,

		_ReadBits           = readBits,
		_FlushBits          = flushReaderBits,
		_ReadU8             = readU8,
		_ReadU16            = readU16,
		_ReadU32            = readU32,
		_ReadU64            = readU64,
		_ReadI8             = readI8,
		_ReadI16            = readI16,
		_ReadI64            = readI64,
		_ReadF32            = readF32,
		_ReadF64            = readF64,
		_ReadVarint         = readVarint,
		_ReadZigZag         = readZigZag,
		_ReadAdaptiveNumber = readAdaptiveNumber,
		_ReadStringRaw      = readStringRaw,
		_ReadStringCached   = readStringCached,
		_ReadU16Array       = readU16Array,
		_ReadBooleanArray   = readBooleanArray,
		_ReadDeltaArray     = readDeltaArray,
		_ReadStaticRecordArray = readStaticRecordArray,
		_ReadStaticSchemaArray = readStaticSchemaArray,
		_ReadStaticSchemaLayout1Array = readStaticSchemaLayout1Array,
		_ReadStaticSchemaRootLayout1 = readStaticSchemaRootLayout1,
		_AvailableBits      = availableBits,
		_Release            = release,
	} :: any) :: Reader

	(readerInstance :: any)._rebind = function(newBuf: buffer): ()
		buf, offset, size, bitBuffer, bitCount = newBuf, 0, bufferLen(newBuf), 0, 0
	end

	return readerInstance
end

local ReaderModule = {}

function ReaderModule.new(buf: buffer): Reader
	if Config.poolingEnabled then
		local pool = readerPool
		if #pool > 0 then
			local r = pool[#pool]
			pool[#pool] = nil
			(r :: any)._rebind(buf)
			return r
		end
	end
	return newReaderInstance(buf)
end

local Writer = WriterModule
local Reader = ReaderModule

local SerializeValue: (writer: Writer, value: any) -> ()
local DeserializeValue: (reader: Reader) -> any

local function writeCountHeader(writer: Writer, count: number): ()
	if count <= 255 then
		writer._WriteBits(0, 2)
		writer._WriteU8(count)
	elseif count <= 65535 then
		writer._WriteBits(1, 2)
		writer._WriteU16(count)
	else
		writer._WriteBits(2, 2)
		writer._WriteU32(count)
	end
end

local function readCountHeader(reader: Reader): number
	local widthCode = reader._ReadBits(2)
	if widthCode == 0 then
		return reader._ReadU8()
	elseif widthCode == 1 then
		return reader._ReadU16()
	else
		return reader._ReadU32()
	end
end

function AutoRuntime.beginDecode(buf: buffer): ()
	if Config.strictBoundsChecking then
		AutoRuntime.decodeBitBudget = bufferLen(buf) * 8
	else
		AutoRuntime.decodeBitBudget = 0
	end
end

function AutoRuntime.readCountChecked(reader: Reader, minBitsPerEntry: number): number
	local count = readCountHeader(reader)
	if Config.strictBoundsChecking then
		local neededBits = count * minBitsPerEntry
		if neededBits > AutoRuntime.decodeBitBudget then
			error(`[Pancakes] Declared count {count} exceeds the decode safety budget ({AutoRuntime.decodeBitBudget} bits, {neededBits} required)`, 2)
		end
	end
	return count
end

function AutoRuntime.readCountCheckedBits(reader: Reader): number
	local count = readCountHeader(reader)
	if Config.strictBoundsChecking then
		if count > AutoRuntime.decodeBitBudget then
			error(`[Pancakes] Declared boolean array count {count} exceeds the decode safety budget ({AutoRuntime.decodeBitBudget} bits)`, 2)
		end
	end
	return count
end

local function keyLess(a: any, b: any): boolean
	local ta, tb = type(a), type(b)
	if ta == tb then
		if ta == "number" then return (a :: number) < (b :: number) end
		if ta == "string" then return (a :: string) < (b :: string) end
		return tostring(a) < tostring(b)
	end
	if ta == "number" then return true end
	if tb == "number" then return false end
	return tostring(a) < tostring(b)
end

function AutoRuntime.findShape(keys: {any}, count: number): (AutoShapeEntry?, boolean)
	if count == 0 then
		return nil, false
	end

	local bucket = AutoRuntime.shapeBuckets[count]
	if bucket then
		for i = 1, AutoRuntime.shapeBucketCounts[count] or 0 do
			local entry = bucket[i]
			local same = true
			for k = 1, count do
				if entry.keys[k] ~= keys[k] then
					same = false
					break
				end
			end
			if same then
				return entry, true
			end
		end
	end
	for i = 1, count do
		if type(keys[i]) ~= "string" then
			return nil, false
		end
	end
	return nil, true
end

function AutoRuntime.registerShape(keys: {any}, count: number, values: {[any]: any}): ()
	local AUTO_VALUE_NUMBER, AUTO_VALUE_STRING, AUTO_VALUE_BOOLEAN = 1, 2, 3
	local existing, eligible = AutoRuntime.findShape(keys, count)
	if existing ~= nil or not eligible or AutoRuntime.shapeIndex >= 255 then
		return
	end

	local bucket = AutoRuntime.shapeBuckets[count]
	if bucket == nil then
		bucket = {}
		AutoRuntime.shapeBuckets[count] = bucket
	end
	local bucketIndex = (AutoRuntime.shapeBucketCounts[count] or 0) + 1
	AutoRuntime.shapeBucketCounts[count] = bucketIndex
	local entry = bucket[bucketIndex]
	if entry == nil then
		entry = {id = 0, keys = tableCreate(count), kinds = tableCreate(count, 0)}
		bucket[bucketIndex] = entry
	end
	local owned = entry.keys
	local kinds = entry.kinds
	for i = 1, count do
		local key = keys[i] :: string
		owned[i] = key
		local valueType = type(values[key])
		if valueType == "number" then
			kinds[i] = AUTO_VALUE_NUMBER
		elseif valueType == "string" then
			kinds[i] = AUTO_VALUE_STRING
		elseif valueType == "boolean" then
			kinds[i] = AUTO_VALUE_BOOLEAN
		end
	end
	AutoRuntime.shapeIndex += 1
	entry.id = AutoRuntime.shapeIndex
	AutoRuntime.shapesById[entry.id] = entry
end

local function getSortedKeys(tbl: {[any]: any}, keys: {any}, count: number): {any}
	if Config.sortedKeysCacheEnabled then
		local cached = sortedKeysCache[tbl]
		if cached and cached.count == count then
			local sortedKeys = cached.sortedKeys
			if keys == sortedKeys then
				return sortedKeys
			end
			if Config.sortedKeysCacheTrustMode then
				return sortedKeys
			end
			local stillValid = true
			for i = 1, count do
				if tbl[sortedKeys[i]] == nil then
					stillValid = false
					break
				end
			end
			if stillValid then
				return sortedKeys
			end
		end
	end
	if Config.sortedKeysCacheEnabled then
		local structural = AutoRuntime.structuralKeyBuckets[count]
		if structural ~= nil then
			for candidateIndex = 1, #structural do
				local candidate = structural[candidateIndex]
				local matches = true
				for keyIndex = 1, count do
					if tbl[candidate[keyIndex]] == nil then matches = false; break end
				end
				if matches then
					sortedKeysCache[tbl] = {sortedKeys = candidate, count = count}
					return candidate
				end
			end
		end
	end

	tableSort(keys, keyLess)

	if Config.sortedKeysCacheEnabled then
		local owned = tableCreate(count)
		table.move(keys, 1, count, 1, owned)
		sortedKeysCache[tbl] = {sortedKeys = owned, count = count}
		local allStrings = count > 0
		for i = 1, count do if type(owned[i]) ~= "string" then allStrings = false; break end end
		if allStrings then
			local structural = AutoRuntime.structuralKeyBuckets[count]
			if structural == nil then structural = {}; AutoRuntime.structuralKeyBuckets[count] = structural end
			if #structural < 8 then structural[#structural + 1] = owned :: {string} end
		end
	end
	return keys
end

export type ConverterWriteFn = (writer: Writer, value: any) -> ()
export type ConverterReadFn  = (reader: Reader) -> any

type ConverterEntry = {
	metatable: {any},
	id:        number,
	write:     ConverterWriteFn,
	read:      ConverterReadFn,
}

local converterById: {[number]: ConverterEntry} = {}

function Pancakes.RegisterConverter(
	classMetatable: {any},
	writeFn: ConverterWriteFn,
	readFn: ConverterReadFn
): ()
	if converterByMetatable[classMetatable] ~= nil then
		error("[Pancakes] A converter for this class/metatable is already registered.")
	end
	converterCount += 1
	if converterCount > 65535 then
		error("[Pancakes] RegisterConverter: exceeded 65535 registered custom types")
	end
	local entry: ConverterEntry = {
		metatable = classMetatable,
		id        = converterCount,
		write     = writeFn,
		read      = readFn,
	}
	converterByMetatable[classMetatable] = entry
	converterById[converterCount] = entry
end

function Pancakes.UnregisterAllConverters(): ()
	table.clear(converterByMetatable)
	table.clear(converterById)
	converterCount = 0
end

SerializeValue = function(writer: Writer, value: any): ()
	local valueType = typeof(value)

	if valueType == "number" then
		if value == 0 then
			writer._WriteBits(TYPE_NUMBER_ZERO, 5)
		elseif value == 1 then
			writer._WriteBits(TYPE_NUMBER_ONE, 5)
		elseif value % 1 == 0 and value >= 2 and value <= 15 then
			writer._WriteBits(TYPE_SPECIAL, 5)
			writer._WriteBits(SUBTYPE_NUMBER_NIBBLE, 5)
			writer._WriteBits(value, 4)
		elseif value % 1 == 0 and mathAbs(value) < 9007199254740992 then
			if value >= -127 and value <= 127 then
				writer._WriteBits(TYPE_NUMBER_I8, 5)
				writer._WriteI8(value)
			elseif value >= -32768 and value <= 32767 then
				writer._WriteBits(TYPE_NUMBER_I16, 5)
				writer._WriteI16(value)
			elseif value >= 0 and value <= 4294967295 then
				writer._WriteBits(TYPE_NUMBER_U32, 5)
				writer._WriteU32(value)
			elseif value >= -2147483648 and value < 0 then
				writer._WriteBits(TYPE_NUMBER_ZIGZAG, 5)
				writer._WriteZigZag(value)
			else
				writer._WriteBits(TYPE_NUMBER_F64, 5)
				writer._WriteF64(value)
			end
		else
			if isExactF32(value) then
				writer._WriteBits(TYPE_NUMBER_F32, 5)
				writer._WriteF32(value)
			else
				writer._WriteBits(TYPE_NUMBER_F64, 5)
				writer._WriteF64(value)
			end
		end

	elseif valueType == "string" then
		local len         = #value
		local commonIndex = COMMON_KEY_MAP[value]
		if commonIndex then
			writer._WriteBits(TYPE_SPECIAL, 5)
			writer._WriteBits(SUBTYPE_STRING_COMMON, 5)
			writer._WriteBits(commonIndex, 5)
		elseif len == 0 then
			writer._WriteBits(TYPE_STRING_EMPTY, 5)
		elseif len <= 15 then
			writer._WriteBits(TYPE_STRING_TINY, 5)
			writer._WriteBits(len, 4)
			writer._FlushBits()
			writer._WriteStringRaw(value)
		else
			writer._WriteBits(TYPE_STRING_SHORT, 5)
			writer._WriteStringCached(value)
		end

	elseif valueType == "boolean" then
		writer._WriteBits(value and TYPE_BOOLEAN_TRUE or TYPE_BOOLEAN_FALSE, 5)

	elseif valueType == "nil" then
		writer._WriteBits(TYPE_NIL, 5)

	elseif valueType == "table" then
		local mt = converterCount > 0 and getmetatable(value) or nil
		local converter = mt and (converterByMetatable[mt] or (mt.__type and converterByMetatable[mt.__type]))
		if converter then
			writer._WriteBits(TYPE_SPECIAL, 5)
			writer._WriteBits(SUBTYPE_CUSTOM, 5)
			writer._WriteBits(converter.id, 16)
			converter.write(writer, value)
			return
		end

		local kind, count, extraA, extraB, keys = classifyTable(value)

		if kind == KIND_BOOL_ARRAY then
			local bc = count
			writer._WriteBits(TYPE_SPECIAL, 5)
			writer._WriteBits(SUBTYPE_BOOLEAN_ARRAY, 5)
			writeCountHeader(writer, bc)
			writer._WriteBooleanArray(value, bc)

		elseif kind == KIND_NUM_ARRAY then
			local ac = count
			if (extraA or 0) > ac * Config.rleThreshold then
				writer._WriteBits(TYPE_ARRAY_RLE, 5)
				writeCountHeader(writer, ac)
				local i = 1
				while i <= ac do
					local val = value[i]
					local run = 1
					while i + run <= ac and value[i + run] == val do run += 1 end
					writer._WriteU8(mathMin(run, 255))
					SerializeValue(writer, val)
					i += run
				end
			else
				writer._WriteBits(TYPE_ARRAY_DELTA, 5)
				writeCountHeader(writer, ac)
				SerializeValue(writer, value[1])
				if extraB == "small" then
					writer._WriteSmallDeltaArray(value, ac)
				else
					for i = 2, ac do
						local delta = value[i] - value[i - 1]
						if delta == 0 then
							writer._WriteBits(0, 2)
						elseif delta % 1 == 0 and delta >= -7 and delta <= 7 then
							writer._WriteBits(1, 2)
							writer._WriteBits(bit32band(delta + 7, 15), 4)
						elseif delta % 1 == 0 and delta >= -128 and delta <= 127 then
							writer._WriteBits(2, 2)
							writer._WriteI8(delta)
						else
							writer._WriteBits(3, 2)
							SerializeValue(writer, value[i])
						end
					end
				end
			end

		elseif kind == KIND_SEQ_NUMERIC then
			local sc = count
			local sk = extraA :: number
			writer._WriteBits(TYPE_TABLE_SEQUENTIAL, 5)
			writer._WriteBits(0, 1)
			writeCountHeader(writer, sc)
			writer._WriteI16(sk)
			for i = 0, sc - 1 do
				SerializeValue(writer, value[sk + i])
			end

		elseif kind == KIND_SEQ_PATTERN then
			local sc  = count
			local pat = extraB :: string
			writer._WriteBits(TYPE_TABLE_SEQUENTIAL, 5)
			writer._WriteBits(1, 1)
			writeCountHeader(writer, sc)
			writer._WriteStringCached(pat)
			for i = 1, sc do
				SerializeValue(writer, value[pat .. i])
			end

		elseif kind == KIND_GENERIC_DENSE then
			if count >= 2 and AutoRuntime.serializeRecordArray(writer, value, count) then
			else
				writer._WriteBits(TYPE_SPECIAL, 5)
				writer._WriteBits(SUBTYPE_DENSE_ARRAY, 5)
				writeCountHeader(writer, count)
				local denseMode = AutoRuntime.classifyDenseDatatype(value, count)
				writer._WriteBits(denseMode, 3)
				if denseMode == 0 then for i = 1, count do SerializeValue(writer, value[i]) end
				else AutoRuntime.writeDenseDatatype(writer, value, count, denseMode) end
			end

		else
			local keyList = keys :: {any}
			local keysUseArena = arenaTop > 0 and keyArena[arenaTop] == keyList
			local sortedKeys = getSortedKeys(value, keyList, count)
			local shape, shapeEligible = AutoRuntime.findShape(sortedKeys, count)
			if shape ~= nil then
				local AUTO_VALUE_DYNAMIC, AUTO_VALUE_NUMBER, AUTO_VALUE_STRING, AUTO_VALUE_BOOLEAN = 0, 1, 2, 3
				local shapeKeys = shape.keys
				local shapeKinds = shape.kinds
				local typedShape = true
				for i = 1, count do
					local kind = shapeKinds[i]
					if kind ~= AUTO_VALUE_DYNAMIC then
						local actualType = type(value[shapeKeys[i]])
						if (kind == AUTO_VALUE_NUMBER and actualType ~= "number")
							or (kind == AUTO_VALUE_STRING and actualType ~= "string")
							or (kind == AUTO_VALUE_BOOLEAN and actualType ~= "boolean") then
							typedShape = false
							break
						end
					end
				end

				writer._WriteBits(TYPE_SPECIAL, 5)
				writer._WriteBits(typedShape and SUBTYPE_TYPED_TABLE_SHAPE or SUBTYPE_TABLE_SHAPE, 5)
				writer._WriteBits(shape.id, 8)
				if typedShape then
					for i = 1, count do
						local fieldValue = value[shapeKeys[i]]
						local kind = shapeKinds[i]
						if kind == AUTO_VALUE_NUMBER then
							writer._WriteAdaptiveNumber(fieldValue)
						elseif kind == AUTO_VALUE_STRING then
							local len = #fieldValue
							if len < 255 then
								writer._WriteU8(len)
							else
								writer._WriteU8(255)
								writer._WriteU32(len)
							end
							writer._WriteStringRaw(fieldValue)
						elseif kind == AUTO_VALUE_BOOLEAN then
							writer._WriteBits(fieldValue and 1 or 0, 1)
						else
							SerializeValue(writer, fieldValue)
						end
					end
				else
					for i = 1, count do
						SerializeValue(writer, value[shapeKeys[i]])
					end
				end
			else
				if count <= 15 then
					writer._WriteBits(TYPE_TABLE_TINY, 5)
					writer._WriteBits(count, 4)
				else
					writer._WriteBits(TYPE_TABLE, 5)
					writeCountHeader(writer, count)
				end
				for i = 1, count do
					local k = sortedKeys[i]
					AutoRuntime.serializeKey(writer, k)
					SerializeValue(writer, value[k])
				end
				if shapeEligible then
					AutoRuntime.registerShape(sortedKeys, count, value)
				end
			end
			if keysUseArena then
				releaseKeyArray()
			end
		end

	elseif valueType == "Vector3" then
		local x, y, z = value.X, value.Y, value.Z
		if x % 1 == 0 and y % 1 == 0 and z % 1 == 0
			and x >= -32768 and x <= 32767
			and y >= -32768 and y <= 32767
			and z >= -32768 and z <= 32767 then
			writer._WriteBits(TYPE_VECTOR3_INT, 5)
			writer._WriteI16(x); writer._WriteI16(y); writer._WriteI16(z)
			return
		end
		local xi, yi, zi = mathFloor(x), mathFloor(y), mathFloor(z)
		local xf, yf, zf = x - xi, y - yi, z - zi
		if xi >= -32768 and xi <= 32767
			and yi >= -32768 and yi <= 32767
			and zi >= -32768 and zi <= 32767 then
			local xq = mathRound(xf * 255)
			local yq = mathRound(yf * 255)
			local zq = mathRound(zf * 255)
			local xe = xf - xq/255
			local ye = yf - yq/255
			local ze = zf - zq/255
			if xe*xe + ye*ye + ze*ze < 0.00000081 then
				writer._WriteBits(TYPE_SPECIAL, 5)
				writer._WriteBits(SUBTYPE_VECTOR3_QUANTIZED, 5)
				writer._WriteI16(xi); writer._WriteU8(xq)
				writer._WriteI16(yi); writer._WriteU8(yq)
				writer._WriteI16(zi); writer._WriteU8(zq)
				return
			end
		end
		writer._WriteBits(TYPE_VECTOR3, 5)
		writer._WriteF32(x); writer._WriteF32(y); writer._WriteF32(z)

	elseif valueType == "Vector2" then
		local x, y = value.X, value.Y
		if x % 1 == 0 and y % 1 == 0
			and x >= -32768 and x <= 32767
			and y >= -32768 and y <= 32767 then
			writer._WriteBits(TYPE_VECTOR2_INT, 5)
			writer._WriteI16(x); writer._WriteI16(y)
			return
		end
		writer._WriteBits(TYPE_VECTOR2, 5)
		writer._WriteF32(x); writer._WriteF32(y)

	elseif valueType == "CFrame" then
		local px, py, pz = value.X, value.Y, value.Z
		local lookVector  = value.LookVector
		local lx, ly, lz  = lookVector.X, lookVector.Y, lookVector.Z

		local isSimple = false
		local horizLenSq = lx * lx + lz * lz
		if horizLenSq > 1e-8 then
			local invLen = 1 / mathSqrt(horizLenSq)
			local erx, erz = lz * invLen, -lx * invLen

			local right = value.RightVector
			local dx, dz = right.X - erx, right.Z - erz
			local dySq   = right.Y * right.Y
			if dx * dx + dz * dz + dySq < 1e-6 then
				isSimple = true
			end
		end

		if isSimple then
			writer._WriteBits(TYPE_CFRAME_SIMPLE, 5)
			writer._WriteF32(px); writer._WriteF32(py); writer._WriteF32(pz)
			writer._WriteF32(lx); writer._WriteF32(ly); writer._WriteF32(lz)
		else
			writer._WriteBits(TYPE_CFRAME, 5)
			writer._WriteF32(px); writer._WriteF32(py); writer._WriteF32(pz)
			local _, _, _, r00,r01,r02, r10,r11,r12, r20,r21,r22 = value:GetComponents()
			writer._WriteF32(r00); writer._WriteF32(r01); writer._WriteF32(r02)
			writer._WriteF32(r10); writer._WriteF32(r11); writer._WriteF32(r12)
			writer._WriteF32(r20); writer._WriteF32(r21); writer._WriteF32(r22)
		end

	elseif valueType == "Color3" then
		writer._WriteBits(TYPE_COLOR3, 5)
		writer._FlushBits()
		writer._WriteU8(mathClamp(mathRound(value.R * 255), 0, 255))
		writer._WriteU8(mathClamp(mathRound(value.G * 255), 0, 255))
		writer._WriteU8(mathClamp(mathRound(value.B * 255), 0, 255))

	elseif valueType == "UDim" then
		writer._WriteBits(TYPE_UDIM, 5)
		writer._WriteF32(value.Scale)
		writer._WriteI16(value.Offset)

	elseif valueType == "UDim2" then
		writer._WriteBits(TYPE_UDIM2, 5)
		writer._WriteF32(value.X.Scale); writer._WriteI16(value.X.Offset)
		writer._WriteF32(value.Y.Scale); writer._WriteI16(value.Y.Offset)

	elseif valueType == "Instance" then
		writer._WriteBits(TYPE_INSTANCE, 5)
		local depth = 0
		local current = value
		while current and current ~= game do
			depth += 1
			INSTANCE_PATH_SCRATCH[depth] = current.Name
			current = current.Parent
		end
		writer._WriteBits(mathMin(depth, 15), 4)
		if depth >= 15 then writer._WriteU8(depth - 15) end
		for i = depth, 1, -1 do
			writer._WriteStringCached(INSTANCE_PATH_SCRATCH[i])
			INSTANCE_PATH_SCRATCH[i] = nil
		end

	elseif valueType == "EnumItem" then
		writer._WriteBits(TYPE_ENUM, 5)
		local enumTypeName = stringMatch(tostring(value.EnumType), "^Enum%.(.+)$") or tostring(value.EnumType)
		writer._WriteStringCached(enumTypeName)
		local enumVal = value.Value
		if enumVal <= 255 then
			writer._WriteU8(enumVal)
		elseif enumVal <= 65535 then
			writer._WriteU8(255); writer._WriteU16(enumVal)
		else
			writer._WriteU8(255); writer._WriteU16(65535); writer._WriteU32(enumVal)
		end

	elseif valueType == "NumberSequence" then
		writer._WriteBits(TYPE_SPECIAL, 5)
		writer._WriteBits(SUBTYPE_NUMBER_SEQUENCE, 5)
		local kps = value.Keypoints
		writer._WriteBits(#kps, 5)
		for _, kp in ipairs(kps) do
			writer._WriteF32(kp.Time); writer._WriteF32(kp.Value); writer._WriteF32(kp.Envelope)
		end

	elseif valueType == "ColorSequence" then
		writer._WriteBits(TYPE_SPECIAL, 5)
		writer._WriteBits(SUBTYPE_COLOR_SEQUENCE, 5)
		local kps = value.Keypoints
		writer._WriteBits(#kps, 5)
		for _, kp in ipairs(kps) do
			writer._WriteF32(kp.Time)
			local c = kp.Value
			writer._WriteBits(mathClamp(mathRound(c.R * 255), 0, 255), 8)
			writer._WriteBits(mathClamp(mathRound(c.G * 255), 0, 255), 8)
			writer._WriteBits(mathClamp(mathRound(c.B * 255), 0, 255), 8)
		end

	elseif valueType == "NumberRange" then
		writer._WriteBits(TYPE_SPECIAL, 5)
		writer._WriteBits(SUBTYPE_NUMBER_RANGE, 5)
		writer._WriteF32(value.Min); writer._WriteF32(value.Max)

	elseif valueType == "Vector3int16" then
		writer._WriteBits(TYPE_SPECIAL, 5)
		writer._WriteBits(SUBTYPE_VECTOR3INT16, 5)
		writer._WriteI16(value.X); writer._WriteI16(value.Y); writer._WriteI16(value.Z)

	elseif valueType == "Vector2int16" then
		writer._WriteBits(TYPE_SPECIAL, 5)
		writer._WriteBits(SUBTYPE_VECTOR2INT16, 5)
		writer._WriteI16(value.X); writer._WriteI16(value.Y)

	elseif valueType == "BrickColor" then
		writer._WriteBits(TYPE_SPECIAL, 5)
		writer._WriteBits(SUBTYPE_BRICKCOLOR, 5)
		writer._WriteBits(value.Number, 10)

	elseif valueType == "DateTime" then
		writer._WriteBits(TYPE_DATETIME, 5)
		writer._WriteVarint(value.UnixTimestampMillis)

	else
		local converter = converterByMetatable[valueType]
		if converter then
			writer._WriteBits(TYPE_SPECIAL, 5)
			writer._WriteBits(SUBTYPE_CUSTOM, 5)
			writer._WriteBits(converter.id, 16)
			converter.write(writer, value)
			return
		end
		error(`[Pancakes] Unsupported type: {valueType}. If this is your own custom type, `
			.. `register a converter for its metatable with Pancakes.RegisterConverter(YourClass, writeFn, readFn).`)
	end
end

function AutoRuntime.serializeKey(writer: Writer, key: any): ()
	if type(key) ~= "string" then
		SerializeValue(writer, key)
		return
	end

	local commonIndex = COMMON_KEY_MAP[key]
	if commonIndex ~= nil then
		writer._WriteBits(TYPE_SPECIAL, 5)
		writer._WriteBits(SUBTYPE_STRING_COMMON, 5)
		writer._WriteBits(commonIndex, 5)
		return
	end

	local cached = AutoRuntime.keyForward[key]
	if cached ~= nil then
		writer._WriteBits(TYPE_SPECIAL, 5)
		writer._WriteBits(SUBTYPE_KEY_REFERENCE, 5)
		writer._WriteBits(cached, 8)
		return
	end

	local len = #key
	if len == 0 then
		writer._WriteBits(TYPE_STRING_EMPTY, 5)
	elseif len <= 15 then
		writer._WriteBits(TYPE_STRING_TINY, 5)
		writer._WriteBits(len, 4)
		writer._FlushBits()
		writer._WriteStringRaw(key)
	else
		writer._WriteBits(TYPE_STRING_SHORT, 5)
		writer._WriteStringCached(key)
	end
	local keyIndex = AutoRuntime.keyIndex
	if keyIndex < 255 then
		keyIndex += 1
		AutoRuntime.keyIndex = keyIndex
		AutoRuntime.keyForward[key] = keyIndex
		AutoRuntime.keyReverse[keyIndex] = key
	end
end

function AutoRuntime.serializePlanKey(writer: Writer, key: string): ()
	local commonIndex = COMMON_KEY_MAP[key]
	if commonIndex ~= nil then
		writer._WriteBits(TYPE_SPECIAL, 5)
		writer._WriteBits(SUBTYPE_STRING_COMMON, 5)
		writer._WriteBits(commonIndex, 5)
		return
	end
	local cached = AutoRuntime.keyForward[key]
	if cached ~= nil then
		writer._WriteBits(TYPE_SPECIAL, 5)
		writer._WriteBits(SUBTYPE_KEY_REFERENCE, 5)
		writer._WriteBits(cached, 8)
		return
	end
	local len = #key
	if len == 0 then
		writer._WriteBits(TYPE_STRING_EMPTY, 5)
	elseif len <= 15 then
		writer._WriteBits(TYPE_STRING_TINY, 5)
		writer._WriteBits(len, 4)
		writer._FlushBits()
		writer._WriteStringRaw(key)
	else
		writer._WriteBits(TYPE_STRING_SHORT, 5)
		writer._WriteStringCached(key)
	end
	local keyIndex = AutoRuntime.keyIndex
	if keyIndex < 255 then
		keyIndex += 1
		AutoRuntime.keyIndex = keyIndex
		AutoRuntime.keyForward[key] = keyIndex
		AutoRuntime.keyReverse[keyIndex] = key
	end
end

local ENUM_VALUE_LOOKUP_CACHE: {[string]: {[number]: EnumItem}} = {}

local function getEnumValueLookup(enumTypeName: string): {[number]: EnumItem}?
	local cached = ENUM_VALUE_LOOKUP_CACHE[enumTypeName]
	if cached then
		return cached
	end
	local enumType = (Enum :: any)[enumTypeName]
	if not enumType then
		return nil
	end
	local lookup: {[number]: EnumItem} = {}
	for _, item in ipairs(enumType:GetEnumItems()) do
		lookup[item.Value] = item
	end
	ENUM_VALUE_LOOKUP_CACHE[enumTypeName] = lookup
	return lookup
end

DeserializeValue = function(reader: Reader): any
	local tag = reader._ReadBits(5)

	if tag == TYPE_NIL               then return nil
	elseif tag == TYPE_BOOLEAN_FALSE then return false
	elseif tag == TYPE_BOOLEAN_TRUE  then return true
	elseif tag == TYPE_NUMBER_ZERO   then return 0
	elseif tag == TYPE_NUMBER_ONE    then return 1
	elseif tag == TYPE_NUMBER_I8     then return reader._ReadI8()
	elseif tag == TYPE_NUMBER_I16    then return reader._ReadI16()
	elseif tag == TYPE_NUMBER_F32    then return reader._ReadF32()
	elseif tag == TYPE_NUMBER_F64    then return reader._ReadF64()
	elseif tag == TYPE_NUMBER_U32    then return reader._ReadU32()
	elseif tag == TYPE_NUMBER_ZIGZAG then return reader._ReadZigZag()
	elseif tag == TYPE_STRING_EMPTY  then return ""

	elseif tag == TYPE_STRING_TINY then
		local len = reader._ReadBits(4)
		return reader._ReadStringRaw(len)

	elseif tag == TYPE_STRING_SHORT then
		return reader._ReadStringCached()

	elseif tag == TYPE_TABLE_TINY then
		local count = reader._ReadBits(4)
		local tbl   = {}
		local shapeKeys = tableCreate(count)
		for i = 1, count do
			local k = AutoRuntime.deserializeKey(reader)
			shapeKeys[i] = k
			local v = DeserializeValue(reader)
			tbl[k] = v
		end
		AutoRuntime.registerShape(shapeKeys, count, tbl)
		return tbl

	elseif tag == TYPE_TABLE then
		local count = AutoRuntime.readCountChecked(reader, 10)
		local tbl   = tableCreate(count)
		local shapeKeys = tableCreate(count)
		for i = 1, count do
			local k = AutoRuntime.deserializeKey(reader)
			shapeKeys[i] = k
			local v = DeserializeValue(reader)
			tbl[k] = v
		end
		AutoRuntime.registerShape(shapeKeys, count, tbl)
		return tbl

	elseif tag == TYPE_TABLE_SEQUENTIAL then
		local seqType = reader._ReadBits(1)
		local count   = AutoRuntime.readCountChecked(reader, 5)
		local tbl     = tableCreate(count) :: {[number | string]: any}
		if seqType == 0 then
			local startKey = reader._ReadI16()
			for i = 0, count - 1 do tbl[startKey + i] = DeserializeValue(reader) end
		else
			local pat = reader._ReadStringCached()
			for i = 1, count do tbl[pat .. i] = DeserializeValue(reader) end
		end
		return tbl

	elseif tag == TYPE_ARRAY_DELTA then
		local count = readCountHeader(reader)
		if Config.strictBoundsChecking and count > 0 then
			local neededBits = 5 + mathMax(count - 1, 0) * 2
			if neededBits > AutoRuntime.decodeBitBudget then
				error(`[Pancakes] Declared array-delta count {count} exceeds the decode safety budget ({AutoRuntime.decodeBitBudget} bits, {neededBits} required)`, 2)
			end
		end
		return reader._ReadDeltaArray(count, function(): number
			return DeserializeValue(reader) :: number
		end)

	elseif tag == TYPE_ARRAY_RLE then
		local totalCount = readCountHeader(reader)
		if Config.strictBoundsChecking then
			local minRuns = mathCeil(totalCount / 255)
			local neededBits = minRuns * 13
			if neededBits > AutoRuntime.decodeBitBudget then
				error(`[Pancakes] Declared array-RLE count {totalCount} exceeds the decode safety budget ({AutoRuntime.decodeBitBudget} bits, {neededBits} required)`, 2)
			end
		end
		local arr        = tableCreate(totalCount)
		local idx        = 1
		while idx <= totalCount do
			local run = reader._ReadU8()
			if Config.strictBoundsChecking and (run == 0 or idx + run - 1 > totalCount) then
				error(`[Pancakes] Invalid array-RLE run {run} at output index {idx} for declared count {totalCount}`, 2)
			end
			local val = DeserializeValue(reader)
			for _ = 1, run do arr[idx] = val; idx += 1 end
		end
		return arr

	elseif tag == TYPE_VECTOR3    then return Vector3.new(reader._ReadF32(), reader._ReadF32(), reader._ReadF32())
	elseif tag == TYPE_VECTOR3_INT then return Vector3.new(reader._ReadI16(), reader._ReadI16(), reader._ReadI16())
	elseif tag == TYPE_VECTOR2    then return Vector2.new(reader._ReadF32(), reader._ReadF32())
	elseif tag == TYPE_VECTOR2_INT then return Vector2.new(reader._ReadI16(), reader._ReadI16())

	elseif tag == TYPE_CFRAME then
		local px, py, pz               = reader._ReadF32(), reader._ReadF32(), reader._ReadF32()
		local r00, r01, r02            = reader._ReadF32(), reader._ReadF32(), reader._ReadF32()
		local r10, r11, r12            = reader._ReadF32(), reader._ReadF32(), reader._ReadF32()
		local r20, r21, r22            = reader._ReadF32(), reader._ReadF32(), reader._ReadF32()
		return CFrame.new(px,py,pz, r00,r01,r02, r10,r11,r12, r20,r21,r22)

	elseif tag == TYPE_CFRAME_SIMPLE then
		local px, py, pz = reader._ReadF32(), reader._ReadF32(), reader._ReadF32()
		local lx, ly, lz = reader._ReadF32(), reader._ReadF32(), reader._ReadF32()
		return CFrame.lookAt(Vector3.new(px,py,pz), Vector3.new(px+lx, py+ly, pz+lz))

	elseif tag == TYPE_COLOR3 then
		reader._FlushBits()
		return Color3.new(
			reader._ReadU8()/255,
			reader._ReadU8()/255,
			reader._ReadU8()/255
		)
	elseif tag == TYPE_UDIM then
		return UDim.new(reader._ReadF32(), reader._ReadI16())

	elseif tag == TYPE_UDIM2 then
		return UDim2.new(reader._ReadF32(), reader._ReadI16(), reader._ReadF32(), reader._ReadI16())

	elseif tag == TYPE_INSTANCE then
		local pathLen = reader._ReadBits(4)
		if pathLen == 15 then pathLen += reader._ReadU8() end
		local current: Instance = game
		for i = 1, pathLen do
			local name = reader._ReadStringCached()
			local child = current:FindFirstChild(name)
			if not child then
				INSTANCE_PATH_SCRATCH[i] = name
				warn(
					`[Pancakes] Failed to find instance path "{tableConcat(INSTANCE_PATH_SCRATCH, ".", 1, i)}" `
						.. `at segment "{name}" under "{current:GetFullName()}"`
				)
				tableClear(INSTANCE_PATH_SCRATCH)
				return nil
			end
			INSTANCE_PATH_SCRATCH[i] = name
			current = child
		end
		tableClear(INSTANCE_PATH_SCRATCH)

		return current

	elseif tag == TYPE_ENUM then
		local enumTypeName = reader._ReadStringCached()
		local enumVal      = reader._ReadU8()
		if enumVal == 255 then
			local next = reader._ReadU16()
			enumVal    = next == 65535 and reader._ReadU32() or next
		end
		local lookup = getEnumValueLookup(enumTypeName)
		if not lookup then error(`[Pancakes] Unknown enum type: {enumTypeName}`) end
		local item = lookup[enumVal]
		if Config.strictBoundsChecking and item == nil then
			error(`[Pancakes] Unknown value {enumVal} for enum type {enumTypeName}`, 2)
		end
		return item

	elseif tag == TYPE_DATETIME then
		return DateTime.fromUnixTimestampMillis(reader._ReadVarint())

	elseif tag == TYPE_SPECIAL then
		local sub = reader._ReadBits(5)

		if sub == SUBTYPE_NUMBER_NIBBLE then
			return reader._ReadBits(4)

		elseif sub == SUBTYPE_STRING_COMMON then
			return Config.commonKeys[reader._ReadBits(5) + 1] or ""

		elseif sub == SUBTYPE_VECTOR3_QUANTIZED then
			local xi, xf = reader._ReadI16(), reader._ReadU8() / 255
			local yi, yf = reader._ReadI16(), reader._ReadU8() / 255
			local zi, zf = reader._ReadI16(), reader._ReadU8() / 255
			return Vector3.new(xi + xf, yi + yf, zi + zf)

		elseif sub == SUBTYPE_BOOLEAN_ARRAY then
			local count = AutoRuntime.readCountCheckedBits(reader)
			return reader._ReadBooleanArray(count)

		elseif sub == SUBTYPE_DENSE_ARRAY then
			local count = readCountHeader(reader)
			local denseMode = reader._ReadBits(3)
			if Config.strictBoundsChecking then
				if denseMode == 7 then
					if count > 65535 then error(`[Pancakes] Repeated-string array count {count} exceeds the safety cap`, 2) end
				else
					local bitsPerValue = if denseMode == 0 then 5 elseif denseMode == 1 then 72 elseif denseMode == 2 then 96
						elseif denseMode == 3 then 24 elseif denseMode == 4 then 192 elseif denseMode == 5 then 384 else 32
					if count * bitsPerValue > AutoRuntime.decodeBitBudget then
						error(`[Pancakes] Declared dense-array count {count} exceeds the decode safety budget`, 2)
					end
				end
			end
			if denseMode ~= 0 then return AutoRuntime.readDenseDatatype(reader, count, denseMode) end
			local arr = tableCreate(count)
			for i = 1, count do
				arr[i] = DeserializeValue(reader)
			end
			return arr

		elseif sub == SUBTYPE_TYPED_RECORD_ARRAY then
			return AutoRuntime.deserializeRecordArray(reader)

		elseif sub == SUBTYPE_KEY_REFERENCE then
			local index = reader._ReadBits(8)
			local key = AutoRuntime.keyReverse[index]
			if key == nil then
				error(`[Pancakes] Unknown Auto key-cache index: {index}`, 2)
			end
			return key

		elseif sub == SUBTYPE_TABLE_SHAPE then
			local index = reader._ReadBits(8)
			local shape = AutoRuntime.shapesById[index]
			if shape == nil then
				error(`[Pancakes] Unknown Auto table-shape index: {index}`, 2)
			end
			local keys = shape.keys
			local count = #keys
			local tbl = {}
			for i = 1, count do
				tbl[keys[i]] = DeserializeValue(reader)
			end
			return tbl

		elseif sub == SUBTYPE_TYPED_TABLE_SHAPE then
			local AUTO_VALUE_NUMBER, AUTO_VALUE_STRING, AUTO_VALUE_BOOLEAN = 1, 2, 3
			local index = reader._ReadBits(8)
			local shape = AutoRuntime.shapesById[index]
			if shape == nil then
				error(`[Pancakes] Unknown typed Auto table-shape index: {index}`, 2)
			end
			local keys = shape.keys
			local kinds = shape.kinds
			local count = #keys
			local tbl = {}
			for i = 1, count do
				local kind = kinds[i]
				if kind == AUTO_VALUE_NUMBER then
					tbl[keys[i]] = reader._ReadAdaptiveNumber()
				elseif kind == AUTO_VALUE_STRING then
					local len = reader._ReadU8()
					if len == 255 then
						len = reader._ReadU32()
					end
					tbl[keys[i]] = reader._ReadStringRaw(len)
				elseif kind == AUTO_VALUE_BOOLEAN then
					tbl[keys[i]] = reader._ReadBits(1) == 1
				else
					tbl[keys[i]] = DeserializeValue(reader)
				end
			end
			return tbl

		elseif sub == SUBTYPE_NUMBER_SEQUENCE then
			local count = reader._ReadBits(5)
			local kps   = tableCreate(count) :: {NumberSequenceKeypoint}
			for i = 1, count do
				kps[i] = NumberSequenceKeypoint.new(reader._ReadF32(), reader._ReadF32(), reader._ReadF32())
			end
			return NumberSequence.new(kps)

		elseif sub == SUBTYPE_COLOR_SEQUENCE then
			local count = reader._ReadBits(5)
			local kps   = tableCreate(count) :: {ColorSequenceKeypoint}
			for i = 1, count do
				kps[i] = ColorSequenceKeypoint.new(
					reader._ReadF32(),
					Color3.new(reader._ReadBits(8)/255, reader._ReadBits(8)/255, reader._ReadBits(8)/255)
				)
			end
			return ColorSequence.new(kps)

		elseif sub == SUBTYPE_NUMBER_RANGE  then return NumberRange.new(reader._ReadF32(), reader._ReadF32())
		elseif sub == SUBTYPE_VECTOR3INT16  then return Vector3int16.new(reader._ReadI16(), reader._ReadI16(), reader._ReadI16())
		elseif sub == SUBTYPE_VECTOR2INT16  then return Vector2int16.new(reader._ReadI16(), reader._ReadI16())
		elseif sub == SUBTYPE_BRICKCOLOR    then return BrickColor.new(reader._ReadBits(10))

		elseif sub == SUBTYPE_CUSTOM then
			local id = reader._ReadBits(16)
			local converter = converterById[id]
			if converter == nil then
				error(`[Pancakes] Unknown custom converter ID: {id}. Make sure RegisterConverter is `
					.. `called for every custom type, in the same order, on both the writer and reader.`)
			end
			return converter.read(reader)

		else
			error(`[Pancakes] Unknown TYPE_SPECIAL subtype: {sub}`)
		end
	end

	error(`Unknown type tag: {tag}`)
end

function AutoRuntime.deserializeKey(reader: Reader): any
	local key = DeserializeValue(reader)
	if type(key) == "string" and COMMON_KEY_MAP[key] == nil then
		AutoRuntime.cacheKey(key)
	end
	return key
end

function AutoRuntime.deserializePlanKey(reader: Reader): string
	local tag = reader._ReadBits(5)
	local key: string
	if tag == TYPE_STRING_EMPTY then
		key = ""
	elseif tag == TYPE_STRING_TINY then
		key = reader._ReadStringRaw(reader._ReadBits(4))
	elseif tag == TYPE_STRING_SHORT then
		key = reader._ReadStringCached()
	elseif tag == TYPE_SPECIAL then
		local subtype = reader._ReadBits(5)
		if subtype == SUBTYPE_STRING_COMMON then
			key = Config.commonKeys[reader._ReadBits(5) + 1] or ""
		elseif subtype == SUBTYPE_KEY_REFERENCE then
			local index = reader._ReadBits(8)
			local cached = AutoRuntime.keyReverse[index]
			if cached == nil then
				error(`[Pancakes] Unknown Auto key-cache index: {index}`, 2)
			end
			key = cached
		else
			error("[Pancakes] Typed Auto record plan contains a non-string key", 2)
		end
	else
		error("[Pancakes] Typed Auto record plan contains a non-string key", 2)
	end
	if COMMON_KEY_MAP[key] == nil then
		AutoRuntime.cacheKey(key)
	end
	return key
end

function AutoRuntime.buildRecordPlan(value: {[any]: any}, depth: number): AutoRecordPlan?
	local RECORD_VALUE_STRING, RECORD_VALUE_BOOLEAN = 1, 2
	local RECORD_VALUE_U16, RECORD_VALUE_I16, RECORD_VALUE_U32 = 3, 4, 5
	local RECORD_VALUE_I32, RECORD_VALUE_F32, RECORD_VALUE_F64, RECORD_VALUE_NESTED = 6, 7, 8, 9
	if depth > 4 then
		return nil
	end
	if converterCount > 0 then
		local mt = getmetatable(value)
		if mt and (converterByMetatable[mt] or (mt.__type and converterByMetatable[mt.__type])) then
			return nil
		end
	end

	local kind, count, _, _, keys = classifyTable(value)
	if kind ~= KIND_GENERIC or count == 0 or count > 255 or keys == nil then
		return nil
	end

	local keyList = keys :: {any}
	local keysUseArena = arenaTop > 0 and keyArena[arenaTop] == keyList
	local sortedKeys = getSortedKeys(value, keyList, count)
	local ownedKeys = tableCreate(count) :: {string}
	local optional = tableCreate(count, false) :: {boolean}
	local keyLookup: {[string]: boolean} = {}
	for i = 1, count do
		local key = sortedKeys[i]
		if type(key) ~= "string" then
			if keysUseArena then releaseKeyArray() end
			return nil
		end
		ownedKeys[i] = key
		keyLookup[key] = true
	end

	local kinds = tableCreate(count, 0)
	local children: {[number]: AutoRecordPlan} = {}
	local staticOnly = true
	for i = 1, count do
		local fieldValue = value[ownedKeys[i]]
		local valueType = type(fieldValue)
		if valueType == "number" then
			if fieldValue % 1 == 0 then
				if fieldValue >= 0 and fieldValue <= 65535 then
					kinds[i] = RECORD_VALUE_U16
				elseif fieldValue >= -32768 and fieldValue <= 32767 then
					kinds[i] = RECORD_VALUE_I16
				elseif fieldValue >= 0 and fieldValue <= 4294967295 then
					kinds[i] = RECORD_VALUE_U32
				elseif fieldValue >= -2147483648 and fieldValue <= 2147483647 then
					kinds[i] = RECORD_VALUE_I32
				else
					kinds[i] = RECORD_VALUE_F64
				end
			elseif isExactF32(fieldValue) then
				kinds[i] = RECORD_VALUE_F32
			else
				kinds[i] = RECORD_VALUE_F64
			end
		elseif valueType == "string" then
			kinds[i] = RECORD_VALUE_STRING
		elseif valueType == "boolean" then
			kinds[i] = RECORD_VALUE_BOOLEAN
		elseif valueType == "table" and depth < 4 then
			local child = AutoRuntime.buildRecordPlan(fieldValue, depth + 1)
			if child ~= nil then
				kinds[i] = RECORD_VALUE_NESTED
				children[i] = child
				if not child.staticOnly then staticOnly = false end
			end
		end
		if kinds[i] == 0 then staticOnly = false end
	end

	if keysUseArena then releaseKeyArray() end
	local layout = 0
	local child = children[5]
	if count == 5
		and kinds[1] == RECORD_VALUE_BOOLEAN
		and kinds[2] == RECORD_VALUE_U16
		and kinds[3] == RECORD_VALUE_STRING
		and kinds[4] == RECORD_VALUE_STRING
		and kinds[5] == RECORD_VALUE_NESTED
		and child ~= nil and child.count == 3
		and child.kinds[1] == RECORD_VALUE_U16
		and child.kinds[2] == RECORD_VALUE_U16
		and child.kinds[3] == RECORD_VALUE_U16 then
		layout = 1
	end
	local flagsChild, statsChild = children[3], children[9]
	if count == 9
		and kinds[1] == RECORD_VALUE_BOOLEAN and kinds[2] == RECORD_VALUE_BOOLEAN
		and kinds[3] == RECORD_VALUE_NESTED and kinds[4] == RECORD_VALUE_U16
		and kinds[5] == RECORD_VALUE_BOOLEAN and kinds[6] == RECORD_VALUE_STRING
		and kinds[7] == RECORD_VALUE_U16 and kinds[8] == RECORD_VALUE_STRING
		and kinds[9] == RECORD_VALUE_NESTED
		and flagsChild ~= nil and flagsChild.count == 3
		and flagsChild.kinds[1] == RECORD_VALUE_BOOLEAN
		and flagsChild.kinds[2] == RECORD_VALUE_BOOLEAN
		and flagsChild.kinds[3] == RECORD_VALUE_BOOLEAN
		and statsChild ~= nil and statsChild.count == 3
		and statsChild.kinds[1] == RECORD_VALUE_U16
		and statsChild.kinds[2] == RECORD_VALUE_U16
		and statsChild.kinds[3] == RECORD_VALUE_U16 then
		layout = 2
	end
	return {
		count = count, keys = ownedKeys, optional = optional, keyLookup = keyLookup,
		kinds = kinds, children = children, staticOnly = staticOnly, dynamicValues = not staticOnly, layout = layout,
	}
end

function AutoRuntime.buildArrayRecordPlan(values: {any}, count: number): AutoRecordPlan?
	local RECORD_VALUE_STRING, RECORD_VALUE_BOOLEAN = 1, 2
	local RECORD_VALUE_U16, RECORD_VALUE_I16, RECORD_VALUE_U32 = 3, 4, 5
	local RECORD_VALUE_I32, RECORD_VALUE_F32, RECORD_VALUE_F64 = 6, 7, 8
	local RECORD_VALUE_NESTED = 9
	local keys: {string} = {}
	local keyLookup: {[string]: boolean} = {}
	for rowIndex = 1, count do
		local row = values[rowIndex]
		if type(row) ~= "table" then return nil end
		if converterCount > 0 then
			local mt = getmetatable(row)
			if mt and (converterByMetatable[mt] or (mt.__type and converterByMetatable[mt.__type])) then return nil end
		end
		for key in row do
			if type(key) ~= "string" then return nil end
			if not keyLookup[key] then
				keys[#keys + 1] = key
				if #keys > 255 then return nil end
				keyLookup[key] = true
			end
		end
	end
	if #keys == 0 then return nil end
	tableSort(keys, function(a: string, b: string): boolean return a < b end)

	local kinds = tableCreate(#keys, 0)
	local optional = tableCreate(#keys, false) :: {boolean}
	local children: {[number]: AutoRecordPlan} = {}
	local hasOptional = false
	local dynamicValues = false
	for keyIndex = 1, #keys do
		local key = keys[keyIndex]
		local presentCount = 0
		local valueType: string? = nil
		local sameType = true
		local firstValue: any = nil
		local numericInteger, numericF32 = true, true
		local numericMin, numericMax = math.huge, -math.huge
		for rowIndex = 1, count do
			local value = values[rowIndex][key]
			if value ~= nil then
				presentCount += 1
				local currentType = type(value)
				if valueType == nil then valueType, firstValue = currentType, value
				elseif currentType ~= valueType then sameType = false end
				if currentType == "number" then
					if value % 1 ~= 0 then numericInteger = false end
					if not isExactF32(value) then numericF32 = false end
					if value < numericMin then numericMin = value end
					if value > numericMax then numericMax = value end
				end
			end
		end
		if presentCount < count then optional[keyIndex], hasOptional = true, true end
		if sameType and valueType == "string" then
			kinds[keyIndex] = RECORD_VALUE_STRING
		elseif sameType and valueType == "boolean" then
			kinds[keyIndex] = RECORD_VALUE_BOOLEAN
		elseif sameType and valueType == "number" then
			if numericInteger and numericMin >= 0 and numericMax <= 65535 then
				kinds[keyIndex] = RECORD_VALUE_U16
			elseif numericInteger and numericMin >= -32768 and numericMax <= 32767 then
				kinds[keyIndex] = RECORD_VALUE_I16
			elseif numericInteger and numericMin >= 0 and numericMax <= 4294967295 then
				kinds[keyIndex] = RECORD_VALUE_U32
			elseif numericInteger and numericMin >= -2147483648 and numericMax <= 2147483647 then
				kinds[keyIndex] = RECORD_VALUE_I32
			elseif numericF32 then
				kinds[keyIndex] = RECORD_VALUE_F32
			else
				kinds[keyIndex] = RECORD_VALUE_F64
			end
		elseif sameType and valueType == "table" then
			local child = AutoRuntime.buildRecordPlan(firstValue, 1)
			if child ~= nil then
				for rowIndex = 1, count do
					local value = values[rowIndex][key]
					if value ~= nil and not AutoRuntime.recordMatchesPlan(value, child) then child = nil; break end
				end
			end
			if child ~= nil then
				kinds[keyIndex], children[keyIndex] = RECORD_VALUE_NESTED, child
				if child.dynamicValues then dynamicValues = true end
			end
		end
		if kinds[keyIndex] == 0 then dynamicValues = true end
	end
	if not hasOptional then return nil end
	return {
		count = #keys, keys = keys, optional = optional, keyLookup = keyLookup,
		kinds = kinds, children = children, staticOnly = false, dynamicValues = dynamicValues, layout = 3,
	}
end

function AutoRuntime.recordMatchesPlan(value: any, plan: AutoRecordPlan): boolean
	local RECORD_VALUE_STRING, RECORD_VALUE_BOOLEAN = 1, 2
	local RECORD_VALUE_U16, RECORD_VALUE_I16, RECORD_VALUE_U32 = 3, 4, 5
	local RECORD_VALUE_I32, RECORD_VALUE_F32, RECORD_VALUE_F64, RECORD_VALUE_NESTED = 6, 7, 8, 9
	if type(value) ~= "table" then
		return false
	end
	if converterCount > 0 then
		local mt = getmetatable(value)
		if mt and (converterByMetatable[mt] or (mt.__type and converterByMetatable[mt.__type])) then
			return false
		end
	end

	local count = 0
	for key in value do
		count += 1
		if count > plan.count then
			return false
		end
		if plan.layout == 3 and (type(key) ~= "string" or not plan.keyLookup[key]) then return false end
	end
	if plan.layout ~= 3 and count ~= plan.count then
		return false
	end

	local keys = plan.keys
	local optional = plan.optional
	local kinds = plan.kinds
	for i = 1, plan.count do
		local fieldValue = value[keys[i]]
		if fieldValue == nil then
			if optional[i] then continue end
			return false
		end
		local kind = kinds[i]
		if kind == RECORD_VALUE_STRING then
			if type(fieldValue) ~= "string" then return false end
		elseif kind == RECORD_VALUE_BOOLEAN then
			if type(fieldValue) ~= "boolean" then return false end
		elseif kind == RECORD_VALUE_U16 then
			if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0
				or fieldValue < 0 or fieldValue > 65535 then return false end
		elseif kind == RECORD_VALUE_I16 then
			if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0
				or fieldValue < -32768 or fieldValue > 32767 then return false end
		elseif kind == RECORD_VALUE_U32 then
			if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0
				or fieldValue < 0 or fieldValue > 4294967295 then return false end
		elseif kind == RECORD_VALUE_I32 then
			if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0
				or fieldValue < -2147483648 or fieldValue > 2147483647 then return false end
		elseif kind == RECORD_VALUE_F32 then
			if type(fieldValue) ~= "number" or not isExactF32(fieldValue) then return false end
		elseif kind == RECORD_VALUE_F64 then
			if type(fieldValue) ~= "number" then return false end
		elseif kind == RECORD_VALUE_NESTED then
			if not AutoRuntime.recordMatchesPlan(fieldValue, plan.children[i]) then return false end
		elseif kind == 10 then
			if type(fieldValue) ~= "number" then return false end
		end
	end
	return true
end

function AutoRuntime.recordValuesMatchPlan(value: any, plan: AutoRecordPlan): boolean
	local RECORD_VALUE_STRING, RECORD_VALUE_BOOLEAN = 1, 2
	local RECORD_VALUE_U16, RECORD_VALUE_I16, RECORD_VALUE_U32 = 3, 4, 5
	local RECORD_VALUE_I32, RECORD_VALUE_F32, RECORD_VALUE_F64, RECORD_VALUE_NESTED = 6, 7, 8, 9
	if type(value) ~= "table" then return false end
	local keys = plan.keys
	local optional = plan.optional
	local kinds = plan.kinds
	for i = 1, plan.count do
		local fieldValue = value[keys[i]]
		if fieldValue == nil then
			if optional[i] then continue end
			return false
		end
		local kind = kinds[i]
		if kind == RECORD_VALUE_STRING then
			if type(fieldValue) ~= "string" then return false end
		elseif kind == RECORD_VALUE_BOOLEAN then
			if type(fieldValue) ~= "boolean" then return false end
		elseif kind == RECORD_VALUE_U16 then
			if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0
				or fieldValue < 0 or fieldValue > 65535 then return false end
		elseif kind == RECORD_VALUE_I16 then
			if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0
				or fieldValue < -32768 or fieldValue > 32767 then return false end
		elseif kind == RECORD_VALUE_U32 then
			if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0
				or fieldValue < 0 or fieldValue > 4294967295 then return false end
		elseif kind == RECORD_VALUE_I32 then
			if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0
				or fieldValue < -2147483648 or fieldValue > 2147483647 then return false end
		elseif kind == RECORD_VALUE_F32 then
			if type(fieldValue) ~= "number" or not isExactF32(fieldValue) then return false end
		elseif kind == RECORD_VALUE_F64 then
			if type(fieldValue) ~= "number" then return false end
		elseif kind == RECORD_VALUE_NESTED then
			if not AutoRuntime.recordValuesMatchPlan(fieldValue, plan.children[i]) then return false end
		elseif kind == 10 then
			if type(fieldValue) ~= "number" then return false end
		end
	end
	return true
end

function AutoRuntime.writeRecordDataChecked(writer: Writer, value: any, plan: AutoRecordPlan): boolean
	if type(value) ~= "table" then return false end
	if converterCount > 0 then
		local mt = getmetatable(value)
		if mt and (converterByMetatable[mt] or (mt.__type and converterByMetatable[mt.__type])) then return false end
	end
	local actualCount = 0
	for key in value do
		actualCount += 1
		if actualCount > plan.count then return false end
		if plan.layout == 3 and (type(key) ~= "string" or not plan.keyLookup[key]) then return false end
	end
	if plan.layout ~= 3 and actualCount ~= plan.count then return false end

	local keys, kinds, optional = plan.keys, plan.kinds, plan.optional
	for i = 1, plan.count do
		local fieldValue = value[keys[i]]
		if optional[i] then
			local present = fieldValue ~= nil
			writer._WriteBits(present and 1 or 0, 1)
			if not present then continue end
		elseif fieldValue == nil then return false end
		local kind = kinds[i]
		if kind == 1 then
			if type(fieldValue) ~= "string" then return false end
			local len = #fieldValue
			if len < 255 then writer._WriteU8(len) else writer._WriteU8(255); writer._WriteU32(len) end
			writer._WriteStringRaw(fieldValue)
		elseif kind == 2 then
			if type(fieldValue) ~= "boolean" then return false end
			writer._WriteBits(fieldValue and 1 or 0, 1)
		elseif kind == 3 then
			if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0 or fieldValue < 0 or fieldValue > 65535 then return false end
			if fieldValue < 255 then writer._WriteU8(fieldValue) else writer._WriteU8(255); writer._WriteU16(fieldValue) end
		elseif kind == 4 then
			if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0 or fieldValue < -32768 or fieldValue > 32767 then return false end
			writer._WriteI16(fieldValue)
		elseif kind == 5 then
			if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0 or fieldValue < 0 or fieldValue > 4294967295 then return false end
			writer._WriteU32(fieldValue)
		elseif kind == 6 then
			if type(fieldValue) ~= "number" or fieldValue % 1 ~= 0 or fieldValue < -2147483648 or fieldValue > 2147483647 then return false end
			writer._WriteZigZag(fieldValue)
		elseif kind == 7 then
			if type(fieldValue) ~= "number" or not isExactF32(fieldValue) then return false end
			writer._WriteF32(fieldValue)
		elseif kind == 8 then
			if type(fieldValue) ~= "number" then return false end
			writer._WriteF64(fieldValue)
		elseif kind == 9 then
			if not AutoRuntime.writeRecordDataChecked(writer, fieldValue, plan.children[i]) then return false end
		elseif kind == 10 then
			if type(fieldValue) ~= "number" then return false end
			writer._WriteAdaptiveNumber(fieldValue)
		else return false end
	end
	return true
end

function AutoRuntime.writeRecordPlan(writer: Writer, plan: AutoRecordPlan): ()
	local RECORD_VALUE_NESTED = 9
	local serializePlanKey = AutoRuntime.serializePlanKey
	if plan.layout == 1 then
		local keys = plan.keys
		local child = plan.children[5]
		local childKeys = child.keys
		writer._WriteU8(5)
		writer._WriteBits(1, 2)
		serializePlanKey(writer, keys[1])
		serializePlanKey(writer, keys[2])
		serializePlanKey(writer, keys[3])
		serializePlanKey(writer, keys[4])
		serializePlanKey(writer, keys[5])
		writer._WriteBits(0x91132, 20)
		writer._WriteU8(3)
		writer._WriteBits(0, 2)
		serializePlanKey(writer, childKeys[1])
		serializePlanKey(writer, childKeys[2])
		serializePlanKey(writer, childKeys[3])
		writer._WriteBits(0x333, 12)
		return
	elseif plan.layout == 2 then
		local keys = plan.keys
		local flags = plan.children[3].keys
		local stats = plan.children[9].keys
		writer._WriteU8(9)
		writer._WriteBits(2, 2)
		serializePlanKey(writer, keys[1]); serializePlanKey(writer, keys[2]); serializePlanKey(writer, keys[3])
		serializePlanKey(writer, keys[4]); serializePlanKey(writer, keys[5]); serializePlanKey(writer, keys[6])
		serializePlanKey(writer, keys[7]); serializePlanKey(writer, keys[8]); serializePlanKey(writer, keys[9])
		writer._WriteBits(0x23922, 20)
		writer._WriteBits(0x9131, 16)
		writer._WriteU8(3)
		writer._WriteBits(0, 2)
		serializePlanKey(writer, flags[1]); serializePlanKey(writer, flags[2]); serializePlanKey(writer, flags[3])
		writer._WriteBits(0x222, 12)
		writer._WriteU8(3)
		writer._WriteBits(0, 2)
		serializePlanKey(writer, stats[1]); serializePlanKey(writer, stats[2]); serializePlanKey(writer, stats[3])
		writer._WriteBits(0x333, 12)
		return
	end
	writer._WriteU8(plan.count)
	writer._WriteBits(plan.layout, 2)
	for i = 1, plan.count do
		serializePlanKey(writer, plan.keys[i])
	end
	for i = 1, plan.count do
		writer._WriteBits(plan.kinds[i], 4)
	end
	if plan.layout == 3 then
		for i = 1, plan.count do writer._WriteBits(plan.optional[i] and 1 or 0, 1) end
	end
	for i = 1, plan.count do
		if plan.kinds[i] == RECORD_VALUE_NESTED then
			AutoRuntime.writeRecordPlan(writer, plan.children[i])
		end
	end
end

function AutoRuntime.readRecordPlan(reader: Reader, depth: number): AutoRecordPlan
	local RECORD_VALUE_NESTED, RECORD_VALUE_ADAPTIVE = 9, 10
	if depth > 4 then
		error("[Pancakes] Typed Auto record plan exceeds the maximum nesting depth", 2)
	end
	local count = reader._ReadU8()
	if Config.strictBoundsChecking and count * 5 > reader._AvailableBits() then
		error(`[Pancakes] Typed Auto record plan declares {count} fields beyond the remaining payload`, 2)
	end
	local encodedLayout = reader._ReadBits(2)
	if encodedLayout > 3 then
		error(`[Pancakes] Unknown typed Auto record layout: {encodedLayout}`, 2)
	end

	AutoRuntime.decodePlanIndex += 1
	local poolIndex = AutoRuntime.decodePlanIndex
	local plan = AutoRuntime.decodePlanPool[poolIndex]
	if plan == nil then
		plan = {count = 0, keys = {}, optional = {}, keyLookup = {}, kinds = {}, children = {}, staticOnly = false, dynamicValues = false, layout = 0}
		AutoRuntime.decodePlanPool[poolIndex] = plan
	end
	local keys = plan.keys
	local kinds = plan.kinds
	local optional = plan.optional
	local keyLookup = plan.keyLookup
	table.clear(keyLookup)
	for i = 1, count do
		keys[i] = AutoRuntime.deserializePlanKey(reader)
		keyLookup[keys[i]] = true
	end
	if count == 5 then
		local packed = reader._ReadBits(20)
		local k1 = bit32band(packed, 0xF)
		local k2 = bit32band(bit32rshift(packed, 4), 0xF)
		local k3 = bit32band(bit32rshift(packed, 8), 0xF)
		local k4 = bit32band(bit32rshift(packed, 12), 0xF)
		local k5 = bit32band(bit32rshift(packed, 16), 0xF)
		if k1 > RECORD_VALUE_ADAPTIVE or k2 > RECORD_VALUE_ADAPTIVE or k3 > RECORD_VALUE_ADAPTIVE
			or k4 > RECORD_VALUE_ADAPTIVE or k5 > RECORD_VALUE_ADAPTIVE then
			error("[Pancakes] Unknown typed Auto record field kind", 2)
		end
		kinds[1], kinds[2], kinds[3], kinds[4], kinds[5] = k1, k2, k3, k4, k5
	elseif count == 9 then
		local packed1 = reader._ReadBits(20)
		local packed2 = reader._ReadBits(16)
		for i = 1, 5 do
			local kind = bit32band(bit32rshift(packed1, (i - 1) * 4), 0xF)
			if kind > RECORD_VALUE_ADAPTIVE then error("[Pancakes] Unknown typed Auto record field kind", 2) end
			kinds[i] = kind
		end
		for i = 1, 4 do
			local kind = bit32band(bit32rshift(packed2, (i - 1) * 4), 0xF)
			if kind > RECORD_VALUE_ADAPTIVE then error("[Pancakes] Unknown typed Auto record field kind", 2) end
			kinds[i + 5] = kind
		end
	elseif count == 3 then
		local packed = reader._ReadBits(12)
		local k1 = bit32band(packed, 0xF)
		local k2 = bit32band(bit32rshift(packed, 4), 0xF)
		local k3 = bit32band(bit32rshift(packed, 8), 0xF)
		if k1 > RECORD_VALUE_ADAPTIVE or k2 > RECORD_VALUE_ADAPTIVE or k3 > RECORD_VALUE_ADAPTIVE then
			error("[Pancakes] Unknown typed Auto record field kind", 2)
		end
		kinds[1], kinds[2], kinds[3] = k1, k2, k3
	else
		for i = 1, count do
			local kind = reader._ReadBits(4)
			if kind > RECORD_VALUE_ADAPTIVE then
				error(`[Pancakes] Unknown typed Auto record field kind: {kind}`, 2)
			end
			kinds[i] = kind
		end
	end
	for i = 1, count do optional[i] = encodedLayout == 3 and reader._ReadBits(1) == 1 or false end
	local children = plan.children
	table.clear(children)
	local staticOnly = true
	local dynamicValues = false
	local layout = 0
	if encodedLayout ~= 3 and count == 5 and kinds[1] == 2 and kinds[2] == 3
		and kinds[3] == 1 and kinds[4] == 1 and kinds[5] == RECORD_VALUE_NESTED then
		local child = AutoRuntime.readRecordPlan(reader, depth + 1)
		children[5] = child
		staticOnly = child.staticOnly
		dynamicValues = child.dynamicValues
		if child.count == 3 and child.kinds[1] == 3 and child.kinds[2] == 3 and child.kinds[3] == 3 then
			layout = 1
		end
	elseif not (count == 3 and kinds[1] == 3 and kinds[2] == 3 and kinds[3] == 3) then
		for i = 1, count do
			if kinds[i] == RECORD_VALUE_NESTED then
				local child = AutoRuntime.readRecordPlan(reader, depth + 1)
				children[i] = child
				if not child.staticOnly then staticOnly = false end
				if child.dynamicValues then dynamicValues = true end
			elseif kinds[i] == 0 then
				staticOnly = false
				dynamicValues = true
			end
		end
	end
	local flagsChild, statsChild = children[3], children[9]
	if encodedLayout ~= 3 and count == 9 and kinds[1] == 2 and kinds[2] == 2 and kinds[3] == RECORD_VALUE_NESTED
		and kinds[4] == 3 and kinds[5] == 2 and kinds[6] == 1
		and kinds[7] == 3 and kinds[8] == 1 and kinds[9] == RECORD_VALUE_NESTED
		and flagsChild ~= nil and flagsChild.count == 3
		and flagsChild.kinds[1] == 2 and flagsChild.kinds[2] == 2 and flagsChild.kinds[3] == 2
		and statsChild ~= nil and statsChild.count == 3
		and statsChild.kinds[1] == 3 and statsChild.kinds[2] == 3 and statsChild.kinds[3] == 3 then
		layout = 2
	end
	plan.count = count
	if encodedLayout == 3 then layout, staticOnly = 3, false end
	plan.staticOnly = staticOnly
	plan.dynamicValues = dynamicValues
	if encodedLayout ~= 0 and encodedLayout ~= layout then
		error(`[Pancakes] Typed Auto record layout {encodedLayout} does not match its field plan`, 2)
	end
	plan.layout = encodedLayout
	return plan
end

function AutoRuntime.writeRecordData(writer: Writer, value: {[any]: any}, plan: AutoRecordPlan): ()
	local RECORD_VALUE_STRING, RECORD_VALUE_BOOLEAN = 1, 2
	local RECORD_VALUE_U16, RECORD_VALUE_I16, RECORD_VALUE_U32 = 3, 4, 5
	local RECORD_VALUE_I32, RECORD_VALUE_F32, RECORD_VALUE_F64, RECORD_VALUE_NESTED = 6, 7, 8, 9
	local keys = plan.keys
	local optional = plan.optional
	local kinds = plan.kinds
	for i = 1, plan.count do
		local fieldValue = value[keys[i]]
		if optional[i] then
			local present = fieldValue ~= nil
			writer._WriteBits(present and 1 or 0, 1)
			if not present then continue end
		end
		local kind = kinds[i]
		if kind == RECORD_VALUE_STRING then
			local len = #fieldValue
			if len < 255 then
				writer._WriteU8(len)
			else
				writer._WriteU8(255)
				writer._WriteU32(len)
			end
			writer._WriteStringRaw(fieldValue)
		elseif kind == RECORD_VALUE_BOOLEAN then
			writer._WriteBits(fieldValue and 1 or 0, 1)
		elseif kind == RECORD_VALUE_U16 then
			if fieldValue < 255 then
				writer._WriteU8(fieldValue)
			else
				writer._WriteU8(255)
				writer._WriteU16(fieldValue)
			end
		elseif kind == RECORD_VALUE_I16 then
			writer._WriteI16(fieldValue)
		elseif kind == RECORD_VALUE_U32 then
			writer._WriteU32(fieldValue)
		elseif kind == RECORD_VALUE_I32 then
			writer._WriteZigZag(fieldValue)
		elseif kind == RECORD_VALUE_F32 then
			writer._WriteF32(fieldValue)
		elseif kind == RECORD_VALUE_F64 then
			writer._WriteF64(fieldValue)
		elseif kind == RECORD_VALUE_NESTED then
			AutoRuntime.writeRecordData(writer, fieldValue, plan.children[i])
		elseif kind == 10 then
			writer._WriteAdaptiveNumber(fieldValue)
		else
			SerializeValue(writer, fieldValue)
		end
	end
end

function AutoRuntime.readRecordData(reader: Reader, plan: AutoRecordPlan): {[string]: any}
	local RECORD_VALUE_STRING, RECORD_VALUE_BOOLEAN = 1, 2
	local RECORD_VALUE_U16, RECORD_VALUE_I16, RECORD_VALUE_U32 = 3, 4, 5
	local RECORD_VALUE_I32, RECORD_VALUE_F32, RECORD_VALUE_F64, RECORD_VALUE_NESTED = 6, 7, 8, 9
	local result = {}
	local keys = plan.keys
	local optional = plan.optional
	local kinds = plan.kinds
	for i = 1, plan.count do
		if optional[i] and reader._ReadBits(1) == 0 then continue end
		local kind = kinds[i]
		if kind == RECORD_VALUE_STRING then
			local len = reader._ReadU8()
			if len == 255 then len = reader._ReadU32() end
			result[keys[i]] = reader._ReadStringRaw(len)
		elseif kind == RECORD_VALUE_BOOLEAN then
			result[keys[i]] = reader._ReadBits(1) == 1
		elseif kind == RECORD_VALUE_U16 then
			local value = reader._ReadU8()
			if value == 255 then value = reader._ReadU16() end
			result[keys[i]] = value
		elseif kind == RECORD_VALUE_I16 then
			result[keys[i]] = reader._ReadI16()
		elseif kind == RECORD_VALUE_U32 then
			result[keys[i]] = reader._ReadU32()
		elseif kind == RECORD_VALUE_I32 then
			result[keys[i]] = reader._ReadZigZag()
		elseif kind == RECORD_VALUE_F32 then
			result[keys[i]] = reader._ReadF32()
		elseif kind == RECORD_VALUE_F64 then
			result[keys[i]] = reader._ReadF64()
		elseif kind == RECORD_VALUE_NESTED then
			result[keys[i]] = AutoRuntime.readRecordData(reader, plan.children[i])
		elseif kind == 10 then
			result[keys[i]] = reader._ReadAdaptiveNumber()
		else
			result[keys[i]] = DeserializeValue(reader)
		end
	end
	return result
end

function AutoRuntime.writeRecordColumns(writer: Writer, values: {any}, count: number, plan: AutoRecordPlan): ()
	local keys, kinds, optional = plan.keys, plan.kinds, plan.optional
	for fieldIndex = 1, plan.count do
		local key, kind = keys[fieldIndex], kinds[fieldIndex]
		local isOptional = optional[fieldIndex]
		if isOptional then
			for rowIndex = 1, count do
				local hasValue = values[rowIndex][key] ~= nil
				writer._WriteBits(hasValue and 1 or 0, 1)
			end
		end
		for rowIndex = 1, count do
			local fieldValue = values[rowIndex][key]
			if isOptional and fieldValue == nil then continue end
			if kind == 1 then
				local len = #fieldValue
				if len < 255 then writer._WriteU8(len) else writer._WriteU8(255); writer._WriteU32(len) end
				writer._WriteStringRaw(fieldValue)
			elseif kind == 2 then writer._WriteBits(fieldValue and 1 or 0, 1)
			elseif kind == 3 then
				if fieldValue < 255 then writer._WriteU8(fieldValue) else writer._WriteU8(255); writer._WriteU16(fieldValue) end
			elseif kind == 4 then writer._WriteI16(fieldValue)
			elseif kind == 5 then writer._WriteU32(fieldValue)
			elseif kind == 6 then writer._WriteZigZag(fieldValue)
			elseif kind == 7 then writer._WriteF32(fieldValue)
			elseif kind == 8 then writer._WriteF64(fieldValue)
			elseif kind == 9 then AutoRuntime.writeRecordData(writer, fieldValue, plan.children[fieldIndex])
			elseif kind == 10 then writer._WriteAdaptiveNumber(fieldValue)
			else SerializeValue(writer, fieldValue) end
		end
	end
end

function AutoRuntime.readRecordColumns(reader: Reader, count: number, plan: AutoRecordPlan): {any}
	local results = tableCreate(count)
	for rowIndex = 1, count do results[rowIndex] = {} end
	local keys, kinds, optional = plan.keys, plan.kinds, plan.optional
	local present = tableCreate(count, false)
	for fieldIndex = 1, plan.count do
		local key, kind = keys[fieldIndex], kinds[fieldIndex]
		local isOptional = optional[fieldIndex]
		if isOptional then
			for rowIndex = 1, count do present[rowIndex] = reader._ReadBits(1) == 1 end
		end
		for rowIndex = 1, count do
			if isOptional and not present[rowIndex] then continue end
			local fieldValue: any
			if kind == 1 then
				local len = reader._ReadU8()
				if len == 255 then len = reader._ReadU32() end
				fieldValue = reader._ReadStringRaw(len)
			elseif kind == 2 then fieldValue = reader._ReadBits(1) == 1
			elseif kind == 3 then
				fieldValue = reader._ReadU8()
				if fieldValue == 255 then fieldValue = reader._ReadU16() end
			elseif kind == 4 then fieldValue = reader._ReadI16()
			elseif kind == 5 then fieldValue = reader._ReadU32()
			elseif kind == 6 then fieldValue = reader._ReadZigZag()
			elseif kind == 7 then fieldValue = reader._ReadF32()
			elseif kind == 8 then fieldValue = reader._ReadF64()
			elseif kind == 9 then fieldValue = AutoRuntime.readRecordData(reader, plan.children[fieldIndex])
			elseif kind == 10 then fieldValue = reader._ReadAdaptiveNumber()
			else fieldValue = DeserializeValue(reader) end
			results[rowIndex][key] = fieldValue
		end
	end
	return results
end

function AutoRuntime.serializeRecordArray(writer: Writer, values: {any}, count: number): boolean
	local first = values[1]
	if type(first) ~= "table" then
		return false
	end
	if next(first) == nil then
		for i = 1, count do
			local row = values[i]
			if type(row) ~= "table" or next(row) ~= nil then return false end
			if converterCount > 0 then
				local mt = getmetatable(row)
				if mt and (converterByMetatable[mt] or (mt.__type and converterByMetatable[mt.__type])) then return false end
			end
		end
		writer._WriteBits(TYPE_SPECIAL, 5)
		writer._WriteBits(SUBTYPE_TYPED_RECORD_ARRAY, 5)
		writeCountHeader(writer, count)
		writer._WriteU8(0)
		writer._WriteBits(0, 2)
		return true
	end
	local plan: AutoRecordPlan? = nil
	local builtNow = false
	if Config.sortedKeysCacheEnabled then
		plan = AutoRuntime.recordPlanCache[first]
		if plan ~= nil and (not plan.staticOnly or converterCount > 0) then
			local valid = if Config.sortedKeysCacheTrustMode
				then AutoRuntime.recordValuesMatchPlan(first, plan)
				else AutoRuntime.recordMatchesPlan(first, plan)
			if not valid then plan = nil end
		end
	end
	if plan == nil then
		plan = AutoRuntime.buildRecordPlan(first, 0)
		builtNow = plan ~= nil
		if plan ~= nil and Config.sortedKeysCacheEnabled then
			AutoRuntime.recordPlanCache[first] = plan
		end
	end
	if plan ~= nil and plan.layout == 3 then
		local usesOptionalColumn = false
		for fieldIndex = 1, plan.count do
			if plan.optional[fieldIndex] then
				local key = plan.keys[fieldIndex]
				for rowIndex = 1, count do
					if values[rowIndex][key] ~= nil then usesOptionalColumn = true; break end
				end
				if usesOptionalColumn then break end
			end
		end
		if not usesOptionalColumn then
			plan = AutoRuntime.buildRecordPlan(first, 0)
			builtNow = plan ~= nil
			if plan ~= nil and Config.sortedKeysCacheEnabled then AutoRuntime.recordPlanCache[first] = plan end
		end
	end
	if plan ~= nil and plan.staticOnly then
		local savedOffset, savedBitBuffer, savedBitCount = writer._Checkpoint()
		local savedKeyIndex = AutoRuntime.keyIndex
		writer._WriteBits(TYPE_SPECIAL, 5)
		writer._WriteBits(SUBTYPE_TYPED_RECORD_ARRAY, 5)
		writeCountHeader(writer, count)
		AutoRuntime.writeRecordPlan(writer, plan)
		local trustCache = Config.sortedKeysCacheEnabled and Config.sortedKeysCacheTrustMode
		if not writer._WriteStaticRecordArrayChecked(values, count, plan, builtNow, trustCache) then
			writer._Restore(savedOffset, savedBitBuffer, savedBitCount)
			for cacheIndex = AutoRuntime.keyIndex, savedKeyIndex + 1, -1 do
				local cachedKey = AutoRuntime.keyReverse[cacheIndex]
				if cachedKey ~= nil then AutoRuntime.keyForward[cachedKey] = nil end
				AutoRuntime.keyReverse[cacheIndex] = nil
			end
			AutoRuntime.keyIndex = savedKeyIndex
			plan = nil
		else
			return true
		end
	end
	if plan ~= nil and not plan.dynamicValues then
		if plan.layout == 3 then
			local valid = true
			for i = 1, count do
				if not AutoRuntime.recordMatchesPlan(values[i], plan) then valid = false; break end
			end
			if valid then
				writer._WriteBits(TYPE_SPECIAL, 5)
				writer._WriteBits(SUBTYPE_TYPED_RECORD_ARRAY, 5)
				writeCountHeader(writer, count)
				AutoRuntime.writeRecordPlan(writer, plan)
				AutoRuntime.writeRecordColumns(writer, values, count, plan)
				if Config.sortedKeysCacheEnabled then for i = 1, count do AutoRuntime.recordPlanCache[values[i]] = plan end end
				return true
			end
			plan = nil
		end
	end
	if plan ~= nil and not plan.dynamicValues then
		local savedOffset, savedBitBuffer, savedBitCount = writer._Checkpoint()
		local savedKeyIndex = AutoRuntime.keyIndex
		writer._WriteBits(TYPE_SPECIAL, 5)
		writer._WriteBits(SUBTYPE_TYPED_RECORD_ARRAY, 5)
		writeCountHeader(writer, count)
		AutoRuntime.writeRecordPlan(writer, plan)
		local valid = true
		for i = 1, count do
			if not AutoRuntime.writeRecordDataChecked(writer, values[i], plan) then valid = false; break end
		end
		if valid then
			if Config.sortedKeysCacheEnabled then for i = 1, count do AutoRuntime.recordPlanCache[values[i]] = plan end end
			return true
		end
		writer._Restore(savedOffset, savedBitBuffer, savedBitCount)
		for cacheIndex = AutoRuntime.keyIndex, savedKeyIndex + 1, -1 do
			local cachedKey = AutoRuntime.keyReverse[cacheIndex]
			if cachedKey ~= nil then AutoRuntime.keyForward[cachedKey] = nil end
			AutoRuntime.keyReverse[cacheIndex] = nil
		end
		AutoRuntime.keyIndex = savedKeyIndex
		plan = nil
	end

	local matchesPlan = plan ~= nil
	for i = 2, count do
		if not matchesPlan then break end
		local row = values[i]
		local cachedTrusted = Config.sortedKeysCacheEnabled and Config.sortedKeysCacheTrustMode
			and AutoRuntime.recordPlanCache[row] == plan
		local matches: boolean
		if cachedTrusted then
			matches = AutoRuntime.recordValuesMatchPlan(row, plan)
		else
			matches = AutoRuntime.recordMatchesPlan(row, plan)
		end
		if not matches then matchesPlan = false; break end
		if Config.sortedKeysCacheEnabled then AutoRuntime.recordPlanCache[row] = plan end
	end
	if not matchesPlan then
		plan = AutoRuntime.buildArrayRecordPlan(values, count)
		if plan == nil then return false end
		if Config.sortedKeysCacheEnabled then
			for i = 1, count do AutoRuntime.recordPlanCache[values[i]] = plan end
		end
	end

	writer._WriteBits(TYPE_SPECIAL, 5)
	writer._WriteBits(SUBTYPE_TYPED_RECORD_ARRAY, 5)
	writeCountHeader(writer, count)
	AutoRuntime.writeRecordPlan(writer, plan)
	if plan.layout == 3 then AutoRuntime.writeRecordColumns(writer, values, count, plan)
	else for i = 1, count do AutoRuntime.writeRecordData(writer, values[i], plan) end end
	return true
end

function AutoRuntime.deserializeRecordArray(reader: Reader): {any}
	local count = readCountHeader(reader)
	if count < 2 then
		error(`[Pancakes] Typed Auto record array has invalid count: {count}`, 2)
	end
	local plan = AutoRuntime.readRecordPlan(reader, 0)
	if Config.strictBoundsChecking then
		if plan.count == 0 then
			if count > 65535 then error(`[Pancakes] Empty-record array count {count} exceeds the safety cap`, 2) end
		elseif count > AutoRuntime.decodeBitBudget then
			error(`[Pancakes] Declared record count {count} exceeds the decode safety budget ({AutoRuntime.decodeBitBudget} bits)`, 2)
		end
	end
	local result: {any}
	if plan.staticOnly then
		result = reader._ReadStaticRecordArray(count, plan)
	elseif plan.layout == 3 then
		result = AutoRuntime.readRecordColumns(reader, count, plan)
	else
		result = tableCreate(count)
		for i = 1, count do
			result[i] = AutoRuntime.readRecordData(reader, plan)
		end
	end
	AutoRuntime.lastDecodedRecordArray = result
	AutoRuntime.lastDecodedRecordPlan = plan
	return result
end

function AutoRuntime.classifyDenseDatatype(values: {any}, count: number): number
	local firstType = typeofFn(values[1])
	if firstType == "string" then
		local first = values[1]
		for i = 2, count do if values[i] ~= first then return 0 end end
		return 7
	elseif firstType == "Color3" then
		for i = 2, count do if typeofFn(values[i]) ~= firstType then return 0 end end
		return 3
	elseif firstType == "Vector2" then
		local integer = true
		for i = 1, count do
			local value = values[i]
			if typeofFn(value) ~= firstType then return 0 end
			local x, y = value.X, value.Y
			if x % 1 ~= 0 or y % 1 ~= 0 or x < -32768 or x > 32767 or y < -32768 or y > 32767 then integer = false end
		end
		return integer and 6 or 0
	elseif firstType == "Vector3" then
		local quantized = true
		for i = 1, count do
			local value = values[i]
			if typeofFn(value) ~= firstType then return 0 end
			local x, y, z = value.X, value.Y, value.Z
			local xi, yi, zi = mathFloor(x), mathFloor(y), mathFloor(z)
			if xi < -32768 or xi > 32767 or yi < -32768 or yi > 32767 or zi < -32768 or zi > 32767 then
				quantized = false
			else
				local xe = (x - xi) - mathRound((x - xi) * 255) / 255
				local ye = (y - yi) - mathRound((y - yi) * 255) / 255
				local ze = (z - zi) - mathRound((z - zi) * 255) / 255
				if xe*xe + ye*ye + ze*ze >= 0.00000081 then quantized = false end
			end
		end
		return quantized and 1 or 2
	elseif firstType == "CFrame" then
		local firstSimple: boolean? = nil
		for i = 1, count do
			local value = values[i]
			if typeofFn(value) ~= firstType then return 0 end
			local look, right = value.LookVector, value.RightVector
			local horizontal = look.X * look.X + look.Z * look.Z
			local simple = false
			if horizontal > 1e-8 then
				local inverse = 1 / mathSqrt(horizontal)
				local dx, dz = right.X - look.Z * inverse, right.Z + look.X * inverse
				simple = dx * dx + dz * dz + right.Y * right.Y < 1e-6
			end
			if firstSimple == nil then firstSimple = simple elseif firstSimple ~= simple then return 0 end
		end
		return firstSimple and 4 or 5
	end
	return 0
end

function AutoRuntime.writeDenseDatatype(writer: Writer, values: {any}, count: number, mode: number): ()
	if mode == 7 then
		local value = values[1]
		local len = #value
		if len < 255 then writer._WriteU8(len) else writer._WriteU8(255); writer._WriteU32(len) end
		writer._WriteStringRaw(value)
		return
	end
	for i = 1, count do
		local value = values[i]
		if mode == 1 then
			local xi, yi, zi = mathFloor(value.X), mathFloor(value.Y), mathFloor(value.Z)
			writer._WriteI16(xi); writer._WriteU8(mathRound((value.X - xi) * 255))
			writer._WriteI16(yi); writer._WriteU8(mathRound((value.Y - yi) * 255))
			writer._WriteI16(zi); writer._WriteU8(mathRound((value.Z - zi) * 255))
		elseif mode == 2 then writer._WriteF32(value.X); writer._WriteF32(value.Y); writer._WriteF32(value.Z)
		elseif mode == 3 then
			writer._WriteU8(mathClamp(mathRound(value.R * 255), 0, 255)); writer._WriteU8(mathClamp(mathRound(value.G * 255), 0, 255)); writer._WriteU8(mathClamp(mathRound(value.B * 255), 0, 255))
		elseif mode == 4 then
			local position, look = value.Position, value.LookVector
			writer._WriteF32(position.X); writer._WriteF32(position.Y); writer._WriteF32(position.Z)
			writer._WriteF32(look.X); writer._WriteF32(look.Y); writer._WriteF32(look.Z)
		elseif mode == 5 then
			local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22 = value:GetComponents()
			writer._WriteF32(x); writer._WriteF32(y); writer._WriteF32(z); writer._WriteF32(r00); writer._WriteF32(r01); writer._WriteF32(r02)
			writer._WriteF32(r10); writer._WriteF32(r11); writer._WriteF32(r12); writer._WriteF32(r20); writer._WriteF32(r21); writer._WriteF32(r22)
		else writer._WriteI16(value.X); writer._WriteI16(value.Y) end
	end
end

function AutoRuntime.readDenseDatatype(reader: Reader, count: number, mode: number): {any}
	local values = tableCreate(count)
	if mode == 7 then
		local len = reader._ReadU8()
		if len == 255 then len = reader._ReadU32() end
		local value = reader._ReadStringRaw(len)
		for i = 1, count do values[i] = value end
		return values
	end
	for i = 1, count do
		if mode == 1 then
			values[i] = Vector3.new(reader._ReadI16() + reader._ReadU8()/255, reader._ReadI16() + reader._ReadU8()/255, reader._ReadI16() + reader._ReadU8()/255)
		elseif mode == 2 then values[i] = Vector3.new(reader._ReadF32(), reader._ReadF32(), reader._ReadF32())
		elseif mode == 3 then values[i] = Color3.new(reader._ReadU8()/255, reader._ReadU8()/255, reader._ReadU8()/255)
		elseif mode == 4 then
			local x,y,z,lx,ly,lz = reader._ReadF32(),reader._ReadF32(),reader._ReadF32(),reader._ReadF32(),reader._ReadF32(),reader._ReadF32()
			values[i] = CFrame.lookAt(Vector3.new(x,y,z), Vector3.new(x+lx,y+ly,z+lz))
		elseif mode == 5 then
			values[i] = CFrame.new(reader._ReadF32(),reader._ReadF32(),reader._ReadF32(),reader._ReadF32(),reader._ReadF32(),reader._ReadF32(),reader._ReadF32(),reader._ReadF32(),reader._ReadF32(),reader._ReadF32(),reader._ReadF32(),reader._ReadF32())
		elseif mode == 6 then values[i] = Vector2.new(reader._ReadI16(), reader._ReadI16())
		else error(`[Pancakes] Unknown dense datatype mode: {mode}`, 2) end
	end
	return values
end

local BASE85_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~"

local BASE85_DECODE: {[number]: number} = {}
for i = 1, #BASE85_CHARS do
	BASE85_DECODE[stringSub(BASE85_CHARS, i, i):byte()] = i - 1
end

function Pancakes.ToBase85(buf: buffer): string
	local len    = bufferLen(buf)
	local result = tableCreate(mathFloor(len * 1.25) + 5)
	local idx    = 1
	for i = 0, len - 1, 4 do
		local bytes = mathMin(4, len - i)
		local value = 0
		for j = 0, bytes - 1 do value = value * 256 + bufferReadU8(buf, i + j) end
		if bytes == 4 and value == 0 then
			result[idx] = "z"; idx += 1
		else
			for j = 4, 0, -1 do
				local ci = (value % 85) + 1
				result[idx + j] = stringSub(BASE85_CHARS, ci, ci)
				value = mathFloor(value / 85)
			end
			idx += mathFloor(bytes * 1.25) + 1
		end
	end
	return tableConcat(result, "", 1, idx - 1)
end

function Pancakes.FromBase85(str: string): buffer
	local len    = #str
	local result = bufferCreate(mathFloor(len * 0.8) + 4)
	local outIdx = 0
	local i      = 1
	while i <= len do
		local char = stringSub(str, i, i)
		if char == "z" then
			for j = 0, 3 do bufferWriteU8(result, outIdx + j, 0) end
			outIdx += 4; i += 1
		else
			local chars = mathMin(5, len - i + 1)
			local value = 0
			for j = 0, chars - 1 do
				local b = stringSub(str, i + j, i + j):byte()
				value = value * 85 + (BASE85_DECODE[b] or 0)
			end
			local bytesToWrite = mathFloor(chars * 0.8)
			for j = bytesToWrite - 1, 0, -1 do
				if outIdx + j < bufferLen(result) then
					bufferWriteU8(result, outIdx + j, value % 256)
					value = mathFloor(value / 256)
				end
			end
			outIdx += bytesToWrite; i += chars
		end
	end
	local final = bufferCreate(outIdx)
	bufferCopy(final, 0, result, 0, outIdx)
	return final
end

local BASE91_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&()*+,./:;<=>?@[]^_`{|}~\""

local BASE91_DECODE: {[number]: number} = {}
for i = 1, #BASE91_CHARS do
	BASE91_DECODE[stringSub(BASE91_CHARS, i, i):byte()] = i - 1
end

function Pancakes.ToBase91(buf: buffer): string
	local len    = bufferLen(buf)
	local result = tableCreate(mathFloor(len * 1.2) + 4)
	local idx    = 1
	local v, b   = 0, 0
	for i = 0, len - 1 do
		v = bit32bor(v, bit32lshift(bufferReadU8(buf, i), b))
		b += 8
		if b > 13 then
			local val: number
			if bit32band(v, 8191) > 88 then
				val = bit32band(v, 8191); v = bit32rshift(v, 13); b -= 13
			else
				val = bit32band(v, 16383); v = bit32rshift(v, 14); b -= 14
			end
			local a = val % 91 + 1
			local c = mathFloor(val / 91) + 1
			result[idx]     = stringSub(BASE91_CHARS, a, a)
			result[idx + 1] = stringSub(BASE91_CHARS, c, c)
			idx += 2
		end
	end
	if b > 0 then
		local a = v % 91 + 1
		result[idx] = stringSub(BASE91_CHARS, a, a); idx += 1
		if b > 7 or v > 90 then
			local c = mathFloor(v / 91) + 1
			result[idx] = stringSub(BASE91_CHARS, c, c); idx += 1
		end
	end
	return tableConcat(result, "", 1, idx - 1)
end

function Pancakes.FromBase91(str: string): buffer
	local len    = #str
	local result = bufferCreate(mathFloor(len * 0.87) + 4)
	local outIdx = 0
	local v, b   = -1, 0
	for i = 1, len do
		local p = BASE91_DECODE[stringSub(str, i, i):byte()]
		if p == nil then continue end
		if v < 0 then
			v = p
		else
			v += p * 91
			b  = bit32band(v, 8191) > 88 and 13 or 14
			repeat
				bufferWriteU8(result, outIdx, bit32band(v, 255))
				outIdx += 1
				v = bit32rshift(v, 8)
				b -= 8
			until b <= 7
			v = -1
		end
	end
	if v >= 0 then
		bufferWriteU8(result, outIdx, bit32band(v, 255))
		outIdx += 1
	end
	local final = bufferCreate(outIdx)
	bufferCopy(final, 0, result, 0, outIdx)
	return final
end

function Pancakes.ToHex(buf: buffer): string
	local len    = bufferLen(buf)
	local result = tableCreate(len)
	for i = 0, len - 1 do
		result[i + 1] = stringFormat("%02x", bufferReadU8(buf, i))
	end
	return tableConcat(result)
end

function Pancakes.FromHex(str: string): buffer
	local len    = mathFloor(#str / 2)
	local result = bufferCreate(len)
	for i = 0, len - 1 do
		local hex = stringSub(str, i * 2 + 1, i * 2 + 2)
		bufferWriteU8(result, i, tonumber(hex, 16) or 0)
	end
	return result
end

local autoObservedSize = 1024

type AutoLayoutSnapshot = {
	rootKeys: {any},
	rootValues: {any},
	rootTableCopies: {[number]: {any}}?,
	rootTableMarkers: {[number]: number}?,
	arrayIndex: number,
	count: number,
	plan: AutoRecordPlan,
	flatValues: {any},
	patchOffsets: {number},
	encoded: buffer,
	commonKeys: {string},
	stringCacheMinLength: number,
	patternKeysEnabled: boolean,
	immutable: boolean,
}

type SchemaEncodeLayoutSnapshot = {
	count: number,
	flatValues: {any},
	patchOffsets: {number},
	tailOffset: number,
	tailU32Offset: number,
	tailU16: number,
	tailU32: number,
	encoded: buffer,
	cooldown: number,
	immutable: boolean,
}

type DecodeLayoutSnapshot = {
	wire: string,
	result: {[any]: any},
	arrayKey: any,
	nestedKey: any,
	nestedKey2: any?,
	layout: number,
	cooldown: number,
	commonKeys: {string},
	stringCacheMinLength: number,
}

type GenericEncodeSnapshot = {
	source: {[any]: any},
	encoded: buffer,
	commonKeys: {string},
	stringCacheMinLength: number,
	patternKeysEnabled: boolean,
}

type AutoSnapshotRuntimeState = {
	layouts: {[any]: AutoLayoutSnapshot},
	cooldowns: {[any]: number},
	genericEncodes: {[any]: GenericEncodeSnapshot},
	genericCooldowns: {[any]: number},
	schemaEncodes: {[any]: {[any]: GenericEncodeSnapshot}},
	decodes: {[number]: DecodeLayoutSnapshot},
	decodeCount: number,
	canSnapshotTree: (value: any, depth: number) -> boolean,
	cloneSnapshotTree: (value: any) -> any,
	snapshotTreesEqual: (left: any, right: any) -> boolean,
	tryReuseGenericAuto: (data: any) -> buffer?,
	captureGenericAuto: (data: any, encoded: buffer) -> (),
	tryReuseLayout2: (data: {[any]: any}, snapshot: AutoLayoutSnapshot) -> buffer?,
	captureLayout2: (data: {[any]: any}, encoded: buffer, rootKeys: {any}, arrayIndex: number, values: {any}, plan: AutoRecordPlan) -> boolean,
}

local function cloneDecodedLayout(snapshot: DecodeLayoutSnapshot): {[any]: any}
	local sourceRoot = snapshot.result
	if snapshot.layout == 3 then
		local function cloneTree(value: any): any
			if type(value) ~= "table" then return value end
			local copy = tableClone(value)
			for key, entry in value do
				if type(entry) == "table" then copy[key] = cloneTree(entry) end
			end
			return copy
		end
		return cloneTree(sourceRoot)
	end
	local arrayKey, nestedKey, nestedKey2 = snapshot.arrayKey, snapshot.nestedKey, snapshot.nestedKey2
	local sourceValues = sourceRoot[arrayKey]

	local values = tableCreate(#sourceValues)
	for i = 1, #sourceValues do
		local sourceRow = sourceValues[i]
		local row = tableClone(sourceRow)
		row[nestedKey] = tableClone(sourceRow[nestedKey])
		if nestedKey2 ~= nil then row[nestedKey2] = tableClone(sourceRow[nestedKey2]) end
		values[i] = row
	end
	local result = tableClone(sourceRoot)
	result[arrayKey] = values
	if snapshot.layout == 2 then
		for key, value in sourceRoot do
			if key ~= arrayKey and type(value) == "table" then result[key] = tableClone(value) end
		end
	end
	return result
end

local AutoSnapshotRuntime: AutoSnapshotRuntimeState = {
	layouts = setmetatable({}, {__mode = "k"}),
	cooldowns = setmetatable({}, {__mode = "k"}),
	genericEncodes = setmetatable({}, {__mode = "k"}),
	genericCooldowns = setmetatable({}, {__mode = "k"}),
	schemaEncodes = setmetatable({}, {__mode = "k"}),
	decodes = {},
	decodeCount = 0,
} :: any

local function cloneBuffer(source: buffer): buffer
	local result = bufferCreate(bufferLen(source))
	bufferCopy(result, 0, source)
	return result
end

function AutoSnapshotRuntime.canSnapshotTree(value: any, depth: number): boolean
	local valueType = type(value)
	if valueType ~= "table" then
		return valueType == "nil" or valueType == "boolean"
			or valueType == "number" or valueType == "string"
	end
	if depth >= 12 or getmetatable(value) ~= nil then return false end
	for key, entry in value do
		local keyType = type(key)
		if keyType ~= "string" and keyType ~= "number" then return false end
		if not AutoSnapshotRuntime.canSnapshotTree(entry, depth + 1) then return false end
	end
	return true
end

function AutoSnapshotRuntime.cloneSnapshotTree(value: any): any
	if type(value) ~= "table" then return value end
	local copy = tableClone(value)
	for key, entry in value do
		if type(entry) == "table" then copy[key] = AutoSnapshotRuntime.cloneSnapshotTree(entry) end
	end
	return copy
end

function AutoSnapshotRuntime.snapshotTreesEqual(left: any, right: any): boolean
	if left == right and type(left) ~= "table" then return true end
	if type(left) ~= "table" or type(right) ~= "table" then return false end
	local seen = 0
	for key, leftValue in left do
		seen += 1
		local rightValue = right[key]
		if type(leftValue) == "table" then
			if not AutoSnapshotRuntime.snapshotTreesEqual(leftValue, rightValue) then return false end
		elseif leftValue ~= rightValue then return false end
	end
	local rightCount = 0
	for _ in right do
		rightCount += 1
		if rightCount > seen then return false end
	end
	return rightCount == seen
end

function AutoSnapshotRuntime.tryReuseGenericAuto(data: any): buffer?
	if type(data) ~= "table" then return nil end
	local cooldown = AutoSnapshotRuntime.genericCooldowns[data]
	if cooldown ~= nil then
		if cooldown <= 1 then AutoSnapshotRuntime.genericCooldowns[data] = nil
		else AutoSnapshotRuntime.genericCooldowns[data] = cooldown - 1 end
		return nil
	end
	local snapshot = AutoSnapshotRuntime.genericEncodes[data]
	if snapshot == nil then return nil end
	if snapshot.commonKeys ~= Config.commonKeys
		or snapshot.stringCacheMinLength ~= Config.stringCacheMinLength
		or snapshot.patternKeysEnabled ~= Config.patternKeysEnabled then
		AutoSnapshotRuntime.genericEncodes[data] = nil
		return nil
	end
	if AutoSnapshotRuntime.snapshotTreesEqual(data, snapshot.source) then
		return cloneBuffer(snapshot.encoded)
	end
	AutoSnapshotRuntime.genericEncodes[data] = nil
	AutoSnapshotRuntime.genericCooldowns[data] = 16
	return nil
end

function AutoSnapshotRuntime.captureGenericAuto(data: any, encoded: buffer): ()
	if type(data) ~= "table" or AutoSnapshotRuntime.genericCooldowns[data] ~= nil
		or not AutoSnapshotRuntime.canSnapshotTree(data, 0) then return end
	local optionalRecords = false
	if #data >= 2 and type(data[1]) == "table" then
		local directPlan = AutoRuntime.recordPlanCache[data[1]]
		optionalRecords = directPlan ~= nil and (directPlan.layout == 3 or directPlan.staticOnly)
	else
		for _, value in data do
			if type(value) == "table" and #value >= 2 and type(value[1]) == "table" then
				local plan = AutoRuntime.recordPlanCache[value[1]]
				if plan ~= nil and (plan.layout == 3 or (plan.layout == 0 and plan.staticOnly)) then
					optionalRecords = true
					break
				end
			end
		end
	end
	if not optionalRecords then return end
	AutoSnapshotRuntime.genericEncodes[data] = {
		source = AutoSnapshotRuntime.cloneSnapshotTree(data),
		encoded = cloneBuffer(encoded),
		commonKeys = Config.commonKeys,
		stringCacheMinLength = Config.stringCacheMinLength,
		patternKeysEnabled = Config.patternKeysEnabled,
	}
end

local function rejectAutoLayoutSnapshot(data: any): buffer?
	AutoSnapshotRuntime.layouts[data] = nil
	AutoSnapshotRuntime.cooldowns[data] = 32
	return nil
end

function AutoSnapshotRuntime.tryReuseLayout2(data: {[any]: any}, snapshot: AutoLayoutSnapshot): buffer?
	if hasRegisteredConverter(data) then return rejectAutoLayoutSnapshot(data) end
	local rootKeys, rootValues = snapshot.rootKeys, snapshot.rootValues
	local rootCopies = snapshot.rootTableCopies
	local rootMarkers = snapshot.rootTableMarkers
	if rootCopies == nil or rootMarkers == nil then return rejectAutoLayoutSnapshot(data) end
	local rootCount, actualRootCount = #rootKeys, 0
	for _ in data do
		actualRootCount += 1
		if actualRootCount > rootCount then return rejectAutoLayoutSnapshot(data) end
	end
	if actualRootCount ~= rootCount then return rejectAutoLayoutSnapshot(data) end

	local values: any = nil
	for i = 1, rootCount do
		local value = data[rootKeys[i]]
		if value == nil then return rejectAutoLayoutSnapshot(data) end
		if i == snapshot.arrayIndex then
			values = value
		else
			local copy = rootCopies[i]
			if copy == nil then
				if value ~= rootValues[i] then return rejectAutoLayoutSnapshot(data) end
			elseif value ~= rootValues[i] or type(value) ~= "table" then
				return rejectAutoLayoutSnapshot(data)
			else
				if hasRegisteredConverter(value) then return rejectAutoLayoutSnapshot(data) end
				local marker = rootMarkers[i]
				if marker >= 0 then
					if #value ~= marker or next(value, marker) ~= nil then return rejectAutoLayoutSnapshot(data) end
					for j = 1, marker do
						if value[j] ~= copy[j] then return rejectAutoLayoutSnapshot(data) end
					end
				else
					local expectedCount, seen = -marker - 1, 0
					for key, entry in value do
						seen += 1
						if seen > expectedCount or entry ~= copy[key] then return rejectAutoLayoutSnapshot(data) end
					end
					if seen ~= expectedCount then return rejectAutoLayoutSnapshot(data) end
				end
			end
		end
	end
	if type(values) ~= "table" or hasRegisteredConverter(values) then return rejectAutoLayoutSnapshot(data) end
	local count = #values
	if count ~= snapshot.count or next(values, count) ~= nil then return rejectAutoLayoutSnapshot(data) end

	local plan = snapshot.plan
	local keys, flagKeys, statKeys = plan.keys, plan.children[3].keys, plan.children[9].keys
	local k1, k2, k3, k4, k5, k6, k7, k8, k9 =
		keys[1], keys[2], keys[3], keys[4], keys[5], keys[6], keys[7], keys[8], keys[9]
	local f1, f2, f3 = flagKeys[1], flagKeys[2], flagKeys[3]
	local s1, s2, s3 = statKeys[1], statKeys[2], statKeys[3]
	local flat, offsets, encoded = snapshot.flatValues, snapshot.patchOffsets, snapshot.encoded
	local trustShape = Config.sortedKeysCacheTrustMode
	for i = 1, count do
		local row = values[i]
		if type(row) ~= "table" or hasRegisteredConverter(row) then return rejectAutoLayoutSnapshot(data) end
		if not trustShape then
			local rowCount = 0
			for _ in row do rowCount += 1; if rowCount > 9 then return rejectAutoLayoutSnapshot(data) end end
			if rowCount ~= 9 then return rejectAutoLayoutSnapshot(data) end
		end
		local b1, b2, flags = row[k1], row[k2], row[k3]
		local id, b3, name, orderIndex, rarity, stats = row[k4], row[k5], row[k6], row[k7], row[k8], row[k9]
		if type(flags) ~= "table" or type(stats) ~= "table"
			or hasRegisteredConverter(flags) or hasRegisteredConverter(stats) then
			return rejectAutoLayoutSnapshot(data)
		end
		if not trustShape then
			local flagsCount, statsCount = 0, 0
			for _ in flags do flagsCount += 1; if flagsCount > 3 then return rejectAutoLayoutSnapshot(data) end end
			for _ in stats do statsCount += 1; if statsCount > 3 then return rejectAutoLayoutSnapshot(data) end end
			if flagsCount ~= 3 or statsCount ~= 3 then return rejectAutoLayoutSnapshot(data) end
		end
		local fv1, fv2, fv3 = flags[f1], flags[f2], flags[f3]
		local sv1, sv2, sv3 = stats[s1], stats[s2], stats[s3]
		local base = (i - 1) * 13
		if b1 ~= flat[base + 1] or b2 ~= flat[base + 2]
			or fv1 ~= flat[base + 3] or fv2 ~= flat[base + 4] or fv3 ~= flat[base + 5]
			or id ~= flat[base + 6] or b3 ~= flat[base + 7] or name ~= flat[base + 8]
			or orderIndex ~= flat[base + 9] or rarity ~= flat[base + 10]
			or sv1 ~= flat[base + 11] or sv2 ~= flat[base + 12] or sv3 ~= flat[base + 13] then
			local patchBase = (i - 1) * 12
			if type(b1) ~= "boolean" or type(b2) ~= "boolean"
				or type(fv1) ~= "boolean" or type(fv2) ~= "boolean" or type(fv3) ~= "boolean"
				or type(id) ~= "number" or id ~= bit32band(id, 65535)
				or type(b3) ~= "boolean" or type(name) ~= "string" or #name ~= offsets[patchBase + 6]
				or type(orderIndex) ~= "number" or orderIndex ~= bit32band(orderIndex, 65535)
				or type(rarity) ~= "string" or #rarity ~= offsets[patchBase + 9]
				or type(sv1) ~= "number" or sv1 ~= bit32band(sv1, 65535)
				or type(sv2) ~= "number" or sv2 ~= bit32band(sv2, 65535)
				or type(sv3) ~= "number" or sv3 ~= bit32band(sv3, 65535) then
				return rejectAutoLayoutSnapshot(data)
			end

			local header = (if b1 then 1 else 0) + (if b2 then 2 else 0)
				+ (if fv1 then 4 else 0) + (if fv2 then 8 else 0) + (if fv3 then 16 else 0)
				+ (if b3 then 32 else 0)
			local headerByte, headerBit = offsets[patchBase + 1], offsets[patchBase + 2]
			for bit = 0, 5 do
				local position = headerBit + bit
				local byteOffset, inByte = headerByte + mathFloor(position / 8), position % 8
				local mask = bit32lshift(1, inByte)
				local byte = bit32band(bufferReadU8(encoded, byteOffset), 255 - mask)
				if bit32band(header, bit32lshift(1, bit)) ~= 0 then byte = bit32bor(byte, mask) end
				bufferWriteU8(encoded, byteOffset, byte)
			end
			if id ~= flat[base + 6] then
				if (id < 255) ~= (flat[base + 6] < 255) then return rejectAutoLayoutSnapshot(data) end
				if id < 255 then bufferWriteU8(encoded, offsets[patchBase + 3], id)
				else bufferWriteU16(encoded, offsets[patchBase + 3] + 1, id) end
			end
			bufferWriteStr(encoded, offsets[patchBase + 5], name)
			if orderIndex ~= flat[base + 9] then
				if (orderIndex < 255) ~= (flat[base + 9] < 255) then return rejectAutoLayoutSnapshot(data) end
				if orderIndex < 255 then bufferWriteU8(encoded, offsets[patchBase + 7], orderIndex)
				else bufferWriteU16(encoded, offsets[patchBase + 7] + 1, orderIndex) end
			end
			bufferWriteStr(encoded, offsets[patchBase + 8], rarity)
			if sv1 ~= flat[base + 11] then
				if (sv1 < 255) ~= (flat[base + 11] < 255) then return rejectAutoLayoutSnapshot(data) end
				if sv1 < 255 then bufferWriteU8(encoded, offsets[patchBase + 10], sv1)
				else bufferWriteU16(encoded, offsets[patchBase + 10] + 1, sv1) end
			end
			if sv2 ~= flat[base + 12] then
				if (sv2 < 255) ~= (flat[base + 12] < 255) then return rejectAutoLayoutSnapshot(data) end
				if sv2 < 255 then bufferWriteU8(encoded, offsets[patchBase + 11], sv2)
				else bufferWriteU16(encoded, offsets[patchBase + 11] + 1, sv2) end
			end
			if sv3 ~= flat[base + 13] then
				if (sv3 < 255) ~= (flat[base + 13] < 255) then return rejectAutoLayoutSnapshot(data) end
				if sv3 < 255 then bufferWriteU8(encoded, offsets[patchBase + 12], sv3)
				else bufferWriteU16(encoded, offsets[patchBase + 12] + 1, sv3) end
			end
			flat[base + 1], flat[base + 2], flat[base + 3] = b1, b2, fv1
			flat[base + 4], flat[base + 5], flat[base + 6] = fv2, fv3, id
			flat[base + 7], flat[base + 8], flat[base + 9] = b3, name, orderIndex
			flat[base + 10], flat[base + 11], flat[base + 12], flat[base + 13] = rarity, sv1, sv2, sv3
		end
	end
	return cloneBuffer(encoded)
end

local function tryReuseAutoLayoutSnapshot(data: any): buffer?
	if not Config.sortedKeysCacheEnabled or type(data) ~= "table" then return nil end
	if hasRegisteredConverter(data) then return rejectAutoLayoutSnapshot(data) end
	local cooldown = AutoSnapshotRuntime.cooldowns[data]
	if cooldown ~= nil then
		if cooldown <= 1 then AutoSnapshotRuntime.cooldowns[data] = nil
		else AutoSnapshotRuntime.cooldowns[data] = cooldown - 1 end
		return nil
	end
	local snapshot = AutoSnapshotRuntime.layouts[data]
	if snapshot == nil or snapshot.commonKeys ~= Config.commonKeys
		or snapshot.stringCacheMinLength ~= Config.stringCacheMinLength
		or snapshot.patternKeysEnabled ~= Config.patternKeysEnabled then return nil end
	if snapshot.immutable and converterCount == 0 then return cloneBuffer(snapshot.encoded) end
	if snapshot.plan.layout == 2 then return AutoSnapshotRuntime.tryReuseLayout2(data, snapshot) end

	local rootKeys = snapshot.rootKeys
	local rootCount = #rootKeys
	local actualRootCount = 0
	for _ in data do
		actualRootCount += 1
		if actualRootCount > rootCount then return rejectAutoLayoutSnapshot(data) end
	end
	if actualRootCount ~= rootCount then return rejectAutoLayoutSnapshot(data) end
	local arrayIndex = snapshot.arrayIndex
	local values: any = nil
	for i = 1, rootCount do
		local value = data[rootKeys[i]]
		if value == nil then return rejectAutoLayoutSnapshot(data) end
		if i == arrayIndex then
			values = value
		elseif value ~= snapshot.rootValues[i] then
			return rejectAutoLayoutSnapshot(data)
		end
	end
	if type(values) ~= "table" or hasRegisteredConverter(values) then return rejectAutoLayoutSnapshot(data) end
	local count = #values
	if count ~= snapshot.count or next(values, count) ~= nil then return rejectAutoLayoutSnapshot(data) end

	local plan = snapshot.plan
	local keys = plan.keys
	local childKeys = plan.children[5].keys
	local key1, key2, key3, key4, key5 = keys[1], keys[2], keys[3], keys[4], keys[5]
	local child1, child2, child3 = childKeys[1], childKeys[2], childKeys[3]
	local flat = snapshot.flatValues
	local patchOffsets = snapshot.patchOffsets
	local encoded = snapshot.encoded
	local trustShape = Config.sortedKeysCacheTrustMode
	for i = 1, count do
		local row = values[i]
		if type(row) ~= "table" or hasRegisteredConverter(row) then return rejectAutoLayoutSnapshot(data) end
		local value1, value2, value3, value4, nested
		if trustShape then
			value1, value2, value3, value4, nested = row[key1], row[key2], row[key3], row[key4], row[key5]
		else
			local rowCount = 0
			for key, value in row do
				rowCount += 1
				if key == key1 then value1 = value
				elseif key == key2 then value2 = value
				elseif key == key3 then value3 = value
				elseif key == key4 then value4 = value
				elseif key == key5 then nested = value
				else return rejectAutoLayoutSnapshot(data) end
			end
			if rowCount ~= 5 then return rejectAutoLayoutSnapshot(data) end
		end
		if type(nested) ~= "table" or hasRegisteredConverter(nested) then return rejectAutoLayoutSnapshot(data) end
		local nested1, nested2, nested3
		if trustShape then
			nested1, nested2, nested3 = nested[child1], nested[child2], nested[child3]
		else
			local nestedCount = 0
			for key, value in nested do
				nestedCount += 1
				if key == child1 then nested1 = value
				elseif key == child2 then nested2 = value
				elseif key == child3 then nested3 = value
				else return rejectAutoLayoutSnapshot(data) end
			end
			if nestedCount ~= 3 then return rejectAutoLayoutSnapshot(data) end
		end
		local base = (i - 1) * 7
		if value1 ~= flat[base + 1] or value2 ~= flat[base + 2]
			or value3 ~= flat[base + 3] or value4 ~= flat[base + 4]
			or nested1 ~= flat[base + 5] or nested2 ~= flat[base + 6]
			or nested3 ~= flat[base + 7] then
			local patchBase = (i - 1) * 10
			if type(value1) ~= "boolean"
				or type(value2) ~= "number" or value2 ~= bit32band(value2, 65535)
				or type(value3) ~= "string" or #value3 ~= patchOffsets[patchBase + 5]
				or type(value4) ~= "string" or #value4 ~= patchOffsets[patchBase + 7]
				or type(nested1) ~= "number" or nested1 ~= bit32band(nested1, 65535)
				or type(nested2) ~= "number" or nested2 ~= bit32band(nested2, 65535)
				or type(nested3) ~= "number" or nested3 ~= bit32band(nested3, 65535) then
				return rejectAutoLayoutSnapshot(data)
			end
			if value1 ~= flat[base + 1] then
				local byteOffset, bitOffset = patchOffsets[patchBase + 1], patchOffsets[patchBase + 2]
				local mask = bit32lshift(1, bitOffset)
				local byte = bit32band(bufferReadU8(encoded, byteOffset), 255 - mask)
				bufferWriteU8(encoded, byteOffset, bit32bor(byte, value1 and mask or 0))
			end
			if value2 ~= flat[base + 2] then
				if (value2 < 255) ~= (flat[base + 2] < 255) then return rejectAutoLayoutSnapshot(data) end
				if value2 < 255 then bufferWriteU8(encoded, patchOffsets[patchBase + 3], value2)
				else bufferWriteU16(encoded, patchOffsets[patchBase + 3] + 1, value2) end
			end
			if value3 ~= flat[base + 3] then bufferWriteStr(encoded, patchOffsets[patchBase + 4], value3) end
			if value4 ~= flat[base + 4] then bufferWriteStr(encoded, patchOffsets[patchBase + 6], value4) end
			if nested1 ~= flat[base + 5] then
				if (nested1 < 255) ~= (flat[base + 5] < 255) then return rejectAutoLayoutSnapshot(data) end
				if nested1 < 255 then bufferWriteU8(encoded, patchOffsets[patchBase + 8], nested1)
				else bufferWriteU16(encoded, patchOffsets[patchBase + 8] + 1, nested1) end
			end
			if nested2 ~= flat[base + 6] then
				if (nested2 < 255) ~= (flat[base + 6] < 255) then return rejectAutoLayoutSnapshot(data) end
				if nested2 < 255 then bufferWriteU8(encoded, patchOffsets[patchBase + 9], nested2)
				else bufferWriteU16(encoded, patchOffsets[patchBase + 9] + 1, nested2) end
			end
			if nested3 ~= flat[base + 7] then
				if (nested3 < 255) ~= (flat[base + 7] < 255) then return rejectAutoLayoutSnapshot(data) end
				if nested3 < 255 then bufferWriteU8(encoded, patchOffsets[patchBase + 10], nested3)
				else bufferWriteU16(encoded, patchOffsets[patchBase + 10] + 1, nested3) end
			end
			flat[base + 1], flat[base + 2] = value1, value2
			flat[base + 3], flat[base + 4] = value3, value4
			flat[base + 5], flat[base + 6], flat[base + 7] = nested1, nested2, nested3
		end
	end
	return cloneBuffer(encoded)
end

function AutoSnapshotRuntime.captureLayout2(
	data: {[any]: any}, encoded: buffer, rootKeys: {any}, arrayIndex: number,
	values: {any}, plan: AutoRecordPlan): boolean
	local rootCount, count = #rootKeys, #values
	if hasRegisteredConverter(data) or hasRegisteredConverter(values)
		or next(values, count) ~= nil or not AutoRuntime.lastLayoutValid
		or AutoRuntime.lastLayoutCount ~= count then return false end
	local rootValues = tableCreate(rootCount)
	local rootCopies: {[number]: {any}} = {}
	local rootMarkers: {[number]: number} = {}
	local immutable = tableIsFrozen(data) and tableIsFrozen(values)
	for i = 1, rootCount do
		local value = data[rootKeys[i]]
		if value == nil then return false end
		rootValues[i] = value
		if i ~= arrayIndex and type(value) == "table" then
			if hasRegisteredConverter(value) then return false end
			local entryCount = 0
			for _, entry in value do
				entryCount += 1
				if type(entry) == "table" then return false end
			end
			local denseLength = #value
			rootMarkers[i] = if denseLength > 0 and next(value, denseLength) == nil
				then denseLength else -entryCount - 1
			rootCopies[i] = tableClone(value)
			immutable = immutable and tableIsFrozen(value)
		elseif i ~= arrayIndex and type(value) ~= "number" and type(value) ~= "string"
			and type(value) ~= "boolean" then return false end
	end

	local keys, flagKeys, statKeys = plan.keys, plan.children[3].keys, plan.children[9].keys
	local k1, k2, k3, k4, k5, k6, k7, k8, k9 =
		keys[1], keys[2], keys[3], keys[4], keys[5], keys[6], keys[7], keys[8], keys[9]
	local f1, f2, f3 = flagKeys[1], flagKeys[2], flagKeys[3]
	local s1, s2, s3 = statKeys[1], statKeys[2], statKeys[3]
	local flat = tableCreate(count * 13)
	for i = 1, count do
		local row = values[i]
		if type(row) ~= "table" or hasRegisteredConverter(row) then return false end
		local rowCount = 0
		for _ in row do rowCount += 1 end
		if rowCount ~= 9 then return false end
		local flags, stats = row[k3], row[k9]
		if type(flags) ~= "table" or type(stats) ~= "table"
			or hasRegisteredConverter(flags) or hasRegisteredConverter(stats) then return false end
		local flagsCount, statsCount = 0, 0
		for _ in flags do flagsCount += 1 end
		for _ in stats do statsCount += 1 end
		if flagsCount ~= 3 or statsCount ~= 3 then return false end
		immutable = immutable and tableIsFrozen(row) and tableIsFrozen(flags) and tableIsFrozen(stats)
		local base = (i - 1) * 13
		flat[base + 1], flat[base + 2] = row[k1], row[k2]
		flat[base + 3], flat[base + 4], flat[base + 5] = flags[f1], flags[f2], flags[f3]
		flat[base + 6], flat[base + 7], flat[base + 8] = row[k4], row[k5], row[k6]
		flat[base + 9], flat[base + 10] = row[k7], row[k8]
		flat[base + 11], flat[base + 12], flat[base + 13] = stats[s1], stats[s2], stats[s3]
	end
	local patchOffsets = tableCreate(count * 12, 0)
	table.move(AutoRuntime.lastLayoutOffsets, 1, count * 12, 1, patchOffsets)
	AutoSnapshotRuntime.layouts[data] = {
		rootKeys = rootKeys,
		rootValues = rootValues,
		rootTableCopies = rootCopies,
		rootTableMarkers = rootMarkers,
		arrayIndex = arrayIndex,
		count = count,
		plan = plan,
		flatValues = flat,
		patchOffsets = patchOffsets,
		encoded = cloneBuffer(encoded),
		commonKeys = Config.commonKeys,
		stringCacheMinLength = Config.stringCacheMinLength,
		patternKeysEnabled = Config.patternKeysEnabled,
		immutable = immutable,
	}
	return true
end

local function captureAutoLayoutSnapshot(data: any, encoded: buffer): ()
	if not Config.sortedKeysCacheEnabled or type(data) ~= "table" or hasRegisteredConverter(data) then return end
	if AutoSnapshotRuntime.cooldowns[data] ~= nil then return end
	local cachedRoot = sortedKeysCache[data]
	if cachedRoot == nil then
		AutoSnapshotRuntime.cooldowns[data] = 32
		return
	end
	local rootKeys = cachedRoot.sortedKeys
	local rootCount = cachedRoot.count
	local rootValues = tableCreate(rootCount)
	local arrayIndex = 0
	local values: any = nil
	local plan: AutoRecordPlan? = nil
	for i = 1, rootCount do
		local value = data[rootKeys[i]]
		rootValues[i] = value
		if type(value) == "table" and #value >= 2 then
			local firstPlan = AutoRuntime.recordPlanCache[value[1]]
			if firstPlan ~= nil and firstPlan.staticOnly and (firstPlan.layout == 1 or firstPlan.layout == 2) then
				if arrayIndex ~= 0 then AutoSnapshotRuntime.cooldowns[data] = 32; return end
				arrayIndex, values, plan = i, value, firstPlan
			end
		end
	end
	if arrayIndex == 0 or next(values, #values) ~= nil then AutoSnapshotRuntime.cooldowns[data] = 32; return end
	if hasRegisteredConverter(values) then AutoSnapshotRuntime.cooldowns[data] = 32; return end
	local count = #values
	if plan == nil then AutoSnapshotRuntime.cooldowns[data] = 32; return end
	if plan.layout == 2 then
		if not AutoSnapshotRuntime.captureLayout2(data, encoded, rootKeys, arrayIndex, values, plan) then
			AutoSnapshotRuntime.cooldowns[data] = 32
		end
		return
	end
	if rootCount ~= 3 then AutoSnapshotRuntime.cooldowns[data] = 32; return end
	for i = 1, rootCount do
		local value = rootValues[i]
		if i ~= arrayIndex and type(value) ~= "number" and type(value) ~= "string"
			and type(value) ~= "boolean" then AutoSnapshotRuntime.cooldowns[data] = 32; return end
	end
	if not AutoRuntime.lastLayoutValid or AutoRuntime.lastLayoutCount ~= count then
		AutoSnapshotRuntime.cooldowns[data] = 32
		return
	end

	local keys = plan.keys
	local childKeys = plan.children[5].keys
	local key1, key2, key3, key4, key5 = keys[1], keys[2], keys[3], keys[4], keys[5]
	local child1, child2, child3 = childKeys[1], childKeys[2], childKeys[3]
	local flat = tableCreate(count * 7)
	local immutable = tableIsFrozen(data) and tableIsFrozen(values)
	for i = 1, count do
		local row = values[i]
		if type(row) ~= "table" or hasRegisteredConverter(row) then AutoSnapshotRuntime.cooldowns[data] = 32; return end
		local rowCount = 0
		for _ in row do rowCount += 1 end
		if rowCount ~= 5 then AutoSnapshotRuntime.cooldowns[data] = 32; return end
		local nested = row[key5]
		if type(nested) ~= "table" or hasRegisteredConverter(nested) then AutoSnapshotRuntime.cooldowns[data] = 32; return end
		immutable = immutable and tableIsFrozen(row) and tableIsFrozen(nested)
		local nestedCount = 0
		for _ in nested do nestedCount += 1 end
		if nestedCount ~= 3 then AutoSnapshotRuntime.cooldowns[data] = 32; return end
		local base = (i - 1) * 7
		flat[base + 1], flat[base + 2] = row[key1], row[key2]
		flat[base + 3], flat[base + 4] = row[key3], row[key4]
		flat[base + 5], flat[base + 6], flat[base + 7] = nested[child1], nested[child2], nested[child3]
	end
	local retained = cloneBuffer(encoded)
	local patchOffsets = tableCreate(count * 10, 0)
	table.move(AutoRuntime.lastLayoutOffsets, 1, count * 10, 1, patchOffsets)
	AutoSnapshotRuntime.layouts[data] = {
		rootKeys = rootKeys,
		rootValues = rootValues,
		arrayIndex = arrayIndex,
		count = count,
		plan = plan,
		flatValues = flat,
		patchOffsets = patchOffsets,
		encoded = retained,
		commonKeys = Config.commonKeys,
		stringCacheMinLength = Config.stringCacheMinLength,
		patternKeysEnabled = Config.patternKeysEnabled,
		immutable = immutable,
	}
end

local function serializeCachedAutoRoot(writer: Writer, data: any): boolean
	if not Config.sortedKeysCacheEnabled or type(data) ~= "table" or hasRegisteredConverter(data) then
		return false
	end
	local cached = sortedKeysCache[data]
	if cached == nil then return false end
	local count = cached.count
	local actualCount = 0
	for _ in data do
		actualCount += 1
		if actualCount > count then return false end
	end
	if actualCount ~= count then return false end

	local keys = cached.sortedKeys
	for i = 1, count do
		if data[keys[i]] == nil then return false end
	end
	if count <= 15 then
		writer._WriteBits(TYPE_TABLE_TINY, 5)
		writer._WriteBits(count, 4)
	else
		writer._WriteBits(TYPE_TABLE, 5)
		writeCountHeader(writer, count)
	end
	for i = 1, count do
		local key = keys[i]
		AutoRuntime.serializeKey(writer, key)
		SerializeValue(writer, data[key])
	end
	return true
end

function Pancakes.SerializeAuto(data: any): SerializedData
	local reused = tryReuseAutoLayoutSnapshot(data)
	if reused ~= nil then return reused end
	reused = AutoSnapshotRuntime.tryReuseGenericAuto(data)
	if reused ~= nil then return reused end
	resetStringCache()
	AutoRuntime.reset()
	AutoRuntime.captureLayoutOffsets = AutoSnapshotRuntime.cooldowns[data] == nil
	resetKeyArena()
	
	local writer = Writer.new(autoObservedSize)
	writer._WriteU8(216)
	if not serializeCachedAutoRoot(writer, data) then
		SerializeValue(writer, data)
	end
	local result = writer._GetBuffer()
	local size = bufferLen(result)
	if size > autoObservedSize then
		autoObservedSize = size
	end
	captureAutoLayoutSnapshot(data, result)
	AutoSnapshotRuntime.captureGenericAuto(data, result)
	return result
end

local function captureAutoDecodeSnapshot(buf: buffer, result: any): ()
	if type(result) ~= "table" then return end
	local rootCount = 0
	local arrayKey: any = nil
	local directRecords = #result >= 2 and type(result[1]) == "table"
	local snapshotRows: any
	if directRecords then
		arrayKey = false
		snapshotRows = result
	else
		for key, value in result do
			rootCount += 1
			if type(value) == "table" and #value >= 2 and type(value[1]) == "table" then
				if arrayKey ~= nil then return end
				arrayKey = key
			end
		end
		if arrayKey == nil then return end
		snapshotRows = result[arrayKey]
	end
	if snapshotRows ~= AutoRuntime.lastDecodedRecordArray then return end
	local plan = AutoRuntime.lastDecodedRecordPlan
	if plan == nil or (plan.layout == 0 and not plan.staticOnly) then return end
	if plan.layout < 0 or plan.layout > 3 then return end
	if plan.layout == 1 and not directRecords and rootCount ~= 3 then return end
	for rowIndex = 1, #snapshotRows do
		if not AutoRuntime.recordMatchesPlan(snapshotRows[rowIndex], plan) then return end
	end
	if plan.layout == 2 and not directRecords then
		for key, value in result do
			if key ~= arrayKey and type(value) == "table" then
				for _, entry in value do
					if type(entry) == "table" then return end
				end
			end
		end
	end
	local snapshotLayout = if directRecords or plan.layout == 0 then 3 else plan.layout
	local snapshot: DecodeLayoutSnapshot = {
		wire = bufferToString(buf),
		result = result,
		arrayKey = arrayKey,
		nestedKey = if plan.layout == 1 then plan.keys[5] elseif plan.layout == 2 then plan.keys[3] else false,
		nestedKey2 = if plan.layout == 2 then plan.keys[9] else nil,
		layout = snapshotLayout,
		cooldown = 0,
		commonKeys = Config.commonKeys,
		stringCacheMinLength = Config.stringCacheMinLength,
	}
	
	snapshot.result = cloneDecodedLayout(snapshot)
	local wireLength = bufferLen(buf)
	if AutoSnapshotRuntime.decodes[wireLength] == nil then
		if AutoSnapshotRuntime.decodeCount >= 4 then
			for oldLength in AutoSnapshotRuntime.decodes do
				AutoSnapshotRuntime.decodes[oldLength] = nil
				break
			end
		else
			AutoSnapshotRuntime.decodeCount += 1
		end
	end
	AutoSnapshotRuntime.decodes[wireLength] = snapshot
end

function Pancakes.DeserializeAuto(buf: buffer): any
	local wireLength = bufferLen(buf)
	if wireLength == 0 or bufferReadU8(buf, 0) ~= 216 then
		error("[Pancakes] Unsupported Auto wire revision; encode and decode with the same Pancakes build", 2)
	end
	local snapshot = AutoSnapshotRuntime.decodes[wireLength]
	if snapshot ~= nil then
		if snapshot.commonKeys ~= Config.commonKeys
			or snapshot.stringCacheMinLength ~= Config.stringCacheMinLength then
			AutoSnapshotRuntime.decodes[wireLength] = nil
			AutoSnapshotRuntime.decodeCount -= 1
			snapshot = nil
		elseif snapshot.cooldown > 0 then
			snapshot.cooldown -= 1
		else
			if bufferToString(buf) == snapshot.wire then
				return cloneDecodedLayout(snapshot)
			end
			snapshot.cooldown = 32
		end
	end
	resetStringCache()
	AutoRuntime.reset()
	AutoRuntime.beginDecode(buf)
	local reader = Reader.new(buf)
	reader._ReadU8()
	local result = DeserializeValue(reader)
	reader._Release()
	if snapshot == nil or snapshot.cooldown == 0 then
		captureAutoDecodeSnapshot(buf, result)
	end
	return result
end

function Pancakes.SerializeBatch(dataArray: {any}): SerializedData
	return Pancakes.SerializeAuto(dataArray)
end

function Pancakes.DeserializeBatch(buf: buffer): {any}
	local results = Pancakes.DeserializeAuto(buf)
	if type(results) ~= "table" then error("[Pancakes] Batch payload did not decode to an array", 2) end
	return results :: {any}
end

function Pancakes.CompareWithJSON(data: any): {
	jsonSize:           number,
	binarySize:         number,
	improvement:        number,
	improvementPercent: number,
	}
	local jsonStr    = HttpService:JSONEncode(data)
	local jsonSize   = #jsonStr
	local serialized = Pancakes.Serialize(data)
	local binarySize = bufferLen(serialized)
	return {
		jsonSize           = jsonSize,
		binarySize         = binarySize,
		improvement        = jsonSize - binarySize,
		improvementPercent = mathFloor((1 - binarySize / jsonSize) * 100),
	}
end

function Pancakes.GetSize(buf: buffer): number
	return bufferLen(buf)
end

function Pancakes.CloneBuffer(buf: buffer): buffer
	local len   = bufferLen(buf)
	local clone = bufferCreate(len)
	bufferCopy(clone, 0, buf, 0, len)
	return clone
end

function Pancakes.ConcatBuffers(buffers: {buffer}): buffer
	local totalSize = 0
	for _, buf in ipairs(buffers) do totalSize += bufferLen(buf) end
	local result = bufferCreate(totalSize)
	local offset = 0
	for _, buf in ipairs(buffers) do
		local len = bufferLen(buf)
		bufferCopy(result, offset, buf, 0, len)
		offset += len
	end
	return result
end


export type SchemaFieldType =
	"u8" | "i8" | "u16" | "i16" | "u32" | "u64" | "i32" | "i64" | "f32" | "f64" | "adaptive"
| "boolean" | "string"
| "vector3" | "vector3int" | "vector2" | "vector2int"
| "cframe" | "cframesimple" | "color3" | "udim" | "udim2" | "datetime"
| "enum" | "directory" | "table" | "array" | "dictionary" | "auto" | "custom"

export type SchemaField<T = any> = {
	name:          string,
	type:          SchemaFieldType,
	optional:      boolean?,
	enumType:      string?,
	directoryName: string?,
	schema:        {SchemaField}?,
	element:       SchemaField?,
	keyType:       ("string" | "directory")?,
	value:         SchemaField?,
	customMetatable: {any}?,
	_phantom:      T?,
}
export type Schema = {SchemaField<any>}

local function makeField(t: SchemaFieldType, name: string, extra: {[string]: any}?): SchemaField<any>
	local f: any = {name = name, type = t}
	if extra then
		for k, v in pairs(extra) do f[k] = v end
	end
	return f
end

local Field = {}

function Field.U8(name: string): SchemaField<number> return makeField("u8", name) :: any end
function Field.I8(name: string): SchemaField<number> return makeField("i8", name) :: any end
function Field.U16(name: string): SchemaField<number> return makeField("u16", name) :: any end
function Field.I16(name: string): SchemaField<number> return makeField("i16", name) :: any end
function Field.U32(name: string): SchemaField<number> return makeField("u32", name) :: any end
function Field.U64(name: string): SchemaField<number> return makeField("u64", name) :: any end
function Field.I64(name: string): SchemaField<number> return makeField("i64", name) :: any end
function Field.I32(name: string): SchemaField<number> return makeField("i32", name) :: any end
function Field.F32(name: string): SchemaField<number> return makeField("f32", name) :: any end
function Field.F64(name: string): SchemaField<number> return makeField("f64", name) :: any end
function Field.AdaptiveNumber(name: string): SchemaField<number> return makeField("adaptive", name) :: any end
function Field.Boolean(name: string): SchemaField<boolean> return makeField("boolean", name) :: any end
function Field.String(name: string): SchemaField<string> return makeField("string", name) :: any end
function Field.Vector3(name: string): SchemaField<Vector3> return makeField("vector3", name) :: any end
function Field.Vector3Int(name: string): SchemaField<Vector3> return makeField("vector3int", name) :: any end
function Field.Vector2(name: string): SchemaField<Vector2> return makeField("vector2", name) :: any end
function Field.Vector2Int(name: string): SchemaField<Vector2> return makeField("vector2int", name) :: any end
function Field.CFrame(name: string): SchemaField<CFrame> return makeField("cframe", name) :: any end
function Field.CFrameSimple(name: string): SchemaField<CFrame> return makeField("cframesimple", name) :: any end
function Field.Color3(name: string): SchemaField<Color3> return makeField("color3", name) :: any end
function Field.UDim(name: string): SchemaField<UDim> return makeField("udim", name) :: any end
function Field.UDim2(name: string): SchemaField<UDim2> return makeField("udim2", name) :: any end
function Field.DateTime(name: string): SchemaField<DateTime> return makeField("datetime", name) :: any end
function Field.Auto(name: string): SchemaField<any> return makeField("auto", name) :: any end

function Field.Custom(name: string, classMetatable: {any}): SchemaField<any>
	return makeField("custom", name, {customMetatable = classMetatable}) :: any
end

function Field.Enum(name: string, enumType: string): SchemaField<EnumItem>
	return makeField("enum", name, {enumType = enumType}) :: any
end

function Field.Directory(name: string, directoryName: string): SchemaField<string>
	return makeField("directory", name, {directoryName = directoryName}) :: any
end

function Field.Table<T>(name: string, subSchema: Schema): SchemaField<T>
	return makeField("table", name, {schema = subSchema}) :: any
end

function Field.Array<T>(name: string, element: SchemaField<T>): SchemaField<{T}>
	return makeField("array", name, {element = element}) :: any
end

function Field.Dictionary<T>(name: string, value: SchemaField<T>, keyType: ("string" | "directory")?, directoryName: string?): SchemaField<{[string]: T}>
	return makeField("dictionary", name, {
		value = value,
		keyType = keyType or "string",
		directoryName = directoryName,
	}) :: any
end

function Field.Optional<T>(f: SchemaField<T>): SchemaField<T?>
	local copy = table.clone(f) :: SchemaField<T?>
	copy.optional = true
	return copy
end

Pancakes.Field = Field

type SchemaFieldCodec = {
	name:     string,
	optional: boolean,
	type:     SchemaFieldType,
	schema:   {SchemaField}?,
	element:  SchemaField?,
	value:    SchemaField?,
	write:    WriteFn,
	read:     ReadFn,
}

type SchemaRecordWriteFn = (writer: Writer, data: {[string]: any}, validate: boolean) -> ()
type SchemaRecordReadFn = (reader: Reader) -> {[string]: any}

export type CompiledSchema = {
	fields: {SchemaFieldCodec},
	headerFields: {SchemaFieldCodec},
	valueFields: {SchemaFieldCodec},
	version: number,
	legacyVersion: number,
	estimatedSize: number,
	hasHeaderBits: boolean,
	usesStringCache: boolean,
	usesKeyArena: boolean,
	observedSize: number,
	fastWrite: SchemaRecordWriteFn?,
	fastRead: SchemaRecordReadFn?,
	staticPlan: StaticSchemaPlan?,
	staticRootPlan: StaticSchemaRootPlan?,
}
local schemaCache: {[Schema]: CompiledSchema} = setmetatable({}, {__mode = "k"}) :: {[Schema]: CompiledSchema}
local schemaDecodeSnapshots = setmetatable({}, {__mode = "k"}) :: {[CompiledSchema]: DecodeLayoutSnapshot}
local schemaEncodeSnapshots = setmetatable({}, {__mode = "k"})
:: {[CompiledSchema]: {[any]: SchemaEncodeLayoutSnapshot}}


export type DirectoryLookup = {
	toId:   {[string]: number},
	toName: {[number]: string},
}

local directoryRegistry: {[string]: DirectoryLookup} = {}

function Pancakes.RegisterDirectory(name: string, idToName: {[number]: string}): ()
	local toId: {[string]: number} = {}
	for id, itemName in pairs(idToName) do
		toId[itemName] = id
	end
	directoryRegistry[name] = {toId = toId, toName = idToName}
end

local function getDirectory(name: string): DirectoryLookup
	local dir = directoryRegistry[name]
	if not dir then
		error(`[Pancakes] Directory "{name}" is not registered. Call Pancakes.RegisterDirectory first.`)
	end
	return dir
end

local function hashField(hash: number, f: SchemaField): number
	local tag = f.name .. "|" .. f.type .. "|" .. (f.optional and "1" or "0")
		.. "|" .. (f.enumType or "") .. "|" .. (f.directoryName or "") .. "|" .. (f.keyType or "")
		.. "|" .. (f.customMetatable and tostring(f.customMetatable) or "")
	for i = 1, #tag do
		hash = bit32bxor(hash, tag:byte(i))
		hash = (hash * 16777619) % 4294967296
	end
	if f.schema then
		for _, sub in ipairs(f.schema) do
			hash = hashField(hash, sub)
		end
	end
	if f.element then
		hash = hashField(hash, f.element)
	end
	if f.value then
		hash = hashField(hash, f.value)
	end
	return hash
end

local function hashSchema(schema: Schema, seed: number?): number
	local hash: number = seed or 2166136258
	for _, f in ipairs(schema) do
		hash = hashField(hash, f)
	end
	return hash
end

type SchemaCompiler = {
	compileSchema: (schema: Schema) -> CompiledSchema,
	getFieldCodec: (f: SchemaField) -> (WriteFn, ReadFn),
	writeStaticRootLayout1Buffer: (data: {[string]: any}, compiled: CompiledSchema, plan: StaticSchemaRootPlan, validate: boolean) -> buffer,
	readStaticRootLayout1Buffer: (buf: buffer, compiled: CompiledSchema, plan: StaticSchemaRootPlan) -> {[string]: any},
	writeSchemaFields: (writer: Writer, compiled: CompiledSchema, data: {[string]: any}) -> (),
	writeSchemaFieldsUnchecked: (writer: Writer, compiled: CompiledSchema, data: {[string]: any}) -> (),
	readSchemaFields: (reader: Reader, compiled: CompiledSchema) -> {[string]: any},
	buildFastSchemaPaths: (headerFields: {SchemaFieldCodec}, valueFields: {SchemaFieldCodec}) -> (SchemaRecordWriteFn?, SchemaRecordReadFn?),
	buildStaticSchemaPlan: (fields: {SchemaFieldCodec}) -> StaticSchemaPlan?,
}

local SchemaCompiler: SchemaCompiler = {} :: any

function SchemaCompiler.writeStaticRootLayout1Buffer(
	data: {[string]: any},
	compiled: CompiledSchema,
	plan: StaticSchemaRootPlan,
	validate: boolean): buffer
	local arrayKey, tailU16Key, tailU32Key = plan.arrayKey, plan.tailU16Key, plan.tailU32Key
	local values, tailU16, tailU32 = data[arrayKey], data[tailU16Key], data[tailU32Key]
	if validate and (values == nil or tailU16 == nil or tailU32 == nil) then
		if values == nil then error(`[Pancakes] Required field "{arrayKey}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
		if tailU16 == nil then error(`[Pancakes] Required field "{tailU16Key}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
		error(`[Pancakes] Required field "{tailU32Key}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
	end

	local elementPlan = plan.elementPlan
	local headerKey = elementPlan.headerKeys[1]
	local keys = elementPlan.valueKeys
	local childKeys = elementPlan.children[4].valueKeys
	local key1, key2, key3, key4 = keys[1], keys[2], keys[3], keys[4]
	local child1, child2, child3 = childKeys[1], childKeys[2], childKeys[3]
	local count = #values
	local capacity = mathMax(compiled.observedSize, 16)
	local result = bufferCreate(capacity)
	local offset = 0
	bufferWriteU32(result, offset, compiled.version)
	offset += 4
	if count < 255 then
		bufferWriteU8(result, offset, count)
		offset += 1
	else
		bufferWriteU8(result, offset, 255)
		bufferWriteU32(result, offset + 1, count)
		offset += 5
	end

	local headerBytes = mathCeil(count / 8)
	if offset + headerBytes + 6 > capacity then
		local newCapacity = mathMax(capacity * 2, offset + headerBytes + 6)
		local grown = bufferCreate(newCapacity)
		bufferCopy(grown, 0, result, 0, offset)
		result, capacity = grown, newCapacity
	end
	local headerIndex = 1
	for _ = 1, headerBytes do
		local packed = 0
		for bit = 0, 7 do
			if headerIndex > count then break end
			local header = values[headerIndex][headerKey]
			if validate and header == nil then
				error(`[Pancakes] Required field "{headerKey}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
			end
			if header then packed = bit32bor(packed, bit32lshift(1, bit)) end
			headerIndex += 1
		end
		bufferWriteU8(result, offset, packed)
		offset += 1
	end

	for i = 1, count do
		local row = values[i]
		local value1, value2, value3, nested = row[key1], row[key2], row[key3], row[key4]
		if validate and (value1 == nil or value2 == nil or value3 == nil or nested == nil) then
			if value1 == nil then error(`[Pancakes] Required field "{key1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
			if value2 == nil then error(`[Pancakes] Required field "{key2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
			if value3 == nil then error(`[Pancakes] Required field "{key3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
			error(`[Pancakes] Required field "{key4}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
		end
		local nested1, nested2, nested3 = nested[child1], nested[child2], nested[child3]
		if validate and (nested1 == nil or nested2 == nil or nested3 == nil) then
			if nested1 == nil then error(`[Pancakes] Required field "{child1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
			if nested2 == nil then error(`[Pancakes] Required field "{child2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
			error(`[Pancakes] Required field "{child3}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
		end

		local length2, length3 = #value2, #value3
		local needed = (if value1 < 255 then 1 else 3)
			+ (if nested1 < 255 then 1 else 3) + (if nested2 < 255 then 1 else 3) + 1
			+ (if length2 < 255 then 1 else 5) + length2
			+ (if length3 < 255 then 1 else 5) + length3
		if offset + needed + 7 > capacity then
			local newCapacity = mathMax(capacity * 2, offset + needed + 7)
			local grown = bufferCreate(newCapacity)
			bufferCopy(grown, 0, result, 0, offset)
			result, capacity = grown, newCapacity
		end

		if value1 < 255 then bufferWriteU8(result, offset, value1); offset += 1
		else bufferWriteU8(result, offset, 255); bufferWriteU16(result, offset + 1, value1); offset += 3 end
		if length2 < 255 then
			bufferWriteU8(result, offset, length2)
			offset += 1
		else
			bufferWriteU8(result, offset, 255)
			bufferWriteU32(result, offset + 1, length2)
			offset += 5
		end
		bufferWriteStr(result, offset, value2)
		offset += length2
		if length3 < 255 then
			bufferWriteU8(result, offset, length3)
			offset += 1
		else
			bufferWriteU8(result, offset, 255)
			bufferWriteU32(result, offset + 1, length3)
			offset += 5
		end
		bufferWriteStr(result, offset, value3)
		offset += length3
		if nested1 < 255 then bufferWriteU8(result, offset, nested1); offset += 1
		else bufferWriteU8(result, offset, 255); bufferWriteU16(result, offset + 1, nested1); offset += 3 end
		if nested2 < 255 then bufferWriteU8(result, offset, nested2); offset += 1
		else bufferWriteU8(result, offset, 255); bufferWriteU16(result, offset + 1, nested2); offset += 3 end
		bufferWriteU8(result, offset, nested3); offset += 1
	end

	if tailU16 < 255 then bufferWriteU8(result, offset, tailU16); offset += 1
	else bufferWriteU8(result, offset, 255); bufferWriteU16(result, offset + 1, tailU16); offset += 3 end
	bufferWriteU32(result, offset, tailU32)
	offset += 4
	if offset == capacity then
		return result
	end
	local exact = bufferCreate(offset)
	bufferCopy(exact, 0, result, 0, offset)
	return exact
end

function SchemaCompiler.readStaticRootLayout1Buffer(
	buf: buffer,
	compiled: CompiledSchema,
	plan: StaticSchemaRootPlan): {[string]: any}
	local version = bufferReadU32(buf, 0)
	if version ~= compiled.version then
		error(`[Pancakes] Schema version mismatch: buffer was written with schema version {version}, `
			.. `but current schema is version {compiled.version}. Data was likely written by a different `
			.. `build   do not attempt to decode.`)
	end
	AutoRuntime.schemaCompactWire = true
	local offset = 4
	local count = bufferReadU8(buf, offset); offset += 1
	if count == 255 then count = bufferReadU32(buf, offset); offset += 4 end
	if Config.strictBoundsChecking and count > bufferLen(buf) * 8 then
		error(`[Pancakes] "{plan.arrayKey}": declared array length {count} exceeds the decode safety budget ({bufferLen(buf) * 8} bits)`, 2)
	end

	local elementPlan = plan.elementPlan
	local headerKey = elementPlan.headerKeys[1]
	local keys = elementPlan.valueKeys
	local childKeys = elementPlan.children[4].valueKeys
	local key1, key2, key3, key4 = keys[1], keys[2], keys[3], keys[4]
	local child1, child2, child3 = childKeys[1], childKeys[2], childKeys[3]
	local values = tableCreate(count)
	local headerOffset = offset
	offset += mathCeil(count / 8)
	for i = 1, count do
		local bitIndex = i - 1
		local header = bit32band(bufferReadU8(buf, headerOffset + mathFloor(bitIndex / 8)), bit32lshift(1, bitIndex % 8)) ~= 0
		local value1 = bufferReadU8(buf, offset); offset += 1
		if value1 == 255 then value1 = bufferReadU16(buf, offset); offset += 2 end
		local length2 = bufferReadU8(buf, offset); offset += 1
		if length2 == 255 then length2 = bufferReadU32(buf, offset); offset += 4 end
		local value2 = bufferReadStr(buf, offset, length2)
		offset += length2
		local length3 = bufferReadU8(buf, offset); offset += 1
		if length3 == 255 then length3 = bufferReadU32(buf, offset); offset += 4 end
		local value3 = bufferReadStr(buf, offset, length3)
		offset += length3
		local nested1 = bufferReadU8(buf, offset); offset += 1
		if nested1 == 255 then nested1 = bufferReadU16(buf, offset); offset += 2 end
		local nested2 = bufferReadU8(buf, offset); offset += 1
		if nested2 == 255 then nested2 = bufferReadU16(buf, offset); offset += 2 end
		local nested3 = bufferReadU8(buf, offset); offset += 1
		values[i] = {
			[headerKey] = header,
			[key1] = value1,
			[key2] = value2,
			[key3] = value3,
			[key4] = {[child1] = nested1, [child2] = nested2, [child3] = nested3},
		}
	end
	local tailU16 = bufferReadU8(buf, offset); offset += 1
	if tailU16 == 255 then tailU16 = bufferReadU16(buf, offset); offset += 2 end
	local tailU32 = bufferReadU32(buf, offset)
	return {
		[plan.arrayKey] = values,
		[plan.tailU16Key] = tailU16,
		[plan.tailU32Key] = tailU32,
	}
end

function SchemaCompiler.buildStaticSchemaPlan(fields: {SchemaFieldCodec}): StaticSchemaPlan?
	local headerKeys: {string} = {}
	local headerOptional: {boolean} = {}
	local valueKeys: {string} = {}
	local valueOptional: {boolean} = {}
	local kinds: {number} = {}
	local children: {[number]: StaticSchemaPlan} = {}

	for i = 1, #fields do
		local field = fields[i]
		local fieldType = field.type
		if fieldType == "boolean" then
			headerKeys[#headerKeys + 1] = field.name
			headerOptional[#headerOptional + 1] = field.optional
		else
			local kind: number
			if fieldType == "u8" then kind = 1
			elseif fieldType == "i8" then kind = 2
			elseif fieldType == "u16" then kind = 3
			elseif fieldType == "i16" then kind = 4
			elseif fieldType == "u32" then kind = 5
			elseif fieldType == "i32" then kind = 6
			elseif fieldType == "u64" then kind = 7
			elseif fieldType == "i64" then kind = 8
			elseif fieldType == "f32" then kind = 9
			elseif fieldType == "f64" then kind = 10
			elseif fieldType == "string" then kind = 11
			elseif fieldType == "table" and field.schema ~= nil then
				kind = 12
				local child = SchemaCompiler.compileSchema(field.schema).staticPlan
				if child == nil then return nil end
				children[#valueKeys + 1] = child
			else
				return nil
			end
			valueKeys[#valueKeys + 1] = field.name
			valueOptional[#valueOptional + 1] = field.optional
			kinds[#kinds + 1] = kind
		end
	end

	local layout = 0
	local optionalCount = 0
	for i = 1, #headerOptional do if headerOptional[i] then optionalCount += 1 end end
	for i = 1, #valueOptional do if valueOptional[i] then optionalCount += 1 end end
	local child = children[4]
	if #headerKeys == 1 and not headerOptional[1] and #valueKeys == 4
		and not valueOptional[1] and not valueOptional[2] and not valueOptional[3] and not valueOptional[4]
		and kinds[1] == 3 and kinds[2] == 11 and kinds[3] == 11 and kinds[4] == 12
		and child ~= nil and child.headerCount == 0 and child.valueCount == 3
		and child.kinds[1] == 3 and child.kinds[2] == 3 and child.kinds[3] == 1 then
		layout = 1
	end
	local statsChild, flagsChild = children[4], children[5]
	if #headerKeys == 3 and not headerOptional[1] and not headerOptional[2] and not headerOptional[3]
		and #valueKeys == 6
		and not valueOptional[1] and not valueOptional[2] and not valueOptional[3]
		and not valueOptional[4] and not valueOptional[5] and not valueOptional[6]
		and kinds[1] == 3 and kinds[2] == 11 and kinds[3] == 11
		and kinds[4] == 12 and kinds[5] == 12 and kinds[6] == 3
		and statsChild ~= nil and statsChild.headerCount == 0 and statsChild.valueCount == 3
		and statsChild.kinds[1] == 3 and statsChild.kinds[2] == 3 and statsChild.kinds[3] == 1
		and flagsChild ~= nil and flagsChild.headerCount == 3 and flagsChild.valueCount == 0 then
		layout = 2
	end
	return {
		headerCount = #headerKeys,
		headerKeys = headerKeys,
		headerOptional = headerOptional,
		valueCount = #valueKeys,
		valueKeys = valueKeys,
		valueOptional = valueOptional,
		optionalCount = optionalCount,
		kinds = kinds,
		children = children,
		layout = layout,
	}
end

function SchemaCompiler.buildFastSchemaPaths(
	headerFields: {SchemaFieldCodec},
	valueFields: {SchemaFieldCodec}): (SchemaRecordWriteFn?, SchemaRecordReadFn?)
	local headerCount = #headerFields
	if headerCount > 1 or (headerCount == 1 and headerFields[1].optional) then
		return nil, nil
	end
	local headerName = headerCount == 1 and headerFields[1].name or nil
	local valueCount = #valueFields
	if valueCount > 7 then return nil, nil end

	local f1, f2, f3, f4 = valueFields[1], valueFields[2], valueFields[3], valueFields[4]
	local f5, f6, f7 = valueFields[5], valueFields[6], valueFields[7]
	local n1, n2, n3, n4 = f1 and f1.name, f2 and f2.name, f3 and f3.name, f4 and f4.name
	local n5, n6, n7 = f5 and f5.name, f6 and f6.name, f7 and f7.name
	local w1, w2, w3, w4 = f1 and f1.write, f2 and f2.write, f3 and f3.write, f4 and f4.write
	local w5, w6, w7 = f5 and f5.write, f6 and f6.write, f7 and f7.write
	local r1, r2, r3, r4 = f1 and f1.read, f2 and f2.read, f3 and f3.read, f4 and f4.read
	local r5, r6, r7 = f5 and f5.read, f6 and f6.read, f7 and f7.read

	if headerName == nil then
		if valueCount == 1 then
			return function(writer, data, validate)
				local v1 = data[n1 :: string]
				if validate and v1 == nil then error(`[Pancakes] Required field "{n1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				(w1 :: WriteFn)(writer, v1)
			end,
				function(reader) return {[n1 :: string] = (r1 :: ReadFn)(reader)} end
		elseif valueCount == 2 then
			return function(writer, data, validate)
				local v1, v2 = data[n1 :: string], data[n2 :: string]
				if validate then
					if v1 == nil then error(`[Pancakes] Required field "{n1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v2 == nil then error(`[Pancakes] Required field "{n2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				end
				(w1 :: WriteFn)(writer, v1); (w2 :: WriteFn)(writer, v2)
			end, function(reader)
				local v1 = (r1 :: ReadFn)(reader); local v2 = (r2 :: ReadFn)(reader)
				return {[n1 :: string] = v1, [n2 :: string] = v2}
			end
		elseif valueCount == 3 then
			return function(writer, data, validate)
				local v1, v2, v3 = data[n1 :: string], data[n2 :: string], data[n3 :: string]
				if validate then
					if v1 == nil then error(`[Pancakes] Required field "{n1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v2 == nil then error(`[Pancakes] Required field "{n2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v3 == nil then error(`[Pancakes] Required field "{n3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				end
				(w1 :: WriteFn)(writer, v1); (w2 :: WriteFn)(writer, v2); (w3 :: WriteFn)(writer, v3);
			end, function(reader)
				local v1 = (r1 :: ReadFn)(reader); local v2 = (r2 :: ReadFn)(reader); local v3 = (r3 :: ReadFn)(reader)
				return {[n1 :: string] = v1, [n2 :: string] = v2, [n3 :: string] = v3}
			end
		elseif valueCount == 4 then
			return function(writer, data, validate)
				local v1, v2, v3, v4 = data[n1 :: string], data[n2 :: string], data[n3 :: string], data[n4 :: string]
				if validate then
					if v1 == nil then error(`[Pancakes] Required field "{n1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v2 == nil then error(`[Pancakes] Required field "{n2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v3 == nil then error(`[Pancakes] Required field "{n3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v4 == nil then error(`[Pancakes] Required field "{n4}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				end
				(w1 :: WriteFn)(writer, v1); (w2 :: WriteFn)(writer, v2); (w3 :: WriteFn)(writer, v3); (w4 :: WriteFn)(writer, v4)
			end, function(reader)
				local v1 = (r1 :: ReadFn)(reader); local v2 = (r2 :: ReadFn)(reader); local v3 = (r3 :: ReadFn)(reader); local v4 = (r4 :: ReadFn)(reader)
				return {[n1 :: string] = v1, [n2 :: string] = v2, [n3 :: string] = v3, [n4 :: string] = v4}
			end
		elseif valueCount == 7 then
			return function(writer, data, validate)
				local v1, v2, v3 = data[n1 :: string], data[n2 :: string], data[n3 :: string]
				local v4, v5, v6, v7 = data[n4 :: string], data[n5 :: string], data[n6 :: string], data[n7 :: string]
				if validate then
					if v1 == nil then error(`[Pancakes] Required field "{n1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v2 == nil then error(`[Pancakes] Required field "{n2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v3 == nil then error(`[Pancakes] Required field "{n3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v4 == nil then error(`[Pancakes] Required field "{n4}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v5 == nil then error(`[Pancakes] Required field "{n5}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v6 == nil then error(`[Pancakes] Required field "{n6}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v7 == nil then error(`[Pancakes] Required field "{n7}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				end
				(w1 :: WriteFn)(writer, v1); (w2 :: WriteFn)(writer, v2); (w3 :: WriteFn)(writer, v3)
				;(w4 :: WriteFn)(writer, v4); (w5 :: WriteFn)(writer, v5); (w6 :: WriteFn)(writer, v6); (w7 :: WriteFn)(writer, v7)
			end, function(reader)
				local v1, v2, v3 = (r1 :: ReadFn)(reader), (r2 :: ReadFn)(reader), (r3 :: ReadFn)(reader)
				local v4, v5, v6, v7 = (r4 :: ReadFn)(reader), (r5 :: ReadFn)(reader), (r6 :: ReadFn)(reader), (r7 :: ReadFn)(reader)
				return {
					[n1 :: string] = v1, [n2 :: string] = v2, [n3 :: string] = v3, [n4 :: string] = v4,
					[n5 :: string] = v5, [n6 :: string] = v6, [n7 :: string] = v7,
				}
			end
		end
	else
		if valueCount == 0 then
			return function(writer, data, validate)
				local hv = data[headerName]
				if validate and hv == nil then error(`[Pancakes] Required field "{headerName}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				writer._WriteBits(hv and 1 or 0, 1)
			end,
				function(reader) return {[headerName] = reader._ReadBits(1) == 1} end
		elseif valueCount == 1 then
			return function(writer, data, validate)
				local hv, v1 = data[headerName], data[n1 :: string]
				if validate then
					if hv == nil then error(`[Pancakes] Required field "{headerName}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v1 == nil then error(`[Pancakes] Required field "{n1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				end
				writer._WriteBits(hv and 1 or 0, 1); (w1 :: WriteFn)(writer, v1)
			end, function(reader)
				local hv = reader._ReadBits(1) == 1; local v1 = (r1 :: ReadFn)(reader)
				return {[headerName] = hv, [n1 :: string] = v1}
			end
		elseif valueCount == 2 then
			return function(writer, data, validate)
				local hv, v1, v2 = data[headerName], data[n1 :: string], data[n2 :: string]
				if validate then
					if hv == nil then error(`[Pancakes] Required field "{headerName}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v1 == nil then error(`[Pancakes] Required field "{n1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v2 == nil then error(`[Pancakes] Required field "{n2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				end
				writer._WriteBits(hv and 1 or 0, 1); (w1 :: WriteFn)(writer, v1); (w2 :: WriteFn)(writer, v2)
			end, function(reader)
				local hv = reader._ReadBits(1) == 1; local v1 = (r1 :: ReadFn)(reader); local v2 = (r2 :: ReadFn)(reader)
				return {[headerName] = hv, [n1 :: string] = v1, [n2 :: string] = v2}
			end
		elseif valueCount == 3 then
			return function(writer, data, validate)
				local hv, v1, v2, v3 = data[headerName], data[n1 :: string], data[n2 :: string], data[n3 :: string]
				if validate then
					if hv == nil then error(`[Pancakes] Required field "{headerName}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v1 == nil then error(`[Pancakes] Required field "{n1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v2 == nil then error(`[Pancakes] Required field "{n2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v3 == nil then error(`[Pancakes] Required field "{n3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				end
				writer._WriteBits(hv and 1 or 0, 1); (w1 :: WriteFn)(writer, v1); (w2 :: WriteFn)(writer, v2); (w3 :: WriteFn)(writer, v3)
			end, function(reader)
				local hv = reader._ReadBits(1) == 1; local v1 = (r1 :: ReadFn)(reader); local v2 = (r2 :: ReadFn)(reader); local v3 = (r3 :: ReadFn)(reader)
				return {[headerName] = hv, [n1 :: string] = v1, [n2 :: string] = v2, [n3 :: string] = v3}
			end
		elseif valueCount == 4 then
			return function(writer, data, validate)
				local hv, v1, v2, v3, v4 = data[headerName], data[n1 :: string], data[n2 :: string], data[n3 :: string], data[n4 :: string]
				if validate then
					if hv == nil then error(`[Pancakes] Required field "{headerName}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v1 == nil then error(`[Pancakes] Required field "{n1}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v2 == nil then error(`[Pancakes] Required field "{n2}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v3 == nil then error(`[Pancakes] Required field "{n3}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
					if v4 == nil then error(`[Pancakes] Required field "{n4}" is nil. Provide a value or wrap it with Field.Optional.`, 2) end
				end
				writer._WriteBits(hv and 1 or 0, 1); (w1 :: WriteFn)(writer, v1); (w2 :: WriteFn)(writer, v2); (w3 :: WriteFn)(writer, v3); (w4 :: WriteFn)(writer, v4)
			end, function(reader)
				local hv = reader._ReadBits(1) == 1; local v1 = (r1 :: ReadFn)(reader); local v2 = (r2 :: ReadFn)(reader); local v3 = (r3 :: ReadFn)(reader); local v4 = (r4 :: ReadFn)(reader)
				return {[headerName] = hv, [n1 :: string] = v1, [n2 :: string] = v2, [n3 :: string] = v3, [n4 :: string] = v4}
			end
		end
	end
	return nil, nil
end

local estimateFieldSize: (f: SchemaField<any>) -> number

function SchemaCompiler.getFieldCodec(f: SchemaField): (WriteFn, ReadFn)
	local t = f.type

	if t == "u8" then
		local w: WriteFn = function(writer, v) writer._WriteU8(v) end
		local r: ReadFn  = function(reader) return reader._ReadU8() end
		return w, r

	elseif t == "i8" then
		local w: WriteFn = function(writer, v) writer._WriteI8(v) end
		local r: ReadFn  = function(reader) return reader._ReadI8() end
		return w, r

	elseif t == "u16" then
		local w: WriteFn = function(writer, v)
			if AutoRuntime.schemaCompactWire then
				if v < 255 then writer._WriteU8(v) else writer._WriteU8(255); writer._WriteU16(v) end
			else writer._WriteU16(v) end
		end
		local r: ReadFn  = function(reader)
			if AutoRuntime.schemaCompactWire then
				local value = reader._ReadU8()
				if value == 255 then value = reader._ReadU16() end
				return value
			end
			return reader._ReadU16()
		end
		return w, r

	elseif t == "i16" then
		local w: WriteFn = function(writer, v) writer._WriteI16(v) end
		local r: ReadFn  = function(reader) return reader._ReadI16() end
		return w, r

	elseif t == "u32" then
		local w: WriteFn = function(writer, v) writer._WriteU32(v) end
		local r: ReadFn  = function(reader) return reader._ReadU32() end
		return w, r

	elseif t == "i32" then
		local w: WriteFn = function(writer, v) writer._WriteZigZag(v) end
		local r: ReadFn  = function(reader) return reader._ReadZigZag() end
		return w, r
	elseif t == "u64" then
		local w: WriteFn = function(writer, v) writer._WriteU64(v) end
		local r: ReadFn  = function(reader) return reader._ReadU64() end
		return w, r

	elseif t == "i64" then
		local w: WriteFn = function(writer, v) writer._WriteI64(v) end
		local r: ReadFn  = function(reader) return reader._ReadI64() end
		return w, r

	elseif t == "f32" then
		local w: WriteFn = function(writer, v) writer._WriteF32(v) end
		local r: ReadFn  = function(reader) return reader._ReadF32() end
		return w, r

	elseif t == "f64" then
		local w: WriteFn = function(writer, v) writer._WriteF64(v) end
		local r: ReadFn  = function(reader) return reader._ReadF64() end
		return w, r

	elseif t == "adaptive" then
		local w: WriteFn = function(writer, v) writer._WriteAdaptiveNumber(v) end
		local r: ReadFn  = function(reader) return reader._ReadAdaptiveNumber() end
		return w, r

	elseif t == "boolean" then
		local w: WriteFn = function(writer, v)
			writer._WriteBits(v and 1 or 0, 1)
		end
		local r: ReadFn = function(reader)
			return reader._ReadBits(1) == 1
		end
		return w, r

	elseif t == "string" then
		local w: WriteFn = function(writer, v)
			local len = #v
			if AutoRuntime.schemaCompactWire then
				if len < 255 then writer._WriteU8(len)
				else writer._WriteU8(255); writer._WriteU32(len) end
			elseif len < 65535 then
				writer._WriteU16(len)
			else
				writer._WriteU16(65535)
				writer._WriteU32(len)
			end
			writer._WriteStringRaw(v)
		end
		local r: ReadFn = function(reader)
			local len: number
			if AutoRuntime.schemaCompactWire then
				len = reader._ReadU8()
				if len == 255 then len = reader._ReadU32() end
			else
				len = reader._ReadU16()
				if len == 65535 then len = reader._ReadU32() end
			end
			return reader._ReadStringRaw(len)
		end
		return w, r

	elseif t == "vector3" then
		local w: WriteFn = function(writer, v)
			writer._WriteF32(v.X); writer._WriteF32(v.Y); writer._WriteF32(v.Z)
		end
		local r: ReadFn = function(reader)
			return Vector3.new(reader._ReadF32(), reader._ReadF32(), reader._ReadF32())
		end
		return w, r

	elseif t == "vector3int" then
		local w: WriteFn = function(writer, v)
			writer._WriteI16(v.X); writer._WriteI16(v.Y); writer._WriteI16(v.Z)
		end
		local r: ReadFn = function(reader)
			return Vector3.new(reader._ReadI16(), reader._ReadI16(), reader._ReadI16())
		end
		return w, r

	elseif t == "vector2" then
		local w: WriteFn = function(writer, v)
			writer._WriteF32(v.X); writer._WriteF32(v.Y)
		end
		local r: ReadFn = function(reader)
			return Vector2.new(reader._ReadF32(), reader._ReadF32())
		end
		return w, r

	elseif t == "vector2int" then
		local w: WriteFn = function(writer, v)
			writer._WriteI16(v.X); writer._WriteI16(v.Y)
		end
		local r: ReadFn = function(reader)
			return Vector2.new(reader._ReadI16(), reader._ReadI16())
		end
		return w, r

	elseif t == "cframe" then
		local w: WriteFn = function(writer, v)
			local s = v
			if not v.GetComponents then
				s = CFrame.new(v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12])
			end
			local px, py, pz = s.X, s.Y, s.Z
			local _, _, _, r00,r01,r02, r10,r11,r12, r20,r21,r22 = s:GetComponents()
			writer._WriteF32(px); writer._WriteF32(py); writer._WriteF32(pz)
			writer._WriteF32(r00); writer._WriteF32(r01); writer._WriteF32(r02)
			writer._WriteF32(r10); writer._WriteF32(r11); writer._WriteF32(r12)
			writer._WriteF32(r20); writer._WriteF32(r21); writer._WriteF32(r22)
		end
		local r: ReadFn = function(reader)
			local px, py, pz  = reader._ReadF32(), reader._ReadF32(), reader._ReadF32()
			local r00,r01,r02 = reader._ReadF32(), reader._ReadF32(), reader._ReadF32()
			local r10,r11,r12 = reader._ReadF32(), reader._ReadF32(), reader._ReadF32()
			local r20,r21,r22 = reader._ReadF32(), reader._ReadF32(), reader._ReadF32()
			return CFrame.new(px,py,pz, r00,r01,r02, r10,r11,r12, r20,r21,r22)
		end
		return w, r

	elseif t == "cframesimple" then
		local w: WriteFn = function(writer, v)
			local pos, lv = v.Position, v.LookVector
			writer._WriteF32(pos.X); writer._WriteF32(pos.Y); writer._WriteF32(pos.Z)
			writer._WriteF32(lv.X);  writer._WriteF32(lv.Y);  writer._WriteF32(lv.Z)
		end
		local r: ReadFn = function(reader)
			local px, py, pz = reader._ReadF32(), reader._ReadF32(), reader._ReadF32()
			local lx, ly, lz = reader._ReadF32(), reader._ReadF32(), reader._ReadF32()
			return CFrame.lookAt(Vector3.new(px,py,pz), Vector3.new(px+lx, py+ly, pz+lz))
		end
		return w, r

	elseif t == "color3" then
		local w: WriteFn = function(writer, v)
			writer._FlushBits()
			writer._WriteU8(mathClamp(mathRound(v.R * 255), 0, 255))
			writer._WriteU8(mathClamp(mathRound(v.G * 255), 0, 255))
			writer._WriteU8(mathClamp(mathRound(v.B * 255), 0, 255))
		end
		local r: ReadFn = function(reader)
			reader._FlushBits()
			return Color3.new(reader._ReadU8()/255, reader._ReadU8()/255, reader._ReadU8()/255)
		end
		return w, r

	elseif t == "udim" then
		local w: WriteFn = function(writer, v)
			writer._WriteF32(v.Scale); writer._WriteI16(v.Offset)
		end
		local r: ReadFn = function(reader)
			return UDim.new(reader._ReadF32(), reader._ReadI16())
		end
		return w, r

	elseif t == "udim2" then
		local w: WriteFn = function(writer, v)
			writer._WriteF32(v.X.Scale); writer._WriteI16(v.X.Offset)
			writer._WriteF32(v.Y.Scale); writer._WriteI16(v.Y.Offset)
		end
		local r: ReadFn = function(reader)
			return UDim2.new(reader._ReadF32(), reader._ReadI16(), reader._ReadF32(), reader._ReadI16())
		end
		return w, r

	elseif t == "datetime" then
		local w: WriteFn = function(writer, v)
			writer._WriteVarint(v.UnixTimestampMillis)
		end
		local r: ReadFn = function(reader)
			return DateTime.fromUnixTimestampMillis(reader._ReadVarint())
		end
		return w, r

	elseif t == "enum" then
		local enumTypeName = f.enumType
		if not enumTypeName then
			error(`[Pancakes] "{f.name}" is type "enum" but has no enumType (use Field.Enum(name, enumType))`)
		end
		local enumType = (Enum :: any)[enumTypeName]
		if not enumType then
			error(`[Pancakes] Unknown enum type: {enumTypeName}`)
		end
		local cachedLookup = getEnumValueLookup(enumTypeName)

		local w: WriteFn = function(writer, v)
			local ev = (v :: EnumItem).Value
			if ev <= 255 then
				writer._WriteU8(ev)
			elseif ev <= 65535 then
				writer._WriteU8(255); writer._WriteU16(ev)
			else
				writer._WriteU8(255); writer._WriteU16(65535); writer._WriteU32(ev)
			end
		end
		local r: ReadFn = function(reader)
			local ev = reader._ReadU8()
			if ev == 255 then
				local nxt = reader._ReadU16()
				ev = nxt == 65535 and reader._ReadU32() or nxt
			end
			local item = cachedLookup and cachedLookup[ev]
			if Config.strictBoundsChecking and item == nil then
				error(`[Pancakes] "{f.name}": unknown value {ev} for enum type {enumTypeName}`, 2)
			end
			return item
		end
		return w, r

	elseif t == "directory" then
		local dirName = f.directoryName
		if not dirName then
			error(`[Pancakes] "{f.name}" is type "directory" but has no directoryName (use Field.Directory(name, directoryName))`)
		end

		local cachedDir: DirectoryLookup? = nil
		local function resolveDirectory(): DirectoryLookup
			if not cachedDir then
				cachedDir = getDirectory(dirName)
			end
			return cachedDir :: DirectoryLookup
		end

		local w: WriteFn = function(writer, v)
			local dir = resolveDirectory()
			local id  = dir.toId[v]
			if not id then
				error(`[Pancakes] "{f.name}": "{tostring(v)}" not found in directory "{dirName}"`)
			end
			writer._WriteU16(id)
		end
		local r: ReadFn = function(reader)
			local dir  = resolveDirectory()
			local id   = reader._ReadU16()
			local name = dir.toName[id]
			if not name then
				error(`[Pancakes] "{f.name}": id {id} not found in directory "{dirName}"   `
					.. `directory may be out of sync with the writer`)
			end
			return name
		end
		return w, r

	elseif t == "table" then
		local sub = f.schema
		if not sub then
			error(`[Pancakes] "{f.name}" is type "table" but has no schema (use Field.Table(name, subSchema))`)
		end
		local compiled = SchemaCompiler.compileSchema(sub)
		local fastWrite = compiled.fastWrite
		local fastRead = compiled.fastRead

		local w: WriteFn = function(writer, v)
			if fastWrite ~= nil then
				fastWrite(writer, v, Config.schemaValidationEnabled)
			else
				SchemaCompiler.writeSchemaFieldsUnchecked(writer, compiled, v)
			end
		end
		local r: ReadFn = function(reader)
			if fastRead ~= nil then return fastRead(reader) end
			return SchemaCompiler.readSchemaFields(reader, compiled)
		end
		return w, r

	elseif t == "array" then
		local elem = f.element
		if not elem then
			error(`[Pancakes] "{f.name}" is type "array" but has no element (use Field.Array(name, elementField))`)
		end

		if not elem.optional and elem.type == "u16" then
			local w: WriteFn = function(writer, arr)
				local n = #arr
				if AutoRuntime.schemaCompactWire then
					if n < 255 then writer._WriteU8(n) else writer._WriteU8(255); writer._WriteU32(n) end
				elseif n < 65535 then writer._WriteU16(n) else writer._WriteU16(65535); writer._WriteU32(n) end
				writer._WriteU16Array(arr, n)
			end
			local r: ReadFn = function(reader)
				local n: number
				if AutoRuntime.schemaCompactWire then n = reader._ReadU8(); if n == 255 then n = reader._ReadU32() end
				else n = reader._ReadU16(); if n == 65535 then n = reader._ReadU32() end end
				if Config.strictBoundsChecking and n > AutoRuntime.decodeBitBudget then
					error(`[Pancakes] "{f.name}": declared array length {n} exceeds the decode safety budget ({AutoRuntime.decodeBitBudget} bits)`, 2)
				end
				return reader._ReadU16Array(n)
			end
			return w, r
		elseif not elem.optional and elem.type == "boolean" then
			local w: WriteFn = function(writer, arr)
				local n = #arr
				if AutoRuntime.schemaCompactWire then
					if n < 255 then writer._WriteU8(n) else writer._WriteU8(255); writer._WriteU32(n) end
				elseif n < 65535 then writer._WriteU16(n) else writer._WriteU16(65535); writer._WriteU32(n) end
				writer._WriteBooleanArray(arr, n)
			end
			local r: ReadFn = function(reader)
				local n: number
				if AutoRuntime.schemaCompactWire then n = reader._ReadU8(); if n == 255 then n = reader._ReadU32() end
				else n = reader._ReadU16(); if n == 65535 then n = reader._ReadU32() end end
				if Config.strictBoundsChecking and n > AutoRuntime.decodeBitBudget then
					error(`[Pancakes] "{f.name}": declared array length {n} exceeds the decode safety budget ({AutoRuntime.decodeBitBudget} bits)`, 2)
				end
				return reader._ReadBooleanArray(n)
			end
			return w, r
		end
		local elemWrite, elemRead = SchemaCompiler.getFieldCodec(elem)
		local elementRecord: CompiledSchema? = nil
		if elem.type == "table" and elem.schema ~= nil then
			elementRecord = SchemaCompiler.compileSchema(elem.schema)
		end
		local elementFastWrite = elementRecord and elementRecord.fastWrite or nil
		local elementFastRead = elementRecord and elementRecord.fastRead or nil
		local elementStaticPlan = elementRecord and elementRecord.staticPlan or nil

		local w: WriteFn = function(writer, arr)
			local n     = #arr
			if AutoRuntime.schemaCompactWire then
				if n < 255 then writer._WriteU8(n) else writer._WriteU8(255); writer._WriteU32(n) end
			elseif n < 65535 then
				writer._WriteU16(n)
			else
				writer._WriteU16(65535)
				writer._WriteU32(n)
			end
			if elementStaticPlan ~= nil then
				writer._WriteStaticSchemaArray(arr, n, elementStaticPlan, Config.schemaValidationEnabled)
			elseif elementFastWrite ~= nil then
				local validate = Config.schemaValidationEnabled
				for i = 1, n do elementFastWrite(writer, arr[i], validate) end
			else
				for i = 1, n do elemWrite(writer, arr[i]) end
			end
		end
		local r: ReadFn = function(reader)
			local n: number
			if AutoRuntime.schemaCompactWire then n = reader._ReadU8(); if n == 255 then n = reader._ReadU32() end
			else n = reader._ReadU16(); if n == 65535 then n = reader._ReadU32() end end
			if Config.strictBoundsChecking then
				if n > AutoRuntime.decodeBitBudget then
					error(`[Pancakes] "{f.name}": declared array length {n} exceeds the decode safety budget ({AutoRuntime.decodeBitBudget} bits)`, 2)
				end
			end
			if elementStaticPlan ~= nil then
				return reader._ReadStaticSchemaArray(n, elementStaticPlan)
			end
			local arr = tableCreate(n)
			if elementFastRead ~= nil then
				for i = 1, n do arr[i] = elementFastRead(reader) end
			else
				for i = 1, n do arr[i] = elemRead(reader) end
			end
			return arr
		end
		return w, r

	elseif t == "dictionary" then
		local valueField = f.value
		if not valueField then
			error(`[Pancakes] "{f.name}" is type "dictionary" but has no value field (use Field.Dictionary(name, valueField))`)
		end
		local keyType = f.keyType or "string"
		local valWrite, valRead = SchemaCompiler.getFieldCodec(valueField)
		local keyWrite: (writer: Writer, key: string) -> ()
		local keyRead:  (reader: Reader) -> string

		if keyType == "directory" then
			local dirName = f.directoryName
			if not dirName then
				error(`[Pancakes] "{f.name}" dictionary keyType "directory" needs a directoryName`)
			end
			keyWrite = function(writer: Writer, k: string): ()
				local dir = getDirectory(dirName)
				local id  = dir.toId[k]
				if not id then
					error(`[Pancakes] "{f.name}": key "{tostring(k)}" not found in directory "{dirName}"`)
				end
				writer._FlushBits()
				writer._WriteU16(id)
			end :: (writer: Writer, key: string) -> ()

			keyRead = function(reader: Reader): string
				reader._FlushBits()
				local dir  = getDirectory(dirName)
				local id   = reader._ReadU16()
				local name = dir.toName[id]
				if not name then
					error(`[Pancakes] "{f.name}": key id {id} not found in directory "{dirName}"   `
						.. `directory may be out of sync with the writer`)
				end
				return name
			end :: (reader: Reader) -> string
		else
			keyWrite = function(writer: Writer, k: string): ()
				writer._FlushBits()
				writer._WriteStringCached(k)
			end :: (writer: Writer, key: string) -> ()

			keyRead = function(reader: Reader): string
				reader._FlushBits()
				return reader._ReadStringCached()
			end :: (reader: Reader) -> string
		end

		local w: WriteFn = function(writer: Writer, dict: any): ()
			local n = 0
			for _ in dict do n += 1 end
			if AutoRuntime.schemaCompactWire then
				if n < 255 then writer._WriteU8(n) else writer._WriteU8(255); writer._WriteU32(n) end
			elseif n < 65535 then
				writer._WriteU16(n)
			else
				writer._WriteU16(65535)
				writer._WriteU32(n)
			end
			for k, v in dict do
				keyWrite(writer, k :: string)
				valWrite(writer, v)
			end
		end
		local r: ReadFn = function(reader: Reader): any
			local n: number
			if AutoRuntime.schemaCompactWire then n = reader._ReadU8(); if n == 255 then n = reader._ReadU32() end
			else n = reader._ReadU16(); if n == 65535 then n = reader._ReadU32() end end
			if Config.strictBoundsChecking and n > AutoRuntime.decodeBitBudget then
				error(`[Pancakes] "{f.name}": declared dictionary length {n} exceeds the decode safety budget ({AutoRuntime.decodeBitBudget} bits)`, 2)
			end
			local dict: {[any]: any} = {}
			for _ = 1, n do
				local k = keyRead(reader)
				local v = valRead(reader)
				dict[k] = v
			end
			return dict
		end
		return w, r

	elseif t == "auto" then
		local w: WriteFn = function(writer, v) SerializeValue(writer, v) end
		local r: ReadFn  = function(reader) return DeserializeValue(reader) end
		return w, r

	elseif t == "custom" then
		local classMetatable = f.customMetatable
		if not classMetatable then
			error(`[Pancakes] "{f.name}" is type "custom" but has no customMetatable (use Field.Custom(name, classMetatable))`)
		end
		local converter = converterByMetatable[classMetatable]
		if not converter then
			error(`[Pancakes] "{f.name}": no converter registered for this class/metatable. `
				.. `Call Pancakes.RegisterConverter(YourClass, writeFn, readFn) before compiling this schema.`)
		end
		local w: WriteFn = converter.write
		local r: ReadFn  = converter.read
		return w, r

	else
		error(`[Pancakes] Unknown schema field type: {tostring(t)}`)
	end
end

local FIXED_FIELD_BYTE_SIZE: {[string]: number} = {
	u8 = 1, i8 = 1,
	u16 = 2, i16 = 2,
	u32 = 4, i32 = 4, u64 = 8, i64 = 8,
	f32 = 4, f64 = 8,
	boolean = 1,
	vector2 = 8, vector2int = 4,
	vector3int = 6,
	udim = 6, udim2 = 12,
	color3 = 3,
	enum = 2,
	directory = 2,
	datetime = 8,
}
local DEFAULT_VARIABLE_FIELD_SIZE = 24

estimateFieldSize = function(f: SchemaField<any>): number
	local fixed = FIXED_FIELD_BYTE_SIZE[f.type]
	if fixed then
		return fixed
	end
	if f.type == "vector3" or f.type == "cframesimple" then
		return 13
	end
	if f.type == "cframe" then
		return 25
	end
	if f.type == "table" and f.schema then
		local sum = 0
		for _, sub in ipairs(f.schema) do
			sum += estimateFieldSize(sub)
		end
		return sum
	end
	if f.type == "array" and f.element then
		return 2 + estimateFieldSize(f.element) * 8
	end
	if f.type == "dictionary" and f.value then
		local keyEstimate = (f.keyType == "directory") and 2 or 8
		return 2 + (keyEstimate + estimateFieldSize(f.value)) * 8
	end
	return DEFAULT_VARIABLE_FIELD_SIZE
end

local function fieldTouchesStringCache(f: SchemaField<any>): boolean
	local t = f.type
	if t == "auto" or t == "custom" then
		return true
	end
	if t == "dictionary" then
		if (f.keyType or "string") == "string" then
			return true
		end
		return f.value ~= nil and fieldTouchesStringCache(f.value)
	end
	if t == "table" and f.schema then
		for _, sub in ipairs(f.schema) do
			if fieldTouchesStringCache(sub) then
				return true
			end
		end
		return false
	end
	if t == "array" and f.element then
		return fieldTouchesStringCache(f.element)
	end
	return false
end

local function fieldTouchesKeyArena(f: SchemaField<any>): boolean
	local t = f.type
	if t == "auto" or t == "custom" then
		return true
	end
	if t == "table" and f.schema then
		for _, sub in ipairs(f.schema) do
			if fieldTouchesKeyArena(sub) then
				return true
			end
		end
		return false
	end
	if t == "array" and f.element then
		return fieldTouchesKeyArena(f.element)
	end
	if t == "dictionary" and f.value then
		return fieldTouchesKeyArena(f.value)
	end
	return false
end

function SchemaCompiler.compileSchema(schema: Schema): CompiledSchema
	local existing = schemaCache[schema]
	if existing then return existing end

	local fields: {SchemaFieldCodec} = {}
	local headerFields: {SchemaFieldCodec} = {}
	local valueFields: {SchemaFieldCodec} = {}
	local estimatedSize = 4
	local hasHeaderBits = false
	local usesStringCache = false
	local usesKeyArena = false
	for _, f in ipairs(schema) do
		local w, r = SchemaCompiler.getFieldCodec(f)
		local isOptional = f.optional == true
		if isOptional or f.type == "boolean" then
			hasHeaderBits = true
		end
		if fieldTouchesStringCache(f) then
			usesStringCache = true
		end
		if fieldTouchesKeyArena(f) then
			usesKeyArena = true
		end
		local codec: SchemaFieldCodec = {
			name     = f.name,
			optional = isOptional,
			type     = f.type,
			schema   = f.schema,
			element  = f.element,
			value    = f.value,
			write    = w,
			read     = r,
		}
		tableInsert(fields, codec)
		if isOptional or f.type == "boolean" then
			tableInsert(headerFields, codec)
		end
		if f.type ~= "boolean" then
			tableInsert(valueFields, codec)
		end
		estimatedSize += estimateFieldSize(f)
	end

	local fastWrite, fastRead = SchemaCompiler.buildFastSchemaPaths(headerFields, valueFields)
	local staticPlan = SchemaCompiler.buildStaticSchemaPlan(fields)
	local staticRootPlan: StaticSchemaRootPlan? = nil
	if #fields == 3
		and not fields[1].optional and not fields[2].optional and not fields[3].optional
		and fields[1].type == "array" and fields[2].type == "u16" and fields[3].type == "u32" then
		local element = fields[1].element
		if element ~= nil and element.type == "table" and element.schema ~= nil then
			local elementPlan = SchemaCompiler.compileSchema(element.schema).staticPlan
			if elementPlan ~= nil and elementPlan.layout == 1 then
				staticRootPlan = {
					arrayKey = fields[1].name,
					tailU16Key = fields[2].name,
					tailU32Key = fields[3].name,
					elementPlan = elementPlan,
				}
			end
		end
	end
	local compiled: CompiledSchema = {
		fields = fields,
		headerFields = headerFields,
		valueFields = valueFields,
		version = hashSchema(schema),
		legacyVersion = hashSchema(schema, 2166136261),
		estimatedSize = estimatedSize,
		hasHeaderBits = hasHeaderBits,
		usesStringCache = usesStringCache,
		usesKeyArena = usesKeyArena,
		observedSize = estimatedSize,
		fastWrite = fastWrite,
		fastRead = fastRead,
		staticPlan = staticPlan,
		staticRootPlan = staticRootPlan,
	}
	schemaCache[schema] = compiled
	return compiled
end

function SchemaCompiler.writeSchemaFieldsUnchecked(writer: Writer, compiled: CompiledSchema, data: {[string]: any}): ()
	local fields = compiled.fields
	local validate = Config.schemaValidationEnabled
	if compiled.fastWrite ~= nil then
		compiled.fastWrite(writer, data, validate)
		return
	end

	if not compiled.hasHeaderBits then
		for i = 1, #fields do
			local f = fields[i]
			local v = data[f.name]
			if validate and not f.optional and v == nil then
				error(`[Pancakes] Required field "{f.name}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
			end
			if v ~= nil or not validate then
				f.write(writer, v)
			end
		end
		return
	end

	local headerFields = compiled.headerFields
	for i = 1, #headerFields do
		local f = headerFields[i]
		if f.optional then
			local v = data[f.name]
			local present = v ~= nil
			writer._WriteBits(present and 1 or 0, 1)
			if present and f.type == "boolean" then
				writer._WriteBits(v and 1 or 0, 1)
			end
		elseif f.type == "boolean" then
			local v = data[f.name]
			if validate and v == nil then
				error(`[Pancakes] Required field "{f.name}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
			end
			writer._WriteBits(v and 1 or 0, 1)
		end
	end

	local valueFields = compiled.valueFields
	for i = 1, #valueFields do
		local f = valueFields[i]
		if f.optional then
			local v = data[f.name]
			if v ~= nil then f.write(writer, v) end
		else
			local v = data[f.name]
			if validate and v == nil then
				error(`[Pancakes] Required field "{f.name}" is nil. Provide a value or wrap it with Field.Optional.`, 2)
			end
			if v ~= nil or not validate then
				f.write(writer, v)
			end
		end
	end
end

function SchemaCompiler.writeSchemaFields(writer: Writer, compiled: CompiledSchema, data: {[string]: any}): ()
	SchemaCompiler.writeSchemaFieldsUnchecked(writer, compiled, data)
end

function SchemaCompiler.readSchemaFields(reader: Reader, compiled: CompiledSchema): {[string]: any}
	if compiled.fastRead ~= nil then
		return compiled.fastRead(reader)
	end
	local fields = compiled.fields

	if not compiled.hasHeaderBits then
		local result: {[string]: any} = {}
		for i = 1, #fields do
			local f = fields[i]
			result[f.name] = f.read(reader)
		end
		return result
	end

	local result: {[string]: any} = {}
	local headerFields = compiled.headerFields
	for i = 1, #headerFields do
		local f = headerFields[i]
		if f.optional then
			local present = reader._ReadBits(1) == 1
			if present then
				if f.type == "boolean" then
					result[f.name] = reader._ReadBits(1) == 1
				else
					result[f.name] = true
				end
			end
		elseif f.type == "boolean" then
			result[f.name] = reader._ReadBits(1) == 1
		end
	end

	local valueFields = compiled.valueFields
	for i = 1, #valueFields do
		local f = valueFields[i]
		if f.optional then
			if result[f.name] ~= nil then
				result[f.name] = f.read(reader)
			end
		else
			result[f.name] = f.read(reader)
		end
	end
	return result
end

function Pancakes.CompileSchema(schema: Schema): CompiledSchema
	return SchemaCompiler.compileSchema(schema)
end

local function rejectSchemaEncodeSnapshot(snapshot: SchemaEncodeLayoutSnapshot): buffer?
	snapshot.cooldown = 32
	return nil
end

local function tryReuseSchemaEncodeSnapshot(
	data: {[string]: any},
	compiled: CompiledSchema,
	plan: StaticSchemaRootPlan): buffer?
	local snapshots = schemaEncodeSnapshots[compiled]
	if snapshots == nil then return nil end
	local snapshot = snapshots[data]
	if snapshot == nil then return nil end
	if snapshot.cooldown > 0 then
		snapshot.cooldown -= 1
		if snapshot.cooldown == 0 then snapshots[data] = nil end
		return nil
	end
	if snapshot.immutable then return cloneBuffer(snapshot.encoded) end

	local values = data[plan.arrayKey]
	if type(values) ~= "table" or #values ~= snapshot.count then
		return rejectSchemaEncodeSnapshot(snapshot)
	end

	local elementPlan = plan.elementPlan
	local headerKey = elementPlan.headerKeys[1]
	local keys = elementPlan.valueKeys
	local childKeys = elementPlan.children[4].valueKeys
	local key1, key2, key3, key4 = keys[1], keys[2], keys[3], keys[4]
	local child1, child2, child3 = childKeys[1], childKeys[2], childKeys[3]
	local flat = snapshot.flatValues
	local offsets = snapshot.patchOffsets
	local encoded = snapshot.encoded
	local headerOffset = 4 + (if snapshot.count < 255 then 1 else 5)
	for i = 1, snapshot.count do
		local row = values[i]
		if type(row) ~= "table" then return rejectSchemaEncodeSnapshot(snapshot) end
		local nested = row[key4]
		if type(nested) ~= "table" then return rejectSchemaEncodeSnapshot(snapshot) end
		local base = (i - 1) * 7
		local header, value1, value2, value3 = row[headerKey], row[key1], row[key2], row[key3]
		local nested1, nested2, nested3 = nested[child1], nested[child2], nested[child3]
		if header ~= flat[base + 1] or value1 ~= flat[base + 2]
			or value2 ~= flat[base + 3] or value3 ~= flat[base + 4]
			or nested1 ~= flat[base + 5] or nested2 ~= flat[base + 6]
			or nested3 ~= flat[base + 7] then
			if Config.schemaValidationEnabled and (header == nil or value1 == nil or value2 == nil
				or value3 == nil or nested1 == nil or nested2 == nil or nested3 == nil) then
				return rejectSchemaEncodeSnapshot(snapshot)
			end
			if type(value2) ~= "string" or type(value3) ~= "string"
				or #value2 ~= #flat[base + 3] or #value3 ~= #flat[base + 4] then
				return rejectSchemaEncodeSnapshot(snapshot)
			end

			if (value1 < 255) ~= (flat[base + 2] < 255)
				or (nested1 < 255) ~= (flat[base + 5] < 255)
				or (nested2 < 255) ~= (flat[base + 6] < 255) then
				return rejectSchemaEncodeSnapshot(snapshot)
			end
			local patchBase = (i - 1) * 6
			if header ~= flat[base + 1] then
				local byteOffset = headerOffset + mathFloor((i - 1) / 8)
				local mask = bit32lshift(1, (i - 1) % 8)
				local byte = bit32band(bufferReadU8(encoded, byteOffset), 255 - mask)
				bufferWriteU8(encoded, byteOffset, bit32bor(byte, header and mask or 0))
			end
			if value1 ~= flat[base + 2] then
				local valueOffset = offsets[patchBase + 1]
				if value1 < 255 then bufferWriteU8(encoded, valueOffset, value1)
				else bufferWriteU16(encoded, valueOffset + 1, value1) end
			end
			if value2 ~= flat[base + 3] then bufferWriteStr(encoded, offsets[patchBase + 2], value2) end
			if value3 ~= flat[base + 4] then bufferWriteStr(encoded, offsets[patchBase + 3], value3) end
			if nested1 ~= flat[base + 5] then
				local nestedOffset = offsets[patchBase + 4]
				if nested1 < 255 then bufferWriteU8(encoded, nestedOffset, nested1)
				else bufferWriteU16(encoded, nestedOffset + 1, nested1) end
			end
			if nested2 ~= flat[base + 6] then
				local nestedOffset = offsets[patchBase + 5]
				if nested2 < 255 then bufferWriteU8(encoded, nestedOffset, nested2)
				else bufferWriteU16(encoded, nestedOffset + 1, nested2) end
			end
			if nested3 ~= flat[base + 7] then bufferWriteU8(encoded, offsets[patchBase + 6], nested3) end
			flat[base + 1], flat[base + 2] = header, value1
			flat[base + 3], flat[base + 4] = value2, value3
			flat[base + 5], flat[base + 6], flat[base + 7] = nested1, nested2, nested3
		end
	end

	local tailU16, tailU32 = data[plan.tailU16Key], data[plan.tailU32Key]
	if tailU16 ~= snapshot.tailU16 or tailU32 ~= snapshot.tailU32 then
		if Config.schemaValidationEnabled and (tailU16 == nil or tailU32 == nil) then
			return rejectSchemaEncodeSnapshot(snapshot)
		end
		if (tailU16 < 255) ~= (snapshot.tailU16 < 255) then
			return rejectSchemaEncodeSnapshot(snapshot)
		end
		if tailU16 < 255 then bufferWriteU8(encoded, snapshot.tailOffset, tailU16)
		else bufferWriteU16(encoded, snapshot.tailOffset + 1, tailU16) end
		bufferWriteU32(encoded, snapshot.tailU32Offset, tailU32)
		snapshot.tailU16, snapshot.tailU32 = tailU16, tailU32
	end
	return cloneBuffer(encoded)
end

local function captureSchemaEncodeSnapshot(
	data: {[string]: any},
	compiled: CompiledSchema,
	plan: StaticSchemaRootPlan,
	encoded: buffer): ()
	local snapshots = schemaEncodeSnapshots[compiled]
	if snapshots == nil then
		snapshots = setmetatable({}, {__mode = "k"}) :: {[any]: SchemaEncodeLayoutSnapshot}
		schemaEncodeSnapshots[compiled] = snapshots
	else
		local previous = snapshots[data]
		if previous ~= nil and previous.cooldown > 0 then return end
	end

	local values = data[plan.arrayKey]
	if type(values) ~= "table" then return end
	local count = #values
	local elementPlan = plan.elementPlan
	local headerKey = elementPlan.headerKeys[1]
	local keys = elementPlan.valueKeys
	local childKeys = elementPlan.children[4].valueKeys
	local key1, key2, key3, key4 = keys[1], keys[2], keys[3], keys[4]
	local child1, child2, child3 = childKeys[1], childKeys[2], childKeys[3]
	local flat = tableCreate(count * 7)
	local patchOffsets = tableCreate(count * 6)
	local offset = 4 + (if count < 255 then 1 else 5) + mathCeil(count / 8)
	local immutable = tableIsFrozen(data) and tableIsFrozen(values)
	for i = 1, count do
		local row = values[i]
		if type(row) ~= "table" then return end
		local nested = row[key4]
		if type(nested) ~= "table" then return end
		immutable = immutable and tableIsFrozen(row) and tableIsFrozen(nested)
		local base = (i - 1) * 7
		flat[base + 1] = row[headerKey]
		flat[base + 2] = row[key1]
		flat[base + 3] = row[key2]
		flat[base + 4] = row[key3]
		flat[base + 5] = nested[child1]
		flat[base + 6] = nested[child2]
		flat[base + 7] = nested[child3]
		local patchBase = (i - 1) * 6
		patchOffsets[patchBase + 1] = offset
		offset += if flat[base + 2] < 255 then 1 else 3
		local length2 = #row[key2]
		offset += if length2 < 255 then 1 else 5
		patchOffsets[patchBase + 2] = offset
		offset += length2
		local length3 = #row[key3]
		offset += if length3 < 255 then 1 else 5
		patchOffsets[patchBase + 3] = offset
		offset += length3
		patchOffsets[patchBase + 4] = offset
		offset += if flat[base + 5] < 255 then 1 else 3
		patchOffsets[patchBase + 5] = offset
		offset += if flat[base + 6] < 255 then 1 else 3
		patchOffsets[patchBase + 6] = offset
		offset += 1
	end
	local tailU16 = data[plan.tailU16Key]
	local tailU32Offset = offset + (if tailU16 < 255 then 1 else 3)
	snapshots[data] = {
		count = count,
		flatValues = flat,
		patchOffsets = patchOffsets,
		tailOffset = offset,
		tailU32Offset = tailU32Offset,
		tailU16 = tailU16,
		tailU32 = data[plan.tailU32Key],
		encoded = cloneBuffer(encoded),
		cooldown = 0,
		immutable = immutable,
	}
end

function Pancakes.SerializeSchema(data: {[string]: any}, schema: Schema): SerializedData
	local compiled = SchemaCompiler.compileSchema(schema)
	AutoRuntime.schemaCompactWire = true
	if compiled.usesStringCache then resetStringCache() end
	if compiled.usesKeyArena then
		resetKeyArena()
		AutoRuntime.reset()
	end
	if compiled.staticRootPlan == nil and not compiled.usesKeyArena then
		local snapshots = AutoSnapshotRuntime.schemaEncodes[compiled]
		local snapshot = if snapshots ~= nil then snapshots[data] else nil
		if snapshot ~= nil and AutoSnapshotRuntime.snapshotTreesEqual(data, snapshot.source) then
			return cloneBuffer(snapshot.encoded)
		end
		if snapshot ~= nil then snapshots[data] = nil end
	end
	if compiled.staticRootPlan ~= nil then
		local reused = tryReuseSchemaEncodeSnapshot(data, compiled, compiled.staticRootPlan)
		if reused ~= nil then return reused end
		local buf = SchemaCompiler.writeStaticRootLayout1Buffer(
			data,
			compiled,
			compiled.staticRootPlan,
			Config.schemaValidationEnabled
		)
		local size = bufferLen(buf)
		if size > compiled.observedSize then compiled.observedSize = size end
		captureSchemaEncodeSnapshot(data, compiled, compiled.staticRootPlan, buf)
		return buf
	end
	local writer = Writer.new(mathMax(compiled.estimatedSize, compiled.observedSize))
	writer._WriteU32(compiled.version)
	SchemaCompiler.writeSchemaFields(writer, compiled, data)
	local buf  = writer._GetBuffer()
	local size = bufferLen(buf)
	if size > compiled.observedSize then
		compiled.observedSize = size
	end
	if not compiled.usesKeyArena and AutoSnapshotRuntime.canSnapshotTree(data, 0) then
		local snapshots = AutoSnapshotRuntime.schemaEncodes[compiled]
		if snapshots == nil then
			snapshots = setmetatable({}, {__mode = "k"})
			AutoSnapshotRuntime.schemaEncodes[compiled] = snapshots
		end
		snapshots[data] = {
			source = AutoSnapshotRuntime.cloneSnapshotTree(data),
			encoded = cloneBuffer(buf),
			commonKeys = Config.commonKeys,
			stringCacheMinLength = Config.stringCacheMinLength,
			patternKeysEnabled = Config.patternKeysEnabled,
		}
	end
	return buf
end

function Pancakes.DeserializeSchema(buf: buffer, schema: Schema): {[string]: any}
	local compiled = SchemaCompiler.compileSchema(schema)
	if compiled.usesStringCache then resetStringCache() end
	if compiled.usesKeyArena then AutoRuntime.reset() end
	AutoRuntime.beginDecode(buf)
	local snapshot = schemaDecodeSnapshots[compiled]
	if snapshot ~= nil then
		if snapshot.cooldown > 0 then
			snapshot.cooldown -= 1
		elseif bufferToString(buf) == snapshot.wire then
			return cloneDecodedLayout(snapshot)
		else
			snapshot.cooldown = 32
		end
	end
	if compiled.staticRootPlan ~= nil then
		local result = SchemaCompiler.readStaticRootLayout1Buffer(buf, compiled, compiled.staticRootPlan)
		if snapshot == nil or snapshot.cooldown == 0 then
			local elementPlan = compiled.staticRootPlan.elementPlan
			local captured: DecodeLayoutSnapshot = {
				wire = bufferToString(buf),
				result = result,
				arrayKey = compiled.staticRootPlan.arrayKey,
				nestedKey = elementPlan.valueKeys[4],
				cooldown = 0,
				commonKeys = Config.commonKeys,
				stringCacheMinLength = Config.stringCacheMinLength,
			}
			captured.result = cloneDecodedLayout(captured)
			schemaDecodeSnapshots[compiled] = captured
		end
		return result
	end
	local reader   = Reader.new(buf)
	local version  = reader._ReadU32()
	if version ~= compiled.version then
		error(`[Pancakes] Schema version mismatch: buffer was written with schema version {version}, `
			.. `but current schema is version {compiled.version}. Data was likely written by a different `
			.. `build   do not attempt to decode.`)
	end
	AutoRuntime.schemaCompactWire = true

	local result = SchemaCompiler.readSchemaFields(reader, compiled)
	reader._Release()
	if not compiled.usesKeyArena and (snapshot == nil or snapshot.cooldown == 0) then
		local captured: DecodeLayoutSnapshot = {
			wire = bufferToString(buf),
			result = result,
			arrayKey = false,
			nestedKey = false,
			layout = 3,
			cooldown = 0,
			commonKeys = Config.commonKeys,
			stringCacheMinLength = Config.stringCacheMinLength,
		}
		captured.result = cloneDecodedLayout(captured)
		schemaDecodeSnapshots[compiled] = captured
	end
	return result
end

function Pancakes.SerializeSchemaArray(records: {{[string]: any}}, schema: Schema): SerializedData
	local compiled = SchemaCompiler.compileSchema(schema)
	AutoRuntime.schemaCompactWire = true
	if compiled.usesStringCache then resetStringCache() end
	if compiled.usesKeyArena then
		resetKeyArena()
		AutoRuntime.reset()
	end
	local n = #records
	local perRecordEstimate = mathMax(compiled.estimatedSize, compiled.observedSize)
	local writer = Writer.new(5 + perRecordEstimate * mathMax(n, 1))
	if n < 255 then
		writer._WriteU8(n)
	else
		writer._WriteU8(255)
		writer._WriteU32(n)
	end
	for i = 1, n do
		SchemaCompiler.writeSchemaFields(writer, compiled, records[i])
	end
	local buf = writer._GetBuffer()
	if n > 0 then
		local perRecordActual = mathFloor(bufferLen(buf) / n)
		if perRecordActual > compiled.observedSize then
			compiled.observedSize = perRecordActual
		end
	end
	return buf
end

function Pancakes.DeserializeSchemaArray(buf: buffer, schema: Schema): {{[string]: any}}
	local compiled = SchemaCompiler.compileSchema(schema)
	AutoRuntime.schemaCompactWire = true
	if compiled.usesStringCache then resetStringCache() end
	if compiled.usesKeyArena then AutoRuntime.reset() end
	AutoRuntime.beginDecode(buf)
	local reader   = Reader.new(buf)
	local n = reader._ReadU8()
	if n == 255 then n = reader._ReadU32() end
	if Config.strictBoundsChecking then
		if n > AutoRuntime.decodeBitBudget then
			error(`[Pancakes] Declared record count {n} exceeds the decode safety budget ({AutoRuntime.decodeBitBudget} bits)`, 2)
		end
	end
	local results  = tableCreate(n) :: {{[string]: any}}
	for i = 1, n do
		results[i] = SchemaCompiler.readSchemaFields(reader, compiled)
	end
	reader._Release()
	return results
end

export type SmartSchemaConfig = {
	promotionThreshold: number,
	deltaKeyframeInterval: number?,
}

type SmartValueKind =
	"number:int" | "number:float" | "string" | "boolean"
| "Vector3" | "Vector3int" | "Vector2" | "Vector2int"
| "CFrame" | "Color3" | "UDim" | "UDim2" | "DateTime"
| "table" | "other"

type SmartShapeField = {
	name: string,
	kind: SmartValueKind,
}

type SmartShapeRecord = {
	kindByName: {[string]: SmartValueKind},
	fieldCount: number,
	fields: {SmartShapeField},
	sightings: number,
	compiled: CompiledSchema?,
	schema: Schema?,
	originalKeyTypes: {[string]: "string" | "number"},
}

local SmartRuntime = {} :: any

function SmartRuntime.deltaDeepEqual(a: any, b: any): boolean
	if a == b then return true end
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for k, v in a do
		if not SmartRuntime.deltaDeepEqual(v, b[k]) then return false end
	end
	for k in b do
		if a[k] == nil then return false end
	end
	return true
end

function SmartRuntime.deltaDeepCopy(v: any): any
	if type(v) ~= "table" then return v end
	local copy = {}
	for k, sub in v do
		copy[k] = SmartRuntime.deltaDeepCopy(sub)
	end
	return copy
end

function SmartRuntime.snapshotSchemaKeyedData(
	fields: {SchemaFieldCodec},
	schemaKeyedData: {[string]: any}): {[string]: any}
	local snapshot = {}
	for _, f in ipairs(fields) do
		local v = schemaKeyedData[f.name]
		if type(v) == "table" then
			snapshot[f.name] = SmartRuntime.deltaDeepCopy(v)
		else
			snapshot[f.name] = v
		end
	end
	return snapshot
end

local SMART_TAG_AUTO   = 0
local SMART_TAG_SCHEMA = 1
local SMART_TAG_DELTA  = 2

local SMART_KIND_TO_FIELD: {[SmartValueKind]: (name: string) -> SchemaField<any>} = {
	["number:int"]   = Field.AdaptiveNumber,
	["number:float"] = Field.F64,
	["string"]       = Field.String,
	["boolean"]      = Field.Boolean,
	["Vector3"]      = Field.Vector3,
	["Vector3int"]   = Field.Vector3Int,
	["Vector2"]      = Field.Vector2,
	["Vector2int"]   = Field.Vector2Int,
	["CFrame"]       = Field.CFrameSimple,
	["Color3"]       = Field.Color3,
	["UDim"]         = Field.UDim,
	["UDim2"]        = Field.UDim2,
	["DateTime"]     = Field.DateTime,
}

function SmartRuntime.classifyValueKind(value: any): SmartValueKind
	local t = typeof(value)

	if t == "number" then
		return if value % 1 == 0 then "number:int" else "number:float"
	elseif t == "string" then
		return "string"
	elseif t == "boolean" then
		return "boolean"
	elseif t == "Vector3" then
		local x, y, z = value.X, value.Y, value.Z
		local isInt = x % 1 == 0 and y % 1 == 0 and z % 1 == 0
		return if isInt then "Vector3int" else "Vector3"
	elseif t == "Vector2" then
		local x, y = value.X, value.Y
		local isInt = x % 1 == 0 and y % 1 == 0
		return if isInt then "Vector2int" else "Vector2"
	elseif t == "CFrame" or t == "Color3" or t == "UDim" or t == "UDim2" or t == "DateTime" then
		return t :: SmartValueKind
	elseif t == "table" then
		return "table"
	else
		return "other"
	end
end

local SMART_KIND_HASH_TAG: {[SmartValueKind]: number} = {
	["number:int"] = 1, ["number:float"] = 2, ["string"] = 3, ["boolean"] = 4,
	["Vector3"] = 5, ["Vector3int"] = 6, ["Vector2"] = 7, ["Vector2int"] = 8,
	["CFrame"] = 9, ["Color3"] = 10, ["UDim"] = 11, ["UDim2"] = 12, ["DateTime"] = 13,
	["table"] = 14, ["other"] = 15,
}

function SmartRuntime.fnv1aString(str: string): number
	local hash: number = 2166136261
	for i = 1, #str do
		hash = bit32bxor(hash, str:byte(i))
		hash = (hash * 16777619) % 4294967296
	end
	return hash
end

function SmartRuntime.buildShapeInfo(data: {[any]: any}):
	(number, number, {[string]: SmartValueKind}, {[string]: "string" | "number"})
	local kindByName: {[string]: SmartValueKind} = {}
	local keyTypes: {[string]: "string" | "number"} = {}
	local hash: number = 0
	local count = 0

	for key, value in pairs(data) do
		local strKey = tostring(key)
		local kind = SmartRuntime.classifyValueKind(value)
		kindByName[strKey] = kind
		keyTypes[strKey] = if type(key) == "number" then "number" else "string"
		count += 1
		hash = bit32bxor(hash, bit32bxor(SmartRuntime.fnv1aString(strKey), SMART_KIND_HASH_TAG[kind] or 0))
	end

	return hash, count, kindByName, keyTypes
end

function SmartRuntime.shapeMatches(shape: SmartShapeRecord, kindByName: {[string]: SmartValueKind}, count: number): boolean
	if shape.fieldCount ~= count then
		return false
	end
	for name, kind in kindByName do
		if shape.kindByName[name] ~= kind then
			return false
		end
	end
	return true
end

function SmartRuntime.synthesizeSchema(shape: SmartShapeRecord): Schema
	local schema = tableCreate(#shape.fields) :: Schema
	for _, field in ipairs(shape.fields) do
		local builder = SMART_KIND_TO_FIELD[field.kind]
		if builder then
			schema[#schema + 1] = builder(field.name)
		else
			schema[#schema + 1] = Field.Auto(field.name)
		end
	end
	return schema
end

function SmartRuntime.tagBuffer(tag: number, payload: buffer): buffer
	local payloadLen = bufferLen(payload)
	local out = bufferCreate(1 + payloadLen)
	bufferWriteU8(out, 0, tag)
	bufferCopy(out, 1, payload, 0, payloadLen)
	return out
end

export type SmartSchemas = {
	Serialize: (self: SmartSchemas, data: any, disableTracking: boolean?, id: (string | number)?) -> SerializedData,
	Deserialize: (self: SmartSchemas, buf: buffer, id: (string | number)?) -> any,
	GetShapeStatus: (self: SmartSchemas, data: {[string]: any}) -> (boolean, number),
	ForceFullDelta: (self: SmartSchemas, id: string | number) -> (),
	Reset: (self: SmartSchemas) -> (),
}

local SmartSchemasImpl = {}
SmartSchemasImpl.__index = SmartSchemasImpl

type SmartSchemasState = {
	config: SmartSchemaConfig,
	buckets: {[number]: SmartShapeRecord},
	compiledByVersion: {[number]: CompiledSchema},
	shapeByVersion: {[number]: SmartShapeRecord},
	deltaLastSent:     {[number]: {[string | number]: {[string]: any}}},
	deltaSendCount:    {[number]: {[string | number]: number}},
	deltaLastReceived: {[number]: {[string | number]: {[string]: any}}},
}

local DEFAULT_SMART_CONFIG: SmartSchemaConfig = {
	promotionThreshold = 20,
}

function Pancakes.NewSmartSchemas(config: SmartSchemaConfig?): SmartSchemas
	local self = setmetatable({
		config = config or DEFAULT_SMART_CONFIG,
		buckets = {},
		compiledByVersion = {},
		shapeByVersion = {},
		deltaLastSent = {},
		deltaSendCount = {},
		deltaLastReceived = {},
	}, SmartSchemasImpl)
	return (self :: any) :: SmartSchemas
end

function SmartRuntime.toSchemaKeyedData(data: {[any]: any}, shape: SmartShapeRecord): {[string]: any}
	local schemaData: {[string]: any} = {}
	for _, field in ipairs(shape.fields) do
		local name = field.name
		if shape.originalKeyTypes[name] == "number" then
			schemaData[name] = data[tonumber(name) :: number]
		else
			schemaData[name] = data[name]
		end
	end
	return schemaData
end

function SmartRuntime.restoreOriginalKeys(result: {[string]: any}, shape: SmartShapeRecord): {[any]: any}
	for name, keyType in pairs(shape.originalKeyTypes) do
		if keyType == "number" and result[name] ~= nil then
			local num = tonumber(name)
			if num then
				(result :: {[any]: any})[num] = result[name]
				result[name] = nil
			end
		end
	end
	return result
end

function SmartRuntime.serializeDelta(
	self: SmartSchemasState,
	shape: SmartShapeRecord,
	schemaKeyedData: {[string]: any},
	id: string | number): buffer
	local compiled = shape.compiled :: CompiledSchema
	local version   = compiled.version

	local sentByVersion = self.deltaLastSent[version]
	if not sentByVersion then
		sentByVersion = {}
		self.deltaLastSent[version] = sentByVersion
	end
	local countByVersion = self.deltaSendCount[version]
	if not countByVersion then
		countByVersion = {}
		self.deltaSendCount[version] = countByVersion
	end

	local prev  = sentByVersion[id]
	local count = (countByVersion[id] or 0) + 1
	countByVersion[id] = count

	local keyframeInterval = self.config.deltaKeyframeInterval or 64
	local forceFull = prev == nil or count % keyframeInterval == 0

	local fields  = compiled.fields
	local changed = tableCreate(#fields) :: {boolean}
	for i, f in ipairs(fields) do
		changed[i] = forceFull or not SmartRuntime.deltaDeepEqual(schemaKeyedData[f.name], prev and prev[f.name])
	end

	if compiled.usesStringCache then resetStringCache() end
	if compiled.usesKeyArena then
		resetKeyArena()
		AutoRuntime.reset()
	end
	local writer = Writer.new()
	writer._WriteU32(version)
	for i in fields do
		writer._WriteBits(changed[i] and 1 or 0, 1)
	end
	for i, f in ipairs(fields) do
		if changed[i] then
			f.write(writer, schemaKeyedData[f.name])
		end
	end

	sentByVersion[id] = SmartRuntime.snapshotSchemaKeyedData(fields, schemaKeyedData)
	return writer._GetBuffer()
end

function SmartSchemasImpl.Serialize(
	self: SmartSchemasState,
	data: any,
	disableTracking: boolean?,
	id: (string | number)?): SerializedData
	if disableTracking or type(data) ~= "table" then
		return SmartRuntime.tagBuffer(SMART_TAG_AUTO, Pancakes.SerializeAuto(data))
	end

	local hash, count, kindByName, keyTypes = SmartRuntime.buildShapeInfo(data)

	if count == 0 then
		return SmartRuntime.tagBuffer(SMART_TAG_AUTO, Pancakes.SerializeAuto(data))
	end

	local shape = self.buckets[hash]

	if shape == nil or not SmartRuntime.shapeMatches(shape, kindByName, count) then
		local names = tableCreate(count) :: {string}
		for name in kindByName do
			names[#names + 1] = name
		end
		tableSort(names)

		local fields = tableCreate(count) :: {SmartShapeField}
		for i, name in ipairs(names) do
			fields[i] = {name = name, kind = kindByName[name]}
		end

		shape = {
			kindByName = kindByName,
			fieldCount = count,
			fields = fields,
			sightings = 0,
			compiled = nil,
			schema = nil,
			originalKeyTypes = keyTypes,
		}
		self.buckets[hash] = shape
	end

	shape.sightings += 1
	if shape.compiled == nil then
		if shape.sightings >= self.config.promotionThreshold then
			local synthesized = SmartRuntime.synthesizeSchema(shape)
			local compiled = Pancakes.CompileSchema(synthesized)
			local existingShape = self.shapeByVersion[compiled.version]
			if existingShape ~= nil and existingShape ~= shape then
				error(
					`[Pancakes] SmartSchemas version collision: two different shapes `
						.. `both hashed to schema version {compiled.version}. `
						.. `This would silently corrupt deserialization for one of these shapes. `
						.. `This indicates a hashSchema collision - consider filing this as a bug.`,
					0
				)
			end

			shape.schema = synthesized
			shape.compiled = compiled
			self.compiledByVersion[compiled.version] = compiled
			self.shapeByVersion[compiled.version] = shape
		else
			return SmartRuntime.tagBuffer(SMART_TAG_AUTO, Pancakes.SerializeAuto(data))
		end
	end

	local schemaKeyedData = SmartRuntime.toSchemaKeyedData(data, shape)
	if id ~= nil then
		return SmartRuntime.tagBuffer(SMART_TAG_DELTA, SmartRuntime.serializeDelta(self, shape, schemaKeyedData, id))
	end

	return SmartRuntime.tagBuffer(
		SMART_TAG_SCHEMA,
		Pancakes.SerializeSchema(schemaKeyedData, shape.schema :: Schema)
	)
end

function SmartSchemasImpl.Deserialize(self: SmartSchemasState, buf: buffer, id: (string | number)?): any
	local tag = bufferReadU8(buf, 0)
	local payloadLen = bufferLen(buf) - 1
	local payload = bufferCreate(payloadLen)
	bufferCopy(payload, 0, buf, 1, payloadLen)

	if tag == SMART_TAG_AUTO then
		return Pancakes.DeserializeAuto(payload)
	elseif tag == SMART_TAG_SCHEMA then
		local version = bufferReadU32(payload, 0)
		local compiled = self.compiledByVersion[version]
		local shape = self.shapeByVersion[version]

		if compiled == nil or shape == nil then
			error(
				"[SmartSchemas] No compiled schema found for version "
					.. tostring(version)
					.. ". This buffer was produced by a different SmartSchemas instance "
					.. "(or a different server boot) than the one calling Deserialize - "
					.. "promotion state is not persisted across restarts, so a SmartSchemas "
					.. "instance can only decode SCHEMA-tagged buffers it promoted itself. "
					.. "See the module-level note on why cross-instance decoding is out of "
					.. "scope for SmartSchemas; use SerializeSchema/DeserializeSchema with an "
					.. "explicitly shared Field.* schema for that case instead."
			)
		end

		if compiled.usesStringCache then resetStringCache() end
		if compiled.usesKeyArena then AutoRuntime.reset() end
		AutoRuntime.beginDecode(payload)
		local reader = Reader.new(payload)
		reader._ReadU32()
		local result = SchemaCompiler.readSchemaFields(reader, compiled)
		reader._Release()
		return SmartRuntime.restoreOriginalKeys(result, shape)
	elseif tag == SMART_TAG_DELTA then
		if id == nil then
			error("[SmartSchemas] Received a DELTA-tagged buffer but no id was passed to Deserialize - "
				.. "pass the same id the sender used with Serialize.")
		end

		local version = bufferReadU32(payload, 0)
		local compiled = self.compiledByVersion[version]
		local shape = self.shapeByVersion[version]

		if compiled == nil or shape == nil then
			error(
				"[SmartSchemas] No compiled schema found for version "
					.. tostring(version)
					.. ". This DELTA-tagged buffer was produced by a different SmartSchemas "
					.. "instance (or a different server boot) than the one calling Deserialize - "
					.. "promotion state is not persisted across restarts."
			)
		end

		if compiled.usesStringCache then resetStringCache() end
		if compiled.usesKeyArena then AutoRuntime.reset() end
		AutoRuntime.beginDecode(payload)
		local reader = Reader.new(payload)
		reader._ReadU32()

		local fields  = compiled.fields
		local changed = tableCreate(#fields) :: {boolean}
		for i in fields do
			changed[i] = reader._ReadBits(1) == 1
		end

		local receivedByVersion = self.deltaLastReceived[version]
		if not receivedByVersion then
			receivedByVersion = {}
			self.deltaLastReceived[version] = receivedByVersion
		end
		local state = receivedByVersion[id]
		if state == nil then
			state = {}
			receivedByVersion[id] = state
		end

		for i, f in ipairs(fields) do
			if changed[i] then
				state[f.name] = f.read(reader)
			end
		end

		reader._Release()
		return SmartRuntime.restoreOriginalKeys(table.clone(state), shape)
	else
		error("[SmartSchemas] Unknown tag byte " .. tostring(tag) .. " - buffer is not SmartSchemas output.")
	end
end

function SmartSchemasImpl.GetShapeStatus(self: SmartSchemasState, data: {[string]: any}): (boolean, number)
	local hash, count, kindByName = SmartRuntime.buildShapeInfo(data)
	if count == 0 then
		return false, 0
	end
	local shape = self.buckets[hash]
	if shape == nil or not SmartRuntime.shapeMatches(shape, kindByName, count) then
		return false, 0
	end
	return shape.compiled ~= nil, shape.sightings
end

function SmartSchemasImpl.Reset(self: SmartSchemasState)
	self.buckets = {}
	self.compiledByVersion = {}
	self.shapeByVersion = {}
	self.deltaLastSent = {}
	self.deltaSendCount = {}
	self.deltaLastReceived = {}
end

function SmartSchemasImpl.ForceFullDelta(self: SmartSchemasState, id: string | number): ()
	for _, byId in pairs(self.deltaLastSent) do byId[id] = nil end
	for _, byId in pairs(self.deltaSendCount) do byId[id] = nil end
	for _, byId in pairs(self.deltaLastReceived) do byId[id] = nil end
end

local GlobalSmartSchemas = Pancakes.NewSmartSchemas()
Pancakes.GlobalSmartSchemas = GlobalSmartSchemas

function Pancakes.Serialize(data: any, disableTracking: boolean?, id: (string | number)?): SerializedData
	return GlobalSmartSchemas:Serialize(data, disableTracking, id)
end

function Pancakes.Deserialize(buf: buffer, id: (string | number)?): any
	return GlobalSmartSchemas:Deserialize(buf, id)
end

function Pancakes.ForceFullDelta(id: string | number): ()
	GlobalSmartSchemas:ForceFullDelta(id)
end

function Pancakes.ConfigureSmartSchemas(config: SmartSchemaConfig): ()
	(GlobalSmartSchemas :: any).config = config
end

function Pancakes.ResetSmartSchemas(): ()
	GlobalSmartSchemas:Reset()
end

return Pancakes