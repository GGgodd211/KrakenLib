--[[
	KrakenUI — премиальная переиспользуемая GUI-библиотека для executor-скриптов (Roblox Luau)

	Единый монолитный файл: без require, без внешних модулей, без сторонних зависимостей.
	Внутри — только UI-фреймворк (окна, вкладки, секции, элементы управления, тема, шрифты,
	иконки, звук, анимации, лоадер, нотификации, key-screen, окно настроек, редактор биндов)
	и ни строчки игровой логики. Подключи файл в пустой скрипт — библиотека поднимет пустое
	окно и не упадёт.

	Публичный API вызывается через один и тот же объект-библиотеку — назови его как хочешь:

		local KrakenLib = loadstring(readfile("KrakenUI.luau"))()

		KrakenLib:Window(opts) -> Window
		Window:Tab(opts) -> Tab
		Tab:Section(opts) -> Section
		Tab:Accordion() -> Accordion
		Section:Toggle / :Slider / :Dropdown / :Keybind / :Colorpicker / :Textbox / :Button
		Section:Label / :Divider / :Paragraph / :Radio / :Stepper / :ProgressBar / :Table / :Image
		Section:Row(count) / :Group(opts)

		KrakenLib:Notification(opts)
		KrakenLib:Announcement(opts)
		KrakenLib:Modal(opts)
		KrakenLib:ContextMenu():Attach(guiObject, items)
		KrakenLib:Loader(opts):Run(onDone)
		KrakenLib:KeySystem(opts):Prompt(onSuccess)
		KrakenLib:Watermark(opts) / KrakenLib:KeybindList(opts)
		KrakenLib:Settings(opts) / KrakenLib:KeybindEditor()
		KrakenLib:Search(query) / KrakenLib:ScrollToFlag(flag)
		KrakenLib:GetWindow(name) / KrakenLib:CloseAll()
		KrakenLib:Unload()

		KrakenLib.Theming    — темы, акцент, радиус, плотность, экспорт/импорт темы
		KrakenLib.Fonts      — встроенные + кастомные шрифты
		KrakenLib.Icons      — иконки (Get/Register/List)
		KrakenLib.Sounds     — UI-звуки (click/hover/toggle), кастомные звуки
		KrakenLib.Animations — переиспользуемые анимационные пресеты
		KrakenLib.Events     — глобальная шина событий
		KrakenLib.Hotkeys    — глобальные хоткеи
		KrakenLib.Tooltip    — всплывающие подсказки
		KrakenLib.Config     — сохранение/загрузка Flags на диск
		KrakenLib.Flags / KrakenLib._elements — значения и объекты всех элементов по флагам

	Полная документация — в README.md.
--]]

local Library = {}
Library.__index = Library

------------------------------------------------------------------
-- СЕРВИСЫ
------------------------------------------------------------------
local cloneref = cloneref or function(x) return x end

local TweenService      = cloneref(game:GetService("TweenService"))
local UserInputService  = cloneref(game:GetService("UserInputService"))
local RunService        = cloneref(game:GetService("RunService"))
local Players           = cloneref(game:GetService("Players"))
local HttpService       = cloneref(game:GetService("HttpService"))
local SoundService       = cloneref(game:GetService("SoundService"))

local LocalPlayer = Players.LocalPlayer

local function getGui()
	local ok, gui = pcall(function()
		if gethui then return gethui() end
		return LocalPlayer:WaitForChild("PlayerGui")
	end)
	if ok and gui then return gui end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function protect(inst)
	local ok = pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(inst)
		elseif protect_gui then
			protect_gui(inst)
		end
	end)
	return ok
end

------------------------------------------------------------------
-- МЕЛКИЕ УТИЛИТЫ
------------------------------------------------------------------
local function new(class, props, children)
	local inst = Instance.new(class)
	if props then
		for k, v in pairs(props) do
			inst[k] = v
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	return inst
end

local function corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

local function stroke(color, thickness, transparency)
	return new("UIStroke", {
		Color = color or Color3.fromRGB(255, 255, 255),
		Thickness = thickness or 1,
		Transparency = transparency or 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Мягкое неоновое свечение вокруг инстанса (имитация "glow" через UIStroke+градиент,
-- т.к. настоящих blur/shadow-фильтров в Roblox UI нет). Уважает Library.Theming:GetGlow().
local function glowStroke(parent, color, enabledFn)
	local g = new("UIStroke", {
		Color = color, Thickness = 2, Transparency = 0.55,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
	})
	new("UIGradient", {
		Color = ColorSequence.new(color, color),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.5, 0.75),
			NumberSequenceKeypoint.new(1, 0.2),
		}),
		Rotation = 90,
		Parent = g,
	})
	if enabledFn then
		g.Enabled = enabledFn()
	end
	return g
end

local function pad(l, t, r, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l or 8),
		PaddingTop = UDim.new(0, t or 8),
		PaddingRight = UDim.new(0, r or 8),
		PaddingBottom = UDim.new(0, b or 8),
	})
end

local function listLayout(direction, padding, alignment)
	return new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left,
	})
end

local function tween(inst, time, style, dir, props)
	local info = TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function round(v, decimals)
	local mult = 10 ^ (decimals or 0)
	return math.floor(v * mult + 0.5) / mult
end

local function fmtNumber(v, decimals)
	if decimals and decimals > 0 then
		return string.format("%." .. decimals .. "f", v)
	end
	return tostring(math.floor(v + 0.5))
end

local function safeCallback(fn, ...)
	if not fn then return end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[KrakenUI] callback error: " .. tostring(err))
	end
end

local function genId()
	return HttpService:GenerateGUID(false)
end

------------------------------------------------------------------
-- ШРИФТЫ (встроенные пресеты + кастомные)
------------------------------------------------------------------
-- Roblox рендерит шрифты через Enum.Font (устаревающий, но всегда рабочий способ)
-- либо через Font.new(family, weight, style) — второй способ поддерживает
-- пользовательские FontFace, загруженные как Roblox font-family asset (rbxassetid).
local Fonts = {}
Fonts.__index = Fonts

local BUILTIN_FONTS = {
	["Gotham"]        = Enum.Font.Gotham,
	["Gotham Bold"]   = Enum.Font.GothamBold,
	["Gotham Black"]  = Enum.Font.GothamBlack,
	["Gotham Medium"] = Enum.Font.GothamMedium,
	["Montserrat"]    = Enum.Font.Montserrat,
	["Roboto"]        = Enum.Font.SourceSans, -- ближайший доступный без внешних asset'ов
	["Source Sans"]   = Enum.Font.SourceSans,
	["Source Sans Bold"] = Enum.Font.SourceSansBold,
	["Verdana"]       = Enum.Font.Arial, -- в Roblox нет нативной Verdana, ближайший аналог
	["Tahoma XP"]     = Enum.Font.Arial, -- аналог, нативной Tahoma в движке нет
	["Monaco"]        = Enum.Font.Code, -- моноширинный аналог
	["Code"]          = Enum.Font.Code,
	["Bangers"]       = Enum.Font.Bangers,
	["Fondamento"]    = Enum.Font.Fondamento,
	["Highway Gothic"]= Enum.Font.Highway,
}

function Fonts.new()
	local self = setmetatable({}, Fonts)
	self._custom = {} -- name -> Font (FontFace) объект
	self._current = "Gotham"
	self._size = 13
	return self
end

-- Регистрация кастомного шрифта. assetId — rbxassetid ссылка на family json
-- (см. документацию Roblox "Custom Fonts" / Studio -> Font Manager).
-- weight/style опциональны.
function Fonts:Register(name, assetId, weight, style)
	assert(type(name) == "string", "Fonts:Register — имя шрифта должно быть строкой")
	local ok, fontObj = pcall(function()
		return Font.new(assetId, weight or Enum.FontWeight.Regular, style or Enum.FontStyle.Normal)
	end)
	if not ok then
		warn("[KrakenUI.Fonts] не удалось зарегистрировать шрифт '" .. name .. "': " .. tostring(fontObj))
		return false
	end
	self._custom[name] = fontObj
	return true
end

function Fonts:List()
	local list = {}
	for name in pairs(BUILTIN_FONTS) do table.insert(list, name) end
	for name in pairs(self._custom) do table.insert(list, name) end
	table.sort(list)
	return list
end

-- Возвращает значение, которое можно присвоить textLabel.FontFace (Font) или .Font (Enum.Font)
function Fonts:Resolve(name)
	if self._custom[name] then
		return self._custom[name], true -- true = это Font-объект (используем FontFace)
	end
	if BUILTIN_FONTS[name] then
		return BUILTIN_FONTS[name], false
	end
	return BUILTIN_FONTS["Gotham"], false
end

function Fonts:Apply(textInst, name, size)
	local resolved, isFontFace = self:Resolve(name or self._current)
	if isFontFace then
		textInst.FontFace = resolved
	else
		textInst.Font = resolved
	end
	if size then
		textInst.TextSize = size
	end
end

function Fonts:SetDefault(name, size)
	if name then self._current = name end
	if size then self._size = size end
end

function Fonts:GetDefault()
	return self._current, self._size
end

Library.Fonts = Fonts.new()

------------------------------------------------------------------
-- ЗВУК (UI sound effects — click/hover/toggle; выключено по умолчанию)
------------------------------------------------------------------
local Sounds = {}
Sounds.__index = Sounds

local DEFAULT_SOUNDS = {
	click    = "rbxassetid://6895079853",
	hover    = "rbxassetid://6895079091",
	toggleOn = "rbxassetid://6895079853",
	toggleOff = "rbxassetid://6895079091",
	notify   = "rbxassetid://6895079648",
}

function Sounds.new()
	local self = setmetatable({}, Sounds)
	self._sounds = table.clone(DEFAULT_SOUNDS)
	self._enabled = false
	self._volume = 0.4
	return self
end

function Sounds:SetEnabled(v) self._enabled = v and true or false end
function Sounds:GetEnabled() return self._enabled end
function Sounds:SetVolume(v) self._volume = clamp(v, 0, 1) end
function Sounds:GetVolume() return self._volume end

-- Register(name, soundId) — подставить свой звук под ключ (в т.ч. переопределить встроенный)
function Sounds:Register(name, soundId)
	self._sounds[name] = soundId
end

function Sounds:List()
	local list = {}
	for name in pairs(self._sounds) do table.insert(list, name) end
	table.sort(list)
	return list
end

-- Play(name) — no-op, если звук выключен через :SetEnabled(false) (по умолчанию)
function Sounds:Play(name)
	if not self._enabled then return end
	local id = self._sounds[name]
	if not id then return end
	local ok, s = pcall(Instance.new, "Sound")
	if not ok then return end
	s.SoundId = id
	s.Volume = self._volume
	s.Parent = SoundService
	local played = pcall(function() s:Play() end)
	if not played then s:Destroy(); return end
	s.Ended:Connect(function() s:Destroy() end)
	task.delay(4, function() if s.Parent then s:Destroy() end end)
end

Library.Sounds = Sounds.new()

------------------------------------------------------------------
-- АНИМАЦИИ (переиспользуемые твин-пресеты для любых GuiObject)
------------------------------------------------------------------
local Animations = {}
Animations.__index = Animations

function Animations.new()
	return setmetatable({ _custom = {} }, Animations)
end

-- Register(name, fn) — fn(inst, opts) — добавить свой пресет
function Animations:Register(name, fn)
	self._custom[name] = fn
end

function Animations:List()
	local list = { "FadeIn", "FadeOut", "Pulse", "Shake", "SlideInLeft", "SlideInRight", "SlideInTop" }
	for name in pairs(self._custom) do table.insert(list, name) end
	table.sort(list)
	return list
end

-- Play(inst, presetName, opts) — opts: { Duration, OnComplete }
function Animations:Play(inst, presetName, opts)
	opts = opts or {}
	local speed = Library.Theming:GetAnimSpeed()
	local duration = (opts.Duration or 0.25) * speed

	if self._custom[presetName] then
		return self._custom[presetName](inst, opts)
	end

	if presetName == "FadeIn" then
		inst.BackgroundTransparency = 1
		local t = tween(inst, duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundTransparency = 0 })
		if opts.OnComplete then t.Completed:Connect(function() safeCallback(opts.OnComplete) end) end
		return t
	elseif presetName == "FadeOut" then
		local t = tween(inst, duration, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { BackgroundTransparency = 1 })
		if opts.OnComplete then t.Completed:Connect(function() safeCallback(opts.OnComplete) end) end
		return t
	elseif presetName == "Pulse" then
		local origSize = inst.Size
		tween(inst, duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = origSize + UDim2.new(0, 4, 0, 4) })
		task.delay(duration * 0.5, function()
			tween(inst, duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Size = origSize })
			if opts.OnComplete then task.delay(duration * 0.5, function() safeCallback(opts.OnComplete) end) end
		end)
	elseif presetName == "Shake" then
		local origPos = inst.Position
		task.spawn(function()
			for _, dx in ipairs({ 6, -6, 4, -4, 2, -2, 0 }) do
				tween(inst, 0.03, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, { Position = origPos + UDim2.new(0, dx, 0, 0) })
				task.wait(0.03)
			end
			inst.Position = origPos
			safeCallback(opts.OnComplete)
		end)
	elseif presetName == "SlideInLeft" or presetName == "SlideInRight" or presetName == "SlideInTop" then
		local origPos = inst.Position
		local dx = presetName == "SlideInLeft" and -30 or (presetName == "SlideInRight" and 30 or 0)
		local dy = presetName == "SlideInTop" and -30 or 0
		inst.Position = origPos + UDim2.new(0, dx, 0, dy)
		local t = tween(inst, duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Position = origPos })
		if opts.OnComplete then t.Completed:Connect(function() safeCallback(opts.OnComplete) end) end
		return t
	else
		warn("[KrakenUI.Animations] неизвестный пресет: " .. tostring(presetName))
	end
end

Library.Animations = Animations.new()

------------------------------------------------------------------
-- ИКОНКИ (Get/Register/List — единый реестр иконок библиотеки)
------------------------------------------------------------------
local Icons = {}
Icons.__index = Icons

