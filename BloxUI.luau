--!nonstrict
--[[
	BloxUI — A fork and rewrite of VibeUI
	Single-file library. See README.md for usage and API documentation.
]]

if shared.BloxUI then
	pcall(function() shared.BloxUI:Unload() end)
end

local LoadStart = os.clock()

--==============================================================================
-- Services
--==============================================================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local GuiService       = game:GetService("GuiService")
local Lighting         = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

--==============================================================================
-- Executor shims (degrade gracefully off-executor)
--==============================================================================

local cloneref       = cloneref
local gethui         = gethui
local getgenv        = getgenv
local getcustomasset = getcustomasset -- sUNC standard (legacy getsynasset alias dropped)
local function httpget(url: string): string
	return game:HttpGet(url)
end

local isfile, isfolder, makefolder = isfile, isfolder, makefolder
local writefile, readfile          = writefile, readfile
local listfiles, delfile           = listfiles, delfile

local HasFileSystem = (isfile and isfolder and makefolder and writefile and readfile and listfiles) and true or false

local function GetParentGui(): Instance
	local ok, hui = pcall(function()
		if gethui then return gethui() end
		local cg = game:GetService("CoreGui")
		return cloneref and cloneref(cg) or cg
	end)
	if ok and hui then return hui end
	-- Studio / no-executor fallback
	return LocalPlayer:WaitForChild("PlayerGui")
end

--==============================================================================
-- Types
--==============================================================================

export type Theme = { [string]: Color3 }

export type WindowConfig = {
	Title: string?,
	Logo: string?,
	Size: UDim2?,
	FadeTime: number?,
	Resizable: boolean?,
	Keybind: Enum.KeyCode?,
	FeatureSearch: boolean?,
	Layout: string?,
}

export type TabConfig = {
	Name: string?,
	Columns: number?,
	Order: number?,
}

export type SettingsPageConfig = {
	Name: string?,
	Columns: number?,
	Order: number?,
	SettingsPosition: string?,
}

export type ToggleConfig = {
	Name: string?,
	Flag: string?,
	Default: boolean?,
	Tooltip: string?,
	Callback: ((value: boolean) -> ())?,
}

export type SliderConfig = {
	Name: string?,
	Flag: string?,
	Min: number?,
	Max: number?,
	Default: number?,
	Decimals: number?,
	Suffix: string?,
	Tooltip: string?,
	Callback: ((value: number) -> ())?,
}

export type DropdownConfig = {
	Name: string?,
	Flag: string?,
	Items: { string }?,
	Default: (string | { string })?,
	Multi: boolean?,
	Search: boolean?,
	Tooltip: string?,
	Callback: ((value: any) -> ())?,
}

--==============================================================================
-- Config / presets
--==============================================================================

local Config = {
	Folder    = "BloxUI",
	FadeSpeed = 0.18,
	Tween = {
		Time      = 0.18,
		Style     = Enum.EasingStyle.Quad,
		Direction = Enum.EasingDirection.Out,
	},
	MenuKeybind  = Enum.KeyCode.RightControl,
	-- Default to the real system cursor: a script-drawn cursor visibly drifts
	-- from the OS pointer (which drives hover hit-testing) whenever the game
	-- renders below native resolution or under display scaling. Opt-in only.
	CustomCursor = false,
	Rounded      = false,
	Outlines     = true, -- element border outlines (toggle off for a flatter look)
	NotificationSide = "BottomRight", -- BottomRight | BottomLeft | TopRight | TopLeft
	NotificationDuration = 5, -- default seconds a toast stays on screen
	NotificationSound = "rbxassetid://9080003278", -- played on each toast ("" to disable)
	Transparency = 0, -- 0 = opaque, 1 = fully see-through
	Scale        = 1, -- global UI scale
	FeatureSearch = false, -- enable feature search in new windows
	MobileToggle = true, -- show a floating open/close button on touch devices
	GlowIntensity = 0, -- neon glow on accent bars (sliders, progress): 0 = off (opt-in), 1 = max
	Glass         = false, -- glassmorphism: blur the game world behind translucent UI
	GlassBlur     = 18,    -- BlurEffect size while glass mode + menu are active
	GlassTransparency = 0.18, -- minimum surface translucency in glass mode
	StreamProof   = false, -- best-effort: hide the UI from screen capture (executor-dependent)
}

local Folders = {
	Root    = Config.Folder,
	Configs = Config.Folder .. "/Configs",
	Assets  = Config.Folder .. "/Assets",
}
local ConfigControlFlags = {
	DeviceMode = true, __AutoLoad = true,
	ConfigList = true, ConfigName = true, ConfigJSON = true,
}

-- // Profiles are basenames, never paths into another game's config directory. \\ --
local function validConfigName(name)
	return type(name) == "string" and name ~= "" and name ~= "None" and #name <= 120
		and name:lower() ~= "__bloxui_metadata"
		and name:lower() ~= "__bloxui_metadata.json"
		and name ~= "." and name ~= ".." and not name:find("/", 1, true)
		and not name:find("\\", 1, true) and not name:find('[<>:"|?*]')
		and not name:find("%c") and not name:match("^%s") and not name:match("[%s%.]$")
end

local function configFileExists(path)
	local ok, exists = pcall(isfile, path)
	return ok and exists == true
end

local function readConfigFile(path)
	if not configFileExists(path) then return nil end
	local ok, raw = pcall(readfile, path)
	return ok and type(raw) == "string" and raw or nil
end

local Presets: { [string]: Theme } = {
	["Bloxxer Blue"] = {
		["Outline"] = Color3.fromRGB(44, 44, 56),
		["Page Background"] = Color3.fromRGB(13, 13, 13),
		["Text"] = Color3.fromRGB(235, 235, 235),
		["Border"] = Color3.fromRGB(16, 14, 14),
		["Inline"] = Color3.fromRGB(16, 16, 16),
		["Hovered Element"] = Color3.fromRGB(26, 26, 26),
		["Text Stroke"] = Color3.fromRGB(0, 0, 0),
		["Gradient"] = Color3.fromRGB(208, 208, 208),
		["Placeholder Text"] = Color3.fromRGB(185, 185, 185),
		["Background"] = Color3.fromRGB(16, 16, 16),
		["Element"] = Color3.fromRGB(40, 40, 43),
		["Accent"] = Color3.fromRGB(180, 217, 255),
	},
	["Midnight"] = {
		Background       = Color3.fromRGB(14, 17, 15),
		Border           = Color3.fromRGB(12, 12, 12),
		Inline           = Color3.fromRGB(20, 24, 21),
		["Hovered Element"] = Color3.fromRGB(37, 42, 45),
		["Page Background"] = Color3.fromRGB(25, 30, 26),
		Outline          = Color3.fromRGB(42, 49, 45),
		Element          = Color3.fromRGB(30, 36, 31),
		Gradient         = Color3.fromRGB(208, 208, 208),
		Text             = Color3.fromRGB(235, 235, 235),
		["Text Stroke"]  = Color3.fromRGB(0, 0, 0),
		["Placeholder Text"] = Color3.fromRGB(185, 185, 185),
		Accent           = Color3.fromRGB(202, 243, 255),
	},
	["Crimson"] = {
		Background       = Color3.fromRGB(17, 14, 15),
		Border           = Color3.fromRGB(12, 12, 12),
		Inline           = Color3.fromRGB(24, 20, 21),
		["Hovered Element"] = Color3.fromRGB(45, 37, 40),
		["Page Background"] = Color3.fromRGB(30, 25, 26),
		Outline          = Color3.fromRGB(49, 42, 44),
		Element          = Color3.fromRGB(36, 30, 31),
		Gradient         = Color3.fromRGB(208, 208, 208),
		Text             = Color3.fromRGB(235, 235, 235),
		["Text Stroke"]  = Color3.fromRGB(0, 0, 0),
		["Placeholder Text"] = Color3.fromRGB(185, 185, 185),
		Accent           = Color3.fromRGB(255, 105, 120),
	},
	["Indigo"] = {
		Background       = Color3.fromRGB(15, 15, 19),
		Border           = Color3.fromRGB(12, 12, 12),
		Inline           = Color3.fromRGB(21, 21, 27),
		["Hovered Element"] = Color3.fromRGB(40, 40, 52),
		["Page Background"] = Color3.fromRGB(26, 26, 33),
		Outline          = Color3.fromRGB(44, 44, 56),
		Element          = Color3.fromRGB(31, 31, 40),
		Gradient         = Color3.fromRGB(208, 208, 208),
		Text             = Color3.fromRGB(235, 235, 235),
		["Text Stroke"]  = Color3.fromRGB(0, 0, 0),
		["Placeholder Text"] = Color3.fromRGB(185, 185, 185),
		Accent           = Color3.fromRGB(150, 160, 255),
	},
}

--==============================================================================
-- Library skeleton (forward-declared so components can use it)
--==============================================================================

local Library = {
	Flags     = {},   -- flag -> value
	_setters  = {},   -- flag -> function(value)
	_windows  = {},   -- created windows (for saving/restoring position)
	Theme     = {},   -- live theme value table (filled below)
	KeyList   = nil,
	Config    = Config, -- exposed so users can tweak options before building the window
}
Library.__index = Library

-- // Device choice is shared with the hub loader; only the override is persisted. \\ --
local function detectDeviceMode(inputService)
	local preferred
	pcall(function() preferred = inputService.PreferredInput.Name end)
	if preferred == "Touch" then return "Mobile" end
	if preferred == "KeyboardAndMouse" then return "PC" end
	return inputService.TouchEnabled and (not inputService.KeyboardEnabled or not inputService.MouseEnabled)
		and "Mobile" or "PC"
end

local function validDevicePreference(value)
	return value == "Auto" or value == "Mobile" or value == "PC"
end

local function loadDeviceProfile(env)
	local device = type(env.__BloxUIDevice) == "table" and env.__BloxUIDevice or {}
	local preference = device.Preference
	if not validDevicePreference(preference) and type(readfile) == "function" then
		pcall(function()
			if type(isfile) == "function" and not isfile("BloxUI/Device.json") then return end
			local json = readfile("BloxUI/Device.json")
			if type(json) ~= "string" or #json > 1024 then return end
			local saved = HttpService:JSONDecode(json)
			if type(saved) == "table" and saved.schema_version == 1 and validDevicePreference(saved.preference) then
				preference = saved.preference
			end
		end)
	end
	device.Preference = validDevicePreference(preference) and preference or "Auto"
	device.Detected = detectDeviceMode(UserInputService)
	device.Mode = device.Preference == "Auto" and device.Detected or device.Preference
	env.__BloxUIDevice = device
	return device
end

local function saveDevicePreference(preference)
	if type(writefile) ~= "function" then return false end
	return pcall(function()
		if type(makefolder) == "function" then
			if type(isfolder) ~= "function" or not isfolder("BloxUI") then pcall(makefolder, "BloxUI") end
		end
		writefile("BloxUI/Device.json", HttpService:JSONEncode({ schema_version = 1, preference = preference }))
	end)
end

local Device = loadDeviceProfile(getgenv and getgenv() or shared)
local DeviceRefreshers = {}
Library.Device = Device

function Library:GetDeviceMode()
	return Device.Mode
end

local function matchesGesture(input, origin)
	if origin.UserInputType == Enum.UserInputType.Touch then return input == origin end
	return input.UserInputType == Enum.UserInputType.MouseMovement
end

local function computeWindowGeometry(viewport, size, position, scale)
	scale = math.clamp(scale, 0.5, 2)
	local width = math.clamp(size.X, 1, math.max(1, (viewport.X - 24) / scale))
	local height = math.clamp(size.Y, 1, math.max(1, (viewport.Y - 24) / scale))
	local x = math.clamp(position.X, width * scale / 2 + 12, math.max(width * scale / 2 + 12, viewport.X - width * scale / 2 - 12))
	local y = math.clamp(position.Y, height * scale / 2 + 12, math.max(height * scale / 2 + 12, viewport.Y - height * scale / 2 - 12))
	return Vector2.new(width, height), Vector2.new(x, y)
end

local function reflowSections(columns, sections, compact)
	for index, column in columns do column.Visible = not compact or index == 1 end
	for _, entry in sections do
		entry.frame.Parent = columns[compact and 1 or entry.side]
		entry.frame.LayoutOrder = entry.order
	end
end

--==============================================================================
-- Maid — central cleanup
--==============================================================================

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:GiveTask(task)
	table.insert(self._tasks, task)
	return task
end

function Maid:Clean()
	local tasks = self._tasks
	self._tasks = {}
	for _, t in tasks do
		local tt = typeof(t)
		if tt == "RBXScriptConnection" then
			t:Disconnect()
		elseif tt == "Instance" then
			t:Destroy()
		elseif tt == "function" then
			pcall(t)
		elseif tt == "thread" then
			pcall(task.cancel, t)
		elseif type(t) == "table" and type(t.Clean) == "function" then
			t:Clean()
		end
	end
end

local LibMaid = Maid.new()

-- Writing into the protected UI container (gethui()/CoreGui) needs the executor's identity.
-- Engine-dispatched callbacks (tween completions, UserInputService, RenderStepped, task.delay)
-- can arrive on a thread that lost it, and the identity can READ unchanged while the capability
-- is already gone — so re-assert unconditionally rather than testing the number first. No-op when
-- set/getthreadidentity are absent (off-executor / non-sUNC), so the library still runs there.
local BASE_IDENTITY = 8
pcall(function()
	if getthreadidentity then
		local cur = getthreadidentity()
		if type(cur) == "number" and cur > BASE_IDENTITY then BASE_IDENTITY = cur end
	end
end)
local function keepCapability()
	if setthreadidentity then pcall(setthreadidentity, BASE_IDENTITY) end
end

--==============================================================================
-- Input manager — single global dispatch (fixes connection accumulation)
--==============================================================================

local Input = {} do
	local listeners = { Began = {}, Changed = {}, Ended = {} }
	-- Reused snapshot buffer (UIS input isn't dispatched re-entrantly, so one buffer
	-- is safe). Snapshotting first lets a handler add/remove listeners mid-dispatch
	-- without corrupting the `pairs` traversal — for ALL kinds, not just Changed.
	local snapBuf = {}

	local function fire(kind, input, gpe)
		keepCapability() -- re-assert identity once per event: covers Changed here + the task.spawn'd Began/Ended
		local n = 0
		for fn in listeners[kind] do n += 1; snapBuf[n] = fn end
		if kind == "Changed" then
			-- High-frequency (every frame the pointer moves); handlers are internal,
			-- non-yielding (drag, slider, tooltip, cursor) — call directly, no thread.
			for i = 1, n do
				local ok, err = pcall(snapBuf[i], input, gpe)
				if not ok then warn("[BloxUI] input handler error: " .. tostring(err)) end
				snapBuf[i] = nil
			end
		else
			-- Began/Ended fire user keybind callbacks, which may yield — isolate each.
			for i = 1, n do
				task.spawn(snapBuf[i], input, gpe)
				snapBuf[i] = nil
			end
		end
	end

	function Input.Init()
		LibMaid:GiveTask(UserInputService.InputBegan:Connect(function(i, g) fire("Began", i, g) end))
		LibMaid:GiveTask(UserInputService.InputChanged:Connect(function(i, g) fire("Changed", i, g) end))
		LibMaid:GiveTask(UserInputService.InputEnded:Connect(function(i, g) fire("Ended", i, g) end))
	end

	--- Subscribe to a global input event. Returns a disconnect function.
	function Input.On(kind: string, fn): () -> ()
		listeners[kind][fn] = true
		return function() listeners[kind][fn] = nil end
	end

	function Input.isPrimary(input): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end

	function Input.isMove(input): boolean
		return input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
	end
end

--==============================================================================
-- Theme manager
--==============================================================================

local Theme = {} do
	Theme.Values = Library.Theme

	-- Registry indexed for fast lookups instead of one flat array scanned linearly:
	--   byInst[inst][prop] = entry   → O(props) Retag / Untag (called on every hover)
	--   byKey[key][entry]  = true    → O(matches) Set for a single colour (live recolor)
	--   funcEntries[entry] = true    → function refs, re-resolved on any Set
	-- entry = { inst=, prop=, ref= }
	local byInst, byKey, funcEntries = {}, {}, {}
	Theme.Registry = byInst -- exposed for debugging

	for k, v in Presets["Bloxxer Blue"] do
		Theme.Values[k] = v
	end

	--- A function theme value that declares which keys it reads, so Theme.Set(key)
	--- only re-resolves it when `key` is one of its deps (avoids re-running every
	--- gradient closure on every colour change). Usage: ThemeTag = { Color = Theme.Fn({"Gradient"}, fn) }.
	function Theme.Fn(deps, resolver)
		local set = {}
		for _, k in deps do set[k] = true end
		return { __themefn = true, deps = set, resolver = resolver }
	end
	local function isFn(ref)
		return type(ref) == "function" or (type(ref) == "table" and ref.__themefn)
	end

	function Theme.Resolve(ref)
		if type(ref) == "table" and ref.__themefn then return ref.resolver() end
		if type(ref) == "function" then return ref() end
		return Theme.Values[ref]
	end

	local function attach(entry)
		if isFn(entry.ref) then
			funcEntries[entry] = true
		else
			local s = byKey[entry.ref]
			if not s then s = {}; byKey[entry.ref] = s end
			s[entry] = true
		end
	end
	local function detach(entry)
		if isFn(entry.ref) then
			funcEntries[entry] = nil
		else
			local s = byKey[entry.ref]
			if s then s[entry] = nil end
		end
	end
	local function dropEntry(entry) -- fully forget one (inst,prop)
		detach(entry)
		local bi = byInst[entry.inst]
		if bi then
			bi[entry.prop] = nil
			if next(bi) == nil then byInst[entry.inst] = nil end
		end
	end

	--- Register instance properties to follow a theme key (string) or function.
	function Theme.Tag(inst: Instance, map)
		local bi = byInst[inst]
		if not bi then bi = {}; byInst[inst] = bi end
		for prop, ref in map do
			local entry = bi[prop]
			if entry then detach(entry) else entry = { inst = inst, prop = prop }; bi[prop] = entry end
			entry.ref = ref
			attach(entry)
			pcall(function() inst[prop] = Theme.Resolve(ref) end)
		end
	end

	--- Re-point an already-themed property to a new key WITHOUT setting the value
	--- — callers animate the change with Tween.To, and a later Theme.Set on the
	--- new key keeps tracking it.
	function Theme.Retag(inst: Instance, map)
		local bi = byInst[inst]
		if not bi then return end
		for prop, ref in map do
			local entry = bi[prop]
			if entry then detach(entry); entry.ref = ref; attach(entry) end
		end
	end

	--- Forget every entry for an instance (called when it is destroyed).
	function Theme.Untag(inst: Instance)
		local bi = byInst[inst]
		if not bi then return end
		for _, entry in bi do detach(entry) end
		byInst[inst] = nil
	end

	local function apply(entry)
		local ok = pcall(function() entry.inst[entry.prop] = Theme.Resolve(entry.ref) end)
		if not ok then dropEntry(entry) end -- prune destroyed instances
	end

	--- Change a theme color live across the whole UI.
	function Theme.Set(key: string, color: Color3)
		Theme.Values[key] = color
		local s = byKey[key]
		if s then for entry in s do apply(entry) end end
		for entry in funcEntries do
			local ref = entry.ref
			-- bare fn (undeclared deps) → always; declared themefn → only if it reads `key`
			if type(ref) ~= "table" or ref.deps[key] then apply(entry) end
		end
	end

	--- Apply a whole theme in one pass (cheaper than Set per key).
	function Theme.Load(t: Theme)
		for k, v in t do Theme.Values[k] = v end
		for k in t do
			local s = byKey[k]
			if s then for entry in s do apply(entry) end end
		end
		for entry in funcEntries do
			local ref = entry.ref
			if type(ref) ~= "table" then apply(entry)
			else
				for k in t do if ref.deps[k] then apply(entry); break end end
			end
		end
	end
end

--==============================================================================
-- Tween helpers
--==============================================================================

local Tween = {} do
	local TRANS = {
		Frame          = { "BackgroundTransparency" },
		TextLabel      = { "TextTransparency", "BackgroundTransparency" },
		TextButton     = { "TextTransparency", "BackgroundTransparency" },
		TextBox        = { "TextTransparency", "BackgroundTransparency" },
		ImageLabel     = { "BackgroundTransparency", "ImageTransparency" },
		ImageButton    = { "BackgroundTransparency", "ImageTransparency" },
		ScrollingFrame = { "BackgroundTransparency", "ScrollBarImageTransparency" },
		UIStroke       = { "Transparency" },
	}

	local ShownCache = setmetatable({}, { __mode = "k" })

	--- Update the cached "visible" value so fades animate to the new target
	--- (used by the global UI-transparency feature and stateful elements).
	function Tween.SetShown(inst: Instance, prop: string, value: number)
		local t = ShownCache[inst]
		if not t then t = {}; ShownCache[inst] = t end
		t[prop] = value
	end

	local function info(timeOverride, styleOverride, dirOverride)
		return TweenInfo.new(
			timeOverride or Config.Tween.Time,
			styleOverride or Config.Tween.Style,
			dirOverride or Config.Tween.Direction
		)
	end
	Tween.Info = info

	--- Tween an instance to a goal. Returns the Tween object.
	function Tween.To(inst: Instance, goal, tweenInfo: TweenInfo?): Tween
		local t = TweenService:Create(inst, tweenInfo or info(), goal)
		t:Play()
		return t
	end

	-- O(1) ClassName lookup (all fade-able instances are concrete classes, no
	-- subclassing) instead of a linear IsA scan per descendant on every fade.
	function Tween.PropsFor(inst): { string }?
		return TRANS[inst.ClassName]
	end

	--- Fade every fade-able descendant of `root` in/out. Returns last tween.
	--- On fade-OUT we snapshot each property's CURRENT value (so it reflects the
	--- element's live state, e.g. a ticked checkbox); fade-IN animates back to
	--- that snapshot. This fixes stateful elements blanking after a tab switch.
	function Tween.Fade(root: Instance, visible: boolean, speed: number?): Tween?
		local i = info(speed or Config.FadeSpeed)
		local list = root:GetDescendants()
		table.insert(list, root)
		local last: Tween? = nil
		for _, inst in list do
			local props = Tween.PropsFor(inst)
			if not props then continue end
			local cache = ShownCache[inst]
			for _, prop in props do
				if visible then
					-- always restore from the snapshot if we have one; never read the
					-- current value (it may be mid-fade-out, which would lock in a
					-- half-transparent target and blank the tab). Stateful elements
					-- (e.g. toggle ticks) keep the snapshot current via Tween.SetShown.
					local target = (cache and cache[prop] ~= nil) and cache[prop] or inst[prop]
					inst[prop] = 1
					last = TweenService:Create(inst, i, { [prop] = target })
					last:Play()
				else
					if not cache then cache = {}; ShownCache[inst] = cache end
					if cache[prop] == nil then
						cache[prop] = inst[prop] -- snapshot the visible value once
					end
					last = TweenService:Create(inst, i, { [prop] = 1 })
					last:Play()
				end
			end
		end
		return last
	end
end

--==============================================================================
-- Instance factory + small UI helpers
--==============================================================================

-- Tracked surfaces/strokes, keyed by instance so removal is O(1) and a destroyed
-- element prunes itself (via Destroying) instead of lingering until a lazy sweep.
local Surfaces: { [Instance]: number } = {}            -- inst -> opaque base transparency
local BorderStrokes: { [Instance]: { base: number, parent: Instance, border: number } } = {}

-- Drop a destroyed instance from every registry it might be in.
local function untrack(inst: Instance)
	Surfaces[inst] = nil
	BorderStrokes[inst] = nil
	Theme.Untag(inst)
end

--- Create an instance. `props.ThemeTag = {Prop = "Key"|fn}` auto-registers theme.
local function Create(class: string, props, children: { Instance }?): any
	local inst = Instance.new(class)
	local themeTag = props.ThemeTag
	props.ThemeTag = nil
	local solid = props.Solid -- Solid=true opts this surface OUT of the glass/global transparency pass
	props.Solid = nil
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		inst[k] = v
	end
	local tracked = false
	-- track opaque surfaces so they can be made see-through globally
	-- (GuiObjects all have BackgroundTransparency; avoids a pcall per instance)
	if inst:IsA("GuiObject") then
		local bt = inst.BackgroundTransparency
		if bt < 1 and not solid then
			Surfaces[inst] = bt
			tracked = true
			if Config.Transparency and Config.Transparency > 0 then
				inst.BackgroundTransparency = bt + (1 - bt) * Config.Transparency
			end
		end
	end
	if themeTag then
		Theme.Tag(inst, themeTag)
		tracked = true
	end
	-- auto-prune from the registries when destroyed (covers themed strokes too,
	-- which Stroke() adds to BorderStrokes after this returns)
	if tracked then
		inst.Destroying:Once(function() untrack(inst) end)
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local GetFont -- forward-declared; resolves the loaded custom font or a fallback

local function Stroke(parent: Instance, key: string?, transparency: number?): Instance
	local s = Create("UIStroke", {
		Parent = parent,
		Thickness = 1,
		Transparency = transparency or 0,
		LineJoinMode = Enum.LineJoinMode.Miter,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		ThemeTag = { Color = key or "Outline" },
	})
	local border = parent:IsA("GuiObject") and parent.BorderSizePixel or 0
	BorderStrokes[s] = { base = transparency or 0, parent = parent, border = border }
	if not Config.Outlines then
		s.Transparency = 1
		if parent:IsA("GuiObject") then parent.BorderSizePixel = 0 end
	end
	return s
end

local function TextStroke(parent: Instance): Instance
	return Create("UIStroke", {
		Parent = parent,
		Thickness = 1,
		Transparency = 0.35,
		LineJoinMode = Enum.LineJoinMode.Miter,
		ThemeTag = { Color = "Text Stroke" },
	})
end

local function Corner(parent: Instance, radius: number?)
	if not Config.Rounded then return end
	Create("UICorner", { Parent = parent, CornerRadius = UDim.new(0, radius or 4) })
end

-- Neon glow for accent bars (slider fills, progress bars). A soft 9-slice glow
-- image, tinted to the accent, stretched over the bar. Intensity (Config.Glow-
-- Intensity, 0..1) drives its transparency and is adjustable live from Settings.
local GLOW_IMAGE = "rbxassetid://5028857084"
local GLOW_SLICE = Rect.new(24, 24, 232, 232)
local Glows: { [Instance]: boolean } = {} -- glow image -> true (for live intensity)
local function glowTransparency(): number
	return 1 - math.clamp(Config.GlowIntensity or 0, 0, 1) * 0.85
end
--- Add a glow that tracks `bar` (a child of it, slightly larger for the bloom).
local function addGlow(bar: GuiObject): Instance
	local glow = Create("ImageLabel", {
		Parent = bar,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 20, 1, 16), -- spill past the bar so the bloom shows
		Image = GLOW_IMAGE,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = GLOW_SLICE,
		ImageColor3 = Color3.fromRGB(202, 243, 255),
		ImageTransparency = glowTransparency(),
		ZIndex = (bar.ZIndex or 1) + 1,
		ThemeTag = { ImageColor3 = "Accent" },
	})
	Glows[glow] = true
	glow.Destroying:Once(function() Glows[glow] = nil end)
	return glow
end
local function ApplyGlowIntensity(n: number)
	Config.GlowIntensity = math.clamp(n, 0, 1)
	local t = glowTransparency()
	for glow in Glows do
		if not pcall(function() glow.ImageTransparency = t end) then Glows[glow] = nil end
	end
end

-- GetMouseLocation() is full-screen (includes the topbar inset), but our GUIs
-- live under an IgnoreGuiInset=false ScreenGui whose AbsolutePosition is measured
-- in the inset-excluded space. Subtract the inset so mouse↔AbsolutePosition math
-- (colorpicker palette, sliders, hover hit-tests) lines up with the rendered UI.
local function MousePos(): Vector2
	return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
end

-- Position from an actual input event (works for both mouse and touch), mapped
-- into AbsolutePosition space. Falls back to the mouse location.
local function InputPos(input): Vector2
	if input and input.Position then
		return Vector2.new(input.Position.X, input.Position.Y) - GuiService:GetGuiInset()
	end
	return MousePos()
end


local function isMouseOver(gui: Instance, input): boolean
	local mp = input and InputPos(input) or MousePos()
	local p, s = gui.AbsolutePosition, gui.AbsoluteSize
	return mp.X >= p.X and mp.X <= p.X + s.X and mp.Y >= p.Y and mp.Y <= p.Y + s.Y
end

local function MakeText(parent: Instance, text: string, props): TextLabel
	props = props or {}
	props.Parent = parent
	props.FontFace = props.FontFace or GetFont()
	props.Text = text
	props.TextSize = props.TextSize or 13
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.TextColor3 = props.TextColor3 or Theme.Values.Text
	props.ThemeTag = props.ThemeTag or { TextColor3 = "Text" }
	local label = Create("TextLabel", props)
	TextStroke(label)
	return label
end

-- Highlight a text input's border (accent) while it's focused, so it's obvious
-- which field is active / editable.
local function FocusHighlight(box: TextBox, stroke: Instance, maid)
	maid:GiveTask(box.Focused:Connect(function()
		Theme.Retag(stroke, { Color = "Accent" })
		Tween.To(stroke, { Color = Theme.Values.Accent, Transparency = 0 })
	end))
	maid:GiveTask(box.FocusLost:Connect(function()
		Theme.Retag(stroke, { Color = "Outline" })
		Tween.To(stroke, { Color = Theme.Values.Outline })
	end))
