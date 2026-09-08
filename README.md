# Pancakes

High-performance binary serialization for Roblox Luau.

Pancakes serializes supported Luau values and Roblox datatypes into compact native `buffer` values. It provides automatic serialization, explicit schemas, SmartSchemas, custom converters, buffer utilities, runtime configuration, and malformed-buffer protection.

## Installation
Pesde and Ember are comming soon!

### Wally

Add Pancakes to your `wally.toml`:

```toml
[dependencies]
Pancakes = "darkgamerroblox/pancakes@1.0.0"
```

Then run:

```bash
wally install
```

## Basic usage

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pancakes = require(ReplicatedStorage.Packages.Pancakes)

local encoded: buffer = Pancakes.SerializeAuto({
    coins = 1250,
    name = "Pancake",
    equipped = true,
})

local decoded = Pancakes.DeserializeAuto(encoded)
print(decoded.coins)
```

## Package layout

`src/init.luau` is the main module and `src/Settings.luau` is its child module. The included `default.project.json` maps the `src` directory as one Roblox ModuleScript package, so `require(script.Settings)` works after syncing.

## Documentation
https://darkgamerroblox.github.io/Pancakes/

## License

MIT.
