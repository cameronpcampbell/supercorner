# Supercorner React

A React-lua wrapper for [Supercorner](https://github.com/cameronpcampbell/supercorner).

## Installation

Add to your `wally.toml`:

```toml
[dependencies]
supercorner-react = "cameronpcampbell/supercorner-react@{version}"
```

## Usage

```luau
local Supercorner = require(path.to.SupercornerReact)
local React = require(path.to.React)

local function MyComponent()
    return React.createElement(Supercorner, {
        CornerRadius = 24,
        CornerSmoothing = 0.6,
        BackgroundColor3 = Color3.new(1, 1, 1),
        Size = UDim2.fromOffset(200, 200),
    })
end
```

## Fallback Behavior

If Supercorner fails to create (e.g. the editable memory budget is exhausted), the component automatically falls back to a standard `UICorner`.