end

--- Effective background transparency for a surface whose opaque base is `base`,
--- given the current global UI transparency.
local function SurfaceAlpha(base: number): number
	return base + (1 - base) * Config.Transparency
end

-- Global UI scale: a UIScale per top-level surface, driven together.
local ScaleInstances: { Instance } = {}
local function trackScale(guiObject: Instance): Instance
	local s = Create("UIScale", { Parent = guiObject, Scale = Config.Scale })
	table.insert(ScaleInstances, s)
	return s
end
local function ApplyScale(n: number)
	Config.Scale = math.clamp(n, 0.5, 2)
	for i = #ScaleInstances, 1, -1 do
		if not pcall(function() ScaleInstances[i].Scale = Config.Scale end) then
			table.remove(ScaleInstances, i)
		end
	end
	for _, window in Library._windows do
		if window.FitToViewport then window:FitToViewport() end
	end
	for i = #DeviceRefreshers, 1, -1 do
		if not pcall(DeviceRefreshers[i]) then table.remove(DeviceRefreshers, i) end
	end
end

-- Functions that re-apply state-dependent transparency (e.g. the active tab,
-- whose target differs from its tracked base). Run after the generic pass.
local TransparencyRefreshers: { () -> () } = {}

--- Make the whole UI see-through. alpha: 0 (opaque) … 1 (invisible).
--- Lerps every tracked opaque surface and keeps fade animations in sync.
local function ApplyTransparency(alpha: number)
	Config.Transparency = math.clamp(alpha, 0, 1)
	for inst, base in Surfaces do
		local ok = pcall(function()
			local v = SurfaceAlpha(base)
			inst.BackgroundTransparency = v
			Tween.SetShown(inst, "BackgroundTransparency", v)
		end)
		if not ok then Surfaces[inst] = nil end -- prune destroyed instances
	end
	for i = #TransparencyRefreshers, 1, -1 do
		if not pcall(TransparencyRefreshers[i]) then
			table.remove(TransparencyRefreshers, i)
		end
	end
end

--==============================================================================
-- Glass mode (glassmorphism): translucent surfaces + a world blur behind the UI.
-- Roblox can't blur individual GUIs, so a single Lighting BlurEffect blurs the 3D
-- scene behind the (now translucent) menu while it's open — a real frosted feel.
--==============================================================================

local GlassBlur = Create("BlurEffect", { Parent = Lighting, Name = "\0", Enabled = false, Size = 0 })
LibMaid:GiveTask(GlassBlur) -- destroyed on :Unload(), which removes the blur
local menuOpen, preGlassAlpha, glassAppliedAlpha = false, 0, 0

local function refreshGlass()
	local on = Config.Glass and menuOpen and Device.Mode == "PC" and Config.GlassBlur > 0
	if on then
		GlassBlur.Enabled = true
		Tween.To(GlassBlur, { Size = Config.GlassBlur }, Tween.Info(Config.FadeSpeed))
	else
		local t = Tween.To(GlassBlur, { Size = 0 }, Tween.Info(Config.FadeSpeed))
		t.Completed:Once(function()
			keepCapability()
			if not (Config.Glass and menuOpen and Device.Mode == "PC" and Config.GlassBlur > 0) then GlassBlur.Enabled = false end
		end)
	end
end

--- Toggle glassmorphism. Ensures a minimum surface translucency (so the blur shows
--- through) without clobbering a higher user-set transparency; on off it restores
--- the pre-glass value ONLY if the user didn't change transparency while glass was on.
local function ApplyGlass(on: boolean)
	on = on and true or false
	if on == Config.Glass then return end
	Config.Glass = on
	if on then
		preGlassAlpha = Config.Transparency
		glassAppliedAlpha = math.max(Config.Transparency, Config.GlassTransparency)
		ApplyTransparency(glassAppliedAlpha)
	elseif math.abs(Config.Transparency - glassAppliedAlpha) < 1e-4 then
		ApplyTransparency(preGlassAlpha) -- untouched since glass set it → revert
	end
	refreshGlass()
end

--==============================================================================
-- Drag / resize
--==============================================================================

local function MakeDraggable(frame: GuiObject, handle: GuiObject?, maid)
	handle = handle or frame
	local dragStart, startPos
	local stopMove
	maid:GiveTask(function() if stopMove then stopMove() end end)
	maid:GiveTask((handle :: any).InputBegan:Connect(function(input)
		if Input.isPrimary(input) then
			dragStart, startPos = input.Position, frame.Position
			if stopMove then stopMove() end
			-- move listener lives only for the drag's duration
			stopMove = Input.On("Changed", function(inp)
				if matchesGesture(inp, input) then
					local delta = inp.Position - dragStart
					frame.Position = UDim2.new(
						startPos.X.Scale, startPos.X.Offset + delta.X,
						startPos.Y.Scale, startPos.Y.Offset + delta.Y)
				end
			end)
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					if stopMove then stopMove(); stopMove = nil end
					conn:Disconnect()
				end
			end)
			maid:GiveTask(conn)
		end
	end))
end

local function MakeResizable(frame: GuiObject, minSize: Vector2, maid)
	-- invisible hit area in the bottom-right corner…
	local grip = Create("TextButton", {
		Parent = frame,
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -2, 1, -2),
		Size = UDim2.fromOffset(16, 16),
		BorderSizePixel = 0,
		ZIndex = 20,
		BackgroundTransparency = 1,
	})
	local function fitGrip()
		local dimension = Device.Mode == "Mobile" and 40 / Config.Scale or 16
		grip.Size = UDim2.fromOffset(dimension, dimension)
	end
	fitGrip()
	table.insert(DeviceRefreshers, fitGrip)
	-- …with three diagonal grip dots (subtle; brighten to accent on hover)
	local dots = {}
	for i = 0, 2 do
		local d = Create("Frame", {
			Parent = grip, AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -(i * 4), 1, -(i * 4)), Size = UDim2.fromOffset(3, 3),
			BorderSizePixel = 0, BackgroundTransparency = 0.35, ZIndex = 21,
			BackgroundColor3 = Color3.fromRGB(120, 130, 140), ThemeTag = { BackgroundColor3 = "Outline" },
		})
		Create("UICorner", { Parent = d, CornerRadius = UDim.new(1, 0) })
		dots[#dots + 1] = d
	end
	maid:GiveTask(grip.MouseEnter:Connect(function()
		for _, d in dots do
			Theme.Retag(d, { BackgroundColor3 = "Accent" })
			Tween.To(d, { BackgroundColor3 = Theme.Values.Accent, BackgroundTransparency = 0 })
		end
	end))
	maid:GiveTask(grip.MouseLeave:Connect(function()
		for _, d in dots do
			Theme.Retag(d, { BackgroundColor3 = "Outline" })
			Tween.To(d, { BackgroundColor3 = Theme.Values.Outline, BackgroundTransparency = 0.35 })
		end
	end))
	local startSize, startPos
	local stopMove
	maid:GiveTask(function() if stopMove then stopMove() end end)
	maid:GiveTask(grip.InputBegan:Connect(function(input)
		if Input.isPrimary(input) then
			-- work in pre-scale offset units so the grip tracks 1:1 at any UI scale
			startSize, startPos = frame.AbsoluteSize / Config.Scale, input.Position
			if stopMove then stopMove() end
			stopMove = Input.On("Changed", function(inp)
				if matchesGesture(inp, input) then
					local delta = (inp.Position - startPos) / Config.Scale
					local viewport = frame.Parent.AbsoluteSize / Config.Scale
					local maxWidth, maxHeight = math.max(1, viewport.X - 24 / Config.Scale), math.max(1, viewport.Y - 24 / Config.Scale)
					frame.Size = UDim2.fromOffset(
						math.clamp(startSize.X + delta.X, math.min(Device.Mode == "Mobile" and 280 / Config.Scale or minSize.X, maxWidth), maxWidth),
						math.clamp(startSize.Y + delta.Y, math.min(minSize.Y, maxHeight), maxHeight))
				end
			end)
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					if stopMove then stopMove(); stopMove = nil end
					conn:Disconnect()
				end
			end)
			maid:GiveTask(conn)
		end
	end))
	return grip
end

--==============================================================================
-- Holders (ScreenGuis)
--==============================================================================

local Parent = GetParentGui()

-- Best-effort stream-proofing: hide the UI from screen capture / recording IF the
-- executor exposes a way to. There is no universal API for ScreenGuis, so this
-- tries the common ones and is a silent no-op where unsupported.
local function protectGui(gui: Instance)
	if not Config.StreamProof then return end
	pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
	pcall(function() if protect_gui then protect_gui(gui) end end)               -- some executors
	pcall(function() if gui.SetAttribute then gui:SetAttribute("StreamProof", true) end end) -- honoured by a few
end

local Holder = Create("ScreenGui", {
	Parent = Parent,
	Name = "\0",
	ZIndexBehavior = Enum.ZIndexBehavior.Global,
	IgnoreGuiInset = false, -- AbsolutePosition then shares GetMouseLocation's space
	DisplayOrder = 999,
	ResetOnSpawn = false,
})
LibMaid:GiveTask(Holder)
protectGui(Holder)

local UnusedHolder = Create("ScreenGui", {
	Parent = Parent,
	Name = "\0",
	Enabled = false,
	ResetOnSpawn = false,
})
LibMaid:GiveTask(UnusedHolder)

-- Modals (loader / message box / key system) render above the main UI.
-- Sibling z-index behaviour means child ZIndex need not be set manually.
local ModalHolder = Create("ScreenGui", {
	Parent = Parent,
	Name = "\0",
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = false,
	DisplayOrder = 1000,
	ResetOnSpawn = false,
})
LibMaid:GiveTask(ModalHolder)
protectGui(ModalHolder)

-- Marked so a LATER run can find and clear a previous session's leftovers. Both normal
-- teardown routes (an unload hook, or this library object) live in getgenv(), and an
-- executor "clear globals" — or an unload that died halfway — drops them while the
-- interface stays on screen. Loading again then stacks a second window over the first
-- with no way to remove either. An attribute is the only dependable handle here: these
-- holders are deliberately named "\0", and the popup holder carries no text to match on.
for _, h in { Holder, UnusedHolder, ModalHolder } do
	pcall(function() h:SetAttribute("BloxUIHolder", true) end)
end

-- Full-screen transparent layer; toasts are pushed to a configurable corner
-- by the layout's alignment (see ApplyNotificationSide).
local NotifHolder = Create("Frame", {
	Parent = Holder,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	BorderSizePixel = 0,
})
local NotifLayout = Create("UIListLayout", {
	Parent = NotifHolder,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
Create("UIPadding", {
	Parent = NotifHolder,
	PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
	PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
})

local function ApplyNotificationSide(side: string)
	Config.NotificationSide = side
	NotifLayout.VerticalAlignment = (side == "TopRight" or side == "TopLeft")
		and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
	NotifLayout.HorizontalAlignment = (side == "TopLeft" or side == "BottomLeft")
		and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right
end
ApplyNotificationSide(Config.NotificationSide)

--==============================================================================
-- Anchored popup follow loop (single RenderStepped for all popups + cursor)
--==============================================================================

local Anchors = {} -- frame -> updater fn
local OpenPopups = {} -- popup -> true (exclusive popups currently open)
local OpenPopupList = {} -- popup -> anchor; ALL open popups, for one shared outside-click handler
local hideTooltip: (() -> ())? = nil -- set by the Tooltip block; hides any visible tooltip

-- Top-anchored floating widgets (watermark, top ticker) claim a stacking slot so
-- they don't load on top of each other. They stay draggable afterwards.
local topStackY = 12
local function claimTopSlot(height: number): number
	local y = topStackY
	topStackY = topStackY + height + 8
	return y
end

-- Always created (hidden) so the Settings "Custom cursor" toggle can show it at
-- runtime. Previously it only existed if Config.CustomCursor was true *before* the
-- window was built, so flipping the toggle did nothing (and still hid the system
-- cursor → no cursor at all).
local CursorBg = Create("Frame", {
	Parent = Holder, BackgroundTransparency = 1, ZIndex = 9999,
	Size = UDim2.fromOffset(16, 16), Visible = false,
})
Create("ImageLabel", {
	Parent = CursorBg, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	Image = "rbxassetid://76631660114196", ZIndex = 9999,
	ThemeTag = { ImageColor3 = "Accent" },
})

-- Open popups follow their anchor each frame (negligible when none are open;
-- needed so popups track the window while it is dragged).
LibMaid:GiveTask(RunService.RenderStepped:Connect(function()
	if next(Anchors) == nil then return end -- idle frames pay nothing
	keepCapability()
	for _, fn in Anchors do
		fn()
	end
end))

-- Custom cursor follows the pointer on movement only (event-driven, opt-in).
LibMaid:GiveTask(Input.On("Changed", function(input)
	if CursorBg.Visible and Input.isMove(input) then
		local m = MousePos()
		CursorBg.Position = UDim2.fromOffset(m.X, m.Y)
	end
end))

local function CloseAllPopups(except)
	for popup in OpenPopups do
		if popup ~= except then
			popup:SetOpen(false)
		end
	end
end

-- One shared outside-click handler for every popup (replaces a per-popup Began
-- listener that fired — and spawned — for all of them on every click).
LibMaid:GiveTask(Input.On("Began", function(input)
	if not Input.isPrimary(input) or next(OpenPopupList) == nil then return end
	for popup, anchor in OpenPopupList do
		if popup.IsOpen and not isMouseOver(popup.Frame, input) and not isMouseOver(anchor, input) then
			popup:SetOpen(false)
		end
	end
end))

--- Generic popup attached under an anchor element. Handles fade, follow, outside-click.
local function CreatePopup(anchorTo: GuiObject, maid, exclusive: boolean?)
	local frame = Create("Frame", {
		Parent = UnusedHolder,
		Visible = false,
		Solid = true, -- stay opaque + readable under glass mode
		BackgroundColor3 = Color3.fromRGB(20, 24, 21),
		BorderColor3 = Color3.fromRGB(12, 12, 12),
		BorderSizePixel = 2,
		Size = UDim2.fromOffset(100, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 50,
		ThemeTag = { BackgroundColor3 = "Inline", BorderColor3 = "Border" },
	})
	Stroke(frame, "Outline")
	maid:GiveTask(frame)

	local popup = { Frame = frame, IsOpen = false }

	function popup:SetOpen(open: boolean)
		if open == self.IsOpen then return end -- idempotent; no debounce so a mid-open popup can still be closed
		self.IsOpen = open
		if self.OnStateChanged then self.OnStateChanged(open) end -- let an owner (e.g. dropdown) resync its chevron on external closes

		if open then
			if hideTooltip then hideTooltip() end -- a tooltip would float over the list
			if exclusive ~= false then
				CloseAllPopups(self)
				OpenPopups[self] = true
			end
			frame.Visible = true
			frame.Parent = Holder
			OpenPopupList[self] = anchorTo
			Anchors[frame] = function()
				local ap, as = anchorTo.AbsolutePosition, anchorTo.AbsoluteSize
				local viewport, height = Holder.AbsoluteSize, frame.AbsoluteSize.Y
				local below = ap.Y + as.Y + 6
				local y = below + height <= viewport.Y - 8 and below or ap.Y - height - 6
				frame.Position = UDim2.fromOffset(math.clamp(ap.X, 8, math.max(8, viewport.X - as.X - 8)),
					math.clamp(y, 8, math.max(8, viewport.Y - height - 8)))
				frame.Size = UDim2.fromOffset(math.min(as.X, math.max(1, viewport.X - 16)), 0)
			end
			Anchors[frame]()
		else
			OpenPopups[self] = nil
			OpenPopupList[self] = nil
			Anchors[frame] = nil
		end

		local last = Tween.Fade(frame, open, Config.FadeSpeed)
		local function done()
			if not frame.Parent then return end
			keepCapability()
			frame.Visible = self.IsOpen
			if not self.IsOpen then frame.Parent = UnusedHolder end
		end
		if last then last.Completed:Once(done) else done() end
	end

	-- ensure a still-open popup is forgotten (and stops following) if its owner is cleaned up
	maid:GiveTask(function() OpenPopups[popup] = nil; OpenPopupList[popup] = nil; Anchors[frame] = nil end)

	return popup
end

--==============================================================================
-- Assets + custom font
--==============================================================================

-- Only the alpha checkerboard is used (the HSV palette is built from gradients now),
-- so we no longer download saturation/value/hue on startup.
local Assets = {
	Checkers   = { "checkers.png",   "https://github.com/sametexe001/images/blob/main/checkers.png?raw=true" },
}

if HasFileSystem then
	for _, dir in Folders do
		if not isfolder(dir) then pcall(makefolder, dir) end
	end
	for _, data in Assets do
		local path = Folders.Assets .. "/" .. data[1]
		if not isfile(path) then
			pcall(function() writefile(path, httpget(data[2])) end)
		end
	end
end

--- Normalise an image reference for an Image property. Accepts a bare numeric
--- asset id ("123") OR an already-qualified content string and leaves the latter
--- untouched — rbxassetid://, rbxasset:// (what getcustomasset/`GetImage` return),
--- rbxthumb://, http(s)://. Blindly prefixing broke every non-numeric value.
local function AssetUrl(value: any): string
	local s = tostring(value or "")
	if s == "" then return "" end
	if s:match("^%a[%w%+%.%-]*://") then return s end -- already has a URI scheme
	return "rbxassetid://" .. s
end

function Library:GetImage(name: string): string
	local data = Assets[name]
	if not data then return "" end
	if HasFileSystem and getcustomasset then
		local path = Folders.Assets .. "/" .. data[1]
		if isfile(path) then
			local ok, id = pcall(getcustomasset, path)
			if ok then return id end
		end
	end
	return ""
end

-- Default UI font: a clean, smooth sans. Set `Library.Font` (a Font object)
-- before building the window to override.
Library.Font = Library.Font or Font.fromEnum(Enum.Font.Gotham)

-- assign the forward-declared GetFont (do NOT redeclare with `local`)
function GetFont(): Font
	return Library.Font or Font.fromEnum(Enum.Font.Gotham)
end

--==============================================================================
-- Tooltip
--==============================================================================

local Tooltip = {} do
	local frame = Create("Frame", {
		Parent = Holder, Visible = false, ZIndex = 5000,
		AutomaticSize = Enum.AutomaticSize.XY, BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(14, 17, 15),
		ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" },
	})
	Stroke(frame, "Outline")
	Create("UIPadding", { Parent = frame,
		PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) })
	Corner(frame, 4)
	-- size is set explicitly per-tooltip (measured, capped at MAX_TT_W) so long
	-- text wraps instead of running off-screen; AutomaticSize.X ignores constraints.
	local MAX_TT_W = 260
	local label = Create("TextLabel", {
		Parent = frame, BackgroundTransparency = 1,
		FontFace = GetFont(), TextSize = 13, ZIndex = 5001, RichText = true, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "", TextColor3 = Color3.fromRGB(235, 235, 235),
		ThemeTag = { TextColor3 = "Text" },
	})

	-- coloured [KIND] prefix for info markers
	local TOOLTIP_KINDS = {
		info    = { c = Color3.fromRGB(110, 170, 245), t = "INFO" },
		tip     = { c = Color3.fromRGB(120, 230, 150), t = "TIP" },
		warning = { c = Color3.fromRGB(245, 170, 90),  t = "WARNING" },
		error   = { c = Color3.fromRGB(245, 110, 110), t = "ERROR" },
	}

	-- place near the cursor but keep the whole tooltip on screen
	local function place()
		local m = MousePos()
		local vp = Holder.AbsoluteSize
		local fw, fh = frame.AbsoluteSize.X, frame.AbsoluteSize.Y
		local px = math.clamp(m.X + 14, 4, math.max(4, vp.X - fw - 4))
		local py = math.clamp(m.Y + 16, 4, math.max(4, vp.Y - fh - 4))
		frame.Position = UDim2.fromOffset(px, py)
	end

	local active = false
	local currentGui: GuiObject? = nil

	local function hide()
		frame.Visible = false
		active = false
		currentGui = nil
	end
	hideTooltip = hide -- let popups hide the tooltip when they open

	-- is the pointer still within the bound element's screen rect?
	local function overGui(gui: GuiObject?): boolean
		if not gui or not gui.Parent or not gui.Visible then return false end
		local m = MousePos()
		local p, s = gui.AbsolutePosition, gui.AbsoluteSize
		return m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
	end

	-- follow the pointer only while a tooltip is shown and the mouse moves
	LibMaid:GiveTask(Input.On("Changed", function(input)
		if not active or not Input.isMove(input) then return end
		-- hide if a popup (dropdown/colorpicker/keybind list) is open — the tooltip
		-- would otherwise float over it — or if the pointer left the bound element
		-- (e.g. a popup opened on top, so MouseLeave never fired).
		if next(OpenPopups) ~= nil or not overGui(currentGui) then
			hide()
		else
			place()
		end
	end))

	function Tooltip.Bind(gui: GuiObject, text: string, maid, kind: string?)
		local k = kind and TOOLTIP_KINDS[kind]
		local display = text
		if k then
			local c = k.c
			display = ("<b><font color=\"rgb(%d,%d,%d)\">[%s]</font></b> %s")
				:format(math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), k.t, text)
		end
		local plain = (k and ("[" .. k.t .. "] ") or "") .. text -- for measuring (no rich tags)
		maid:GiveTask(gui.MouseEnter:Connect(function()
			-- don't pop a tooltip while a popup is open: it would render over the list
			if next(OpenPopups) ~= nil then return end
			label.Text = display
			local ok, b = pcall(function()
				return game:GetService("TextService"):GetTextSize(plain, 13, Enum.Font.Gotham, Vector2.new(MAX_TT_W, 100000))
			end)
			if ok and b then
				label.Size = UDim2.fromOffset(math.ceil(b.X) + 4, math.ceil(b.Y))
			else
				label.Size = UDim2.fromOffset(MAX_TT_W, 40)
			end
			currentGui = gui
			frame.Visible = true
			active = true
			place()
			task.defer(place)
		end))
		maid:GiveTask(gui.MouseLeave:Connect(function()
			if currentGui == gui then hide() end
		end))
	end
end

local ConfigMetadata = (function()
local Metadata = {
    FILENAME = "__bloxui_metadata.json",
    RESERVED_NAME = "__bloxui_metadata",
}

local MAX_TIMESTAMP = 9007199254740991
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local TIMESTAMPS = { "CreatedAt", "UpdatedAt", "LastUsedAt" }

local function validTimestamp(value)
    return type(value) == "number" and value == value and value >= 0
        and value <= MAX_TIMESTAMP and value == math.floor(value)
end

function Metadata.validName(name)
    if type(name) ~= "string" or name == "" or #name > 120 or name == "None"
        or name == "." or name == ".." or name:find("/", 1, true) or name:find("\\", 1, true)
        or name:find('[<>:"|?*]') or name:find("%c") or name:match("^%s") or name:match("[%s%.]$") then
        return false
    end
    local lower = name:lower()
    return lower ~= Metadata.RESERVED_NAME and lower ~= Metadata.FILENAME
end

local function emptyIndex()
    return { schema_version = 1, profiles = {} }
end

local function profileFrom(value)
    local profile = {}
    if type(value) == "table" then
        for _, key in ipairs(TIMESTAMPS) do
            local timestamp = rawget(value, key)
            if validTimestamp(timestamp) then profile[key] = timestamp end
        end
    end
    return profile
end

local function profilesFrom(index)
    if type(index) ~= "table" or rawget(index, "schema_version") ~= 1 then return nil end
    local profiles = rawget(index, "profiles")
    return type(profiles) == "table" and profiles or nil
end

-- // Invalid or unsupported sidecars never prevent profiles themselves from loading. \\ --
function Metadata.read(raw, decode)
    if type(raw) ~= "string" or raw == "" or #raw > 2 * 1024 * 1024 or type(decode) ~= "function" then
        return emptyIndex()
    end
    local ok, result = pcall(function()
        local decoded = decode(raw)
        local profiles = profilesFrom(decoded)
        if not profiles then return emptyIndex() end
        local index = emptyIndex()
        for name, value in pairs(profiles) do
            if Metadata.validName(name) and type(value) == "table" then
                index.profiles[name] = profileFrom(value)
            end
        end
        return index
    end)
    return ok and result or emptyIndex()
end

-- // Only an explicit new-file creation can establish an otherwise unknown creation time. \\ --
function Metadata.touch(index, name, action, now)
    local profiles = profilesFrom(index)
    if not profiles or not Metadata.validName(name) or not validTimestamp(now)
        or (action ~= "create" and action ~= "save" and action ~= "use" and action ~= "delete") then
        return false, nil
    end
    local previous = rawget(profiles, name)
    if action == "delete" then
        if previous == nil then return false, nil end
        rawset(profiles, name, nil)
        return true, nil
    end
    local profile = profileFrom(previous)
    if action == "create" then
        if profile.CreatedAt == nil then profile.CreatedAt = now end
        profile.UpdatedAt = now
    elseif action == "save" then
        profile.UpdatedAt = now
    else
        profile.LastUsedAt = now
    end
    local changed = type(previous) ~= "table"
    if not changed then
        for _, key in ipairs(TIMESTAMPS) do
            if rawget(previous, key) ~= profile[key] then changed = true; break end
        end
    end
    if changed then rawset(profiles, name, profile) end
    return changed, changed and profile or previous
end

-- // DateTime owns Roblox local time; the CLI fallback is used only without that engine datatype. \\ --
function Metadata.formatTimestamp(epoch, _now)
    if not validTimestamp(epoch) then return "Unknown" end
    local ok, text = pcall(function()
        local date
        if DateTime ~= nil then
            local localTime = DateTime.fromUnixTimestamp(epoch):ToLocalTime()
            if type(localTime) ~= "table" then return "Unknown" end
            date = { year = localTime.Year, month = localTime.Month, day = localTime.Day,
                hour = localTime.Hour, min = localTime.Minute }
        else
            date = os.date("*t", epoch)
        end
        if type(date) ~= "table" then return "Unknown" end
        local function part(value, low, high)
            return type(value) == "number" and value == value and value >= low and value <= high
                and value == math.floor(value)
        end
        if not part(date.year, 1, 9999) or not part(date.month, 1, 12) or not part(date.day, 1, 31)
            or not part(date.hour, 0, 23) or not part(date.min, 0, 59) then return "Unknown" end
        local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
        if date.year % 4 == 0 and (date.year % 100 ~= 0 or date.year % 400 == 0) then days[2] = 29 end
        if date.day > days[date.month] then return "Unknown" end
        local month = MONTHS[date.month]
        return ("%d %s %04d, %02d:%02d"):format(date.day, month, date.year, date.hour, date.min)
    end)
    return ok and type(text) == "string" and text or "Unknown"
end

function Metadata.describe(index, name, now)
    local profiles = profilesFrom(index)
    local profile = profiles and Metadata.validName(name) and rawget(profiles, name)
    profile = profileFrom(profile)
    return {
        Created = Metadata.formatTimestamp(profile.CreatedAt, now),
        LastUsed = profile.LastUsedAt == nil and "Never" or Metadata.formatTimestamp(profile.LastUsedAt, now),
        Updated = Metadata.formatTimestamp(profile.UpdatedAt, now),
    }
end

return Metadata
end)()
Library.ConfigMetadataVersion = "v1.0.0"

function Library:NextFlag(): string
	return "flag_" .. HttpService:GenerateGUID(false)
end

--- Set a single flag's value programmatically (drives the element's own :Set via
--- its registered setter, so the UI + callback update). No-op for unknown flags.
function Library:SetValue(flag: string, value: any)
	local setter = self._setters[flag]
	if setter then setter(value) end
end

--- Read a single flag's current value.
function Library:GetFlag(flag: string): any
	return self.Flags[flag]
end

-- // One universe shares profiles across its places, without inheriting another game's auto-load. \\ --
--- Auto-load: which named config (if any) is applied automatically on launch.
function Library:GetAutoLoad(): string?
	if not HasFileSystem then return nil end
	local name = readConfigFile(Folders.Configs .. "/autoload.txt")
	if validConfigName(name) and configFileExists(Folders.Configs .. "/" .. name .. ".json") then return name end
	return nil
end

--- Set (or clear, with nil/"None") the config that auto-loads on launch.
function Library:SetAutoLoad(name: string?): boolean
	if not HasFileSystem then return false end
	local p = Folders.Configs .. "/autoload.txt"
	if name == nil or name == "" or name == "None" then
		if not configFileExists(p) then return true end
		if type(delfile) == "function" then pcall(delfile, p) end
		if configFileExists(p) then
			local ok = pcall(writefile, p, "")
			return ok and readConfigFile(p) == ""
		end
		return true
	end
	if not validConfigName(name) or not configFileExists(Folders.Configs .. "/" .. name .. ".json") then return false end
	local ok = pcall(writefile, p, name)
	return ok and readConfigFile(p) == name
end

function Library:SafeCall(fn, ...): boolean
	if type(fn) ~= "function" then return false end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[BloxUI] callback error: " .. tostring(err)) end
	return ok
end

function Library:GetConfig(): string
	local out = {}
	for flag, value in self.Flags do
		if ConfigControlFlags[flag] then continue end
		if type(value) == "table" and value.Key then            -- keybind
			out[flag] = { Key = tostring(value.Key), Mode = value.Mode, Toggled = value.Toggled }
		elseif type(value) == "table" and value.Color then       -- colorpicker
			out[flag] = { Color = value.Color, Alpha = value.Alpha }
		else
			out[flag] = value
		end
	end
	-- persist the primary window's position (restored on load)
	local w = self._windows[1]
	if w and w._root then
		local p = w._root.Position
		out.__WindowPos = { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset }
	end
	return HttpService:JSONEncode(out)