-- Плейсхолдер-набор из общедоступных ассетов Roblox (можно полностью заменить через :Register).
local ICON_SET = {
	settings   = "rbxassetid://10734950309",
	cog        = "rbxassetid://10734950309",
	search     = "rbxassetid://10734896200",
	close      = "rbxassetid://10747384394",
	minimize   = "rbxassetid://10734953397",
	restore    = "rbxassetid://10734953397",
	chevronUp    = "rbxassetid://10709790949",
	chevronDown  = "rbxassetid://10709791437",
	chevronLeft  = "rbxassetid://10709790581",
	chevronRight = "rbxassetid://10709791336",
	key        = "rbxassetid://10734943297",
	lock       = "rbxassetid://10747370824",
	unlock     = "rbxassetid://10747371055",
	info       = "rbxassetid://10734953095",
	warning    = "rbxassetid://10734924990",
	error      = "rbxassetid://10747384372",
	success    = "rbxassetid://10709791198",
	star       = "rbxassetid://10734950309",
	heart      = "rbxassetid://10734924021",
	bolt       = "rbxassetid://10734950176",
	save       = "rbxassetid://10734951549",
	load       = "rbxassetid://10734951327",
	trash      = "rbxassetid://10747384394",
	copy       = "rbxassetid://10734893163",
	paste      = "rbxassetid://10734895702",
	refresh    = "rbxassetid://10709806799",
	filter     = "rbxassetid://10734896200",
	palette    = "rbxassetid://10734943297",
	sliders    = "rbxassetid://10723416860",
	tabs       = "rbxassetid://10734950309",
	keyboard   = "rbxassetid://10734953897",
	mouse      = "rbxassetid://10734951770",
	edit       = "rbxassetid://10734943291",
	plus       = "rbxassetid://10734896200",
	shield     = "rbxassetid://10734950309",
	friend     = "rbxassetid://10723416950",
	bag        = "rbxassetid://10734924021",
	eye        = "rbxassetid://10734924990",
}

function Icons.new()
	local self = setmetatable({}, Icons)
	self._icons = table.clone(ICON_SET)
	return self
end

function Icons:Get(name)
	return self._icons[name]
end

function Icons:Register(name, imageId)
	assert(type(name) == "string" and type(imageId) == "string", "Icons:Register(name, imageId)")
	self._icons[name] = imageId
end

function Icons:List()
	local list = {}
	for name in pairs(self._icons) do table.insert(list, name) end
	table.sort(list)
	return list
end

Library.Icons = Icons.new()

------------------------------------------------------------------
-- ТЕМА (Theming) + пресеты
------------------------------------------------------------------
local Theming = {}
Theming.__index = Theming

local THEME_PRESETS = {
	["Void Purple"] = { Accent = Color3.fromRGB(138, 92, 246), Bg = Color3.fromRGB(18, 16, 26), Panel = Color3.fromRGB(26, 22, 38), Text = Color3.fromRGB(235, 233, 245), SubText = Color3.fromRGB(160, 155, 180) },
	["Cyber Blue"]  = { Accent = Color3.fromRGB(56, 152, 255),  Bg = Color3.fromRGB(12, 16, 24), Panel = Color3.fromRGB(18, 24, 36), Text = Color3.fromRGB(230, 238, 248), SubText = Color3.fromRGB(140, 155, 178) },
	["Sunset"]      = { Accent = Color3.fromRGB(255, 122, 89),  Bg = Color3.fromRGB(26, 18, 20), Panel = Color3.fromRGB(36, 24, 26), Text = Color3.fromRGB(250, 235, 230), SubText = Color3.fromRGB(190, 155, 145) },
	["Mono Dark"]   = { Accent = Color3.fromRGB(210, 210, 210), Bg = Color3.fromRGB(14, 14, 14), Panel = Color3.fromRGB(22, 22, 22), Text = Color3.fromRGB(235, 235, 235), SubText = Color3.fromRGB(150, 150, 150) },
	["Mono Light"]  = { Accent = Color3.fromRGB(40, 40, 40),    Bg = Color3.fromRGB(240, 240, 240), Panel = Color3.fromRGB(252, 252, 252), Text = Color3.fromRGB(25, 25, 25), SubText = Color3.fromRGB(100, 100, 100) },
	["Nord"]        = { Accent = Color3.fromRGB(136, 192, 208), Bg = Color3.fromRGB(30, 34, 42), Panel = Color3.fromRGB(38, 43, 52), Text = Color3.fromRGB(229, 233, 240), SubText = Color3.fromRGB(150, 165, 185) },
	["Dracula"]     = { Accent = Color3.fromRGB(189, 147, 249), Bg = Color3.fromRGB(24, 24, 32), Panel = Color3.fromRGB(34, 34, 46), Text = Color3.fromRGB(248, 248, 242), SubText = Color3.fromRGB(150, 150, 170) },
}

function Theming.new()
	local self = setmetatable({}, Theming)
	self._preset = "Void Purple"
	self._colors = table.clone(THEME_PRESETS["Void Purple"])
	self._radius = 12
	self._borderThickness = 1
	self._glow = true
	self._animSpeed = 1 -- множитель длительности твинов
	self._density = "Normal" -- Compact / Normal / Comfortable
	self._listeners = {}
	return self
end

local DENSITY_PADDING = {
	Compact = { row = 4, section = 6, pad = 6 },
	Normal = { row = 6, section = 8, pad = 8 },
	Comfortable = { row = 10, section = 12, pad = 12 },
}

function Theming:SetDensity(name)
	if not DENSITY_PADDING[name] then return end
	self._density = name
	self:_notify()
end

function Theming:GetDensity()
	return self._density, DENSITY_PADDING[self._density]
end

function Theming:List()
	local list = {}
	for name in pairs(THEME_PRESETS) do table.insert(list, name) end
	table.sort(list)
	return list
end

function Theming:Use(presetName)
	local preset = THEME_PRESETS[presetName]
	if not preset then
		warn("[KrakenUI.Theming] неизвестный пресет: " .. tostring(presetName))
		return
	end
	self._preset = presetName
	self._colors = table.clone(preset)
	self:_notify()
end

function Theming:SetAccent(color3)
	self._colors.Accent = color3
	self:_notify()
end

function Theming:Get()
	return self._colors
end

function Theming:SetRadius(px) self._radius = clamp(px, 0, 20); self:_notify() end
function Theming:GetRadius() return self._radius end

function Theming:SetBorderThickness(px) self._borderThickness = clamp(px, 0, 3); self:_notify() end
function Theming:GetBorderThickness() return self._borderThickness end

function Theming:SetGlow(enabled) self._glow = enabled and true or false; self:_notify() end
function Theming:GetGlow() return self._glow end

function Theming:SetAnimSpeed(mult) self._animSpeed = mult; self:_notify() end
function Theming:GetAnimSpeed() return self._animSpeed end

function Theming:OnChanged(fn)
	table.insert(self._listeners, fn)
	return function()
		for i, f in ipairs(self._listeners) do
			if f == fn then table.remove(self._listeners, i) break end
		end
	end
end

function Theming:_notify()
	for _, fn in ipairs(self._listeners) do
		safeCallback(fn, self._colors)
	end
end

-- Export() -> JSON-строка со всей текущей темой (пресет, акцент, радиус, бордер, glow, density, скорость анимаций)
function Theming:Export()
	local c = self._colors
	local ok, json = pcall(HttpService.JSONEncode, HttpService, {
		Preset = self._preset,
		Accent = { c.Accent.R, c.Accent.G, c.Accent.B },
		Radius = self._radius,
		BorderThickness = self._borderThickness,
		Glow = self._glow,
		AnimSpeed = self._animSpeed,
		Density = self._density,
	})
	if not ok then
		warn("[KrakenUI.Theming] ошибка экспорта: " .. tostring(json))
		return nil
	end
	return json
end

-- Import(jsonString) -> boolean — применить тему, ранее полученную через :Export()
function Theming:Import(jsonString)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, jsonString)
	if not ok then
		warn("[KrakenUI.Theming] не удалось разобрать JSON темы: " .. tostring(data))
		return false
	end
	if data.Preset and THEME_PRESETS[data.Preset] then
		self._colors = table.clone(THEME_PRESETS[data.Preset])
		self._preset = data.Preset
	end
	if data.Accent then
		self._colors.Accent = Color3.new(data.Accent[1], data.Accent[2], data.Accent[3])
	end
	if data.Radius then self._radius = data.Radius end
	if data.BorderThickness then self._borderThickness = data.BorderThickness end
	if data.Glow ~= nil then self._glow = data.Glow end
	if data.AnimSpeed then self._animSpeed = data.AnimSpeed end
	if data.Density and DENSITY_PADDING[data.Density] then self._density = data.Density end
	self:_notify()
	return true
end

Library.Theming = Theming.new()

------------------------------------------------------------------
-- ГЛОБАЛЬНОЕ СОСТОЯНИЕ БИБЛИОТЕКИ
------------------------------------------------------------------
Library.Flags = {}          -- flag -> value
Library._elements = {}      -- flag -> element table (для программного доступа/поиска)
Library._connections = {}   -- все RBXScriptConnection, отключаются в Unload
Library._activeDrag = nil
Library._screenGui = nil
Library._windows = {}
Library._notifications = {}
Library._notifHolder = nil
Library._notifCounter = 0

local function track(conn)
	table.insert(Library._connections, conn)
	return conn
end

------------------------------------------------------------------
-- EVENTS (глобальная шина событий pub/sub, не завязана на конкретные элементы)
------------------------------------------------------------------
local EventsMT = {}
EventsMT.__index = EventsMT

function EventsMT.new()
	return setmetatable({ _handlers = {} }, EventsMT)
end

-- On(event, fn) -> unsubscribe()
function EventsMT:On(event, fn)
	self._handlers[event] = self._handlers[event] or {}
	table.insert(self._handlers[event], fn)
	return function() self:Off(event, fn) end
end

function EventsMT:Off(event, fn)
	local list = self._handlers[event]
	if not list then return end
	for i, f in ipairs(list) do
		if f == fn then table.remove(list, i) break end
	end
end

function EventsMT:Fire(event, ...)
	for _, fn in ipairs(self._handlers[event] or {}) do
		safeCallback(fn, ...)
	end
end

Library.Events = EventsMT.new()

------------------------------------------------------------------
-- HOTKEYS (глобальный менеджер хоткеев — не привязан к конкретным элементам GUI,
-- работает даже когда меню закрыто/свёрнуто)
------------------------------------------------------------------
local HotkeysMT = {}
HotkeysMT.__index = HotkeysMT

function HotkeysMT.new()
	return setmetatable({ _binds = {} }, HotkeysMT)
end

-- Bind(name, keyCode, mode, callback) — mode: "Toggle" | "Hold" | "Always"
function HotkeysMT:Bind(name, keyCode, mode, callback)
	self._binds[name] = { Key = keyCode, Mode = mode or "Toggle", Callback = callback, Active = false }
end

function HotkeysMT:Unbind(name)
	self._binds[name] = nil
end

function HotkeysMT:List()
	local list = {}
	for name, b in pairs(self._binds) do
		table.insert(list, { Name = name, Key = b.Key, Mode = b.Mode, Active = b.Active })
	end
	table.sort(list, function(a, b) return a.Name < b.Name end)
	return list
end

Library.Hotkeys = HotkeysMT.new()

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	for _, b in pairs(Library.Hotkeys._binds) do
		local matches = (input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == b.Key) or (input.UserInputType == b.Key)
		if matches then
			if b.Mode == "Toggle" then
				b.Active = not b.Active
				safeCallback(b.Callback, b.Active)
			elseif b.Mode == "Hold" or b.Mode == "Always" then
				b.Active = true
				safeCallback(b.Callback, true)
			end
		end
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	for _, b in pairs(Library.Hotkeys._binds) do
		local matches = (input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == b.Key) or (input.UserInputType == b.Key)
		if matches and b.Mode == "Hold" then
			b.Active = false
			safeCallback(b.Callback, false)
		end
	end
end))

function Library:Unload()
	for _, conn in ipairs(self._connections) do
		pcall(function() conn:Disconnect() end)
	end
	self._connections = {}
	if self._screenGui then
		pcall(function() self._screenGui:Destroy() end)
		self._screenGui = nil
	end
	self._windows = {}
	self._elements = {}
	self.Flags = {}
	self.Hotkeys._binds = {}
	self.Events._handlers = {}
	self.Theming._listeners = {}
end

local function ensureRoot()
	if Library._screenGui and Library._screenGui.Parent then
		return Library._screenGui
	end
	local gui = new("ScreenGui", {
		Name = "KrakenUI_" .. genId():sub(1, 8),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
	})
	gui.Parent = getGui()
	protect(gui)
	Library._screenGui = gui
	return gui
end

------------------------------------------------------------------
-- DRAG / RESIZE ПОМОЩНИКИ
------------------------------------------------------------------
local function makeDraggable(handle, target, boundToScreen)
	local dragging, dragStart, startPos = false, nil, nil

	track(handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					conn:Disconnect()
				end
			end)
		end
	end))

	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			local newX = startPos.X.Offset + delta.X
			local newY = startPos.Y.Offset + delta.Y
			if boundToScreen then
				local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
				newX = clamp(newX, 0, viewport.X - target.AbsoluteSize.X)
				newY = clamp(newY, 0, viewport.Y - target.AbsoluteSize.Y)
			end
			target.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
		end
	end))
end

local RESIZE_DIRS = {
	{ name = "R",  cursorHint = "resize-x",  anchor = Vector2.new(1, 0.5), size = UDim2.new(0, 6, 1, -12), pos = UDim2.new(1, -3, 0, 6) },
	{ name = "L",  cursorHint = "resize-x",  anchor = Vector2.new(0, 0.5), size = UDim2.new(0, 6, 1, -12), pos = UDim2.new(0, -3, 0, 6) },
	{ name = "T",  cursorHint = "resize-y",  anchor = Vector2.new(0.5, 0), size = UDim2.new(1, -12, 0, 6), pos = UDim2.new(0, 6, 0, -3) },
	{ name = "B",  cursorHint = "resize-y",  anchor = Vector2.new(0.5, 1), size = UDim2.new(1, -12, 0, 6), pos = UDim2.new(0, 6, 1, -3) },
	{ name = "TL", cursorHint = "resize-tl", anchor = Vector2.new(0, 0),   size = UDim2.new(0, 10, 0, 10), pos = UDim2.new(0, -3, 0, -3) },
	{ name = "TR", cursorHint = "resize-tr", anchor = Vector2.new(1, 0),   size = UDim2.new(0, 10, 0, 10), pos = UDim2.new(1, -7, 0, -3) },
	{ name = "BL", cursorHint = "resize-bl", anchor = Vector2.new(0, 1),   size = UDim2.new(0, 10, 0, 10), pos = UDim2.new(0, -3, 1, -7) },
	{ name = "BR", cursorHint = "resize-br", anchor = Vector2.new(1, 1),   size = UDim2.new(0, 10, 0, 10), pos = UDim2.new(1, -7, 1, -7) },
}

