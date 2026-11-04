
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local okEnv, env = pcall(function()
	return getfenv(1)
end)
if not okEnv or type(env) ~= "table" then
	env = {}
end
local okGenv, genv = pcall(function()
	return type(env.getgenv) == "function" and env.getgenv() or env
end)
if not okGenv or type(genv) ~= "table" then
	genv = env
end
local function exec(name)
	local ok, fn = pcall(function()
		return env[name] or genv[name]
	end)
	if ok and type(fn) == "function" then
		return fn
	end
	return nil
end
local writefile = exec("writefile")
local readfile = exec("readfile")
local isfile = exec("isfile")
local isfolder = exec("isfolder")
local makefolder = exec("makefolder")
local delfile = exec("delfile")
local listfiles = exec("listfiles")
local gethui = exec("gethui")
local mousemoverel = exec("mousemoverel")

do
	local previous = genv.CurzsV3UI
	if type(previous) == "table" and type(previous.Unload) == "function" then
		pcall(previous.Unload, previous)
	end
end

local LocalPlayer = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local Assets = {
	Background = "122952835362504",
	Logo = "95889853031767",
	SubTab = "98471112752809",
	NotifyIcon = "91599051711511",
	NotifySound = "18595195017",
	Main = "135962296175199",
	Player = "132353928218632",
	Visuals = "136812801080702",
	Misc = "92721198018554",
	Settings = "77932102403882",
}

local Fonts = {
	Gotham = { Enum.Font.GothamMedium, Enum.Font.GothamBold },
	SourceSans = { Enum.Font.SourceSansSemibold, Enum.Font.SourceSansBold },
	Nunito = { Enum.Font.Nunito, Enum.Font.Nunito },
	Ubuntu = { Enum.Font.Ubuntu, Enum.Font.Ubuntu },
	Roboto = { Enum.Font.Roboto, Enum.Font.Roboto },
	Jura = { Enum.Font.Jura, Enum.Font.Jura },
	TitilliumWeb = { Enum.Font.TitilliumWeb, Enum.Font.TitilliumWeb },
}

local FontNames = { "Gotham", "SourceSans", "Nunito", "Ubuntu", "Roboto", "Jura", "TitilliumWeb" }

local Theme = {
	Accent = Color3.fromRGB(110, 140, 255),
	Text = Color3.fromRGB(238, 241, 252),
	Box = Color3.fromRGB(10, 12, 22),
	Font = "Gotham",
	Dim = 0.4,
	Outline = WHITE,
	OutlineTrans = 0.86,
	OutlineThick = 1,
	Edge = WHITE,
	EdgeTrans = 0.9,
	BoxTrans = 0.35,
	Radius = 18,
	UIScale = 1,
	Wallpaper = true,
	Sound = true,
	Volume = 0.6,
	NotifyTime = 2.5,
}

local Library = {
	Flags = {},
	Setters = {},
	Updaters = {},
	Connections = {},
	OnUnload = {},
	NoRestore = {},
	Loading = false,
}

pcall(function()
	genv.CurzsV3UI = Library
end)

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled
Library.IsMobile = IsMobile

local Root = "curzsV3/" .. tostring(LocalPlayer.UserId)

local hasFS = type(writefile) == "function"
	and type(readfile) == "function"
	and type(isfile) == "function"
	and type(isfolder) == "function"
	and type(makefolder) == "function"

local memoryStore = {}
local Storage = {}

function Storage.init()
	if not hasFS then
		return
	end
	for _, path in ipairs({ "curzsV3", Root, Root .. "/configs", Root .. "/uiconfigs" }) do
		if not isfolder(path) then
			pcall(makefolder, path)
		end
	end
end

function Storage.write(path, data)
	if hasFS then
		return pcall(writefile, path, data)
	end
	memoryStore[path] = data
	return true
end

function Storage.read(path)
	if hasFS then
		if isfile(path) then
			local ok, data = pcall(readfile, path)
			if ok then
				return data
			end
		end
		return nil
	end
	return memoryStore[path]
end

function Storage.remove(path)
	if hasFS then
		if type(delfile) == "function" and isfile(path) then
			pcall(delfile, path)
		end
		return
	end
	memoryStore[path] = nil
end

function Storage.list(folder)
	folder = folder or "configs"
	local names = {}
	if hasFS then
		if type(listfiles) == "function" then
			local ok, files = pcall(listfiles, Root .. "/" .. folder)
			if ok then
				for _, file in ipairs(files) do
					local name = file:match("([^/\\]+)%.json$")
					if name then
						table.insert(names, name)
					end
				end
			end
		end
	else
		for path in pairs(memoryStore) do
			local name = path:match("/" .. folder .. "/([^/]+)%.json$")
			if name then
				table.insert(names, name)
			end
		end
	end
	table.sort(names)
	return names
end

local function encode(mode)
	local source = {}
	for flag, value in pairs(Library.Flags) do
		local isUI = flag:sub(1, 3) == "ui_"
		if not ((mode == "ui" and not isUI) or (mode == "noui" and isUI)) then
			source[flag] = value
		end
	end
	local out = {}
	for flag, value in pairs(source) do
		if typeof(value) == "Color3" then
			out[flag] = { __color = true, r = value.R, g = value.G, b = value.B }
		else
			out[flag] = value
		end
	end
	return HttpService:JSONEncode(out)
end

local function apply(json)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(data) ~= "table" then
		return false
	end
	Library.Loading = true
	for flag, value in pairs(data) do
		local setter = not Library.NoRestore[flag] and Library.Setters[flag]
		if setter then
			if type(value) == "table" and value.__color then
				value = Color3.new(value.r, value.g, value.b)
			end
			pcall(setter, value)
		end
	end
	Library.Loading = false
	return true
end

local function queueSave()
end

local function cleanName(text)
	text = tostring(text or ""):gsub("[^%w_%- ]", "")
	return text:match("^%s*(.-)%s*$")
end

function Library:SaveNow()
end

function Library:LoadAutosave()
	local data = Storage.read(Root .. "/settings.json")
	if data then
		apply(data)
	end
end

function Library:GetConfigs()
	return Storage.list()
end

function Library:SaveConfig(name)
	name = cleanName(name)
	if name == "" then
		return false
	end
	Storage.write(Root .. "/configs/" .. name .. ".json", encode("noui"))
	return true
end

function Library:LoadConfig(name)
	name = cleanName(name)
	if name == "" then
		return false
	end
	local data = Storage.read(Root .. "/configs/" .. name .. ".json")
	if not data or not apply(data) then
		return false
	end
	Library:SaveNow()
	return true
end

function Library:DeleteConfig(name)
	name = cleanName(name)
	if name == "" then
		return false
	end
	Storage.remove(Root .. "/configs/" .. name .. ".json")
	memoryStore[Root .. "/configs/" .. name .. ".json"] = nil
	return true
end

function Library:GetUIConfigs()
	return Storage.list("uiconfigs")
end

function Library:SaveUIConfig(name)
	name = cleanName(name)
	if name == "" then
		return false
	end
	Storage.write(Root .. "/uiconfigs/" .. name .. ".json", encode("ui"))
	return true
end

function Library:LoadUIConfig(name)
	name = cleanName(name)
	if name == "" then
		return false
	end
	local data = Storage.read(Root .. "/uiconfigs/" .. name .. ".json")
	if not data or not apply(data) then
		return false
	end
	Library:SaveNow()
	return true
end

function Library:DeleteUIConfig(name)
	name = cleanName(name)
	if name == "" then
		return false
	end
	Storage.remove(Root .. "/uiconfigs/" .. name .. ".json")
	memoryStore[Root .. "/uiconfigs/" .. name .. ".json"] = nil
	return true
end

local function new(class, props, parent)
	local inst = Instance.new(class)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent, transparency, color, thickness)
	return new("UIStroke", {
		Color = color or WHITE,
		Transparency = transparency,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function tween(inst, time, props, style, direction)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function set(inst, props, instant, time, style)
	if instant then
		for key, value in pairs(props) do
			inst[key] = value
		end
	else
		tween(inst, time or 0.2, props, style)
	end
end

local function lift(amount)
	return Theme.Box:Lerp(WHITE, amount)
end

local function sub()
	return Theme.Text:Lerp(Theme.Box, 0.45)
end

local function themed(fn)
	fn()
	table.insert(Library.Updaters, fn)
end

local refreshQueued = false
local function refresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		for _, fn in ipairs(Library.Updaters) do
			pcall(fn)
		end
	end)
end

local function connect(signal, fn)
	local connection = signal:Connect(fn)
	table.insert(Library.Connections, connection)
	return connection
end

local function label(parent, text, size, bold, dim)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
	themed(function()
		l.Font = Fonts[Theme.Font][bold and 2 or 1]
		l.TextColor3 = dim and sub() or Theme.Text
	end)
	return l
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function drag(area, callback, began, ended)
	local active = false
	area.InputBegan:Connect(function(input)
		if isPress(input) then
			active = true
			if began then
				began()
			end
			callback(input.Position)
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if active and isMove(input) then
			callback(input.Position)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if active and isPress(input) then
			active = false
			if ended then
				ended()
			end
		end
	end)
end

local function register(flag, default, setter)
	if not flag then
		return
	end
	Library.Flags[flag] = default
	Library.Setters[flag] = setter
end

local visTokens = setmetatable({}, { __mode = "k" })

local function rowVisible(r, height, state, instant, clip)
	visTokens[r] = (visTokens[r] or 0) + 1
	local token = visTokens[r]
	if state then
		r.Visible = true
		if instant then
			r.Size = UDim2.new(1, 0, 0, height)
			r.ClipsDescendants = clip
			return
		end
		r.ClipsDescendants = true
		tween(r, 0.38, { Size = UDim2.new(1, 0, 0, height) })
		task.delay(0.4, function()
			if visTokens[r] == token and r.Parent then
				r.ClipsDescendants = clip
			end
		end)
	else
		if instant then
			r.Size = UDim2.new(1, 0, 0, 0)
			r.Visible = false
			return
		end
		r.ClipsDescendants = true
		tween(r, 0.3, { Size = UDim2.new(1, 0, 0, 0) })
		task.delay(0.32, function()
			if visTokens[r] == token and r.Parent then
				r.Visible = false
			end
		end)
	end
end

local function protectGui(gui)
	local placed = pcall(function()
		gui.Parent = type(gethui) == "function" and gethui() or CoreGui
	end)
	if not placed or not gui.Parent then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end

local function parseBind(value)
	if typeof(value) == "EnumItem" then
		if value.EnumType == Enum.KeyCode then
			return { Kind = "Key", Value = value }
		elseif value.EnumType == Enum.UserInputType then
			return { Kind = "Mouse", Value = value }
		end
		return nil
	end
	if type(value) ~= "string" then
		return nil
	end
	local kind, name = value:match("^(%a+):(.+)$")
	if kind == "Key" then
		local ok, found = pcall(function()
			return Enum.KeyCode[name]
		end)
		if ok and found then
			return { Kind = "Key", Value = found }
		end
	elseif kind == "Mouse" then
		local ok, found = pcall(function()
			return Enum.UserInputType[name]
		end)
		if ok and found then
			return { Kind = "Mouse", Value = found }
		end
	elseif kind == "Wheel" then
		return { Kind = "Wheel", Value = name == "Up" and 1 or -1 }
	end
	return nil
end

local function bindToString(bind)
	if not bind then
		return "None"
	end
	if bind.Kind == "Key" then
		return "Key:" .. bind.Value.Name
	elseif bind.Kind == "Mouse" then
		return "Mouse:" .. bind.Value.Name
	end
	return "Wheel:" .. (bind.Value > 0 and "Up" or "Down")
end

local function bindLabel(bind)
	if not bind then
		return "None"
	end
	if bind.Kind == "Wheel" then
		return bind.Value > 0 and "WheelUp" or "WheelDown"
	end
	local name = bind.Value.Name
	if bind.Kind == "Mouse" then
		name = name:gsub("MouseButton", "MB")
		return name
	end
	if name ~= "Left" and name ~= "Right" then
		name = name:gsub("^Left", "L")
		name = name:gsub("^Right", "R")
	end
	name = name:gsub("Control", "Ctrl")
	return name
end

local function ripple(host, position)
	local size = math.max(host.AbsoluteSize.X, host.AbsoluteSize.Y) * 2.6
	local ring = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(position.X - host.AbsolutePosition.X, position.Y - host.AbsolutePosition.Y),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, host)
	corner(ring, 1000)
	tween(ring, 0.6, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 })
	task.delay(0.65, function()
		ring:Destroy()
	end)
end

local function buildPicker(parent, position, onChange)
	local h, s, v = 0, 0, 1

	local body = new("Frame", {
		Position = position,
		Size = UDim2.new(1, 0, 0, 148),
		BackgroundTransparency = 1,
	}, parent)

	local sv = new("Frame", {
		Size = UDim2.new(1, -30, 0, 114),
		BorderSizePixel = 0,
	}, body)
	corner(sv, 7)
	local whiteLayer = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, sv)
	corner(whiteLayer, 7)
	new("UIGradient", { Transparency = NumberSequence.new(0, 1) }, whiteLayer)
	local blackLayer = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BorderSizePixel = 0,
	}, sv)
	corner(blackLayer, 7)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
	}, blackLayer)
	local svCursor = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, sv)
	corner(svCursor, 6)
	stroke(svCursor, 0, WHITE, 2)

	local hue = new("Frame", {
		Position = UDim2.new(1, -20, 0, 0),
		Size = UDim2.fromOffset(20, 114),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, body)
	corner(hue, 7)
	local stops = {}
	for i = 0, 6 do
		table.insert(stops, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
	end
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(stops) }, hue)
	local hueCursor = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 4, 0, 4),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, hue)
	corner(hueCursor, 2)
	stroke(hueCursor, 0.4, BLACK)

	local hex = new("TextBox", {
		Position = UDim2.fromOffset(0, 122),
		Size = UDim2.new(1, 0, 0, 26),
		BorderSizePixel = 0,
		Text = "",
		PlaceholderText = "#FFFFFF",
		ClearTextOnFocus = false,
		TextSize = 13,
	}, body)
	corner(hex, 7)
	local hexEdge = stroke(hex, 0.92)
	themed(function()
		hex.Font = Fonts[Theme.Font][1]
		hex.TextColor3 = Theme.Text
		hex.PlaceholderColor3 = sub()
		hex.BackgroundColor3 = lift(0.1)
		hex.BackgroundTransparency = 0.3
	end)
	hex.Focused:Connect(function()
		tween(hexEdge, 0.2, { Color = Theme.Accent, Transparency = 0.35 })
	end)

	local function toHex(color)
		return string.format(
			"#%02X%02X%02X",
			math.round(color.R * 255),
			math.round(color.G * 255),
			math.round(color.B * 255)
		)
	end

	local function render()
		local color = Color3.fromHSV(h, s, v)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(0.5, h)
		hex.Text = toHex(color)
		return color
	end
	render()

	local function commit()
		onChange(render())
	end

	local picker = {}
	function picker:Load(color)
		h, s, v = color:ToHSV()
		render()
	end

	drag(sv, function(position)
		s = math.clamp((position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
		v = 1 - math.clamp((position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		commit()
	end, function()
		tween(svCursor, 0.2, { Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Back)
	end, function()
		tween(svCursor, 0.25, { Size = UDim2.fromOffset(12, 12) }, Enum.EasingStyle.Back)
	end)
	drag(hue, function(position)
		h = math.clamp((position.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 0.999)
		commit()
	end)

	hex.FocusLost:Connect(function()
		tween(hexEdge, 0.25, { Color = WHITE, Transparency = 0.92 })
		local text = hex.Text:gsub("#", "")
		local n = #text == 6 and tonumber(text, 16)
		if n then
			h, s, v = Color3.fromRGB(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256):ToHSV()
			commit()
		else
			render()
		end
	end)

	return picker
end

local function makeButton(parent, text, callback)
	local hover = false

	local b = new("Frame", { BorderSizePixel = 0, ClipsDescendants = true }, parent)
	corner(b, 9)
	local edge = stroke(b, 0.9)
	local press = new("UIScale", {}, b)

	local sheen = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, b)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(0.86, 1),
	}, sheen)
	corner(sheen, 9)

	local caption = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextSize = 13,
		ZIndex = 3,
	}, b)

	local underline = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0, 0, 0, 2),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, b)

	local hit = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
	}, b)

	themed(function()
		caption.Font = Fonts[Theme.Font][1]
		caption.TextColor3 = Theme.Text
		underline.BackgroundColor3 = Theme.Accent
		b.BackgroundColor3 = lift(hover and 0.14 or 0.08)
		b.BackgroundTransparency = 0.25
		edge.Color = hover and Theme.Accent or WHITE
		edge.Transparency = hover and 0.35 or 0.9
	end)

	hit.MouseEnter:Connect(function()
		hover = true
		tween(b, 0.2, { BackgroundColor3 = lift(0.14) })
		tween(edge, 0.2, { Color = Theme.Accent, Transparency = 0.35 })
		tween(underline, 0.35, { Size = UDim2.new(0.5, 0, 0, 2) })
	end)
	hit.MouseLeave:Connect(function()
		hover = false
		tween(b, 0.25, { BackgroundColor3 = lift(0.08) })
		tween(edge, 0.25, { Color = WHITE, Transparency = 0.9 })
		tween(underline, 0.25, { Size = UDim2.new(0, 0, 0, 2) })
		tween(press, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	hit.InputBegan:Connect(function(input)
		if isPress(input) then
			tween(press, 0.08, { Scale = 0.97 })
			ripple(b, input.Position)
		end
	end)
	hit.InputEnded:Connect(function(input)
		if isPress(input) then
			tween(press, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
	hit.MouseButton1Click:Connect(function()
		if callback then
			task.spawn(callback)
		end
	end)
	return b
end

local mobileGui
local mobileSlots = 0

function Library:MobileButton(title, imageId, handlers)
	if not mobileGui then
		mobileGui = new("ScreenGui", {
			Name = HttpService:GenerateGUID(false),
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 997,
		})
		protectGui(mobileGui)
		table.insert(Library.OnUnload, function()
			if mobileGui then
				mobileGui:Destroy()
				mobileGui = nil
			end
		end)
	end
	mobileSlots += 1
	local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 400)
	local slot = mobileSlots - 1
	local btn = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(view.X - 48 - math.floor(slot / 4) * 72, 60 + (slot % 4) * 84),
		Size = UDim2.fromOffset(54, 54),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Active = true,
	}, mobileGui)
	corner(btn, 27)
	local edge = stroke(btn, 0.4, WHITE, 2)
	local scale = new("UIScale", {}, btn)
	new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. imageId,
	}, btn)
	local caption = label(btn, title, 11, true)
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.Position = UDim2.new(0.5, 0, 1, 2)
	caption.Size = UDim2.fromOffset(84, 14)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.TextStrokeTransparency = 0.6
	themed(function()
		btn.BackgroundColor3 = Theme.Box
	end)

	local object = { Frame = btn }
	local active = false
	function object:SetVisible(state)
		btn.Visible = state
	end
	function object:SetActive(state)
		active = state
		tween(edge, 0.2, { Color = state and Theme.Accent or WHITE, Transparency = state and 0 or 0.4 })
	end
	function object:Destroy()
		btn:Destroy()
	end
	object:SetVisible(true)


	local current, pressedAt, startPos, startOffset, dragging = nil, 0, Vector2.zero, Vector2.zero, false
	btn.InputBegan:Connect(function(input)
		if not isPress(input) or current then
			return
		end
		current = input
		pressedAt = os.clock()
		startPos = Vector2.new(input.Position.X, input.Position.Y)
		startOffset = Vector2.new(btn.Position.X.Offset, btn.Position.Y.Offset)
		dragging = false
		if handlers.IsHold and handlers.IsHold() and handlers.Down then
			handlers.Down()
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if not current or not isMove(input) then
			return
		end
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if not dragging then
			if os.clock() - pressedAt >= 0.45 and (pos - startPos).Magnitude > 10 then
				dragging = true
				startPos = pos
				if handlers.IsHold and handlers.IsHold() and handlers.Up then
					handlers.Up()
				end
				tween(scale, 0.2, { Scale = 1.15 }, Enum.EasingStyle.Back)
			end
		else
			local size = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 400)
			local goal = startOffset + (pos - startPos)
			btn.Position = UDim2.fromOffset(math.clamp(goal.X, 30, size.X - 30), math.clamp(goal.Y, 30, size.Y - 40))
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if not current or not isPress(input) then
			return
		end
		local wasDragging = dragging
		local held = os.clock() - pressedAt
		current, dragging = nil, false
		tween(scale, 0.2, { Scale = 1 })
		if wasDragging then
			return
		end
		if handlers.IsHold and handlers.IsHold() then
			if handlers.Up then
				handlers.Up()
			end
		elseif held < 0.45 and handlers.Tap then
			handlers.Tap()
		end
	end)
	return object
end

