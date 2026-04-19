--!strict

local React = require(script.Packages.react)
local ReactRoblox = require(script.Packages["react-roblox"])
local Supercorner = require(script.Packages["supercorner-react"])

local Players = game:GetService("Players")

local CreateElement = React.createElement

local function App()
	local cornerRadius, setCornerRadius = React.useState(75)
	local cornerSmoothing, setCornerSmoothing = React.useState(1)

	React.useEffect(function()
		local running = true

		task.spawn(function()
			while running and (cornerRadius > 0 or cornerSmoothing > 0) do
				task.wait(0.1)
				if not running then break end
				setCornerRadius(function(v: number) return math.max(v - 2, 0) end)
				setCornerSmoothing(function(v: number) return math.max(v - 2/35, 0) end)
			end
		end)

		return function()
			running = false
		end
	end, {})

	return CreateElement("ScreenGui", {}, {
		MySupercorner = CreateElement(Supercorner :: any, {
			CornerRadius = cornerRadius,
			CornerSmoothing = cornerSmoothing,
			Redrawable = true,
			Size = UDim2.fromScale(.8, .8),
			Position = UDim2.fromScale(.5, .5),
			AnchorPoint = Vector2.new(.5, .5),
			BackgroundColor3 = BrickColor.Yellow().Color,
			BackgroundTransparency = .5,
			StrokeThickness = 5,
			StrokeGradient = CreateElement("UIGradient", {
				Color = ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 0, 1)),
			}),
		}, {
            CreateElement("Frame", {
                Size = UDim2.fromScale(1, 1),
                Transparency = .5,

            })
		}),
	})
end

local root = ReactRoblox.createRoot(Instance.new("Folder"))
root:render(ReactRoblox.createPortal(CreateElement(App :: any), Players.LocalPlayer.PlayerGui))