local function makeResizable(frame, minSize, maxSize)
	minSize = minSize or Vector2.new(360, 240)
	maxSize = maxSize or Vector2.new(1200, 900)

	for _, dir in ipairs(RESIZE_DIRS) do
		local handle = new("TextButton", {
			Name = "Resize_" .. dir.name,
			BackgroundTransparency = 1,
			Text = "",
			Size = dir.size,
			Position = dir.pos,
			ZIndex = 50,
			Parent = frame,
		})

		local dragging, dragStart, startSize, startPos = false, nil, nil, nil

		track(handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = input.Position
				startSize = frame.Size
				startPos = frame.Position
				local conn
				conn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						conn:Disconnect()
					end
				end)
			end
		end))

		track(UserInputService.InputChanged:Connect(function(input)
			if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			local delta = input.Position - dragStart
			local dx, dy = 0, 0
			local w, h = startSize.X.Offset, startSize.Y.Offset
			local px, py = startPos.X.Offset, startPos.Y.Offset

			if dir.name:find("R") then w = clamp(startSize.X.Offset + delta.X, minSize.X, maxSize.X) end
			if dir.name:find("L") then
				w = clamp(startSize.X.Offset - delta.X, minSize.X, maxSize.X)
				dx = startSize.X.Offset - w
			end
			if dir.name:find("B") then h = clamp(startSize.Y.Offset + delta.Y, minSize.Y, maxSize.Y) end
			if dir.name:find("T") then
				h = clamp(startSize.Y.Offset - delta.Y, minSize.Y, maxSize.Y)
				dy = startSize.Y.Offset - h
			end

			frame.Size = UDim2.new(startSize.X.Scale, w, startSize.Y.Scale, h)
			if dx ~= 0 then frame.Position = UDim2.new(startPos.X.Scale, px + dx, frame.Position.Y.Scale, frame.Position.Y.Offset) end
			if dy ~= 0 then frame.Position = UDim2.new(frame.Position.X.Scale, frame.Position.X.Offset, startPos.Y.Scale, py + dy) end
		end))
	end
end

------------------------------------------------------------------
-- СВОРАЧИВАЕМЫЙ КОНТЕЙНЕР (используется Tab / Section / настройками)
------------------------------------------------------------------
local function makeCollapsible(headerBtn, arrowIcon, body, startCollapsed, onToggle)
	local collapsed = startCollapsed and true or false

	local function apply(animated)
		local targetSize = collapsed and UDim2.new(1, 0, 0, 0) or nil
		if collapsed then
			body.Visible = true
			if animated then
				tween(body, 0.18 * Library.Theming:GetAnimSpeed(), Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Size = UDim2.new(1, 0, 0, 0) })
				task.delay(0.18, function() if collapsed then body.Visible = false end end)
			else
				body.Size = UDim2.new(1, 0, 0, 0)
				body.Visible = false
			end
		else
			body.Visible = true
			local fullY = body:FindFirstChildOfClass("UIListLayout")
			local targetHeight = fullY and (fullY.AbsoluteContentSize.Y) or body.AbsoluteSize.Y
			if animated then
				tween(body, 0.18 * Library.Theming:GetAnimSpeed(), Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Size = UDim2.new(1, 0, 0, targetHeight) })
			else
				body.Size = UDim2.new(1, 0, 0, targetHeight)
			end
		end
		if arrowIcon then
			tween(arrowIcon, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Rotation = collapsed and -90 or 0 })
		end
	end

	track(headerBtn.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		apply(true)
		safeCallback(onToggle, collapsed)
	end))

	apply(false)

	return {
		IsCollapsed = function() return collapsed end,
		SetCollapsed = function(_, v, animated)
			collapsed = v and true or false
			apply(animated ~= false)
		end,
	}
end

------------------------------------------------------------------
-- NOTIFICATION
------------------------------------------------------------------
local function ensureNotifHolder()
	if Library._notifHolder and Library._notifHolder.Parent then
		return Library._notifHolder
	end
	local root = ensureRoot()
	local holder = new("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 320, 1, -32),
		Parent = root,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = holder
	Library._notifHolder = holder
	return holder
end

-- opts: { Title, Text, Duration, Icon = "info"/"success"/"warning"/"error" }
function Library:Notification(opts)
	opts = opts or {}
	local theme = self.Theming:Get()
	local holder = ensureNotifHolder()
	Library.Sounds:Play("notify")

	local iconName = opts.Icon or "info"
	local iconColors = {
		info = theme.Accent, success = Color3.fromRGB(88, 210, 130),
		warning = Color3.fromRGB(240, 180, 70), error = Color3.fromRGB(235, 90, 90),
	}

	local card = new("Frame", {
		BackgroundColor3 = theme.Panel,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		LayoutOrder = -(function() self._notifCounter = self._notifCounter + 1; return self._notifCounter end)(),
		Parent = holder,
	}, { corner(10), stroke(theme.Accent, 1, 0.75), pad(10, 8, 10, 8) })

	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	row.Parent = card
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = row

	local dot = new("Frame", {
		Size = UDim2.new(0, 6, 0, 6),
		Position = UDim2.new(0, 0, 0, 6),
		BackgroundColor3 = iconColors[iconName] or theme.Accent,
		Parent = row,
	}, { corner(3) })

	local textCol = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -14, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row })
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = textCol

	if opts.Title then
		local titleLbl = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
			Text = opts.Title, TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13,
			Parent = textCol,
		})
		Library.Fonts:Apply(titleLbl, "Gotham Bold", 13)
	end
	if opts.Text then
		local bodyLbl = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			Text = opts.Text, TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 12, TextWrapped = true, Parent = textCol,
		})
		Library.Fonts:Apply(bodyLbl, "Gotham", 12)
	end

	card.Position = UDim2.new(1, 40, card.Position.Y.Scale, 0)
	card.BackgroundTransparency = 1
	tween(card, 0.25 * self.Theming:GetAnimSpeed(), Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0 })

	task.delay(opts.Duration or 4, function()
		if not card.Parent then return end
		local t = tween(card, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { Position = UDim2.new(1, 40, 0, 0), BackgroundTransparency = 1 })
		t.Completed:Wait()
		card:Destroy()
	end)

	return card
end

------------------------------------------------------------------
-- LOADER (детальный многоэтапный прогресс)
------------------------------------------------------------------
local LoaderMT = {}
LoaderMT.__index = LoaderMT

-- opts: { Title, Subtitle, Steps = {{Name=,Weight=}, ...}, SkipAfter = 3 }
function Library:Loader(opts)
	opts = opts or {}
	local theme = self.Theming:Get()
	local root = ensureRoot()

	local self2 = setmetatable({}, LoaderMT)
	self2._steps = opts.Steps or {}
	self2._skipRequested = false

	local overlay = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.4,
		Size = UDim2.new(1, 0, 1, 0), ZIndex = 500, Parent = root,
	})

	local card = new("Frame", {
		BackgroundColor3 = theme.Panel, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 420, 0, 340),
		ZIndex = 501, Parent = overlay,
	}, { corner(self.Theming:GetRadius()), stroke(theme.Accent, 1, 0.5), pad(18, 16, 18, 16) })

	local header = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = card })
	local spinner = new("Frame", {
		Size = UDim2.new(0, 22, 0, 22), BackgroundTransparency = 1, Parent = header,
	}, { new("UIStroke", { Color = theme.Accent, Thickness = 3, Transparency = 0.2 }) })
	local titleLbl = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(1, -32, 0, 20),
		Text = opts.Title or "Инициализация...", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16,
		Parent = header,
	})
	Library.Fonts:Apply(titleLbl, "Gotham Bold", 16)
	local subLbl = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 32, 0, 20), Size = UDim2.new(1, -32, 0, 16),
		Text = opts.Subtitle or "Подготовка...", TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12,
		Parent = header,
	})
	Library.Fonts:Apply(subLbl, "Gotham", 12)

	track(RunService.RenderStepped:Connect(function(dt)
		spinner.Rotation = (spinner.Rotation + dt * 220) % 360
	end))

	-- Главная полоса
	local barBg = new("Frame", { BackgroundColor3 = theme.Bg, Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 0, 48), Parent = card }, { corner(4) })
	local barFill = new("Frame", { BackgroundColor3 = theme.Accent, Size = UDim2.new(0, 0, 1, 0), Parent = barBg }, { corner(4) })

	local statusLbl = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 62), Size = UDim2.new(1, 0, 0, 16),
		Text = "Этап 0 из 0 · 0% · 0.0s", TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 11,
		Parent = card,
	})
	Library.Fonts:Apply(statusLbl, "Code", 11)

	-- Список этапов
	local stepsHolder = new("ScrollingFrame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 86), Size = UDim2.new(1, 0, 0, 140),
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = theme.Accent, Parent = card,
	})
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = stepsHolder

	local stepRows = {}
	for i, step in ipairs(self2._steps) do
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = i, Parent = stepsHolder })
		local mark = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(0, 16, 1, 0), Text = "○", TextColor3 = theme.SubText, TextSize = 12, Parent = row,
		})
		local lbl = new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 20, 0, 0), Size = UDim2.new(1, -90, 1, 0),
			Text = step.Name or ("Этап " .. i), TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, Parent = row,
		})
		Library.Fonts:Apply(lbl, "Gotham", 12)
		local stateLbl = new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(1, -70, 0, 0), Size = UDim2.new(0, 70, 1, 0),
			Text = "ожидание", TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Right, TextSize = 11, Parent = row,
		})
		stepRows[i] = { mark = mark, label = lbl, state = stateLbl }
	end

	-- Мини-консоль лога
	local logBox = new("TextLabel", {
		BackgroundColor3 = theme.Bg, Position = UDim2.new(0, 0, 1, -44), Size = UDim2.new(1, 0, 0, 44),
		Text = "", TextColor3 = theme.SubText, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = card,
	}, { corner(6), pad(6, 4, 6, 4) })
	Library.Fonts:Apply(logBox, "Code", 10)
	local logLines = {}
	local function pushLog(msg)
		table.insert(logLines, msg)
		while #logLines > 3 do table.remove(logLines, 1) end
		logBox.Text = table.concat(logLines, "\n")
	end

	local skipBtn = new("TextButton", {
		BackgroundColor3 = theme.Bg, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 74, 0, 22), Text = "Пропустить", TextColor3 = theme.SubText, TextSize = 11,
		Visible = false, Parent = header,
	}, { corner(6) })
	Library.Fonts:Apply(skipBtn, "Gotham", 11)
	track(skipBtn.MouseButton1Click:Connect(function() self2._skipRequested = true end))
	task.delay(3, function() if overlay.Parent then skipBtn.Visible = true end end)

	-- Публичный метод запуска этапов. taskFn(stepIndex) может вернуть true/false (успех/пропуск)
	function self2:Run(onDone)
		task.spawn(function()
			local total = math.max(#self2._steps, 1)
			local weightSum = 0
			for _, s in ipairs(self2._steps) do weightSum = weightSum + (s.Weight or (100 / total)) end
			local acc = 0
			local startClock = os.clock()

			for i, step in ipairs(self2._steps) do
				local elapsedStart = os.clock()
				stepRows[i].mark.Text = "◔"
				stepRows[i].state.Text = "загрузка"
				stepRows[i].label.TextColor3 = theme.Text

				if step.Fn then
					local ok, err = pcall(step.Fn)
					if not ok then
						warn("[KrakenUI.Loader] ошибка на этапе '" .. tostring(step.Name) .. "': " .. tostring(err))
					end
				else
					task.wait(0.05)
				end

				-- минимум 150мс на видимый этап + равномерный чанкинг
				local minTime = 0.15
				local spent = os.clock() - elapsedStart
				if spent < minTime then task.wait(minTime - spent) end

				acc = acc + (step.Weight or (100 / total))
				local pct = clamp(acc / weightSum, 0, 1)
				tween(barFill, 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Size = UDim2.new(pct, 0, 1, 0) })

				stepRows[i].mark.Text = "●"
				stepRows[i].mark.TextColor3 = theme.Accent
				stepRows[i].state.Text = "ok"
				stepRows[i].label.TextColor3 = theme.SubText
				pushLog(("[%02ds] %s — готово"):format(math.floor(os.clock() - startClock), step.Name or ("Этап " .. i)))

				statusLbl.Text = ("Этап %d из %d · %d%% · %.1fs"):format(i, total, math.floor(pct * 100), os.clock() - startClock)

				if self2._skipRequested then
					-- докручиваем остаток мгновенно в фоне, но выходим из UI-показа
					break
				end
			end

			if self2._skipRequested then
				for j = 1, #self2._steps do
					stepRows[j].mark.Text = "●"
					stepRows[j].state.Text = "ok"
				end
				barFill.Size = UDim2.new(1, 0, 1, 0)
			end

			task.wait(0.15)
			local fadeOut = tween(overlay, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { BackgroundTransparency = 1 })
			tween(card, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { BackgroundTransparency = 1 })
			fadeOut.Completed:Wait()
			overlay:Destroy()
			safeCallback(onDone)
		end)
	end

	return self2
end

------------------------------------------------------------------
-- MODAL (универсальный диалог подтверждения/алерта)
------------------------------------------------------------------
-- opts: { Title, Text, AcceptText, CancelText, ShowCancel, Size, OnAccept, OnCancel }
function Library:Modal(opts)
	opts = opts or {}
	local theme = self.Theming:Get()
	local root = ensureRoot()

	local overlay = new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), ZIndex = 600, Parent = root,
	})

	local card = new("Frame", {
		BackgroundColor3 = theme.Panel, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0), Size = opts.Size or UDim2.new(0, 360, 0, 180),
		BackgroundTransparency = 1, ZIndex = 601, Parent = overlay,
	}, { corner(self.Theming:GetRadius()), stroke(theme.Accent, 1, 0.5), pad(16, 14, 16, 14) })

	local titleLbl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
		Text = opts.Title or "Подтверждение", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15, Parent = card,
	})
	Library.Fonts:Apply(titleLbl, "Gotham Bold", 15)

	local bodyLbl = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Text = opts.Text or "", TextColor3 = theme.SubText, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Parent = card,
	})
	Library.Fonts:Apply(bodyLbl, "Gotham", 13)

	local btnRow = new("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 32), Parent = card,
	})
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right }).Parent = btnRow

	local function close()
		local t = tween(overlay, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { BackgroundTransparency = 1 })
		tween(card, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { BackgroundTransparency = 1 })
		t.Completed:Wait()
		overlay:Destroy()
	end

	if opts.ShowCancel ~= false then
		local cancelBtn = new("TextButton", {
			BackgroundColor3 = theme.Bg, Size = UDim2.new(0, 90, 1, 0), Text = opts.CancelText or "Отмена",
			TextColor3 = theme.SubText, TextSize = 13, AutoButtonColor = false, Parent = btnRow,
		}, { corner(6) })
		Library.Fonts:Apply(cancelBtn, "Gotham", 13)
		track(cancelBtn.MouseButton1Click:Connect(function()
			safeCallback(opts.OnCancel)
			close()
		end))
	end

	local acceptBtn = new("TextButton", {
		BackgroundColor3 = theme.Accent, Size = UDim2.new(0, 90, 1, 0), Text = opts.AcceptText or "ОК",
		TextColor3 = Color3.new(1, 1, 1), TextSize = 13, AutoButtonColor = false, Parent = btnRow,
	}, { corner(6) })
	Library.Fonts:Apply(acceptBtn, "Gotham Bold", 13)
	track(acceptBtn.MouseButton1Click:Connect(function()
		safeCallback(opts.OnAccept)
		close()
	end))

	tween(overlay, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundTransparency = 0.45 })
	tween(card, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundTransparency = 0 })

	return { Close = close }
end