function Library:CreateWindow(config)
	config = config or {}
	Storage.init()

	local gui = new("ScreenGui", {
		Name = HttpService:GenerateGUID(false),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
	})
	protectGui(gui)
	self.Gui = gui

	local window = { Tabs = {}, Visible = false }
	local W, H = 860, 560

	local function screen()
		local size = gui.AbsoluteSize
		if size.X < 10 then
			size = workspace.CurrentCamera.ViewportSize
		end
		return size
	end

	local function fit()
		local size = screen()
		return math.min(1, (size.X - 40) / W, (size.Y - 40) / H) * (IsMobile and 0.85 or 1)
	end

	local main = new("CanvasGroup", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Active = true,
	}, gui)
	local scale = new("UIScale", { Scale = 0.94 }, main)
	local mainCorner = corner(main, 18)
	local mainStroke = stroke(main, 0.86)

	new("ImageLabel", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. Assets.Background,
		ScaleType = Enum.ScaleType.Crop,
	}, main)

	local dim = new("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, main)
	themed(function()
		dim.BackgroundColor3 = Theme.Box
		dim.BackgroundTransparency = Theme.Dim
	end)

	local wallpaper = main:FindFirstChild("Background")
	themed(function()
		mainCorner.CornerRadius = UDim.new(0, Theme.Radius)
		mainStroke.Color = Theme.Outline
		mainStroke.Transparency = Theme.OutlineTrans
		mainStroke.Thickness = Theme.OutlineThick
		if wallpaper then
			wallpaper.Visible = Theme.Wallpaper
		end
	end)
	themed(function()
		if window.Visible then
			tween(scale, 0.25, { Scale = fit() * Theme.UIScale })
		end
	end)

	local top = new("Frame", {
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundTransparency = 1,
	}, main)
	new("ImageLabel", {
		Position = UDim2.fromOffset(18, 13),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. Assets.Logo,
	}, top)
	local title = label(top, config.Title or "curzs V3", 18, true)
	title.Position = UDim2.fromOffset(62, 0)
	title.Size = UDim2.new(1, -80, 1, 0)

	local line = new("Frame", {
		Position = UDim2.new(0, 18, 1, -1),
		Size = UDim2.new(1, -36, 0, 1),
		BorderSizePixel = 0,
	}, top)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, line)
	themed(function()
		line.BackgroundColor3 = Theme.Accent
	end)


	local strip = new("Frame", {
		Position = UDim2.fromOffset(18, 66),
		Size = UDim2.new(1, -36, 0, 44),
		BackgroundTransparency = 1,
	}, main)

	local content = new("Frame", {
		Position = UDim2.fromOffset(18, 116),
		Size = UDim2.new(1, -36, 1, -202),
		BackgroundTransparency = 1,
	}, main)

	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(0, 60),
		AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0,
	}, main)
	corner(bar, 30)
	local barStroke = stroke(bar, 0.88)
	themed(function()
		bar.BackgroundColor3 = Theme.Box
		bar.BackgroundTransparency = 0.25
		barStroke.Color = Theme.Edge
		barStroke.Transparency = Theme.EdgeTrans
	end)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 7),
		PaddingRight = UDim.new(0, 7),
	}, bar)

	local target = screen() / 2
	local current = target
	main.Position = UDim2.fromOffset(current.X, current.Y)

	connect(RunService.RenderStepped, function(dt)
		if (current - target).Magnitude < 0.05 then
			if current ~= target then
				current = target
				main.Position = UDim2.fromOffset(current.X, current.Y)
			end
			return
		end
		current = current:Lerp(target, 1 - math.exp(-dt * 12))
		main.Position = UDim2.fromOffset(current.X, current.Y)
	end)

	local dragging = false
	local dragStart = Vector2.zero
	local startTarget = target

	top.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startTarget = target
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragging and isMove(input) then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			local size = screen()
			target = Vector2.new(
				math.clamp(startTarget.X + delta.X, 80, size.X - 80),
				math.clamp(startTarget.Y + delta.Y, 30, size.Y - 30)
			)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if isPress(input) then
			dragging = false
		end
	end)

	function window:SetVisible(state)
		window.Visible = state
		local base = fit() * Theme.UIScale
		if state then
			main.Visible = true
			scale.Scale = base * 0.92
			bar.Position = UDim2.new(0.5, 0, 1, 30)
			tween(main, 0.35, { GroupTransparency = 0 })
			tween(scale, 0.5, { Scale = base }, Enum.EasingStyle.Back)
			task.delay(0.12, function()
				tween(bar, 0.55, { Position = UDim2.new(0.5, 0, 1, -16) }, Enum.EasingStyle.Back)
			end)
		else
			tween(main, 0.22, { GroupTransparency = 1 })
			tween(scale, 0.25, { Scale = base * 0.94 })
			task.delay(0.25, function()
				if not window.Visible then
					main.Visible = false
				end
			end)
		end
	end

	function window:Toggle()
		window:SetVisible(not window.Visible)
	end

	if IsMobile then
		Library:MobileButton("Menu", "74522573654858", {
			Tap = function()
				window:Toggle()
			end,
		})
	end


	local toasts = new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.fromOffset(264, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, gui)
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, toasts)

	local notifyTemplate = new("Sound", {
		Name = "CurzsNotifySound",
		SoundId = "rbxassetid://" .. Assets.NotifySound,
		Volume = 0.6,
	}, SoundService)
	Library.NotifyTemplate = notifyTemplate

	local soundWarned = false
	local function warnSound()
		if not soundWarned then
			soundWarned = true
			warn("[curzs V3] Notify sound " .. Assets.NotifySound .. " did not load (the audio may be private or not allowed in this game).")
		end
	end


	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ notifyTemplate })
		end)
	end)

	local function playNotifySound()
		if not Theme.Sound then
			return
		end
		task.spawn(function()
			local ok = pcall(function()
				local snd = notifyTemplate:Clone()
				snd.Volume = math.max(Theme.Volume, 0.05)
				snd.Parent = SoundService

				local waited = 0
				while not snd.IsLoaded and waited < 4 do
					task.wait(0.05)
					waited += 0.05
				end
				if not snd.IsLoaded then
					warnSound()
					snd:Destroy()
					return
				end

				snd:Play()
				task.wait(0.15)
				if not snd.IsPlaying then
					pcall(function()
						SoundService:PlayLocalSound(snd)
					end)
				end
				task.delay(math.max(snd.TimeLength, 1) + 1, function()
					snd:Destroy()
				end)
			end)
			if not ok then
				warnSound()
			end
		end)
	end

	function Library:Notify(text, duration)
		duration = duration or Theme.NotifyTime
		if #toasts:GetChildren() > 7 then
			return
		end
		playNotifySound()

		local holder = new("Frame", {
			Size = UDim2.fromOffset(264, 46),
			BackgroundTransparency = 1,
		}, toasts)

		local toast = new("CanvasGroup", {
			Position = UDim2.fromOffset(44, 0),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Box,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			GroupTransparency = 1,
		}, holder)
		corner(toast, 14)
		stroke(toast, 0.9)

		local icon = new("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, -3),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. Assets.NotifyIcon,
			ScaleType = Enum.ScaleType.Fit,
		}, toast)
		local iconScale = new("UIScale", { Scale = 0.4 }, icon)
		tween(iconScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)

		new("TextLabel", {
			Position = UDim2.fromOffset(48, 0),
			Size = UDim2.new(1, -62, 1, -8),
			BackgroundTransparency = 1,
			Text = text,
			TextSize = 13,
			Font = Fonts[Theme.Font][1],
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, toast)

		local track = new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 14, 1, -7),
			Size = UDim2.new(1, -28, 0, 2),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
		}, toast)
		corner(track, 1)
		local fill = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
		}, track)
		corner(fill, 1)

		tween(toast, 0.5, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint)
		tween(fill, duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)

		task.delay(duration, function()
			tween(toast, 0.35, { GroupTransparency = 1, Position = UDim2.fromOffset(30, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.35)
			tween(holder, 0.25, { Size = UDim2.fromOffset(264, 0) })
			task.wait(0.27)
			holder:Destroy()
		end)
	end


	local function showPage(subTab)
		local page = subTab.Page
		subTab.Shown = true
		page.Visible = true
		page.GroupTransparency = 1
		page.Position = UDim2.fromOffset(0, 12)
		tween(page, 0.45, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
	end

	local function hidePage(subTab)
		if not subTab.Shown then
			return
		end
		subTab.Shown = false
		tween(subTab.Page, 0.15, { GroupTransparency = 1 })
		task.delay(0.15, function()
			if not subTab.Shown then
				subTab.Page.Visible = false
			end
		end)
	end

	function window:Select(tab)
		if window.Current == tab then
			return
		end
		local old = window.Current
		window.Current = tab
		if old then
			old.Style()
			if old.CurrentSub then
				hidePage(old.CurrentSub)
			end
			tween(old.SubBar, 0.15, { GroupTransparency = 1 })
			task.delay(0.15, function()
				if window.Current ~= old then
					old.SubBar.Visible = false
				end
			end)
		end
		tab.SubBar.Visible = true
		tab.SubBar.GroupTransparency = 1
		tab.SubBar.Position = UDim2.fromOffset(0, 8)
		tween(tab.SubBar, 0.45, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
		if tab.CurrentSub then
			showPage(tab.CurrentSub)
		end
		tab.Style()
	end

	function window:AddTab(name, assetId)
		local tab = { Name = name, Subs = {}, SubX = 0 }
		local hovered = false

		local btn = new("TextButton", {
			Size = UDim2.fromOffset(46, 46),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = #window.Tabs + 1,
		}, bar)
		corner(btn, 23)

		local icon = new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 23, 0.5, 0),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. assetId,
		}, btn)

		local caption = label(btn, name, 13, true)
		caption.AnchorPoint = Vector2.new(0, 0.5)
		caption.Position = UDim2.new(0, 50, 0.5, 0)
		caption.Size = UDim2.new(1, -56, 0, 18)
		caption.TextTransparency = 1
		caption.TextTruncate = Enum.TextTruncate.None

		local function style(instant)
			local selected = window.Current == tab
			btn.BackgroundColor3 = Theme.Accent
			set(btn, { BackgroundTransparency = selected and 0.8 or (hovered and 0.9 or 1) }, instant)
			set(icon, { ImageTransparency = (selected or hovered) and 0 or 0.4 }, instant)
		end
		tab.Style = style
		themed(function()
			style(true)
		end)

		btn.MouseEnter:Connect(function()
			hovered = true
			local width = TextService:GetTextSize(name, 13, Fonts[Theme.Font][2], Vector2.new(300, 20)).X
			tween(btn, 0.4, { Size = UDim2.fromOffset(50 + width + 20, 46) }, Enum.EasingStyle.Back)
			tween(icon, 0.35, { Size = UDim2.fromOffset(28, 28) }, Enum.EasingStyle.Back)
			tween(caption, 0.3, { TextTransparency = 0, Position = UDim2.new(0, 46, 0.5, 0) })
			style()
		end)
		btn.MouseLeave:Connect(function()
			hovered = false
			tween(btn, 0.3, { Size = UDim2.fromOffset(46, 46) })
			tween(icon, 0.25, { Size = UDim2.fromOffset(24, 24) })
			tween(caption, 0.15, { TextTransparency = 1, Position = UDim2.new(0, 50, 0.5, 0) })
			style()
		end)
		btn.MouseButton1Click:Connect(function()
			window:Select(tab)
		end)


		local subBar = new("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			GroupTransparency = 1,
		}, strip)
		tab.SubBar = subBar

		local pill = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.fromOffset(0, 40),
			AutomaticSize = Enum.AutomaticSize.X,
			BorderSizePixel = 0,
		}, subBar)
		corner(pill, 20)
		local pillStroke = stroke(pill, 0.88)
		themed(function()
			pill.BackgroundColor3 = Theme.Box
			pill.BackgroundTransparency = 0.25
			pillStroke.Color = Theme.Edge
			pillStroke.Transparency = Theme.EdgeTrans
		end)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, pill)
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		}, pill)

		local function selectSub(subTab)
			if tab.CurrentSub == subTab then
				return
			end
			local old = tab.CurrentSub
			tab.CurrentSub = subTab
			if old then
				old.Style()
				hidePage(old)
			end
			subTab.Style()
			if window.Current == tab then
				showPage(subTab)
			end
		end
		tab.SelectSub = selectSub

		function tab:AddSubTab(subName, iconId)
			local subTab = { Name = subName, Next = 1, Sections = {}, Shown = false }
			local subHovered = false

			local textWidth = TextService:GetTextSize(subName, 13, Fonts[Theme.Font][2], Vector2.new(300, 20)).X
			local openWidth = 34 + textWidth + 14

			local sbtn = new("TextButton", {
				Size = UDim2.fromOffset(32, 32),
				Text = "",
				AutoButtonColor = false,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				LayoutOrder = #tab.Subs + 1,
			}, pill)
			corner(sbtn, 16)

			local sicon = new("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 16, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Image = "rbxassetid://" .. (iconId or Assets.SubTab),
			}, sbtn)

			local scaption = label(sbtn, subName, 13, true)
			scaption.AnchorPoint = Vector2.new(0, 0.5)
			scaption.Position = UDim2.new(0, 38, 0.5, 0)
			scaption.Size = UDim2.new(1, -40, 0, 18)
			scaption.TextTransparency = 1
			scaption.TextTruncate = Enum.TextTruncate.None

			local function substyle(instant)
				local selected = tab.CurrentSub == subTab
				local open = selected or subHovered
				local iconSize = open and 18 or 16
				sbtn.BackgroundColor3 = Theme.Accent
				set(sbtn, { BackgroundTransparency = selected and 0.8 or (subHovered and 0.9 or 1) }, instant, 0.25)
				set(sbtn, { Size = UDim2.fromOffset(open and openWidth or 32, 32) }, instant, 0.4, Enum.EasingStyle.Back)
				set(sicon, { ImageTransparency = open and 0 or 0.4 }, instant, 0.25)
				set(sicon, { Size = UDim2.fromOffset(iconSize, iconSize) }, instant, 0.35, Enum.EasingStyle.Back)
				set(scaption, {
					TextTransparency = open and 0 or 1,
					Position = open and UDim2.new(0, 34, 0.5, 0) or UDim2.new(0, 38, 0.5, 0),
				}, instant, 0.3)
			end
			subTab.Style = substyle
			themed(function()
				substyle(true)
			end)

			sbtn.MouseEnter:Connect(function()
				subHovered = true
				substyle()
			end)
			sbtn.MouseLeave:Connect(function()
				subHovered = false
				substyle()
			end)
			sbtn.MouseButton1Click:Connect(function()
				selectSub(subTab)
			end)


			local page = new("CanvasGroup", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = false,
				GroupTransparency = 1,
			}, content)
			subTab.Page = page

			local scroller = new("ScrollingFrame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 2,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
			}, page)
			themed(function()
				scroller.ScrollBarImageColor3 = Theme.Accent
			end)
			new("UIPadding", {
				PaddingRight = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 8),
			}, scroller)

			local columns = {}
			local columnCount = { 0, 0 }
			for i = 1, 2 do
				local column = new("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.new(i == 1 and 0 or 0.5, i == 1 and 0 or 8, 0, 0),
					Size = UDim2.new(0.5, -8, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				}, scroller)
				new("UIListLayout", {
					Padding = UDim.new(0, 16),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}, column)
				columns[i] = column
			end

			function subTab:AddSection(title, side)
				local index = side or subTab.Next
				subTab.Next = subTab.Next == 1 and 2 or 1
				columnCount[index] += 1

				local holder = new("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = columnCount[index],
				}, columns[index])
				table.insert(subTab.Sections, holder)
				new("UIPadding", {
					PaddingTop = UDim.new(0, 1),
					PaddingBottom = UDim.new(0, 1),
					PaddingLeft = UDim.new(0, 1),
					PaddingRight = UDim.new(0, 1),
				}, holder)
				new("UIListLayout", {
					Padding = UDim.new(0, 7),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}, holder)

				local heading = label(holder, title, 13, true)
				heading.Size = UDim2.new(1, 0, 0, 18)
				heading.LayoutOrder = 1
				new("UIPadding", { PaddingLeft = UDim.new(0, 4) }, heading)

				local box = new("Frame", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BorderSizePixel = 0,
					LayoutOrder = 2,
				}, holder)
				corner(box, 12)
				local boxStroke = stroke(box, 0.9)
				themed(function()
					box.BackgroundColor3 = Theme.Box
					box.BackgroundTransparency = Theme.BoxTrans
					boxStroke.Color = Theme.Edge
					boxStroke.Transparency = Theme.EdgeTrans
				end)
				new("UIPadding", {
					PaddingTop = UDim.new(0, 12),
					PaddingBottom = UDim.new(0, 12),
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}, box)
				new("UIListLayout", {
					Padding = UDim.new(0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}, box)

				local sec = {}
				local count = 0
				local flagPrefix = tab.Name .. "." .. subName .. "." .. title

				local function row(height)
					count += 1
					return new("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, height),
						LayoutOrder = count,
					}, box)
				end

				local function flagFor(opts)
					if opts.Flag == false then
						return nil
					end
					return opts.Flag or (flagPrefix .. "." .. opts.Name)
				end

				function sec:AddLabel(text)
					local r = row(20)
					local l = label(r, text, 13, false, true)
					l.Size = UDim2.fromScale(1, 1)
					local object = {}
					function object:Set(value)
						l.Text = value
					end
					return object
				end

				function sec:AddButton(opts)
					local r = row(36)
					local b = makeButton(r, opts.Name, opts.Callback)
					b.Size = UDim2.fromScale(1, 1)
				end

				function sec:AddButtons(list)
					local r = row(36)
					new("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}, r)
					local n = #list
					for i, item in ipairs(list) do
						local b = makeButton(r, item.Name, item.Callback)
						b.LayoutOrder = i
						b.Size = UDim2.new(1 / n, -8 * (n - 1) / n, 1, 0)
					end
				end







				function sec:AddToggle(opts)
					local flag = flagFor(opts)
					local state = opts.Default == true
					local object = {}
					local kb = opts.Keybind
					local afterSet = nil

					local r = row(30)
					local head = r
					if kb then
						r.ClipsDescendants = true
						head = new("Frame", {
							Size = UDim2.new(1, 0, 0, 30),
							BackgroundTransparency = 1,
						}, r)
					end

					local l = label(head, opts.Name, 13)
					l.Size = UDim2.new(1, kb and -184 or -58, 1, 0)
					local track = new("TextButton", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(44, 24),
						Text = "",
						AutoButtonColor = false,
						BorderSizePixel = 0,
					}, head)
					corner(track, 12)
					local edge = stroke(track, 0.92)
					local knob = new("Frame", {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 4, 0.5, 0),
						Size = UDim2.fromOffset(16, 16),
						BackgroundColor3 = WHITE,
						BorderSizePixel = 0,
					}, track)
					corner(knob, 8)

					local pressedKnob = false
					local running = {}

					local function play(inst, time, props, style, instant)
						local old = running[inst]
						if old then
							old:Cancel()
							running[inst] = nil
						end
						if instant then
							for key, value in pairs(props) do
								inst[key] = value
							end
						else
							running[inst] = tween(inst, time, props, style)
						end
					end

					local function knobGoal()
						local w = pressedKnob and 22 or 16
						return {
							Size = UDim2.fromOffset(w, 16),
							Position = state and UDim2.new(1, -4 - w, 0.5, 0) or UDim2.new(0, 4, 0.5, 0),
						}
					end

					local function paint(instant)
						play(track, 0.3, { BackgroundColor3 = state and Theme.Accent or lift(0.16) }, nil, instant)
						play(edge, 0.3, {
							Color = state and Theme.Accent or WHITE,
							Transparency = state and 0.5 or 0.92,
						}, nil, instant)
						play(knob, 0.4, knobGoal(), Enum.EasingStyle.Back, instant)
					end
					themed(function()
						paint(true)
					end)

					function object:Set(value)
						state = value == true
						if flag then
							Library.Flags[flag] = state
						end
						paint(false)
						queueSave()
						if afterSet then
							afterSet()
						end
						if opts.Callback then
							task.spawn(opts.Callback, state)
						end
					end
					function object:Get()
						return state
					end

					function object:IsActive()
						return state and (object.KeyActive == nil or object.KeyActive)
					end
					function object:SetVisible(visible, instant)
						rowVisible(r, 30, visible, instant, kb ~= nil)
					end

					track.InputBegan:Connect(function(input)
						if isPress(input) then
							pressedKnob = true
							play(knob, 0.15, knobGoal())
						end
					end)
					track.InputEnded:Connect(function(input)
						if isPress(input) then
							pressedKnob = false
							play(knob, 0.3, knobGoal(), Enum.EasingStyle.Back)
						end
					end)
					track.MouseLeave:Connect(function()
						pressedKnob = false
						play(knob, 0.3, knobGoal(), Enum.EasingStyle.Back)
					end)
					track.Activated:Connect(function()
						object:Set(not state)
					end)
					register(flag, state, function(value)
						object:Set(value)
					end)

					if kb then
						local MODES = { "Toggle", "Always", "Hold" }
						local bind = parseBind(kb.Default)
						local mode = table.find(MODES, kb.Mode) and kb.Mode or "Toggle"
						local listening, menuOpen = false, false
						local held = false
						local skipClick, skipMenu = false, false
						local wheelStamp = 0
						local keyActive = mode ~= "Hold"
						local lastEffective = false
						local refreshEffective
						local mobileBtn
						local keyFlag = flag and (flag .. "_key")
						local modeFlag = flag and (flag .. "_mode")

						local chip = new("TextButton", {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -52, 0.5, 0),
							Size = UDim2.fromOffset(120, 24),
							BorderSizePixel = 0,
							TextSize = 12,
							AutoButtonColor = false,
							Text = "",
							TextTruncate = Enum.TextTruncate.AtEnd,
						}, head)
						corner(chip, 7)
						local chipEdge = stroke(chip, 0.92)

						local function paintChip()
							chip.Text = listening and "..." or ((IsMobile and "Button" or bindLabel(bind)) .. " | " .. mode)
							chip.Font = Fonts[Theme.Font][1]
							chip.TextColor3 = listening and Theme.Accent or (keyActive and Theme.Text or sub())
							chip.BackgroundColor3 = lift(0.1)
							chip.BackgroundTransparency = 0.3
							chipEdge.Color = (listening or menuOpen) and Theme.Accent or WHITE
							chipEdge.Transparency = (listening or menuOpen) and 0.35 or 0.92
						end
						themed(paintChip)


						function refreshEffective()
							object.KeyActive = keyActive
							local effective = state and keyActive
							if effective ~= lastEffective then
								lastEffective = effective
								if kb.OnActive then
									task.spawn(kb.OnActive, effective)
								end
							end
							paintChip()
						end
						local baseRefresh = refreshEffective
						refreshEffective = function()
							baseRefresh()
							if mobileBtn then
								mobileBtn:SetVisible(state)
								mobileBtn:SetActive(state and keyActive)
							end
						end
						afterSet = refreshEffective
						object.KeyActive = keyActive


						local menu = new("Frame", {
							Position = UDim2.fromOffset(0, 36),
							Size = UDim2.new(1, 0, 0, 30),
							BorderSizePixel = 0,
							BackgroundTransparency = 0.3,
						}, r)
						corner(menu, 9)
						stroke(menu, 0.92)
						new("UIPadding", {
							PaddingTop = UDim.new(0, 3),
							PaddingBottom = UDim.new(0, 3),
							PaddingLeft = UDim.new(0, 3),
							PaddingRight = UDim.new(0, 3),
						}, menu)
						themed(function()
							menu.BackgroundColor3 = lift(0.08)
						end)
						local modePill = new("Frame", {
							Size = UDim2.fromScale(1 / 3, 1),
							BorderSizePixel = 0,
						}, menu)
						corner(modePill, 7)
						themed(function()
							modePill.BackgroundColor3 = Theme.Accent
						end)

						local modeButtons = {}
						local setMenu
						for i, name in ipairs(MODES) do
							local b = new("TextButton", {
								Position = UDim2.fromScale((i - 1) / 3, 0),
								Size = UDim2.fromScale(1 / 3, 1),
								BackgroundTransparency = 1,
								AutoButtonColor = false,
								Text = name,
								TextSize = 12,
							}, menu)
							modeButtons[name] = b
							b.MouseButton1Click:Connect(function()
								object:SetMode(name)
								setMenu(false)
							end)
						end

						local function paintMenu(instant)
							local index = table.find(MODES, mode) or 1
							set(modePill, { Position = UDim2.fromScale((index - 1) / 3, 0) }, instant, 0.35)
							for name, b in pairs(modeButtons) do
								local on = name == mode
								b.Font = Fonts[Theme.Font][on and 2 or 1]
								set(b, { TextColor3 = on and WHITE or sub() }, instant, 0.25)
							end
						end
						themed(function()
							paintMenu(true)
						end)

						setMenu = function(state2)
							menuOpen = state2
							tween(r, 0.35, { Size = UDim2.new(1, 0, 0, state2 and 66 or 30) })
							if state2 then
								menu.BackgroundTransparency = 1
								modePill.BackgroundTransparency = 1
								tween(menu, 0.3, { BackgroundTransparency = 0.3 })
								tween(modePill, 0.3, { BackgroundTransparency = 0 })
								for i, name in ipairs(MODES) do
									local b = modeButtons[name]
									b.TextTransparency = 1
									task.delay(0.05 * (i - 1) + 0.05, function()
										tween(b, 0.25, { TextTransparency = 0 })
									end)
								end
							end
							paintChip()
						end

						function object:SetBind(newBind)
							bind = newBind
							if keyFlag then
								Library.Flags[keyFlag] = bindToString(bind)
							end

							if not bind and mode ~= "Hold" then
								keyActive = true
							end
							refreshEffective()
							queueSave()
						end
						function object:SetMode(newMode)
							if not table.find(MODES, newMode) then
								return
							end
							local previous = mode
							mode = newMode
							if modeFlag then
								Library.Flags[modeFlag] = mode
							end
							held = false
							if mode == "Always" then
								keyActive = true
							elseif mode == "Hold" then
								keyActive = false
							elseif previous == "Hold" then
								keyActive = true
							end
							paintMenu(false)
							refreshEffective()
							queueSave()
						end
						function object:GetBind()
							return bind
						end
						function object:GetMode()
							return mode
						end

						local function matches(input)
							if not bind then
								return false
							end
							if bind.Kind == "Key" then
								return input.KeyCode == bind.Value
							elseif bind.Kind == "Mouse" then
								return input.UserInputType == bind.Value
							end
							return false
						end

						local function pressed()
							held = true
							if mode == "Toggle" then
								keyActive = not keyActive
							else
								keyActive = true
							end
							refreshEffective()
							if kb.OnPress then
								task.spawn(kb.OnPress, keyActive)
							end
						end

						if IsMobile then
							mobileBtn = Library:MobileButton(kb.Title or opts.Name, kb.Image or "80066181348863", {
								IsHold = function()
									return mode == "Hold"
								end,
								Down = function()
									pressed()
								end,
								Up = function()
									held = false
									if mode == "Hold" then
										keyActive = false
										refreshEffective()
									end
								end,
								Tap = function()
									pressed()
								end,
							})
							mobileBtn:SetVisible(state)
						end

						chip.MouseButton1Click:Connect(function()
							if IsMobile then
								setMenu(not menuOpen)
								return
							end
							if skipClick then
								skipClick = false
								return
							end
							listening = true
							paintChip()
						end)
						chip.MouseButton2Click:Connect(function()
							if skipMenu then
								skipMenu = false
								return
							end
							if listening then
								return
							end
							setMenu(not menuOpen)
						end)

						connect(UserInputService.InputBegan, function(input, processed)
							if listening then
								local t = input.UserInputType
								local captured, newBind = false, nil
								if t == Enum.UserInputType.Keyboard then
									if input.KeyCode == Enum.KeyCode.Escape then
										listening = false
										paintChip()
										return
									elseif input.KeyCode == Enum.KeyCode.Backspace then
										captured = true
									else
										captured, newBind = true, { Kind = "Key", Value = input.KeyCode }
									end
								elseif
									t == Enum.UserInputType.MouseButton1
									or t == Enum.UserInputType.MouseButton2
									or t == Enum.UserInputType.MouseButton3
								then
									captured, newBind = true, { Kind = "Mouse", Value = t }
									if t == Enum.UserInputType.MouseButton1 then
										skipClick = true
										task.delay(1, function()
											skipClick = false
										end)
									elseif t == Enum.UserInputType.MouseButton2 then
										skipMenu = true
										task.delay(1, function()
											skipMenu = false
										end)
									end
								elseif t.Name:find("^Gamepad") and input.KeyCode ~= Enum.KeyCode.Unknown then
									captured, newBind = true, { Kind = "Key", Value = input.KeyCode }
								end
								if captured then
									listening = false
									object:SetBind(newBind)
								end
								return
							end
							if processed or not bind then
								return
							end
							if matches(input) then
								pressed()
							end
						end)
						connect(UserInputService.InputEnded, function(input)
							if held and bind and bind.Kind ~= "Wheel" and matches(input) then
								held = false
								if mode == "Hold" then
									keyActive = false
									refreshEffective()
								end
							end
						end)
						connect(UserInputService.InputChanged, function(input, processed)
							if input.UserInputType ~= Enum.UserInputType.MouseWheel then
								return
							end
							local dir = input.Position.Z > 0 and 1 or -1
							if listening then
								listening = false
								object:SetBind({ Kind = "Wheel", Value = dir })
								return
							end
							if processed or not bind or bind.Kind ~= "Wheel" or bind.Value ~= dir then
								return
							end
							pressed()
							held = false
							if mode == "Hold" then

								local stamp = os.clock()
								wheelStamp = stamp
								task.delay(0.25, function()
									if wheelStamp == stamp then
										keyActive = false
										refreshEffective()
									end
								end)
							end
						end)

						if keyFlag then
							register(keyFlag, bindToString(bind), function(value)
								object:SetBind(parseBind(value))
							end)
							register(modeFlag, mode, function(value)
								object:SetMode(value)
							end)
						end
						paintMenu(true)
					end

					return object
				end

				function sec:AddSlider(opts)
					local flag = flagFor(opts)
					local min, max = opts.Min or 0, opts.Max or 100
					local step = opts.Increment or 1
					local suffix = opts.Suffix == nil and "%" or opts.Suffix
					local value = math.clamp(opts.Default or min, min, max)
					local object = {}
					local sliding, hovering = false, false

					local r = row(48)
					local l = label(r, opts.Name, 13)
					l.Size = UDim2.new(1, -68, 0, 20)
					local readout = label(r, "", 13, true, true)
					readout.AnchorPoint = Vector2.new(1, 0)
					readout.Position = UDim2.new(1, 0, 0, 0)
					readout.Size = UDim2.fromOffset(64, 20)
					readout.TextXAlignment = Enum.TextXAlignment.Right

					local hit = new("TextButton", {
						Position = UDim2.fromOffset(0, 26),
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						Text = "",
						AutoButtonColor = false,
					}, r)
					local track = new("Frame", {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.new(1, 0, 0, 6),
						BorderSizePixel = 0,
					}, hit)
					corner(track, 3)
					local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
					corner(fill, 3)
					local knob = new("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromOffset(12, 12),
						BackgroundColor3 = WHITE,
						BorderSizePixel = 0,
						ZIndex = 2,
					}, track)
					corner(knob, 100)
					themed(function()
						track.BackgroundColor3 = lift(0.16)
						fill.BackgroundColor3 = Theme.Accent
					end)

					local function knobSize()
						local size = sliding and 18 or (hovering and 15 or 12)
						tween(knob, 0.25, { Size = UDim2.fromOffset(size, size) }, Enum.EasingStyle.Back)
					end

					local function show(instant)
						local alpha = (value - min) / (max - min)
						set(fill, { Size = UDim2.fromScale(alpha, 1) }, instant, 0.12)
						set(knob, { Position = UDim2.fromScale(alpha, 0.5) }, instant, 0.12)
						readout.Text = tostring(math.round(value * 100) / 100) .. suffix
					end
					show(true)

					function object:Set(v)
						v = math.clamp(tonumber(v) or min, min, max)
						value = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
						if flag then
							Library.Flags[flag] = value
						end
						show(false)
						queueSave()
						if opts.Callback then
							task.spawn(opts.Callback, value)
						end
					end
					function object:Get()
						return value
					end
					function object:SetVisible(visible, instant)
						rowVisible(r, 48, visible, instant, false)
					end

					hit.MouseEnter:Connect(function()
						hovering = true
						knobSize()
					end)
					hit.MouseLeave:Connect(function()
						hovering = false
						knobSize()
					end)
					drag(hit, function(position)
						local alpha = math.clamp((position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
						object:Set(min + (max - min) * alpha)
					end, function()
						sliding = true
						knobSize()
					end, function()
						sliding = false
						knobSize()
					end)
					register(flag, value, function(v)
						object:Set(v)
					end)
					return object
				end

				function sec:AddSelector(opts)
					local flag = flagFor(opts)
					local options = opts.Options
					local value = opts.Default or options[1]
					local object = {}
					local indexOf = {}
					local n = #options

					local r = row(62)
					local l = label(r, opts.Name, 13)
					l.Size = UDim2.new(1, 0, 0, 20)
					local rail = new("Frame", {
						Position = UDim2.fromOffset(0, 26),
						Size = UDim2.new(1, 0, 0, 36),
						BorderSizePixel = 0,
					}, r)
					corner(rail, 10)
					stroke(rail, 0.92)
					new("UIPadding", {
						PaddingTop = UDim.new(0, 3),
						PaddingBottom = UDim.new(0, 3),
						PaddingLeft = UDim.new(0, 3),
						PaddingRight = UDim.new(0, 3),
					}, rail)
					themed(function()
						rail.BackgroundColor3 = lift(0.08)
						rail.BackgroundTransparency = 0.3
					end)
					local pill = new("Frame", {
						Size = UDim2.fromScale(1 / n, 1),
						BorderSizePixel = 0,
					}, rail)
					corner(pill, 8)
					themed(function()
						pill.BackgroundColor3 = Theme.Accent
					end)

					local buttons = {}
					for i, option in ipairs(options) do
						indexOf[option] = i
						local b = new("TextButton", {
							Position = UDim2.fromScale((i - 1) / n, 0),
							Size = UDim2.fromScale(1 / n, 1),
							BackgroundTransparency = 1,
							AutoButtonColor = false,
							Text = option,
							TextSize = 13,
						}, rail)
						buttons[option] = b
						b.MouseButton1Click:Connect(function()
							object:Set(option)
						end)
					end

					local function paint(instant)
						local index = indexOf[value] or 1
						set(pill, { Position = UDim2.fromScale((index - 1) / n, 0) }, instant, 0.4)
						for option, b in pairs(buttons) do
							local on = option == value
							b.Font = Fonts[Theme.Font][on and 2 or 1]
							set(b, { TextColor3 = on and WHITE or sub() }, instant, 0.25)
						end
					end
					themed(function()
						paint(true)
					end)

					function object:Set(v)
						if not buttons[v] then
							return
						end
						value = v
						if flag then
							Library.Flags[flag] = value
						end
						paint(false)
						queueSave()
						if opts.Callback then
							task.spawn(opts.Callback, value)
						end
					end
					function object:Get()
						return value
					end
					function object:SetVisible(visible, instant)
						rowVisible(r, 62, visible, instant, false)
					end
					register(flag, value, function(v)
						object:Set(v)
					end)
					return object
				end

				function sec:AddDropdown(opts)
					local flag = flagFor(opts)
					local options = opts.Options or {}
					local value = opts.Default
					if value == nil then
						value = options[1]
					end
					local open = false
					local hovering = false
					local itemHeight = 28
					local object = {}
					local items = {}
					local itemList = {}

					local r = row(36)
					r.ClipsDescendants = true
					local head = new("TextButton", {
						Size = UDim2.new(1, 0, 0, 36),
						BorderSizePixel = 0,
						Text = "",
						AutoButtonColor = false,
					}, r)
					corner(head, 9)
					local edge = stroke(head, 0.92)
					local l = label(head, opts.Name, 13)
					l.Position = UDim2.fromOffset(12, 0)
					l.Size = UDim2.new(0.5, -12, 1, 0)
					local currentLabel = label(head, "", 13, false, true)
					currentLabel.AnchorPoint = Vector2.new(1, 0)
					currentLabel.Position = UDim2.new(1, -30, 0, 0)
					currentLabel.Size = UDim2.new(0.5, -34, 1, 0)
					currentLabel.TextXAlignment = Enum.TextXAlignment.Right
					local arrow = label(head, ">", 15, true, true)
					arrow.AnchorPoint = Vector2.new(0.5, 0.5)
					arrow.Position = UDim2.new(1, -16, 0.5, 0)
					arrow.Size = UDim2.fromOffset(14, 14)
					arrow.TextXAlignment = Enum.TextXAlignment.Center

					local list = new("ScrollingFrame", {
						Position = UDim2.fromOffset(0, 40),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 2,
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
					}, r)
					new("UIListLayout", {
						Padding = UDim.new(0, 2),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}, list)

					local function openHeight()
						return 40 + math.min(#options, 5) * (itemHeight + 2)
					end

					local function edgeState()
						local active = open or hovering
						tween(edge, 0.25, {
							Color = active and Theme.Accent or WHITE,
							Transparency = active and 0.4 or 0.92,
						})
					end

					local function paint()
						head.BackgroundColor3 = lift(0.1)
						head.BackgroundTransparency = 0.3
						currentLabel.Text = tostring(value == nil and "None" or value)
						list.ScrollBarImageColor3 = Theme.Accent
						for option, b in pairs(items) do
							local on = option == value
							b.Font = Fonts[Theme.Font][on and 2 or 1]
							b.TextColor3 = on and Theme.Accent or sub()
						end
					end
					themed(paint)

					local function setOpen(state)
						open = state
						tween(r, 0.3, { Size = UDim2.new(1, 0, 0, open and openHeight() or 36) })
						tween(arrow, 0.3, { Rotation = open and 90 or 0 }, Enum.EasingStyle.Back)
						edgeState()
						if open then
							for i, b in ipairs(itemList) do
								b.TextTransparency = 1
								task.delay(0.04 * (i - 1) + 0.05, function()
									tween(b, 0.25, { TextTransparency = 0 })
								end)
							end
						end
					end

					local function build()
						for _, b in pairs(items) do
							b:Destroy()
						end
						items = {}
						itemList = {}
						for i, option in ipairs(options) do
							local b = new("TextButton", {
								Size = UDim2.new(1, 0, 0, itemHeight),
								BackgroundColor3 = WHITE,
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								Text = tostring(option),
								TextSize = 13,
								TextXAlignment = Enum.TextXAlignment.Left,
								AutoButtonColor = false,
								LayoutOrder = i,
							}, list)
							corner(b, 7)
							new("UIPadding", { PaddingLeft = UDim.new(0, 12) }, b)
							b.MouseEnter:Connect(function()
								tween(b, 0.15, { BackgroundTransparency = 0.92 })
							end)
							b.MouseLeave:Connect(function()
								tween(b, 0.15, { BackgroundTransparency = 1 })
							end)
							b.MouseButton1Click:Connect(function()
								object:Set(option)
								setOpen(false)
							end)
							items[option] = b
							itemList[i] = b
						end
						list.Size = UDim2.new(1, 0, 0, math.min(#options, 5) * (itemHeight + 2))
						paint()
						if open then
							r.Size = UDim2.new(1, 0, 0, openHeight())
						end
					end
					build()

					function object:Set(v)
						if v == nil then
							return
						end
						if #options > 0 and not table.find(options, v) then
							return
						end
						value = v
						if flag then
							Library.Flags[flag] = value
						end
						paint()
						queueSave()
						if opts.Callback then
							task.spawn(opts.Callback, value)
						end
					end
					function object:Get()
						return value
					end
					function object:SetOptions(newOptions)
						options = newOptions
						if not table.find(options, value) then
							value = options[1]
						end
						build()
					end
					function object:SetVisible(visible, instant)
						if not visible and open then
							open = false
							edgeState()
						end
						rowVisible(r, 36, visible, instant, true)
					end

					head.MouseEnter:Connect(function()
						hovering = true
						edgeState()
					end)
					head.MouseLeave:Connect(function()
						hovering = false
						edgeState()
					end)
					head.MouseButton1Click:Connect(function()
						setOpen(not open)
					end)
					register(flag, value, function(v)
						object:Set(v)
					end)
					return object
				end


				function sec:AddContainer()
					count += 1
					local c = new("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						LayoutOrder = count,
					}, box)
					new("UIListLayout", {
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}, c)
					return c
				end



				function sec:AddMultiDropdown(opts)
					local flag = flagFor(opts)
					local options = opts.Options or {}
					local selected = {}
					for _, v in ipairs(opts.Default or {}) do
						selected[v] = true
					end
					local exclusive = opts.Exclusive
					local open, hovering = false, false
					local itemHeight = 28
					local object = {}
					local items, itemList = {}, {}

					local r = row(36)
					r.ClipsDescendants = true
					local head = new("TextButton", {
						Size = UDim2.new(1, 0, 0, 36),
						BorderSizePixel = 0,
						Text = "",
						AutoButtonColor = false,
					}, r)
					corner(head, 9)
					local edge = stroke(head, 0.92)
					local l = label(head, opts.Name, 13)
					l.Position = UDim2.fromOffset(12, 0)
					l.Size = UDim2.new(0.4, -12, 1, 0)
					local summaryLabel = label(head, "", 13, false, true)
					summaryLabel.AnchorPoint = Vector2.new(1, 0)
					summaryLabel.Position = UDim2.new(1, -30, 0, 0)
					summaryLabel.Size = UDim2.new(0.6, -34, 1, 0)
					summaryLabel.TextXAlignment = Enum.TextXAlignment.Right
					local arrow = label(head, ">", 15, true, true)
					arrow.AnchorPoint = Vector2.new(0.5, 0.5)
					arrow.Position = UDim2.new(1, -16, 0.5, 0)
					arrow.Size = UDim2.fromOffset(14, 14)
					arrow.TextXAlignment = Enum.TextXAlignment.Center

					local list = new("ScrollingFrame", {
						Position = UDim2.fromOffset(0, 40),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 2,
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
					}, r)
					new("UIListLayout", {
						Padding = UDim.new(0, 2),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}, list)

					local function openHeight()
						return 40 + math.max(1, math.min(#options, 5)) * (itemHeight + 2)
					end
					local function edgeState()
						local active = open or hovering
						tween(edge, 0.25, {
							Color = active and Theme.Accent or WHITE,
							Transparency = active and 0.4 or 0.92,
						})
					end
					local function toList()
						local out = {}
						for _, o in ipairs(options) do
							if selected[o] then
								table.insert(out, o)
							end
						end
						return out
					end
					local function paint()
						head.BackgroundColor3 = lift(0.1)
						head.BackgroundTransparency = 0.3
						local names = toList()
						summaryLabel.Text = #names == 0 and "None" or (#names <= 2 and table.concat(names, ", ") or (#names .. " selected"))
						list.ScrollBarImageColor3 = Theme.Accent
						for option, b in pairs(items) do
							local on = selected[option] == true
							b.Text = (on and "[x]  " or "[  ]  ") .. tostring(option)
							b.Font = Fonts[Theme.Font][on and 2 or 1]
							b.TextColor3 = on and Theme.Accent or sub()
						end
					end
					themed(paint)

					local function setOpen(state)
						open = state
						tween(r, 0.3, { Size = UDim2.new(1, 0, 0, open and openHeight() or 36) })
						tween(arrow, 0.3, { Rotation = open and 90 or 0 }, Enum.EasingStyle.Back)
						edgeState()
						if open then
							for i, b in ipairs(itemList) do
								b.TextTransparency = 1
								task.delay(0.03 * (i - 1) + 0.05, function()
									tween(b, 0.25, { TextTransparency = 0 })
								end)
							end
						end
					end

					local function commit()
						if flag then
							Library.Flags[flag] = toList()
						end
						paint()
						queueSave()
						if opts.Callback then
							local copy = {}
							for k, v in pairs(selected) do
								copy[k] = v
							end
							task.spawn(opts.Callback, copy)
						end
					end

					local function toggleOption(option)
						if selected[option] then
							selected[option] = nil
						else
							if exclusive then
								if option == exclusive then
									selected = {}
								else
									selected[exclusive] = nil
								end
							end
							selected[option] = true
						end
						if exclusive and next(selected) == nil then
							selected[exclusive] = true
						end
						commit()
					end

					local function build()
						for _, b in pairs(items) do
							b:Destroy()
						end
						items, itemList = {}, {}
						for i, option in ipairs(options) do
							local b = new("TextButton", {
								Size = UDim2.new(1, 0, 0, itemHeight),
								BackgroundColor3 = WHITE,
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								Text = tostring(option),
								TextSize = 13,
								TextXAlignment = Enum.TextXAlignment.Left,
								AutoButtonColor = false,
								LayoutOrder = i,
							}, list)
							corner(b, 7)
							new("UIPadding", { PaddingLeft = UDim.new(0, 12) }, b)
							b.MouseEnter:Connect(function()
								tween(b, 0.15, { BackgroundTransparency = 0.92 })
							end)
							b.MouseLeave:Connect(function()
								tween(b, 0.15, { BackgroundTransparency = 1 })
							end)
							b.MouseButton1Click:Connect(function()
								toggleOption(option)
							end)
							items[option] = b
							itemList[i] = b
						end
						list.Size = UDim2.new(1, 0, 0, math.max(1, math.min(#options, 5)) * (itemHeight + 2))
						paint()
						if open then
							r.Size = UDim2.new(1, 0, 0, openHeight())
						end
					end
					build()

					function object:Get()
						local copy = {}
						for k, v in pairs(selected) do
							copy[k] = v
						end
						return copy
					end
					function object:Set(listOrSet)
						selected = {}
						for k, v in pairs(listOrSet or {}) do
							if v == true then
								selected[k] = true
							elseif type(v) == "string" then
								selected[v] = true
							end
						end
						if exclusive and next(selected) == nil then
							selected[exclusive] = true
						end
						commit()
					end
					function object:Clear()
						selected = {}
						if exclusive then
							selected[exclusive] = true
						end
						commit()
					end
					function object:SetOptions(newOptions)
						options = newOptions
						for k in pairs(selected) do
							if not table.find(options, k) then
								selected[k] = nil
							end
						end
						build()
					end
					function object:SetVisible(visible, instant)
						if not visible and open then
							open = false
							edgeState()
						end
						rowVisible(r, 36, visible, instant, true)
					end

					head.MouseEnter:Connect(function()
						hovering = true
						edgeState()
					end)
					head.MouseLeave:Connect(function()
						hovering = false
						edgeState()
					end)
					head.MouseButton1Click:Connect(function()
						setOpen(not open)
					end)
					register(flag, toList(), function(v)
						object:Set(v)
					end)
					return object
				end

				function sec:AddColorPicker(opts)
					local flag = flagFor(opts)
					local value = opts.Default or WHITE
					local h, s, v = value:ToHSV()
					local open = false
					local object = {}

					local r = row(30)
					r.ClipsDescendants = true
					local head = new("TextButton", {
						Size = UDim2.new(1, 0, 0, 30),
						BackgroundTransparency = 1,
						Text = "",
						AutoButtonColor = false,
					}, r)
					local l = label(head, opts.Name, 13)
					l.Size = UDim2.new(1, -56, 1, 0)
					local swatch = new("Frame", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(38, 20),
						BorderSizePixel = 0,
					}, head)
					corner(swatch, 6)
					stroke(swatch, 0.75)
					local swatchScale = new("UIScale", {}, swatch)
					head.MouseEnter:Connect(function()
						tween(swatchScale, 0.25, { Scale = 1.08 }, Enum.EasingStyle.Back)
					end)
					head.MouseLeave:Connect(function()
						tween(swatchScale, 0.25, { Scale = 1 })
					end)

					local body = new("Frame", {
						Position = UDim2.fromOffset(0, 36),
						Size = UDim2.new(1, 0, 0, 148),
						BackgroundTransparency = 1,
					}, r)

					local sv = new("Frame", {
						Size = UDim2.new(1, -30, 0, 114),
						BorderSizePixel = 0,
					}, body)
					corner(sv, 7)
					local whiteLayer = new("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = WHITE,
						BorderSizePixel = 0,
					}, sv)
					corner(whiteLayer, 7)
					new("UIGradient", { Transparency = NumberSequence.new(0, 1) }, whiteLayer)
					local blackLayer = new("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = BLACK,
						BorderSizePixel = 0,
					}, sv)
					corner(blackLayer, 7)
					new("UIGradient", {
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(1, 0),
						}),
					}, blackLayer)
					local svCursor = new("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromOffset(12, 12),
						BackgroundTransparency = 1,
						ZIndex = 3,
					}, sv)
					corner(svCursor, 6)
					stroke(svCursor, 0, WHITE, 2)

					local hue = new("Frame", {
						Position = UDim2.new(1, -20, 0, 0),
						Size = UDim2.fromOffset(20, 114),
						BackgroundColor3 = WHITE,
						BorderSizePixel = 0,
					}, body)
					corner(hue, 7)
					local stops = {}
					for i = 0, 6 do
						table.insert(stops, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
					end
					new("UIGradient", { Rotation = 90, Color = ColorSequence.new(stops) }, hue)
					local hueCursor = new("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.new(1, 4, 0, 4),
						BackgroundColor3 = WHITE,
						BorderSizePixel = 0,
						ZIndex = 3,
					}, hue)
					corner(hueCursor, 2)
					stroke(hueCursor, 0.4, BLACK)

					local hex = new("TextBox", {
						Position = UDim2.fromOffset(0, 122),
						Size = UDim2.new(1, 0, 0, 26),
						BorderSizePixel = 0,
						Text = "",
						PlaceholderText = "#FFFFFF",
						ClearTextOnFocus = false,
						TextSize = 13,
					}, body)
					corner(hex, 7)
					local hexEdge = stroke(hex, 0.92)
					themed(function()
						hex.Font = Fonts[Theme.Font][1]
						hex.TextColor3 = Theme.Text
						hex.PlaceholderColor3 = sub()
						hex.BackgroundColor3 = lift(0.1)
						hex.BackgroundTransparency = 0.3
					end)
					hex.Focused:Connect(function()
						tween(hexEdge, 0.2, { Color = Theme.Accent, Transparency = 0.35 })
					end)

					local function toHex(color)
						return string.format(
							"#%02X%02X%02X",
							math.round(color.R * 255),
							math.round(color.G * 255),
							math.round(color.B * 255)
						)
					end

					local function show()
						value = Color3.fromHSV(h, s, v)
						swatch.BackgroundColor3 = value
						sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
						svCursor.Position = UDim2.fromScale(s, 1 - v)
						hueCursor.Position = UDim2.fromScale(0.5, h)
						hex.Text = toHex(value)
					end
					show()

					local function commit()
						show()
						if flag then
							Library.Flags[flag] = value
						end
						queueSave()
						if opts.Callback then
							task.spawn(opts.Callback, value)
						end
					end

					function object:Set(color)
						if typeof(color) ~= "Color3" then
							return
						end
						h, s, v = color:ToHSV()
						commit()
					end
					function object:Get()
						return value
					end

					drag(sv, function(position)
						s = math.clamp((position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
						v = 1 - math.clamp((position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
						commit()
					end, function()
						tween(svCursor, 0.2, { Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Back)
					end, function()
						tween(svCursor, 0.25, { Size = UDim2.fromOffset(12, 12) }, Enum.EasingStyle.Back)
					end)
					drag(hue, function(position)
						h = math.clamp((position.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 0.999)
						commit()
					end)

					hex.FocusLost:Connect(function()
						tween(hexEdge, 0.25, { Color = WHITE, Transparency = 0.92 })
						local text = hex.Text:gsub("#", "")
						local n = #text == 6 and tonumber(text, 16)
						if n then
							object:Set(Color3.fromRGB(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256))
						else
							show()
						end
					end)

					head.MouseButton1Click:Connect(function()
						open = not open
						tween(r, 0.35, { Size = UDim2.new(1, 0, 0, open and 184 or 30) })
					end)

					register(flag, value, function(color)
						object:Set(color)
					end)
					return object
				end



				function sec:AddColorRow(opts)
					local flag = flagFor(opts)
					local defaults = opts.Defaults
					local n = #defaults
					local values = {}
					local swatches = {}
					local strokes = {}
					local selected = nil
					local open = false
					local object = {}
					local picker

					local r = row(30)
					r.ClipsDescendants = true
					local head = new("Frame", {
						Size = UDim2.new(1, 0, 0, 30),
						BackgroundTransparency = 1,
					}, r)
					local l = label(head, opts.Name, 13)
					l.Size = UDim2.new(1, -(n * 44 + 4), 1, 0)

					local function paintSelection()
						for i, edge in ipairs(strokes) do
							local on = open and selected == i
							tween(edge, 0.2, { Transparency = on and 0 or 0.75 })
						end
					end

					for i = 1, n do
						values[i] = defaults[i]
						local sw = new("TextButton", {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -(n - i) * 44, 0.5, 0),
							Size = UDim2.fromOffset(38, 20),
							BackgroundColor3 = values[i],
							BorderSizePixel = 0,
							Text = "",
							AutoButtonColor = false,
						}, head)
						corner(sw, 6)
						strokes[i] = stroke(sw, 0.75)
						local swScale = new("UIScale", {}, sw)
						swatches[i] = sw
						sw.MouseEnter:Connect(function()
							tween(swScale, 0.25, { Scale = 1.1 }, Enum.EasingStyle.Back)
						end)
						sw.MouseLeave:Connect(function()
							tween(swScale, 0.25, { Scale = 1 })
						end)
						sw.MouseButton1Click:Connect(function()
							if open and selected == i then
								open = false
							else
								open = true
								selected = i
								picker:Load(values[i])
							end
							paintSelection()
							tween(r, 0.35, { Size = UDim2.new(1, 0, 0, open and 184 or 30) })
						end)
					end

					picker = buildPicker(r, UDim2.fromOffset(0, 36), function(color)
						if selected then
							object:Set(selected, color, true)
						end
					end)

					function object:Set(i, color, fromPicker)
						if typeof(color) ~= "Color3" or not values[i] then
							return
						end
						values[i] = color
						swatches[i].BackgroundColor3 = color
						if flag then
							Library.Flags[flag .. "_" .. i] = color
						end
						if selected == i and not fromPicker then
							picker:Load(color)
						end
						queueSave()
						if opts.Callback then
							task.spawn(opts.Callback, table.clone(values))
						end
					end
					function object:Get()
						return values
					end
					function object:SetVisible(visible, instant)
						if not visible and open then
							open = false
							selected = nil
							paintSelection()
						end
						rowVisible(r, 30, visible, instant, true)
					end

					for i = 1, n do
						register(flag and (flag .. "_" .. i), values[i], function(color)
							object:Set(i, color)
						end)
					end
					return object
				end

				function sec:AddKeybind(opts)
					local flag = flagFor(opts)
					local key = opts.Default
					local listening = false
					local object = {}

					local r = row(30)
					local l = label(r, opts.Name, 13)
					l.Size = UDim2.new(1, -96, 1, 0)
					local b = new("TextButton", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(88, 26),
						BorderSizePixel = 0,
						TextSize = 12,
						AutoButtonColor = false,
						Text = "",
					}, r)
					corner(b, 7)
					local edge = stroke(b, 0.92)

					local function paint()
						b.Text = listening and "..." or (key and key.Name or "None")
						b.Font = Fonts[Theme.Font][1]
						b.TextColor3 = listening and Theme.Accent or Theme.Text
						b.BackgroundColor3 = lift(0.1)
						b.BackgroundTransparency = 0.3
						edge.Color = listening and Theme.Accent or WHITE
						edge.Transparency = listening and 0.35 or 0.92
					end
					themed(paint)

					function object:Set(value)
						if type(value) == "string" then
							local ok, found = pcall(function()
								return Enum.KeyCode[value]
							end)
							key = ok and found or nil
						else
							key = value
						end
						if flag then
							Library.Flags[flag] = key and key.Name or "None"
						end
						paint()
						queueSave()
					end
					function object:Get()
						return key
					end

					b.MouseButton1Click:Connect(function()
						listening = true
						paint()
					end)
					connect(UserInputService.InputBegan, function(input, processed)
						if listening then
							if input.UserInputType == Enum.UserInputType.Keyboard then
								listening = false
								if input.KeyCode ~= Enum.KeyCode.Escape then
									object:Set(input.KeyCode)
								else
									paint()
								end
							end
							return
						end
						if not processed and key and input.KeyCode == key and opts.Callback then
							task.spawn(opts.Callback)
						end
					end)
					register(flag, key and key.Name or "None", function(value)
						object:Set(value)
					end)
					return object
				end

				function sec:AddTextbox(opts)
					local flag = flagFor(opts)
					local value = opts.Default or ""
					local object = {}
					local r = row(36)
					local input = new("TextBox", {
						Size = UDim2.fromScale(1, 1),
						BorderSizePixel = 0,
						Text = value,
						PlaceholderText = opts.Placeholder or opts.Name,
						ClearTextOnFocus = false,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
					}, r)
					corner(input, 9)
					local edge = stroke(input, 0.92)
					new("UIPadding", {
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
					}, input)
					themed(function()
						input.Font = Fonts[Theme.Font][1]
						input.TextColor3 = Theme.Text
						input.PlaceholderColor3 = sub()
						input.BackgroundColor3 = lift(0.1)
						input.BackgroundTransparency = 0.3
					end)

					function object:Set(text)
						value = tostring(text)
						input.Text = value
						if flag then
							Library.Flags[flag] = value
						end
						queueSave()
						if opts.Callback then
							task.spawn(opts.Callback, value)
						end
					end
					function object:Get()
						return value
					end
					input.Focused:Connect(function()
						tween(edge, 0.25, { Color = Theme.Accent, Transparency = 0.35 })
					end)
					input.FocusLost:Connect(function()
						tween(edge, 0.3, { Color = WHITE, Transparency = 0.92 })
						object:Set(input.Text)
					end)
					register(flag, value, function(text)
						object:Set(text)
					end)
					return object
				end

				return sec
			end

			table.insert(tab.Subs, subTab)
			if not tab.CurrentSub then
				selectSub(subTab)
			end
			return subTab
		end

		table.insert(window.Tabs, tab)
		if not window.Current then
			window:Select(tab)
		end
		return tab
	end

	return window
end

function Library:Unload()
	for _, fn in ipairs(self.OnUnload or {}) do
		pcall(fn)
	end
	self.OnUnload = {}
	for _, connection in ipairs(self.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	self.Connections = {}
	self.Updaters = {}
	if self.NotifyTemplate then
		pcall(function()
			self.NotifyTemplate:Destroy()
		end)
		self.NotifyTemplate = nil
	end
	if self.Gui then
		self.Gui:Destroy()
	end
end

local window = Library:CreateWindow({ Title = "curzs V3" })

local built, buildError = pcall(function()

local function safe(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		warn("[curzs V3] " .. name .. " failed: " .. tostring(err))
		pcall(function()
			Library:Notify(name .. " failed to load")
		end)
	end
end

local mainTab = window:AddTab("Main", Assets.Main)
local playerTab = window:AddTab("Player", Assets.Player)
local visualsTab = window:AddTab("Visuals", Assets.Visuals)
local miscTab = window:AddTab("Misc", Assets.Misc)
local settingsTab = window:AddTab("UI Settings", Assets.Settings)

local aimbotTab = mainTab:AddSubTab("Aimbot")
local silentTab = mainTab:AddSubTab("Silent Aim")
local rageTab = mainTab:AddSubTab("Rage")

local moveTab = playerTab:AddSubTab("Movements")
local whiteTab = playerTab:AddSubTab("Whitelist")
local blackTab = playerTab:AddSubTab("Blacklist")
local antiTab = playerTab:AddSubTab("Anti Aim")

local espTab = visualsTab:AddSubTab("Player Visuals")
visualsTab:AddSubTab("Test 2")

local autoTab = miscTab:AddSubTab("Auto Buy")
local weaponTab = miscTab:AddSubTab("Weapons")
local dataTab = miscTab:AddSubTab("Game Data")

local uiTab = settingsTab:AddSubTab("UI Settings")
local cfgTab = settingsTab:AddSubTab("Config")

local Core = {
	Lists = { white = { ids = {}, feat = {} }, black = { ids = {}, feat = {} } },
	Emote = { playing = false },
}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

Core.PartOptions = {
	"Closest", "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
	"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}

Core.Fallback = {
	UpperTorso = "Torso", LowerTorso = "Torso", Torso = "UpperTorso",
	LeftUpperArm = "Left Arm", LeftLowerArm = "Left Arm", LeftHand = "Left Arm",
	RightUpperArm = "Right Arm", RightLowerArm = "Right Arm", RightHand = "Right Arm",
	LeftUpperLeg = "Left Leg", LeftLowerLeg = "Left Leg", LeftFoot = "Left Leg",
	RightUpperLeg = "Right Leg", RightLowerLeg = "Right Leg", RightFoot = "Right Leg",
	["Left Arm"] = "LeftUpperArm", ["Right Arm"] = "RightUpperArm",
	["Left Leg"] = "LeftUpperLeg", ["Right Leg"] = "RightUpperLeg",
}

function Core.alive(player, minHp)
	local char = player.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= (minHp or 0) then
		return nil
	end
	return char, hum
end

function Core.toScreen(c, pos)
	local p, on = c:WorldToViewportPoint(pos)
	return Vector2.new(p.X, p.Y), on and p.Z > 0
end

function Core.matches(name, set)
	for sel in pairs(set) do
		if sel == name or Core.Fallback[sel] == name then
			return true
		end
	end
	return false
end

function Core.pickPart(c, char, origin, set)
	local all = set.Closest or next(set) == nil
	local best, bestD
	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("BasePart") then
			local ok
			if all then
				ok = part.Name ~= "HumanoidRootPart"
			else
				ok = Core.matches(part.Name, set)
			end
			if ok then
				local sp, on = Core.toScreen(c, part.Position)
				if on then
					local d = (sp - origin).Magnitude
					if not bestD or d < bestD then
						best, bestD = part, d
					end
				end
			end
		end
	end
	return best, bestD
end

function Core.visible(c, part, char)
	rayParams.FilterDescendantsInstances = { LocalPlayer.Character, char }
	local origin = c.CFrame.Position
	return workspace:Raycast(origin, part.Position - origin, rayParams) == nil
end

function Core.canTarget(player, feature)
	local w, b = Core.Lists.white, Core.Lists.black
	local id = player.UserId
	if w.feat[feature] and w.ids[id] then
		return false
	end
	if (b.feat[feature] or b.feat.All) and next(b.ids) and not b.ids[id] then
		return false
	end
	return true
end

function Core.nearestTarget(cfg, feature, c, center)
	local bestPlayer, bestD
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and Core.canTarget(player, feature) then
			local char = Core.alive(player, 2)
			if char then
				local part, d = Core.pickPart(c, char, center, cfg.parts)
				if part and d <= cfg.fovRef.Size and (not cfg.wall or Core.visible(c, part, char)) then
					if not bestD or d < bestD then
						bestPlayer, bestD = player, d
					end
				end
			end
		end
	end
	return bestPlayer
end

Core.PuppetReq = {}
local puppet = { real = nil, set = false }
connect(RunService.Heartbeat, function()
	local best
	for _, req in pairs(Core.PuppetReq) do
		if not best or req.pri > best.pri then
			best = req
		end
	end
	if not best then
		return
	end
	local ch = LocalPlayer.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	puppet.real = root.CFrame
	puppet.set = true
	local ok, cf = pcall(best.fn, puppet.real)
	if ok and cf then
		root.CFrame = cf
	end
end)
local puppetBind = "CurzsPuppet" .. HttpService:GenerateGUID(false)
RunService:BindToRenderStep(puppetBind, Enum.RenderPriority.First.Value, function()
	if puppet.set then
		puppet.set = false
		local ch = LocalPlayer.Character
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		if root and puppet.real then
			root.CFrame = puppet.real
		end
	end
end)

Core.flickSaved = nil
function Core.flick(pos)
	local c = workspace.CurrentCamera
	if not c then
		return
	end
	if Core.flickSaved then
		c.CFrame = Core.flickSaved
	end
	local real = c.CFrame
	local mouse = UserInputService:GetMouseLocation()
	local ray = c:ViewportPointToRay(mouse.X, mouse.Y).Direction.Unit
	local origin = real.Position
	local toTarget = (pos - origin).Unit
	local axis = ray:Cross(toTarget)
	if axis.Magnitude < 1e-5 then
		return
	end
	local angle = math.acos(math.clamp(ray:Dot(toTarget), -1, 1))
	Core.flickSaved = real
	Core.flickTime = os.clock()
	c.CFrame = CFrame.new(origin) * CFrame.fromAxisAngle(axis.Unit, angle) * real.Rotation
end

function Core.flickAt(camPos, pos)
	local c = workspace.CurrentCamera
	if not c then
		return
	end
	if Core.flickSaved then
		c.CFrame = Core.flickSaved
	end
	local real = c.CFrame
	local base = CFrame.lookAt(camPos, pos)
	c.CFrame = base
	local mouse = UserInputService:GetMouseLocation()
	local ray = c:ViewportPointToRay(mouse.X, mouse.Y).Direction.Unit
	local toTarget = (pos - camPos).Unit
	local axis = ray:Cross(toTarget)
	Core.flickSaved = real
	Core.flickTime = os.clock()
	if axis.Magnitude >= 1e-5 then
		local angle = math.acos(math.clamp(ray:Dot(toTarget), -1, 1))
		c.CFrame = CFrame.new(camPos) * CFrame.fromAxisAngle(axis.Unit, angle) * base.Rotation
	end
end
function Core.unflick()
	if Core.flickSaved then
		local c = workspace.CurrentCamera
		if c then
			c.CFrame = Core.flickSaved
		end
		Core.flickSaved = nil
	end
end
local flickBind = "CurzsFlick" .. HttpService:GenerateGUID(false)
RunService:BindToRenderStep(flickBind, Enum.RenderPriority.First.Value, Core.unflick)
table.insert(Library.OnUnload, function()
	Core.PuppetReq = {}
	pcall(RunService.UnbindFromRenderStep, RunService, puppetBind)
	pcall(RunService.UnbindFromRenderStep, RunService, flickBind)
	pcall(Core.unflick)
	local ch = LocalPlayer.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if puppet.set and root and puppet.real then
		root.CFrame = puppet.real
	end
end)

local camHold = { n = 0, cf = nil, kind = nil }
local camHoldBind = "CurzsCamHold" .. HttpService:GenerateGUID(false)
function Core.holdCamera(on)
	if on then
		camHold.n += 1
		if camHold.n == 1 then
			local c = workspace.CurrentCamera
			if c then
				camHold.cf, camHold.kind = c.CFrame, c.CameraType
				c.CameraType = Enum.CameraType.Scriptable
				RunService:BindToRenderStep(camHoldBind, Enum.RenderPriority.Camera.Value + 10, function()
					local cam = workspace.CurrentCamera
					if cam and camHold.cf then
						cam.CFrame = camHold.cf
					end
				end)
			end
		end
	else
		camHold.n = math.max(camHold.n - 1, 0)
		if camHold.n == 0 and camHold.cf then
			pcall(RunService.UnbindFromRenderStep, RunService, camHoldBind)
			local c = workspace.CurrentCamera
			if c then
				c.CameraType = camHold.kind or Enum.CameraType.Custom
				c.CFrame = camHold.cf
			end
			camHold.cf = nil
		end
	end
end
table.insert(Library.OnUnload, function()
	camHold.n = 1
	Core.holdCamera(false)
end)

local ReplicatedStorageCore = game:GetService("ReplicatedStorage")
function Core.sendAim(pos)
	local ev = ReplicatedStorageCore:FindFirstChild("MainEvent")
	if ev then
		pcall(ev.FireServer, ev, "UpdateMousePos", pos)
	end
end

function Core.setGroup(rows, state, instant)
	for i, object in ipairs(rows) do
		if instant then
			object:SetVisible(state, true)
		else
			task.delay((i - 1) * 0.06, function()
				object:SetVisible(state)
			end)
		end
	end
end

function Core.seq(colors)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, colors[1]),
		ColorSequenceKeypoint.new(0.5, colors[2]),
		ColorSequenceKeypoint.new(1, colors[3]),
	})
end

local fovGui = new("ScreenGui", {
	Name = HttpService:GenerateGUID(false),
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 998,
})
protectGui(fovGui)
table.insert(Library.OnUnload, function()
	fovGui:Destroy()
end)

function Core.makeFov(outline, fill)
	local f = { Show = false, FillOn = false, Opacity = 25, Speed = 60, Size = 150, Outline = outline, Fill = fill }
	local frame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(300, 300),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
	}, fovGui)
	corner(frame, 1000)
	local st = stroke(frame, 0, WHITE, 2)
	local strokeGrad = new("UIGradient", {}, st)
	local fillGrad = new("UIGradient", {}, frame)
	function f:Apply()
		strokeGrad.Color = Core.seq(f.Outline)
		fillGrad.Color = Core.seq(f.Fill)
	end
	function f:Update(pos)
		if not f.Show then
			frame.Visible = false
			return
		end
		frame.Visible = true
		frame.Size = UDim2.fromOffset(f.Size * 2, f.Size * 2)
		frame.Position = UDim2.fromOffset(pos.X, pos.Y)
		local t = os.clock()

		strokeGrad.Rotation = (t * f.Speed) % 360
		strokeGrad.Offset = Vector2.new(math.sin(t * 0.9) * 0.3, math.cos(t * 0.7) * 0.3)
		fillGrad.Rotation = (-t * f.Speed * 0.6) % 360
		fillGrad.Offset = Vector2.new(math.cos(t * 0.6) * 0.3, math.sin(t * 0.8) * 0.3)
		st.Thickness = 2 + math.sin(t * 2) * 0.35
		frame.BackgroundTransparency = f.FillOn and (1 - f.Opacity / 100) or 1
	end
	function f:Destroy()
		frame:Destroy()
	end
	table.insert(Library.OnUnload, function()
		pcall(frame.Destroy, frame)
	end)
	f:Apply()
	return f
end

function Core.fovUI(sec, f, prefix)
	sec:AddToggle({
		Name = "Show FOV",
		Flag = prefix .. "_showfov",
		Callback = function(state)
			f.Show = state
		end,
	})
	sec:AddSlider({
		Name = "FOV Size",
		Min = 20,
		Max = 600,
		Default = f.Size,
		Suffix = "px",
		Flag = prefix .. "_fovsize",
		Callback = function(value)
			f.Size = value
		end,
	})
	sec:AddColorRow({
		Name = "Outline",
		Defaults = f.Outline,
		Flag = prefix .. "_fovout",
		Callback = function(colors)
			f.Outline = colors
			f:Apply()
		end,
	})
	sec:AddToggle({
		Name = "Fill FOV",
		Flag = prefix .. "_fillfov",
		Callback = function(state)
			f.FillOn = state
		end,
	})
	sec:AddColorRow({
		Name = "Fill",
		Defaults = f.Fill,
		Flag = prefix .. "_fovfill",
		Callback = function(colors)
			f.Fill = colors
			f:Apply()
		end,
	})
	sec:AddSlider({
		Name = "Fill Opacity",
		Min = 0,
		Max = 100,
		Default = f.Opacity,
		Flag = prefix .. "_fillop",
		Callback = function(value)
			f.Opacity = value
		end,
	})
	sec:AddSlider({
		Name = "Animation Speed",
		Min = 0,
		Max = 360,
		Default = f.Speed,
		Suffix = "",
		Flag = prefix .. "_fovspeed",
		Callback = function(value)
			f.Speed = value
		end,
	})
end

function Core.hitUI(sec, cfg, prefix)
	sec:AddMultiDropdown({
		Name = "Hit Part",
		Options = Core.PartOptions,
		Default = { "Closest" },
		Exclusive = "Closest",
		Flag = prefix .. "_parts",
		Callback = function(set)
			cfg.parts = set
		end,
	})
end

safe("Aimbot", function()
	local mousemoverel = exec("mousemoverel")
	local fov = Core.makeFov(
		{ Color3.fromRGB(255, 90, 150), Color3.fromRGB(170, 110, 255), Color3.fromRGB(90, 200, 255) },
		{ Color3.fromRGB(255, 90, 150), Color3.fromRGB(150, 100, 255), Color3.fromRGB(80, 190, 255) }
	)
	local cfg = {
		parts = { Closest = true },
		fovRef = fov,
		wall = false,
		sticky = false,
		enabled = false,
		locked = nil,
		lockTime = 0,
		acc = Vector2.zero,
		smR = 35, smL = 35, smJ = 45,
		stR = 100, stL = 100, stJ = 100,
		humanize = 0,
		shaky = false,
		shR = 2, shL = 2, shJ = 2,
	}

	local function alphaFor(percent, dt)
		local s = math.clamp(percent / 100, 0, 1)
		local a60 = 1 - s * 0.98
		return 1 - (1 - a60) ^ (dt * 60)
	end

	local function resolve(c, player, mouse)
		local char = Core.alive(player, 2)
		if not char or not Core.canTarget(player, "Aimbot") then
			return nil
		end
		local part = Core.pickPart(c, char, mouse, cfg.parts)
		if not part then
			return nil
		end
		local sp, on = Core.toScreen(c, part.Position)
		if not on then
			return nil
		end
		return char, part, sp
	end

	local warned = false
	local function step(dt)
		local c = workspace.CurrentCamera
		if not c then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		fov:Update(mouse)
		if not cfg.enabled then
			cfg.locked = nil
			return
		end

		local player = cfg.locked
		local char, part, sp

		local keep = cfg.sticky and player ~= nil and player.Parent == Players
		if player and player.Parent == Players then
			char, part, sp = resolve(c, player, mouse)
		end
		if not keep then
			local best = Core.nearestTarget(cfg, "Aimbot", c, mouse)
			if best ~= player then
				player = best
				cfg.lockTime = os.clock()
				char, part, sp = nil, nil, nil
				if player then
					char, part, sp = resolve(c, player, mouse)
				end
			end
			if not char then
				player = nil
			end
			cfg.locked = player
		end
		if not (char and part and sp) then
			return
		end

		if cfg.wall and not Core.visible(c, part, char) then
			return
		end

		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart") or part
		local vel = root.AssemblyLinearVelocity
		local side = vel:Dot(c.CFrame.RightVector)
		local air = math.abs(vel.Y) > 7
		if hum then
			local st = hum:GetState()
			air = air or st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall
		end

		local smX, stX, shX = (cfg.smR + cfg.smL) / 2, (cfg.stR + cfg.stL) / 2, (cfg.shR + cfg.shL) / 2
		if side > 3 then
			smX, stX, shX = cfg.smR, cfg.stR, cfg.shR
		elseif side < -3 then
			smX, stX, shX = cfg.smL, cfg.stL, cfg.shL
		end
		local smY, stY, shY = smX, stX, shX
		if air then
			smY, stY, shY = cfg.smJ, cfg.stJ, cfg.shJ
		else
			smY, stY, shY = (cfg.smR + cfg.smL) / 2, (cfg.stR + cfg.stL) / 2, (cfg.shR + cfg.shL) / 2
		end


		local h = cfg.humanize / 100
		local t = os.clock()
		local ramp, breathe = 1, 1
		local drift = Vector2.zero
		if h > 0 then
			ramp = math.clamp((t - cfg.lockTime) / (0.06 + 0.4 * h), 0, 1)
			breathe = 1 - 0.5 * h * (0.5 + 0.5 * math.noise(t * 1.3, 0.5, 0))
			drift = Vector2.new(math.noise(t * 2.1, 1.5, 0), math.noise(t * 1.7, 7.5, 0)) * h * 9
		end
		local ax = alphaFor(smX, dt) * (stX / 100) * ramp * breathe
		local ay = alphaFor(smY, dt) * (stY / 100) * ramp * breathe

		local off = drift
		if cfg.shaky then
			off += Vector2.new((math.random() - 0.5) * 2 * shX * 2.2, (math.random() - 0.5) * 2 * shY * 2.2)
		end

		if mousemoverel then
			cfg.acc += Vector2.new((sp.X + off.X - mouse.X) * ax, (sp.Y + off.Y - mouse.Y) * ay)
			local mx = cfg.acc.X >= 0 and math.floor(cfg.acc.X) or math.ceil(cfg.acc.X)
			local my = cfg.acc.Y >= 0 and math.floor(cfg.acc.Y) or math.ceil(cfg.acc.Y)
			cfg.acc -= Vector2.new(mx, my)
			if mx ~= 0 or my ~= 0 then
				mousemoverel(mx, my)
			end
		else

			local cf = c.CFrame
			local function yp(v)
				return math.atan2(-v.X, -v.Z), math.asin(math.clamp(v.Y, -1, 1))
			end
			local cy, cp = yp(cf.LookVector)
			local gy, gp = yp((part.Position - cf.Position).Unit)
			local dy = ((gy - cy + math.pi) % (2 * math.pi)) - math.pi
			c.CFrame = CFrame.new(cf.Position)
				* CFrame.Angles(0, cy + dy * ax, 0)
				* CFrame.Angles(math.clamp(cp + (gp - cp) * ay, -1.5, 1.5), 0, 0)
			if not warned then
				warned = true
				Library:Notify("No mousemoverel here, aiming with the camera")
			end
		end
	end

	local bindName = "CurzsAimbot" .. HttpService:GenerateGUID(false)
	RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, function(dt)
		local ok, err = pcall(step, dt)
		if not ok then
			warn("[curzs V3] aimbot: " .. tostring(err))
		end
	end)
	table.insert(Library.OnUnload, function()
		pcall(RunService.UnbindFromRenderStep, RunService, bindName)
	end)


	local ctl = {}
	local function slider(sec, name, key, flag, min, max, default, suffix)
		ctl[key] = sec:AddSlider({
			Name = name,
			Min = min,
			Max = max,
			Default = default,
			Suffix = suffix,
			Flag = flag,
			Callback = function(value)
				cfg[key] = value
			end,
		})
	end

	local main = aimbotTab:AddSection("Aimbot", 1)
	main:AddToggle({
		Name = "Enable",
		Flag = "aim_enable",
		Keybind = {
			Mode = "Toggle",
			Title = "Aimbot",
			OnActive = function(active)
				cfg.enabled = active
				cfg.locked = nil
				cfg.lockTime = os.clock()
			end,
			OnPress = function()
				cfg.locked = nil
			end,
		},
	})
	main:AddToggle({
		Name = "Sticky Aim",
		Flag = "aim_sticky",
		Callback = function(state)
			cfg.sticky = state
		end,
	})
	main:AddToggle({
		Name = "Wall Check",
		Flag = "aim_wall",
		Callback = function(state)
			cfg.wall = state
		end,
	})
	local backup
	main:AddToggle({
		Name = "Blatant Config",
		Flag = "aim_blatant",
		Callback = function(state)
			if state then
				backup = {}
				for key, object in pairs(ctl) do
					backup[key] = object:Get()
				end
				backup.shaky = cfg.shaky
				for _, key in ipairs({ "smR", "smL", "smJ" }) do
					ctl[key]:Set(0)
				end
				for _, key in ipairs({ "stR", "stL", "stJ" }) do
					ctl[key]:Set(100)
				end
				ctl.humanize:Set(0)
				cfg.shaky = false
			elseif backup then
				for key, value in pairs(backup) do
					if ctl[key] then
						ctl[key]:Set(value)
					end
				end
				cfg.shaky = backup.shaky
				backup = nil
			end
		end,
	})
	main:AddLabel("Method: Mouse")
	Core.hitUI(aimbotTab:AddSection("Hit Part", 1), cfg, "aim")
	Core.fovUI(aimbotTab:AddSection("FOV", 1), fov, "aim")

	local smooth = aimbotTab:AddSection("Smoothness", 2)
	slider(smooth, "Right Smoothness", "smR", "aim_sm_r", 0, 100, 35)
	slider(smooth, "Left Smoothness", "smL", "aim_sm_l", 0, 100, 35)
	slider(smooth, "Jump Smoothness", "smJ", "aim_sm_j", 0, 100, 45)

	local strength = aimbotTab:AddSection("Strength", 2)
	slider(strength, "Right Strength", "stR", "aim_st_r", 0, 100, 100)
	slider(strength, "Left Strength", "stL", "aim_st_l", 0, 100, 100)
	slider(strength, "Jump Strength", "stJ", "aim_st_j", 0, 100, 100)

	local human = aimbotTab:AddSection("Humanize", 2)
	slider(human, "Humanize (high = human, low = AI)", "humanize", "aim_human", 0, 100, 0)

	local shake = aimbotTab:AddSection("Shaky Aim", 2)
	local shRows = {}
	shake:AddToggle({
		Name = "Shaky Aim",
		Flag = "aim_shaky",
		Callback = function(state)
			cfg.shaky = state
			Core.setGroup(shRows, state)
		end,
	})
	slider(shake, "Right Shake", "shR", "aim_sh_r", 1, 5, 2, "")
	slider(shake, "Left Shake", "shL", "aim_sh_l", 1, 5, 2, "")
	slider(shake, "Jump Shake", "shJ", "aim_sh_j", 1, 5, 2, "")
	shRows = { ctl.shR, ctl.shL, ctl.shJ }
	Core.setGroup(shRows, false, true)
end)

safe("Silent Aim", function()
	local fov = Core.makeFov(
		{ Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 220, 120) },
		{ Color3.fromRGB(255, 160, 50), Color3.fromRGB(255, 80, 100), Color3.fromRGB(255, 200, 90) }
	)
	local cfg = { parts = { Closest = true }, fovRef = fov, wall = false, hit = 100, force = true }
	local S = {
		active = false,
		on = false,
		method = "Camera Flick",
		spoof = nil,
		real = nil,
		missOff = Vector3.zero,
		nextRoll = 0,
		lastTarget = nil,
		errors = 0,
		errAt = 0,
	}

	local function holdingTool()
		local ch = LocalPlayer.Character
		return ch ~= nil and ch:FindFirstChildOfClass("Tool") ~= nil
	end


	local function update(dt)
		local c = workspace.CurrentCamera
		if not c or not S.active then
			S.on = false
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		local target = Core.nearestTarget(cfg, "SilentAim", c, mouse)
		local char = target and Core.alive(target, 2)
		local part = char and Core.pickPart(c, char, mouse, cfg.parts)
		if not part then
			S.on, S.spoof, S.lastTarget = false, nil, nil
			return
		end

		local hc = cfg.hit / 100
		local real = part.Position
		S.real = real
		local now = os.clock()
		if now >= S.nextRoll then
			S.nextRoll = now + 0.3 + math.random() * 0.3
			if math.random() < (1 - hc) ^ 1.2 then
				local dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
				S.missOff = (dir.Magnitude > 0 and dir.Unit or Vector3.yAxis) * (3 + math.random() * 4)
			else
				S.missOff = Vector3.zero
			end
		end

		if hc >= 1 then
			S.spoof = real
		else
			local goal = real + S.missOff
			if S.lastTarget ~= target or not S.spoof then
				S.spoof = goal
			else
				local rate = 2 + 38 * hc ^ 1.3
				S.spoof = S.spoof:Lerp(goal, 1 - math.exp(-dt * rate))
			end
		end
		S.lastTarget = target
		S.on = true
	end

	table.insert(Library.OnUnload, function()
		S.active, S.on = false, false
	end)


	local function selfDebug(err)
		warn("[curzs V3] silent aim: " .. tostring(err))
		pcall(Core.unflick)
		S.on, S.spoof, S.real, S.lastTarget, S.missOff, S.nextRoll = false, nil, nil, nil, Vector3.zero, 0
		local now = os.clock()
		if now - S.errAt > 5 then
			S.errors = 0
		end
		S.errAt = now
		S.errors += 1
		if S.errors == 3 then
			Library:Notify("Silent aim hit an error and was reset")
		end
	end

	local function aimPoint()

		return cfg.force and S.real or S.spoof
	end

	connect(RunService.Heartbeat, function(dt)
		local ok, err = pcall(function()
			update(dt)
			if not (S.on and S.spoof) or Core.RageOn then
				return
			end
			local aim = aimPoint()
			if not aim then
				return
			end
			local holding = holdingTool()
			if holding then

				for _ = 1, cfg.force and 3 or 1 do
					Core.sendAim(aim)
				end
			end
			if S.method == "Tool Flick" and not holding then
				return
			end
			if cfg.force then

				local ch = LocalPlayer.Character
				local head = ch and ch:FindFirstChild("Head")
				if head then
					Core.flickAt(head.Position, aim)
				else
					Core.flick(aim)
				end
			else
				Core.flick(aim)
			end
		end)
		if not ok then
			selfDebug(err)
		end
	end)
	connect(RunService.RenderStepped, function()
		local ok, err = pcall(function()
			fov:Update(UserInputService:GetMouseLocation())
			if S.on and S.spoof and holdingTool() and not Core.RageOn then
				local aim = aimPoint()
				if aim then
					Core.sendAim(aim)
				end
			end
		end)
		if not ok then
			selfDebug(err)
		end
	end)

	local main = silentTab:AddSection("Silent Aim", 1)
	main:AddToggle({
		Name = "Enable",
		Flag = "silent_enable",
		Keybind = {
			Mode = "Toggle",
			Title = "Silent Aim",
			OnActive = function(active)
				S.active = active
				if not active then
					S.on = false
				end
			end,
		},
	})
	main:AddDropdown({
		Name = "Method",
		Options = { "Camera Flick", "Tool Flick" },
		Default = "Camera Flick",
		Flag = "silent_method",
		Callback = function(value)
			S.method = value
		end,
	})
	main:AddLabel("No hooks. Tool Flick needs a tool in hand.")
	main:AddSlider({
		Name = "Hit Chance",
		Min = 0,
		Max = 100,
		Default = 100,
		Flag = "silent_hit",
		Callback = function(value)
			cfg.hit = value
		end,
	})
	main:AddToggle({
		Name = "Wall Check",
		Flag = "silent_wall",
		Callback = function(state)
			cfg.wall = state
		end,
	})
	main:AddToggle({
		Name = "Force Hit",
		Default = true,
		Flag = "silent_force",
		Callback = function(state)
			cfg.force = state
		end,
	})
	Core.hitUI(silentTab:AddSection("Hit Part", 1), cfg, "silent")
	Core.fovUI(silentTab:AddSection("FOV", 2), fov, "silent")
end)

local function myChar()
	local ch = LocalPlayer.Character
	return ch, ch and ch:FindFirstChildOfClass("Humanoid"), ch and ch:FindFirstChild("HumanoidRootPart")
end

safe("Movements", function()
	local V3 = Vector3.new
	local macro = { on = false, speed = 450, boost = 80, lastYaw = 0, normal = 16 }
	local fly = { on = false, speed = 100, anim = "Superman", vel = Vector3.zero, char = nil, joints = {}, cur = {}, f = 0, s = 0, u = 0, tilt = 0, roll = 0 }
	local cfs = { on = false, speed = 50 }
	local noclip, infjump = false, false


	connect(RunService.RenderStepped, function(dt)
		if not macro.on then
			return
		end
		local _, hum, root = myChar()
		local cam = workspace.CurrentCamera
		if not (hum and root and cam) or hum.Health <= 0 then
			return
		end
		hum.WalkSpeed = macro.speed
		local look = cam.CFrame.LookVector
		look = V3(look.X, 0, look.Z)
		if look.Magnitude < 1e-3 then
			return
		end
		look = look.Unit
		local yaw = math.atan2(-look.X, -look.Z)
		local diff = yaw - macro.lastYaw
		if diff > math.pi then
			diff -= 2 * math.pi
		elseif diff < -math.pi then
			diff += 2 * math.pi
		end
		macro.lastYaw = yaw
		local turn = math.abs(diff)
		if turn > 0.01 then
			local right = V3(-look.Z, 0, look.X)
			local sideBoost = right * (diff > 0 and -1 or 1)
			local power = turn * macro.boost * 60
			local vel = root.AssemblyLinearVelocity
			local extra = (look * 0.7 + sideBoost * 0.75) * power * dt
			root.AssemblyLinearVelocity = V3(vel.X + extra.X, vel.Y, vel.Z + extra.Z)
		end
	end)





	local Poses = {}

	Poses.Superman = function(t, f, s, u, pitch)
		local fw, bk = math.max(f, 0), math.max(-f, 0)
		local idle = 1 - fw
		local sway = math.sin(t * 2)
		local p = {}
		local tilt = -0.25 * idle + (pitch - 1.45) * fw + 0.28 * bk

		p.LeftHip = V3(-0.35 * idle - 0.28 * fw, 0, -0.05)
		p.LeftKnee = V3(-1.05 * idle - 0.55 * fw + sway * 0.05, 0, 0)
		p.RightHip = V3(0.12 * idle - 0.12 * fw, 0, 0.04)
		p.RightKnee = V3(-0.05 - 0.1 * fw, 0, 0)
		p.LeftAnkle = V3(0.35, 0, 0)
		p.RightAnkle = V3(0.1, 0, 0)

		p.LeftShoulder = V3(0.06 + 2.95 * fw + sway * 0.04, 0, -0.08 - 0.1 * fw)
		p.LeftElbow = V3(0.12 * idle, 0, 0)
		p.RightShoulder = V3(0.06 + sway * 0.03, 0, 0.1 + 0.06 * fw)
		p.RightElbow = V3(0.15 + 1.25 * fw, 0, 0)

		p.RightShoulder += V3(0, 0, math.max(s, 0) * 0.5)
		p.LeftShoulder -= V3(0, 0, math.max(-s, 0) * 0.5)

		p.LeftKnee = p.LeftKnee * (1 - math.max(u, 0) * 0.7)
		return p, tilt, -s * 0.45
	end

	Poses.Hover = function(t, f, s, u, pitch)
		local sway = math.sin(t * 1.6)
		local p = {}
		p.LeftShoulder = V3(0.1 + sway * 0.05, 0, -0.5 - 0.08 * sway)
		p.RightShoulder = V3(0.1 - sway * 0.05, 0, 0.5 + 0.08 * sway)
		p.LeftElbow = V3(0.3, 0, 0)
		p.RightElbow = V3(0.3, 0, 0)
		p.LeftHip = V3(-0.08 + sway * 0.04, 0, -0.05)
		p.RightHip = V3(0.08 - sway * 0.04, 0, 0.05)
		p.LeftKnee = V3(-0.25 + sway * 0.05, 0, 0)
		p.RightKnee = V3(-0.15 - sway * 0.05, 0, 0)
		return p, f * 0.38, -s * 0.3
	end

	Poses.Plane = function(t, f, s, u, pitch)
		local fw, bk = math.max(f, 0), math.max(-f, 0)
		local flap = math.sin(t * 3) * 0.04
		local p = {}
		local tilt = -0.15 * (1 - fw) + (pitch - 1.4) * fw + 0.2 * bk
		p.LeftShoulder = V3(0, 0, -1.5 - flap)
		p.RightShoulder = V3(0, 0, 1.5 + flap)
		p.LeftElbow = V3(0, 0, 0)
		p.RightElbow = V3(0, 0, 0)
		p.LeftHip = V3(-0.06, 0, -0.04)
		p.RightHip = V3(-0.06, 0, 0.04)
		p.LeftKnee = V3(-0.05, 0, 0)
		p.RightKnee = V3(-0.05, 0, 0)
		return p, tilt, -s * 0.85
	end

	Poses.Dive = function(t, f, s, u, pitch)
		local fw = math.max(f, 0)
		local p = {}
		local tilt = -0.55 * (1 - fw) + (pitch - 1.45) * fw
		p.LeftShoulder = V3(3.05, 0, -0.1)
		p.RightShoulder = V3(3.05, 0, 0.1)
		p.LeftElbow = V3(0, 0, 0)
		p.RightElbow = V3(0, 0, 0)
		p.LeftHip = V3(-0.04, 0, -0.02)
		p.RightHip = V3(-0.04, 0, 0.02)
		p.LeftKnee = V3(-0.04, 0, 0)
		p.RightKnee = V3(-0.04, 0, 0)
		p.LeftAnkle = V3(0.6, 0, 0)
		p.RightAnkle = V3(0.6, 0, 0)
		return p, tilt, -s * 0.5
	end

	Poses.Float = function(t, f, s, u, pitch)
		local a, b, c = math.sin(t * 0.9), math.sin(t * 1.3 + 1), math.sin(t * 0.7 + 2)
		local p = {}
		p.LeftShoulder = V3(0.4 + b * 0.3, 0, -0.55 - c * 0.2)
		p.RightShoulder = V3(0.4 - b * 0.3, 0, 0.55 + c * 0.2)
		p.LeftElbow = V3(0.5 + a * 0.2, 0, 0)
		p.RightElbow = V3(0.5 - a * 0.2, 0, 0)
		p.LeftHip = V3(-0.2 + c * 0.15, 0, -0.1)
		p.RightHip = V3(0.1 - c * 0.15, 0, 0.1)
		p.LeftKnee = V3(-0.5 + a * 0.2, 0, 0)
		p.RightKnee = V3(-0.35 - a * 0.2, 0, 0)
		return p, a * 0.15 - 0.15 + f * 0.25, b * 0.1 - s * 0.25
	end

	local JOINTS = {
		"Neck", "Waist", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow",
		"LeftHip", "RightHip", "LeftKnee", "RightKnee", "LeftAnkle", "RightAnkle",
	}

	local function bindChar(ch)
		fly.char = ch
		fly.joints, fly.cur = {}, {}
		for _, name in ipairs(JOINTS) do
			local m = ch:FindFirstChild(name, true)
			if m and m:IsA("Motor6D") then
				fly.joints[name] = { m = m, c0 = m.C0 }
			end
		end
	end

	local function restoreJoints()
		for _, j in pairs(fly.joints) do
			pcall(function()
				j.m.C0 = j.c0
			end)
		end
		fly.joints, fly.cur = {}, {}
	end

	local function flyStop()
		local ch, hum, root = myChar()
		restoreJoints()
		fly.char = nil
		fly.vel = Vector3.zero
		if ch then
			local animate = ch:FindFirstChild("Animate")
			if animate and animate:IsA("LocalScript") then
				animate.Disabled = false
			end
		end
		if hum then
			hum.PlatformStand = false
		end
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			local look = root.CFrame.LookVector
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
		end
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end

	local function flyStep(dt)
		local ch, hum, root = myChar()
		local cam = workspace.CurrentCamera
		if not (ch and hum and root and cam) or hum.Health <= 0 then
			return
		end
		if fly.char ~= ch then
			restoreJoints()
			bindChar(ch)
			local animate = ch:FindFirstChild("Animate")
			if animate and animate:IsA("LocalScript") then
				animate.Disabled = true
			end
		end
		hum.PlatformStand = true
		for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
			track:Stop(0.1)
		end


		local look = cam.CFrame.LookVector
		local flat = V3(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then
			local up = cam.CFrame.UpVector
			flat = V3(up.X, 0, up.Z)
		end
		flat = flat.Magnitude > 1e-3 and flat.Unit or V3(0, 0, -1)
		local rightV = V3(-flat.Z, 0, flat.X)
		local move = hum.MoveDirection
		local f, s = move:Dot(flat), move:Dot(rightV)
		local u = (hum.Jump and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0)
		local dir = look * f + rightV * s + Vector3.yAxis * u
		if dir.Magnitude > 1 then
			dir = dir.Unit
		end
		fly.vel = fly.vel:Lerp(dir * fly.speed, 1 - math.exp(-dt * 9))
		root.AssemblyLinearVelocity = fly.vel
		root.AssemblyAngularVelocity = Vector3.zero


		local k = 1 - math.exp(-dt * 8)
		fly.f += (f - fly.f) * k
		fly.s += (s - fly.s) * k
		fly.u += (u - fly.u) * k
		local pitch = math.asin(math.clamp(look.Y, -1, 1))
		local pose, tilt, roll = (Poses[fly.anim] or Poses.Superman)(os.clock(), fly.f, fly.s, fly.u, pitch)
		fly.tilt += (tilt - fly.tilt) * k
		fly.roll += (roll - fly.roll) * k
		pose.Neck = V3(-fly.tilt * 0.65, 0, 0)
		pose.Waist = V3(-fly.tilt * 0.1, 0, 0)
		local yaw = math.atan2(-flat.X, -flat.Z)
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(fly.tilt, 0, fly.roll)
		local jk = 1 - math.exp(-dt * 10)
		for name, j in pairs(fly.joints) do
			local goal = pose[name] or Vector3.zero
			local cur = (fly.cur[name] or Vector3.zero):Lerp(goal, jk)
			fly.cur[name] = cur
			j.m.C0 = j.c0 * CFrame.Angles(cur.X, cur.Y, cur.Z)
		end
	end
	connect(RunService.RenderStepped, function(dt)
		if fly.on then
			local ok, err = pcall(flyStep, dt)
			if not ok then
				warn("[curzs V3] flight: " .. tostring(err))
			end
		end
	end)


	connect(RunService.Heartbeat, function(dt)
		if not cfs.on or fly.on then
			return
		end
		local _, hum, root = myChar()
		if hum and root and hum.Health > 0 then
			local md = hum.MoveDirection
			if md.Magnitude > 0 then
				root.CFrame = root.CFrame + md * cfs.speed * dt
			end
		end
	end)
	connect(RunService.Stepped, function()
		if not noclip then
			return
		end
		local ch = myChar()
		if ch then
			for _, part in ipairs(ch:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end
	end)
	connect(UserInputService.JumpRequest, function()
		if infjump then
			local _, hum = myChar()
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end)


	local macroSec = moveTab:AddSection("Fake Macro", 1)
	macroSec:AddToggle({
		Name = "Fake Macro",
		Flag = "mv_macro",
		Keybind = {
			Mode = "Toggle",
			Title = "Macro",
			OnActive = function(active)
				Core.MacroOn = active
				macro.on = active
				local _, hum = myChar()
				if active then
					macro.normal = hum and hum.WalkSpeed or 16
					LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
				else
					if hum then
						hum.WalkSpeed = macro.normal
					end
					LocalPlayer.CameraMode = Enum.CameraMode.Classic
				end
			end,
		},
	})
	macroSec:AddSlider({
		Name = "Speed",
		Min = 0,
		Max = 1000,
		Default = 450,
		Suffix = "",
		Flag = "mv_macro_speed",
		Callback = function(value)
			macro.speed = value
		end,
	})
	macroSec:AddSlider({
		Name = "Turn Boost",
		Min = 0,
		Max = 200,
		Default = 80,
		Suffix = "",
		Flag = "mv_macro_boost",
		Callback = function(value)
			macro.boost = value
		end,
	})

	local flySec = moveTab:AddSection("Flight", 2)
	local flyRows = {}
	flySec:AddToggle({
		Name = "Flight",
		Flag = "mv_fly",
		Keybind = {
			Mode = "Toggle",
			Title = "Fly",
			OnActive = function(active)
				fly.on = active
				Core.FlyOn = active
				if not active then
					flyStop()
				end
			end,
		},
		Callback = function(state)
			Core.setGroup(flyRows, state)
		end,
	})
	flyRows[1] = flySec:AddSlider({
		Name = "Fly Speed",
		Min = 0,
		Max = 1000,
		Default = 100,
		Suffix = "",
		Flag = "mv_fly_speed",
		Callback = function(value)
			fly.speed = value
		end,
	})
	flyRows[2] = flySec:AddDropdown({
		Name = "Fly Animation",
		Options = { "Superman", "Hover", "Plane", "Dive", "Float" },
		Default = "Superman",
		Flag = "mv_fly_anim",
		Callback = function(value)
			fly.anim = value
		end,
	})
	Core.setGroup(flyRows, false, true)

	local cfSec = moveTab:AddSection("CFrame Speed", 1)
	cfSec:AddToggle({
		Name = "CFrame Speed",
		Flag = "mv_cfs",
		Keybind = {
			Mode = "Toggle",
			Title = "CFrame",
			OnActive = function(active)
				Core.CfsOn = active
				cfs.on = active
			end,
		},
	})
	cfSec:AddSlider({
		Name = "Speed",
		Min = 0,
		Max = 10000,
		Default = 50,
		Suffix = "",
		Flag = "mv_cfs_speed",
		Callback = function(value)
			cfs.speed = value
		end,
	})

	local miscSec = moveTab:AddSection("Misc", 2)
	miscSec:AddToggle({
		Name = "Noclip",
		Flag = "mv_noclip",
		Keybind = {
			Mode = "Toggle",
			Title = "Noclip",
			OnActive = function(active)
				noclip = active
			end,
		},
	})
	miscSec:AddToggle({
		Name = "Infinite Jump",
		Flag = "mv_infjump",
		Keybind = {
			Mode = "Toggle",
			Title = "Inf Jump",
			OnActive = function(active)
				infjump = active
			end,
		},
	})

	table.insert(Library.OnUnload, function()
		macro.on, cfs.on, noclip, infjump = false, false, false, false
		if fly.on then
			fly.on = false
			pcall(flyStop)
		end
	end)
end)

safe("Anti Aim", function()

	local VOID_UP = 1e9
	table.insert(Library.OnUnload, function()
		Core.PuppetReq.void = nil
	end)

	local voidSec = antiTab:AddSection("Void Spam", 1)
	voidSec:AddToggle({
		Name = "Void Spam",
		Flag = "aa_void",
		Keybind = {
			Mode = "Toggle",
			Title = "Void",
			OnActive = function(active)
				Core.PuppetReq.void = active
						and {
							pri = 1,
							fn = function(real)
								return real + Vector3.new(0, VOID_UP, 0)
							end,
						}
					or nil
			end,
		},
	})


	local emoteList = {
		{ "Floss", 86650444341667 },
		{ "Take The L", 87481618665215 },
		{ "Tornado", 81859224655399 },
		{ "67", 94678277882413 },
	}
	local emoteIds, emoteNames = {}, {}
	for _, e in ipairs(emoteList) do
		emoteIds[e[1]] = e[2]
		table.insert(emoteNames, e[1])
	end
	local emote = { pick = emoteNames[1], speed = 10, loop = true, track = nil }

	local function loadTrack(id)
		local _, hum = myChar()
		if not hum then
			return nil
		end
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local function try(animation)
			local ok, track = pcall(animator.LoadAnimation, animator, animation)
			if not ok or not track then
				return nil
			end
			local t0 = os.clock()
			while track.Length == 0 and os.clock() - t0 < 2 do
				task.wait(0.05)
			end
			if track.Length > 0 then
				return track
			end
			pcall(track.Destroy, track)
			return nil
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. id
		local track = try(anim)
		if track then
			return track
		end

		local ok, objects = pcall(function()
			return game:GetObjects("rbxassetid://" .. id)
		end)
		if ok and objects then
			for _, obj in ipairs(objects) do
				local found = obj:IsA("Animation") and obj or obj:FindFirstChildWhichIsA("Animation", true)
				if found then
					track = try(found)
					if track then
						return track
					end
				end
			end
		end
		return nil
	end



	local function setAnimate(disabled)
		local ch = myChar()
		local animate = ch and ch:FindFirstChild("Animate")
		if animate and animate:IsA("LocalScript") then
			animate.Disabled = disabled
		end
	end

	local function halt()
		if emote.track then
			pcall(function()
				emote.track:Stop(0.15)
			end)
			emote.track = nil
		end
		if Core.Emote.playing then
			Core.Emote.playing = false
			if not Core.FlyOn then
				setAnimate(false)
			end
		end
	end

	local starting = false
	local function startEmote()
		if starting then
			return
		end
		starting = true
		local id = emoteIds[emote.pick]
		local track = id and loadTrack(id)
		if not track then
			starting = false
			if id then
				emote.wanted = false
				Library:Notify("Couldn't load " .. tostring(emote.pick))
			end
			return
		end
		if not emote.wanted or Core.FlyOn then
			pcall(track.Destroy, track)
			starting = false
			return
		end
		emote.track = track
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped = emote.loop
		Core.Emote.playing = true
		setAnimate(true)
		local _, hum = myChar()
		if hum then
			for _, other in ipairs(hum:GetPlayingAnimationTracks()) do
				if other ~= track then
					other:Stop(0.1)
				end
			end
		end
		track.Stopped:Connect(function()
			if emote.track == track then
				emote.track = nil
				Core.Emote.playing = false
				if not emote.loop then
					emote.wanted = false
				end
				if not Core.FlyOn then
					setAnimate(false)
				end
			end
		end)
		track:Play(0.1, 1, emote.speed / 10)
		starting = false
	end

	local function stopEmote()
		emote.wanted = false
		halt()
	end

	local function playEmote()
		halt()
		emote.wanted = true
		startEmote()
	end



	local lastTry = 0
	connect(RunService.Heartbeat, function()
		if Core.FlyOn and emote.track then
			halt()
		end
		if emote.wanted and not Core.FlyOn and not emote.track and not starting and os.clock() - lastTry > 0.4 then
			lastTry = os.clock()
			task.spawn(startEmote)
		end
		if not (emote.track and Core.Emote.playing) then
			return
		end
		local _, hum = myChar()
		if not hum then
			return
		end
		for _, other in ipairs(hum:GetPlayingAnimationTracks()) do
			if other ~= emote.track and other.Priority.Value <= emote.track.Priority.Value then
				other:Stop(0.05)
			end
		end
	end)

	local emoteSec = antiTab:AddSection("Emotes", 1)
	emoteSec:AddDropdown({
		Name = "Emote",
		Options = emoteNames,
		Default = emoteNames[1],
		Flag = "aa_emote",
		Callback = function(value)
			emote.pick = value
		end,
	})
	emoteSec:AddSlider({
		Name = "Emote Speed",
		Min = 0,
		Max = 100,
		Default = 10,
		Suffix = "",
		Flag = "aa_emote_speed",
		Callback = function(value)
			emote.speed = value
			if emote.track then
				emote.track:AdjustSpeed(value / 10)
			end
		end,
	})
	emoteSec:AddToggle({
		Name = "Loop Emote",
		Default = true,
		Flag = "aa_emote_loop",
		Callback = function(state)
			emote.loop = state
			if emote.track then
				emote.track.Looped = state
			end
		end,
	})
	emoteSec:AddButtons({
		{ Name = "Play Emote", Callback = playEmote },
		{ Name = "Stop Emote", Callback = stopEmote },
	})
	table.insert(Library.OnUnload, stopEmote)






	local ORBIT = 1e12
	local TS = { on = false, char = nil, joints = {}, parts = {}, detached = false, angle = 0, neck = nil }


	local MODE_JOINTS = {
		["Torso"] = {
			Neck = true, LeftShoulder = true, RightShoulder = true, LeftHip = true, RightHip = true,
			["Left Shoulder"] = true, ["Right Shoulder"] = true, ["Left Hip"] = true, ["Right Hip"] = true,
		},
		["Arms + Torso"] = {
			Neck = true, LeftHip = true, RightHip = true, ["Left Hip"] = true, ["Right Hip"] = true,
		},
	}
	TS.mode = "Arms + Torso"
	local function collect(ch)
		TS.char = ch
		TS.joints, TS.parts = {}, {}
		local ROOT_JOINTS = MODE_JOINTS[TS.mode] or MODE_JOINTS.Torso
		for _, d in ipairs(ch:GetDescendants()) do
			if d:IsA("Motor6D") and ROOT_JOINTS[d.Name] and d.Part1 then
				table.insert(TS.joints, { inst = d, Name = d.Name, Part0 = d.Part0, Part1 = d.Part1, C0 = d.C0, C1 = d.C1, Parent = d.Parent })
				table.insert(TS.parts, d.Part1)
			end
		end
	end


	local function setDetached(state)
		TS.detached = state
		if not state then
			local _, _, root = myChar()
			if root then
				for _, part in ipairs(TS.parts) do
					pcall(function()
						part.CFrame = root.CFrame
						part.AssemblyLinearVelocity = Vector3.zero
					end)
				end
			end
		end
		for _, j in ipairs(TS.joints) do
			pcall(function()
				if state then
					if j.inst and j.inst.Parent then
						j.inst:Destroy()
					end
				elseif not (j.inst and j.inst.Parent) and j.Parent and j.Parent.Parent then
					local m = Instance.new("Motor6D")
					m.Name, m.Part0, m.Part1, m.C0, m.C1 = j.Name, j.Part0, j.Part1, j.C0, j.C1
					m.Parent = j.Parent
					j.inst = m
				end
			end)
		end
	end
	local function torsoOff()
		TS.on = false
		if TS.char then
			setDetached(false)
			local hum = TS.char:FindFirstChildOfClass("Humanoid")
			if hum and TS.neck ~= nil then
				pcall(function()
					hum.RequiresNeck = TS.neck
				end)
			end
		end
		TS.char, TS.neck = nil, nil
	end
	connect(RunService.Heartbeat, function(dt)
		if not TS.on then
			return
		end
		local ch, hum, root = myChar()
		if not (ch and root) then
			return
		end
		if TS.char ~= ch then
			collect(ch)
			TS.detached = false
			if hum then
				if TS.neck == nil then
					TS.neck = hum.RequiresNeck
				end
				pcall(function()
					hum.RequiresNeck = false
				end)
			end
		end
		local want = not Core.Emote.playing
		if want ~= TS.detached then
			setDetached(want)
		end
		if TS.detached then
			TS.angle += dt * 2
			local origin = root.Position + Vector3.new(math.cos(TS.angle), 0, math.sin(TS.angle)) * ORBIT
			for i, part in ipairs(TS.parts) do
				if part.Parent then
					part.CFrame = CFrame.new(origin + Vector3.new(i * 1.5, 0, 0))
						* CFrame.Angles(TS.angle * 3 + i, TS.angle * 2, 0)
					part.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)

	local spin = { on = false, speed = 360, angle = 0 }
	local spinBind = "CurzsSpin" .. HttpService:GenerateGUID(false)
	RunService:BindToRenderStep(spinBind, Enum.RenderPriority.Camera.Value + 2, function(dt)
		if not spin.on then
			return
		end
		local _, hum, root = myChar()
		if not (hum and root) then
			return
		end
		spin.angle = (spin.angle + math.rad(spin.speed) * dt) % (2 * math.pi)
		hum.AutoRotate = false
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, spin.angle, 0)
	end)
	table.insert(Library.OnUnload, function()
		pcall(RunService.UnbindFromRenderStep, RunService, spinBind)
		pcall(torsoOff)
		if spin.on then
			spin.on = false
			local _, hum = myChar()
			if hum then
				hum.AutoRotate = true
			end
		end
	end)

	local charSec = antiTab:AddSection("Character", 2)
	charSec:AddDropdown({
		Name = "Character",
		Options = { "Arms + Torso", "Torso" },
		Default = "Arms + Torso",
		Flag = "aa_char_mode",
		Callback = function(value)
			if TS.mode == value then
				return
			end
			TS.mode = value

			if TS.char then
				setDetached(false)
				TS.char = nil
			end
		end,
	})
	charSec:AddToggle({
		Name = "Enable Character",
		Flag = "aa_char",
		Keybind = {
			Mode = "Toggle",
			Title = "Torso",
			OnActive = function(active)
				if active then
					TS.on = true
				else
					torsoOff()
				end
			end,
		},
	})
	charSec:AddToggle({
		Name = "Spin Bot",
		Flag = "aa_spin",
		Keybind = {
			Mode = "Toggle",
			Title = "Spin",
			OnActive = function(active)
				spin.on = active
				if not active then
					local _, hum = myChar()
					if hum then
						hum.AutoRotate = true
					end
				end
			end,
		},
	})
	charSec:AddSlider({
		Name = "Spin Speed",
		Min = 0,
		Max = 1000,
		Default = 360,
		Suffix = "",
		Flag = "aa_spin_speed",
		Callback = function(value)
			spin.speed = value
		end,
	})
end)

local function buildList(tab, key, noun, features)
	local L = Core.Lists[key]
	local entries = {}
	local optionMap = {}
	local selected = {}
	local flagName = "list_" .. key

	local pickSec = tab:AddSection(noun .. " Players", 1)
	local picker = pickSec:AddMultiDropdown({
		Name = "Players",
		Options = {},
		Flag = false,
		Callback = function(set)
			selected = set
		end,
	})
	local listSec = tab:AddSection(noun .. "ed", 1)
	local holder = listSec:AddContainer()

	local function render()
		for _, child in ipairs(holder:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i, e in ipairs(entries) do
			local rowFrame = new("Frame", {
				Size = UDim2.new(1, 0, 0, 46),
				BorderSizePixel = 0,
				LayoutOrder = i,
			}, holder)
			corner(rowFrame, 10)
			themed(function()
				rowFrame.BackgroundColor3 = lift(0.08)
				rowFrame.BackgroundTransparency = 0.3
			end)
			local avatar = new("ImageLabel", {
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.fromOffset(34, 34),
				BackgroundTransparency = 1,
				Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", e.id),
			}, rowFrame)
			corner(avatar, 17)
			local display = label(rowFrame, e.display, 13, true)
			display.Position = UDim2.fromOffset(48, 5)
			display.Size = UDim2.new(1, -96, 0, 18)
			local uname = label(rowFrame, "@" .. e.name, 12, false, true)
			uname.Position = UDim2.fromOffset(48, 23)
			uname.Size = UDim2.new(1, -96, 0, 16)
			local x = new("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(26, 26),
				Text = "X",
				TextSize = 13,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.fromRGB(200, 60, 70),
				BackgroundTransparency = 0.4,
			}, rowFrame)
			corner(x, 8)
			themed(function()
				x.Font = Fonts[Theme.Font][2]
				x.TextColor3 = Theme.Text
			end)
			x.MouseButton1Click:Connect(function()
				for n, entry in ipairs(entries) do
					if entry.id == e.id then
						table.remove(entries, n)
						break
					end
				end
				L.ids[e.id] = nil
				Library.Flags[flagName] = entries
				queueSave()
				render()
			end)
		end
	end

	local function rebuildIds()
		L.ids = {}
		for _, e in ipairs(entries) do
			L.ids[e.id] = true
		end
	end

	register(flagName, entries, function(list)
		entries = {}
		for _, e in ipairs(type(list) == "table" and list or {}) do
			if type(e) == "table" and e.id then
				table.insert(entries, { id = e.id, name = tostring(e.name), display = tostring(e.display) })
			end
		end
		Library.Flags[flagName] = entries
		rebuildIds()
		render()
	end)

	local lastKey
	local function refreshPlayers()
		optionMap = {}
		local names = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then
				local text = p.DisplayName .. " (@" .. p.Name .. ")"
				optionMap[text] = p
				table.insert(names, text)
			end
		end
		table.sort(names)
		local key = table.concat(names, "|")
		if key ~= lastKey then
			lastKey = key
			picker:SetOptions(names)
		end
	end
	refreshPlayers()
	task.spawn(function()
		while Library.Gui and Library.Gui.Parent do
			task.wait(2)
			refreshPlayers()
		end
	end)
	connect(Players.PlayerAdded, refreshPlayers)
	connect(Players.PlayerRemoving, function()
		task.delay(0.2, refreshPlayers)
	end)

	pickSec:AddButton({
		Name = noun,
		Callback = function()
			local added = 0
			for text in pairs(selected) do
				local p = optionMap[text]
				if p and not L.ids[p.UserId] then
					table.insert(entries, { id = p.UserId, name = p.Name, display = p.DisplayName })
					L.ids[p.UserId] = true
					added += 1
				end
			end
			if added > 0 then
				picker:Clear()
				selected = {}
				Library.Flags[flagName] = entries
				queueSave()
				render()
			else
				Library:Notify("Pick a player first")
			end
		end,
	})

	local applies = tab:AddSection("Applies To", 2)
	for _, f in ipairs(features) do
		applies:AddToggle({
			Name = f[2],
			Flag = flagName .. "_" .. f[1],
			Callback = function(state)
				L.feat[f[1]] = state
			end,
		})
	end
	render()
end

safe("Whitelist", function()
	buildList(whiteTab, "white", "Whitelist", {
		{ "Aimbot", "Aimbot" },
		{ "SilentAim", "Silent Aim" },
		{ "ESP", "ESP" },
	})
end)
safe("Blacklist", function()
	buildList(blackTab, "black", "Blacklist", {
		{ "Aimbot", "Aimbot" },
		{ "SilentAim", "Silent Aim" },
		{ "ESP", "ESP" },
		{ "Ragebot", "Ragebot" },
		{ "All", "All" },
	})
end)

safe("Ragebot", function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local VIM
	pcall(function()
		VIM = game:GetService("VirtualInputManager")
	end)
	local GUNS = { "[Double-Barrel SG]", "[Revolver]", "[TacticalShotgun]" }

	local MAG = { ["[Double-Barrel SG]"] = 2, ["[Revolver]"] = 6, ["[TacticalShotgun]"] = 5 }
	local HEIGHT = 20
	local ATTACK_TIME, VOID_TIME = 1, 1
	local VOID_Y = 1e6
	local SWING = 10000
	local rb = {
		on = false, gun = GUNS[1], selected = "CLOSEST", waiting = false,
		reloading = false, reloadAt = 0, shots = 0, lastShot = 0, warnedGun = false,
		arrive = 0, phase = "attack", phaseT = 0, flip = 1, pull = true,
	}
	local rstate = { on = false, origin = nil }



	local pulledRoot, pulledCF = nil, nil
	local function releasePull()
		if pulledRoot then
			pcall(function()
				pulledRoot.Anchored = false
			end)
			pulledRoot, pulledCF = nil, nil
		end
	end
	connect(RunService.RenderStepped, function()
		if pulledRoot and pulledCF and pulledRoot.Parent then
			pulledRoot.CFrame = pulledCF
		end
	end)

	local function enterReal(root)
		if rstate.on then
			return
		end
		rstate.on = true
		rstate.origin = root.CFrame
		local _, hum0 = myChar()
		if hum0 then
			hum0.PlatformStand = true
		end
		Core.holdCamera(true)
	end
	local function leaveReal()
		if not rstate.on then
			return
		end
		rstate.on = false
		local _, hum1, root = myChar()
		if root and rstate.origin then
			root.CFrame = rstate.origin
			root.AssemblyLinearVelocity = Vector3.zero
		end
		rstate.origin = nil
		if hum1 and not Core.FlyOn then
			hum1.PlatformStand = false
		end
		Core.holdCamera(false)
	end
	local function clearReq()
		Core.RageOn = false
		releasePull()
		leaveReal()
	end

	local function nearestPlayer()
		local _, _, root = myChar()
		local ref = rstate.origin and rstate.origin.Position or (root and root.Position)
		if not ref then
			return nil
		end
		local best, bestD
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then
				local ch = Core.alive(p, 2)
				local r = ch and ch:FindFirstChild("HumanoidRootPart")
				if r then
					local d = (ref - r.Position).Magnitude
					if not bestD or d < bestD then
						best, bestD = p, d
					end
				end
			end
		end
		return best
	end


	local function blacklistMode()
		return Core.Lists.black.feat.Ragebot or Core.Lists.black.feat.All
	end
	local function pickTarget()
		if blacklistMode() then
			local _, _, root = myChar()
			local best, bestD
			for id in pairs(Core.Lists.black.ids) do
				local p = Players:GetPlayerByUserId(id)
				if p and p ~= LocalPlayer then
					local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					local d = (root and r) and (root.Position - r.Position).Magnitude or 1e9
					if not bestD or d < bestD then
						best, bestD = p, d
					end
				end
			end
			return best
		end
		if rb.selected == "CLOSEST" then
			return nearestPlayer()
		end
		return rb.selected
	end

	local function findGun()
		local ch = LocalPlayer.Character
		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
		return (ch and ch:FindFirstChild(rb.gun)) or (bp and bp:FindFirstChild(rb.gun))
	end

	local function ammoOf(tool)
		for _, n in ipairs({ "Ammo", "CurrentAmmo", "Clip" }) do
			local v = tool:FindFirstChild(n)
			if v and v:IsA("ValueBase") then
				return tonumber(v.Value)
			end
		end
		local a = tool:GetAttribute("Ammo")
		return type(a) == "number" and a or nil
	end

	local function fireReload(tool)
		pcall(function()
			local ev = ReplicatedStorage:FindFirstChild("MainEvent")
			if ev then
				ev:FireServer("Reload", tool)
			end
		end)
		if VIM then
			pcall(function()
				VIM:SendKeyEvent(true, Enum.KeyCode.R, false, game)
				task.delay(0.05, function()
					VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
				end)
			end)
		end
	end

	local function visibleFrom(origin, part, char)
		rayParams.FilterDescendantsInstances = { LocalPlayer.Character, char }
		return workspace:Raycast(origin, part.Position - origin, rayParams) == nil
	end


	local function goVoid(root)
		releasePull()
		rb.flip = -rb.flip
		root.CFrame = CFrame.new(rstate.origin.Position + Vector3.new(SWING * rb.flip, VOID_Y, 0))
		root.AssemblyLinearVelocity = Vector3.zero
	end

	local function step()
		if not rb.on then
			clearReq()
			return
		end
		if Core.TripBusy then
			return
		end
		local target = pickTarget()
		local tch = target and target.Character
		local thum = tch and tch:FindFirstChildOfClass("Humanoid")
		local troot = tch and tch:FindFirstChild("HumanoidRootPart")
		if not (thum and troot) then
			clearReq()
			return
		end

		if rb.selected == "CLOSEST" and not blacklistMode() then
			rb.waiting = false
		elseif rb.waiting then
			if thum.Health >= 10 then
				rb.waiting = false
			else
				clearReq()
				return
			end
		elseif thum.Health <= 2 then
			rb.waiting = true
			Library:Notify("Target dead")
			clearReq()
			return
		end

		local ch, hum, root = myChar()
		if not (ch and hum and root) or hum.Health <= 0 then
			clearReq()
			return
		end
		local tool = findGun()
		if not tool then
			if not rb.warnedGun then
				rb.warnedGun = true
				Library:Notify("Couldn't find " .. rb.gun)
			end
			clearReq()
			return
		end
		rb.warnedGun = false
		if tool.Parent ~= ch then
			hum:EquipTool(tool)
		end
		Core.RageOn = true
		enterReal(root)
		local now = os.clock()
		local ammo = ammoOf(tool)


		if rb.reloading then
			goVoid(root)
			local be = ch:FindFirstChild("BodyEffects")
			local reloadFlag = be and be:FindFirstChild("Reload")
			local stillReloading = reloadFlag ~= nil and reloadFlag.Value == true
			local timeout = now - rb.reloadAt > (ammo == nil and 2.8 or 6)
			if (ammo ~= nil and ammo > 0 and now - rb.reloadAt > 0.3 and not stillReloading) or timeout then
				rb.reloading, rb.shots = false, 0
				rb.phase, rb.phaseT, rb.arrive = "attack", now, now
			end
			return
		end
		local empty = (ammo ~= nil and ammo <= 0) or (ammo == nil and rb.shots >= (MAG[rb.gun] or 5))
		if empty then
			rb.reloading, rb.reloadAt = true, now
			fireReload(tool)
			goVoid(root)
			return
		end


		if rb.phase == "void" then
			goVoid(root)
			if now - rb.phaseT >= VOID_TIME then
				rb.phase, rb.phaseT, rb.arrive = "attack", now, now
			end
			return
		end
		if now - rb.phaseT >= ATTACK_TIME then
			rb.phase, rb.phaseT = "void", now
			goVoid(root)
			return
		end



		local pos, tp
		if rb.pull then
			local my = rstate.origin
			root.CFrame = my
			root.AssemblyLinearVelocity = Vector3.zero
			local front = my * CFrame.new(0, 0, -4)
			if pulledRoot ~= troot then
				releasePull()
			end
			pulledRoot = troot
			pulledCF = CFrame.lookAt(front.Position, my.Position)
			troot.Anchored = true
			troot.CFrame = pulledCF
			troot.AssemblyLinearVelocity = Vector3.zero
			pos, tp = my.Position, front.Position
		else
			releasePull()
			tp = troot.Position
			pos = tp + Vector3.new(0, HEIGHT, 0)
			root.CFrame = CFrame.lookAt(pos, tp, Vector3.xAxis)
			root.AssemblyLinearVelocity = Vector3.zero
		end

		local gate = rb.pull and 0.05 or 0.12
		if now - rb.arrive >= gate and tool.Parent == ch and now - rb.lastShot > 0.03 and visibleFrom(pos + Vector3.new(0, 1.5, 0), troot, tch) then
			local head = tch:FindFirstChild("Head")
			local ap = head and head.Position or tp
			for _ = 1, 3 do
				Core.sendAim(ap)
			end
			Core.flickAt(pos + Vector3.new(0, 1.5, 0), ap)
			tool:Activate()
			tool:Activate()
			Core.sendAim(ap)
			rb.lastShot = now
			rb.shots += 1
		end
	end

	connect(RunService.Heartbeat, function()
		local ok, err = pcall(step)
		if not ok then
			warn("[curzs V3] ragebot: " .. tostring(err))
			pcall(Core.unflick)
		end
	end)
	table.insert(Library.OnUnload, function()
		rb.on = false
		clearReq()
	end)


	local optionMap, lastKey = {}, nil
	local targetDrop
	local function refreshTargets()
		optionMap = { Closest = "CLOSEST" }
		local names = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then
				local text = p.DisplayName .. " (@" .. p.Name .. ")"
				optionMap[text] = p
				table.insert(names, text)
			end
		end
		table.sort(names)
		table.insert(names, 1, "Closest")
		local key = table.concat(names, "|")
		if key ~= lastKey then
			lastKey = key
			targetDrop:SetOptions(names)
		end
		rb.selected = optionMap[targetDrop:Get()] or "CLOSEST"
	end

	local main = rageTab:AddSection("Ragebot", 1)
	main:AddToggle({
		Name = "Ragebot",
		Flag = "rage_enable",
		Keybind = {
			Mode = "Toggle",
			Title = "Ragebot",
			OnActive = function(active)
				rb.on = active
				rb.reloading, rb.waiting = false, false
				rb.phase, rb.phaseT = "attack", os.clock()
				if not active then
					clearReq()
				end
			end,
		},
	})
	main:AddDropdown({
		Name = "Gun",
		Options = GUNS,
		Default = GUNS[1],
		Flag = "rage_gun",
		Callback = function(value)
			rb.gun = value
			rb.shots, rb.reloading = 0, false
		end,
	})
	main:AddToggle({
		Name = "Pull Target",
		Default = true,
		Flag = "rage_pull",
		Callback = function(state)
			rb.pull = state
			if not state then
				releasePull()
			end
		end,
	})
	targetDrop = main:AddDropdown({
		Name = "Target",
		Options = { "Closest" },
		Default = "Closest",
		Flag = false,
		Callback = function(value)
			rb.selected = optionMap[value] or "CLOSEST"
		end,
	})
	main:AddLabel("Blacklist > Ragebot ON uses blacklisted players")
	refreshTargets()
	task.spawn(function()
		while Library.Gui and Library.Gui.Parent do
			task.wait(2)
			pcall(refreshTargets)
		end
	end)
end)

safe("Protections", function()
	local prot = { fling = false, void = false, sit = false }
	local safeCF, safeAt = nil, 0
	local seatOff, seatChar = false, nil

	local function busy()
		return Core.RageOn or Core.TripBusy or Core.FlyOn or Core.CfsOn or Core.MacroOn or next(Core.PuppetReq) ~= nil
	end

	connect(RunService.Heartbeat, function()
		local ch, hum, root = myChar()
		if not (ch and hum and root) or hum.Health <= 0 then
			return
		end
		local now = os.clock()
		local vel = root.AssemblyLinearVelocity.Magnitude
		local pos = root.Position
		local isBusy = busy()


		if not isBusy and vel < 120 and pos.Y > -250 and pos.Y < 5000 and now - safeAt > 0.3 then
			safeCF, safeAt = root.CFrame, now
		end
		Core.SafeCF = safeCF


		if prot.fling and not isBusy then
			local ang = root.AssemblyAngularVelocity.Magnitude
			if vel > 250 or ang > 60 or pos.Y > 8000 then
				local near = pos.Y > 8000
				if not near then
					for _, p in ipairs(Players:GetPlayers()) do
						local r = p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
						if r and (r.Position - pos).Magnitude < 30 then
							near = true
							break
						end
					end
				end
				if near then
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
					if safeCF then
						root.CFrame = safeCF
					end
					hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				end
			end
		end


		if prot.void and not isBusy and pos.Y < -250 then
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = safeCF or CFrame.new(pos.X, 100, pos.Z)
		end


		local wantOff = prot.sit or Core.RageOn or false
		if seatChar ~= ch then
			seatChar, seatOff = ch, false
		end
		if wantOff ~= seatOff then
			seatOff = wantOff
			pcall(hum.SetStateEnabled, hum, Enum.HumanoidStateType.Seated, not wantOff)
		end
		if wantOff and hum.Sit then
			hum.Sit = false
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)


	connect(RunService.Stepped, function()
		if not prot.fling then
			return
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and p.Character then
				for _, part in ipairs(p.Character:GetChildren()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end
			end
		end
	end)
	pcall(function()
		workspace.FallenPartsDestroyHeight = -1e9
	end)

	local sec = moveTab:AddSection("Protection", 2)
	sec:AddToggle({
		Name = "Anti Fling",
		Flag = "prot_fling",
		Callback = function(state)
			prot.fling = state
		end,
	})
	sec:AddToggle({
		Name = "Anti Void",
		Flag = "prot_void",
		Callback = function(state)
			prot.void = state
		end,
	})
	sec:AddToggle({
		Name = "Anti Sit",
		Flag = "prot_sit",
		Callback = function(state)
			prot.sit = state
		end,
	})
end)

safe("Auto Debug", function()
	local notifyOn = false
	local since = {}
	local function fixed(msg)
		if notifyOn then
			Library:Notify("Debug: " .. msg, 2)
		end
	end
	task.spawn(function()
		while Library.Gui and Library.Gui.Parent do
			task.wait(1)
			pcall(function()
				local using = Core.RageOn or Core.TripBusy
				if camHold.n > 0 and not using then
					since.cam = since.cam or os.clock()
					if os.clock() - since.cam > 2 then
						since.cam = nil
						camHold.n = 1
						Core.holdCamera(false)
						fixed("released a stuck camera")
					end
				else
					since.cam = nil
				end
				if Core.PuppetReq.glide and not Core.TripBusy then
					Core.PuppetReq.glide = nil
					fixed("cleared a stray teleport")
				end
				if (Core.PuppetReq.rage or Core.PuppetReq.rbvoid) and not Core.RageOn then
					Core.PuppetReq.rage, Core.PuppetReq.rbvoid = nil, nil
					fixed("cleared a stray ragebot move")
				end
				if Core.flickSaved and os.clock() - (Core.flickTime or 0) > 0.3 then
					Core.unflick()
					fixed("put a stuck camera aim back")
				end
				local _, _, root = myChar()
				if root and not (using or Core.FlyOn or next(Core.PuppetReq)) and root.Position.Y > 50000 then
					root.AssemblyLinearVelocity = Vector3.zero
					root.CFrame = Core.SafeCF or CFrame.new(root.Position.X, 100, root.Position.Z)
					fixed("brought you back from the void")
				end
			end)
		end
	end)
	local sec = dataTab:AddSection("Debug", 1)
	sec:AddToggle({
		Name = "Debug Notifications",
		Flag = "debug_notify",
		Callback = function(state)
			notifyOn = state
		end,
	})
	sec:AddLabel("Auto debug is always on")
end)

safe("Auto Buy", function()
	local armor = { on = false, thr = 100 }
	local stim = { on = false, thr = 50 }
	local fireclick = exec("fireclickdetector")
	local fireprompt = exec("fireproximityprompt")
	local T = { busy = false, armorCool = 0, stimCool = 0, stockCool = 0 }
	local LIGHT = 1e6
	local cache = {}

	local function armorValue()
		local ch = LocalPlayer.Character
		local be = ch and ch:FindFirstChild("BodyEffects")
		local a = be and be:FindFirstChild("Armor")
		return a and tonumber(a.Value)
	end
	local function healthPct()
		local _, hum = myChar()
		if hum and hum.Health > 0 then
			return hum.Health / math.max(hum.MaxHealth, 1) * 100
		end
	end
	local function stimTool()
		for _, holder in ipairs({ LocalPlayer:FindFirstChildOfClass("Backpack"), LocalPlayer.Character }) do
			if holder then
				for _, t in ipairs(holder:GetChildren()) do
					if t:IsA("Tool") and t.Name:find("Stim", 1, true) then
						return t
					end
				end
			end
		end
	end
	local function useStim(tool)
		local _, hum = myChar()
		if hum then
			hum:EquipTool(tool)
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			tool:Activate()
		end
	end


	local function getItem(pattern)
		local hit = cache[pattern]
		if hit and hit.part.Parent then
			return hit
		end
		if cache.miss and cache.miss[pattern] and os.clock() < cache.miss[pattern] then
			return nil
		end
		local ig = workspace:FindFirstChild("Ignored")
		local item
		local shop = ig and ig:FindFirstChild("Shop")
		if shop then
			for _, d in ipairs(shop:GetChildren()) do
				if d.Name:find(pattern, 1, true) then
					item = d
					break
				end
			end
		end
		if not item then
			for _, d in ipairs((ig or workspace):GetDescendants()) do
				if (d:IsA("Model") or d:IsA("BasePart")) and d.Name:find(pattern, 1, true) then
					item = d
					break
				end
			end
		end
		if not item then
			cache.miss = cache.miss or {}
			cache.miss[pattern] = os.clock() + 5
			return nil
		end
		local part = item:IsA("BasePart") and item or item:FindFirstChild("Head") or item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
		if not part then
			return nil
		end
		hit = {
			part = part,
			cd = item:FindFirstChildWhichIsA("ClickDetector", true),
			pp = item:FindFirstChildWhichIsA("ProximityPrompt", true),
		}
		cache[pattern] = hit
		return hit
	end



	local function runTrip(pattern, doneFn)
		local info = getItem(pattern)
		if not info then
			if os.clock() - (T.lastNotify or 0) > 5 then
				T.lastNotify = os.clock()
				Library:Notify("Shop item not found: " .. pattern, 3)
			end
			return false
		end
		local _, _, root = myChar()
		if not root then
			return false
		end
		local origin = root.CFrame
		local dest = CFrame.new(info.part.Position + Vector3.new(0, 3, 0))
		Core.holdCamera(true)
		pcall(function()
			local t1 = os.clock()
			local nextFire = 0
			while not doneFn() and os.clock() - t1 < 3 do
				local _, _, r = myChar()
				if not r then
					break
				end
				r.CFrame = dest
				r.AssemblyLinearVelocity = Vector3.zero


				local now = os.clock()
				if now >= nextFire then
					nextFire = now + 0.1
					for _ = 1, 2 do
						if info.cd and fireclick then
							pcall(fireclick, info.cd)
						end
						if info.pp and fireprompt then
							pcall(fireprompt, info.pp)
						end
					end
				end
				RunService.Heartbeat:Wait()
			end
		end)
		local _, _, back = myChar()
		if back then
			back.CFrame = origin
			back.AssemblyLinearVelocity = Vector3.zero
		end
		Core.holdCamera(false)
		return doneFn()
	end

	local function trip(pattern, doneFn)
		local ok, res = pcall(runTrip, pattern, doneFn)
		if not ok then
			warn("[curzs V3] shop trip: " .. tostring(res))
			return false
		end
		return res
	end

	local function begin(job)
		T.busy = true
		Core.TripBusy = true
		task.spawn(function()
			local ok, err = pcall(job)
			if not ok then
				warn("[curzs V3] auto buy: " .. tostring(err))
			end
			Core.PuppetReq.glide = nil
			T.busy = false
			Core.TripBusy = false
		end)
	end

	local function armorFull()
		local v = armorValue()
		return v ~= nil and v >= 200
	end
	local function haveStim()
		return stimTool() ~= nil
	end

	connect(RunService.Heartbeat, function()
		if T.busy then
			return
		end
		local now = os.clock()
		if armor.on and now > T.armorCool then
			local a = armorValue()
			if a and a < armor.thr and a < (T.cap or math.huge) then
				begin(function()
					local startA = armorValue() or 0
					local last, lastChange, stalled = startA, os.clock(), false
					local function done()
						local v = armorValue() or 0
						local t = os.clock()
						if v ~= last then
							last, lastChange = v, t
						end
						if v >= armor.thr or v >= 200 then
							return true
						end

						if t - lastChange > (v > startA and 0.5 or 1) then
							stalled = true
							return true
						end
						return false
					end
					trip("[Full Armor]", done)
					local v = armorValue() or 0
					if stalled and v > 0 then
						T.cap = v
					end
					T.armorCool = os.clock() + (v > startA and 0.3 or 3)
				end)
				return
			end
		end
		if stim.on and now > T.stockCool and not haveStim() and healthPct() then

			begin(function()
				trip("[Stim]", haveStim)
				T.stockCool = os.clock() + 3
			end)
			return
		end
		if stim.on and now > T.stimCool then
			local pct = healthPct()
			if pct and pct < stim.thr then
				begin(function()
					if not haveStim() then
						trip("[Stim]", haveStim)
					end
					local tool = stimTool()
					if tool then
						useStim(tool)

						if not haveStim() then
							trip("[Stim]", haveStim)
						end
					end
					T.stimCool = os.clock() + 1
				end)
			end
		end
	end)
	table.insert(Library.OnUnload, function()
		armor.on, stim.on = false, false
		Core.PuppetReq.glide = nil
		Core.TripBusy = false
	end)

	local armorSec = autoTab:AddSection("Auto Armor", 1)
	armorSec:AddToggle({
		Name = "Auto Armor",
		Flag = "auto_armor",
		Callback = function(state)
			armor.on = state
			if state then
				task.spawn(getItem, "[Full Armor]")
			end
		end,
	})
	armorSec:AddSlider({
		Name = "Buy below",
		Min = 0,
		Max = 200,
		Default = 100,
		Suffix = "",
		Flag = "auto_armor_thr",
		Callback = function(value)
			armor.thr = value
			T.cap = nil
		end,
	})
	local stimSec = autoTab:AddSection("Auto Stim", 2)
	stimSec:AddToggle({
		Name = "Auto Stim",
		Flag = "auto_stim",
		Callback = function(state)
			stim.on = state
			if state then
				task.spawn(getItem, "[Stim]")
			end
		end,
	})
	stimSec:AddSlider({
		Name = "Use below health",
		Min = 0,
		Max = 100,
		Default = 50,
		Flag = "auto_stim_thr",
		Callback = function(value)
			stim.thr = value
		end,
	})
end)

safe("Rapid Fire", function()
	local rf = { on = false }
	local saved = {}

	local function isCooldown(name)
		local n = name:lower()
		if n:find("reload", 1, true) then
			return false
		end
		return n:find("cooldown", 1, true) or n:find("firerate", 1, true) or n:find("fire_rate", 1, true)
			or n:find("firedelay", 1, true) or n:find("shootdelay", 1, true) or n:find("shotdelay", 1, true)
			or n == "delay" or n == "debounce" or n:find("rateoffire", 1, true)
	end

	local function patchTool(tool)
		for _, d in ipairs(tool:GetDescendants()) do
			if d:IsA("ValueBase") and (d:IsA("NumberValue") or d:IsA("IntValue")) and isCooldown(d.Name) then
				if saved[d] == nil then
					saved[d] = d.Value
				end
				if d.Value ~= 0 then
					d.Value = 0
				end
			end
		end
		for name, value in pairs(tool:GetAttributes()) do
			if type(value) == "number" and isCooldown(name) then
				saved[tool] = saved[tool] or {}
				if saved[tool][name] == nil then
					saved[tool][name] = value
				end
				if value ~= 0 then
					tool:SetAttribute(name, 0)
				end
			end
		end
		pcall(function()
			tool.Enabled = true
		end)
	end

	local function patchAll()
		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
		for _, holder in ipairs({ bp, LocalPlayer.Character }) do
			if holder then
				for _, t in ipairs(holder:GetChildren()) do
					if t:IsA("Tool") then
						patchTool(t)
					end
				end
			end
		end
	end

	local function restoreAll()
		for inst, value in pairs(saved) do
			pcall(function()
				if type(value) == "table" then
					for name, v in pairs(value) do
						inst:SetAttribute(name, v)
					end
				else
					inst.Value = value
				end
			end)
		end
		saved = {}
	end


	local function isGun(tool)
		for _, n in ipairs({ "Ammo", "MaxAmmo", "CurrentAmmo", "Clip", "ShootingCooldown" }) do
			if tool:FindFirstChild(n) then
				return true
			end
		end
		local n = tool.Name:lower()
		for _, key in ipairs({ "gun", "shotgun", "sg", "revolver", "pistol", "rifle", "smg", "ak", "glock", "uzi", "mac", "ar", "deagle", "dagger" }) do
			if n:find(key, 1, true) then
				return key ~= "dagger"
			end
		end
		return false
	end



	local held = false
	connect(UserInputService.InputBegan, function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			held = true
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			held = false
		end
	end)
	local function fire()
		if not (rf.on and held) or Core.RageOn or UserInputService:GetFocusedTextBox() then
			return
		end
		local ch = LocalPlayer.Character
		local tool = ch and ch:FindFirstChildOfClass("Tool")
		if tool and isGun(tool) then
			pcall(function()
				tool.Enabled = true
			end)
			tool:Activate()
		end
	end
	connect(RunService.Heartbeat, function()
		if not rf.on then
			return
		end

		local ch = LocalPlayer.Character
		local tool = ch and ch:FindFirstChildOfClass("Tool")
		if tool and isGun(tool) then
			patchTool(tool)
		end
		fire()
	end)
	connect(RunService.Stepped, fire)
	connect(RunService.RenderStepped, fire)
	task.spawn(function()
		while Library.Gui and Library.Gui.Parent do
			task.wait(1)
			if rf.on then
				pcall(patchAll)
			end
		end
	end)
	table.insert(Library.OnUnload, function()
		rf.on = false
		restoreAll()
	end)

	local sec = weaponTab:AddSection("Rapid Fire", 1)
	sec:AddToggle({
		Name = "Rapid Fire",
		Flag = "misc_rapid",
		Callback = function(state)
			rf.on = state
			if state then
				pcall(patchAll)
			else
				restoreAll()
			end
		end,
	})
	sec:AddLabel("Hold M1 with a gun in hand")
end)

safe("ESP", function()
	local rnd = Random.new()
	local function randColors()
		local h = rnd:NextNumber()
		return {
			Color3.fromHSV(h, 0.75, 1),
			Color3.fromHSV((h + 0.14) % 1, 0.8, 1),
			Color3.fromHSV((h + 0.32) % 1, 0.85, 1),
		}
	end

	local E = {
		alive = true,
		dirty = true,
		main = false,
		box = false,
		fillOp = 20,
		skel = false,
		charm = false,
		charmTime = 2,
		hp = false,
		dist = false,
		name = false,
		display = true,
		distFont = "Gotham",
		nameFont = "Gotham",
		cBox = randColors(),
		cFill = randColors(),
		cSkel = randColors(),
		cCharm = randColors(),
		cHp = { Color3.fromRGB(70, 255, 120), Color3.fromRGB(255, 220, 70), Color3.fromRGB(255, 70, 70) },
		cDist = randColors(),
		cName = randColors(),
	}

	local gui = new("ScreenGui", {
		Name = HttpService:GenerateGUID(false),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 997,
	})
	protectGui(gui)
	table.insert(Library.OnUnload, function()
		E.alive = false
		gui:Destroy()
	end)

	local objs = {}

	local function textLabel(size)
		local l = new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(160, 14),
			AnchorPoint = Vector2.new(0.5, 0),
			TextSize = size,
			TextColor3 = WHITE,
			TextStrokeTransparency = 0.5,
			Visible = false,
			Text = "",
		}, gui)
		local g = new("UIGradient", {}, l)
		return l, g
	end

	local function newObj(player)
		local o = { player = player, lines = {}, segs = {}, segChar = nil, segTime = 0 }
		o.box = new("Frame", {
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
			Visible = false,
		}, gui)
		local st = stroke(o.box, 0, WHITE, 1.5)
		o.strokeGrad = new("UIGradient", {}, st)
		o.fillGrad = new("UIGradient", {}, o.box)

		o.hpBack = new("Frame", {
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Visible = false,
		}, gui)
		o.hpClip = new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, o.hpBack)
		o.hpFill = new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, o.hpClip)
		o.hpGrad = new("UIGradient", { Rotation = 90 }, o.hpFill)

		o.nameL, o.nameGrad = textLabel(13)
		o.distL, o.distGrad = textLabel(12)
		objs[player] = o
		return o
	end

	local function destroyObj(o)
		for _, inst in ipairs({ o.box, o.hpBack, o.nameL, o.distL }) do
			pcall(inst.Destroy, inst)
		end
		for _, line in ipairs(o.lines) do
			pcall(line.frame.Destroy, line.frame)
		end
	end

	local function applyColors(o)
		o.strokeGrad.Color = Core.seq(E.cBox)
		o.fillGrad.Color = Core.seq(E.cFill)
		o.nameGrad.Color = Core.seq(E.cName)
		o.distGrad.Color = Core.seq(E.cDist)
		o.hpGrad.Color = Core.seq(E.cHp)
		for _, line in ipairs(o.lines) do
			line.grad.Color = Core.seq(E.cSkel)
		end
	end

	local function getLine(o, i)
		local line = o.lines[i]
		if not line then
			local frame = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				ZIndex = 5,
				Visible = false,
			}, gui)
			local grad = new("UIGradient", { Color = Core.seq(E.cSkel) }, frame)
			line = { frame = frame, grad = grad }
			o.lines[i] = line
		end
		return line
	end






	local R15 = {
		{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
		{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
		{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
		{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
		{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
	}
	local R6 = {
		{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
		{ "Torso", "Left Leg" }, { "Torso", "Right Leg" },
	}
	local function isBodyPart(char, part)
		if not (part and part:IsA("BasePart")) or part.Name == "HumanoidRootPart" or part.Transparency >= 0.99 then
			return false
		end
		return part:FindFirstAncestorOfClass("Tool") == nil and part:FindFirstAncestorOfClass("Accessory") == nil
	end
	local function buildSegs(char)
		local segs, seen = {}, {}
		local function add(a, b)
			if a and b and a ~= b and isBodyPart(char, a) and isBodyPart(char, b) then
				local key = a:GetFullName() .. ">" .. b:GetFullName()
				if not seen[key] then
					seen[key] = true
					table.insert(segs, { a, b })
				end
			end
		end
		for _, pair in ipairs(R15) do
			add(char:FindFirstChild(pair[1], true), char:FindFirstChild(pair[2], true))
		end
		for _, pair in ipairs(R6) do
			add(char:FindFirstChild(pair[1], true), char:FindFirstChild(pair[2], true))
		end
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("Motor6D") and d.Part0 and d.Part1 and d.Part0:IsDescendantOf(char) and d.Part1:IsDescendantOf(char) then
				if not seen[d.Part1:GetFullName() .. ">" .. d.Part0:GetFullName()] then
					add(d.Part0, d.Part1)
				end
			end
		end
		return segs
	end

	local function setLine(frame, a, b)
		local d = b - a
		frame.Size = UDim2.fromOffset(d.Magnitude, 2)
		frame.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		frame.Rotation = math.deg(math.atan2(d.Y, d.X))
	end


	local function drawSkeleton(o, char, c, spin, cx, cy, k)
		local used = 0
		if E.skel then
			local now = os.clock()
			if o.segChar ~= char or (#o.segs == 0 and now - o.segTime > 0.5) or now - o.segTime > 3 then
				o.segs, o.segChar, o.segTime = buildSegs(char), char, now
			end
			for _, seg in ipairs(o.segs) do
				local p0, p1 = seg[1], seg[2]
				if p0.Parent and p1.Parent then
					local pa = c:WorldToViewportPoint(p0.Position)
					local pb = c:WorldToViewportPoint(p1.Position)
					if pa.Z > 0 and pb.Z > 0 then
						used += 1
						local line = getLine(o, used)
						line.frame.Visible = true
						line.grad.Rotation = spin
						setLine(
							line.frame,
							Vector2.new(cx + (pa.X - cx) * k, cy + (pa.Y - cy) * k),
							Vector2.new(cx + (pb.X - cx) * k, cy + (pb.Y - cy) * k)
						)
					end
				end
			end
		end
		for i = used + 1, #o.lines do
			o.lines[i].frame.Visible = false
		end
	end

	local function hideObj(o)
		o.box.Visible = false
		o.hpBack.Visible = false
		o.nameL.Visible = false
		o.distL.Visible = false
		for _, line in ipairs(o.lines) do
			line.frame.Visible = false
		end
	end

	local function update()
		local c = workspace.CurrentCamera
		if not c then
			return
		end
		local t = os.clock()
		local spin = (t * 70) % 360
		local viewH = c.ViewportSize.Y
		local tanHalf = math.tan(math.rad(c.FieldOfView) / 2)
		for player, o in pairs(objs) do
			if E.dirty then
				applyColors(o)
			end
			local char, hum = Core.alive(player)


			local show, cx, cy, h = false, 0, 0, 0
			if E.main and char and Core.canTarget(player, "ESP") then
				local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
				if root then
					local scale = 1
					pcall(function()
						scale = char:GetScale()
					end)
					local top = c:WorldToViewportPoint(root.Position + Vector3.new(0, 2.7 * scale, 0))
					local bot = c:WorldToViewportPoint(root.Position - Vector3.new(0, 3.1 * scale, 0))
					if top.Z > 0 and bot.Z > 0 then
						show = true
						h = math.abs(bot.Y - top.Y)
						cx, cy = (top.X + bot.X) / 2, (top.Y + bot.Y) / 2
					end
				end
			end
			if not show then
				hideObj(o)
			else
				local w = h * 0.55
				local minX, minY, maxY = cx - w / 2, cy - h / 2, cy + h / 2

				o.box.Visible = E.box
				if E.box then
					o.box.Position = UDim2.fromOffset(minX, minY)
					o.box.Size = UDim2.fromOffset(w, h)
					o.box.BackgroundTransparency = 1 - E.fillOp / 100
					o.strokeGrad.Rotation = spin
					o.fillGrad.Rotation = -spin * 0.6
				end

				o.hpBack.Visible = E.hp
				if E.hp then
					local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
					o.hpBack.Position = UDim2.fromOffset(minX - 7, minY)
					o.hpBack.Size = UDim2.fromOffset(4, h)
					o.hpClip.Size = UDim2.new(1, 0, 0, h * frac)
					o.hpFill.Size = UDim2.fromOffset(4, h)
				end

				o.nameL.Visible = E.name
				if E.name then
					o.nameL.Font = Fonts[E.nameFont][2]
					o.nameL.Text = E.display and player.DisplayName or player.Name
					o.nameL.Position = UDim2.fromOffset(cx, minY - 16)
					o.nameGrad.Rotation = spin
				end

				o.distL.Visible = E.dist
				if E.dist then
					local root = char:FindFirstChild("HumanoidRootPart")
					o.distL.Font = Fonts[E.distFont][1]
					o.distL.Text = root and (math.floor((root.Position - c.CFrame.Position).Magnitude) .. " studs") or ""
					o.distL.Position = UDim2.fromOffset(cx, maxY + 2)
					o.distGrad.Rotation = -spin
				end

				drawSkeleton(o, char, c, spin, cx, cy, 1)
			end
		end
		E.dirty = false
	end
	connect(RunService.RenderStepped, function()
		local ok, err = pcall(update)
		if not ok then
			warn("[curzs V3] esp: " .. tostring(err))
		end
	end)


	local function watchPlayer(player)
		if player == LocalPlayer or objs[player] then
			return
		end
		local o = newObj(player)
		E.dirty = true
		return o
	end
	for _, p in ipairs(Players:GetPlayers()) do
		watchPlayer(p)
	end
	connect(Players.PlayerAdded, watchPlayer)
	connect(Players.PlayerRemoving, function(player)
		local o = objs[player]
		if o then
			objs[player] = nil
			destroyObj(o)
		end
	end)


	local lastAttack = 0
	connect(UserInputService.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			lastAttack = os.clock()
		end
	end)

	local function sampleColors(colors, x)
		local pos = (x % 1) * 3
		local i = math.floor(pos)
		return colors[i % 3 + 1]:Lerp(colors[(i + 1) % 3 + 1], pos - i)
	end



	local function spawnCharm(char)
		if not (E.main and E.charm) or E.charmTime <= 0 then
			return
		end
		local old = char:FindFirstChild("CurzsCharm")
		if old then
			old:Destroy()
		end
		local hl = Instance.new("Highlight")
		hl.Name = "CurzsCharm"
		hl.Adornee = char
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillTransparency = 0.35
		hl.OutlineTransparency = 0.1
		hl.Parent = char
		local dur = E.charmTime
		local colors = E.cCharm
		task.spawn(function()
			local t0 = os.clock()
			while hl.Parent and E.alive do
				local a = (os.clock() - t0) / dur
				if a >= 1 then
					break
				end
				local col = sampleColors(colors, a * 2.5)
				local fade = math.clamp((a - 0.3) / 0.7, 0, 1)
				hl.FillColor = col
				hl.OutlineColor = sampleColors(colors, a * 2.5 + 0.33)
				hl.FillTransparency = 0.35 + 0.65 * fade
				hl.OutlineTransparency = 0.1 + 0.9 * fade
				RunService.RenderStepped:Wait()
			end
			hl:Destroy()
		end)
	end

	local function watchHits(player)
		if player == LocalPlayer then
			return
		end
		local function hook(char)
			local hum = char:WaitForChild("Humanoid", 5)
			if not hum then
				return
			end
			local last = hum.Health
			hum.HealthChanged:Connect(function(health)
				if E.alive and health < last and os.clock() - lastAttack < 0.8 then
					local mine = LocalPlayer.Character
					if mine and mine:FindFirstChildOfClass("Tool") then
						spawnCharm(char)
					end
				end
				last = health
			end)
		end
		if player.Character then
			task.spawn(hook, player.Character)
		end
		connect(player.CharacterAdded, hook)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		watchHits(p)
	end
	connect(Players.PlayerAdded, watchHits)


	local function colorRow(sec, name, key, flag)
		sec:AddColorRow({
			Name = name,
			Defaults = E[key],
			Flag = flag,
			Callback = function(colors)
				E[key] = colors
				E.dirty = true
			end,
		})
	end
	local function toggle(sec, name, key, flag)
		sec:AddToggle({
			Name = name,
			Flag = flag,
			Callback = function(state)
				E[key] = state
			end,
		})
	end
	local function fontDrop(sec, key, flag)
		sec:AddDropdown({
			Name = "Font",
			Options = FontNames,
			Default = "Gotham",
			Flag = flag,
			Callback = function(value)
				E[key] = value
			end,
		})
	end

	local mainSec = espTab:AddSection("Main ESP", 1)
	toggle(mainSec, "Main ESP", "main", "esp_main")

	local boxSec = espTab:AddSection("Box", 1)
	toggle(boxSec, "Box", "box", "esp_box")
	colorRow(boxSec, "Outline Colors", "cBox", "esp_box_out")
	colorRow(boxSec, "Fill Colors", "cFill", "esp_box_fill")
	boxSec:AddSlider({
		Name = "Fill Opacity",
		Min = 0,
		Max = 100,
		Default = 20,
		Flag = "esp_fill_op",
		Callback = function(value)
			E.fillOp = value
		end,
	})

	local skelSec = espTab:AddSection("Skeleton", 1)
	toggle(skelSec, "Skeleton", "skel", "esp_skel")
	colorRow(skelSec, "Colors", "cSkel", "esp_skel_col")

	local charmSec = espTab:AddSection("Hit Charm", 1)
	toggle(charmSec, "Hit Charm", "charm", "esp_charm")
	colorRow(charmSec, "Colors", "cCharm", "esp_charm_col")
	charmSec:AddSlider({
		Name = "Duration",
		Min = 0,
		Max = 5,
		Increment = 0.1,
		Default = 2,
		Suffix = "s",
		Flag = "esp_charm_dur",
		Callback = function(value)
			E.charmTime = value
		end,
	})

	local hpSec = espTab:AddSection("Health Bar", 2)
	toggle(hpSec, "Health Bar", "hp", "esp_hp")
	colorRow(hpSec, "Full / Mid / Low", "cHp", "esp_hp_col")

	local distSec = espTab:AddSection("Distance", 2)
	toggle(distSec, "Distance", "dist", "esp_dist")
	colorRow(distSec, "Colors", "cDist", "esp_dist_col")
	fontDrop(distSec, "distFont", "esp_dist_font")

	local nameSec = espTab:AddSection("Name", 2)
	toggle(nameSec, "Name", "name", "esp_name")
	colorRow(nameSec, "Colors", "cName", "esp_name_col")
	fontDrop(nameSec, "nameFont", "esp_name_font")
	nameSec:AddToggle({
		Name = "Display",
		Default = true,
		Flag = "esp_display",
		Callback = function(state)
			E.display = state
		end,
	})
end)

safe("UI Settings", function()

local interface = uiTab:AddSection("Interface")
interface:AddColorPicker({
	Name = "Accent Color",
	Default = Theme.Accent,
	Flag = "ui_accent",
	Callback = function(color)
		Theme.Accent = color
		refresh()
	end,
})
interface:AddColorPicker({
	Name = "Font Color",
	Default = Theme.Text,
	Flag = "ui_text",
	Callback = function(color)
		Theme.Text = color
		refresh()
	end,
})
interface:AddColorPicker({
	Name = "Panel Color",
	Default = Theme.Box,
	Flag = "ui_panel",
	Callback = function(color)
		Theme.Box = color
		refresh()
	end,
})
interface:AddDropdown({
	Name = "Font",
	Options = FontNames,
	Default = Theme.Font,
	Flag = "ui_font",
	Callback = function(name)
		Theme.Font = name
		refresh()
	end,
})
interface:AddSlider({
	Name = "Background Dim",
	Min = 0,
	Max = 100,
	Default = 60,
	Flag = "ui_opacity",
	Callback = function(value)
		Theme.Dim = 1 - value / 100
		refresh()
	end,
})
interface:AddSlider({
	Name = "Section Opacity",
	Min = 0,
	Max = 100,
	Default = 65,
	Flag = "ui_boxop",
	Callback = function(value)
		Theme.BoxTrans = 1 - value / 100
		refresh()
	end,
})

local outlines = uiTab:AddSection("Outlines")
outlines:AddColorPicker({
	Name = "Window Outline",
	Default = Theme.Outline,
	Flag = "ui_outline",
	Callback = function(color)
		Theme.Outline = color
		refresh()
	end,
})
outlines:AddSlider({
	Name = "Window Outline Opacity",
	Min = 0,
	Max = 100,
	Default = 14,
	Flag = "ui_outline_op",
	Callback = function(value)
		Theme.OutlineTrans = 1 - value / 100
		refresh()
	end,
})
outlines:AddSlider({
	Name = "Window Outline Thickness",
	Min = 0,
	Max = 4,
	Increment = 0.5,
	Default = 1,
	Suffix = "px",
	Flag = "ui_outline_th",
	Callback = function(value)
		Theme.OutlineThick = value
		refresh()
	end,
})
outlines:AddColorPicker({
	Name = "Panel Outline",
	Default = Theme.Edge,
	Flag = "ui_edge",
	Callback = function(color)
		Theme.Edge = color
		refresh()
	end,
})
outlines:AddSlider({
	Name = "Panel Outline Opacity",
	Min = 0,
	Max = 100,
	Default = 10,
	Flag = "ui_edge_op",
	Callback = function(value)
		Theme.EdgeTrans = 1 - value / 100
		refresh()
	end,
})

local windowSec = uiTab:AddSection("Window")
windowSec:AddSlider({
	Name = "Corner Radius",
	Min = 0,
	Max = 28,
	Default = 18,
	Suffix = "px",
	Flag = "ui_radius",
	Callback = function(value)
		Theme.Radius = value
		refresh()
	end,
})
windowSec:AddSlider({
	Name = "UI Scale",
	Min = 70,
	Max = 110,
	Default = 100,
	Flag = "ui_scale",
	Callback = function(value)
		Theme.UIScale = value / 100
		refresh()
	end,
})
windowSec:AddToggle({
	Name = "Wallpaper",
	Default = true,
	Flag = "ui_wallpaper",
	Callback = function(state)
		Theme.Wallpaper = state
		refresh()
	end,
})

local notifySec = uiTab:AddSection("Notifications")
notifySec:AddToggle({
	Name = "Sound",
	Default = true,
	Flag = "ui_sound",
	Callback = function(state)
		Theme.Sound = state
	end,
})
notifySec:AddSlider({
	Name = "Volume",
	Min = 0,
	Max = 100,
	Default = 60,
	Flag = "ui_volume",
	Callback = function(value)
		Theme.Volume = value / 100
	end,
})
notifySec:AddSlider({
	Name = "Duration",
	Min = 1,
	Max = 10,
	Increment = 0.5,
	Default = 2.5,
	Suffix = "s",
	Flag = "ui_notifytime",
	Callback = function(value)
		Theme.NotifyTime = value
	end,
})
notifySec:AddButton({
	Name = "Test Notification",
	Callback = function()
		Library:Notify("This is a test notification")
	end,
})

local menu = uiTab:AddSection("Menu")
menu:AddKeybind({
	Name = "Menu Key",
	Default = Enum.KeyCode.RightShift,
	Flag = "ui_menukey",
	Callback = function()
		window:Toggle()
	end,
})
menu:AddButton({
	Name = "Unload UI",
	Callback = function()
		Library:Unload()
	end,
})

local presets = {
	{ Name = "Midnight", Accent = Color3.fromRGB(110, 140, 255), Box = Color3.fromRGB(10, 12, 22), Text = Color3.fromRGB(238, 241, 252) },
	{ Name = "Amethyst", Accent = Color3.fromRGB(148, 118, 255), Box = Color3.fromRGB(14, 12, 24), Text = Color3.fromRGB(240, 238, 250) },
	{ Name = "Sakura", Accent = Color3.fromRGB(255, 126, 179), Box = Color3.fromRGB(22, 12, 18), Text = Color3.fromRGB(252, 238, 245) },
	{ Name = "Emerald", Accent = Color3.fromRGB(72, 214, 150), Box = Color3.fromRGB(8, 18, 15), Text = Color3.fromRGB(234, 250, 243) },
	{ Name = "Crimson", Accent = Color3.fromRGB(255, 82, 98), Box = Color3.fromRGB(20, 9, 11), Text = Color3.fromRGB(252, 236, 238) },
	{ Name = "Ice", Accent = Color3.fromRGB(96, 208, 255), Box = Color3.fromRGB(8, 16, 24), Text = Color3.fromRGB(236, 248, 254) },
	{ Name = "Sunset", Accent = Color3.fromRGB(255, 160, 90), Box = Color3.fromRGB(22, 14, 10), Text = Color3.fromRGB(253, 242, 232) },
	{ Name = "Mono", Accent = Color3.fromRGB(230, 230, 238), Box = Color3.fromRGB(12, 12, 14), Text = Color3.fromRGB(240, 240, 242) },
}

local function applyPreset(preset)
	local values = {
		ui_accent = preset.Accent,
		ui_text = preset.Text,
		ui_panel = preset.Box,
		ui_outline = preset.Accent,
		ui_outline_op = 30,
	}
	Library.Loading = true
	for flag, value in pairs(values) do
		local setter = Library.Setters[flag]
		if setter then
			pcall(setter, value)
		end
	end
	Library.Loading = false
	Library:SaveNow()
	Library:Notify("Applied " .. preset.Name)
end

local presetsSec = cfgTab:AddSection("UI Presets")
for i = 1, #presets, 2 do
	local a, b = presets[i], presets[i + 1]
	local row = {
		{ Name = a.Name, Callback = function() applyPreset(a) end },
	}
	if b then
		table.insert(row, { Name = b.Name, Callback = function() applyPreset(b) end })
	end
	presetsSec:AddButtons(row)
end

local uiConfigs = cfgTab:AddSection("UI Configs")
local uiConfigName = uiConfigs:AddTextbox({ Name = "UI Config Name", Placeholder = "UI config name", Flag = false })
local uiConfigList = uiConfigs:AddDropdown({
	Name = "Saved UI Configs",
	Options = Library:GetUIConfigs(),
	Flag = false,
})

local function pickUIName()
	local name = cleanName(uiConfigName:Get())
	if name == "" then
		name = cleanName(uiConfigList:Get())
	end
	return name
end

uiConfigs:AddButtons({
	{
		Name = "Save UI",
		Callback = function()
			local name = pickUIName()
			if name == "" then
				Library:Notify("Enter a UI config name")
				return
			end
			Library:SaveUIConfig(name)
			uiConfigList:SetOptions(Library:GetUIConfigs())
			uiConfigList:Set(name)
			Library:Notify("Saved UI " .. name)
		end,
	},
	{
		Name = "Load UI",
		Callback = function()
			local name = pickUIName()
			if name ~= "" and Library:LoadUIConfig(name) then
				Library:Notify("Loaded UI " .. name)
			else
				Library:Notify("UI config not found")
			end
		end,
	},
})
uiConfigs:AddButtons({
	{
		Name = "Delete UI",
		Callback = function()
			local name = pickUIName()
			if name == "" then
				Library:Notify("Select a UI config")
				return
			end
			Library:DeleteUIConfig(name)
			uiConfigList:SetOptions(Library:GetUIConfigs())
			Library:Notify("Deleted UI " .. name)
		end,
	},
	{
		Name = "Refresh",
		Callback = function()
			uiConfigList:SetOptions(Library:GetUIConfigs())
			Library:Notify("Refreshed")
		end,
	},
})

local configs = cfgTab:AddSection("Configs")
local configName = configs:AddTextbox({ Name = "Config Name", Placeholder = "Config name", Flag = false })
local configList = configs:AddDropdown({
	Name = "Saved Configs",
	Options = Library:GetConfigs(),
	Flag = false,
})

local function pickName()
	local name = cleanName(configName:Get())
	if name == "" then
		name = cleanName(configList:Get())
	end
	return name
end

configs:AddButtons({
	{
		Name = "Save",
		Callback = function()
			local name = pickName()
			if name == "" then
				Library:Notify("Enter a config name")
				return
			end
			Library:SaveConfig(name)
			configList:SetOptions(Library:GetConfigs())
			configList:Set(name)
			Library:Notify("Saved " .. name)
		end,
	},
	{
		Name = "Load",
		Callback = function()
			local name = pickName()
			if name ~= "" and Library:LoadConfig(name) then
				Library:Notify("Loaded " .. name)
			else
				Library:Notify("Config not found")
			end
		end,
	},
})
configs:AddButtons({
	{
		Name = "Delete",
		Callback = function()
			local name = pickName()
			if name == "" then
				Library:Notify("Select a config")
				return
			end
			Library:DeleteConfig(name)
			configList:SetOptions(Library:GetConfigs())
			Library:Notify("Deleted " .. name)
		end,
	},
	{
		Name = "Refresh",
		Callback = function()
			configList:SetOptions(Library:GetConfigs())
			Library:Notify("Refreshed")
		end,
	},
})

end)

end)
if not built then
	warn("[curzs V3] UI build error: " .. tostring(buildError))
end

window:SetVisible(true)

task.delay(0.8, function()
	Library:Notify("UI made by Harve " .. utf8.char(0x1F528), 4)
end)

return Library
