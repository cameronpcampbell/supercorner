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

Supercorner.new(Scope, {
    CornerRadius = CornerRadiusState,
    CornerSmoothing = 0.6,
    MaxCornerRadius = 48,
    Redrawable = true,
    BackgroundColor3 = Color3.new(1, 1, 1),
    Size = UDim2.fromOffset(200, 200),
})
```

## Reactive Geometry

Set `Redrawable = true` when `CornerRadius`, `CornerSmoothing`, any individual
corner radius, `PreserveSmoothing`, `AntiAlias`, or `StrokeThickness` is
reactive. Configure `MaxCornerRadius` or the individual maximum-radius props for
the largest values the component will display.

Related geometry changes made together are coalesced into one deferred redraw,
so the component does not rasterize transient combinations of new and old
values. For predetermined animations between two geometries, prefer
`Supercorner.atlas` to pre-render discrete keypoints.

When all four effective corner radii are `0` and `Redrawable` is false,
`Supercorner.new` renders the fill with a regular `Frame`. This avoids allocating
image content for a rectangular fill, while any visible stroke continues to use
the normal Supercorner image renderer. Fill color and transparency remain
reactive in this mode; a fully transparent fill produces a hollow shape with a
Supercorner-rendered stroke.

Set `ForceSupercorner = true` to disable this zero-radius fill optimization and
keep the entire component on the normal Supercorner image-rendering path. This
is a static construction option and does not disable the emergency fallback
used when Supercorner image creation fails.

## Fallback Behavior

If Supercorner fails to create (e.g. the editable memory budget is exhausted), the component automatically falls back to a standard `UICorner`.