------------------------------------------------------------------
-- CONTEXT MENU (меню по ПКМ для любого GuiObject)
------------------------------------------------------------------
-- items: { { Name = "Копировать", Icon = "copy", Callback = function() end }, ... }
function Library:ContextMenu()
	local theme = self.Theming:Get()
	local root = ensureRoot()
	local menuFrame = nil

	local function close()
		if menuFrame then
			menuFrame:Destroy()
			menuFrame = nil
		end
	end

	local function open(items, x, y)
		close()
		menuFrame = new("Frame", {
			BackgroundColor3 = theme.Panel, Position = UDim2.new(0, x, 0, y),
			Size = UDim2.new(0, 180, 0, #items * 26 + 8), ZIndex = 900, Parent = root,
		}, { corner(8), stroke(theme.Accent, 1, 0.5), pad(4, 4, 4, 4) })
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = menuFrame

		for i, item in ipairs(items) do
			local btn = new("TextButton", {
				BackgroundColor3 = theme.Bg, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24),
				Text = "", AutoButtonColor = false, LayoutOrder = i, ZIndex = 901, Parent = menuFrame,
			}, { corner(5) })
			local offset = 0
			if item.Icon and Library.Icons:Get(item.Icon) then
				offset = 20
				new("ImageLabel", {
					BackgroundTransparency = 1, Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 6, 0.5, -7),
					Image = Library.Icons:Get(item.Icon), ImageColor3 = theme.SubText, ZIndex = 901, Parent = btn,
				})
			end
			local lbl = new("TextLabel", {
				BackgroundTransparency = 1, Size = UDim2.new(1, -10 - offset, 1, 0), Position = UDim2.new(0, 6 + offset, 0, 0),
				Text = item.Name or "", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, ZIndex = 901, Parent = btn,
			})
			Library.Fonts:Apply(lbl, "Gotham", 12)
			track(btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0.5 end))
			track(btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 1 end))
			track(btn.MouseButton1Click:Connect(function()
				close()
				safeCallback(item.Callback)
			end))
		end
	end

	track(UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and menuFrame then
			close()
		end
	end))

	local api = {}
	-- Attach(guiObject, items) — открывать это меню по ПКМ на guiObject
	function api:Attach(guiObject, items)
		track(guiObject.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				open(items, input.Position.X, input.Position.Y)
			end
		end))
	end
	function api:Close() close() end

	return api
end

------------------------------------------------------------------
-- KEY SYSTEM (generic — экран ввода лицензионного ключа для СВОИХ легальных скриптов)
------------------------------------------------------------------
local KeySystemMT = {}
KeySystemMT.__index = KeySystemMT

-- opts:
--  Title, Subtitle, Note
--  SaveFolder (папка для writefile/readfile, если executor поддерживает)
--  Validate = function(key) -> boolean, reason
--  GetHWID = function() -> string (опционально)
--  BuyUrl, DiscordUrl
--  RateLimit = { Attempts = 5, Window = 60 }
function Library:KeySystem(opts)
	opts = opts or {}
	local self2 = setmetatable({}, KeySystemMT)
	self2._opts = opts
	self2._attempts = {}

	local hasFS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
	self2._hasFS = hasFS
	self2._folder = opts.SaveFolder or "KrakenUI"

	if hasFS and type(makefolder) == "function" and not isfolder(self2._folder) then
		pcall(makefolder, self2._folder)
	end

	function self2:_keyPath()
		return self2._folder .. "/key.txt"
	end

	function self2:LoadSavedKey()
		if not self2._hasFS then return nil end
		local ok, data = pcall(readfile, self2:_keyPath())
		if ok then return data end
		return nil
	end

	function self2:SaveKey(key)
		if not self2._hasFS then return end
		pcall(writefile, self2:_keyPath(), key)
	end

	function self2:_checkRateLimit()
		local window = (opts.RateLimit and opts.RateLimit.Window) or 60
		local maxAttempts = (opts.RateLimit and opts.RateLimit.Attempts) or 5
		local now = os.clock()
		local list = {}
		for _, t in ipairs(self2._attempts) do
			if now - t < window then table.insert(list, t) end
		end
		self2._attempts = list
		if #list >= maxAttempts then
			local wait = window - (now - list[1])
			return false, wait
		end
		return true, 0
	end

	function self2:_recordAttempt()
		table.insert(self2._attempts, os.clock())
	end

	-- Показывает окно, вызывает onSuccess(key) при удачной разблокировке
	function self2:Prompt(onSuccess)
		local theme = Library.Theming:Get()
		local root = ensureRoot()

		local overlay = new("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
			Size = UDim2.new(1, 0, 1, 0), ZIndex = 400, Parent = root,
		})

		local card = new("Frame", {
			BackgroundColor3 = theme.Panel, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 380, 0, 300),
			ZIndex = 401, Parent = overlay,
		}, { corner(Library.Theming:GetRadius()), stroke(theme.Accent, 1, 0.5), pad(18, 16, 18, 16) })

		local titleLbl = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22),
			Text = opts.Title or "Введите ключ доступа", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, Parent = card,
		})
		Library.Fonts:Apply(titleLbl, "Gotham Bold", 16)

		local subLbl = new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 32),
			Text = opts.Subtitle or "Ключ можно получить у разработчика.", TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 12, TextWrapped = true, Parent = card,
		})
		Library.Fonts:Apply(subLbl, "Gotham", 12)

		local inputBg = new("Frame", { BackgroundColor3 = theme.Bg, Position = UDim2.new(0, 0, 0, 62), Size = UDim2.new(1, 0, 0, 36), Parent = card }, { corner(8), stroke(theme.Accent, 1, 0.7) })
		local input = new("TextBox", {
			BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0),
			PlaceholderText = "XXXX-XXXX-XXXX", Text = "", TextColor3 = theme.Text, TextSize = 14,
			ClearTextOnFocus = false, Parent = inputBg,
		})
		Library.Fonts:Apply(input, "Code", 14)

		local statusLbl = new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 100), Size = UDim2.new(1, 0, 0, 18),
			Text = "", TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, Parent = card,
		})
		Library.Fonts:Apply(statusLbl, "Gotham", 12)

		local unlockBtn = new("TextButton", {
			BackgroundColor3 = theme.Accent, Position = UDim2.new(0, 0, 0, 126), Size = UDim2.new(1, 0, 0, 34),
			Text = "Разблокировать", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, AutoButtonColor = false, Parent = card,
		}, { corner(8) })
		Library.Fonts:Apply(unlockBtn, "Gotham Bold", 14)

		local btnRow = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 168), Size = UDim2.new(1, 0, 0, 28), Parent = card })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }).Parent = btnRow

		local function linkBtn(text, url)
			local b = new("TextButton", {
				BackgroundColor3 = theme.Bg, Size = UDim2.new(0.5, -4, 1, 0), Text = text, TextColor3 = theme.SubText, TextSize = 12, Parent = btnRow,
			}, { corner(6) })
			Library.Fonts:Apply(b, "Gotham", 12)
			if url then
				track(b.MouseButton1Click:Connect(function()
					pcall(function() setclipboard(url) end)
					Library:Notification({ Title = "Ссылка скопирована", Text = url, Duration = 3 })
				end))
			end
			return b
		end
		linkBtn("Купить ключ", opts.BuyUrl)
		linkBtn("Discord", opts.DiscordUrl)

		local cooldownLbl = new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 202), Size = UDim2.new(1, 0, 0, 16),
			Text = "", TextColor3 = Color3.fromRGB(235, 120, 120), TextSize = 11, Parent = card,
		})
		Library.Fonts:Apply(cooldownLbl, "Gotham", 11)

		-- Автоподстановка сохранённого ключа
		local savedKey = self2:LoadSavedKey()
		if savedKey and savedKey ~= "" then
			input.Text = savedKey
			statusLbl.Text = "Сохранённый ключ найден"
			statusLbl.TextColor3 = theme.SubText
		end

		local maskPattern = "^%u%u%u%u%-%u%u%u%u%-%u%u%u%u$"
		local debounceToken = 0

		local function liveValidateFormat(text)
			return text:match(maskPattern) ~= nil
		end

		track(input:GetPropertyChangedSignal("Text"):Connect(function()
			input.Text = input.Text:upper()
			debounceToken = debounceToken + 1
			local myToken = debounceToken
			task.delay(0.4, function()
				if myToken ~= debounceToken then return end
				local formatOk = liveValidateFormat(input.Text)
				unlockBtn.BackgroundColor3 = formatOk and theme.Accent or theme.Bg
				unlockBtn.AutoButtonColor = formatOk
				if input.Text == "" then
					statusLbl.Text = ""
				elseif formatOk then
					statusLbl.Text = "Формат верный"
					statusLbl.TextColor3 = Color3.fromRGB(100, 210, 130)
				else
					statusLbl.Text = "Ожидаемый формат: XXXX-XXXX-XXXX"
					statusLbl.TextColor3 = Color3.fromRGB(230, 110, 110)
				end
			end)
		end))

		local function attemptUnlock()
			if not liveValidateFormat(input.Text) then return end

			local allowed, wait = self2:_checkRateLimit()
			if not allowed then
				cooldownLbl.Text = ("Слишком много попыток. Повтор через %ds"):format(math.ceil(wait))
				return
			end
			self2:_recordAttempt()

			local key = input.Text
			local ok, reason = true, nil
			if opts.Validate then
				ok, reason = opts.Validate(key)
			end

			if ok then
				statusLbl.Text = "Ключ принят"
				statusLbl.TextColor3 = Color3.fromRGB(100, 210, 130)
				Library.Sounds:Play("toggleOn")
				self2:SaveKey(key)
				task.wait(0.2)
				local fadeOut = tween(overlay, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { BackgroundTransparency = 1 })
				tween(card, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { BackgroundTransparency = 1 })
				fadeOut.Completed:Wait()
				overlay:Destroy()
				safeCallback(onSuccess, key)
			else
				statusLbl.Text = reason or "Неверный ключ"
				statusLbl.TextColor3 = Color3.fromRGB(230, 110, 110)
				Library.Sounds:Play("toggleOff")
				tween(card, 0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, { Position = card.Position + UDim2.new(0, 6, 0, 0) })
				task.wait(0.08)
				tween(card, 0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, { Position = UDim2.new(0.5, 0, 0.5, 0) })
			end
		end

		track(unlockBtn.MouseButton1Click:Connect(attemptUnlock))
		track(input.FocusLost:Connect(function(enterPressed)
			if enterPressed then attemptUnlock() end
		end))
	end

	return self2
end

------------------------------------------------------------------
-- ЭЛЕМЕНТЫ: базовый ряд с подписью (для Toggle/Slider/Dropdown и т.д.)
------------------------------------------------------------------
local function baseRow(parent, theme, height)
	return new("Frame", {
		BackgroundColor3 = theme.Bg, Size = UDim2.new(1, 0, 0, height or 36),
		Parent = parent,
	}, { corner(8), pad(10, 0, 10, 0) })
end

------------------------------------------------------------------
-- ДИСПЕТЧЕР ЭЛЕМЕНТОВ (общая фабрика методов Toggle/Slider/... — переиспользуется
-- Section'ом, Group и Row, чтобы контейнеры можно было свободно вкладывать друг в друга)
------------------------------------------------------------------
local function makeElementDispatcher(getBody)
	local dispatcher = {}

	local function add(kind, o)
		o = o or {}
		local builder = ELEMENT_BUILDERS[kind]
		local body = getBody()
		local element = builder(body, o)
		if o.Flag then
			Library._elements[o.Flag] = element
			if Library.Flags[o.Flag] == nil then
				Library.Flags[o.Flag] = element.Get and element:Get() or o.Default
			end
		end
		return element
	end

	function dispatcher:Toggle(o) return add("Toggle", o) end
	function dispatcher:Slider(o) return add("Slider", o) end
	function dispatcher:Dropdown(o) return add("Dropdown", o) end
	function dispatcher:Keybind(o) return add("Keybind", o) end
	function dispatcher:Colorpicker(o) return add("Colorpicker", o) end
	function dispatcher:Textbox(o) return add("Textbox", o) end
	function dispatcher:Button(o) return add("Button", o) end
	function dispatcher:Label(o) return add("Label", o) end
	function dispatcher:Divider() return add("Divider", {}) end
	function dispatcher:Paragraph(o) return add("Paragraph", o) end
	function dispatcher:Radio(o) return add("Radio", o) end
	function dispatcher:Stepper(o) return add("Stepper", o) end
	function dispatcher:ProgressBar(o) return add("ProgressBar", o) end
	function dispatcher:Table(o) return add("Table", o) end
	function dispatcher:Image(o) return add("Image", o) end

	-- Row(count) — раскладывает count колонок в ряд; у каждой колонки доступны
	-- те же методы (Toggle/Slider/...), что и у обычной секции.
	function dispatcher:Row(count)
		count = count or 2
		local body = getBody()
		local rowFrame = new("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = body,
		})
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = rowFrame
		local cells = {}
		for i = 1, count do
			local cell = new("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1 / count, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = rowFrame,
			})
			local _, dp = Library.Theming:GetDensity()
			listLayout(Enum.FillDirection.Vertical, dp and dp.row or 6).Parent = cell
			table.insert(cells, makeElementDispatcher(function() return cell end))
		end
		return table.unpack(cells)
	end

	-- Group(opts) — мастер-тоггл, который показывает/прячет вложенные элементы
	-- (условная видимость, например "включить блок настроек ESP").
	function dispatcher:Group(gopts)
		gopts = gopts or {}
		local body = getBody()
		local groupBody = new("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			Visible = gopts.Default and true or false, ClipsDescendants = true, Parent = body,
		})
		local _, dp = Library.Theming:GetDensity()
		listLayout(Enum.FillDirection.Vertical, dp and dp.row or 6).Parent = groupBody
		pad(14, 4, 0, 0).Parent = groupBody

		local masterToggle = add("Toggle", {
			Name = gopts.Name, Default = gopts.Default, Flag = gopts.Flag,
			Callback = function(v)
				groupBody.Visible = v
				safeCallback(gopts.Callback, v)
			end,
		})

		local sub = makeElementDispatcher(function() return groupBody end)
		sub.MasterToggle = masterToggle
		return sub
	end

	return dispatcher
end

------------------------------------------------------------------
-- SECTION
------------------------------------------------------------------
local SectionMT = {}
SectionMT.__index = SectionMT

