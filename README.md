# Supercorner

A Figma-inspired UICorner alternative for Roblox.

Benefits to Supercorner:
- Supports individual corner radii.
- Supports corner smoothing (squircles).

## Disclaimer

> This library is not an official product from the Figma team and does not guarantee to produce the same results as you would get in Figma.

> This is a Roblox/Luau fork of [phamfoo/figma-squircle](https://github.com/phamfoo/figma-squircle) - Big thanks to the original creator.

<img src="demo.png" alt="comparison between supercorner and uicorner" width="400">

## UI Framework Support

- [React-luau](https://github.com/cameronpcampbell/supercorner/tree/main/supercorner_react)

## Installation

Add to your `wally.toml`:

```toml
[dependencies]
supercorner = "cameronpcampbell/supercorner@{version}"
```

## Usage

```luau
local Supercorner = require(path.to.Supercorner)

local Squircle = Supercorner.new({
	CornerRadius = 24,
	CornerSmoothing = 0.6,
})

local ImageLabel = Instance.new("ImageLabel")
ImageLabel.ImageContent = Squircle:GetContent()
ImageLabel.ScaleType = Enum.ScaleType.Slice
ImageLabel.SliceCenter = Squircle:GetSliceCenter()
ImageLabel.SliceScale = Squircle:GetSliceScale()
ImageLabel.Size = UDim2.fromOffset(200, 200)
ImageLabel.BackgroundTransparency = 1
ImageLabel.Parent = SomeParent

-- Clean up when done
Squircle:Destroy()
```

## Sizing

Supercorner automatically calculates the image size from the corner radii. There is no need to specify a width or height manually.

For supercorners with `Redrawable` set the true: `MaxCornerRadius` (or the per-corner variants `MaxTopLeftCornerRadius`, `MaxTopRightCornerRadius`, `MaxBottomRightCornerRadius`, `MaxBottomLeftCornerRadius`) control the image size. These define the largest radii you intend to use, and the image is allocated to fit them. Without these, the image is sized for the initial radii.

For static (non-redrawable) supercorners: The image is always sized from the initial radii since they cannot be redrawn.

If a redraw exceeds the max radii, the radius is clamped and a warning is emitted.

## Static Content

By default, Supercorner converts the rendered image into static content using [`CreateDataModelContentAsync`](https://devforum.roblox.com/t/studio-beta-introducing-createdatamodelcontent-convert-editable-mesh-and-image-data-into-static-content/4541898). This frees up the editable memory budget since most supercorner's don't need to change after creation.

This requires the **Enable Mesh/Image to static content conversion API** beta feature to be enabled. If the feature is not enabled, Supercorner will automatically fall back to keeping the EditableImage alive.

## Redrawing

If you need to update a supercorner after creation, pass `Redrawable = true` in the constructor:

```luau
local Squircle = Supercorner.new({
	CornerRadius = 24,
	CornerSmoothing = 0.6,
	MaxCornerRadius = 48,
	Redrawable = true,
})
ImageLabel.ImageContent = Squircle:GetContent()
ImageLabel.ScaleType = Enum.ScaleType.Slice
ImageLabel.SliceCenter = Squircle:GetSliceCenter()
ImageLabel.SliceScale = Squircle:GetSliceScale()

-- Update corners later
Squircle:Redraw({
	CornerRadius = 32,
	CornerSmoothing = 0.8,
	TopLeftCornerRadius = 16,
	TopRightCornerRadius = 16,
})
ImageLabel.ImageContent = Squircle:GetContent()
ImageLabel.SliceCenter = Squircle:GetSliceCenter()
```

Calling `:Redraw()` on a non-redrawable (static) supercorner will throw an error. Only use `Redrawable = true` when you actually need to update corners at runtime, as doing so takes up some amount of our editable memory budget.
