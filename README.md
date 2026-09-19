<div align="center">

# 🐙 KrakenUI

**A premium, self-contained GUI library for Roblox Luau executors.**
One file. Zero dependencies. Zero game logic. Just a beautiful, modern UI toolkit.

[![Luau](https://img.shields.io/badge/language-Luau-00A2FF?style=for-the-badge&logo=lua&logoColor=white)](https://luau-lang.org/)
[![Roblox](https://img.shields.io/badge/platform-Roblox-E2231A?style=for-the-badge&logo=roblox&logoColor=white)](https://www.roblox.com/)
[![Single File](https://img.shields.io/badge/architecture-single--file-6C4FE0?style=for-the-badge)](#-installation)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](#-license)
[![GitHub last commit](https://img.shields.io/github/last-commit/GGgodd211/KrakenLib?style=for-the-badge&color=6C4FE0)](https://github.com/GGgodd211/KrakenLib)

[Quick Start](#-quick-start) · [API Reference](#-api-reference) · [Theming](#-theming) · [Full Example](#-full-example) · [Contributing](#-contributing)

</div>

---

## 🧠 What is KrakenUI?

KrakenUI is a **pure UI framework** — windows, tabs, sections, 15+ interactive elements,
theming, fonts, icons, sound, animation presets, notifications, dialogs, a key-screen, a
settings panel and a keybind editor — all in **one monolithic `.luau` file** with no
`require`, no external modules, and **no game logic whatsoever**. Drop it into an empty
script and it boots a clean, empty window without errors.

Everything hangs off a single library object, however you name it:

```lua
local KrakenLib = loadstring(readfile("KrakenUI.luau"))()
```

From there, **actions** are called with a colon (`KrakenLib:Window(...)`, `KrakenLib:Modal(...)`)
and **stateful submodules** are accessed with a dot (`KrakenLib.Theming`, `KrakenLib.Sounds`,
`KrakenLib.Events`) — one consistent convention across the entire API.

---

## ✨ Features

| | |
|---|---|
| 🪟 **Windows & Tabs** | Draggable, 8-direction resizable windows · collapsible fade+slide tabs · minimize-to-bubble |
| 🧩 **15+ Elements** | Toggle, Slider, Dropdown, Keybind, Colorpicker, Textbox, Button, Label, Divider, Paragraph, Radio, Stepper, ProgressBar, Table, Image |
| 📐 **Composable Layout** | `Row(n)` for side-by-side columns, `Group()` for conditional visibility, `Accordion()` for exclusive panels — all nestable |
| 🎨 **Theming Engine** | 7 built-in presets, live accent/radius/border/density/glow controls, JSON theme export/import |
| 🔤 **Custom Fonts** | Built-in font presets + register your own Roblox Font Family assets |
| 🖼️ **Icon Registry** | `Get` / `Register` / `List` — drop in your own icon set in one line |
| 🔊 **Sound Engine** | Opt-in UI sound effects (click/hover/toggle/notify), fully customizable |
| 🎬 **Animation Presets** | FadeIn/Out, Pulse, Shake, SlideIn — reusable on any `GuiObject`, extensible via `Register` |
| 📡 **Event Bus & Hotkeys** | Global pub/sub events + hotkeys that work even with the menu closed |
| 💬 **Rich Feedback** | Toast notifications, persistent announcement banners, modal dialogs, context menus, tooltips |
| 🔑 **Key System** | Live format validation, rate-limiting, autosave, buy/discord links — generic, bring your own backend |
| ⏳ **Multi-stage Loader** | Weighted step progress bar with live sub-status, mini console log, skip button |
| 💾 **Config Persistence** | Save/load every flag to disk as JSON, list and delete saved profiles |
| ⚙️ **Built-in Panels** | Ready-made Settings window and Keybind Editor with conflict detection |
| 🔍 **Search & Navigate** | `Search(query)` + `ScrollToFlag(flag)` — jump straight to any element, anywhere |
| 🪟 **Multi-window** | `GetWindow(name)` / `CloseAll()` registry for managing several windows at once |

---

## 📦 Installation

**Option A — host it yourself and `loadstring` it:**

```lua
local KrakenLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/GGgodd211/KrakenLib/main/KrakenUI.luau"
))()
```

**Option B — load a local copy through your executor:**

```lua
local KrakenLib = loadstring(readfile("KrakenUI.luau"))()
```

Either way, the library is fully self-contained — no other files, no `require`, nothing else to install.

---

## 🚀 Quick Start

```lua
local KrakenLib = loadstring(readfile("KrakenUI.luau"))()

local win = KrakenLib:Window({ Title = "My Script", SubTitle = "v1.0", Name = "main" })
local tab = win:Tab({ Name = "Home", Icon = "settings" })
local sec = tab:Section({ Name = "General", Icon = "star" })

sec:Toggle({ Name = "Enable feature", Flag = "MyToggle", Callback = function(v)
    print("Toggle:", v)
end })

sec:Slider({ Name = "Speed", Min = 0, Max = 10, Decimals = 1, Suffix = "x", Flag = "Speed" })

KrakenLib:Notification({ Title = "Ready", Text = "KrakenUI loaded", Icon = "success" })
```

That's it — no setup, no boilerplate, no asset installation.

---

## 🧩 API Reference

All examples below assume `local KrakenLib = loadstring(...)()`.

<details>
<summary><strong>🪟 Windows, Tabs & Layout</strong></summary>

### `KrakenLib:Window(opts) -> Window`

| Field | Type | Description |
|---|---|---|
| `Title` | string | Window title |
| `SubTitle` | string | Optional subtitle |
| `Name` | string | Optional handle, used by `GetWindow(name)` |
| `Size` | UDim2 | Default `0, 620, 0, 420` |
| `MinSize` / `MaxSize` | Vector2 | Resize bounds |

```lua
local win = KrakenLib:Window({ Title = "My Script", SubTitle = "v1.0", Name = "main" })
win:SetTitle("New Title")
```

Windows are draggable, resizable from all 8 edges/corners, fade in on creation, glow with
the accent color, and can be minimized to a small draggable bubble.

### `Window:Tab(opts) -> Tab`

```lua
local tab = win:Tab({ Name = "Combat", Icon = "target" })
```

Fade+slide transition, animated active indicator, staggered fade-in of its contents.

### `Tab:Section(opts) -> Section`

```lua
local sec = tab:Section({ Name = "Aimbot", Icon = "target", Collapsed = false,
    OnCollapse = function(isCollapsed) end })
```

Collapsible card with an animated chevron. Every element method below lives on `Section`.

### `Tab:Accordion() -> Accordion`

A group of sections where only one is expanded at a time.

```lua
local acc = tab:Accordion()
local p1 = acc:Panel({ Name = "Profile A" })
local p2 = acc:Panel({ Name = "Profile B" })
```

### `Section:Row(count)` — side-by-side columns

```lua
local left, right = sec:Row(2)
left:Toggle({ Name = "Left toggle" })
right:Toggle({ Name = "Right toggle" })
```

Each column is a full element dispatcher — `Row` and `Group` nest inside each other freely.

### `Section:Group(opts)` — conditional visibility

```lua
local espGroup = sec:Group({ Name = "Enable ESP", Default = false, Flag = "ESPEnabled" })
espGroup:Colorpicker({ Name = "Outline color", Default = Color3.new(1, 0, 0) })
espGroup:Slider({ Name = "Thickness", Min = 1, Max = 5, Default = 1 })
```

A master toggle that shows/hides everything nested inside it.

</details>

<details>
<summary><strong>🧩 Elements</strong></summary>

Every element accepts an optional `Flag` (registers into `KrakenLib.Flags[flag]` and
`KrakenLib._elements[flag]`) and returns an object with `:Get()` / `:Set()`.

| Method | Purpose |
|---|---|
| `Section:Toggle(opts)` | On/off switch |
| `Section:Slider(opts)` | Draggable numeric slider with decimals + manual text entry |
| `Section:Dropdown(opts)` | Single or multi-select with search |
| `Section:Keybind(opts)` | Toggle / Hold / Always key binding |
| `Section:Colorpicker(opts)` | HSV picker + HEX input |
| `Section:Textbox(opts)` | Text input, optional numeric filter |
| `Section:Button(opts)` | Action button |
| `Section:Label(opts)` | Static text |
| `Section:Divider()` | Thin separator line |
| `Section:Paragraph(opts)` | Title + wrapped body text |
| `Section:Radio(opts)` | Inline mutually-exclusive pill buttons |
| `Section:Stepper(opts)` | Numeric value with −/+ buttons |
| `Section:ProgressBar(opts)` | Embeddable progress bar (`:Set(pct)`) |
| `Section:Table(opts)` | Scrollable data grid, sortable by column |
| `Section:Image(opts)` | Embedded image/banner with optional caption |

```lua
sec:Slider({
    Name = "Offset Y", Min = -10, Max = 10, Decimals = 1, Suffix = "m",
    Hint = "shifts position vertically", Flag = "OffsetY",
    Callback = function(value) end,
})

sec:Dropdown({ Name = "Weapon", Options = { "Knife", "Pistol", "Rifle" }, Multi = false })

sec:Keybind({ Name = "Open menu", Default = Enum.KeyCode.RightShift, Mode = "Toggle" })

sec:Colorpicker({ Name = "ESP Color", Default = Color3.fromRGB(255, 0, 0) })

sec:Radio({ Name = "Aim Target", Options = { "Head", "Chest", "Nearest" }, Default = "Head" })

sec:Stepper({ Name = "FOV", Min = 60, Max = 120, Step = 5, Default = 90 })

local bar = sec:ProgressBar({ Name = "Loading skin", Default = 0 })
bar:Set(0.65)

local tbl = sec:Table({
    Name = "Players", Columns = { "Name", "Distance" }, Sortable = true,
    Rows = { { Name = "Alex", Distance = 42 }, { Name = "Bob", Distance = 15 } },
})
tbl:SetRows({ { Name = "Carl", Distance = 8 } })

sec:Image({ Image = "rbxassetid://0000000000", Height = 120, Caption = "Preview" })
```

</details>

<details>
<summary><strong>💬 Feedback & Overlays</strong></summary>

### `KrakenLib:Notification(opts)`

```lua
KrakenLib:Notification({ Title = "Saved", Text = "Config saved", Icon = "success", Duration = 4 })
```

### `KrakenLib:Announcement(opts)`

A dismissible banner pinned to the top of the screen — unlike `Notification`, it stays until
closed (or `Duration` elapses). Great for update prompts.

```lua
KrakenLib:Announcement({
    Title = "Update available", Text = "v1.1 is out — click to update.", Icon = "info",
    Dismissible = true, OnDismiss = function() end,
})
```

### `KrakenLib:Modal(opts)`

```lua
KrakenLib:Modal({
    Title = "Reset settings?", Text = "This cannot be undone.",
    AcceptText = "Reset", CancelText = "Cancel",
    OnAccept = function() end, OnCancel = function() end,
})
```

### `KrakenLib:ContextMenu()`

```lua
local menu = KrakenLib:ContextMenu()
menu:Attach(someGuiObject, {
    { Name = "Copy", Icon = "copy", Callback = function() end },
    { Name = "Delete", Icon = "trash", Callback = function() end },
})
```

### `KrakenLib:Loader(opts):Run(onDone)`

Multi-stage weighted progress bar with per-step status icons, a mini console log, and a
skip button that appears after 3 seconds.

```lua
local loader = KrakenLib:Loader({
    Title = "MyScript", Subtitle = "Initializing...",
    Steps = {
        { Name = "Loading core...", Weight = 30, Fn = function() task.wait(0.2) end },
        { Name = "Building UI...",  Weight = 40, Fn = function() task.wait(0.2) end },
        { Name = "Done",            Weight = 30 },
    },
})
loader:Run(function() print("loaded") end)
```

### `KrakenLib:KeySystem(opts):Prompt(onSuccess)`

A generic (non-cheat-specific) license key screen: live `XXXX-XXXX-XXXX` format validation
with debounce, rate-limiting, disk autosave, buy/Discord links.

```lua
local ks = KrakenLib:KeySystem({
    Title = "Enter your key",
    BuyUrl = "https://example.com/buy",
    DiscordUrl = "https://discord.gg/example",
    RateLimit = { Attempts = 5, Window = 60 },
    Validate = function(key)
        if key == "AAAA-BBBB-CCCC" then return true end
        return false, "Invalid key"
    end,
})
ks:Prompt(function(validKey) print("unlocked:", validKey) end)
```

### `KrakenLib:Watermark(opts)` / `KrakenLib:KeybindList(opts)`

```lua
local wm = KrakenLib:Watermark({ Text = "MyScript", UpdateInterval = 1,
    UpdateFn = function() return ("MyScript | %d FPS"):format(60) end })
wm:Update("manual text")

local kl = KrakenLib:KeybindList({ Title = "Active binds" })
kl:Refresh({ { Name = "Menu", Key = "RightShift" } })
```

### `KrakenLib.Tooltip:Attach(guiObject, text)`

```lua
KrakenLib.Tooltip:Attach(someGuiObject, "This does X")
```

</details>

<details>
<summary><strong>🎨 Core Modules</strong></summary>

### `KrakenLib.Theming`

```lua
KrakenLib.Theming:List()                  -- {"Cyber Blue", "Dracula", ...}
KrakenLib.Theming:Use("Cyber Blue")
KrakenLib.Theming:SetAccent(Color3.fromRGB(255, 80, 80))
KrakenLib.Theming:SetRadius(14)           -- 0..20
KrakenLib.Theming:SetBorderThickness(2)   -- 0..3
KrakenLib.Theming:SetGlow(true)
KrakenLib.Theming:SetAnimSpeed(0.6)       -- lower = faster
KrakenLib.Theming:SetDensity("Compact")   -- Compact | Normal | Comfortable

local json = KrakenLib.Theming:Export()
KrakenLib.Theming:Import(json)

local unsubscribe = KrakenLib.Theming:OnChanged(function(colors) end)
```

### `KrakenLib.Fonts`

```lua
KrakenLib.Fonts:List()
KrakenLib.Fonts:Register("MyFont", "rbxassetid://1234567890", Enum.FontWeight.Bold)
KrakenLib.Fonts:SetDefault("MyFont", 14)
```

### `KrakenLib.Icons`

```lua
KrakenLib.Icons:Get("settings")
KrakenLib.Icons:Register("myicon", "rbxassetid://0000000000")
KrakenLib.Icons:List()
```

Built-in keys include: `settings, cog, search, close, minimize, restore, chevronUp/Down/Left/Right,
key, lock, unlock, info, warning, error, success, star, heart, bolt, save, load, trash, copy,
paste, refresh, filter, palette, sliders, tabs, keyboard, mouse, edit, plus, shield, friend, bag, eye`.

### `KrakenLib.Sounds`

Opt-in UI sound effects (click, hover, toggle, notify) — disabled by default.

```lua
KrakenLib.Sounds:SetEnabled(true)
KrakenLib.Sounds:SetVolume(0.5)
KrakenLib.Sounds:Register("click", "rbxassetid://0000000000")
KrakenLib.Sounds:Play("click")
```

### `KrakenLib.Animations`

Reusable tween presets for any `GuiObject`.

```lua
KrakenLib.Animations:Play(someFrame, "FadeIn")
KrakenLib.Animations:Play(someFrame, "Shake")
KrakenLib.Animations:Register("MyPreset", function(inst, opts) end)
```

Built-ins: `FadeIn`, `FadeOut`, `Pulse`, `Shake`, `SlideInLeft`, `SlideInRight`, `SlideInTop`.

### `KrakenLib.Events`

```lua
local off = KrakenLib.Events:On("PlayerDied", function(reason) end)
KrakenLib.Events:Fire("PlayerDied", "fall damage")
off()
```

### `KrakenLib.Hotkeys`

Global hotkeys, independent of any GUI element — fire even while the menu is closed.

```lua
KrakenLib.Hotkeys:Bind("ToggleMenu", Enum.KeyCode.RightShift, "Toggle", function(active) end)
KrakenLib.Hotkeys:List()
KrakenLib.Hotkeys:Unbind("ToggleMenu")
```

### `KrakenLib.Config`

```lua
KrakenLib.Config:Save("profile1")
KrakenLib.Config:Load("profile1")
KrakenLib.Config:List()
KrakenLib.Config:Delete("profile1")
```

</details>

<details>
<summary><strong>⚙️ Built-in Panels & Utilities</strong></summary>

### `KrakenLib:Settings(opts)`

Ready-made "Script Settings" window: theme presets, accent color, radius, border, density,
animation speed, font picker + custom font registration, sound toggle/volume, behavior
options, theme export/import.

```lua
KrakenLib:Settings({ OnExport = function(json) end, OnImport = function(json) end })
```

### `KrakenLib:KeybindEditor()`

Ready-made bind manager: add custom binds (Toggle/Hold/Always), delete, conflict highlighting.

```lua
KrakenLib:KeybindEditor()
for _, bind in ipairs(KrakenLib._binds) do print(bind.Name, bind.Mode, bind.Key) end
```

### Search & navigation

```lua
local results = KrakenLib:Search("offset")          -- {"OffsetX", "OffsetY", ...}
KrakenLib:ScrollToFlag(results[1])                    -- switches tab, scrolls, highlights
```

### Window registry

```lua
local win = KrakenLib:GetWindow("main")
KrakenLib:CloseAll()
```

### `KrakenLib:Unload()`

Disconnects every event, destroys the `ScreenGui`, clears flags/elements/hotkeys/events.

```lua
KrakenLib:Unload()
```

</details>

---

## 🎨 Theming

Seven built-in presets, switchable at any time — every open window updates live:

| Preset | Vibe |
|---|---|
| `Void Purple` | Default — deep violet accent, near-black background |
| `Cyber Blue` | Electric blue on dark slate |
| `Sunset` | Warm coral/orange on dark brown |
| `Mono Dark` | Grayscale, minimal |
| `Mono Light` | Grayscale, light background |
| `Nord` | Cool arctic blues |
| `Dracula` | Classic purple-on-dark developer theme |

```lua
KrakenLib.Theming:Use("Nord")
KrakenLib.Theming:SetAccent(Color3.fromRGB(255, 90, 90)) -- override the accent on top of any preset
```

---

## 🗂 Full Example

```lua
local KrakenLib = loadstring(readfile("KrakenUI.luau"))()

KrakenLib.Theming:Use("Cyber Blue")
KrakenLib.Sounds:SetEnabled(true)

local ks = KrakenLib:KeySystem({
    Title = "Enter key",
    Validate = function(key) return key == "DEMO-DEMO-DEMO" end,
})

ks:Prompt(function()
    local loader = KrakenLib:Loader({
        Title = "MyScript",
        Steps = {
            { Name = "Loading core...",  Weight = 30, Fn = function() task.wait(0.2) end },
            { Name = "Building UI...",   Weight = 40, Fn = function() task.wait(0.2) end },
            { Name = "Done",             Weight = 30 },
        },
    })

    loader:Run(function()
        local win = KrakenLib:Window({ Title = "MyScript", SubTitle = "v1.0", Name = "main" })

        local tabMain = win:Tab({ Name = "Home", Icon = "settings" })
        local sec = tabMain:Section({ Name = "General", Icon = "star" })

        sec:Toggle({ Name = "Example toggle", Flag = "Example", Default = false })
        sec:Slider({ Name = "Example slider", Min = 0, Max = 100, Decimals = 1, Suffix = "%", Flag = "ExampleSlider" })
        sec:Divider()

        local group = sec:Group({ Name = "Enable module", Default = false })
        group:Colorpicker({ Name = "Accent", Default = Color3.new(1, 1, 1) })

        local tabSettings = win:Tab({ Name = "Settings", Icon = "cog" })
        tabSettings:Section({ Name = "GUI" }):Button({
            Name = "Open library settings",
            Callback = function() KrakenLib:Settings() end,
        })

        KrakenLib:Watermark({ Text = "MyScript | loaded" })
        KrakenLib:Notification({ Title = "MyScript", Text = "Ready", Icon = "success" })
    end)
end)
```

---

## 🤝 Contributing

Issues and pull requests are welcome. If you're proposing a new element or module, please
keep the library's two hard rules in mind:

1. **Pure UI, no game logic.** KrakenUI never ships hooks, ESP, aim logic, or anti-cheat
   bypasses — it's a rendering/interaction layer only.
2. **Single file, zero dependencies.** Everything must live inside `KrakenUI.luau` with no
   `require` calls and no external asset dependencies beyond `rbxassetid`.

---

## 📄 License

This project is licensed under the **MIT License**. If a `LICENSE` file isn't already in the
repository root, add one with the standard MIT text before distributing.

---

<div align="center">

Made for the Roblox executor community · [github.com/GGgodd211/KrakenLib](https://github.com/GGgodd211/KrakenLib)

</div>