local function createSection(parentBody, opts)
	local theme = Library.Theming:Get()
	opts = opts or {}

	local section = setmetatable({}, SectionMT)

	local container = new("Frame", {
		BackgroundColor3 = theme.Panel, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parentBody,
	}, { corner(10), stroke(theme.Accent, 1, 0.8), pad(10, 8, 10, 10) })

	local headerBtn = new("TextButton", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Text = "", AutoButtonColor = false, Parent = container,
	})
	local titleOffset = 0
	if opts.Icon and Library.Icons:Get(opts.Icon) then
		titleOffset = 18
		new("ImageLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 0, 0.5, -7),
			Image = Library.Icons:Get(opts.Icon), ImageColor3 = theme.Accent, Parent = headerBtn,
		})
	end
	local titleLbl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -20 - titleOffset, 1, 0), Position = UDim2.new(0, titleOffset, 0, 0),
		Text = opts.Name or "Секция", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Parent = headerBtn,
	})
	Library.Fonts:Apply(titleLbl, "Gotham Bold", 13)
	local arrow = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 16, 0, 16),
		Text = "▾", TextColor3 = theme.SubText, TextSize = 12, Parent = headerBtn,
	})

	local body = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, 26), Parent = container, ClipsDescendants = true })
	local _, densityPad2 = Library.Theming:GetDensity()
	local bodyListLayout = listLayout(Enum.FillDirection.Vertical, densityPad2 and densityPad2.row or 6)
	bodyListLayout.Parent = body

	-- живое обновление отступов при смене плотности интерфейса (Theming:SetDensity)
	Library.Theming:OnChanged(function()
		local _, dp = Library.Theming:GetDensity()
		bodyListLayout.Padding = UDim.new(0, dp and dp.row or 6)
	end)

	local collapsible = makeCollapsible(headerBtn, arrow, body, opts.Collapsed, opts.OnCollapse)
	section._collapsible = collapsible
	section._body = body
	section._container = container

	local dispatcher = makeElementDispatcher(function() return body end)
	for name, fn in pairs(dispatcher) do
		if type(fn) == "function" then
			section[name] = fn
		end
	end

	return section
end

------------------------------------------------------------------
-- ЭЛЕМЕНТЫ (Toggle / Slider / Dropdown / Keybind / Colorpicker / Textbox / Button / Label)
------------------------------------------------------------------
ELEMENT_BUILDERS = {}

-- TOGGLE ----------------------------------------------------------
ELEMENT_BUILDERS.Toggle = function(parent, o)
	local theme = Library.Theming:Get()
	local row = baseRow(parent, theme, 36)

	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -50, 1, 0),
		Text = o.Name or "Toggle", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Parent = row,
	})
	Library.Fonts:Apply(lbl, "Gotham", 13)

	local track_ = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 38, 0, 20), BackgroundColor3 = theme.Bg, Parent = row,
	}, { corner(10), stroke(theme.Accent, 1, 0.7) })
	local knob = new("Frame", {
		Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = theme.SubText, Parent = track_,
	}, { corner(8) })

	local clickArea = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", Parent = row })

	local state = o.Default and true or false
	local callback = o.Callback

	local function render(animated)
		local pos = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		local color = state and theme.Accent or theme.Bg
		local knobColor = state and Color3.new(1, 1, 1) or theme.SubText
		if animated then
			tween(knob, 0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Position = pos, BackgroundColor3 = knobColor })
			tween(track_, 0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { BackgroundColor3 = color })
		else
			knob.Position = pos
			knob.BackgroundColor3 = knobColor
			track_.BackgroundColor3 = color
		end
	end
	render(false)

	local api = {}
	api._inst = row
	function api:Get() return state end
	function api:Set(v, fireCallback)
		state = v and true or false
		render(true)
		if o.Flag then Library.Flags[o.Flag] = state end
		Library.Sounds:Play(state and "toggleOn" or "toggleOff")
		if fireCallback ~= false then safeCallback(callback, state) end
	end

	track(clickArea.MouseButton1Click:Connect(function()
		api:Set(not state)
	end))

	return api
end

-- SLIDER ------------------------------------------------------------
ELEMENT_BUILDERS.Slider = function(parent, o)
	local theme = Library.Theming:Get()
	local min = o.Min or 0
	local max = o.Max or 100
	local decimals = o.Decimals or 0
	local step = o.Increment or (decimals > 0 and (1 / (10 ^ decimals)) or 1)
	local suffix = o.Suffix or ""
	local value = clamp(o.Default or min, min, max)

	local row = baseRow(parent, theme, 46)
	row.BackgroundTransparency = 0

	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 4), Size = UDim2.new(1, -70, 0, 16),
		Text = o.Name or "Slider", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Parent = row,
	})
	Library.Fonts:Apply(lbl, "Gotham", 13)

	local valueBoxBg = new("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.new(0, 60, 0, 20),
		BackgroundColor3 = theme.Panel, Parent = row,
	}, { corner(6), stroke(theme.Accent, 1, 0.7) })
	local valueBox = new("TextBox", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -4, 1, 0), Position = UDim2.new(0, 2, 0, 0),
		Text = fmtNumber(value, decimals) .. suffix, TextColor3 = theme.Text, TextSize = 12, ClearTextOnFocus = false, Parent = valueBoxBg,
	})
	Library.Fonts:Apply(valueBox, "Code", 12)

	local barBg = new("Frame", {
		Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = theme.Panel, Parent = row,
	}, { corner(3) })
	local barFill = new("Frame", {
		Size = UDim2.new((value - min) / math.max(max - min, 1e-6), 0, 1, 0), BackgroundColor3 = theme.Accent, Parent = barBg,
	}, { corner(3) })
	local grabber = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new((value - min) / math.max(max - min, 1e-6), 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = barBg,
	}, { corner(6) })

	local hint = nil
	if o.Hint then
		hint = new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 0, 12),
			Text = o.Hint, TextColor3 = theme.SubText, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
		})
		Library.Fonts:Apply(hint, "Gotham", 10)
		row.Size = UDim2.new(1, 0, 0, 58)
	end

	local callback = o.Callback
	local dragging = false

	local api = {}
	api._inst = row
	function api:Get() return value end
	function api:Set(v, fireCallback)
		v = clamp(round(v, decimals), min, max)
		value = v
		local pct = (value - min) / math.max(max - min, 1e-6)
		barFill.Size = UDim2.new(pct, 0, 1, 0)
		grabber.Position = UDim2.new(pct, 0, 0.5, 0)
		valueBox.Text = fmtNumber(value, decimals) .. suffix
		if o.Flag then Library.Flags[o.Flag] = value end
		if fireCallback ~= false then safeCallback(callback, value) end
	end

	local function setFromX(absX)
		local rel = clamp((absX - barBg.AbsolutePosition.X) / math.max(barBg.AbsoluteSize.X, 1), 0, 1)
		local raw = min + rel * (max - min)
		raw = math.floor(raw / step + 0.5) * step
		api:Set(raw)
	end

	track(barBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	-- ручной ввод числа
	local editingCache = nil
	track(valueBox.Focused:Connect(function()
		editingCache = valueBox.Text
	end))
	track(valueBox.FocusLost:Connect(function(enterPressed)
		if not enterPressed then
			-- считаем blur как подтверждение (по ТЗ), Escape отдельно ниже не имеет отдельного сигнала в Roblox API
		end
		local raw = valueBox.Text:gsub(",", "."):gsub("[^%-%.%d]", "")
		local n = tonumber(raw)
		if n then
			api:Set(n)
		else
			valueBox.Text = fmtNumber(value, decimals) .. suffix
		end
	end))

	-- клавиатурная настройка стрелками, когда фокус на боксе значения
	track(valueBox.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			valueBox.Text = fmtNumber(value, decimals) .. suffix
			valueBox:ReleaseFocus()
		elseif input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.Right then
			local mult = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 10 or 1
			local delta = (input.KeyCode == Enum.KeyCode.Right and step or -step) * mult
			api:Set(value + delta)
		end
	end))

	return api
end

-- DROPDOWN ------------------------------------------------------------
ELEMENT_BUILDERS.Dropdown = function(parent, o)
	local theme = Library.Theming:Get()
	local multi = o.Multi and true or false
	local options = o.Options or {}
	local selected = {}
	if multi then
		for _, v in ipairs(o.Default or {}) do selected[v] = true end
	else
		if o.Default then selected[o.Default] = true end
	end

	local row = baseRow(parent, theme, 36)
	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 1, 0),
		Text = o.Name or "Dropdown", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Parent = row,
	})
	Library.Fonts:Apply(lbl, "Gotham", 13)

	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0.48, 0, 0, 26),
		BackgroundColor3 = theme.Panel, Text = "", AutoButtonColor = false, Parent = row,
	}, { corner(6), stroke(theme.Accent, 1, 0.7) })
	local btnLbl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 8, 0, 0),
		Text = "Выбрать...", TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, Parent = btn,
	})
	Library.Fonts:Apply(btnLbl, "Gotham", 12)

	local listFrame = new("Frame", {
		BackgroundColor3 = theme.Panel, Visible = false, ZIndex = 20,
		Size = UDim2.new(0, 200, 0, math.min(#options * 26 + 40, 220)),
		Parent = row,
	}, { corner(8), stroke(theme.Accent, 1, 0.6), pad(6, 6, 6, 6) })

	local searchBox = new("TextBox", {
		BackgroundColor3 = theme.Bg, Size = UDim2.new(1, 0, 0, 22), PlaceholderText = "Поиск...", Text = "",
		TextColor3 = theme.Text, TextSize = 12, ZIndex = 21, Parent = listFrame,
	}, { corner(5) })
	Library.Fonts:Apply(searchBox, "Gotham", 12)

	local scroller = new("ScrollingFrame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 1, -26),
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = theme.Accent, ZIndex = 21, Parent = listFrame,
	})
	listLayout(Enum.FillDirection.Vertical, 2).Parent = scroller

	local callback = o.Callback
	local api = {}
	api._inst = row

	local function summaryText()
		local names = {}
		for k, v in pairs(selected) do if v then table.insert(names, k) end end
		if #names == 0 then return "Выбрать..." end
		table.sort(names)
		return table.concat(names, ", ")
	end

	local function refreshLabel()
		btnLbl.Text = summaryText()
		btnLbl.TextColor3 = (next(selected)) and theme.Text or theme.SubText
	end

	local optionButtons = {}

	local function rebuildOptions(filter)
		for _, c in ipairs(optionButtons) do c:Destroy() end
		optionButtons = {}
		for i, optName in ipairs(options) do
			if not filter or filter == "" or optName:lower():find(filter:lower(), 1, true) then
				local optBtn = new("TextButton", {
					BackgroundColor3 = selected[optName] and theme.Accent or theme.Bg,
					Size = UDim2.new(1, 0, 0, 24), Text = "", AutoButtonColor = false, ZIndex = 21, LayoutOrder = i, Parent = scroller,
				}, { corner(5) })
				local optLbl = new("TextLabel", {
					BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 8, 0, 0),
					Text = optName, TextColor3 = selected[optName] and Color3.new(1, 1, 1) or theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, ZIndex = 21, Parent = optBtn,
				})
				Library.Fonts:Apply(optLbl, "Gotham", 12)

				track(optBtn.MouseButton1Click:Connect(function()
					if multi then
						selected[optName] = not selected[optName] or nil
						if selected[optName] == nil then selected[optName] = nil end
					else
						selected = { [optName] = true }
						listFrame.Visible = false
					end
					refreshLabel()
					rebuildOptions(searchBox.Text)
					if o.Flag then
						Library.Flags[o.Flag] = multi and (function()
							local t = {}
							for k, v in pairs(selected) do if v then table.insert(t, k) end end
							return t
						end)() or next(selected)
					end
					safeCallback(callback, multi and (function()
						local t = {}
						for k, v in pairs(selected) do if v then table.insert(t, k) end end
						return t
					end)() or next(selected))
				end))
				table.insert(optionButtons, optBtn)
			end
		end
	end

	rebuildOptions(nil)
	refreshLabel()

	track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		rebuildOptions(searchBox.Text)
	end))

	track(btn.MouseButton1Click:Connect(function()
		listFrame.Visible = not listFrame.Visible
	end))

	function api:Get()
		if multi then
			local t = {}
			for k, v in pairs(selected) do if v then table.insert(t, k) end end
			return t
		end
		return next(selected)
	end
	function api:SetOptions(newOptions)
		options = newOptions
		rebuildOptions(searchBox.Text)
	end
	function api:Refresh(newOptions)
		if newOptions then options = newOptions end
		rebuildOptions(searchBox.Text)
	end

	return api
end

