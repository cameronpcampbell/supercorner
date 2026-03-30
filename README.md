# SuperCorner

A Figma-inspired UICorner alternative for Roblox.

Benefits to SuperCorner:
- Supports individual corner radii.
- Supports corner smoothing (squircles).

## Disclaimer

> This library is not an official product from the Figma team and does not guarantee to produce the same results as you would get in Figma.

> This is a Roblox/Luau fork of [phamfoo/figma-squircle](https://github.com/phamfoo/figma-squircle) - Big thanks to the original creator.

<img src="demo.png" alt="comparison between supercorner and uicorner" width="400">

## Usage

```luau
local supercorner = require(path.to.supercorner)

-- Create a squircle
local squircle = supercorner.create({
	width = 200,
	height = 200,
	cornerRadius = 24,
	cornerSmoothing = 0.6,
})

-- Apply it to an ImageLabel
local image_label = Instance.new("ImageLabel")
image_label.ImageContent = squircle:get_content()
image_label.Size = UDim2.fromOffset(200, 200)
image_label.BackgroundTransparency = 1
image_label.Parent = some_parent

-- Update corners later
squircle:redraw({
	cornerRadius = 32,
	cornerSmoothing = 0.8,
	topLeftCornerRadius = 16,
	topRightCornerRadius = 16,
})
image_label.ImageContent = squircle:get_content()

-- Clean up when done
squircle:destroy()
```
