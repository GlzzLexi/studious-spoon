--!strict
-- GlzzLexiBear logo animation (Luau)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

-- CONFIG
local CONFIG = {
	-- Use an uploaded image ID, for example "rbxassetid://123456789".
	BearImage = "",

	TimeScale = 1.8, -- 1 = original speed; higher values make the intro slower.
	HoldTime = 2.5, -- Real seconds to hold the finished logo before fading out.
	FillWidth = 0.92, -- Maximum share of screen width used by the logo.
	FillHeight = 0.85, -- Maximum share of screen height used by the logo.
	SlowZoom = true,

	ShowBackground = true, -- false makes the backdrop transparent.
	AutoDestroy = true,
	Font = Enum.Font.FredokaOne,
	TaglineFont = Enum.Font.GothamBold,
	FontSize = 150,
	Tagline = "SHARP WIT. SWEET GLAZE.",

	Background = Color3.fromRGB(10, 18, 30),
	Glow = Color3.fromRGB(18, 36, 58),
	PinkA = Color3.fromRGB(255, 112, 160),
	OrangeB = Color3.fromRGB(255, 178, 70),
	Cream = Color3.fromRGB(250, 242, 224),
	BearBrown = Color3.fromRGB(108, 70, 36),
	BearStroke = Color3.fromRGB(78, 48, 24),
	LoopColor = Color3.fromRGB(255, 134, 130),
}

local TS = CONFIG.TimeScale