-- KEYBIND -------------------------------------------------------------
ELEMENT_BUILDERS.Keybind = function(parent, o)
	local theme = Library.Theming:Get()
	local row = baseRow(parent, theme, 36)

	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -110, 1, 0),
		Text = o.Name or "Keybind", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Parent = row,
	})
	Library.Fonts:Apply(lbl, "Gotham", 13)

	local modes = { "Toggle", "Hold", "Always" }
	local mode = o.Mode or "Toggle"

	local modeBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -76, 0.5, 0), Size = UDim2.new(0, 60, 0, 22),
		BackgroundColor3 = theme.Panel, Text = mode, TextColor3 = theme.SubText, TextSize = 11, AutoButtonColor = false, Parent = row,
	}, { corner(6) })
	Library.Fonts:Apply(modeBtn, "Gotham", 11)

	local keyBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 68, 0, 22),
		BackgroundColor3 = theme.Panel, Text = o.Default and o.Default.Name or "Нет", TextColor3 = theme.Text, TextSize = 11, AutoButtonColor = false, Parent = row,
	}, { corner(6), stroke(theme.Accent, 1, 0.7) })
	Library.Fonts:Apply(keyBtn, "Gotham", 11)

	local currentKey = o.Default
	local listening = false
	local active = false
	local callback = o.Callback

	track(modeBtn.MouseButton1Click:Connect(function()
		local idx = table.find(modes, mode) or 1
		mode = modes[(idx % #modes) + 1]
		modeBtn.Text = mode
	end))

	track(keyBtn.MouseButton1Click:Connect(function()
		listening = true
		keyBtn.Text = "..."
	end))

	track(UserInputService.InputBegan:Connect(function(input, gp)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				currentKey = input.KeyCode
				keyBtn.Text = input.KeyCode.Name
				listening = false
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				currentKey = Enum.UserInputType.MouseButton2
				keyBtn.Text = "MB2"
				listening = false
			end
			return
		end
		if gp then return end
		if not currentKey then return end
		local matches = (input.KeyCode == currentKey) or (input.UserInputType == currentKey)
		if not matches then return end
		if mode == "Toggle" then
			active = not active
			safeCallback(callback, active)
		elseif mode == "Hold" then
			active = true
			safeCallback(callback, true)
		end
	end))

	track(UserInputService.InputEnded:Connect(function(input)
		if not currentKey then return end
		local matches = (input.KeyCode == currentKey) or (input.UserInputType == currentKey)
		if matches and mode == "Hold" then
			active = false
			safeCallback(callback, false)
		end
	end))

	local api = {}
	api._inst = row
	function api:Get() return currentKey, mode, active end
	function api:Set(keyCode, m)
		currentKey = keyCode
		if m then mode = m; modeBtn.Text = mode end
		keyBtn.Text = keyCode and (typeof(keyCode) == "EnumItem" and keyCode.Name or tostring(keyCode)) or "Нет"
	end

	return api
end

-- COLORPICKER -----------------------------------------------------------
ELEMENT_BUILDERS.Colorpicker = function(parent, o)
	local theme = Library.Theming:Get()
	local row = baseRow(parent, theme, 36)

	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -50, 1, 0),
		Text = o.Name or "Color", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Parent = row,
	})
	Library.Fonts:Apply(lbl, "Gotham", 13)

	local color = o.Default or Color3.fromRGB(255, 255, 255)
	local swatch = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 28, 0, 20),
		BackgroundColor3 = color, Text = "", AutoButtonColor = false, Parent = row,
	}, { corner(6), stroke(theme.Text, 1, 0.7) })

	local panel = new("Frame", {
		BackgroundColor3 = theme.Panel, Visible = false, ZIndex = 25, Size = UDim2.new(0, 200, 0, 190),
		Parent = row,
	}, { corner(8), stroke(theme.Accent, 1, 0.6), pad(10, 10, 10, 10) })

	local sv = new("Frame", { BackgroundColor3 = Color3.new(1, 0, 0), Size = UDim2.new(1, 0, 0, 100), ZIndex = 26, Parent = panel }, { corner(6) })
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0)), Rotation = 90 }).Parent = sv
	local svOverlay = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 27, Parent = sv })
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)), Transparency = NumberSequence.new(0, 1), Rotation = 0 }).Parent = svOverlay

	local hueBar = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.new(0, 0, 0, 108), Size = UDim2.new(1, 0, 0, 14), ZIndex = 26, Parent = panel }, { corner(6) })
	local hueGrad = new("UIGradient", { Rotation = 0 })
	do
		local seq = {}
		for i = 0, 6 do
			seq[#seq + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1))
		end
		hueGrad.Color = ColorSequence.new(seq)
	end
	hueGrad.Parent = hueBar

	local hexBox = new("TextBox", {
		BackgroundColor3 = theme.Bg, Position = UDim2.new(0, 0, 0, 130), Size = UDim2.new(1, 0, 0, 22),
		Text = string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255),
		TextColor3 = theme.Text, TextSize = 12, ZIndex = 26, Parent = panel,
	}, { corner(6) })
	Library.Fonts:Apply(hexBox, "Code", 12)

	local h, s, v = Color3.toHSV(color)
	local callback = o.Callback

	local function updateColor()
		color = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = color
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		hexBox.Text = string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
		if o.Flag then Library.Flags[o.Flag] = color end
		safeCallback(callback, color)
	end

	local draggingSV, draggingHue = false, false
	track(sv.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV = true end
	end))
	track(hueBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue = true end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV = false; draggingHue = false end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		if draggingSV then
			local relX = clamp((input.Position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
			local relY = clamp((input.Position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
			s = relX
			v = 1 - relY
			updateColor()
		elseif draggingHue then
			local relX = clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
			h = relX
			updateColor()
		end
	end))

	track(hexBox.FocusLost:Connect(function()
		local hex = hexBox.Text:gsub("#", "")
		if #hex == 6 and hex:match("^%x+$") then
			local r = tonumber(hex:sub(1, 2), 16) / 255
			local g = tonumber(hex:sub(3, 4), 16) / 255
			local b = tonumber(hex:sub(5, 6), 16) / 255
			h, s, v = Color3.toHSV(Color3.new(r, g, b))
			updateColor()
		else
			hexBox.Text = string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
		end
	end))

	track(swatch.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
	end))

	local api = {}
	api._inst = row
	function api:Get() return color end
	function api:Set(c)
		h, s, v = Color3.toHSV(c)
		updateColor()
	end

	return api
end

-- TEXTBOX -----------------------------------------------------------
ELEMENT_BUILDERS.Textbox = function(parent, o)
	local theme = Library.Theming:Get()
	local row = baseRow(parent, theme, 36)

	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(0.4, 0, 1, 0),
		Text = o.Name or "Textbox", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Parent = row,
	})
	Library.Fonts:Apply(lbl, "Gotham", 13)

	local boxBg = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0.55, 0, 0, 24),
		BackgroundColor3 = theme.Panel, Parent = row,
	}, { corner(6), stroke(theme.Accent, 1, 0.7) })
	local box = new("TextBox", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0),
		PlaceholderText = o.Placeholder or "", Text = o.Default or "", TextColor3 = theme.Text, TextSize = 12,
		ClearTextOnFocus = false, Parent = boxBg,
	})
	Library.Fonts:Apply(box, "Gotham", 12)

	if o.Numeric then
		track(box:GetPropertyChangedSignal("Text"):Connect(function()
			local filtered = box.Text:gsub("[^%-%.%d]", "")
			if filtered ~= box.Text then box.Text = filtered end
		end))
	end

	local callback = o.Callback
	track(box.FocusLost:Connect(function(enterPressed)
		if o.Flag then Library.Flags[o.Flag] = box.Text end
		safeCallback(callback, box.Text, enterPressed)
	end))

	local api = {}
	api._inst = row
	function api:Get() return box.Text end
	function api:Set(text)
		box.Text = text
		if o.Flag then Library.Flags[o.Flag] = text end
	end

	return api
end

-- BUTTON -----------------------------------------------------------
ELEMENT_BUILDERS.Button = function(parent, o)
	local theme = Library.Theming:Get()
	local row = new("TextButton", {
		BackgroundColor3 = theme.Accent, Size = UDim2.new(1, 0, 0, 32),
		Text = o.Name or "Button", TextColor3 = Color3.new(1, 1, 1), TextSize = 13, AutoButtonColor = false, Parent = parent,
	}, { corner(8) })
	Library.Fonts:Apply(row, "Gotham Bold", 13)

	track(row.MouseEnter:Connect(function()
		Library.Sounds:Play("hover")
		tween(row, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 0.1 })
	end))
	track(row.MouseLeave:Connect(function()
		tween(row, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 0 })
	end))
	track(row.MouseButton1Click:Connect(function()
		Library.Sounds:Play("click")
		safeCallback(o.Callback)
	end))

	return { Get = function() return nil end, _inst = row }
end

-- LABEL -----------------------------------------------------------
ELEMENT_BUILDERS.Label = function(parent, o)
	local theme = Library.Theming:Get()
	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
		Text = o.Text or o.Name or "", TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12,
		TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
	})
	Library.Fonts:Apply(lbl, "Gotham", 12)
	return {
		Set = function(_, text) lbl.Text = text end,
		Get = function() return lbl.Text end,
	}
end

-- DIVIDER -----------------------------------------------------------
ELEMENT_BUILDERS.Divider = function(parent, _o)
	local theme = Library.Theming:Get()
	return {
		_inst = new("Frame", {
			BackgroundColor3 = theme.SubText, BackgroundTransparency = 0.85,
			Size = UDim2.new(1, 0, 0, 1), Parent = parent,
		}),
		Get = function() return nil end,
	}
end

-- PARAGRAPH -----------------------------------------------------------
ELEMENT_BUILDERS.Paragraph = function(parent, o)
	local theme = Library.Theming:Get()
	local holder = new("Frame", {
		BackgroundColor3 = theme.Bg, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
	}, { corner(8), pad(10, 8, 10, 8) })
	if o.Title then
		local t = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
			Text = o.Title, TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Parent = holder,
		})
		Library.Fonts:Apply(t, "Gotham Bold", 13)
	end
	local body = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, o.Title and 18 or 0), Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Text = o.Text or "", TextColor3 = theme.SubText, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, Parent = holder,
	})
	Library.Fonts:Apply(body, "Gotham", 12)
	return {
		Set = function(_, text) body.Text = text end,
		Get = function() return body.Text end,
	}
end

-- RADIO (инлайн-группа взаимоисключающих кнопок, без выпадающей панели) ------
ELEMENT_BUILDERS.Radio = function(parent, o)
	local theme = Library.Theming:Get()
	local options = o.Options or {}
	local selected = o.Default

	local wrap = new("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
	})

	local offsetY = 0
	if o.Name then
		local lbl = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
			Text = o.Name, TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Parent = wrap,
		})
		Library.Fonts:Apply(lbl, "Gotham", 13)
		offsetY = 20
	end

	local optsRow = new("Frame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, offsetY), Size = UDim2.new(1, 0, 0, 26), Parent = wrap,
	})
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = optsRow

	local callback = o.Callback
	local buttons = {}

	local function render()
		for name, entry in pairs(buttons) do
			local active = (selected == name)
			tween(entry.btn, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundColor3 = active and theme.Accent or theme.Bg })
			entry.lbl.TextColor3 = active and Color3.new(1, 1, 1) or theme.SubText
		end
	end

	local api = {}
	api._inst = wrap

	for i, name in ipairs(options) do
		local btn = new("TextButton", {
			BackgroundColor3 = theme.Bg, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
			Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = optsRow,
		}, { corner(6), pad(10, 0, 10, 0) })
		local btnLbl = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
			Text = name, TextColor3 = theme.SubText, TextSize = 12, Parent = btn,
		})
		Library.Fonts:Apply(btnLbl, "Gotham", 12)
		buttons[name] = { btn = btn, lbl = btnLbl }

		track(btn.MouseButton1Click:Connect(function()
			api:Set(name)
		end))
	end
	render()

	function api:Get() return selected end
	function api:Set(name, fireCallback)
		selected = name
		render()
		if o.Flag then Library.Flags[o.Flag] = selected end
		if fireCallback ~= false then safeCallback(callback, selected) end
	end

	return api
end

-- STEPPER (числовой степпер с кнопками -/+) ------------------------------
ELEMENT_BUILDERS.Stepper = function(parent, o)
	local theme = Library.Theming:Get()
	local min = o.Min or 0
	local max = o.Max or 100
	local step = o.Step or 1
	local decimals = o.Decimals or 0
	local suffix = o.Suffix or ""
	local value = clamp(o.Default or min, min, max)

	local row = baseRow(parent, theme, 36)
	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -120, 1, 0),
		Text = o.Name or "Stepper", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Parent = row,
	})
	Library.Fonts:Apply(lbl, "Gotham", 13)

	local controls = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 110, 0, 24),
		BackgroundTransparency = 1, Parent = row,
	})
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }).Parent = controls

	local function mkBtn(text)
		local b = new("TextButton", {
			BackgroundColor3 = theme.Panel, Size = UDim2.new(0, 24, 1, 0), Text = text,
			TextColor3 = theme.Text, TextSize = 14, AutoButtonColor = false, Parent = controls,
		}, { corner(6) })
		Library.Fonts:Apply(b, "Gotham Bold", 14)
		return b
	end
	local minusBtn = mkBtn("−")
	local valLbl = new("TextLabel", {
		BackgroundColor3 = theme.Bg, Size = UDim2.new(0, 50, 1, 0),
		Text = fmtNumber(value, decimals) .. suffix, TextColor3 = theme.Text, TextSize = 12, Parent = controls,
	}, { corner(6) })
	Library.Fonts:Apply(valLbl, "Code", 12)
	local plusBtn = mkBtn("+")

	local callback = o.Callback
	local api = {}
	api._inst = row

	function api:Get() return value end
	function api:Set(v, fireCallback)
		value = clamp(round(v, decimals), min, max)
		valLbl.Text = fmtNumber(value, decimals) .. suffix
		if o.Flag then Library.Flags[o.Flag] = value end
		if fireCallback ~= false then safeCallback(callback, value) end
	end

	track(minusBtn.MouseButton1Click:Connect(function() api:Set(value - step) end))
	track(plusBtn.MouseButton1Click:Connect(function() api:Set(value + step) end))

	return api
end

-- PROGRESSBAR (встраиваемый прогресс-бар, не тянет за собой Loader-оверлей) --
ELEMENT_BUILDERS.ProgressBar = function(parent, o)
	local theme = Library.Theming:Get()
	local hasName = o.Name ~= nil

	local row = new("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, hasName and 34 or 16), Parent = parent,
	})

	if hasName then
		local lbl = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
			Text = o.Name, TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, Parent = row,
		})
		Library.Fonts:Apply(lbl, "Gotham", 12)
	end

	local barBg = new("Frame", {
		BackgroundColor3 = theme.Bg, Position = UDim2.new(0, 0, 0, hasName and 20 or 0), Size = UDim2.new(1, 0, 0, 8), Parent = row,
	}, { corner(4) })
	local barFill = new("Frame", {
		BackgroundColor3 = theme.Accent, Size = UDim2.new(clamp(o.Default or 0, 0, 1), 0, 1, 0), Parent = barBg,
	}, { corner(4) })

	local api = {}
	api._inst = row

	function api:Get() return barFill.Size.X.Scale end
	function api:Set(pct)
		pct = clamp(pct, 0, 1)
		tween(barFill, 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Size = UDim2.new(pct, 0, 1, 0) })
	end

	return api
end

-- TABLE (простая табличная сетка с опциональной сортировкой по клику на заголовок) --
ELEMENT_BUILDERS.Table = function(parent, o)
	local theme = Library.Theming:Get()
	local columns = o.Columns or {}
	local rows = o.Rows or {}
	local sortable = o.Sortable and true or false
	local hasName = o.Name ~= nil

	local holder = new("Frame", {
		BackgroundColor3 = theme.Bg, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
	}, { corner(8), pad(6, 6, 6, 6) })

	if hasName then
		local title = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
			Text = o.Name, TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Parent = holder,
		})
		Library.Fonts:Apply(title, "Gotham Bold", 13)
	end

	local headerOffset = hasName and 18 or 0
	local headerRow = new("Frame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, headerOffset), Size = UDim2.new(1, 0, 0, 20), Parent = holder,
	})
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }).Parent = headerRow
	local colWidth = 1 / math.max(#columns, 1)
	local sortState = { col = nil, asc = true }

	local bodyFrame = new("ScrollingFrame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, headerOffset + 22), Size = UDim2.new(1, 0, 0, o.Height or 120),
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = theme.Accent, Parent = holder,
	})
	listLayout(Enum.FillDirection.Vertical, 2).Parent = bodyFrame

	local function renderRows()
		for _, c in ipairs(bodyFrame:GetChildren()) do
			if not c:IsA("UIListLayout") then c:Destroy() end
		end
		for i, rowData in ipairs(rows) do
			local r = new("Frame", {
				BackgroundColor3 = theme.Panel, BackgroundTransparency = (i % 2 == 0) and 1 or 0.92,
				Size = UDim2.new(1, 0, 0, 20), LayoutOrder = i, Parent = bodyFrame,
			})
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }).Parent = r
			for _, col in ipairs(columns) do
				local cellLbl = new("TextLabel", {
					BackgroundTransparency = 1, Size = UDim2.new(colWidth, -4, 1, 0), Text = tostring(rowData[col] or ""),
					TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 11, Parent = r,
				})
				Library.Fonts:Apply(cellLbl, "Gotham", 11)
			end
		end
	end

	for _, col in ipairs(columns) do
		local props = {
			BackgroundTransparency = 1, Size = UDim2.new(colWidth, -4, 1, 0), Text = col,
			TextColor3 = theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 11, Parent = headerRow,
		}
		if sortable then props.AutoButtonColor = false end
		local hBtn = new(sortable and "TextButton" or "TextLabel", props)
		Library.Fonts:Apply(hBtn, "Gotham Bold", 11)
		if sortable then
			track(hBtn.MouseButton1Click:Connect(function()
				if sortState.col == col then
					sortState.asc = not sortState.asc
				else
					sortState.col = col
					sortState.asc = true
				end
				table.sort(rows, function(a, b)
					local av, bv = a[col], b[col]
					if type(av) == "number" and type(bv) == "number" then
						if sortState.asc then return av < bv else return av > bv end
					end
					if sortState.asc then return tostring(av) < tostring(bv) else return tostring(av) > tostring(bv) end
				end)
				renderRows()
			end))
		end
	end

	renderRows()

	local api = {}
	api._inst = holder
	function api:SetRows(newRows)
		rows = newRows or {}
		renderRows()
	end
	function api:Get() return rows end

	return api
