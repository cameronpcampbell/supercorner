--!strict

local React = require(script.Packages.react)
local ReactRoblox = require(script.Packages["react-roblox"])
local Supercorner = require(script.Packages["supercorner-react"])

local Players = game:GetService("Players")

local CreateElement = React.createElement

local function App()
	return CreateElement("ScreenGui", {}, {
		MySupercorner = CreateElement(Supercorner :: any, {
		    CornerRadius = 20,
			BottomLeftCornerRadius = 35,
			CornerSmoothing = 1.,
			Size = UDim2.fromScale(.8, .8),
            Position = UDim2.fromScale(.5, .5),
            AnchorPoint = Vector2.new(.5, .5),
            BackgroundColor3 = BrickColor.Yellow().Color,
            BackgroundTransparency = .5
		}),
	})
end

local root = ReactRoblox.createRoot(Instance.new("Folder"))
root:render(ReactRoblox.createPortal(CreateElement(App :: any), Players.LocalPlayer.PlayerGui))
