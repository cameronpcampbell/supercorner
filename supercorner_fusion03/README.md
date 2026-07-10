# Supercorner Fusion 0.3

A Fusion 0.3 wrapper for [Supercorner](https://github.com/cameronpcampbell/supercorner).

## Installation

Install the Roblox package with Pesde:

```sh
pesde add cameronpcampbell/supercorner_fusion03@0.1.1 -t roblox
```

Or add it directly to `pesde.toml`:

```toml
[dependencies]
supercorner_fusion03 = { name = "cameronpcampbell/supercorner_fusion03", version = "^0.1.1", target = "roblox" }
```

## Usage

```luau
local Fusion = require(path.to.Fusion)
local Supercorner = require(path.to.SupercornerFusion03)

local Scoped = Fusion.scoped
local Scope = Scoped(Fusion)

local CornerRadiusState = Scope:Value(24)

Supercorner(Scope, {
    CornerRadius = CornerRadiusState,
    CornerSmoothing = 0.6,
    BackgroundColor3 = Color3.new(1, 1, 1),
    Size = UDim2.fromOffset(200, 200),
})
```

## Fallback Behavior

If Supercorner fails to create (e.g. the editable memory budget is exhausted), the component automatically falls back to a standard `UICorner`.