end

function Library:LoadConfig(json: string): (boolean, string?)
	if self._unloaded then return false, "The UI has been unloaded." end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(decoded) ~= "table" then return false, "invalid json" end
	local ok2, err = pcall(function()
		-- restore the window position first
		local wp = decoded.__WindowPos
		local w = self._windows[1]
		if type(wp) == "table" and w and w._root then
			w._root.Position = UDim2.new(wp[1], wp[2], wp[3], wp[4])
		end
		for flag, value in decoded do
			if self._unloaded then error("The UI has been unloaded.") end
			if flag == "__WindowPos" or ConfigControlFlags[flag] then continue end
			local setter = self._setters[flag]
			if not setter then continue end
			if type(value) == "table" and value.Key then
				setter(value)
			elseif type(value) == "table" and value.Color then
				setter(value.Color, value.Alpha)
			else
				setter(value)
			end
		end
	end)
	return ok2, err
end

function Library:ListConfigs(): { string }
	local list, seen = {}, {}
	if not HasFileSystem then return list end
	local folders = { Folders.Configs }
	for _, folder in folders do
		local ok, paths = pcall(listfiles, folder)
		if ok and type(paths) == "table" then
			for _, path in paths do
				local name = type(path) == "string" and path:match("([^/\\]+)%.json$")
				if validConfigName(name) and not seen[name] and configFileExists(folder .. "/" .. name .. ".json") then
					seen[name] = true
					list[#list + 1] = name
				end
			end
		end
	end
	table.sort(list)
	return list
end

function Library:SaveConfig(name: string): boolean
	if not HasFileSystem or not validConfigName(name) then return false end
	local path = Folders.Configs .. "/" .. name .. ".json"
	local existed = configFileExists(path) or self:ReadConfig(name) ~= nil
	local serialized, raw = pcall(self.GetConfig, self)
	if not serialized or type(raw) ~= "string" then return false end
	local written = pcall(writefile, path, raw)
	local confirmed = written and readConfigFile(path) == raw
	if confirmed then
		if not existed then self:_ConfigMetadataIndex().profiles[name] = nil end
		self:_TouchConfigMetadata(name, existed and "save" or "create")
	end
	return confirmed
end

function Library:DeleteConfig(name: string): boolean
	if not HasFileSystem or type(delfile) ~= "function" or not validConfigName(name) then return false end
	local path = Folders.Configs .. "/" .. name .. ".json"
	if configFileExists(path) then
		local auto = readConfigFile(Folders.Configs .. "/autoload.txt")
		local ok = pcall(delfile, path)
		local removed = ok and not configFileExists(path)
		if removed then
			self:_TouchConfigMetadata(name, "delete")
			if auto == name then self:SetAutoLoad(nil) end
		end
		return removed
	end
	return false
end

function Library:ReadConfig(name: string): string?
	if not HasFileSystem or not validConfigName(name) then return nil end
	local path = Folders.Configs .. "/" .. name .. ".json"
	local raw = readConfigFile(path)
	if raw ~= nil then return raw end
	return nil
end

-- // Profile metadata is separate from feature flags and never makes a successful save fail. \\ --
function Library:_ConfigMetadataIndex()
	if self._configMetadataFolder ~= Folders.Configs or not self._configMetadata then
		self._configMetadataFolder = Folders.Configs
		local raw = HasFileSystem and readConfigFile(Folders.Configs .. "/" .. ConfigMetadata.FILENAME)
		self._configMetadata = ConfigMetadata.read(raw, function(text) return HttpService:JSONDecode(text) end)
	end
	return self._configMetadata
end

function Library:_TouchConfigMetadata(name, action)
	if not validConfigName(name) then return false end
	local index = self:_ConfigMetadataIndex()
	local changed = ConfigMetadata.touch(index, name, action, os.time())
	if not changed or not HasFileSystem then return false end
	local encoded, raw = pcall(HttpService.JSONEncode, HttpService, index)
	if not encoded then return false end
	local path = Folders.Configs .. "/" .. ConfigMetadata.FILENAME
	local written = pcall(writefile, path, raw)
	return written and readConfigFile(path) == raw
end

function Library:GetConfigDetails(name)
	return ConfigMetadata.describe(self:_ConfigMetadataIndex(), name, os.time())
end

function Library:LoadProfile(name)
	local raw = self:ReadConfig(name)
	if not raw then return false, "Profile unavailable." end
	local loaded, message = self:LoadConfig(raw)
	if loaded and not self._unloaded then self:_TouchConfigMetadata(name, "use") end
	return loaded, message
end

--==============================================================================
-- Components
--==============================================================================

local Components = {}

local function registerSetter(flag, setter, maid)
	Library._setters[flag] = setter
	maid:GiveTask(function()
		if Library._setters[flag] == setter then
			Library._setters[flag], Library.Flags[flag] = nil, nil
		end
	end)
end

local function removeRefresher(list, callback)
	local index = table.find(list, callback)
	if index then table.remove(list, index) end
end

local function trackTouchTarget(gui, minimum, unscaled)
	local constraint = Create("UISizeConstraint", { Parent = gui })
	local function refresh()
		constraint.MinSize = Vector2.new(0, Device.Mode == "Mobile" and minimum / (unscaled and 1 or Config.Scale) or 0)
	end
	refresh()
	table.insert(DeviceRefreshers, refresh)
	gui.Destroying:Once(function() removeRefresher(DeviceRefreshers, refresh) end)
end

-- A reusable bordered element button skin (Element bg + gradient + outline)
local function ElementSkin(parent, height)
	local btn = Create("TextButton", {
		Parent = parent, Text = "", AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, height),
		BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(30, 36, 31),
		ThemeTag = { BackgroundColor3 = "Element", BorderColor3 = "Border" },
	})
	Create("UIGradient", {
		Parent = btn, Rotation = -165,
		Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(208,208,208)),
		-- declares it only depends on the Gradient key, so Set("Accent") etc. skips it
		ThemeTag = { Color = Theme.Fn({ "Gradient" }, function()
			return ColorSequence.new(Color3.fromRGB(255,255,255), Theme.Values.Gradient)
		end) },
	})
	local stroke = Stroke(btn, "Outline")
	Corner(btn)
	trackTouchTarget(btn, 44)
	return btn, stroke
end

----------------------------------------------------------------- InfoMarker ---
local MARKER_TYPES = {
	info    = { color = function() return Color3.fromRGB(110, 170, 245) end, glyph = "i" },
	tip     = { color = function() return Color3.fromRGB(120, 230, 150) end, glyph = "i" },
	warning = { color = function() return Color3.fromRGB(245, 170, 90) end,  glyph = "!" },
	error   = { color = function() return Color3.fromRGB(245, 110, 110) end, glyph = "!" },
}

-- A circular i / ! marker that shows a tooltip on hover (tips, warnings…).
function Components.InfoMarker(parent, text: string, kind: string?, maid)
	local data = MARKER_TYPES[kind or "info"] or MARKER_TYPES.info
	local marker = Create("TextButton", { Parent = parent, Text = "", AutoButtonColor = false,
		Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0, BackgroundColor3 = data.color() })
	Create("UICorner", { Parent = marker, CornerRadius = UDim.new(1, 0) })
	Create("UIStroke", { Parent = marker, Thickness = 1, Transparency = 0.4,
		Color = Color3.fromRGB(0, 0, 0), ThemeTag = { Color = "Text Stroke" } })
	Create("TextLabel", { Parent = marker, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		FontFace = Font.fromEnum(Enum.Font.GothamBold), Text = data.glyph, TextSize = 12,
		TextYAlignment = Enum.TextYAlignment.Center, TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(14, 17, 15), ThemeTag = { TextColor3 = "Background" } })
	if text and text ~= "" then Tooltip.Bind(marker, text, maid, kind or "info") end
	return marker
end

--------------------------------------------------------------------- Toggle ---
function Components.Toggle(data)
	local maid = data.Maid
	local self = { Value = false, Flag = data.Flag }

	-- flex row: checkbox + name (fills + wraps) + sub-elements (natural width),
	-- grows vertically and never overlaps at any width
	local row = Create("TextButton", {
		Parent = data.Parent, Text = "", AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 15), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0,
	})
	trackTouchTarget(row, 44)
	Create("UIListLayout", { Parent = row, FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Top, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

	local box = Create("Frame", {
		Parent = row, LayoutOrder = 0,
		Size = UDim2.fromOffset(14, 14), BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(30, 36, 31),
		ThemeTag = { BackgroundColor3 = "Element", BorderColor3 = "Border" },
	})
	Stroke(box, "Outline")
	Corner(box, 3)
	local check = Create("ImageLabel", {
		Parent = box, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 2, 1, 2), BackgroundTransparency = 1, ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Fit, Image = "rbxassetid://108016671469439",
		ImageColor3 = Color3.fromRGB(0, 0, 0),
	})

	-- name fills remaining width and wraps in it
	local text = MakeText(row, data.Name or "Toggle", {
		LayoutOrder = 1, Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	})
	Create("UIFlexItem", { Parent = text, FlexMode = Enum.UIFlexMode.Fill })

	-- sub-elements (colorpicker/keybind) take natural width to the right of the name
	local sub = Create("Frame", {
		Parent = row, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2, Size = UDim2.new(0, 0, 0, 15),
	})
	Create("UIListLayout", { Parent = sub, FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder })

	function self:Get() return self.Value end
	function self:SetText(t) text.Text = tostring(t) end
	function self:SetVisibility(b) row.Visible = b end

	function self:Set(value: boolean)
		self.Value = value and true or false
		Library.Flags[self.Flag] = self.Value
		if self.Value then
			Theme.Retag(box, { BackgroundColor3 = "Accent" })
			Tween.To(box, { BackgroundColor3 = Theme.Values.Accent })
			Tween.To(check, { ImageTransparency = 0, Size = UDim2.new(1, 2, 1, 2) },
				Tween.Info(nil, Enum.EasingStyle.Back))
		else
			Theme.Retag(box, { BackgroundColor3 = "Element" })
			Tween.To(box, { BackgroundColor3 = Theme.Values.Element })
			Tween.To(check, { ImageTransparency = 1, Size = UDim2.fromOffset(0, 0) },
				Tween.Info(nil, Enum.EasingStyle.Back))
		end
		-- keep the fade snapshot in sync so a tab switch (which fades the page)
		-- restores the tick state instead of a blank box
		Tween.SetShown(check, "ImageTransparency", self.Value and 0 or 1)
		if data.Callback then Library:SafeCall(data.Callback, self.Value) end
	end

	maid:GiveTask(row.MouseButton1Click:Connect(function() self:Set(not self.Value) end))
	maid:GiveTask(row.MouseEnter:Connect(function()
		if not self.Value then
			Theme.Retag(box, { BackgroundColor3 = "Hovered Element" })
			Tween.To(box, { BackgroundColor3 = Theme.Values["Hovered Element"] })
		end
	end))
	maid:GiveTask(row.MouseLeave:Connect(function()
		if not self.Value then
			Theme.Retag(box, { BackgroundColor3 = "Element" })
			Tween.To(box, { BackgroundColor3 = Theme.Values.Element })
		end
	end))

	self._sub = sub
	self:Set(data.Default and true or false)
	registerSetter(self.Flag, function(v) self:Set(v) end, maid)
	if data.Tooltip then Tooltip.Bind(row, data.Tooltip, maid) end
	if data._SearchRegister then data._SearchRegister(data.Name or "Toggle", row, "Toggle", data) end
	return self
end

--------------------------------------------------------------------- Button ---
function Components.Button(data)
	local maid = data.Maid
	local self = {}
	local row = Create("Frame", {
		Parent = data.Parent, BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	})
	Create("UIListLayout", { Parent = row, FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill, Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder })

	function self:Add(name: string, callback)
		local btn = ElementSkin(row, 20)
		btn.ClipsDescendants = true
		-- truncate long labels within the button instead of spilling into neighbours
		local label = MakeText(btn, name, { Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd })
		if #name > 14 then Tooltip.Bind(btn, name, maid) end -- full text on hover when likely truncated
		local sub = { Button = btn, Label = label }
		function sub:Press()
			Theme.Retag(btn, { BackgroundColor3 = "Accent" })
			Tween.To(btn, { BackgroundColor3 = Theme.Values.Accent })
			Library:SafeCall(callback)
			task.delay(0.12, function()
				if not btn.Parent then return end
				Theme.Retag(btn, { BackgroundColor3 = "Element" })
				Tween.To(btn, { BackgroundColor3 = Theme.Values.Element })
			end)
		end
		maid:GiveTask(btn.MouseButton1Click:Connect(function() sub:Press() end))
		maid:GiveTask(btn.MouseEnter:Connect(function()
			Theme.Retag(btn, { BackgroundColor3 = "Hovered Element" })
			Tween.To(btn, { BackgroundColor3 = Theme.Values["Hovered Element"] })
		end))
		maid:GiveTask(btn.MouseLeave:Connect(function()
			Theme.Retag(btn, { BackgroundColor3 = "Element" })
			Tween.To(btn, { BackgroundColor3 = Theme.Values.Element })
		end))
		if data._SearchRegister then data._SearchRegister(name, btn, "Button", data) end
		return sub
	end

	function self:SetVisibility(b) row.Visible = b end
	return self
end

--------------------------------------------------------------------- Slider ---
function Components.Slider(data)
	local maid = data.Maid
	local self = { Value = data.Min or 0, Flag = data.Flag }
	local minV, maxV = data.Min or 0, data.Max or 100
	-- "Decimals" is the rounding STEP (1 = integers, 0.1 = tenths). When it isn't
	-- given (or is invalid — 0/negative would make 1/decimals = inf → NaN), pick a
	-- step fine enough for the range so a sub-integer range like 0–1 doesn't round
	-- every value to 0/1. Big ranges (e.g. FOV 1–500) still default to integers.
	local decimals = data.Decimals
	if type(decimals) ~= "number" or decimals <= 0 then
		local range = math.abs(maxV - minV)
		decimals = (range <= 2 and 0.01) or (range <= 20 and 0.1) or 1
	end
	local suffix = data.Suffix or ""

	local container = Create("Frame", { Parent = data.Parent, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28), BorderSizePixel = 0 })
	MakeText(container, data.Name or "Slider", { Size = UDim2.new(1, -54, 0, 15),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
	-- editable value shown in a clear little input box (click to type a number)
	local valueBox = Create("Frame", { Parent = container, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, -1), Size = UDim2.new(0, 34, 0, 16), AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(30, 36, 31), BackgroundTransparency = 0.35,
		ThemeTag = { BackgroundColor3 = "Element" } })
	Corner(valueBox, 3)
	local vstroke = Stroke(valueBox, "Outline")
	Create("UIPadding", { Parent = valueBox, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
	local valueText = Create("TextBox", { Parent = valueBox, FontFace = GetFont(), TextSize = 13,
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		Text = "", ClearTextOnFocus = false, TextColor3 = Color3.fromRGB(235, 235, 235),
		TextXAlignment = Enum.TextXAlignment.Center, ThemeTag = { TextColor3 = "Text" } })
	TextStroke(valueText)
	FocusHighlight(valueText, vstroke, maid)

	local bar = Create("TextButton", { Parent = container, Text = "", AutoButtonColor = false,
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 10), BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(30, 36, 31),
		ThemeTag = { BackgroundColor3 = "Element", BorderColor3 = "Border" } })
	trackTouchTarget(container, 76)
	trackTouchTarget(valueBox, 36)
	trackTouchTarget(bar, 32)
	Stroke(bar, "Outline")
	Corner(bar)
	local fill = Create("Frame", { Parent = bar, Size = UDim2.fromScale(0.5, 1), BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { BackgroundColor3 = "Accent" } })
	addGlow(fill) -- neon glow that tracks the fill width

	function self:Get() return self.Value end
	function self:SetVisibility(b) container.Visible = b end

	-- decimal places to display, derived from the step (0.01 -> 2, 0.1 -> 1, 1 -> 0)
	local places = math.max(0, -math.floor(math.log(decimals, 10) + 0.0001))
	function self:Set(value: number)
		local mult = 1 / decimals
		-- round to the step THEN re-clamp (rounding can push a value past a bound
		-- when the range isn't a whole multiple of the step)
		value = math.clamp(math.floor(math.clamp(value, minV, maxV) * mult + 0.5) / mult, minV, maxV)
		self.Value = value
		Library.Flags[self.Flag] = value
		local span = maxV - minV
		local alpha = span ~= 0 and (value - minV) / span or 0 -- guard Min == Max (0/0 = NaN)
		Tween.To(fill, { Size = UDim2.new(alpha, 0, 1, 0) },
			Tween.Info(nil, Enum.EasingStyle.Quart))
		-- format to the step's decimal places to avoid binary-float artifacts
		valueText.Text = string.format("%." .. places .. "f", value) .. suffix
		if data.Callback then Library:SafeCall(data.Callback, value) end
	end

	-- typed input: parse the first number from the text on commit (ignores the
	-- suffix), else revert to the current value
	maid:GiveTask(valueText.FocusLost:Connect(function()
		local n = tonumber(valueText.Text:match("%-?%d+%.?%d*"))
		self:Set(n or self.Value)
	end))

	local function setFrom(input)
		local w = bar.AbsoluteSize.X
		if w <= 0 then return end -- not laid out yet; avoid div-by-zero
		local rel = (InputPos(input).X - bar.AbsolutePosition.X) / w
		self:Set(minV + (maxV - minV) * math.clamp(rel, 0, 1))
	end
	-- subscribe to pointer-move ONLY while dragging (no permanent per-slider listener)
	local stopMove
	maid:GiveTask(function() if stopMove then stopMove() end end)
	maid:GiveTask(bar.InputBegan:Connect(function(input)
		if Input.isPrimary(input) then
			setFrom(input)
			if stopMove then stopMove() end
			stopMove = Input.On("Changed", function(inp) if matchesGesture(inp, input) then setFrom(inp) end end)
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					if stopMove then stopMove(); stopMove = nil end
					conn:Disconnect()
				end
			end)
			maid:GiveTask(conn)
		end
	end))
	-- scroll the wheel over the bar to nudge by one step
	maid:GiveTask(bar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self:Set(self.Value + input.Position.Z * decimals)
		end
	end))
	maid:GiveTask(container.MouseEnter:Connect(function()
		Theme.Retag(bar, { BackgroundColor3 = "Hovered Element" })
		Tween.To(bar, { BackgroundColor3 = Theme.Values["Hovered Element"] })
	end))
	maid:GiveTask(container.MouseLeave:Connect(function()
		Theme.Retag(bar, { BackgroundColor3 = "Element" })
		Tween.To(bar, { BackgroundColor3 = Theme.Values.Element })
	end))

	self:Set(data.Default or minV)
	registerSetter(self.Flag, function(v) self:Set(v) end, maid)
	if data.Tooltip then Tooltip.Bind(container, data.Tooltip, maid) end
	if data._SearchRegister then data._SearchRegister(data.Name or "Slider", container, "Slider", data) end
	return self
end

---------------------------------------------------------------------- Label ---
function Components.Label(data)
	local maid = data.Maid
	local self = {}
	-- flex row: the text fills the remaining width (and wraps in it) while the
	-- sub-element (colorpicker/keybind/etc.) takes its natural width — so the two
	-- never overlap no matter how narrow the column gets.
	local container = Create("Frame", { Parent = data.Parent, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 })
	Create("UIListLayout", { Parent = container, FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Top, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })

	local text = MakeText(container, data.Name or "Label", { LayoutOrder = 0,
		TextSize = data.TextSize,
		Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	Create("UIFlexItem", { Parent = text, FlexMode = Enum.UIFlexMode.Fill }) -- text fills leftover width

	-- sub-element column (natural width); sits to the right of the text
	local sub = Create("Frame", { Parent = container, BackgroundTransparency = 1, LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 18) })
	Create("UIListLayout", { Parent = sub, FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder })

	function self:SetText(t) text.Text = tostring(t) end
	function self:SetVisibility(b) container.Visible = b end
	self._sub = sub
	if data.Tooltip then Tooltip.Bind(container, data.Tooltip, maid) end
	return self
end

------------------------------------------------------------------ Paragraph ---
function Components.Paragraph(data)
	local self = {}
	local container = Create("Frame", { Parent = data.Parent, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 })
	Create("UIListLayout", { Parent = container, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
	MakeText(container, data.Name or "Title", { Size = UDim2.new(1, 0, 0, 15),
		TextXAlignment = Enum.TextXAlignment.Left })
	local body = MakeText(container, data.Content or "", { Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(185, 185, 185), ThemeTag = { TextColor3 = "Placeholder Text" } })
	function self:SetText(t) body.Text = tostring(t) end
	function self:SetVisibility(b) container.Visible = b end
	return self
end

-------------------------------------------------------------------- Divider ---
function Components.Divider(data)
	local container = Create("Frame", { Parent = data.Parent, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 8), BorderSizePixel = 0 })
	Create("Frame", { Parent = container, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(42, 49, 45), ThemeTag = { BackgroundColor3 = "Outline" } })
	return { SetVisibility = function(_, b) container.Visible = b end }
end

----------------------------------------------------------------------- Image ---
-- data: { Image (id / rbxassetid:// / rbxasset:// / url), Size (UDim2), ScaleType, Rounded }
function Components.Image(data)
	local h = (data.Size and data.Size.Y.Offset > 0) and data.Size.Y.Offset or 80
	local container = Create("Frame", { Parent = data.Parent, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, h), BorderSizePixel = 0 })
	local img = Create("ImageLabel", { Parent = container, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = data.Size or UDim2.new(1, 0, 1, 0), Image = AssetUrl(data.Image),
		ScaleType = data.ScaleType or Enum.ScaleType.Fit })
	if data.Rounded then Corner(img, data.Rounded == true and 6 or data.Rounded) end
	if data.Tooltip then Tooltip.Bind(img, data.Tooltip, data.Maid) end
	return {
		SetImage = function(_, v) img.Image = AssetUrl(v) end,
		SetVisibility = function(_, b) container.Visible = b end,
		Instance = img,
	}
end

------------------------------------------------------------------------ Link ---
-- data: { Text, Url } — a button that copies the URL to the clipboard (Discord / credits)
function Components.Link(data)
	local btn = ElementSkin(data.Parent, 26)
	MakeText(btn, data.Text or "Open link", { Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(202, 243, 255),
		ThemeTag = { TextColor3 = "Accent" } })
	if data.Maid then
		data.Maid:GiveTask(btn.MouseButton1Click:Connect(function()
			if data.Url and data.Url ~= "" and setclipboard then pcall(setclipboard, data.Url) end
			Library:Notification({ Title = data.Text or "Link", Description = "Copied to clipboard.", Type = "info", Duration = 3 })
			if data.Callback then Library:SafeCall(data.Callback) end
		end))
	end
	return { SetVisibility = function(_, b) btn.Visible = b end, Instance = btn }
end

-------------------------------------------------------------------- Viewport ---
-- Renders a player's/user's 3D character in a ViewportFrame (great for ESP /
-- inspection). data: { Player, UserId, Size (UDim2), Rotate (bool, default true) }.
-- Handle: :SetPlayer(p) :SetUserId(id) :SetModel(m) :SetRotating(b) :SetVisibility(b) :Clear().
function Components.Viewport(data)
	local maid = data.Maid
	local container = Create("Frame", { Parent = data.Parent, BorderSizePixel = 2,
		Size = data.Size or UDim2.new(1, 0, 0, 150), BackgroundColor3 = Color3.fromRGB(20, 24, 21),
		BorderColor3 = Color3.fromRGB(12, 12, 12), ThemeTag = { BackgroundColor3 = "Inline", BorderColor3 = "Border" } })
	Stroke(container, "Outline"); Corner(container, 4)
	local vp = Create("ViewportFrame", { Parent = container, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 190, 190), LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.4, -1, -0.6) })
	local world = Instance.new("WorldModel"); world.Parent = vp
	local cam = Instance.new("Camera"); cam.Parent = vp; vp.CurrentCamera = cam

	local self = { Instance = vp }
	local current, spinConn, angle = nil, nil, 0

	local function stopSpin() if spinConn then spinConn:Disconnect(); spinConn = nil end end
	maid:GiveTask(stopSpin)

	local function frame()
		if not current then return end
		current:PivotTo(CFrame.new()) -- centre at origin
		local _, size = current:GetBoundingBox()
		local dist = math.max(size.X, size.Y, size.Z) * 1.6 + 2
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, dist), Vector3.new(0, 0, 0))
	end

	function self:Clear() if current then current:Destroy(); current = nil end end
	function self:SetModel(model)
		self:Clear()
		if not model then return end
		-- strip scripts so a cloned character can't error inside the viewport
		for _, d in model:GetDescendants() do
			if d:IsA("BaseScript") then d:Destroy() end
		end
		current = model
		model.Parent = world
		frame()
		if data.Rotate ~= false then self:SetRotating(true) end
	end
	-- Player characters are Archivable=false (so :Clone() returns nil); render a
	-- clean avatar from the UserId instead. Pass a cloneable Model to :SetModel for
	-- a live-pose render (make it Archivable yourself first).
	function self:SetPlayer(player)
		if player and player.UserId then self:SetUserId(player.UserId) end
	end
	function self:SetUserId(userId)
		task.spawn(function()
			local ok, model = pcall(function()
				return (Players :: any):CreateHumanoidModelFromUserId(userId)
			end)
			if ok and model then
				if container.Parent then self:SetModel(model) else model:Destroy() end
			end
		end)
	end
	function self:SetRotating(on)
		stopSpin()
		if on then
			spinConn = RunService.RenderStepped:Connect(function(dt)
				if not current or not current.Parent or not container.Visible then return end
				keepCapability()
				angle += dt * 0.7
				current:PivotTo(CFrame.new() * CFrame.Angles(0, angle, 0))
			end)
			-- no per-call GiveTask: stopSpin (given to the maid once at construction) closes
			-- over spinConn and disconnects whatever is live at clean time — avoids leaking a
			-- dead connection into the window maid on every SetModel/SetPlayer refresh
		end
	end
	function self:SetVisibility(b) container.Visible = b end

	if data.Player then self:SetPlayer(data.Player)
	elseif data.UserId then self:SetUserId(data.UserId) end
	return self
end

