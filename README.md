# Supercorner

A Figma-inspired UICorner alternative for Roblox.

Benefits to Supercorner:
- Supports individual corner radii.
- Supports corner smoothing (squircles).

## Disclaimer

> This library is not an official product from the Figma team and does not guarantee to produce the same results as you would get in Figma.

> This is a Roblox/Luau fork of [phamfoo/figma-squircle](https://github.com/phamfoo/figma-squircle) - Big thanks to the original creator.

<img src="demo.png" alt="comparison between supercorner and uicorner" width="400">

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
ImageLabel.Size = UDim2.fromOffset(200, 200)
ImageLabel.BackgroundTransparency = 1
ImageLabel.Parent = SomeParent

-- Clean up when done
Squircle:Destroy()
```

## Static Content

By default, Supercorner converts the rendered image into static content using [`CreateDataModelContentAsync`](https://devforum.roblox.com/t/studio-beta-introducing-createdatamodelcontent-convert-editable-mesh-and-image-data-into-static-content/4541898). This frees up the editable memory budget since most supercorner's don't need to change after creation.

This requires the **Enable Mesh/Image to static content conversion API** beta feature to be enabled. If the feature is not enabled, Supercorner will automatically fall back to keeping the EditableImage alive.

## Redrawing

If you need to update a supercorner after creation, pass `Redrawable = true` in the constructor:

```luau
local Squircle = Supercorner.new({
	CornerRadius = 24,
	CornerSmoothing = 0.6,
	Redrawable = true,
})

-- Update corners later
Squircle:Redraw({
	CornerRadius = 32,
	CornerSmoothing = 0.8,
	TopLeftCornerRadius = 16,
	TopRightCornerRadius = 16,
})
ImageLabel.ImageContent = Squircle:GetContent()
```

Calling `:Redraw()` on a non-redrawable (static) supercorner will throw an error. Only use `Redrawable = true` when you actually need to update corners at runtime, as it keeps the EditableImage in memory.