-- HELPERS
-- tween() and later() use TimeScale. Their Raw versions use real seconds.
local function tweenRaw(
	obj: Instance,
	duration: number,
	properties: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local animation = TweenService:Create(
		obj,
		TweenInfo.new(
			duration,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out
		),
		properties
	)
	animation:Play()
	return animation
end

local function tween(
	obj: Instance,
	duration: number,
	properties: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	return tweenRaw(obj, duration * TS, properties, style, direction)
end

local function later(duration: number, callback: () -> ())
	task.delay(duration * TS, callback)
end

local function circle(
	parent: Instance,
	color: Color3,
	position: UDim2,
	size: UDim2,
	zIndex: number?
): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = size
	frame.ZIndex = zIndex or 1

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame

	frame.Parent = parent
	return frame
end

local function gradient(parent: Instance, firstColor: Color3, lastColor: Color3, rotation: number?)
	local colorGradient = Instance.new("UIGradient")
	colorGradient.Color = ColorSequence.new(firstColor, lastColor)
	colorGradient.Rotation = rotation or 0
	colorGradient.Parent = parent
	return colorGradient
end

local function measure(text: string, size: number, font: Enum.Font): Vector2
	return TextService:GetTextSize(text, size, font, Vector2.new(2000, 2000))
end

-- GUI ROOT
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove an older copy if this LocalScript runs again in the same session.
local previousGui = playerGui:FindFirstChild("GlzzLexiBearIntro")
if previousGui then
	previousGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "GlzzLexiBearIntro"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.ScreenInsets = Enum.ScreenInsets.None
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = CONFIG.Background
backdrop.BackgroundTransparency = CONFIG.ShowBackground and 0 or 1
backdrop.BorderSizePixel = 0
backdrop.Parent = gui

-- The CanvasGroup lets the finished logo fade out as one unit.
local root = Instance.new("CanvasGroup")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui

local center = Instance.new("Frame")
center.Name = "Center"
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.fromScale(0.5, 0.5)
center.Size = UDim2.fromOffset(0, 0)
center.BackgroundTransparency = 1
center.Parent = root

local fitScale = Instance.new("UIScale")
fitScale.Parent = center

local stage = Instance.new("Frame")
stage.Name = "Stage"
stage.Size = UDim2.fromOffset(0, 0)
stage.BackgroundTransparency = 1
stage.Parent = center

local zoomScale = Instance.new("UIScale")
zoomScale.Scale = CONFIG.SlowZoom and 0.9 or 1
zoomScale.Parent = stage

-- LAYOUT
local FONT_SIZE = CONFIG.FontSize
local LINE_H = FONT_SIZE + 20

local wGlzz = measure("Glzz", FONT_SIZE, CONFIG.Font).X
local wLexi = measure("Lexi", FONT_SIZE, CONFIG.Font).X
local wBear = measure("Bear", FONT_SIZE, CONFIG.Font).X
local prefixWidth = measure("GlzzLexi", FONT_SIZE, CONFIG.Font).X

-- Measure the complete name. The full name is displayed in one TextLabel,
-- so there are no independently positioned word labels leaving gaps.
local total = measure("GlzzLexiBear", FONT_SIZE, CONFIG.Font).X
local startX = -total / 2
local wordY = -70
local lineY = wordY + 112

local DESIGN_W = total + 120
local DESIGN_H = 560

local function updateScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local scale = math.min(
		(viewport.X * CONFIG.FillWidth) / DESIGN_W,
		(viewport.Y * CONFIG.FillHeight) / DESIGN_H
	)
	fitScale.Scale = math.max(scale, 0.2)
end

updateScale()
local camera = workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- LOGO GLOW
local glow = Instance.new("Frame")
glow.Name = "Glow"
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.Size = UDim2.fromOffset(total * 1.35, 560)
glow.Position = UDim2.fromOffset(0, 40)
glow.BackgroundColor3 = CONFIG.Glow
glow.BackgroundTransparency = 1
glow.BorderSizePixel = 0
glow.ZIndex = 0

local glowCorner = Instance.new("UICorner")
glowCorner.CornerRadius = UDim.new(0.5, 0)
glowCorner.Parent = glow
glow.Parent = stage

-- WORDMARK
-- RichText changes colors inside one continuous string. There are no spaces
-- between the closing and opening font tags.
local logoText = Instance.new("TextLabel")
logoText.Name = "LogoText"
logoText.AnchorPoint = Vector2.new(0.5, 0.5)
logoText.Position = UDim2.fromOffset(0, wordY)
logoText.Size = UDim2.fromOffset(total + 24, LINE_H)
logoText.BackgroundTransparency = 1
logoText.RichText = true
logoText.Text = '<font color="#FF70A0">Glzz</font>'
	.. '<font color="#FAF2E0">Lexi</font>'
	.. '<font color="#6C4624">Bear</font>'
logoText.Font = CONFIG.Font
logoText.TextSize = FONT_SIZE
logoText.TextColor3 = Color3.new(1, 1, 1)
logoText.TextXAlignment = Enum.TextXAlignment.Center
logoText.TextYAlignment = Enum.TextYAlignment.Center
logoText.TextTransparency = 1
logoText.MaxVisibleGraphemes = 0
logoText.Parent = stage

-- UNDERLINE AND LOOP
local lineHolder = Instance.new("Frame")
lineHolder.Name = "UnderlineHolder"
lineHolder.AnchorPoint = Vector2.new(0, 0.5)
lineHolder.Position = UDim2.fromOffset(startX, lineY)
lineHolder.Size = UDim2.fromOffset(0, 12)
lineHolder.BackgroundTransparency = 1
lineHolder.ClipsDescendants = true
lineHolder.Parent = stage

local line = Instance.new("Frame")
line.Name = "Underline"
line.Size = UDim2.fromOffset(total, 10)
line.Position = UDim2.fromOffset(0, 1)
line.BackgroundColor3 = Color3.new(1, 1, 1)
line.BorderSizePixel = 0

local lineCorner = Instance.new("UICorner")
lineCorner.CornerRadius = UDim.new(0.5, 0)
lineCorner.Parent = line

gradient(line, CONFIG.PinkA, CONFIG.OrangeB, 0)
line.Parent = lineHolder

local RING = 64
local loopGroup = Instance.new("Frame")
loopGroup.Name = "LoopGroup"
loopGroup.AnchorPoint = Vector2.new(0.5, 0.5)
loopGroup.Position = UDim2.fromOffset(startX + total * 0.305, lineY + RING * 0.42)
loopGroup.Size = UDim2.fromOffset(0, 0)
loopGroup.BackgroundTransparency = 1
loopGroup.Parent = stage

local ring = Instance.new("Frame")
ring.Name = "Ring"
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.Size = UDim2.fromScale(1, 0.82)
ring.BackgroundTransparency = 1

local ringCorner = Instance.new("UICorner")
ringCorner.CornerRadius = UDim.new(0.5, 0)
ringCorner.Parent = ring

local ringStroke = Instance.new("UIStroke")
ringStroke.Color = CONFIG.LoopColor
ringStroke.Thickness = 8
ringStroke.Parent = ring
ring.Parent = loopGroup

local dot = circle(
	loopGroup,
	CONFIG.Cream,
	UDim2.fromScale(0.5, 0.5),
	UDim2.fromScale(0.22, 0.26)
)
dot.AnchorPoint = Vector2.new(0.5, 0.5)

-- BEAR
local BEAR_SIZE = 120
local bearGroup = Instance.new("CanvasGroup")
bearGroup.Name = "BearGroup"
bearGroup.AnchorPoint = Vector2.new(0.5, 1)

-- Keep the bear over the beginning of the word "Bear", as in the original.
local bearRestPos = UDim2.fromOffset(startX + prefixWidth + 62, wordY - LINE_H / 2 + 58)
bearGroup.Position = bearRestPos + UDim2.fromOffset(0, 45)
bearGroup.Size = UDim2.fromOffset(BEAR_SIZE, BEAR_SIZE)
bearGroup.BackgroundTransparency = 1
bearGroup.GroupTransparency = 1
bearGroup.ZIndex = 5
bearGroup.Parent = stage

if CONFIG.BearImage ~= "" then
	local image = Instance.new("ImageLabel")
	image.Name = "BearImage"
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.Image = CONFIG.BearImage
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = bearGroup
else
	local brown = CONFIG.BearBrown
	local dark = CONFIG.BearStroke
	local tan = Color3.fromRGB(228, 190, 144)

	circle(bearGroup, brown, UDim2.fromScale(0.08, 0.08), UDim2.fromScale(0.30, 0.30), 1)
	circle(bearGroup, brown, UDim2.fromScale(0.62, 0.08), UDim2.fromScale(0.30, 0.30), 1)
	circle(bearGroup, tan, UDim2.fromScale(0.14, 0.14), UDim2.fromScale(0.16, 0.16), 2)
	circle(bearGroup, tan, UDim2.fromScale(0.70, 0.14), UDim2.fromScale(0.16, 0.16), 2)
	circle(bearGroup, brown, UDim2.fromScale(0.12, 0.16), UDim2.fromScale(0.76, 0.68), 3)
	circle(bearGroup, tan, UDim2.fromScale(0.32, 0.50), UDim2.fromScale(0.36, 0.28), 4)
	circle(bearGroup, Color3.fromRGB(176, 104, 96), UDim2.fromScale(0.20, 0.52), UDim2.fromScale(0.12, 0.09), 4)
	circle(bearGroup, Color3.fromRGB(176, 104, 96), UDim2.fromScale(0.68, 0.52), UDim2.fromScale(0.12, 0.09), 4)
	circle(bearGroup, Color3.new(0, 0, 0), UDim2.fromScale(0.30, 0.42), UDim2.fromScale(0.08, 0.08), 5)
	circle(bearGroup, Color3.new(0, 0, 0), UDim2.fromScale(0.62, 0.42), UDim2.fromScale(0.08, 0.08), 5)
	circle(bearGroup, dark, UDim2.fromScale(0.44, 0.53), UDim2.fromScale(0.12, 0.08), 5)
	circle(bearGroup, brown, UDim2.fromScale(0.22, 0.82), UDim2.fromScale(0.18, 0.14), 6)
	circle(bearGroup, brown, UDim2.fromScale(0.60, 0.82), UDim2.fromScale(0.18, 0.14), 6)
end

-- TAGLINE
local spacedTagline = string.gsub(CONFIG.Tagline, "(.)", "%1\u{2009}")
local TAG_Y = lineY + 114

local tagline = Instance.new("TextLabel")
tagline.Name = "Tagline"
tagline.AnchorPoint = Vector2.new(0, 0.5)
tagline.Position = UDim2.fromOffset(startX + total * 0.12, TAG_Y + 16)
tagline.Size = UDim2.fromOffset(total * 0.8, 44)
tagline.BackgroundTransparency = 1
tagline.Text = spacedTagline
tagline.Font = CONFIG.TaglineFont
tagline.TextSize = 34
tagline.TextColor3 = Color3.fromRGB(235, 235, 235)
tagline.TextXAlignment = Enum.TextXAlignment.Left
tagline.TextTransparency = 1
tagline.Parent = stage

-- TIMELINE
local function play()
	-- Glow fades in, then slowly breathes.
	tween(glow, 0.8, { BackgroundTransparency = 0.35 })
	later(0.8, function()
		TweenService:Create(
			glow,
			TweenInfo.new(1.6 * TS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundTransparency = 0.6 }
		):Play()
	end)

	-- Gentle push-in while the intro plays.
	if CONFIG.SlowZoom then
		tweenRaw(
			zoomScale,
			(2.9 * TS) + CONFIG.HoldTime,
			{ Scale = 1 },
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out
		)
	end

	-- Reveal the name progressively. MaxVisibleGraphemes counts characters,
	-- while RichText keeps all three color sections in one continuous label.
	later(0.30, function()
		logoText.MaxVisibleGraphemes = 4
		tween(logoText, 0.52, { TextTransparency = 0 })
	end)

	later(0.65, function()
		logoText.MaxVisibleGraphemes = 8
	end)

	later(1.00, function()
		tween(lineHolder, 1.0, { Size = UDim2.fromOffset(total, 12) }, Enum.EasingStyle.Quart)
	end)

	later(1.35, function()
		tween(loopGroup, 0.5, { Size = UDim2.fromOffset(RING, RING) }, Enum.EasingStyle.Back)
	end)

	later(1.45, function()
		tween(bearGroup, 0.55, { GroupTransparency = 0 })
		local rise = tween(bearGroup, 0.7, { Position = bearRestPos }, Enum.EasingStyle.Back)
		rise.Completed:Connect(function()
			TweenService:Create(
				bearGroup,
				TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Position = bearRestPos - UDim2.fromOffset(0, 6) }
			):Play()
		end)
	end)

	later(1.80, function()
		logoText.MaxVisibleGraphemes = 12
	end)

	later(2.45, function()
		tween(tagline, 0.7, {
			TextTransparency = 0,
			Position = UDim2.fromOffset(startX + total * 0.12, TAG_Y),
		})
	end)

	-- Hold the complete logo, then fade it out and clean up.
	if CONFIG.AutoDestroy then
		task.delay((3.2 * TS) + CONFIG.HoldTime, function()
			tweenRaw(root, 0.6, { GroupTransparency = 1 })
			tweenRaw(backdrop, 0.6, { BackgroundTransparency = 1 })
			task.delay(0.7, function()
				if gui.Parent then
					gui:Destroy()
				end
			end)
		end)
	end
end

play()