end

-- IMAGE (встраиваемое изображение/баннер/логотип с опциональной подписью) ----
ELEMENT_BUILDERS.Image = function(parent, o)
	local theme = Library.Theming:Get()
	local height = o.Height or 120
	local hasCaption = o.Caption ~= nil

	local holder = new("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height + (hasCaption and 20 or 0)), Parent = parent,
	})

	local img = new("ImageLabel", {
		BackgroundColor3 = theme.Bg, Size = UDim2.new(1, 0, 0, height),
		Image = o.Image or "", ScaleType = o.ScaleType or Enum.ScaleType.Crop, Parent = holder,
	}, { corner(8) })

	if hasCaption then
		local cap = new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, height + 2), Size = UDim2.new(1, 0, 0, 16),
			Text = o.Caption, TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, Parent = holder,
		})
		Library.Fonts:Apply(cap, "Gotham", 11)
	end

	local api = {}
	api._inst = holder
	function api:Get() return img.Image end
	function api:Set(imageId) img.Image = imageId end

	return api
end

------------------------------------------------------------------
-- TOOLTIP (всплывающая подсказка для любого GuiObject)
------------------------------------------------------------------
local Tooltip = {}
Tooltip.__index = Tooltip

function Tooltip.new()
	return setmetatable({}, Tooltip)
end

-- Attach(guiObject, text) — показывает подсказку при наведении, следует за курсором
function Tooltip:Attach(guiObject, text)
	local theme = Library.Theming:Get()
	local root = ensureRoot()
	local bubble

	track(guiObject.MouseEnter:Connect(function()
		bubble = new("TextLabel", {
			BackgroundColor3 = theme.Panel, AutomaticSize = Enum.AutomaticSize.XY,
			Text = text, TextColor3 = theme.Text, TextSize = 12, ZIndex = 1000, Parent = root,
		}, { corner(6), stroke(theme.Accent, 1, 0.6), pad(6, 4, 6, 4) })
		Library.Fonts:Apply(bubble, "Gotham", 12)
		bubble.BackgroundTransparency = 1
		bubble.TextTransparency = 1
		tween(bubble, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 0, TextTransparency = 0 })
	end))
	track(guiObject.MouseMoved:Connect(function(x, y)
		if bubble then
			bubble.Position = UDim2.new(0, x + 14, 0, y + 14)
		end
	end))
	track(guiObject.MouseLeave:Connect(function()
		if bubble then
			bubble:Destroy()
			bubble = nil
		end
	end))
end

Library.Tooltip = Tooltip.new()

------------------------------------------------------------------
-- TAB
------------------------------------------------------------------
local TabMT = {}
TabMT.__index = TabMT

------------------------------------------------------------------
-- WINDOW
------------------------------------------------------------------
local WindowMT = {}
WindowMT.__index = WindowMT

-- opts: { Title, SubTitle, Size = UDim2, MinSize, MaxSize, KeySystem = self2 (опционально) }
function Library:Window(opts)
	opts = opts or {}
	local theme = self.Theming:Get()
	local root = ensureRoot()

	local window = setmetatable({}, WindowMT)
	window._tabs = {}
	window._name = opts.Name

	local main = new("Frame", {
		Name = "Window", BackgroundColor3 = theme.Bg,
		Size = opts.Size or UDim2.new(0, 620, 0, 420),
		Position = UDim2.new(0.5, -310, 0.5, -210),
		Parent = root,
	}, { corner(self.Theming:GetRadius()), stroke(theme.Accent, self.Theming:GetBorderThickness(), 0.5) })

	local windowGlow = glowStroke(main, theme.Accent, function() return self.Theming:GetGlow() end)
	window._main = main

	-- лёгкое появление окна (fade + scale) при создании
	main.BackgroundTransparency = 1
	main.Size = (opts.Size or UDim2.new(0, 620, 0, 420)) - UDim2.new(0, 16, 0, 16)
	local targetSize = opts.Size or UDim2.new(0, 620, 0, 420)
	tween(main, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundTransparency = 0, Size = targetSize })

	local titleBar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = main })
	local titleLbl = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 4), Size = UDim2.new(1, -120, 0, 18),
		Text = opts.Title or "Window", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15, Parent = titleBar,
	})
	Library.Fonts:Apply(titleLbl, "Gotham Bold", 15)
	local subLbl = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 20), Size = UDim2.new(1, -120, 0, 14),
		Text = opts.SubTitle or "", TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 11, Parent = titleBar,
	})
	Library.Fonts:Apply(subLbl, "Gotham", 11)

	-- Кнопки свернуть/сброс позиции/закрыть
	local closeBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 24, 0, 24),
		BackgroundColor3 = theme.Panel, Text = "×", TextColor3 = theme.SubText, TextSize = 16, AutoButtonColor = false, Parent = titleBar,
	}, { corner(6) })
	local resetBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -40, 0.5, 0), Size = UDim2.new(0, 24, 0, 24),
		BackgroundColor3 = theme.Panel, Text = "⟳", TextColor3 = theme.SubText, TextSize = 14, AutoButtonColor = false, Parent = titleBar,
	}, { corner(6) })
	local minimizeBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -70, 0.5, 0), Size = UDim2.new(0, 24, 0, 24),
		BackgroundColor3 = theme.Panel, Text = "—", TextColor3 = theme.SubText, TextSize = 14, AutoButtonColor = false, Parent = titleBar,
	}, { corner(6) })

	-- Панель вкладок слева
	local tabBar = new("Frame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(0, 140, 1, -48), Parent = main,
	}, { pad(8, 0, 8, 8) })
	listLayout(Enum.FillDirection.Vertical, 4).Parent = tabBar

	-- Контент справа
	local contentHolder = new("Frame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 148, 0, 44), Size = UDim2.new(1, -156, 1, -52), Parent = main,
	})

	makeDraggable(titleBar, main, true)
	makeResizable(main, opts.MinSize or Vector2.new(420, 280), opts.MaxSize or Vector2.new(1100, 800))

	local originalPos = main.Position
	track(resetBtn.MouseButton1Click:Connect(function()
		tween(main, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Position = originalPos })
	end))

	local bubble
	local minimized = false
	track(minimizeBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			main.Visible = false
			bubble = new("TextButton", {
				Size = UDim2.new(0, 46, 0, 46), Position = UDim2.new(0, 20, 0, 20),
				BackgroundColor3 = theme.Panel, Text = "K", TextColor3 = theme.Accent, TextSize = 18, AutoButtonColor = false, Parent = root,
			}, { corner(23), stroke(theme.Accent, 1, 0.4) })
			track(bubble.MouseButton1Click:Connect(function()
				main.Visible = true
				minimized = false
				bubble:Destroy()
			end))
			makeDraggable(bubble, bubble, true)
		end
	end))

	track(closeBtn.MouseButton1Click:Connect(function()
		main.Visible = false
	end))

	self.Theming:OnChanged(function(colors)
		main.BackgroundColor3 = colors.Bg
		windowGlow.Color = colors.Accent
		windowGlow.Enabled = self.Theming:GetGlow()
	end)

	function window:Tab(topts)
		topts = topts or {}
		local tab = setmetatable({}, TabMT)

		local btn = new("TextButton", {
			BackgroundColor3 = theme.Panel, Size = UDim2.new(1, 0, 0, 32), Text = "", AutoButtonColor = false, Parent = tabBar,
		}, { corner(8) })

		local iconOffset = 0
		if topts.Icon and Library.Icons:Get(topts.Icon) then
			iconOffset = 22
			new("ImageLabel", {
				BackgroundTransparency = 1, Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 8, 0.5, -8),
				Image = Library.Icons:Get(topts.Icon), ImageColor3 = theme.SubText, Parent = btn,
			})
		end

		local btnLbl = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, -10 - iconOffset, 1, 0), Position = UDim2.new(0, 10 + iconOffset, 0, 0),
			Text = topts.Name or "Tab", TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Parent = btn,
		})
		Library.Fonts:Apply(btnLbl, "Gotham", 13)

		local activeBar = new("Frame", {
			BackgroundColor3 = theme.Accent, Size = UDim2.new(0, 3, 0, 0), Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5), Parent = btn,
		}, { corner(2) })

		local page = new("ScrollingFrame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Visible = false,
			CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3, ScrollBarImageColor3 = theme.Accent, Parent = contentHolder,
			ClipsDescendants = true,
		})
		local _, densityPad = Library.Theming:GetDensity()
		listLayout(Enum.FillDirection.Vertical, densityPad and densityPad.section or 8).Parent = page
		pad(2, 2, 10, 2).Parent = page

		tab._page = page
		tab._btn = btn
		tab._btnLbl = btnLbl
		tab._activeBar = activeBar

		local function staggerFadeIn()
			-- лёгкая последовательная анимация появления секций внутри вкладки
			local order = 0
			for _, child in ipairs(page:GetChildren()) do
				if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
					order = order + 1
					local delayTime = math.min(order * 0.035, 0.25)
					child.BackgroundTransparency = child.BackgroundTransparency == 1 and 1 or 1
					local origTransp = (child:IsA("Frame") and child.BackgroundTransparency) or nil
					child.Position = child.Position + UDim2.new(0, 0, 0, 6)
					task.delay(delayTime, function()
						if not child.Parent then return end
						tween(child, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
							Position = child.Position - UDim2.new(0, 0, 0, 6),
						})
					end)
				end
			end
		end

		local function activate()
			for _, t in ipairs(window._tabs) do
				t._btn.BackgroundColor3 = theme.Panel
				t._btnLbl.TextColor3 = theme.SubText
				tween(t._activeBar, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = UDim2.new(0, 3, 0, 0) })
				if t._page ~= page then
					t._page.Visible = false
				end
			end
			page.Visible = true
			page.Position = UDim2.new(0, 10, 0, 0)
			page.GroupTransparency = nil
			tween(page, 0.16 * Library.Theming:GetAnimSpeed(), Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Position = UDim2.new(0, 0, 0, 0) })
			btn.BackgroundColor3 = theme.Accent
			btnLbl.TextColor3 = Color3.new(1, 1, 1)
			tween(activeBar, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = UDim2.new(0, 3, 0, 18) })
			staggerFadeIn()
		end

		track(btn.MouseButton1Click:Connect(activate))
		table.insert(window._tabs, tab)
		if #window._tabs == 1 then activate() end

		tab.Activate = activate

		function tab:Section(sopts)
			return createSection(page, sopts)
		end

		-- Accordion — набор секций, где раскрыта только одна (клик по другой закрывает текущую)
		function tab:Accordion()
			local accordion = {}
			local panels = {}
			function accordion:Panel(popts)
				popts = popts or {}
				local userOnCollapse = popts.OnCollapse
				local sec -- объявлена заранее, чтобы замыкание ниже захватило именно эту переменную
				popts = setmetatable({
					OnCollapse = function(isCollapsed)
						if not isCollapsed then
							for _, p in ipairs(panels) do
								if p ~= sec then p._collapsible:SetCollapsed(true, true) end
							end
						end
						safeCallback(userOnCollapse, isCollapsed)
					end,
				}, { __index = popts })
				sec = createSection(page, popts)
				table.insert(panels, sec)
				return sec
			end
			return accordion
		end

		return tab
	end

	-- SetTitle(text) — программно сменить заголовок окна
	function window:SetTitle(text)
		titleLbl.Text = text
	end

	table.insert(self._windows, window)
	return window
end

-- GetWindow(name) — найти ранее созданное окно по Name, переданному в Library:Window({Name=...})
function Library:GetWindow(name)
	for _, w in ipairs(self._windows) do
		if w._name == name then return w end
	end
	return nil
end

-- CloseAll() — скрыть все открытые окна библиотеки
function Library:CloseAll()
	for _, w in ipairs(self._windows) do
		if w._main then w._main.Visible = false end
	end
end

-- ScrollToFlag(flag) — переключает нужную вкладку, скроллит к элементу и коротко подсвечивает его.
-- Полезно вместе с Library:Search(query) для перехода к найденному элементу.
function Library:ScrollToFlag(flag)
	local element = self._elements[flag]
	if not element or not element._inst then return false end
	local inst = element._inst

	for _, window in ipairs(self._windows) do
		for _, tab in ipairs(window._tabs) do
			if inst:IsDescendantOf(tab._page) then
				if tab.Activate then tab.Activate() end
				task.defer(function()
					local targetY = inst.AbsolutePosition.Y - tab._page.AbsolutePosition.Y + tab._page.CanvasPosition.Y
					tween(tab._page, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
						CanvasPosition = Vector2.new(0, math.max(targetY - 20, 0)),
					})
					local theme = self.Theming:Get()
					local hl = new("UIStroke", { Color = theme.Accent, Thickness = 2, Transparency = 0, Parent = inst })
					task.delay(0.9, function() if hl then hl:Destroy() end end)
				end)
				return true
			end
		end
	end
	return false
end