-------------------------------------------------------------------- Textbox ---
function Components.Textbox(data)
	local maid = data.Maid
	local self = { Value = "", Flag = data.Flag }
	local container = Create("Frame", { Parent = data.Parent, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0 })
	trackTouchTarget(container, 68)
	MakeText(container, data.Name or "Textbox", { Size = UDim2.new(1, 0, 0, 15),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
	local bg, bgStroke = ElementSkin(container, 20)
	bg.AnchorPoint = Vector2.new(0, 1)
	bg.Position = UDim2.new(0, 0, 1, 0)
	local input = Create("TextBox", { Parent = bg, FontFace = GetFont(), TextSize = 13,
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClearTextOnFocus = false,
		Text = "", TextColor3 = Color3.fromRGB(235, 235, 235), TextXAlignment = Enum.TextXAlignment.Left,
		PlaceholderColor3 = Color3.fromRGB(185, 185, 185), PlaceholderText = data.Placeholder or "...",
		ClipsDescendants = true, BorderSizePixel = 0,
		ThemeTag = { TextColor3 = "Text", PlaceholderColor3 = "Placeholder Text" } })
	TextStroke(input)
	Create("UIPadding", { Parent = input, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	FocusHighlight(input, bgStroke, maid)

	function self:Get() return self.Value end
	function self:SetVisibility(b) container.Visible = b end

	local settingText = false
	-- `rewrite` = also overwrite the box text (programmatic / commit); live typing
	-- passes false so partial numeric input ("-", ".", "-5") isn't clobbered.
	local function commit(value, rewrite)
		if data.Numeric then
			local n = tonumber(value)
			if n then value = n
			elseif rewrite then value = self.Value -- commit of junk → revert
			else return end                        -- live partial input → keep typing
		end
		self.Value = value
		Library.Flags[self.Flag] = value
		if rewrite then settingText = true; input.Text = tostring(value); settingText = false end
		if data.Callback then Library:SafeCall(data.Callback, value) end
	end
	function self:Set(value) commit(value, true) end

	if data.Finished then
		maid:GiveTask(input.FocusLost:Connect(function(enter)
			if enter then commit(input.Text, true) end -- normalise the box on commit
		end))
	else
		maid:GiveTask(input:GetPropertyChangedSignal("Text"):Connect(function()
			if not settingText then commit(input.Text, false) end -- live: don't rewrite the box
		end))
	end

	if data.Default then self:Set(data.Default) end
	registerSetter(self.Flag, function(v) self:Set(v) end, maid)
	if data.Tooltip then Tooltip.Bind(container, data.Tooltip, maid) end
	if data._SearchRegister then data._SearchRegister(data.Name or "Dropdown", container, "Dropdown", data) end
	return self
end

------------------------------------------------------------------- Dropdown ---
-- Unified dropdown: single/multi + optional inline search.
function Components.Dropdown(data)
	local maid = data.Maid
	local self = { Flag = data.Flag, Value = data.Multi and {} or nil, Options = {}, IsOpen = false }

	local container = Create("Frame", { Parent = data.Parent, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0 })
	trackTouchTarget(container, 68)
	MakeText(container, data.Name or "Dropdown", { Size = UDim2.new(1, 0, 0, 15),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
	local box = ElementSkin(container, 20)
	box.AnchorPoint = Vector2.new(0, 1)
	box.Position = UDim2.new(0, 0, 1, 0)
	local valueText = MakeText(box, "--", { AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.new(1, -28, 0, 15),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
	-- chevron points down when closed (asset's natural orientation is right → +90)
	local icon = Create("ImageLabel", { Parent = box, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1,
		Rotation = 90, ScaleType = Enum.ScaleType.Fit, Image = "rbxassetid://113229176886493",
		ImageColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { ImageColor3 = "Accent" } })

	local popup = CreatePopup(box, maid)
	Create("UIPadding", { Parent = popup.Frame, PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })
	Create("UIListLayout", { Parent = popup.Frame, Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder })

	local searchInput
	if data.Search then
		local searchBg = Create("Frame", { Parent = popup.Frame, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 0, BorderSizePixel = 0 })
		trackTouchTarget(searchBg, 44, true)
		searchInput = Create("TextBox", { Parent = searchBg, FontFace = GetFont(), TextSize = 13,
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ClearTextOnFocus = false,
			TextColor3 = Color3.fromRGB(235, 235, 235), TextXAlignment = Enum.TextXAlignment.Left,
			PlaceholderText = "search..", PlaceholderColor3 = Color3.fromRGB(185, 185, 185), BorderSizePixel = 0,
			ThemeTag = { TextColor3 = "Text", PlaceholderColor3 = "Placeholder Text" } })
	end

	-- multi-select: a Select-all / Clear header
	if data.Multi then
		local ac = Create("Frame", { Parent = popup.Frame, BackgroundTransparency = 1, LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 18) })
		trackTouchTarget(ac, 44, true)
		Create("UIListLayout", { Parent = ac, FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.Fill, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
		local function mini(text, cb)
			local b = Create("TextButton", { Parent = ac, Text = text, FontFace = GetFont(), TextSize = 12,
				AutoButtonColor = false, BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), ZIndex = 51,
				TextColor3 = Color3.fromRGB(202, 243, 255), BackgroundColor3 = Color3.fromRGB(30, 36, 31),
				BackgroundTransparency = 0.4, ThemeTag = { TextColor3 = "Accent", BackgroundColor3 = "Element" } })
			Corner(b, 3)
			maid:GiveTask(b.MouseButton1Click:Connect(cb))
		end
		mini("Select all", function()
			local all = {}
			for name in self.Options do all[#all + 1] = name end
			self:Set(all)
		end)
		mini("Clear", function() self:Set({}) end)
	end

	-- options live in a scrolling list: grows to fit, but caps at MaxHeight and
	-- scrolls for very long dropdowns (compact rows so more fit on screen)
	local MAX_LIST_H = data.MaxHeight or 200
	local list = Create("ScrollingFrame", { Parent = popup.Frame, BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarImageColor3 = Color3.fromRGB(202, 243, 255), LayoutOrder = 2, ZIndex = 51,
		ThemeTag = { ScrollBarImageColor3 = "Accent" } })
	local listLayout = Create("UIListLayout", { Parent = list, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
	Create("UIPadding", { Parent = list, PaddingRight = UDim.new(0, 4) }) -- room for the scrollbar
	-- height = content, capped at MAX_LIST_H (scrolls beyond that)
	local function fitList()
		keepCapability()
		list.Size = UDim2.new(1, 0, 0, math.min(listLayout.AbsoluteContentSize.Y, MAX_LIST_H,
			math.max(44, Holder.AbsoluteSize.Y - 160)))
	end
	maid:GiveTask(listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitList))
	maid:GiveTask(Holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitList))
	table.insert(DeviceRefreshers, fitList)
	maid:GiveTask(function() removeRefresher(DeviceRefreshers, fitList) end)

	local function refreshText()
		if data.Multi then
			valueText.Text = (#self.Value > 0) and table.concat(self.Value, ", ") or "--"
		else
			valueText.Text = self.Value or "--"
		end
		-- Carry the chosen item's tone onto the closed box too, so the current pick reads
		-- at a glance without opening the list. Multi can mix tones, so it stays on theme.
		-- Note: valueText keeps its Text ThemeTag, so a theme CHANGE repaints this until
		-- the next Set. Deliberate — dropping the tag would leave it unthemed for every
		-- caller that passes no ItemColors at all, which is all of them but one.
		if data.ItemColors then
			local tint = (not data.Multi) and self.Value and data.ItemColors[self.Value] or nil
			valueText.TextColor3 = tint or Theme.Values.Text
			valueText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			valueText.TextStrokeTransparency = tint and 0.5 or 1
		end
	end

	function self:Get() return self.Value end
	function self:SetVisibility(b) container.Visible = b end
	-- keep the wrapper's IsOpen + chevron in sync even when the popup is closed
	-- externally (CloseAllPopups / outside-click), so the next box click isn't wasted
	popup.OnStateChanged = function(open)
		self.IsOpen = open
		Tween.To(icon, { Rotation = open and 270 or 90 }) -- down (closed) ↔ up (open)
	end
	function self:SetOpen(b)
		popup:SetOpen(b)
	end

	local function toggleOption(opt, active)
		opt.Selected = active
		-- A tinted row keeps its own colour in BOTH states and is never re-tagged: a
		-- Retag re-attaches theme tracking and the next theme change would repaint it.
		-- Selection still reads clearly from the ✓ and the lit background.
		if opt.Tint then
			Tween.To(opt.Button, { TextColor3 = opt.Tint, BackgroundTransparency = active and 0.88 or 1 })
			if opt.Indicator then
				opt.Indicator.Text = active and "✓" or (data.Multi and "×" or "")
				opt.Indicator.TextColor3 = active and Color3.fromRGB(120, 230, 150) or Color3.fromRGB(235, 90, 90)
				opt.Indicator.TextTransparency = (active or data.Multi) and (active and 0 or 0.15) or 1
			end
			return
		end
		if active then
			Theme.Retag(opt.Button, { TextColor3 = "Accent" })
			Tween.To(opt.Button, { TextColor3 = Theme.Values.Accent, BackgroundTransparency = 0.88 })
			if opt.Indicator then
				opt.Indicator.Text = "✓"
				opt.Indicator.TextColor3 = Color3.fromRGB(120, 230, 150)
				opt.Indicator.TextTransparency = 0
			end
		else
			Theme.Retag(opt.Button, { TextColor3 = "Text" })
			Tween.To(opt.Button, { TextColor3 = Theme.Values.Text, BackgroundTransparency = 1 })
			if opt.Indicator then
				-- show a red × only for multi-select (where exclusion is meaningful)
				opt.Indicator.Text = data.Multi and "×" or ""
				opt.Indicator.TextColor3 = Color3.fromRGB(235, 90, 90)
				opt.Indicator.TextTransparency = data.Multi and 0.15 or 1
			end
		end
	end

	function self:Set(option)
		if data.Multi then
			if type(option) ~= "table" then return end
			self.Value = table.clone(option) -- copy so option clicks don't mutate the caller's table
			for _, opt in self.Options do opt.Selected = false; toggleOption(opt, false) end
			for _, name in option do
				local opt = self.Options[name]
				if opt then opt.Selected = true; toggleOption(opt, true) end
			end
		else
			local opt = self.Options[option]
			if not opt then return end
			self.Value = option
			for name, o in self.Options do
				o.Selected = (name == option)
				toggleOption(o, o.Selected)
			end
		end
		Library.Flags[self.Flag] = self.Value
		refreshText()
		if data.Callback then Library:SafeCall(data.Callback, self.Value) end
	end

	function self:Add(name: string)
		-- Optional per-item styling, so a caller can mirror a palette the player already
		-- knows from the game itself (a rarity ladder, a team colour) instead of a list of
		-- identical grey rows. Both are opt-in: with neither set this is byte-for-byte the
		-- old behaviour, which matters because every game shares this library.
		--   data.ItemColors    = { [name] = Color3 }
		--   data.ItemGradients = { [name] = ColorSequence }  -- shimmer for the top tiers
		-- A tinted row must NOT carry the TextColor3 ThemeTag: Theme.Retag would repaint it
		-- on the next theme change and the colour would silently disappear.
		local tint = data.ItemColors and data.ItemColors[name]
		local grad = data.ItemGradients and data.ItemGradients[name]
		-- A UIGradient MULTIPLIES the text colour, so a gradient row must stay near-white
		-- or the tint is applied twice and the result comes out muddy. The gradient is
		-- already carrying the colour in that case.
		local paint = grad and Color3.fromRGB(255, 255, 255) or tint
		local tag = paint and { BackgroundColor3 = "Hovered Element" }
			or { TextColor3 = "Text", BackgroundColor3 = "Hovered Element" }
		local btn = Create("TextButton", { Parent = list, FontFace = GetFont(), TextSize = 13,
			Text = name, AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 20), ZIndex = 51,
			TextColor3 = paint or Color3.fromRGB(235, 235, 235), BackgroundColor3 = Color3.fromRGB(37, 42, 45),
			ThemeTag = tag })
		trackTouchTarget(btn, 44, true)
		if tint then
			-- saturated tones sit on a mid-grey row; a dark stroke keeps them legible
			-- and reads as the glow the game puts behind its own rarity text
			btn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			btn.TextStrokeTransparency = 0.5
			btn.FontFace = Font.fromEnum(Enum.Font.GothamBold)
		end
		-- UIGradient tints the text while the row background is transparent, and the
		-- background too once hovered — so the hover picks up the same shimmer for free
		if grad then Create("UIGradient", { Parent = btn, Color = grad }) end
		Create("UIPadding", { Parent = btn, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 24) })
		Corner(btn, 3)
		-- selected/unselected indicator: green ✓ when picked, red × when not (multi)
		local indicator = Create("TextLabel", { Parent = btn, BackgroundTransparency = 1, ZIndex = 52,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(14, 14),
			FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 13, Text = "", TextColor3 = Color3.fromRGB(245, 110, 110) })
		-- Tint is carried on the option so toggleOption can honour it. Without this the
		-- initial unselected pass repaints every row to the theme text colour and the
		-- palette vanishes the instant the list is built.
		local opt = { Button = btn, Name = name, Selected = false, Indicator = indicator, Tint = paint }
		maid:GiveTask(btn.MouseEnter:Connect(function()
			if not opt.Selected then Tween.To(btn, { BackgroundTransparency = 0.5 }) end
		end))
		maid:GiveTask(btn.MouseLeave:Connect(function()
			if not opt.Selected then Tween.To(btn, { BackgroundTransparency = 1 }) end
		end))
		maid:GiveTask(btn.MouseButton1Click:Connect(function()
			if data.Multi then
				local idx = table.find(self.Value, name)
				if idx then table.remove(self.Value, idx) else table.insert(self.Value, name) end
				opt.Selected = idx == nil
				toggleOption(opt, opt.Selected)
				Library.Flags[self.Flag] = self.Value
				refreshText()
				if data.Callback then Library:SafeCall(data.Callback, self.Value) end
			else
				if self.Value == name and not data.Required then
					self.Value = nil
					opt.Selected = false
					toggleOption(opt, false)
					Library.Flags[self.Flag] = nil
					refreshText()
					if data.Callback then Library:SafeCall(data.Callback, nil) end
				else
					self:Set(name)
				end
			end
		end))
		self.Options[name] = opt
		toggleOption(opt, false) -- initial indicator state (× for multi, none for single)
		return opt
	end

	function self:Remove(name)
		local opt = self.Options[name]
		if opt then opt.Button:Destroy(); self.Options[name] = nil end
	end

	function self:Refresh(list)
		for name in self.Options do self:Remove(name) end
		for _, v in list do self:Add(v) end
		-- drop selections that no longer exist, then re-sync the display + flag
		if data.Multi then
			local kept = {}
			for _, name in (self.Value or {}) do if self.Options[name] then kept[#kept + 1] = name end end
			self:Set(kept)
		elseif self.Value ~= nil then
			if self.Options[self.Value] then
				-- rebuilt rows start unselected; re-apply the highlight for the kept value
				for name, o in self.Options do o.Selected = (name == self.Value); toggleOption(o, o.Selected) end
			else
				self.Value = nil
				Library.Flags[self.Flag] = nil
				refreshText()
			end
		end
	end

	maid:GiveTask(box.MouseButton1Click:Connect(function() self:SetOpen(not self.IsOpen) end))
	maid:GiveTask(box.MouseEnter:Connect(function()
		Theme.Retag(box, { BackgroundColor3 = "Hovered Element" })
		Tween.To(box, { BackgroundColor3 = Theme.Values["Hovered Element"] })
	end))
	maid:GiveTask(box.MouseLeave:Connect(function()
		Theme.Retag(box, { BackgroundColor3 = "Element" })
		Tween.To(box, { BackgroundColor3 = Theme.Values.Element })
	end))

	if searchInput then
		maid:GiveTask(searchInput:GetPropertyChangedSignal("Text"):Connect(function()
			keepCapability()
			local q = searchInput.Text:lower()
			for name, opt in self.Options do
				opt.Button.Visible = q == "" or (name:lower():find(q, 1, true) ~= nil)
			end
		end))
	end

	for _, v in (data.Items or {}) do self:Add(v) end
	refreshText()
	if data.Default then self:Set(data.Default) end
	registerSetter(self.Flag, function(v) self:Set(v) end, maid)
	if data.Tooltip then Tooltip.Bind(container, data.Tooltip, maid) end
	if data._SearchRegister then data._SearchRegister(data.Name or "Textbox", container, "Textbox", data) end
	return self
end

----------------------------------------------------------------- Colorpicker ---
function Components.Colorpicker(data)
	local maid = data.Maid
	local self = {
		Flag = data.Flag, IsOpen = false,
		Hue = 0, Sat = 0, Val = 1, Alpha = data.Alpha or 0,
		Color = Color3.fromRGB(255, 255, 255), HexValue = "ffffff",
	}

	-- swatch button (placed inline, e.g. inside a Label/Toggle sub-element row)
	local swatch = Create("TextButton", { Parent = data.Parent, Text = "", AutoButtonColor = false,
		Size = UDim2.fromOffset(15, 15), BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255), ThemeTag = { BorderColor3 = "Border" } })
	Stroke(swatch, "Outline")
	Corner(swatch, 3)

	local win = Create("Frame", { Parent = UnusedHolder, Visible = false, Solid = true,
		Size = UDim2.fromOffset(220, 200), BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(14, 17, 15), ZIndex = 60,
		ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	Stroke(win, "Outline")
	maid:GiveTask(win)
	Create("UIPadding", { Parent = win, PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })

	-- palette: hue base + saturation (white→clear, left→right) + value (clear→black, top→bottom).
	-- Built from gradients (not images) so orientation always matches the sat=x / val=1-y math.
	local palette = Create("TextButton", { Parent = win, Text = "", AutoButtonColor = false, Solid = true,
		Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -28, 1, -28), BorderSizePixel = 2,
		BorderColor3 = Color3.fromRGB(12, 12, 12), BackgroundColor3 = Color3.fromRGB(255, 0, 0), ZIndex = 61 })
	local satOverlay = Create("Frame", { Parent = palette, BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 62, Solid = true })
	Create("UIGradient", { Parent = satOverlay, Rotation = 0,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
	local valOverlay = Create("Frame", { Parent = palette, BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 63, Solid = true })
	Create("UIGradient", { Parent = valOverlay, Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) })
	local paletteDot = Create("Frame", { Parent = palette, Size = UDim2.fromOffset(6, 6), ZIndex = 64,
		BorderColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 1, BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		AnchorPoint = Vector2.new(0.5, 0.5) })
	Create("UICorner", { Parent = paletteDot, CornerRadius = UDim.new(1, 0) })

	-- hue strip
	local hue = Create("TextButton", { Parent = win, Text = "", AutoButtonColor = false, Solid = true,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 20, 1, -28),
		BorderSizePixel = 2, BorderColor3 = Color3.fromRGB(12, 12, 12), ZIndex = 61,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
	Create("UIGradient", { Parent = hue, Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
		ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,255,0)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0,255,255)),
		ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,0,255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0)),
	}) })
	local hueDot = Create("Frame", { Parent = hue, Size = UDim2.new(1, 0, 0, 2), ZIndex = 62,
		BorderColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 1, BackgroundColor3 = Color3.fromRGB(255, 255, 255) })

	-- alpha bar
	local alpha = Create("TextButton", { Parent = win, Text = "", AutoButtonColor = false, Solid = true,
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, -28, 0, 20),
		BorderSizePixel = 2, BorderColor3 = Color3.fromRGB(12, 12, 12), ZIndex = 61,
		BackgroundColor3 = Color3.fromRGB(255, 0, 0) })
	local checkers = Library:GetImage("Checkers")
	if checkers ~= "" then
		local c = Create("ImageLabel", { Parent = alpha, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(6, 6), Image = checkers, ZIndex = 60 })
		Create("UIGradient", { Parent = c, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.37, 0.5),
			NumberSequenceKeypoint.new(1, 0),
		}) })
	end
	local alphaDot = Create("Frame", { Parent = alpha, Size = UDim2.new(0, 2, 1, 0), ZIndex = 62,
		BorderColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 1, BackgroundColor3 = Color3.fromRGB(255, 255, 255) })

	function self:Get() return self.Color, self.Alpha end
	function self:SetVisibility(b) swatch.Visible = b end

	local function update(fromAlpha)
		self.Color = Color3.fromHSV(self.Hue, self.Sat, self.Val)
		self.HexValue = self.Color:ToHex()
		Library.Flags[self.Flag] = { Color = self.HexValue, Alpha = self.Alpha }
		Tween.To(swatch, { BackgroundColor3 = self.Color })
		palette.BackgroundColor3 = Color3.fromHSV(self.Hue, 1, 1)
		if not fromAlpha then alpha.BackgroundColor3 = self.Color end
		if data.Callback then Library:SafeCall(data.Callback, self.Color, self.Alpha) end
	end

	function self:Set(color, a)
		-- capture alpha BEFORE reassigning color (original bug #2)
		if type(color) == "table" then
			a = a or color[4]
			color = Color3.fromRGB(color[1], color[2], color[3])
		elseif type(color) == "string" then
			color = Color3.fromHex((color:gsub("#", "")))
		end
		self.Hue, self.Sat, self.Val = color:ToHSV()
		self.Alpha = a or self.Alpha or 0
		paletteDot.Position = UDim2.fromScale(self.Sat, 1 - self.Val)
		hueDot.Position = UDim2.fromScale(0, math.clamp(self.Hue, 0, 0.995))
		alphaDot.Position = UDim2.fromScale(math.clamp(self.Alpha, 0, 0.995), 0)
		update(false)
	end

	-- popup open/close via generic fade
	function self:SetOpen(open)
		if open == self.IsOpen then return end -- idempotent; no debounce so a mid-open popup can still be closed
		self.IsOpen = open
		if open then
			CloseAllPopups(self)
			OpenPopups[self] = true
			win.Visible = true
			win.Parent = Holder
			Anchors[win] = function()
				local ap, as = swatch.AbsolutePosition, swatch.AbsoluteSize
				win.Position = UDim2.fromOffset(ap.X, ap.Y + as.Y + 6)
			end
		else
			OpenPopups[self] = nil
			Anchors[win] = nil
		end
		local last = Tween.Fade(win, open, Config.FadeSpeed)
		local function done()
			if not win.Parent then return end
			keepCapability()
			win.Visible = self.IsOpen
			if not self.IsOpen then win.Parent = UnusedHolder end
		end
		if last then last.Completed:Once(done) else done() end
	end
	maid:GiveTask(function() OpenPopups[self] = nil; Anchors[win] = nil end) -- forget on cleanup

	-- dragging the palette / hue / alpha. InputPos() maps the event's own position
	-- (mouse OR touch) into AbsolutePosition space, so the marker tracks the pointer.
	local function bindDrag(button, onMove)
		local stopMove
		maid:GiveTask(function() if stopMove then stopMove() end end)
		maid:GiveTask(button.InputBegan:Connect(function(input)
			if Input.isPrimary(input) then
				onMove(InputPos(input))
				if stopMove then stopMove() end
			stopMove = Input.On("Changed", function(inp) if matchesGesture(inp, input) then onMove(InputPos(inp)) end end)
				local conn
				conn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						if stopMove then stopMove(); stopMove = nil end
						conn:Disconnect()
					end
				end)
				maid:GiveTask(conn)
			end
		end))
	end

	bindDrag(palette, function(m)
		local sx = math.clamp((m.X - palette.AbsolutePosition.X) / palette.AbsoluteSize.X, 0, 1)
		local sy = math.clamp((m.Y - palette.AbsolutePosition.Y) / palette.AbsoluteSize.Y, 0, 1)
		self.Sat, self.Val = sx, 1 - sy
		paletteDot.Position = UDim2.fromScale(sx, sy)
		update(false)
	end)
	bindDrag(hue, function(m)
		local hy = math.clamp((m.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 1)
		self.Hue = hy
		hueDot.Position = UDim2.fromScale(0, math.min(hy, 0.995))
		update(false)
	end)
	bindDrag(alpha, function(m)
		local ax = math.clamp((m.X - alpha.AbsolutePosition.X) / alpha.AbsoluteSize.X, 0, 1)
		self.Alpha = ax
		alphaDot.Position = UDim2.fromScale(math.min(ax, 0.995), 0)
		update(true)
	end)

	maid:GiveTask(swatch.MouseButton1Click:Connect(function() self:SetOpen(not self.IsOpen) end))
	maid:GiveTask(Input.On("Began", function(input)
		if not self.IsOpen or not Input.isPrimary(input) then return end
		if isMouseOver(win) or isMouseOver(swatch) then return end
		self:SetOpen(false)
	end))

	self:Set(data.Default or Color3.fromRGB(255, 255, 255), data.Alpha or 0)
	registerSetter(self.Flag, function(v, a) self:Set(v, a) end, maid)
	if data._SearchRegister then data._SearchRegister(data.Name or "Colorpicker", swatch, "Colorpicker", data) end
	return self
end

-------------------------------------------------------------------- Keybind ---
local KEY_DISPLAY = {
	RightControl = "RControl", LeftControl = "LControl", RightShift = "RShift", LeftShift = "LShift",
	LeftAlt = "LAlt", RightAlt = "RAlt", Backspace = "None", Return = "Enter", Escape = "Esc",
	MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3",
}

function Components.Keybind(data)
	local maid = data.Maid
	local self = { Flag = data.Flag, Key = "", Value = "None", Mode = data.Mode or "Toggle",
		Toggled = false, Picking = false, IsOpen = false }

	local keyListEntry
	if Library.KeyList then
		keyListEntry = Library.KeyList:Add("None", data.Name or "Keybind", self.Mode)
		maid:GiveTask(function() keyListEntry:Remove() end)
	end

	local btn = Create("TextButton", { Parent = data.Parent, FontFace = GetFont(), TextSize = 12,
		Text = "[None]", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextTransparency = 0.35,
		TextColor3 = Color3.fromRGB(235, 235, 235), ThemeTag = { TextColor3 = "Text" } })
	TextStroke(btn)

	-- mode picker popup (styled like dropdown options)
	local win = Create("Frame", { Parent = UnusedHolder, Visible = false, Solid = true, Size = UDim2.fromOffset(96, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(20, 24, 21), ZIndex = 60,
		ThemeTag = { BackgroundColor3 = "Inline", BorderColor3 = "Border" } })
	Stroke(win, "Outline")
	Corner(win, 4)
	maid:GiveTask(win)
	Create("UIListLayout", { Parent = win, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
	Create("UIPadding", { Parent = win, PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })

	local modeButtons = {}
	for _, mode in { "Toggle", "Hold", "Always" } do
		local mb = Create("TextButton", { Parent = win, FontFace = GetFont(), TextSize = 13, Text = mode,
			AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 20), BorderSizePixel = 0, ZIndex = 61,
			TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
			BackgroundColor3 = Color3.fromRGB(37, 42, 45), TextColor3 = Color3.fromRGB(235, 235, 235),
			ThemeTag = { BackgroundColor3 = "Hovered Element", TextColor3 = "Text" } })
		Create("UIPadding", { Parent = mb, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
		Corner(mb, 3)
		modeButtons[mode] = mb
		maid:GiveTask(mb.MouseEnter:Connect(function()
			if self.Mode ~= mode then Tween.To(mb, { BackgroundTransparency = 0.5 }) end
		end))
		maid:GiveTask(mb.MouseLeave:Connect(function()
			if self.Mode ~= mode then Tween.To(mb, { BackgroundTransparency = 1 }) end
		end))
		maid:GiveTask(mb.MouseButton1Click:Connect(function() self:SetMode(mode) end))
	end

	local function flagState()
		Library.Flags[self.Flag] = { Key = self.Key, Mode = self.Mode, Toggled = self.Toggled }
	end

	function self:Get() return self.Key, self.Mode, self.Toggled end
	-- Callback means "the bind fired" and is raised by Press() alone. Changing WHICH key is
	-- bound, or its mode, raises OnChanged instead -- restoring a saved binding is not the
	-- user activating it. Conflating the two made LoadConfig run every keybind's action:
	-- the hub's kill switch is a keybind, so loading a config silently turned every toggle
	-- back off, sparing only the ones pairs() happened to restore after it.
	-- `silent` is for callers that raise OnChanged themselves, so it fires once per change.
	function self:SetMode(mode, silent)
		self.Mode = mode
		for m, mb in modeButtons do
			if m == mode then
				Theme.Retag(mb, { TextColor3 = "Accent" })
				Tween.To(mb, { BackgroundTransparency = 0.85, TextColor3 = Theme.Values.Accent })
			else
				Theme.Retag(mb, { TextColor3 = "Text" })
				Tween.To(mb, { BackgroundTransparency = 1, TextColor3 = Theme.Values.Text })
			end
		end
		flagState()
		if keyListEntry then keyListEntry:SetText(self.Value, data.Name or "Keybind", self.Mode) end
		if not silent and data.OnChanged then Library:SafeCall(data.OnChanged, self.Key, self.Mode, self.Toggled) end
	end

	local function display(key: string): string
		return KEY_DISPLAY[key] or key
	end

	function self:Set(key)
		if typeof(key) == "EnumItem" then
			local name = key.Name
			self.Key = tostring(key)
			self.Value = (name == "Backspace") and "None" or name
			btn.Text = "[" .. display(self.Value) .. "]"
			flagState()
		elseif type(key) == "table" then
			self.Key = tostring(key.Key)
			-- normalize the display value from the stored Enum string (escaped dots)
			local clean = tostring(key.Key):gsub("Enum%.KeyCode%.", ""):gsub("Enum%.UserInputType%.", "")
			self.Value = (clean == "" and "None") or display(clean) -- restore the None sentinel for unbound keys (avoid "[]")
			btn.Text = "[" .. self.Value .. "]"
			if key.Mode then self:SetMode(key.Mode, true) end
			if key.Toggled ~= nil then self.Toggled = key.Toggled end
			flagState()
		elseif type(key) == "string" and (key == "Toggle" or key == "Hold" or key == "Always") then
			self:SetMode(key, true)
		end
		if keyListEntry then keyListEntry:SetText(self.Value, data.Name or "Keybind", self.Mode) end
		self.Picking = false
		if data.OnChanged then Library:SafeCall(data.OnChanged, self.Key, self.Mode, self.Toggled) end
	end

	function self:Press(state)
		if self.Mode == "Toggle" then self.Toggled = not self.Toggled
		elseif self.Mode == "Hold" then self.Toggled = state
		elseif self.Mode == "Always" then self.Toggled = true end
		flagState()
		if keyListEntry then keyListEntry:SetStatus(self.Toggled) end
		if data.Callback then Library:SafeCall(data.Callback, self.Toggled) end
	end

	function self:SetOpen(open)
		if open == self.IsOpen then return end -- idempotent; no debounce so a mid-open popup can still be closed
		self.IsOpen = open
		if open then
			CloseAllPopups(self)
			OpenPopups[self] = true
			win.Visible = true; win.Parent = Holder
			Anchors[win] = function()
				local ap, as = btn.AbsolutePosition, btn.AbsoluteSize
				win.Position = UDim2.fromOffset(ap.X, ap.Y + as.Y + 6)
			end
		else
			OpenPopups[self] = nil; Anchors[win] = nil
		end
		local last = Tween.Fade(win, open, Config.FadeSpeed)
		local function done()
			if not win.Parent then return end
			keepCapability()
			win.Visible = self.IsOpen
			if not self.IsOpen then win.Parent = UnusedHolder end
		end
		if last then last.Completed:Once(done) else done() end
	end
	maid:GiveTask(function() OpenPopups[self] = nil; Anchors[win] = nil end) -- forget on cleanup

	local pickConn
	maid:GiveTask(function() if pickConn then pickConn:Disconnect() end end) -- one stable cleanup; disconnects a pending pick on unload
	maid:GiveTask(btn.MouseButton1Click:Connect(function()
		if self.Picking then return end -- already waiting for a key; ignore re-clicks
		self.Picking = true
		btn.Text = "[...]"
		if pickConn then pickConn:Disconnect() end
		pickConn = UserInputService.InputBegan:Connect(function(input, gpe)
			-- ignore the UI clicks themselves (LMB/RMB) so re-clicking doesn't bind a mouse button
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2 then return end
			pickConn:Disconnect(); pickConn = nil
			if input.KeyCode == Enum.KeyCode.Escape then -- cancel without rebinding
				self.Picking = false
				btn.Text = "[" .. self.Value .. "]"
				return
			end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				self:Set(input.KeyCode)
			else
				self:Set(input.UserInputType)
			end
		end)
	end))
	maid:GiveTask(btn.MouseButton2Click:Connect(function() self:SetOpen(not self.IsOpen) end))

	maid:GiveTask(Input.On("Began", function(input)
		if self.Value == "None" then return end
		-- don't fire binds while the user is typing in a text box
		if not UserInputService:GetFocusedTextBox() then
			local id = (input.KeyCode ~= Enum.KeyCode.Unknown) and tostring(input.KeyCode) or tostring(input.UserInputType)
			if id == self.Key then
				if self.Mode == "Toggle" then self:Press()
				elseif self.Mode == "Hold" then self:Press(true)
				elseif self.Mode == "Always" then self:Press(true) end
			end
		end
		if Input.isPrimary(input) and self.IsOpen and not isMouseOver(win) and not isMouseOver(btn) then
			self:SetOpen(false)
		end
	end))
	maid:GiveTask(Input.On("Ended", function(input)
		if self.Value == "None" or self.Mode ~= "Hold" then return end
		local id = (input.KeyCode ~= Enum.KeyCode.Unknown) and tostring(input.KeyCode) or tostring(input.UserInputType)
		if id == self.Key then self:Press(false) end
	end))

	self:SetMode(self.Mode)
	if data.Default then self:Set({ Key = data.Default, Mode = self.Mode }) end
	registerSetter(self.Flag, function(v) self:Set(v) end, maid)
	if data._SearchRegister then data._SearchRegister(data.Name or "Keybind", btn, "Keybind", data) end
	return self
end

local FeatureSearch = (function()
local FeatureSearch = {}

function FeatureSearch.normalize(value)
    local text = tostring(value or "")
    text = text:gsub("<[^>]*>", " "):gsub("(%l)(%u)", "%1 %2")
    -- // Ignore menu artwork without discarding non-Latin feature names. \\ --
    local valid, plain = pcall(function()
        local characters = {}
        for _, point in utf8.codes(text) do
            local icon = (point >= 0x1F000 and point <= 0x1FAFF)
                or (point >= 0x2300 and point <= 0x23FF) or (point >= 0x25A0 and point <= 0x27BF)
                or (point >= 0xFE00 and point <= 0xFE0F) or point == 0x200D or point == 0x20E3
            characters[#characters + 1] = icon and " " or utf8.char(point)
        end
        return table.concat(characters)
    end)
    if valid then text = plain end
    return (text:lower():gsub("[%p%c]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$"))
end

local function prepare(entry)
    entry._SearchName = FeatureSearch.normalize(entry.Name)
    entry._SearchSection = FeatureSearch.normalize(entry.SectionName)
    entry._SearchTab = FeatureSearch.normalize(entry.TabName)
    entry._SearchFlag = FeatureSearch.normalize(entry.Flag)
    entry._SearchTooltip = FeatureSearch.normalize(entry.Tooltip)
    entry._SearchText = table.concat({ entry._SearchName, entry._SearchSection,
        entry._SearchTab, entry._SearchFlag, entry._SearchTooltip }, " ")
    return entry
end

-- // Matching is independent of GUI state and never invokes a control callback. \\ --
function FeatureSearch.search(entries, query, limit)
    query = FeatureSearch.normalize(query)
    if query == "" or type(entries) ~= "table" then return {} end
    local terms = {}
    for term in query:gmatch("%S+") do terms[#terms + 1] = term end
    local matches = {}
    for index, entry in ipairs(entries) do
        if type(entry) == "table" then
            if not entry._SearchText then prepare(entry) end
            local score = 0
            local found = true
            for _, term in ipairs(terms) do
                if not entry._SearchText:find(term, 1, true) then found = false; break end
                if entry._SearchName:find(term, 1, true) then score += 0
                elseif entry._SearchSection:find(term, 1, true) then score += 10
                elseif entry._SearchTab:find(term, 1, true) then score += 15
                elseif entry._SearchFlag:find(term, 1, true) then score += 20
                else score += 25 end
            end
            if found then
                if entry._SearchName == query then score -= 100
                elseif entry._SearchName:sub(1, #query) == query then score -= 70
                elseif entry._SearchName:find(query, 1, true) then score -= 40 end
                matches[#matches + 1] = { Entry = entry, Score = score,
                    Order = entry._SearchOrdinal or index, InputOrder = index }
            end
        end
    end
    table.sort(matches, function(a, b)
        if a.Score ~= b.Score then return a.Score < b.Score end
        if a.Order ~= b.Order then return a.Order < b.Order end
        return a.InputOrder < b.InputOrder
    end)
    local results = {}
    local count = limit == nil and #matches or math.clamp(math.floor(tonumber(limit) or 0), 0, #matches)
    for index = 1, count do results[index] = matches[index].Entry end
    return results
end

function FeatureSearch.isAvailable(entry)
    if type(entry) ~= "table" or not entry.Target or not entry.Tab or not entry.Tab.Page then return false end
    local target, page = entry.Target, entry.Tab.Page
    if not target.Parent or not page.Parent then return false end
    local at = target
    while at and at ~= page do
        if at:IsA("GuiObject") and not at.Visible then return false end
        if at:IsA("CanvasGroup") and at.GroupTransparency >= 0.99 then return false end
        at = at.Parent
    end
    -- // An inactive tab deliberately hides its page and moves it to UnusedHolder. \\ --
    return at == page
end

function FeatureSearch.attach(window, body, launcher, maid, ui)
    local controller = { IsOpen = false, Entries = {}, Results = {} }
    local destroyed = false
    local byTarget, connections, rows, ownedRefreshers = {}, {}, {}, {}
    local selected, navigation, refreshQueued = 1, 0, false
    local highlight
    local Create, MakeText = ui.Create, ui.MakeText
    local function own(connection)
        connections[#connections + 1] = connection
        return connection
    end
    local function restore() if ui.keepCapability then ui.keepCapability() end end
    local function touchTarget(gui)
        if not ui.trackTouchTarget then return end
        local before = ui.DeviceRefreshers and #ui.DeviceRefreshers or 0
        ui.trackTouchTarget(gui, 44)
        if ui.DeviceRefreshers then
            for index = before + 1, #ui.DeviceRefreshers do ownedRefreshers[ui.DeviceRefreshers[index]] = true end
        end
    end
    local function clearHighlight()
        if highlight then highlight:Destroy(); highlight = nil end
    end
    local overlay = Create("Frame", { Parent = body, Name = "FeatureSearchOverlay",
        Visible = false, BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 80 })
    controller.Frame = overlay
    local backdrop = Create("TextButton", { Parent = overlay, Name = "FeatureSearchBackdrop",
        Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.3, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 80 })
    local panel = Create("Frame", { Parent = overlay, Name = "FeatureSearchPanel", Solid = true,
        Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 1, -12),
        BackgroundColor3 = ui.Theme.Values.Inline, BorderColor3 = ui.Theme.Values.Border,
        BorderSizePixel = 1, ZIndex = 81, Active = true,
        ThemeTag = { BackgroundColor3 = "Inline", BorderColor3 = "Border" } })
    ui.Corner(panel, 4)
    local title = MakeText(panel, "Search features", { Name = "FeatureSearchTitle", Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -72, 0, 24), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 82 })
    local close = Create("TextButton", { Parent = panel, Name = "FeatureSearchClose", Text = "×",
        AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.new(1, -48, 0, 0), Size = UDim2.fromOffset(44, 40), TextSize = 24,
        TextColor3 = ui.Theme.Values.Text, ThemeTag = { TextColor3 = "Text" }, ZIndex = 83 })
    local inputFrame = Create("Frame", { Parent = panel, Position = UDim2.fromOffset(12, 40),
        Size = UDim2.new(1, -24, 0, 44), BackgroundColor3 = ui.Theme.Values.Element,
        BorderSizePixel = 0, ZIndex = 82, ThemeTag = { BackgroundColor3 = "Element" } })
    ui.Corner(inputFrame, 4)
    ui.Stroke(inputFrame, "Border")
    local input = Create("TextBox", { Parent = inputFrame, Name = "FeatureSearchInput", Text = "",
        PlaceholderText = "Find a feature, e.g. auto roll or fruit ESP", ClearTextOnFocus = false,
        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -56, 1, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = ui.Theme.Values.Text, PlaceholderColor3 = ui.Theme.Values["Placeholder Text"],
        FontFace = ui.GetFont and ui.GetFont() or Font.fromEnum(Enum.Font.Gotham),
        ThemeTag = { TextColor3 = "Text", PlaceholderColor3 = "Placeholder Text" }, ZIndex = 83 })
    controller.Input = input
    local clear = Create("TextButton", { Parent = inputFrame, Name = "FeatureSearchClear", Text = "×",
        AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.new(1, -44, 0, 0), Size = UDim2.fromOffset(44, 44), TextSize = 22,
        TextColor3 = ui.Theme.Values["Placeholder Text"], ThemeTag = { TextColor3 = "Placeholder Text" }, ZIndex = 84 })
    local count = MakeText(panel, "Type a feature name to search every tab.", {
        Name = "FeatureSearchCount", Position = UDim2.fromOffset(12, 88), Size = UDim2.new(1, -24, 0, 20),
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        ThemeTag = { TextColor3 = "Placeholder Text" }, ZIndex = 82 })
    local list = Create("ScrollingFrame", { Parent = panel, Name = "FeatureSearchResults",
        Position = UDim2.fromOffset(12, 112), Size = UDim2.new(1, -24, 1, -124),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 82 })
    Create("UIListLayout", { Parent = list, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
    local empty = MakeText(list, "", { Name = "FeatureSearchEmpty", Size = UDim2.new(1, -8, 0, 50),
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        ThemeTag = { TextColor3 = "Placeholder Text" }, Visible = false, ZIndex = 83 })
    touchTarget(inputFrame)
    touchTarget(close)
    touchTarget(clear)
    local rowHeight = 48
    local function layoutRow(row)
        row.Button.Size = UDim2.new(1, -6, 0, rowHeight)
        local textY = math.max(6, (rowHeight - 36) / 2)
        row.Title.Position = UDim2.fromOffset(10, textY)
        row.Path.Position = UDim2.fromOffset(10, textY + 20)
    end
    local function refreshGeometry()
        if destroyed then return end
        restore()
        local mobile = ui.Device and ui.Device.Mode == "Mobile"
        local scale = math.max(0.01, tonumber(ui.Config.Scale) or 1)
        local touch = mobile and 44 / scale or 0
        local titleHeight, inputHeight = math.max(40, touch), math.max(44, touch)
        local closeWidth, clearWidth = math.max(44, touch), math.max(44, touch)
        rowHeight = math.max(48, touch)
        title.Size = UDim2.new(1, -closeWidth - 28, 0, titleHeight - 12)
        close.Position, close.Size = UDim2.new(1, -closeWidth - 4, 0, 0), UDim2.fromOffset(closeWidth, titleHeight)
        inputFrame.Position, inputFrame.Size = UDim2.fromOffset(12, titleHeight + 4), UDim2.new(1, -24, 0, inputHeight)
        input.Size = UDim2.new(1, -clearWidth - 14, 1, 0)
        clear.Position, clear.Size = UDim2.new(1, -clearWidth, 0, 0), UDim2.fromOffset(clearWidth, inputHeight)
        local countY = titleHeight + inputHeight + 8
        count.Position = UDim2.fromOffset(12, countY)
        local top = countY + 24
        list.Position, list.Size = UDim2.fromOffset(12, top), UDim2.new(1, -24, 1, -top - 12)
        for _, row in ipairs(rows) do layoutRow(row) end
    end
    refreshGeometry()
    if ui.DeviceRefreshers then
        ui.DeviceRefreshers[#ui.DeviceRefreshers + 1] = refreshGeometry
        ownedRefreshers[refreshGeometry] = true
    end

    function controller:Search(query)
        if destroyed then return {} end
        local entries = {}
        for _, entry in ipairs(self.Entries) do
            if FeatureSearch.isAvailable(entry) then entries[#entries + 1] = entry end
        end
        return FeatureSearch.search(entries, query)
    end

    function controller:Navigate(entry)
        if destroyed or not FeatureSearch.isAvailable(entry) then return false end
        restore()
        self:SetOpen(false)
        entry.Tab:Select()
        navigation += 1
        local ownNavigation = navigation
        task.defer(function()
            task.wait()
            if destroyed or navigation ~= ownNavigation or not FeatureSearch.isAvailable(entry)
                or window.CurrentTab ~= entry.Tab then return end
            restore()
            local at = entry.Target.Parent
            local scrolling
            while at and at ~= entry.Tab.Page do
                if at:IsA("ScrollingFrame") then scrolling = at; break end
                at = at.Parent
            end
            if scrolling then
                -- // CanvasPosition and absolute geometry both use rendered pixels, including UIScale. \\ --
                local offset = entry.Target.AbsolutePosition.Y - scrolling.AbsolutePosition.Y
                local maxY = math.max(0, scrolling.AbsoluteCanvasSize.Y - scrolling.AbsoluteWindowSize.Y)
                scrolling.CanvasPosition = Vector2.new(scrolling.CanvasPosition.X,
                    math.clamp(scrolling.CanvasPosition.Y + offset - 12, 0, maxY))
            end
            clearHighlight()
            highlight = Create("UIStroke", { Parent = entry.Target, Name = "FeatureSearchHighlight",
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Transparency = 0,
                Color = ui.Theme.Values.Accent, ThemeTag = { Color = "Accent" } })
            local ownHighlight = highlight
            task.delay(2, function()
                if destroyed or highlight ~= ownHighlight then return end
                restore()
                clearHighlight()
            end)
        end)
        return true
    end

    local function updateSelection()
        for index, row in ipairs(rows) do
            local active = index == selected and row.Button.Visible
            row.Button.BackgroundTransparency = active and 0 or 0.5
            row.Marker.Visible = active
        end
    end
    local function getRow(index)
        if rows[index] then return rows[index] end
        local button = Create("TextButton", { Parent = list, Name = "FeatureSearchResult" .. index,
            Text = "", AutoButtonColor = false, Size = UDim2.new(1, -6, 0, 48), LayoutOrder = index,
            BackgroundColor3 = ui.Theme.Values.Element, BackgroundTransparency = 0.5,
            BorderSizePixel = 0, ZIndex = 83, ThemeTag = { BackgroundColor3 = "Element" } })
        ui.Corner(button, 3)
        local marker = Create("Frame", { Parent = button, Size = UDim2.new(0, 2, 1, -8),
            Position = UDim2.fromOffset(0, 4), BorderSizePixel = 0, BackgroundColor3 = ui.Theme.Values.Accent,
            ThemeTag = { BackgroundColor3 = "Accent" }, ZIndex = 84 })
        local title = MakeText(button, "", { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18),
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 84 })
        local path = MakeText(button, "", { Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 16),
            TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            ThemeTag = { TextColor3 = "Placeholder Text" }, ZIndex = 84 })
        local row = { Button = button, Title = title, Path = path, Marker = marker }
        rows[index] = row
        touchTarget(button)
        layoutRow(row)
        own(button.Activated:Connect(function()
            if row.Entry then controller:Navigate(row.Entry) end
        end))
        own(button.MouseEnter:Connect(function() selected = index; updateSelection() end))
        return row
    end
    local function refresh()
        if destroyed or not controller.IsOpen then return end
        restore()
        local query = input.Text:sub(1, 160)
        local results = controller:Search(query)
        controller.Results = results
        selected = math.clamp(selected, 1, math.max(1, math.min(50, #results)))
        local blank = FeatureSearch.normalize(query) == ""
        count.Text = blank and "Type a feature name to search every tab."
            or (#results > 50 and ("%d features found · showing the first 50"):format(#results)
                or ("%d feature%s found"):format(#results, #results == 1 and "" or "s"))
        empty.Visible = not blank and #results == 0
        empty.Text = "No matching features. Try a shorter name or a word such as farm, ESP or teleport."
        for index = 1, math.min(50, #results) do
            local row, entry = getRow(index), results[index]
            row.Entry, row.Button.Visible = entry, true
            row.Title.Text = tostring(entry.Name)
            row.Path.Text = tostring(entry.TabName or "Tab") .. "  >  " .. tostring(entry.SectionName or "Section")
        end
        for index = math.min(50, #results) + 1, #rows do
            rows[index].Button.Visible, rows[index].Entry = false, nil
        end
        clear.Visible = input.Text ~= ""
        updateSelection()
    end

    function controller:Register(entry)
        if destroyed or type(entry) ~= "table" or type(entry.Name) ~= "string" or entry.Name == "" or not entry.Target then return end
        local indexed = byTarget[entry.Target]
        if not indexed then
            indexed = { _SearchOrdinal = #self.Entries + 1 }
            self.Entries[#self.Entries + 1] = indexed
            byTarget[entry.Target] = indexed
        end
        for key, value in pairs(entry) do indexed[key] = value end
        prepare(indexed)
        if self.IsOpen and not refreshQueued then
            refreshQueued = true
            task.defer(function() refreshQueued = false; refresh() end)
        end
        return indexed
    end

    function controller:RenameTab(tab, name)
        for _, entry in self.Entries do
            if entry.Tab == tab then entry.TabName = name; prepare(entry) end
        end
        refresh()
    end
    function controller:RemoveTab(tab)
        navigation += 1
        clearHighlight()
        for i = #self.Entries, 1, -1 do
            local entry = self.Entries[i]
            if entry.Tab == tab then byTarget[entry.Target] = nil; table.remove(self.Entries, i) end
        end
        for i = #self.Results, 1, -1 do
            if self.Results[i].Tab == tab then table.remove(self.Results, i) end
        end
        for _, row in rows do
            if row.Entry and row.Entry.Tab == tab then row.Entry = nil; row.Button.Visible = false end
        end
        refresh()
    end

    function controller:SetOpen(open)
        if destroyed then return false end
        open = open == true
        if open and not window.IsOpen then return false end
        restore()
        if open then
            if window.SetMinimized then window:SetMinimized(false) end
            ui.CloseAllPopups()
            refreshGeometry()
        end
        self.IsOpen, overlay.Visible = open, open
        if open then
            refresh()
            task.defer(function()
                if not destroyed and self.IsOpen then restore(); input:CaptureFocus() end
            end)
        else
            if ui.UserInputService:GetFocusedTextBox() == input then input:ReleaseFocus(false) end
        end
        return true
    end
    function controller:Close() return self:SetOpen(false) end
    function controller:Destroy()
        if destroyed then return end
        restore()
        self:SetOpen(false)
        destroyed, navigation = true, navigation + 1
        for _, connection in ipairs(connections) do
            if type(connection) == "function" then connection() else connection:Disconnect() end
        end
        clearHighlight()
        overlay:Destroy()
        table.clear(self.Entries)
        table.clear(self.Results)
        table.clear(byTarget)
        table.clear(rows)
        table.clear(connections)
        if ui.DeviceRefreshers then
            for index = #ui.DeviceRefreshers, 1, -1 do
                if ownedRefreshers[ui.DeviceRefreshers[index]] then table.remove(ui.DeviceRefreshers, index) end
            end
        end
        table.clear(ownedRefreshers)
    end
    own(launcher.Activated:Connect(function() controller:SetOpen(not controller.IsOpen) end))
    own(close.Activated:Connect(function() controller:SetOpen(false) end))
    own(backdrop.Activated:Connect(function() controller:SetOpen(false) end))
    own(clear.Activated:Connect(function() input.Text = ""; input:CaptureFocus() end))
    own(input:GetPropertyChangedSignal("Text"):Connect(function()
        selected = 1
        list.CanvasPosition = Vector2.zero
        refresh()
    end))
    own(input.FocusLost:Connect(function(enterPressed)
        if enterPressed and controller.IsOpen and controller.Results[selected] then
            controller:Navigate(controller.Results[selected])
        end
    end))
    own(ui.Input.On("Began", function(key)
        if destroyed or not window.IsOpen then return end
        local focused = ui.UserInputService:GetFocusedTextBox()
        if controller.IsOpen then
            if key.KeyCode == Enum.KeyCode.Escape then controller:SetOpen(false); return end
            if focused ~= nil and focused ~= input then return end
            if key.KeyCode == Enum.KeyCode.Down or key.KeyCode == Enum.KeyCode.Up then
                local length = math.min(50, #controller.Results)
                if length > 0 then
                    selected = ((selected - 1 + (key.KeyCode == Enum.KeyCode.Down and 1 or -1)) % length) + 1
                    updateSelection()
                    local row = rows[selected].Button
                    local top, bottom = row.AbsolutePosition.Y, row.AbsolutePosition.Y + row.AbsoluteSize.Y
                    local viewTop = list.AbsolutePosition.Y
                    local viewBottom = viewTop + list.AbsoluteWindowSize.Y
                    local shift = top < viewTop and top - viewTop or (bottom > viewBottom and bottom - viewBottom or 0)
                    local maxY = math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y)
                    list.CanvasPosition = Vector2.new(list.CanvasPosition.X, math.clamp(list.CanvasPosition.Y + shift, 0, maxY))
                end
                return
            end
        end
        if key.KeyCode == Enum.KeyCode.F and not focused and
            (ui.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or ui.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            controller:SetOpen(true)
        end
    end))
    maid:GiveTask(function() controller:Destroy() end)
    return controller
end

return FeatureSearch
end)()
Library.FeatureSearchVersion = "v1.0.0"

--==============================================================================
-- Window / Tab / Section
--==============================================================================

function Library:SetDeviceMode(preference)
	if not validDevicePreference(preference) then return false end
	Device.Preference = preference
	Device.Mode = preference == "Auto" and Device.Detected or preference
	saveDevicePreference(preference)
	for i = #DeviceRefreshers, 1, -1 do
		if not pcall(DeviceRefreshers[i]) then table.remove(DeviceRefreshers, i) end
	end
	CursorBg.Visible = Config.CustomCursor and menuOpen and Device.Mode == "PC"
	UserInputService.MouseIconEnabled = not CursorBg.Visible
	refreshGlass()
	return true
end

function Library:Window(data: WindowConfig?)
	data = data or {}
	if data.Keybind then Config.MenuKeybind = data.Keybind end
	local maid = Maid.new()
	LibMaid:GiveTask(maid)

	local window = {
		Maid = maid,
		Tabs = {},
		FadeTime = data.FadeTime or 0.3,
		IsOpen = false,
		CurrentTab = nil,
	}
	local featureSearchEnabled = data.FeatureSearch
	if featureSearchEnabled == nil then featureSearchEnabled = Config.FeatureSearch end

	local size = data.Size or UDim2.fromOffset(720, 520)
	local layoutMode = (data.Layout == "Top" or data.Layout == "top") and "Top" or "Side"
	window.Layout = layoutMode
	window.PreferredLayout = layoutMode
	local TITLEBAR_H = Device.Mode == "Mobile" and 44 / Config.Scale or 30
	local hasLogo = data.Logo and data.Logo ~= ""

	local root = Create("Frame", { Parent = Holder, Visible = false, ClipsDescendants = true,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size,
		BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(14, 17, 15),
		ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	Stroke(root, "Outline")
	Corner(root, 6)
	trackScale(root)
	window._root = root
	table.insert(Library._windows, window) -- for save/restore of position in config
	local resizeGrip = (data.Resizable ~= false) and MakeResizable(root, Vector2.new(520, 320), maid) or nil

	-- title bar: logo + title (left), window controls (right); also the drag handle
	local titlebar = Create("Frame", { Parent = root, BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, TITLEBAR_H) })
	MakeDraggable(root, titlebar, maid)
	if hasLogo then
		Create("ImageLabel", { Parent = titlebar, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(18, 18), ScaleType = Enum.ScaleType.Fit,
			Image = AssetUrl(data.Logo), ImageColor3 = Color3.fromRGB(202, 243, 255),
			ThemeTag = { ImageColor3 = "Accent" } })
	end
	local titleText = MakeText(titlebar, data.Title or "BloxUI", { AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, hasLogo and 38 or 12, 0.5, 0), Size = UDim2.new(1, -(hasLogo and 138 or 112), 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14 })
	Create("Frame", { Parent = titlebar, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(202, 243, 255),
		ThemeTag = { BackgroundColor3 = "Accent" } })

	local controls = Create("Frame", { Parent = titlebar, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X })
	Create("UIListLayout", { Parent = controls, FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })

	local function controlButton(order)
		local b = Create("TextButton", { Parent = controls, Text = "", AutoButtonColor = false,
			Size = UDim2.fromOffset(20, 20), LayoutOrder = order, BackgroundTransparency = 1,
			BackgroundColor3 = Color3.fromRGB(37, 42, 45), ThemeTag = { BackgroundColor3 = "Hovered Element" } })
		Corner(b, 3)
		local function refresh()
			local dimension = Device.Mode == "Mobile" and 40 / Config.Scale or 20
			b.Size = UDim2.fromOffset(dimension, dimension)
		end
		refresh()
		table.insert(DeviceRefreshers, refresh)
		maid:GiveTask(b.MouseEnter:Connect(function() Tween.To(b, { BackgroundTransparency = 0.4 }) end))
		maid:GiveTask(b.MouseLeave:Connect(function() Tween.To(b, { BackgroundTransparency = 1 }) end))
		return b
	end

	-- body: everything below the title bar; collapses on minimize
	local body = Create("Frame", { Parent = root, BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, TITLEBAR_H), Size = UDim2.new(1, 0, 1, -TITLEBAR_H) })

	-- Both layout containers are built; only the active one is shown, so the
	-- layout can be switched live. Each tab makes a button in BOTH holders.
	local content = Create("Frame", { Parent = body, BackgroundTransparency = 1, BorderSizePixel = 0 })

	local sideContainer = Create("Frame", { Parent = body, Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(0, 178, 1, -18), BorderColor3 = Color3.fromRGB(42, 49, 45), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(20, 24, 21), ThemeTag = { BackgroundColor3 = "Inline", BorderColor3 = "Outline" } })
	Stroke(sideContainer, "Border"); Corner(sideContainer)
	local sideHolder = Create("ScrollingFrame", { Parent = sideContainer, BackgroundTransparency = 1,
		BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y,
		Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 1, -16) })
	Create("UIPadding", { Parent = sideHolder, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	Create("UIListLayout", { Parent = sideHolder, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

	local topContainer = Create("Frame", { Parent = body, Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 30), BorderColor3 = Color3.fromRGB(42, 49, 45), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(20, 24, 21), ThemeTag = { BackgroundColor3 = "Inline", BorderColor3 = "Outline" } })
	Stroke(topContainer, "Border"); Corner(topContainer)
	local topHolder = Create("ScrollingFrame", { Parent = topContainer, BackgroundTransparency = 1,
		BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 2, ScrollingDirection = Enum.ScrollingDirection.X, Size = UDim2.fromScale(1, 1) })
	Create("UIPadding", { Parent = topHolder, PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5),
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) })
	Create("UIListLayout", { Parent = topHolder, FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })

	local function applyLayout(mode)
		window.Layout = mode
		local isSide = (mode == "Side")
		sideContainer.Visible = isSide
		topContainer.Visible = not isSide
		if isSide then
			content.Position = UDim2.fromOffset(202, 6); content.Size = UDim2.new(1, -214, 1, -18)
		else
			local navHeight = Device.Mode == "Mobile" and 44 / Config.Scale + 8 or 30
			topContainer.Size = UDim2.new(1, -24, 0, navHeight)
			content.Position = UDim2.fromOffset(12, navHeight + 12)
			content.Size = UDim2.new(1, -24, 1, -(navHeight + 24))
		end
	end
	function window:SetLayout(mode)
		window.PreferredLayout = (mode == "Top" or mode == "top") and "Top" or "Side"
		if window.FitToViewport then window:FitToViewport() else applyLayout(window.PreferredLayout) end
	end
	applyLayout(layoutMode)

	CursorBg.Visible = Config.CustomCursor and Device.Mode == "PC"

	-- window controls: minimize (collapse to title bar) + maximize (toggle large)
	local minBtn = controlButton(1)
	Create("Frame", { Parent = minBtn, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 2), BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(235, 235, 235),
		ThemeTag = { BackgroundColor3 = "Text" } })
	local maxBtn = controlButton(2)
	local maxSquare = Create("Frame", { Parent = maxBtn, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, BorderSizePixel = 0 })
	Create("UIStroke", { Parent = maxSquare, Thickness = 1.5, ThemeTag = { Color = "Text" } })
	local searchBtn
	if featureSearchEnabled then
		searchBtn = controlButton(0)
		searchBtn.Name = "FeatureSearchButton"
		local ring = Create("Frame", { Parent = searchBtn, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, -2, 0.5, -2), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, BorderSizePixel = 0 })
		Create("UICorner", { Parent = ring, CornerRadius = UDim.new(1, 0) })
		Create("UIStroke", { Parent = ring, Thickness = 1.5, Color = Theme.Values.Text, ThemeTag = { Color = "Text" } })
		Create("Frame", { Parent = searchBtn, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
			Position = UDim2.new(0.5, 5, 0.5, 5), Size = UDim2.fromOffset(6, 2), BorderSizePixel = 0,
			BackgroundColor3 = Theme.Values.Text, ThemeTag = { BackgroundColor3 = "Text" } })
		Tooltip.Bind(searchBtn, "Search features (Ctrl+F)", maid)
		window._searchButton = searchBtn
	end

	-- separate saved sizes so minimize and maximize don't clobber each other's restore
	local minimized, maximized = false, false
	local maxSavedSize, maxSavedPos = size, root.Position
	local fitting = false
	local preferredSize = size
	local lastFittedSize
	function window:FitToViewport()
		if fitting or not root.Parent then return end
		local viewport = Holder.AbsoluteSize
		if viewport.X <= 24 or viewport.Y <= 24 then return end
		if lastFittedSize and root.Size ~= lastFittedSize and not minimized and not maximized then
			preferredSize = root.Size
		end
		fitting = true
		TITLEBAR_H = Device.Mode == "Mobile" and 44 / Config.Scale or 30
		titlebar.Size = UDim2.new(1, 0, 0, TITLEBAR_H)
		body.Position = UDim2.fromOffset(0, TITLEBAR_H)
		body.Size = UDim2.new(1, 0, 1, -TITLEBAR_H)
		local controlCount = featureSearchEnabled and 3 or 2
		local controlWidth = Device.Mode == "Mobile" and (controlCount * 40) / Config.Scale or controlCount * 20
		titleText.Size = UDim2.new(1, -(hasLogo and 38 or 12) - controlWidth - 20, 0, 16)
		local wanted = maximized and UDim2.fromScale(1, 1) or preferredSize
		local rawSize = Vector2.new(wanted.X.Scale * viewport.X + wanted.X.Offset,
			minimized and TITLEBAR_H or wanted.Y.Scale * viewport.Y + wanted.Y.Offset)
		if Device.Mode == "Mobile" then
			rawSize = Vector2.new(math.max(rawSize.X, 280 / Config.Scale),
				minimized and rawSize.Y or math.max(rawSize.Y, 320 / Config.Scale))
		end
		local center = Vector2.new(root.Position.X.Scale * viewport.X + root.Position.X.Offset,
			root.Position.Y.Scale * viewport.Y + root.Position.Y.Offset)
		local fittedSize, fittedCenter = computeWindowGeometry(viewport, rawSize, center, Config.Scale)
		lastFittedSize = UDim2.fromOffset(fittedSize.X, fittedSize.Y)
		root.Size = lastFittedSize
		root.Position = UDim2.fromOffset(fittedCenter.X, fittedCenter.Y)
		window._compact = Device.Mode == "Mobile" or fittedSize.X < 620
		applyLayout(window._compact and "Top" or window.PreferredLayout)
		for _, tab in window.Tabs do
			reflowSections(tab.Sections.ColumnsData, tab._sectionFrames, window._compact)
		end
		fitting = false
	end
	maid:GiveTask(root:GetPropertyChangedSignal("Size"):Connect(function()
		if fitting or root.Size == lastFittedSize then return end
		if not minimized and not maximized then preferredSize = root.Size end
		window:FitToViewport()
	end))
	maid:GiveTask(root:GetPropertyChangedSignal("Position"):Connect(function() window:FitToViewport() end))
	maid:GiveTask(Holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() window:FitToViewport() end))
	table.insert(DeviceRefreshers, function() window:FitToViewport() end)
	window:FitToViewport()
	function window:SetMinimized(b)
		if b == minimized then return end
		if b and window._featureSearch then window._featureSearch:SetOpen(false) end
		minimized = b
		if resizeGrip then resizeGrip.Visible = not b and not maximized end
		body.Visible = not b
		window:FitToViewport()
	end
	function window:SetMaximized(b)
		if b == maximized then return end
		maximized = b
		if resizeGrip then resizeGrip.Visible = not b and not minimized end
		if b then
			-- // Preserve the unclamped size across mobile rotation and window states. \\ --
			maxSavedSize, maxSavedPos = preferredSize, root.Position
			if minimized then window:SetMinimized(false) end
			-- truly fill the screen (centered)
			root.Position = UDim2.fromScale(0.5, 0.5)
		else
			preferredSize = maxSavedSize
			root.Position = maxSavedPos
		end
		if resizeGrip then resizeGrip.Visible = not maximized and not minimized end
		window:FitToViewport()
	end
	maid:GiveTask(minBtn.MouseButton1Click:Connect(function() window:SetMinimized(not minimized) end))
	maid:GiveTask(maxBtn.MouseButton1Click:Connect(function() window:SetMaximized(not maximized) end))

	function window:SetOpen(open)
		self.IsOpen = open
		menuOpen = open
		if not open then -- don't leave dropdown/colorpicker/keybind popups floating over a hidden window
			if self._featureSearch then self._featureSearch:SetOpen(false) end
			CloseAllPopups()
			if hideTooltip then hideTooltip() end
		end
		refreshGlass() -- fade the glass blur in/out alongside the menu
		if open then root.Visible = true end
		local last = Tween.Fade(root, open, Config.FadeSpeed)
		local function done()
			keepCapability()
			root.Visible = self.IsOpen
			CursorBg.Visible = Config.CustomCursor and self.IsOpen and Device.Mode == "PC"
			UserInputService.MouseIconEnabled = not CursorBg.Visible
			-- re-assert global transparency in case it was changed mid-fade
			if self.IsOpen and Config.Transparency > 0 then ApplyTransparency(Config.Transparency) end
		end
		if last then last.Completed:Once(done) else done() end
	end

	maid:GiveTask(Input.On("Began", function(input)
		if UserInputService:GetFocusedTextBox() then return end -- don't toggle while typing
		local id = (input.KeyCode ~= Enum.KeyCode.Unknown) and input.KeyCode or input.UserInputType
		if id == Config.MenuKeybind then
			window:SetOpen(not window.IsOpen)
		end
	end))

	-- Mobile: a floating, draggable open/close button (no keyboard for the keybind)
	if Config.MobileToggle then
		local mb = Create("TextButton", { Parent = Holder, Name = "MobileLaunchButton", Text = "", AutoButtonColor = false,
			Visible = Device.Mode == "Mobile",
			AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(14, 90), Size = UDim2.fromOffset(104, 72),
			BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 800 })
		maid:GiveTask(mb)
		window._mobileToggle = mb
		local function fitMobileButton()
			mb.Visible = Device.Mode == "Mobile"
			local viewport = Holder.AbsoluteSize
			mb.Position = UDim2.fromOffset(math.clamp(mb.Position.X.Offset, 0, math.max(0, viewport.X - 104)),
				math.clamp(mb.Position.Y.Offset, 0, math.max(0, viewport.Y - 72)))
		end
		table.insert(DeviceRefreshers, fitMobileButton)
		maid:GiveTask(Holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitMobileButton))
		local fallback = {}
		if hasLogo then
			Create("ImageLabel", { Parent = mb, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(52, 25), Size = UDim2.fromOffset(46, 46), ScaleType = Enum.ScaleType.Fit,
				Image = AssetUrl(data.Logo), ImageColor3 = Color3.fromRGB(202, 243, 255), ZIndex = 801,
				ThemeTag = { ImageColor3 = "Accent" } })
		else
			for i = 0, 2 do -- hamburger glyph
				fallback[#fallback + 1] = Create("Frame", { Parent = mb, AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(52, 25 + (i - 1) * 7), Size = UDim2.fromOffset(22, 3), BorderSizePixel = 0,
					ZIndex = 801, BackgroundColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { BackgroundColor3 = "Accent" } })
			end
		end
		MakeText(mb, "Mobile Launch", { Name = "MobileLaunchLabel", Position = UDim2.fromOffset(0, 52),
			Size = UDim2.new(1, 0, 0, 18), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 801 })
		-- tap toggles; drag relocates (so it never blocks gameplay)
		local dragStart, startPos, moved = nil, nil, false
		local stopMove
		maid:GiveTask(function() if stopMove then stopMove() end end)
		maid:GiveTask(mb.InputBegan:Connect(function(input)
			if Input.isPrimary(input) then
				moved, dragStart, startPos = false, input.Position, mb.Position
				if stopMove then stopMove() end
				stopMove = Input.On("Changed", function(inp)
					if matchesGesture(inp, input) then
						local delta = inp.Position - dragStart
						if delta.Magnitude > 6 then moved = true end
						mb.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
						fitMobileButton()
					end
				end)
				local conn
				conn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						if stopMove then stopMove(); stopMove = nil end
						conn:Disconnect()
						if not moved then window:SetOpen(not window.IsOpen) end
					end
				end)
				maid:GiveTask(conn)
			end
		end))
	end

	-- tab button builders (one per layout; a tab makes both so layout can switch live)
	local function makeSideTabBtn(name)
		local btn = Create("TextButton", { Parent = sideHolder, Text = "", AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 25), BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
			BackgroundTransparency = 0.6, BackgroundColor3 = Color3.fromRGB(25, 30, 26),
			ThemeTag = { BackgroundColor3 = "Page Background", BorderColor3 = "Border" } })
		Stroke(btn, "Outline", 0.6)
		Corner(btn)
		trackTouchTarget(btn, 44)
		local liner = Create("Frame", { Parent = btn, Size = UDim2.new(0, 1, 1, 0), BorderSizePixel = 0,
			BackgroundTransparency = 1, BackgroundColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { BackgroundColor3 = "Accent" } })
		local label = MakeText(btn, name, { AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.new(1, -22, 0, 15),
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
		return { btn = btn, liner = liner, label = label, side = true }
	end
	local function makeTopTabBtn(name)
		local btn = Create("TextButton", { Parent = topHolder, Text = "", AutoButtonColor = false,
			Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
			BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 0,
			BackgroundTransparency = 1, BackgroundColor3 = Color3.fromRGB(30, 36, 31),
			ThemeTag = { BackgroundColor3 = "Element", BorderColor3 = "Border" } })
		Corner(btn, 4)
		Create("UIPadding", { Parent = btn, PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) })
		-- bold, rounded accent underline (more prominent active tab)
		local liner = Create("Frame", { Parent = btn, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 1),
			Size = UDim2.new(1, -8, 0, 3), BorderSizePixel = 0, BackgroundTransparency = 1,
			BackgroundColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { BackgroundColor3 = "Accent" } })
		Create("UICorner", { Parent = liner, CornerRadius = UDim.new(1, 0) })
		local label = MakeText(btn, name, { AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 0, 0, 15), FontFace = Font.fromEnum(Enum.Font.GothamMedium),
			TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.X })
		return { btn = btn, liner = liner, label = label, side = false }
	end

	if featureSearchEnabled then
		window._featureSearch = FeatureSearch.attach(window, body, searchBtn, maid, {
			Create = Create, MakeText = MakeText, Stroke = Stroke, Corner = Corner, Theme = Theme,
			Device = Device, Config = Config, trackTouchTarget = trackTouchTarget, keepCapability = keepCapability,
			CloseAllPopups = CloseAllPopups, UserInputService = UserInputService, Input = Input, Library = Library,
			GetFont = GetFont, Maid = Maid,
			DeviceRefreshers = DeviceRefreshers,
		})
	end
	function window:SearchFeatures(query)
		return self._featureSearch and self._featureSearch:Search(query) or {}
	end
	function window:OpenFeatureSearch()
		if self._featureSearch then self:SetMinimized(false); self._featureSearch:SetOpen(true) end
	end

	--------------------------------------------------------------- Tab ---
	function window:Tab(tabData: TabConfig?)
		tabData = tabData or {}
		local tabMaid = Maid.new()
		maid:GiveTask(tabMaid)
		local maid = tabMaid
		local tab = { Name = tostring(tabData.Name or "Tab"), Maid = maid, Destroyed = false,
			Sections = { ColumnsData = {} }, Active = false, Columns = tabData.Columns or 2, _sectionFrames = {} }

		local buttons = { makeSideTabBtn(tab.Name), makeTopTabBtn(tab.Name) }

		-- CanvasGroup so the whole page fades as a single layer (GroupTransparency)
		-- instead of one tween per descendant property on every tab switch.
		local page = Create("CanvasGroup", { Parent = content, BackgroundTransparency = 1, Visible = false,
			GroupTransparency = 0, Size = UDim2.fromScale(1, 1) })
		tab.Page = page
		maid:GiveTask(page)
		for _, bd in buttons do maid:GiveTask(bd.btn) end
		Create("UIListLayout", { Parent = page, FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.Fill, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
		for i = 1, tab.Columns do
			local col = Create("ScrollingFrame", { Parent = page, BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1), ScrollBarThickness = 0, BorderSizePixel = 0,
				CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y })
			Create("UIListLayout", { Parent = col, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
			Create("UIPadding", { Parent = col, PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2),
				PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2) })
			tab.Sections.ColumnsData[i] = col
		end

		function tab:Turn(on)
			if self.Destroyed then return end
			tab.Active = on
			-- respect global UI transparency: active base 0, inactive base 0.6
			local btnTarget = SurfaceAlpha(on and 0 or 0.6)
			for _, bd in buttons do
				Tween.To(bd.btn, { BackgroundTransparency = btnTarget })
				Tween.SetShown(bd.btn, "BackgroundTransparency", btnTarget)
				Tween.To(bd.liner, { BackgroundTransparency = on and 0 or 1 })
				if bd.side then
					-- explicitly own the fill colour so a deselected tab never stays
					-- stuck on the green hover colour (it used to only clear on re-hover)
					local bg = on and "Hovered Element" or "Page Background"
					Theme.Retag(bd.btn, { BackgroundColor3 = bg })
					Tween.To(bd.btn, { BackgroundColor3 = Theme.Values[bg] })
					Tween.To(bd.label, { Position = UDim2.new(0, on and 13 or 8, 0.5, 0) })
				else
					-- top tab: vibrant accent label when active
					Theme.Retag(bd.label, { TextColor3 = on and "Accent" or "Text" })
					Tween.To(bd.label, { TextColor3 = on and Theme.Values.Accent or Theme.Values.Text })
				end
			end
			-- Fade the incoming page in as one layer (GroupTransparency); element
			-- transparencies are left intact so stateful widgets never blank.
			-- The OUTGOING page is hidden *instantly* — a visible fade-out left the
			-- old page overlapping the new one, and fast switching stacked several
			-- lingering pages ("extra second to vanish").
			if on then
				window.CurrentTab = tab
				page.Parent = content
				page.Visible = true
				page.GroupTransparency = 1
				Tween.To(page, { GroupTransparency = 0 }, Tween.Info(window.FadeTime))
			else
				page.Visible = false
				page.Parent = UnusedHolder
				page.GroupTransparency = 0 -- reset for the next time it's shown
			end
		end

		-- re-apply state-dependent transparency when the global UI transparency changes
		local function refreshTransparency()
			local t = SurfaceAlpha(tab.Active and 0 or 0.6)
			for _, bd in buttons do bd.btn.BackgroundTransparency = t; Tween.SetShown(bd.btn, "BackgroundTransparency", t) end
		end
		table.insert(TransparencyRefreshers, refreshTransparency)
		maid:GiveTask(function() removeRefresher(TransparencyRefreshers, refreshTransparency) end)

		local function switchToThis()
			if tab.Destroyed or tab.Active then return end
			for _, t in window.Tabs do t:Turn(t == tab) end
		end
		function tab:Select() switchToThis() end
		function tab:SetName(name)
			if self.Destroyed then return self end
			assert(type(name) == "string" and name ~= "", "Tab name must be a non-empty string")
			self.Name = name
			for _, bd in buttons do bd.label.Text = name end
			if window._featureSearch then window._featureSearch:RenameTab(self, name) end
			return self
		end
		function tab:SetOrder(order)
			if self.Destroyed then return self end
			assert(type(order) == "number" and order == order and math.abs(order) < math.huge, "Tab order must be finite")
			local index = table.find(window.Tabs, self)
			if index then
				table.remove(window.Tabs, index)
				table.insert(window.Tabs, math.clamp(math.floor(order), 1, #window.Tabs + 1), self)
				for i, other in window.Tabs do other:_ApplyOrder(i) end
			end
			return self
		end
		function tab:_ApplyOrder(order)
			self.Order = order
			for _, bd in buttons do bd.btn.LayoutOrder = order end
		end
		function tab:_ReflowSections()
			local ordered = {}
			for _, entry in self._sectionFrames do
				local first = (self.SettingsPosition == "Bottom") ~= entry.builtin
				if first then ordered[#ordered + 1] = entry end
			end
			for _, entry in self._sectionFrames do
				local first = (self.SettingsPosition == "Bottom") ~= entry.builtin
				if not first then ordered[#ordered + 1] = entry end
			end
			for i, entry in ordered do entry.order = i end
			reflowSections(self.Sections.ColumnsData, self._sectionFrames, window._compact)
		end
		function tab:SetSettingsPosition(position)
			if self.Destroyed then return self end
			assert(position == "Top" or position == "Bottom", "SettingsPosition must be Top or Bottom")
			self.SettingsPosition = position
			self:_ReflowSections()
			return self
		end
		function tab:Destroy()
			if self.Destroyed then return end
			self.Destroyed = true
			local index = table.find(window.Tabs, self)
			if index then table.remove(window.Tabs, index) end
			if window._featureSearch then window._featureSearch:RemoveTab(self) end
			local wasCurrent = window.CurrentTab == self
			self.Active = false
			if wasCurrent then window.CurrentTab = nil end
			maid:Clean()
			local owned = table.find(window.Maid._tasks, maid)
			if owned then table.remove(window.Maid._tasks, owned) end
			table.clear(self._sectionFrames)
			table.clear(self.Sections.ColumnsData)
			for i, other in window.Tabs do other:_ApplyOrder(i) end
			if wasCurrent and #window.Tabs > 0 then
				window.Tabs[math.min(index or 1, #window.Tabs)]:Select()
			end
		end
		tab.Delete = tab.Destroy
		for _, bd in buttons do
			maid:GiveTask(bd.btn.MouseButton1Click:Connect(switchToThis))
			maid:GiveTask(bd.btn.MouseEnter:Connect(function()
				if not tab.Active then
					Theme.Retag(bd.btn, { BackgroundColor3 = "Hovered Element" })
					Tween.To(bd.btn, { BackgroundColor3 = Theme.Values["Hovered Element"] })
				end
			end))
			maid:GiveTask(bd.btn.MouseLeave:Connect(function()
				if not tab.Active then
					Theme.Retag(bd.btn, { BackgroundColor3 = "Page Background" })
					Tween.To(bd.btn, { BackgroundColor3 = Theme.Values["Page Background"] })
				end
			end))
		end

		----------------------------------------------------- Section ---
		function tab:Section(secData)
			assert(not tab.Destroyed, "Cannot add a section to a destroyed tab")
			secData = secData or {}
			local section = {}
			local side = math.clamp(secData.Side or 1, 1, tab.Columns)
			local parentCol = tab.Sections.ColumnsData[window._compact and 1 or side]

			local box = Create("Frame", { Parent = parentCol, Size = UDim2.new(1, 0, 0, 25),
				BorderColor3 = Color3.fromRGB(42, 49, 45), BorderSizePixel = 2, AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.fromRGB(20, 24, 21),
				ThemeTag = { BackgroundColor3 = "Inline", BorderColor3 = "Outline" } })
			table.insert(tab._sectionFrames, { frame = box, side = side, order = #tab._sectionFrames + 1, builtin = tab._buildingSettings == true })
			tab:_ReflowSections()
			Stroke(box, "Border")
			Corner(box)
			Create("Frame", { Parent = box, Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0,
				BackgroundColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { BackgroundColor3 = "Accent" } })
			MakeText(box, secData.Name or "Section", { Position = UDim2.fromOffset(8, 5), Size = UDim2.new(1, -16, 0, 15),
				TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left })
			Create("UIPadding", { Parent = box, PaddingBottom = UDim.new(0, 8) })
			local cont = Create("Frame", { Parent = box, BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y })
			Create("UIListLayout", { Parent = cont, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

			local function registerSearch(name, target, kind, cfg)
				if not window._featureSearch then return end
				window._featureSearch:Register({ Name = name or kind, Tooltip = cfg and cfg.Tooltip, Flag = cfg and cfg.Flag,
					Tab = tab, TabName = tab.Name, Section = box, SectionName = secData.Name or "Section",
					Target = target, Container = cont, Kind = kind })
			end
			registerSearch(secData.Name or "Section", box, "Section")
			local function withParent(cfg)
				assert(not tab.Destroyed, "Cannot add controls to a destroyed tab")
				cfg = cfg or {}; cfg.Parent = cont; cfg.Maid = maid; cfg._SearchRegister = registerSearch
				return cfg
			end

			function section:Toggle(c)
				c = withParent(c); c.Flag = c.Flag or Library:NextFlag()
				local t = Components.Toggle(c)
				function t:AddColorpicker(cc)
					cc = cc or {}; cc.Parent = self._sub; cc.Maid = maid; cc.Flag = cc.Flag or Library:NextFlag()
					cc.Name = cc.Name or c.Name; cc._SearchRegister = registerSearch
					return Components.Colorpicker(cc)
				end
				function t:AddKeybind(cc)
					cc = cc or {}; cc.Parent = self._sub; cc.Maid = maid; cc.Flag = cc.Flag or Library:NextFlag()
					cc.Name = cc.Name or c.Name
					cc._SearchRegister = registerSearch
					return Components.Keybind(cc)
				end
				function t:AddInfo(text, kind)
					return Components.InfoMarker(self._sub, text, kind, maid)
				end
				if c.Info then t:AddInfo(c.Info, c.InfoType) end
				return t
			end
			function section:Button(c) return Components.Button(withParent(c)) end
			function section:Slider(c) c = withParent(c); c.Flag = c.Flag or Library:NextFlag(); return Components.Slider(c) end
			function section:Dropdown(c) c = withParent(c); c.Flag = c.Flag or Library:NextFlag(); return Components.Dropdown(c) end
			function section:Searchbox(c) c = withParent(c); c.Search = true; c.Flag = c.Flag or Library:NextFlag(); return Components.Dropdown(c) end
			function section:Textbox(c) c = withParent(c); c.Flag = c.Flag or Library:NextFlag(); return Components.Textbox(c) end
			function section:Paragraph(c) return Components.Paragraph(withParent(c)) end
			function section:Divider() return Components.Divider(withParent({})) end
			function section:Image(c) return Components.Image(withParent(c)) end
			function section:Link(c) return Components.Link(withParent(c)) end
			function section:Viewport(c) return Components.Viewport(withParent(c)) end
			function section:Label(c)
				if type(c) == "string" then c = { Name = c } end
				c = withParent(c)
				local l = Components.Label(c)
				function l:AddColorpicker(cc)
					cc = cc or {}; cc.Parent = self._sub; cc.Maid = maid; cc.Flag = cc.Flag or Library:NextFlag()
					cc.Name = cc.Name or c.Name; cc._SearchRegister = registerSearch
					return Components.Colorpicker(cc)
				end
				function l:AddKeybind(cc)
					cc = cc or {}; cc.Parent = self._sub; cc.Maid = maid; cc.Flag = cc.Flag or Library:NextFlag()
					cc.Name = cc.Name or c.Name
					cc._SearchRegister = registerSearch
					return Components.Keybind(cc)
				end
				function l:AddInfo(text, kind)
					return Components.InfoMarker(self._sub, text, kind, maid)
				end
				if c.Info then l:AddInfo(c.Info, c.InfoType) end
				return l
			end

			return section
		end

		table.insert(window.Tabs, tab)
		tab:SetOrder(tabData.Order or #window.Tabs)
		if not window.CurrentTab then tab:Select() end
		reflowSections(tab.Sections.ColumnsData, tab._sectionFrames, window._compact)
		return tab
	end

	window:SetOpen(true)
	return setmetatable(window, Library)
end

--==============================================================================
-- Watermark / KeybindList / Notifications
--==============================================================================

function Library:Watermark(text: string)
	local maid = LibMaid
	local frame = Create("Frame", { Parent = Holder, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, claimTopSlot(30)), AutomaticSize = Enum.AutomaticSize.XY, BorderSizePixel = 2,
		BorderColor3 = Color3.fromRGB(12, 12, 12), BackgroundColor3 = Color3.fromRGB(14, 17, 15),
		ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	Stroke(frame, "Outline")
	Corner(frame)
	MakeDraggable(frame, frame, maid)
	Create("UIPadding", { Parent = frame, PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7),
		PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12) })
	Create("UIListLayout", { Parent = frame, FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 9),
		SortOrder = Enum.SortOrder.LayoutOrder })
	-- accent tick before the text
	local bar = Create("Frame", { Parent = frame, Size = UDim2.fromOffset(3, 14), BorderSizePixel = 0,
		LayoutOrder = 0, BackgroundColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { BackgroundColor3 = "Accent" } })
	Create("UICorner", { Parent = bar, CornerRadius = UDim.new(0, 2) })
	local label = MakeText(frame, text, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1,
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left })
	return {
		SetText = function(_, t) label.Text = t end,
		SetVisibility = function(_, b) frame.Visible = b end,
	}
end

--- Floating keybind list. opts: { Title = "Keybinds", ShowTitle = true, RichText = false }.
function Library:KeybindList(opts)
	opts = opts or {}
	local list = {}
	Library.KeyList = list
	local richText = opts.RichText and true or false
	local entries: { TextLabel } = {}
	-- auto-sizes to its widest entry (min width keeps it tidy when empty)
	local frame = Create("Frame", { Parent = Holder, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 55), Size = UDim2.fromOffset(120, 0), BorderSizePixel = 2,
		AutomaticSize = Enum.AutomaticSize.XY, BorderColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundColor3 = Color3.fromRGB(14, 17, 15),
		ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	Stroke(frame, "Outline")
	Corner(frame)
	MakeDraggable(frame, frame, LibMaid)
	Create("UIPadding", { Parent = frame, PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	local titleLabel = MakeText(frame, opts.Title or "Keybinds", { Size = UDim2.new(0, 0, 0, 14),
		AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 13, RichText = richText })
	local divider = Create("Frame", { Parent = frame, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 1),
		AnchorPoint = Vector2.new(0, 0), BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(202, 243, 255),
		ThemeTag = { BackgroundColor3 = "Accent" } })
	local body = Create("Frame", { Parent = frame, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY })
	Create("UIListLayout", { Parent = body, SortOrder = Enum.SortOrder.LayoutOrder })

	function list:Add(key, name, mode)
		local entry = MakeText(body, ("%s - %s (%s)"):format(key, name, mode), {
			Size = UDim2.new(0, 0, 0, 15), AutomaticSize = Enum.AutomaticSize.X, RichText = richText,
			TextXAlignment = Enum.TextXAlignment.Left, Visible = false, TextTransparency = 1 })
		entries[#entries + 1] = entry
		local item = { Instance = entry }
		-- Entry is shown whenever a key is bound (not "None"); it does NOT hide when
		-- the bind is inactive. SetStatus only changes the highlight colour.
		function item:SetText(k, n, m)
			entry.Text = ("%s - %s (%s)"):format(k, n, m)
			local bound = k ~= nil and k ~= "" and k ~= "None"
			entry.Visible = bound
			Tween.To(entry, { TextTransparency = bound and 0 or 1 })
		end
		function item:SetStatus(on)
			Theme.Retag(entry, { TextColor3 = on and "Accent" or "Text" })
			Tween.To(entry, { TextColor3 = on and Theme.Values.Accent or Theme.Values.Text })
		end
		function item:Remove()
			local index = table.find(entries, entry)
			if index then table.remove(entries, index) end
			entry:Destroy()
		end
		return item
	end
	function list:SetVisibility(b) frame.Visible = b end
	function list:SetTitle(t) titleLabel.Text = tostring(t) end
	--- Show/hide the title (and its divider); the body shifts up when hidden.
	function list:SetTitleVisible(b)
		b = b and true or false
		titleLabel.Visible = b
		divider.Visible = b
		body.Position = UDim2.fromOffset(0, b and 20 or 0)
	end
	--- Toggle RichText on the title + all entries (so names can use <b>, <font> …).
	function list:SetRichText(b)
		richText = b and true or false
		titleLabel.RichText = richText
		for _, e in entries do e.RichText = richText end
	end
	if opts.ShowTitle == false then list:SetTitleVisible(false) end
	return list
end

--- Optional inventory browser: a draggable panel with a player header (avatar /
--- health / distance) and a grid of tool icons. Returns a viewer handle.
function Library:InventoryViewer()
	local viewer = { Items = {} }
	local frame = Create("Frame", { Parent = Holder, Position = UDim2.fromOffset(20, 80),
		Size = UDim2.fromOffset(320, 280), BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(14, 17, 15), ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	Stroke(frame, "Outline"); Corner(frame, 6); trackScale(frame)

	local titlebar = Create("Frame", { Parent = frame, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26) })
	MakeDraggable(frame, titlebar, LibMaid)
	local title = MakeText(titlebar, "Inventory", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.new(1, -20, 0, 16), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 14 })
	Create("Frame", { Parent = titlebar, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(202, 243, 255),
		ThemeTag = { BackgroundColor3 = "Accent" } })

	local tools = Create("ScrollingFrame", { Parent = frame, Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(1, -20, 1, -110), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { ScrollBarImageColor3 = "Accent" } })
	Create("UIGridLayout", { Parent = tools, CellSize = UDim2.fromOffset(62, 62), CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder })

	local avatar = Create("ImageLabel", { Parent = frame, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.fromOffset(58, 58), BorderColor3 = Color3.fromRGB(42, 49, 45), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(20, 24, 21), Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		ThemeTag = { BackgroundColor3 = "Inline", BorderColor3 = "Outline" } })
	Stroke(avatar, "Border")
	local health = MakeText(frame, "Health: —", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 76, 1, -46),
		Size = UDim2.new(1, -86, 0, 15), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Left })
	local distance = MakeText(frame, "Distance: — studs", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 76, 1, -22),
		Size = UDim2.new(1, -86, 0, 15), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Left })

	function viewer:SetHealth(v) health.Text = "Health: " .. tostring(v) end
	function viewer:SetDistance(v) distance.Text = "Distance: " .. tostring(v) .. " studs" end
	function viewer:SetVisibility(b) frame.Visible = b end
	function viewer:SetPlayer(plr)
		title.Text = (plr.Name or "Player") .. "'s Inventory"
		task.spawn(function()
			local ok, img = pcall(function()
				return (Players :: any):GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok and img then avatar.Image = img end
		end)
	end
	function viewer:AddTool(name: string, image: string?)
		local item = Create("Frame", { Parent = tools, BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
			BackgroundColor3 = Color3.fromRGB(20, 24, 21), ThemeTag = { BackgroundColor3 = "Inline", BorderColor3 = "Outline" } })
		Stroke(item, "Border"); Corner(item, 4)
		Create("ImageLabel", { Parent = item, AnchorPoint = Vector2.new(0.5, 0.4), Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
			Image = AssetUrl(image), ImageColor3 = Color3.fromRGB(202, 243, 255),
			ThemeTag = { ImageColor3 = "Accent" } })
		MakeText(item, name, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3),
			Size = UDim2.new(1, -6, 0, 12), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd })
		local handle = {}
		function handle:Remove() viewer.Items[name] = nil; item:Destroy() end
		viewer.Items[name] = handle
		return handle
	end
	function viewer:RemoveAll()
		for _, h in viewer.Items do h:Remove() end
	end
	return viewer
end

--- A Discord-style user profile card (avatar + display name + subtitle).
--- All fields default to the local player and are overridable. opts:
---   DisplayName, Username, Status, Image (rbxassetid/url), Position (UDim2).
--- Returns: :SetDisplayName / :SetUsername / :SetStatus / :SetAvatar / :SetVisibility.
function Library:UserProfile(opts)
	opts = opts or {}
	local profile = {}
	local frame = Create("Frame", { Parent = Holder, AnchorPoint = Vector2.new(0, 1),
		Position = opts.Position or UDim2.new(0, 12, 1, -12), AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 52), BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(14, 17, 15), ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	Stroke(frame, "Outline"); Corner(frame, 6); trackScale(frame)
	MakeDraggable(frame, frame, LibMaid)
	-- accent stripe at the top, OUTSIDE the content layout (full width, ignores padding)
	Create("Frame", { Parent = frame, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { BackgroundColor3 = "Accent" } })

	-- content row holds the layout so the stripe above isn't treated as a flow item
	local content = Create("Frame", { Parent = frame, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(8, 7), Size = UDim2.new(0, 0, 1, -14) })
	Create("UIListLayout", { Parent = content, FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder })
	Create("UIPadding", { Parent = content, PaddingRight = UDim.new(0, 12) })

	local avatarHolder = Create("Frame", { Parent = content, Size = UDim2.fromOffset(38, 38), LayoutOrder = 0,
		BackgroundColor3 = Color3.fromRGB(20, 24, 21), BorderSizePixel = 0, ThemeTag = { BackgroundColor3 = "Inline" } })
	Create("UICorner", { Parent = avatarHolder, CornerRadius = UDim.new(1, 0) })
	local avatar = Create("ImageLabel", { Parent = avatarHolder, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Image = "", ScaleType = Enum.ScaleType.Crop })
	Create("UICorner", { Parent = avatar, CornerRadius = UDim.new(1, 0) })

	local textCol = Create("Frame", { Parent = content, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 38), LayoutOrder = 1 })
	Create("UIListLayout", { Parent = textCol, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder })
	local nameLabel = MakeText(textCol, opts.DisplayName or LocalPlayer.DisplayName, {
		Size = UDim2.new(0, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 0,
		FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left })
	local subLabel = MakeText(textCol, opts.Status or opts.Username or ("@" .. LocalPlayer.Name), {
		Size = UDim2.new(0, 0, 0, 13), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(185, 185, 185),
		ThemeTag = { TextColor3 = "Placeholder Text" } })

	function profile:SetDisplayName(t) nameLabel.Text = tostring(t) end
	function profile:SetUsername(t) subLabel.Text = tostring(t) end
	function profile:SetStatus(t) subLabel.Text = tostring(t) end
	function profile:SetVisibility(b) frame.Visible = b end
	function profile:SetAvatar(img)
		avatar.Image = AssetUrl(img)
	end

	if opts.Image and opts.Image ~= "" then
		profile:SetAvatar(opts.Image)
	else
		task.spawn(function()
			local ok, img = pcall(function()
				return (Players :: any):GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			if ok and img then avatar.Image = img end
		end)
	end
	return profile
end

--- A scrolling news ticker / marquee. opts:
---   Messages ({string}) or Text (string), Speed (px/s, default 70),
---   Separator (between messages), Tag (left accent label e.g. "NEWS"),
---   Side ("Top"/"Bottom", default Top) or Position+Size (UDim2) for custom placement,
---   Height (default 26).
--- Returns: :SetMessages/:SetText/:SetSpeed/:SetTag/:Pause/:Resume/:SetVisibility/:Destroy.
function Library:Ticker(opts)
	opts = opts or {}
	local ticker = {}
	local speed = opts.Speed or 70
	local sep = opts.Separator or "      |      " -- ASCII-safe default (pass Separator to use • etc.)
	local messages = opts.Messages or { opts.Text or "BloxUI" }
	local side = opts.Side or "Top"
	local height = opts.Height or 30
	local anchorY = (side == "Bottom") and 1 or 0
	local margin = opts.Margin or 14

	-- Floating, centred, rounded "news chip" (offset from the screen edge) instead
	-- of a full-width strip that looks like a system banner. Default width is
	-- responsive (fills the width minus margins, capped) so it never overflows a
	-- phone screen; pass Width/Size for a fixed size.
	local size = opts.Size
		or (opts.Width and UDim2.fromOffset(opts.Width, height))
		or UDim2.new(1, -(margin * 2), 0, height)
	-- a top ticker claims a stacking slot so it doesn't load over the watermark
	local pos = opts.Position
		or (anchorY == 0 and UDim2.new(0.5, 0, 0, claimTopSlot(height)))
		or UDim2.new(0.5, 0, 1, -margin)
	local bar = Create("Frame", { Parent = Holder, AnchorPoint = Vector2.new(0.5, anchorY),
		Position = pos,
		Size = size, BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(20, 24, 21), ThemeTag = { BackgroundColor3 = "Inline" } })
	if not opts.Size and not opts.Width then
		Create("UISizeConstraint", { Parent = bar, MaxSize = Vector2.new(480, math.huge) })
	end
	Create("UICorner", { Parent = bar, CornerRadius = UDim.new(0, 8) })
	Stroke(bar, "Outline")
	trackScale(bar)
	MakeDraggable(bar, bar, LibMaid) -- grab anywhere on the chip to reposition it
	-- soft drop shadow for depth
	Create("ImageLabel", { Parent = bar, BackgroundTransparency = 1, ZIndex = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 30, 1, 30),
		Image = GLOW_IMAGE, ScaleType = Enum.ScaleType.Slice, SliceCenter = GLOW_SLICE,
		ImageColor3 = Color3.fromRGB(0, 0, 0), ImageTransparency = 0.55 })

	-- padded horizontal row: [tag pill] [scrolling area]; kept in its own frame so
	-- the shadow isn't dragged into the layout.
	local row = Create("Frame", { Parent = bar, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	Create("UIPadding", { Parent = row, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) })
	Create("UIListLayout", { Parent = row, FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

	local tagLabel
	if opts.Tag then
		-- compact, softly accent-tinted capsule with accent text + a thin accent
		-- rim (instead of a loud solid pill) so it reads as a clean badge.
		local tag = Create("Frame", { Parent = row, LayoutOrder = 0, Size = UDim2.new(0, 0, 0, 19),
			AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromRGB(202, 243, 255),
			BackgroundTransparency = 0.82, ThemeTag = { BackgroundColor3 = "Accent" } })
		Create("UICorner", { Parent = tag, CornerRadius = UDim.new(1, 0) })
		Stroke(tag, "Accent", 0.5)
		Create("UIPadding", { Parent = tag, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
		tagLabel = MakeText(tag, opts.Tag, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
			FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 11,
			TextColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { TextColor3 = "Accent" } })
	end

	local scrollArea = Create("Frame", { Parent = row, LayoutOrder = 1, BackgroundTransparency = 1,
		ClipsDescendants = true, Size = UDim2.new(1, 0, 1, 0) })
	Create("UIFlexItem", { Parent = scrollArea, FlexMode = Enum.UIFlexMode.Fill }) -- fills the remaining width
	local label = MakeText(scrollArea, table.concat(messages, sep), { AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 0, 0, 15), AutomaticSize = Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13 })

	-- edge fade: text scrolls in/out smoothly at both ends instead of hard-clipping
	local function edgeFade(isLeft: boolean)
		local f = Create("Frame", { Parent = scrollArea, ZIndex = 5, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(isLeft and 0 or 1, 0.5), Position = UDim2.new(isLeft and 0 or 1, 0, 0.5, 0),
			Size = UDim2.new(0, 26, 1, 0), BackgroundColor3 = Color3.fromRGB(20, 24, 21),
			ThemeTag = { BackgroundColor3 = "Inline" } })
		Create("UIGradient", { Parent = f, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, isLeft and 0 or 1),
			NumberSequenceKeypoint.new(1, isLeft and 1 or 0) }) })
	end
	edgeFade(true); edgeFade(false)

	-- cache the two widths (they change only on resize / SetMessages) instead of
	-- reading AbsoluteSize every frame, which can force a layout flush
	local areaW, labelW = scrollArea.AbsoluteSize.X, label.AbsoluteSize.X
	LibMaid:GiveTask(scrollArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() areaW = scrollArea.AbsoluteSize.X end))
	LibMaid:GiveTask(label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() labelW = label.AbsoluteSize.X end))

	local paused, x = false, nil
	local scrollConn
	scrollConn = RunService.RenderStepped:Connect(function(dt)
		if paused or not bar.Parent or not bar.Visible then return end
		keepCapability()
		if x == nil then x = areaW end
		x = x - speed * dt
		if x <= -labelW then x = areaW end -- wrap back to the right once fully scrolled off
		label.Position = UDim2.new(0, math.floor(x), 0.5, 0)
	end)
	LibMaid:GiveTask(scrollConn)

	function ticker:SetMessages(t) messages = t; label.Text = table.concat(t, sep); x = scrollArea.AbsoluteSize.X end
	function ticker:SetText(t) ticker:SetMessages({ t }) end
	function ticker:SetSpeed(n) speed = n end
	function ticker:SetTag(t) if tagLabel then tagLabel.Text = t end end
	function ticker:Pause() paused = true end
	function ticker:Resume() paused = false end
	function ticker:SetVisibility(b) bar.Visible = b end
	function ticker:Destroy() if scrollConn then scrollConn:Disconnect() end bar:Destroy() end
	return ticker
end

local NOTIF_TYPES = {
	info    = { color = function() return Theme.Values.Accent end,   glyph = "i" },
	success = { color = function() return Color3.fromRGB(120, 230, 150) end, glyph = "✓" },
	warning = { color = function() return Color3.fromRGB(245, 205, 110) end, glyph = "!" },
	error   = { color = function() return Color3.fromRGB(245, 120, 120) end, glyph = "×" },
}

local NOTIF_WIDTH = 250

--- Show a toast notification.
--- Accepts either positional args `(title, description, duration, type)` or a
--- single config table `{Title, Description, Duration, Type, Icon}`.
--- `Type` is one of "info" | "success" | "warning" | "error".
--- Returns a handle with `:Close()` to dismiss early.
function Library:Notification(title, description: string?, duration: number?, kind: string?)
	local cfg
	if type(title) == "table" then
		cfg = title
	else
		cfg = { Title = title, Description = description, Duration = duration, Type = kind }
	end
	local ntype = cfg.Type or "info"
	duration = cfg.Duration or Config.NotificationDuration or 5
	local typeData = NOTIF_TYPES[ntype] or NOTIF_TYPES.info
	local accent = typeData.color()

	-- optional notification sound
	local soundId = cfg.Sound or Config.NotificationSound
	if soundId and soundId ~= "" then
		task.spawn(function()
			local ok, snd = pcall(function()
				local s = Instance.new("Sound")
				s.SoundId = soundId
				s.Volume = cfg.Volume or 0.5
				s.Parent = Holder
				return s
			end)
			if ok and snd then
				snd:Play()
				snd.Ended:Once(function() snd:Destroy() end)
				-- fallback cleanup if Ended never fires (e.g. bad asset), based on the
				-- sound's own length rather than a magic 5s
				task.delay(math.max(5, (snd.TimeLength > 0 and snd.TimeLength or 0) + 1), function()
					if snd.Parent then snd:Destroy() end
				end)
			end
		end)
	end

	local frame = Create("Frame", { Parent = NotifHolder, Size = UDim2.fromOffset(NOTIF_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 2, BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(12, 12, 12), BackgroundColor3 = Color3.fromRGB(14, 17, 15),
		ClipsDescendants = true, ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	local s = Stroke(frame, "Outline"); s.Transparency = 1
	Corner(frame)

	-- full-height left accent stripe
	local stripe = Create("Frame", { Parent = frame, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0,
		BackgroundColor3 = accent, BackgroundTransparency = 1 })

	-- type glyph (or custom icon)
	local glyph
	if cfg.Icon then
		glyph = Create("ImageLabel", { Parent = frame, BackgroundTransparency = 1, ImageTransparency = 1,
			Position = UDim2.fromOffset(12, 9), Size = UDim2.fromOffset(16, 16), Image = cfg.Icon, ImageColor3 = accent })
	else
		glyph = Create("TextLabel", { Parent = frame, BackgroundTransparency = 1, TextTransparency = 1,
			Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(16, 16), FontFace = GetFont(),
			Text = typeData.glyph, TextSize = 14, TextColor3 = accent })
	end

	-- content column (auto-stacks title / description / progress)
	local content = Create("Frame", { Parent = frame, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(34, 8), Size = UDim2.new(1, -44, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	Create("UIListLayout", { Parent = content, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })

	local titleLabel = MakeText(content, cfg.Title or "", { Size = UDim2.new(1, 0, 0, 0),
		FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 14,
		AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 1, LayoutOrder = 1 })
	local descLabel
	if cfg.Description and cfg.Description ~= "" then
		descLabel = MakeText(content, cfg.Description, { Size = UDim2.new(1, 0, 0, 0),
			FontFace = Font.fromEnum(Enum.Font.GothamMedium), TextSize = 13,
			AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 1, TextColor3 = Color3.fromRGB(220, 220, 220),
			ThemeTag = { TextColor3 = "Text" }, LayoutOrder = 2 })
	end

	-- progress bar (shrinks over the duration), then a small bottom spacer
	local progress = Create("Frame", { Parent = content, Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0,
		BackgroundColor3 = accent, BackgroundTransparency = 1, LayoutOrder = 3 })
	Create("Frame", { Parent = content, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 2), LayoutOrder = 4 })

	local closed = false
	local handle = {}

	function handle:Close()
		if closed or not frame.Parent then return end -- guard: :Unload() may have destroyed it
		keepCapability() -- auto-dismiss fires this from a task.delay scheduler thread
		closed = true
		-- freeze height so the collapse tween isn't fought by AutomaticSize.Y
		local h = frame.AbsoluteSize.Y
		frame.AutomaticSize = Enum.AutomaticSize.None
		frame.Size = UDim2.fromOffset(NOTIF_WIDTH, h)
		Tween.To(frame, { BackgroundTransparency = 1 })
		Tween.To(s, { Transparency = 1 })
		Tween.To(stripe, { BackgroundTransparency = 1 })
		Tween.To(glyph, glyph:IsA("ImageLabel") and { ImageTransparency = 1 } or { TextTransparency = 1 })
		Tween.To(titleLabel, { TextTransparency = 1 })
		if descLabel then Tween.To(descLabel, { TextTransparency = 1 }) end
		Tween.To(progress, { BackgroundTransparency = 1 })
		Tween.To(frame, { Size = UDim2.fromOffset(NOTIF_WIDTH, 0) })
		task.delay(0.35, function() keepCapability(); frame:Destroy() end)
	end

	-- fade in
	Tween.To(frame, { BackgroundTransparency = 0 })
	Tween.To(s, { Transparency = 0 })
	Tween.To(stripe, { BackgroundTransparency = 0 })
	Tween.To(glyph, glyph:IsA("ImageLabel") and { ImageTransparency = 0 } or { TextTransparency = 0 })
	Tween.To(titleLabel, { TextTransparency = 0 })
	if descLabel then Tween.To(descLabel, { TextTransparency = 0 }) end
	progress.BackgroundTransparency = 0
	Tween.To(progress, { Size = UDim2.new(0, 0, 0, 2) }, Tween.Info(duration, Enum.EasingStyle.Linear))

	-- optional action buttons (LayoutOrder 2.5 → between description and progress)
	if type(cfg.Buttons) == "table" and #cfg.Buttons > 0 then
		local brow = Create("Frame", { Parent = content, BackgroundTransparency = 1, ZIndex = 6,
			Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 2 })
		Create("UIListLayout", { Parent = brow, FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.Fill, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
		for i, b in cfg.Buttons do
			local nb = ElementSkin(brow, 22); nb.LayoutOrder = i; nb.ZIndex = 7
			if b.Primary then Theme.Retag(nb, { BackgroundColor3 = "Accent" }); nb.BackgroundColor3 = accent end
			MakeText(nb, b.Text or "OK", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 12, ZIndex = 7,
				TextColor3 = b.Primary and Color3.fromRGB(14, 17, 15) or Color3.fromRGB(235, 235, 235),
				ThemeTag = b.Primary and { TextColor3 = "Background" } or { TextColor3 = "Text" } })
			nb.MouseButton1Click:Connect(function()
				if b.Callback then Library:SafeCall(b.Callback) end
				handle:Close()
			end)
		end
	end

	-- click to dismiss (behind the action buttons so they get the click)
	local btn = Create("TextButton", { Parent = frame, Text = "", BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 5 })
	btn.MouseButton1Click:Connect(function() handle:Close() end)

	if duration > 0 then
		task.delay(duration + 0.05, function() handle:Close() end)
	end

	return handle
end

--- Set the screen corner toasts appear in.
--- side: "BottomRight" | "BottomLeft" | "TopRight" | "TopLeft"
function Library:SetNotificationSide(side: string)
	ApplyNotificationSide(side)
end

--- Make the whole UI see-through. alpha: 0 (opaque) … 1 (invisible).
function Library:SetTransparency(alpha: number)
	ApplyTransparency(alpha)
end

--- Scale the whole UI. n: 0.5 … 2 (1 = default).
function Library:SetScale(n: number)
	ApplyScale(n)
end

--- Apply a full theme (partial tables are fine; only the given keys change).
--- Call this BEFORE :CreateSettingsPage so the color pickers reflect your style.
--- Keys: Background, Border, Inline, Element, "Hovered Element", "Page Background",
--- Outline, Gradient, Text, "Text Stroke", "Placeholder Text", Accent.
function Library:SetTheme(theme: Theme)
	Theme.Load(theme)
end

--- Register a named preset so it appears in the Settings → Theme presets dropdown.
function Library:AddTheme(name: string, theme: Theme)
	Presets[name] = theme
end

--- Set the neon glow intensity on accent bars (sliders/progress). 0 = off, 1 = max.
function Library:SetGlow(intensity: number)
	ApplyGlowIntensity(intensity)
end

--- Serialize the current theme to a JSON string ({ key = "#rrggbb", ... }).
function Library:ExportTheme(): string
	local out = {}
	for key, color in Theme.Values do
		if typeof(color) == "Color3" then out[key] = "#" .. color:ToHex() end
	end
	return HttpService:JSONEncode(out)
end

--- Apply a theme from a JSON string (as produced by ExportTheme, or hand-written
--- with "#rrggbb" / {r,g,b} values). Returns (ok, errorMessage?).
function Library:ImportTheme(json: string): (boolean, string?)
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(decoded) ~= "table" then return false, "invalid JSON" end
	local theme = {}
	for key, value in decoded do
		local color
		if type(value) == "string" then
			local okc, c = pcall(Color3.fromHex, (value:gsub("#", "")))
			if okc then color = c end
		elseif type(value) == "table" and value[1] then
			color = Color3.fromRGB(value[1], value[2], value[3])
		end
		if color then theme[key] = color end
	end
	if next(theme) == nil then return false, "no valid colours found" end
	Theme.Load(theme)
	return true
end

--- Toggle element border outlines on/off (a flatter look when off).
function Library:SetOutlines(on: boolean)
	Config.Outlines = on
	for s, e in BorderStrokes do
		local ok = pcall(function()
			s.Transparency = on and e.base or 1
			if e.parent and e.parent:IsA("GuiObject") then
				e.parent.BorderSizePixel = on and e.border or 0
			end
		end)
		if not ok then BorderStrokes[s] = nil end -- prune destroyed instances
	end
end

--- Toggle glassmorphism (translucent UI + a world blur behind it while the menu is open).
function Library:SetGlass(on: boolean)
	ApplyGlass(on)
end

--- Set the glass-mode blur strength (0..40).
function Library:SetGlassBlur(n: number)
	Config.GlassBlur = math.clamp(n, 0, 40)
	refreshGlass()
end

--==============================================================================
-- Overlays: Loader, MessageBox, KeySystem
--==============================================================================

-- shared dimmed backdrop + centered panel (in ModalHolder; sibling z-index)
-- opts: Dim, Draggable (whole modal), Closable (top-right X), OnClose.
-- Returns: backdrop, content (parent your stacked content here), close, maid, panel.
local function buildModal(width: number, opts)
	opts = opts or {}
	local modalMaid = Maid.new()
	LibMaid:GiveTask(modalMaid)
	local backdrop = Create("Frame", { Parent = ModalHolder, BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 })
	modalMaid:GiveTask(backdrop)
	if opts.Dim ~= false then Tween.To(backdrop, { BackgroundTransparency = 0.5 }) end

	local panel = Create("Frame", { Parent = backdrop, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2, BackgroundColor3 = Color3.fromRGB(14, 17, 15),
		ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	Stroke(panel, "Outline")
	Corner(panel, 6)
	Create("Frame", { Parent = panel, Size = UDim2.new(1, 0, 0, 2), ZIndex = 3, BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { BackgroundColor3 = "Accent" } })
	trackScale(panel)

	-- inner content holder (has the stacked layout; callers parent their content here
	-- so a close button / drag can live on the outer panel without the list moving it)
	local content = Create("Frame", { Parent = panel, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	Create("UIPadding", { Parent = content, PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) })
	Create("UIListLayout", { Parent = content, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center })

	local function close()
		Tween.To(backdrop, { BackgroundTransparency = 1 })
		local last = Tween.Fade(panel, false, Config.FadeSpeed)
		local function fin() keepCapability(); modalMaid:Clean() end
		if last then last.Completed:Once(fin) else task.delay(0.25, fin) end
	end

	-- drag by grabbing the content (labels / empty areas) — buttons & the key box
	-- sink input so they still click/type normally; moves the whole outer panel
	if opts.Draggable then MakeDraggable(panel, content, modalMaid) end

	if opts.Closable then
		local x = Create("TextButton", { Parent = panel, Text = "", AutoButtonColor = false, ZIndex = 4,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1 })
		local xl = MakeText(x, "×", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center, TextSize = 22, ZIndex = 4,
			TextColor3 = Color3.fromRGB(170, 170, 170), ThemeTag = { TextColor3 = "Placeholder Text" } })
		modalMaid:GiveTask(x.MouseEnter:Connect(function() Tween.To(xl, { TextColor3 = Theme.Values.Text }) end))
		modalMaid:GiveTask(x.MouseLeave:Connect(function() Tween.To(xl, { TextColor3 = Theme.Values["Placeholder Text"] }) end))
		modalMaid:GiveTask(x.MouseButton1Click:Connect(function()
			close()
			if opts.OnClose then pcall(opts.OnClose) end
		end))
	end

	return backdrop, content, close, modalMaid, panel
end

--- A simple progress/loading screen. Returns a handle:
---   :SetProgress(0..1)  :SetStatus(text)  :SetTitle(text)  :Finish(delay?)  :Close()
function Library:Loader(opts)
	opts = opts or {}
	local _, panel, close = buildModal(opts.Width or 320, { Dim = opts.Dim })

	if opts.Logo and opts.Logo ~= "" then
		Create("ImageLabel", { Parent = panel, BackgroundTransparency = 1, Size = UDim2.fromOffset(56, 56),
			LayoutOrder = 0, ScaleType = Enum.ScaleType.Fit, Image = AssetUrl(opts.Logo),
			ImageColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { ImageColor3 = "Accent" } })
	end
	local title = MakeText(panel, opts.Title or "Loading", { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1,
		FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center })
	local status = MakeText(panel, opts.Status or "Please wait…", { Size = UDim2.new(1, 0, 0, 15), LayoutOrder = 2,
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(185, 185, 185),
		ThemeTag = { TextColor3 = "Placeholder Text" } })

	local track = Create("Frame", { Parent = panel, Size = UDim2.new(1, 0, 0, 8), LayoutOrder = 3,
		BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2, BackgroundColor3 = Color3.fromRGB(30, 36, 31),
		ThemeTag = { BackgroundColor3 = "Element", BorderColor3 = "Border" } })
	Stroke(track, "Outline")
	Corner(track, 3)
	local fill = Create("Frame", { Parent = track, Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { BackgroundColor3 = "Accent" } })
	Corner(fill, 3)
	addGlow(fill)

	local handle = {}
	function handle:SetProgress(a) Tween.To(fill, { Size = UDim2.new(math.clamp(a, 0, 1), 0, 1, 0) },
		Tween.Info(nil, Enum.EasingStyle.Quart)) end
	function handle:SetStatus(t) status.Text = tostring(t) end
	function handle:SetTitle(t) title.Text = tostring(t) end
	function handle:Close() close() end
	function handle:Finish(delay) handle:SetProgress(1); task.delay(delay or 0.4, close) end
	return handle
end

--- A modal message box. opts: { Title, Text, Buttons = { {Text=, Callback=, Primary=bool}, ... } }.
--- Convenience: opts.Confirm / opts.Cancel callbacks create Yes/No buttons.
function Library:MessageBox(opts)
	opts = opts or {}
	local _, panel, close = buildModal(opts.Width or 340, {})

	MakeText(panel, opts.Title or "Notice", { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0,
		FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center })
	if opts.Text and opts.Text ~= "" then
		MakeText(panel, opts.Text, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1,
			TextWrapped = true, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Color3.fromRGB(210, 210, 210), ThemeTag = { TextColor3 = "Text" } })
	end

	local buttons = opts.Buttons
	if not buttons then
		buttons = {}
		if opts.Confirm then table.insert(buttons, { Text = opts.ConfirmText or "Confirm", Callback = opts.Confirm, Primary = true }) end
		if opts.Cancel then table.insert(buttons, { Text = opts.CancelText or "Cancel", Callback = opts.Cancel }) end
		if #buttons == 0 then buttons = { { Text = "OK", Primary = true } } end
	end

	local row = Create("Frame", { Parent = panel, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 2 })
	Create("UIListLayout", { Parent = row, FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	for i, b in buttons do
		local btn = ElementSkin(row, 24)
		btn.LayoutOrder = i
		if b.Primary then
			Theme.Retag(btn, { BackgroundColor3 = "Accent" })
			btn.BackgroundColor3 = Theme.Values.Accent
		end
		MakeText(btn, b.Text or "OK", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = b.Primary and Color3.fromRGB(14, 17, 15) or Color3.fromRGB(235, 235, 235),
			ThemeTag = b.Primary and { TextColor3 = "Background" } or { TextColor3 = "Text" } })
		btn.MouseButton1Click:Connect(function()
			close()
			if b.Callback then Library:SafeCall(b.Callback) end
		end)
	end
	return { Close = close }
end

--- A text-input dialog. opts: { Title, Text, Placeholder, Default, Numeric,
--- Confirm = function(text), Cancel = function() }. Confirm gets the entered string.
function Library:Prompt(opts)
	opts = opts or {}
	local _, panel, close = buildModal(opts.Width or 340, { Draggable = true, Closable = true })

	MakeText(panel, opts.Title or "Input", { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0,
		FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center })
	if opts.Text and opts.Text ~= "" then
		MakeText(panel, opts.Text, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1,
			TextWrapped = true, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, ThemeTag = { TextColor3 = "Text" } })
	end
	local box, boxStroke = ElementSkin(panel, 32)
	box.LayoutOrder = 2
	box.AutoButtonColor = false
	local input = Create("TextBox", { Parent = box, FontFace = GetFont(), TextSize = 14, Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Text = opts.Default or "", ClearTextOnFocus = false,
		TextColor3 = Color3.fromRGB(235, 235, 235), TextXAlignment = Enum.TextXAlignment.Center,
		PlaceholderText = opts.Placeholder or "", PlaceholderColor3 = Color3.fromRGB(150, 153, 150),
		BorderSizePixel = 0, ThemeTag = { TextColor3 = "Text", PlaceholderColor3 = "Placeholder Text" } })
	Create("UIPadding", { Parent = input, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })

	local function submit()
		local text = input.Text
		if opts.Numeric and not tonumber(text) then return end
		close()
		if opts.Confirm then Library:SafeCall(opts.Confirm, text) end
	end
	input.FocusLost:Connect(function(enter) if enter then submit() end end)

	local row = Create("Frame", { Parent = panel, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 3 })
	Create("UIListLayout", { Parent = row, FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local cancel = ElementSkin(row, 26); cancel.LayoutOrder = 1
	MakeText(cancel, opts.CancelText or "Cancel", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	cancel.MouseButton1Click:Connect(function() close(); if opts.Cancel then Library:SafeCall(opts.Cancel) end end)
	local okBtn = ElementSkin(row, 26); okBtn.LayoutOrder = 2
	Theme.Retag(okBtn, { BackgroundColor3 = "Accent" }); okBtn.BackgroundColor3 = Theme.Values.Accent
	MakeText(okBtn, opts.ConfirmText or "OK", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(14, 17, 15), ThemeTag = { TextColor3 = "Background" } })
	okBtn.MouseButton1Click:Connect(submit)
	return { Close = close }
end

--- A scrollable changelog panel. opts: { Title, Entries }. Each entry is either a
--- plain string line, or { Version=, Date=, Notes = { "line", ... } }.
function Library:Changelog(opts)
	opts = opts or {}
	local _, panel, close = buildModal(opts.Width or 400, { Draggable = true, Closable = true })
	MakeText(panel, opts.Title or "Changelog", { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0,
		FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center })
	local scroll = Create("ScrollingFrame", { Parent = panel, LayoutOrder = 1, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 260), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4, BorderSizePixel = 0, ScrollBarImageColor3 = Color3.fromRGB(202, 243, 255),
		ThemeTag = { ScrollBarImageColor3 = "Accent" } })
	Create("UIListLayout", { Parent = scroll, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	Create("UIPadding", { Parent = scroll, PaddingRight = UDim.new(0, 6) })
	local order = 0
	local function add(text, opts2)
		order += 1
		opts2 = opts2 or {}
		opts2.Parent = scroll; opts2.LayoutOrder = order
		opts2.Size = UDim2.new(1, 0, 0, 0); opts2.AutomaticSize = Enum.AutomaticSize.Y; opts2.TextWrapped = true
		opts2.TextXAlignment = Enum.TextXAlignment.Left
		return MakeText(scroll, text, opts2)
	end
	for _, e in (opts.Entries or {}) do
		if type(e) == "string" then
			add(e, { TextSize = 13, ThemeTag = { TextColor3 = "Text" } })
		elseif type(e) == "table" then
			local head = e.Version or ""
			if e.Date and e.Date ~= "" then head = head .. "  ·  " .. e.Date end
			add(head, { FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 14,
				TextColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { TextColor3 = "Accent" } })
			for _, note in (e.Notes or {}) do
				add("•  " .. note, { TextSize = 13, TextColor3 = Color3.fromRGB(205, 210, 205), ThemeTag = { TextColor3 = "Text" } })
			end
		end
	end
	return { Close = close }
end

--- A modern key-system gate. opts:
---   Title          window/hub name (accent, bold)
---   TitleColor     Color3 to pin the title colour (e.g. gold over green buttons)
---   Brand          small line under the title (e.g. "yoursite.com")
---   Badge          accent pill next to the brand (e.g. "FREE")
---   Logo           rbxassetid (no prefix) shown above the title
---   Note           instruction line (wraps, never clips)
---   Placeholder    key-box placeholder
---   UnlockText     primary button text (default "Unlock")
---   Footer         small print under the buttons (wraps)
---   SaveKey        bool — remember a valid key on disk
---   Links          { {Text=, Url=} } — stacked "Get Key" buttons (copy the url)
---   Progress       false to hide the checkpoint progress bar
---   Blocking       true  → yields the caller until a valid key, then returns true
---   Validate       function(key) -> boolean[, message]   (HTTP auth / whitelist)
---   OnSuccess      function(key)   OnFail = function()   OnClose = function() (user shut the gate)
--- The card is draggable and has a close (×) button. Non-blocking returns a handle:
---   :Close() :SetProgress(0..1) :SetStatus(text) :SetNote(text).
--- Blocking yields and returns `true` once a key is accepted, or `false` if the
--- user closes the gate — so you can bail cleanly:
---   if not BloxUI:KeySystem({ Blocking = true, ... }) then return end
--- If SaveKey and a stored key validates, it succeeds instantly.
function Library:KeySystem(opts)
	opts = opts or {}
	local closed = false
	local _, panel, close, maid, outer = buildModal(opts.Width or 380, {
		Draggable = true, Closable = true,
		OnClose = function() closed = true; if opts.OnClose then Library:SafeCall(opts.OnClose) end end,
	})
	local keyFile = Folders.Root .. "/key.txt"
	local DARK = Color3.fromRGB(14, 17, 15)

	-- subtle hover that lerps a button's fill toward a target colour
	local function bindHover(btn, base, hovered)
		maid:GiveTask(btn.MouseEnter:Connect(function() Tween.To(btn, { BackgroundColor3 = hovered }) end))
		maid:GiveTask(btn.MouseLeave:Connect(function() Tween.To(btn, { BackgroundColor3 = base }) end))
	end

	-- optional logo
	if opts.Logo and opts.Logo ~= "" then
		Create("ImageLabel", { Parent = panel, BackgroundTransparency = 1, LayoutOrder = 1,
			Size = UDim2.fromOffset(54, 54), ScaleType = Enum.ScaleType.Fit,
			Image = AssetUrl(opts.Logo), ImageColor3 = Color3.fromRGB(202, 243, 255),
			ThemeTag = { ImageColor3 = "Accent" } })
	end

	-- title (accent by default; TitleColor pins a custom colour, e.g. gold over
	-- green buttons). Wraps so a long hub name never clips.
	MakeText(panel, opts.Title or "Key System", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 22,
		TextColor3 = opts.TitleColor or Theme.Values.Accent,
		ThemeTag = opts.TitleColor and {} or { TextColor3 = "Accent" } })

	-- brand line + optional accent pill badge (rendered, so no broken glyphs)
	if (opts.Brand and opts.Brand ~= "") or opts.Badge then
		local brandRow = Create("Frame", { Parent = panel, BackgroundTransparency = 1, LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
		Create("UIListLayout", { Parent = brandRow, FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder })
		if opts.Brand and opts.Brand ~= "" then
			MakeText(brandRow, opts.Brand, { LayoutOrder = 1, Size = UDim2.new(0, 0, 0, 16),
				AutomaticSize = Enum.AutomaticSize.X, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = Color3.fromRGB(170, 175, 170), ThemeTag = { TextColor3 = "Placeholder Text" } })
		end
		if opts.Badge and opts.Badge ~= "" then
			local pill = Create("Frame", { Parent = brandRow, LayoutOrder = 2, Size = UDim2.new(0, 0, 0, 17),
				AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Theme.Values.Accent,
				BackgroundTransparency = 0.8, BorderSizePixel = 0, ThemeTag = { BackgroundColor3 = "Accent" } })
			Corner(pill, 5)
			Create("UIPadding", { Parent = pill, PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) })
			MakeText(pill, opts.Badge, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
				FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 11,
				TextColor3 = Theme.Values.Accent, ThemeTag = { TextColor3 = "Accent" } })
		end
	end

	-- instruction / live status line (wraps, auto-height → never clips)
	local note = MakeText(panel, opts.Note or "Enter your key below to continue. Don't have one? Get a key using the buttons below.",
		{ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(195, 198, 195),
		ThemeTag = { TextColor3 = "Text" } })

	-- checkpoint progress bar (optional)
	local progressFill
	if opts.Progress ~= false then
		local track = Create("Frame", { Parent = panel, LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = Theme.Values.Element, BackgroundTransparency = 0.25, BorderSizePixel = 0,
			ThemeTag = { BackgroundColor3 = "Element" } })
		Corner(track, 3)
		progressFill = Create("Frame", { Parent = track, Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0,
			BackgroundColor3 = Theme.Values.Accent, ThemeTag = { BackgroundColor3 = "Accent" } })
		Corner(progressFill, 3)
		addGlow(progressFill)
	end
	local function setProgress(a)
		if progressFill then Tween.To(progressFill, { Size = UDim2.new(math.clamp(a, 0, 1), 0, 1, 0) },
			Tween.Info(nil, Enum.EasingStyle.Quart)) end
	end

	-- key input (taller, clear placeholder, accent focus glow)
	local box, boxStroke = ElementSkin(panel, 40)
	box.LayoutOrder = 6
	box.AutoButtonColor = false
	box.ClipsDescendants = true
	local input = Create("TextBox", { Parent = box, FontFace = GetFont(), TextSize = 14, Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Text = "", ClearTextOnFocus = false, TextColor3 = Color3.fromRGB(235, 235, 235),
		TextXAlignment = Enum.TextXAlignment.Center, ClipsDescendants = true,
		PlaceholderText = opts.Placeholder or "Paste your key here", PlaceholderColor3 = Color3.fromRGB(150, 153, 150),
		BorderSizePixel = 0, ThemeTag = { TextColor3 = "Text", PlaceholderColor3 = "Placeholder Text" } })
	Create("UIPadding", { Parent = input, PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
	FocusHighlight(input, boxStroke, maid)

	local handle = {}
	local accepted = false
	local function validate(key)
		key = (key or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if key == "" then
			note.Text = "Enter a key first — paste it into the box above."
			return
		end
		local ok, result, msg = pcall(opts.Validate or function() return false end, key)
		if ok and result then
			accepted = true
			if opts.SaveKey and HasFileSystem then pcall(writefile, keyFile, key) end
			setProgress(1)
			Library:Notification({ Title = "Key System", Description = "Key accepted — welcome!", Type = "success", Duration = 4 })
			close()
			if opts.OnSuccess then Library:SafeCall(opts.OnSuccess, key) end
		else
			note.Text = msg or "That key is invalid or expired. Try again."
			Library:Notification({ Title = "Key System", Description = msg or "Invalid key.", Type = "error", Duration = 5 })
			-- shake the whole modal
			local p = outer.Position
			Tween.To(outer, { Position = p + UDim2.fromOffset(8, 0) }, Tween.Info(0.05))
			task.delay(0.05, function() Tween.To(outer, { Position = p }, Tween.Info(0.12, Enum.EasingStyle.Elastic)) end)
			if opts.OnFail then Library:SafeCall(opts.OnFail) end
		end
	end

	-- primary "Unlock" button (full width, accent, hover)
	local unlock = Create("TextButton", { Parent = panel, Text = "", AutoButtonColor = false, LayoutOrder = 7,
		Size = UDim2.new(1, 0, 0, 42), BorderSizePixel = 0, BackgroundColor3 = Theme.Values.Accent,
		ThemeTag = { BackgroundColor3 = "Accent" } })
	Corner(unlock, 6)
	MakeText(unlock, opts.UnlockText or "Unlock", { Size = UDim2.fromScale(1, 1), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center, FontFace = Font.fromEnum(Enum.Font.GothamBold), TextSize = 15,
		TextColor3 = DARK, ThemeTag = { TextColor3 = "Background" } })
	bindHover(unlock, Theme.Values.Accent, Theme.Values.Accent:Lerp(Color3.new(1, 1, 1), 0.14))
	maid:GiveTask(unlock.MouseButton1Click:Connect(function() validate(input.Text) end))
	input.FocusLost:Connect(function(enter) if enter then validate(input.Text) end end)

	-- secondary "Get Key" buttons, stacked full-width (no horizontal clipping)
	for i, link in (opts.Links or {}) do
		local lb = ElementSkin(panel, 36)
		lb.LayoutOrder = 7 + i
		lb.AutoButtonColor = false
		MakeText(lb, link.Text or "Get a Key", { Size = UDim2.fromScale(1, 1), TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center, FontFace = Font.fromEnum(Enum.Font.GothamMedium), TextSize = 14,
			TextColor3 = Theme.Values.Accent, ThemeTag = { TextColor3 = "Accent" } })
		bindHover(lb, Theme.Values.Element, Theme.Values["Hovered Element"])
		maid:GiveTask(lb.MouseButton1Click:Connect(function()
			if link.Url and setclipboard then pcall(setclipboard, link.Url) end
			note.Text = "Key link copied — open it in your browser, finish the checkpoints, then paste your key here."
			setProgress(0.5)
			Library:Notification({ Title = "Key System", Description = "Link copied to clipboard.", Type = "info", Duration = 4 })
		end))
	end

	-- footer small print (wraps, auto-height → never clips)
	if opts.Footer and opts.Footer ~= "" then
		MakeText(panel, opts.Footer, { LayoutOrder = 100, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(135, 138, 135),
			ThemeTag = { TextColor3 = "Placeholder Text" } })
	end

	function handle:Close() close() end
	function handle:SetProgress(a) setProgress(a) end
	function handle:SetStatus(t) note.Text = tostring(t) end
	function handle:SetNote(t) note.Text = tostring(t) end

	-- try a previously-saved key
	if opts.SaveKey and HasFileSystem and isfile(keyFile) then
		task.defer(function() validate(readfile(keyFile)) end)
	end

	-- Blocking gate: yield the caller until a key is accepted (→ true) or the user
	-- closes the gate (→ false). Lets you gate a whole hub in one line:
	--   if not BloxUI:KeySystem({ Blocking = true, ... }) then return end
	if opts.Blocking then
		while not accepted and not closed do task.wait(0.05) end
		return accepted
	end
	return handle
end

--==============================================================================
-- Settings page (Theming / Configs / Settings)
--==============================================================================

function Library:CreateSettingsPage(window, watermark, keybindList, options: SettingsPageConfig?)
	options = options or {}
	local tab = window:Tab({ Name = options.Name or "Settings", Columns = options.Columns or 2, Order = options.Order })
	tab.SettingsSections = {}
	tab:SetSettingsPosition(options.SettingsPosition or "Top")
	tab._buildingSettings = true
	if HasFileSystem then
		local cfgSection = tab:Section({ Name = "Configs", Side = 1 })
		tab.SettingsSections.Configs = cfgSection
		local cfgName, cfgSelected, autoDD
		local createdLabel, usedLabel, savedLabel
		local function refreshDetails()
			if Library._unloaded or tab.Destroyed then return end
			keepCapability()
			if not createdLabel then return end
			local selected = cfgSelected or cfgName
			local details = selected and Library:ReadConfig(selected) and Library:GetConfigDetails(selected)
			createdLabel:SetText("Created: " .. (details and details.Created or "Select a config"))
			usedLabel:SetText("Last used: " .. (details and details.LastUsed or "-"))
			savedLabel:SetText("Last saved: " .. (details and details.Updated or "-"))
		end
		local function cfgNames()
			local n = { "None" }
			for _, c in Library:ListConfigs() do n[#n + 1] = c end
			return n
		end
		local cfgList = cfgSection:Searchbox({ Name = "Configs", Flag = "ConfigList", Items = Library:ListConfigs(),
			Callback = function(v) cfgSelected = v; refreshDetails() end })
		cfgSection:Textbox({ Name = "Config name", Flag = "ConfigName", Placeholder = "name..",
			Callback = function(v) cfgName = v; refreshDetails() end })
		local cd = cfgSection:Button()
		cd:Add("Create", function()
			if cfgName and cfgName ~= "" then
				-- Creating over a name that already exists REPLACES it, because
				-- SaveConfig is a writefile. That is the right behaviour, but
				-- reporting "Created" for what was really an overwrite is not --
				-- it reads as a new config until you notice the old one is gone.
				local existed = Library:ReadConfig(cfgName) ~= nil
				if Library:SaveConfig(cfgName) then
					Library:Notification("Configs",
						(existed and "Replaced '" or "Created '") .. cfgName .. "'", 4, "success")
					cfgList:Refresh(Library:ListConfigs()); refreshDetails()
					cfgList:Set(cfgName)
					if autoDD then autoDD:Refresh(cfgNames()); autoDD:Set(Library:GetAutoLoad() or "None") end
				else
					Library:Notification("Configs", "Could not create this config. Check the name and file access.", 5, "error")
				end
			else
				Library:Notification("Configs", "Type a name first.", 4, "warning")
			end
		end)
		cd:Add("Delete", function()
			if cfgSelected then
				if not Library:DeleteConfig(cfgSelected) then
					Library:Notification("Configs", "Could not delete this profile. Check file access.", 5, "warning")
					return
				end
				Library:Notification("Configs", "Deleted '" .. cfgSelected .. "'", 4, "warning")
				cfgSelected = nil -- the file is gone; clear so a second Delete can't re-notify a stale name
				cfgList:Refresh(Library:ListConfigs()); refreshDetails()
				if autoDD then autoDD:Refresh(cfgNames()); autoDD:Set(Library:GetAutoLoad() or "None") end
			end
		end)
		local ls = cfgSection:Button()
		ls:Add("Load", function()
			if cfgSelected then
				local ok, err = Library:LoadProfile(cfgSelected)
				keepCapability()
				if ok then Library:Notification("Configs", "Loaded '" .. cfgSelected .. "'", 4, "success")
				else Library:Notification("Configs", "Load failed: " .. tostring(err), 6, "error") end
				refreshDetails()
			end
		end)
		ls:Add("Save", function()
			-- Save always overwrites its target -- SaveConfig is a writefile, which
			-- replaces the file outright. What was missing was a target: with nothing
			-- picked in the dropdown this was a silent no-op, no write and no message,
			-- which reads exactly like "saving is broken".
			-- The SELECTION wins over the name box on purpose. The dropdown is what
			-- shows which config you are on, and a stale name left in the box must
			-- never silently redirect the save somewhere else. The box is only a
			-- fallback so the button still does something on a fresh profile where
			-- nothing has been selected yet.
			local name = (cfgSelected ~= nil and cfgSelected ~= "" and cfgSelected)
				or (cfgName ~= nil and cfgName ~= "" and cfgName) or nil
			if not name then
				Library:Notification("Configs", "Pick a config or type a name first.", 4, "warning")
				return
			end
			local existed = Library:ReadConfig(name) ~= nil
			if Library:SaveConfig(name) then
				Library:Notification("Configs",
					(existed and "Overwrote '" or "Saved '") .. name .. "'", 4, "success")
				cfgList:Refresh(Library:ListConfigs()); refreshDetails()
				cfgList:Set(name)
				if autoDD then autoDD:Refresh(cfgNames()); autoDD:Set(Library:GetAutoLoad() or "None") end
			else
				Library:Notification("Configs", "Could not save '" .. name .. "'.", 5, "error")
			end
		end)
		-- auto-load: which config is applied automatically next launch
		autoDD = cfgSection:Dropdown({ Name = "Auto load", Flag = "__AutoLoad",
			Items = cfgNames(), Default = Library:GetAutoLoad() or "None",
			Tooltip = "Choose a saved config to apply automatically on the next launch.",
			Callback = function(v)
				if Library:SetAutoLoad(v) == false then
					Library:Notification("Configs", "Save this profile before assigning Auto load.", 5, "warning")
				end
			end })
		createdLabel = cfgSection:Label({ Name = "Created: Select a config", TextSize = 12 })
		usedLabel = cfgSection:Label({ Name = "Last used: -", TextSize = 12 })
		savedLabel = cfgSection:Label({ Name = "Last saved: -", TextSize = 12 })
		cfgSection:Label({ Name = "Times shown in your local time.", TextSize = 11 })
		Library._refreshConfigDetails = refreshDetails
		tab.Maid:GiveTask(function()
			if Library._refreshConfigDetails == refreshDetails then Library._refreshConfigDetails = nil end
		end)
		local activeProfile = Library:GetAutoLoad()
		if activeProfile then cfgList:Set(activeProfile) end
		refreshDetails()
	end


	local themePickers = {}
	local function syncThemePickers()
		for key, cp in themePickers do
			local value = Theme.Values[key]
			if value then cp:Set(value) end
		end
	end
	do
		local themeSection = tab:Section({ Name = "Theme presets", Side = 1 })
		tab.SettingsSections.ThemePresets = themeSection
		local presetNames = {}
		for name in Presets do table.insert(presetNames, name) end
		themeSection:Dropdown({ Name = "Preset", Flag = "ThemePreset", Items = presetNames,
			Callback = function(name)
				if Presets[name] then Theme.Load(Presets[name]); syncThemePickers() end
			end })
		themeSection:Toggle({ Name = "Outlines", Flag = "Outlines", Default = Config.Outlines,
			Callback = function(value) Library:SetOutlines(value) end })
	end

	local colorsSection = tab:Section({ Name = "Theme colors", Side = 1 })
	tab.SettingsSections.ThemeColors = colorsSection
	for key, value in Theme.Values do
		themePickers[key] = colorsSection:Label(key):AddColorpicker({
			Flag = key .. "_Theme", Default = value,
			Callback = function(color) Theme.Set(key, color) end,
		})
	end

	-- Theme JSON: export the live theme / import a pasted one (portable across hubs)
	local jsonSection = tab:Section({ Name = "Theme JSON", Side = 1 })
	tab.SettingsSections.ThemeJSON = jsonSection
	local jsonBox = jsonSection:Textbox({ Name = "Theme JSON", Flag = "ThemeJSON",
		Placeholder = "Paste theme JSON, then Import…" })
	local jrow = jsonSection:Button()
	jrow:Add("Export", function()
		local json = Library:ExportTheme()
		jsonBox:Set(json)
		if setclipboard then pcall(setclipboard, json) end
		Library:Notification({ Title = "Theme", Description = "Exported to the box + clipboard.", Type = "success", Duration = 4 })
	end)
	jrow:Add("Import", function()
		local ok, err = Library:ImportTheme(jsonBox:Get())
		if ok then
			syncThemePickers() -- reflect the imported colours in the pickers + their flags
			Library:Notification({ Title = "Theme", Description = "Theme imported.", Type = "success", Duration = 4 })
		else
			Library:Notification({ Title = "Theme", Description = "Import failed: " .. tostring(err), Type = "error", Duration = 5 })
		end
	end)

	-- Configs

	-- Config JSON: export/import all flags as JSON (works without filesystem too,
	-- via clipboard) so configs are portable across hubs and executors.
	local cjsonSection = tab:Section({ Name = "Config JSON", Side = 2 })
	tab.SettingsSections.ConfigJSON = cjsonSection
	local cjsonBox = cjsonSection:Textbox({ Name = "Config JSON", Flag = "ConfigJSON",
		Placeholder = "Paste config JSON, then Import…" })
	local cjrow = cjsonSection:Button()
	cjrow:Add("Export", function()
		local json = Library:GetConfig()
		cjsonBox:Set(json)
		if setclipboard then pcall(setclipboard, json) end
		Library:Notification({ Title = "Config", Description = "Exported to the box + clipboard.", Type = "success", Duration = 4 })
	end)
	cjrow:Add("Import", function()
		local ok, err = Library:LoadConfig(cjsonBox:Get())
		if ok then
			Library:Notification({ Title = "Config", Description = "Config imported.", Type = "success", Duration = 4 })
		else
			Library:Notification({ Title = "Config", Description = "Import failed: " .. tostring(err), Type = "error", Duration = 5 })
		end
	end)

	-- Settings
	local settingsSection = tab:Section({ Name = "Interface", Side = 2 })
	tab.SettingsSections.Interface = settingsSection
	local deviceStatus = settingsSection:Label("Detected: " .. Device.Detected .. " | Active: " .. Device.Mode)
	local function refreshDeviceStatus()
		deviceStatus:SetText("Detected: " .. Device.Detected .. " | Active: " .. Device.Mode)
	end
	table.insert(DeviceRefreshers, refreshDeviceStatus)
	tab.Maid:GiveTask(function() removeRefresher(DeviceRefreshers, refreshDeviceStatus) end)
	settingsSection:Dropdown({ Name = "Device mode", Flag = "DeviceMode", Items = { "Auto", "Mobile", "PC" }, Required = true,
		Default = Device.Preference, Callback = function(v) Library:SetDeviceMode(v) end })
	if watermark then
		settingsSection:Toggle({ Name = "Watermark", Flag = "ShowWatermark", Default = true,
			Callback = function(v) watermark:SetVisibility(v) end })
	end
	if keybindList then
		settingsSection:Toggle({ Name = "Keybind list", Flag = "ShowKeybinds", Default = true,
			Callback = function(v) keybindList:SetVisibility(v) end })
		settingsSection:Toggle({ Name = "Show keybind title", Flag = "KeybindTitleShown", Default = true,
			Callback = function(v) keybindList:SetTitleVisible(v) end })
		settingsSection:Toggle({ Name = "Keybind rich text", Flag = "KeybindRichText", Default = false,
			Callback = function(v) keybindList:SetRichText(v) end })
		settingsSection:Textbox({ Name = "Keybind title", Flag = "KeybindTitle", Placeholder = "Keybinds",
			Callback = function(v) keybindList:SetTitle((v and v ~= "") and v or "Keybinds") end })
	end
	settingsSection:Toggle({ Name = "Custom cursor", Flag = "CustomCursor", Default = Config.CustomCursor,
		Callback = function(v)
			Config.CustomCursor = v
			CursorBg.Visible = v and window.IsOpen and Device.Mode == "PC"
			if CursorBg.Visible then -- snap to the pointer now so it appears immediately
				local m = MousePos()
				CursorBg.Position = UDim2.fromOffset(m.X, m.Y)
			end
			UserInputService.MouseIconEnabled = not CursorBg.Visible
		end })
	settingsSection:Dropdown({ Name = "Notifications", Flag = "NotifSide",
		Items = { "BottomRight", "BottomLeft", "TopRight", "TopLeft" }, Default = Config.NotificationSide,
		Callback = function(v)
			ApplyNotificationSide(v)
			Library:Notification({ Title = "Notifications", Description = "Now anchored " .. v, Type = "info", Duration = 3 })
		end })
	settingsSection:Toggle({ Name = "Top-bar layout", Flag = "TopLayout", Default = (window.PreferredLayout == "Top"),
		Callback = function(v) window:SetLayout(v and "Top" or "Side") end })
	settingsSection:Slider({ Name = "UI scale", Flag = "UIScale", Min = 0.5, Max = 2, Decimals = 0.05,
		Default = Config.Scale, Callback = function(v) ApplyScale(v) end })
	settingsSection:Slider({ Name = "UI transparency", Flag = "UITransparency", Min = 0, Max = 1, Decimals = 0.01,
		Default = Config.Transparency, Suffix = "", Callback = function(v) ApplyTransparency(v) end })
	settingsSection:Slider({ Name = "Glow intensity", Flag = "GlowIntensity", Min = 0, Max = 1, Decimals = 0.01,
		Default = Config.GlowIntensity, Suffix = "", Callback = function(v) ApplyGlowIntensity(v) end })
	settingsSection:Toggle({ Name = "Glass mode", Flag = "Glass", Default = Config.Glass,
		Callback = function(v) Library:SetGlass(v) end })
	settingsSection:Slider({ Name = "Glass blur", Flag = "GlassBlur", Min = 0, Max = 40, Decimals = 1,
		Default = Config.GlassBlur, Suffix = "", Callback = function(v) Library:SetGlassBlur(v) end })
	settingsSection:Slider({ Name = "Notif. duration", Flag = "NotifDuration", Min = 1, Max = 15, Decimals = 0.5, Suffix = "s",
		Default = Config.NotificationDuration, Callback = function(v) Config.NotificationDuration = v end })
	settingsSection:Toggle({ Name = "Notif. sounds", Flag = "NotifSounds", Default = Config.NotificationSound ~= "",
		Callback = function(v) Config.NotificationSound = v and "rbxassetid://9080003278" or "" end })
	settingsSection:Slider({ Name = "Fade time", Flag = "FadeTime", Min = 0, Max = 1, Decimals = 0.01,
		Default = Config.FadeSpeed, Callback = function(v) Config.FadeSpeed = v end })
	settingsSection:Slider({ Name = "Tween time", Flag = "TweenTime", Min = 0, Max = 1, Decimals = 0.01,
		Default = Config.Tween.Time, Callback = function(v) Config.Tween.Time = v end })
	settingsSection:Dropdown({ Name = "Tween style", Flag = "TweenStyle",
		Items = { "Linear", "Quad", "Quart", "Cubic", "Sine", "Back", "Bounce", "Elastic", "Exponential" },
		Default = "Quad", Callback = function(v) Config.Tween.Style = Enum.EasingStyle[v] end })
	settingsSection:Label("Menu keybind"):AddKeybind({ Name = "Menu", Flag = "MenuKeybind",
		Default = Config.MenuKeybind, Mode = "Toggle",
		-- OnChanged, not Callback: this resyncs which key opens the menu, so it has to run when
		-- the binding is rebound or restored from a config -- not when the key is pressed.
		OnChanged = function()
			local f = Library.Flags["MenuKeybind"]
			if f and f.Key then
				local ok, enum = pcall(function() return Enum.KeyCode[(f.Key:gsub("Enum.KeyCode.", ""))] end)
				if ok then Config.MenuKeybind = enum end
			end
		end })
	settingsSection:Button():Add("Unload", function() Library:Unload() end)

	tab._buildingSettings = false
	tab:_ReflowSections()

	-- apply the auto-load config once, after the whole UI (and all its setters) exist
	local auto = Library:GetAutoLoad()
	if auto then
		task.defer(function()
			if Library._unloaded or tab.Destroyed then return end
			local raw = Library:ReadConfig(auto)
			if raw and not Library._unloaded then
				local loaded = Library:LoadConfig(raw)
				if loaded and not Library._unloaded then Library:_TouchConfigMetadata(auto, "use") end
				if loaded and Library._refreshConfigDetails then Library._refreshConfigDetails() end
			end
		end)
	end

	return tab
end

--==============================================================================
-- Unload
--==============================================================================

function Library:Unload()
	if self._unloaded then return end
	self._unloaded = true
	LibMaid:Clean()
	local env = getgenv and getgenv()
	local current = (env and env.BloxUI) or shared.BloxUI
	if current == nil or current == self then UserInputService.MouseIconEnabled = true end
	if env and env.BloxUI == self then env.BloxUI = nil end
	if shared.BloxUI == self then shared.BloxUI = nil end
end

--==============================================================================
-- Finalize
--==============================================================================

Input.Init()

if getgenv then getgenv().BloxUI = Library end
shared.BloxUI = Library

Library.LoadTime = os.clock() - LoadStart

return Library
