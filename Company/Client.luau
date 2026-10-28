--!strict
-- GlzzLexiBear logo animation (Luau) - v2: longer + full screen

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

-- CONFIG
local CONFIG = {
	-- uploaded bear image "rbxassetid://123456789".
	-- Leave "" to use the built-in drawn bear.
	BearImage = "",

	TimeScale = 1.8,         -- 1 = original 3.8s speed. Higher = slower/longer.
	HoldTime = 2.5,          -- real seconds to hold the finished logo before fading out
	FillWidth = 0.92,        -- how much of the screen WIDTH the logo may fill (0-1)
	FillHeight = 0.85,       -- how much of the screen HEIGHT the logo may fill (0-1)
	SlowZoom = true,         -- gentle push-in while the logo plays

	ShowBackground = true,   -- full-screen navy backdrop (false = overlay on your own UI)
	AutoDestroy = true,      -- fade out + remove when finished
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

------------------------------------------------------------------------
-- HELPERS

-- tween/later are scaled by TimeScale; the *Raw versions are real seconds.
local function tweenRaw(obj: Instance, t: number, props: {[string]: any}, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function tween(obj: Instance, t: number, props: {[string]: any}, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	return tweenRaw(obj, t * TS, props, style, dir)
end

local function later(t: number, fn: () -> ())
	task.delay(t * TS, fn)
end

local function circle(parent: Instance, color: Color3, pos: UDim2, size: UDim2, z: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Position = pos
	f.Size = size
	f.ZIndex = z or 1
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	f.Parent = parent
	return f
end

local function gradient(parent: Instance, a: Color3, b: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end

local function measure(text: string, size: number, font: Enum.Font): Vector2
	return TextService:GetTextSize(text, size, font, Vector2.new(2000, 2000))
end

------------------------------------------------------------------------
-- GUI ROOT

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "GlzzLexiBearIntro"
gui.IgnoreGuiInset = true    
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.ScreenInsets = Enum.ScreenInsets.None
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = CONFIG.Background
backdrop.BackgroundTransparency = CONFIG.ShowBackground and 0 or 1
backdrop.BorderSizePixel = 0
backdrop.Parent = gui

-- CanvasGroup so the whole logo can fade out as one piece
local root = Instance.new("CanvasGroup")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui

-- "center" sits at screen center and carries the FIT scale
local center = Instance.new("Frame")
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.fromScale(0.5, 0.5)
center.Size = UDim2.fromOffset(0, 0)
center.BackgroundTransparency = 1
center.Parent = root
local fitScale = Instance.new("UIScale")
fitScale.Parent = center

-- "stage" carries the slow push-in zoom
local stage = Instance.new("Frame")
stage.Size = UDim2.fromOffset(0, 0)
stage.BackgroundTransparency = 1
stage.Parent = center
local zoomScale = Instance.new("UIScale")
zoomScale.Scale = CONFIG.SlowZoom and 0.9 or 1
zoomScale.Parent = stage


-- LAYOUT (measured so the three words sit flush together)
local FONT_SIZE = CONFIG.FontSize
local LINE_H = FONT_SIZE + 20
local wGlzz = measure("Glzz", FONT_SIZE, CONFIG.Font).X
local wLexi = measure("Lexi", FONT_SIZE, CONFIG.Font).X
local wBear = measure("Bear", FONT_SIZE, CONFIG.Font).X
local total = wGlzz + wLexi + wBear
local startX = -total / 2
local wordY = -70
local lineY = wordY + 112

-- Design-space bounding box of the whole logo 
local DESIGN_W = total + 120
local DESIGN_H = 560

local function updateScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	local s = math.min(
		(vp.X * CONFIG.FillWidth) / DESIGN_W,
		(vp.Y * CONFIG.FillHeight) / DESIGN_H
	)
	fitScale.Scale = math.max(s, 0.2)
end
updateScale()
local cam = workspace.CurrentCamera
if cam then
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end


-- GLOW (big soft ellipse, breathes)
local glow = Instance.new("Frame")
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.Size = UDim2.fromOffset(total * 1.35, 560)
glow.Position = UDim2.fromOffset(0, 40)
glow.BackgroundColor3 = CONFIG.Glow
glow.BackgroundTransparency = 1
glow.BorderSizePixel = 0
glow.ZIndex = 0
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = glow
end
glow.Parent = stage


-- WORDS
local function makeWord(text: string, x: number, width: number, color: Color3?, useGradient: boolean, stroke: Color3?)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.fromOffset(x, wordY)
	holder.Size = UDim2.fromOffset(0, LINE_H)
	holder.BackgroundTransparency = 1
	holder.ClipsDescendants = true
	holder.Parent = stage

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(width, LINE_H)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = CONFIG.Font
	label.TextSize = FONT_SIZE
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = holder

	if useGradient then
		gradient(label, CONFIG.PinkA, CONFIG.OrangeB, 0)
	end
	if stroke then
		local s = Instance.new("UIStroke")
		s.Color = stroke
		s.Thickness = 4
		s.Transparency = 1
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.Parent = label
	end
	return holder, label
end

local glzzHolder, glzzLabel = makeWord("Glzz", startX, wGlzz, Color3.new(1, 1, 1), true, nil)
local lexiHolder, lexiLabel = makeWord("Lexi", startX + wGlzz, wLexi, CONFIG.Cream, false, nil)
local bearHolder, bearLabel = makeWord("Bear", startX + wGlzz + wLexi, wBear, CONFIG.BearBrown, false, CONFIG.BearStroke)

local function revealWord(holder: Frame, label: TextLabel, width: number, t: number)
	tween(holder, t, {Size = UDim2.fromOffset(width, LINE_H)}, Enum.EasingStyle.Cubic)
	tween(label, t * 0.8, {TextTransparency = 0})
	local s = label:FindFirstChildOfClass("UIStroke")
	if s then
		tween(s, t * 0.8, {Transparency = 0})
	end
end

-- UNDERLINE + LOOP
local lineHolder = Instance.new("Frame")
lineHolder.AnchorPoint = Vector2.new(0, 0.5)
lineHolder.Position = UDim2.fromOffset(startX, lineY)
lineHolder.Size = UDim2.fromOffset(0, 12)
lineHolder.BackgroundTransparency = 1
lineHolder.ClipsDescendants = true
lineHolder.Parent = stage

local line = Instance.new("Frame")
line.Size = UDim2.fromOffset(total, 10)
line.Position = UDim2.fromOffset(0, 1)
line.BackgroundColor3 = Color3.new(1, 1, 1)
line.BorderSizePixel = 0
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = line
end
gradient(line, CONFIG.PinkA, CONFIG.OrangeB, 0)
line.Parent = lineHolder

local RING = 64
local loopGroup = Instance.new("Frame")
loopGroup.AnchorPoint = Vector2.new(0.5, 0.5)
loopGroup.Position = UDim2.fromOffset(startX + total * 0.305, lineY + RING * 0.42)
loopGroup.Size = UDim2.fromOffset(0, 0)
loopGroup.BackgroundTransparency = 1
loopGroup.Parent = stage

local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.Size = UDim2.fromScale(1, 0.82)
ring.BackgroundTransparency = 1
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = ring
	local s = Instance.new("UIStroke")
	s.Color = CONFIG.LoopColor
	s.Thickness = 8
	s.Parent = ring
end
ring.Parent = loopGroup

local dot = circle(loopGroup, CONFIG.Cream, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.22, 0.26))
dot.AnchorPoint = Vector2.new(0.5, 0.5)

-- BEAR
local BEAR_SIZE = 120
local bearGroup = Instance.new("CanvasGroup")
bearGroup.AnchorPoint = Vector2.new(0.5, 1)
local bearRestPos = UDim2.fromOffset(startX + wGlzz + wLexi + 62, wordY - LINE_H / 2 + 58)
bearGroup.Position = bearRestPos + UDim2.fromOffset(0, 45)
bearGroup.Size = UDim2.fromOffset(BEAR_SIZE, BEAR_SIZE)
bearGroup.BackgroundTransparency = 1
bearGroup.GroupTransparency = 1
bearGroup.ZIndex = 5
bearGroup.Parent = stage

if CONFIG.BearImage ~= "" then
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = CONFIG.BearImage
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = bearGroup
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
local spaced = string.gsub(CONFIG.Tagline, "(.)", "%1\u{2009}")
local TAG_Y = lineY + 114
local tagline = Instance.new("TextLabel")
tagline.AnchorPoint = Vector2.new(0, 0.5)
tagline.Position = UDim2.fromOffset(startX + total * 0.12, TAG_Y + 16)
tagline.Size = UDim2.fromOffset(total * 0.8, 44)
tagline.BackgroundTransparency = 1
tagline.Text = spaced
tagline.Font = CONFIG.TaglineFont
tagline.TextSize = 34
tagline.TextColor3 = Color3.fromRGB(235, 235, 235)
tagline.TextXAlignment = Enum.TextXAlignment.Left
tagline.TextTransparency = 1
tagline.Parent = stage

-- TIMELINE 
local function play()
	-- 0.00 glow fades in, then breathes
	tween(glow, 0.8, {BackgroundTransparency = 0.35})
	later(0.8, function()
		TweenService:Create(
			glow,
			TweenInfo.new(1.6 * TS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{BackgroundTransparency = 0.6}
		):Play()
	end)

	-- slow push-in across the whole intro
	if CONFIG.SlowZoom then
		tweenRaw(zoomScale, (2.9 * TS) + CONFIG.HoldTime, {Scale = 1}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	end

	-- 0.30 "Glzz"   0.65 "Lexi"
	later(0.30, function() revealWord(glzzHolder, glzzLabel, wGlzz, 0.65) end)
	later(0.65, function() revealWord(lexiHolder, lexiLabel, wLexi, 0.65) end)

	-- 1.00 underline draws
	later(1.00, function()
		tween(lineHolder, 1.0, {Size = UDim2.fromOffset(total, 12)}, Enum.EasingStyle.Quart)
	end)

	-- 1.35 loop pops with overshoot
	later(1.35, function()
		tween(loopGroup, 0.5, {Size = UDim2.fromOffset(RING, RING)}, Enum.EasingStyle.Back)
	end)

	-- 1.45 bear rises, then idles with a tiny bob
	later(1.45, function()
		tween(bearGroup, 0.55, {GroupTransparency = 0})
		local rise = tween(bearGroup, 0.7, {Position = bearRestPos}, Enum.EasingStyle.Back)
		rise.Completed:Connect(function()
			TweenService:Create(
				bearGroup,
				TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{Position = bearRestPos - UDim2.fromOffset(0, 6)}
			):Play()
		end)
	end)

	-- 1.80 "Bear"
	later(1.80, function() revealWord(bearHolder, bearLabel, wBear, 0.7) end)

	-- 2.45 tagline
	later(2.45, function()
		tween(tagline, 0.7, {
			TextTransparency = 0,
			Position = UDim2.fromOffset(startX + total * 0.12, TAG_Y),
		})
	end)

	-- fade out after the hold 
	if CONFIG.AutoDestroy then
		task.delay((3.2 * TS) + CONFIG.HoldTime, function()
			tweenRaw(root, 0.6, {GroupTransparency = 1})
			tweenRaw(backdrop, 0.6, {BackgroundTransparency = 1})
			task.delay(0.7, function() gui:Destroy() end)
		end)
	end
end

play()