------------------------------------------------------------------
-- НАСТРОЙКИ ГУИ (Settings window)
------------------------------------------------------------------
-- opts: { OnExport, OnImport } — необязательные хуки для сохранения конфигурации
function Library:Settings(opts)
	opts = opts or {}
	local win = self:Window({ Title = "Настройки скрипта", SubTitle = "Внешний вид и поведение GUI", Size = UDim2.new(0, 520, 0, 420) })
	local tab = win:Tab({ Name = "Внешний вид" })
	local sec = tab:Section({ Name = "Тема" })

	sec:Dropdown({
		Name = "Пресет темы",
		Options = self.Theming:List(),
		Default = "Void Purple",
		Callback = function(name) self.Theming:Use(name) end,
	})
	sec:Colorpicker({
		Name = "Акцентный цвет",
		Default = self.Theming:Get().Accent,
		Callback = function(c) self.Theming:SetAccent(c) end,
	})
	sec:Slider({
		Name = "Скругление углов", Min = 0, Max = 20, Default = self.Theming:GetRadius(),
		Callback = function(v) self.Theming:SetRadius(v) end,
	})
	sec:Slider({
		Name = "Толщина бордера", Min = 0, Max = 3, Decimals = 0, Default = self.Theming:GetBorderThickness(),
		Callback = function(v) self.Theming:SetBorderThickness(v) end,
	})
	sec:Toggle({
		Name = "Свечение (glow)", Default = self.Theming:GetGlow(),
		Callback = function(v) self.Theming:SetGlow(v) end,
	})
	sec:Dropdown({
		Name = "Скорость анимаций", Options = { "Slow", "Normal", "Fast" }, Default = "Normal",
		Callback = function(v)
			local map = { Slow = 1.6, Normal = 1.0, Fast = 0.6 }
			self.Theming:SetAnimSpeed(map[v] or 1)
		end,
	})
	sec:Dropdown({
		Name = "Плотность", Options = { "Compact", "Normal", "Comfortable" }, Default = "Normal",
		Callback = function(v) self.Theming:SetDensity(v) end,
	})

	local secFonts = tab:Section({ Name = "Шрифты" })
	secFonts:Dropdown({
		Name = "Шрифт интерфейса",
		Options = self.Fonts:List(),
		Default = self.Fonts:GetDefault(),
		Callback = function(name) self.Fonts:SetDefault(name) end,
	})
	secFonts:Slider({
		Name = "Размер шрифта", Min = 10, Max = 18, Default = 13,
		Callback = function(v) self.Fonts:SetDefault(nil, v) end,
	})
	secFonts:Label({ Text = "Кастомный шрифт: укажи Font Family Asset Id (см. Roblox Font Manager)." })
	local customFontName, customFontId
	secFonts:Textbox({ Name = "Имя шрифта", Placeholder = "MyFont", Callback = function(t) customFontName = t end })
	secFonts:Textbox({ Name = "Asset Id", Placeholder = "rbxassetid://...", Callback = function(t) customFontId = t end })
	secFonts:Button({
		Name = "Зарегистрировать шрифт",
		Callback = function()
			if customFontName and customFontId then
				local ok = self.Fonts:Register(customFontName, customFontId)
				self:Notification({
					Title = ok and "Шрифт добавлен" or "Ошибка",
					Text = ok and customFontName or "Не удалось загрузить шрифт",
					Icon = ok and "success" or "error",
				})
			end
		end,
	})

	local tab2 = win:Tab({ Name = "Поведение" })
	local secBehavior = tab2:Section({ Name = "Общее" })
	secBehavior:Keybind({ Name = "Клавиша открытия меню", Default = Enum.KeyCode.RightShift, Mode = "Toggle" })
	secBehavior:Toggle({ Name = "Открывать меню при инжекте", Default = true })
	secBehavior:Toggle({ Name = "Сворачивать все секции при открытии", Default = false })
	secBehavior:Toggle({ Name = "Показывать лоадер", Default = true })
	secBehavior:Toggle({ Name = "Streamproof по умолчанию", Default = false })
	secBehavior:Dropdown({ Name = "Язык", Options = { "RU", "EN" }, Default = "RU" })

	local secSound = tab2:Section({ Name = "Звук", Icon = "bolt" })
	secSound:Toggle({
		Name = "UI-звуки (клики/тогглы/уведомления)", Default = self.Sounds:GetEnabled(),
		Callback = function(v) self.Sounds:SetEnabled(v) end,
	})
	secSound:Slider({
		Name = "Громкость", Min = 0, Max = 1, Decimals = 2, Default = self.Sounds:GetVolume(),
		Callback = function(v) self.Sounds:SetVolume(v) end,
	})

	local secReset = tab2:Section({ Name = "Сброс и конфиг" })
	secReset:Button({ Name = "Сбросить тему", Callback = function() self.Theming:Use("Void Purple") end })
	secReset:Button({
		Name = "Экспорт UI-конфига",
		Callback = function()
			local data = self.Theming:Export()
			pcall(function() setclipboard(data) end)
			self:Notification({ Title = "Экспортировано", Text = "UI-конфиг скопирован в буфер обмена", Icon = "success" })
			safeCallback(opts.OnExport, data)
		end,
	})
	local importJson = nil
	secReset:Textbox({ Name = "JSON темы", Placeholder = "Вставь экспортированный конфиг...", Callback = function(t) importJson = t end })
	secReset:Button({
		Name = "Импорт UI-конфига",
		Callback = function()
			if not importJson or importJson == "" then return end
			local ok = self.Theming:Import(importJson)
			self:Notification({
				Title = ok and "Импортировано" or "Ошибка",
				Text = ok and "Тема применена" or "Не удалось разобрать конфиг",
				Icon = ok and "success" or "error",
			})
			safeCallback(opts.OnImport, importJson)
		end,
	})

	return win
end

------------------------------------------------------------------
-- РЕДАКТОР БИНДОВ (Keybind Editor)
------------------------------------------------------------------
Library._binds = {} -- { {Name, Flag, Mode, Key, Enabled}, ... }

function Library:KeybindEditor()
	local win = self:Window({ Title = "Редактор биндов", SubTitle = "Управление привязками клавиш", Size = UDim2.new(0, 560, 0, 420) })
	local tab = win:Tab({ Name = "Бинды" })
	local sec = tab:Section({ Name = "Добавить бинд" })

	local nameVal, modeVal = "", "Toggle"
	sec:Textbox({ Name = "Название действия", Placeholder = "Моя фича", Callback = function(t) nameVal = t end })
	sec:Dropdown({ Name = "Режим", Options = { "Toggle", "Hold", "Always" }, Default = "Toggle", Callback = function(v) modeVal = v end })
	local kb = sec:Keybind({ Name = "Клавиша" })

	local list = tab:Section({ Name = "Зарегистрированные бинды" })

	local function refreshList()
		-- пересобираем список наглядно (простая реализация: очищаем и рисуем заново)
		for _, child in ipairs(list._body:GetChildren()) do
			if not child:IsA("UIListLayout") then child:Destroy() end
		end
		local seenKeys = {}
		for _, b in ipairs(Library._binds) do
			local keyName = b.Key and (typeof(b.Key) == "EnumItem" and b.Key.Name or tostring(b.Key)) or "—"
			local conflict = seenKeys[keyName]
			seenKeys[keyName] = true
			local row = new("Frame", { BackgroundColor3 = conflict and Color3.fromRGB(60, 24, 24) or Library.Theming:Get().Bg, Size = UDim2.new(1, 0, 0, 26), Parent = list._body }, { corner(6), pad(8, 0, 8, 0) })
			local lbl = new("TextLabel", {
				BackgroundTransparency = 1, Size = UDim2.new(1, -80, 1, 0),
				Text = ("%s — %s (%s)"):format(b.Name, keyName, b.Mode), TextColor3 = Library.Theming:Get().Text,
				TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, Parent = row,
			})
			Library.Fonts:Apply(lbl, "Gotham", 12)
			local delBtn = new("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 50, 0, 20),
				BackgroundColor3 = Library.Theming:Get().Panel, Text = "Удалить", TextColor3 = Color3.fromRGB(230, 110, 110), TextSize = 11, AutoButtonColor = false, Parent = row,
			}, { corner(5) })
			track(delBtn.MouseButton1Click:Connect(function()
				for i, bb in ipairs(Library._binds) do
					if bb == b then table.remove(Library._binds, i) break end
				end
				refreshList()
			end))
		end
	end

	tab:Section({ Name = "" }) -- spacing placeholder not required; kept minimal
	local addSec = sec
	addSec:Button({
		Name = "Добавить",
		Callback = function()
			local key = select(1, kb:Get())
			if nameVal == "" or not key then
				Library:Notification({ Title = "Ошибка", Text = "Укажите имя и клавишу", Icon = "error" })
				return
			end
			table.insert(Library._binds, { Name = nameVal, Mode = modeVal, Key = key, Enabled = true })
			refreshList()
			Library:Notification({ Title = "Бинд добавлен", Text = nameVal, Icon = "success" })
		end,
	})

	refreshList()
	return win
end

------------------------------------------------------------------
-- CONFIG MANAGER (сохранение/загрузка Library.Flags в файл)
------------------------------------------------------------------
local ConfigManager = {}
ConfigManager.__index = ConfigManager

function ConfigManager.new(folder)
	local self = setmetatable({}, ConfigManager)
	self._folder = folder or "KrakenUI/configs"
	self._hasFS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
	if self._hasFS and type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(self._folder) then
		pcall(makefolder, self._folder)
	end
	return self
end

function ConfigManager:_path(name)
	return self._folder .. "/" .. name .. ".json"
end

function ConfigManager:Save(name)
	if not self._hasFS then
		warn("[KrakenUI.Config] executor не поддерживает файловую систему")
		return false
	end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, Library.Flags)
	if not ok then
		warn("[KrakenUI.Config] ошибка кодирования: " .. tostring(encoded))
		return false
	end
	local writeOk = pcall(writefile, self:_path(name), encoded)
	return writeOk
end

function ConfigManager:Load(name)
	if not self._hasFS then return false end
	local ok, data = pcall(readfile, self:_path(name))
	if not ok then return false end
	local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, data)
	if not decodeOk then return false end
	for flag, value in pairs(decoded) do
		Library.Flags[flag] = value
		local element = Library._elements[flag]
		if element and element.Set then
			pcall(function() element:Set(value, false) end)
		end
	end
	return true
end

function ConfigManager:List()
	if not self._hasFS or type(listfiles) ~= "function" then return {} end
	local ok, files = pcall(listfiles, self._folder)
	if not ok then return {} end
	local names = {}
	for _, path in ipairs(files) do
		local name = path:match("([^/\\]+)%.json$")
		if name then table.insert(names, name) end
	end
	table.sort(names)
	return names
end

function ConfigManager:Delete(name)
	if not self._hasFS or type(delfile) ~= "function" then return false end
	return pcall(delfile, self:_path(name))
end

Library.Config = ConfigManager.new()

------------------------------------------------------------------
-- WATERMARK (компактная плашка со статус-текстом, не привязана к конкретным фичам)
------------------------------------------------------------------
-- opts: { Text, UpdateInterval, UpdateFn = function() -> string }
function Library:Watermark(opts)
	opts = opts or {}
	local theme = self.Theming:Get()
	local root = ensureRoot()

	local frame = new("Frame", {
		BackgroundColor3 = theme.Panel, Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(0, 220, 0, 26),
		Parent = root,
	}, { corner(8), stroke(theme.Accent, 1, 0.6), pad(10, 0, 10, 0) })

	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
		Text = opts.Text or "KrakenUI", TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, Parent = frame,
	})
	Library.Fonts:Apply(lbl, "Code", 12)

	makeDraggable(frame, frame, true)

	local handle = {}
	function handle:Update(text)
		lbl.Text = text
	end
	function handle:Destroy()
		frame:Destroy()
	end

	if opts.UpdateFn then
		task.spawn(function()
			while frame.Parent do
				local ok, text = pcall(opts.UpdateFn)
				if ok and text then lbl.Text = text end
				task.wait(opts.UpdateInterval or 1)
			end
		end)
	end

	return handle
end

------------------------------------------------------------------
-- ANNOUNCEMENT (закрепляемый баннер сверху экрана — для апдейтов/важных сообщений;
-- в отличие от Notification не исчезает сама, пока не закрыта или не задан Duration)
------------------------------------------------------------------
-- opts: { Title, Text, Icon, Dismissible = true, Duration, OnDismiss }
function Library:Announcement(opts)
	opts = opts or {}
	local theme = self.Theming:Get()
	local root = ensureRoot()

	local bar = new("Frame", {
		BackgroundColor3 = theme.Panel, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.new(0, 420, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, ZIndex = 700, Parent = root,
	}, { corner(10), stroke(theme.Accent, 1, 0.5), pad(12, 8, 12, 8) })

	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 701, Parent = bar })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = row

	if opts.Icon and Library.Icons:Get(opts.Icon) then
		new("ImageLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(0, 18, 0, 18), Image = Library.Icons:Get(opts.Icon),
			ImageColor3 = theme.Accent, ZIndex = 701, Parent = row,
		})
	end

	local textCol = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -50, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 701, Parent = row })
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = textCol

	if opts.Title then
		local t = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Text = opts.Title, TextColor3 = theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, ZIndex = 701, Parent = textCol,
		})
		Library.Fonts:Apply(t, "Gotham Bold", 13)
	end
	if opts.Text then
		local b = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
			Text = opts.Text, TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, ZIndex = 701, Parent = textCol,
		})
		Library.Fonts:Apply(b, "Gotham", 12)
	end

	local handle = {}
	local dismissed = false
	function handle:Dismiss()
		if dismissed or not bar.Parent then return end
		dismissed = true
		local t = tween(bar, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { BackgroundTransparency = 1 })
		t.Completed:Wait()
		bar:Destroy()
		safeCallback(opts.OnDismiss)
	end

	if opts.Dismissible ~= false then
		local closeBtn = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 18, 0, 18),
			BackgroundTransparency = 1, Text = "×", TextColor3 = theme.SubText, TextSize = 16, ZIndex = 701, Parent = row,
		})
		track(closeBtn.MouseButton1Click:Connect(function() handle:Dismiss() end))
	end

	if opts.Duration then
		task.delay(opts.Duration, function() handle:Dismiss() end)
	end

	tween(bar, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundTransparency = 0 })

	return handle
end

------------------------------------------------------------------
-- KEYBIND LIST (отображает переданный список активных биндов; данные подаёт вызывающий код)
------------------------------------------------------------------
-- opts: { Title }
function Library:KeybindList(opts)
	opts = opts or {}
	local theme = self.Theming:Get()
	local root = ensureRoot()

	local frame = new("Frame", {
		BackgroundColor3 = theme.Panel, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.new(0, 200, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = root,
	}, { corner(8), stroke(theme.Accent, 1, 0.6), pad(10, 8, 10, 8) })

	local title = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
		Text = opts.Title or "Активные бинды", TextColor3 = theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 11, Parent = frame,
	})
	Library.Fonts:Apply(title, "Gotham Bold", 11)

	local list = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = frame })
	listLayout(Enum.FillDirection.Vertical, 2).Parent = list

	makeDraggable(frame, frame, true)

	local handle = {}
	-- entries: { {Name = "Feature", Key = "E"}, ... }
	function handle:Refresh(entries)
		for _, c in ipairs(list:GetChildren()) do
			if not c:IsA("UIListLayout") then c:Destroy() end
		end
		for i, e in ipairs(entries or {}) do
			local row = new("TextLabel", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = i,
				Text = ("%s [%s]"):format(e.Name, e.Key), TextColor3 = theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, Parent = list,
			})
			Library.Fonts:Apply(row, "Code", 12)
		end
	end
	function handle:Destroy()
		frame:Destroy()
	end

	return handle
end

------------------------------------------------------------------
-- ГЛОБАЛЬНЫЙ ПОИСК ПО ФЛАГАМ/ИМЕНАМ ЭЛЕМЕНТОВ
------------------------------------------------------------------
-- Возвращает список найденных флагов (простая подстрока без учёта регистра).
-- Полноценная подсветка/переход по вкладкам делается вызывающим кодом через
-- Library._elements[flag], т.к. у элементов нет привязки к своему Tab в этой версии.
function Library:Search(query)
	query = (query or ""):lower()
	if query == "" then return {} end
	local results = {}
	for flag in pairs(self._elements) do
		if tostring(flag):lower():find(query, 1, true) then
			table.insert(results, flag)
		end
	end
	table.sort(results)
	return results
end

------------------------------------------------------------------
-- ЭКСПОРТ
------------------------------------------------------------------
return Library
