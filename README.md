<div align="center">

# K R A K E N
### Native controls. Considered design.

**Расширяемая GUI-библиотека для Roblox · Luau · Один файл**

![Version](https://img.shields.io/badge/version-2.0.0-9B82FF?style=flat-square)
![Luau](https://img.shields.io/badge/language-Luau-16171D?style=flat-square&logo=lua&logoColor=white)
![Components](https://img.shields.io/badge/components-18-16171D?style=flat-square)
![Themes](https://img.shields.io/badge/themes-9-16171D?style=flat-square)

[Начало](#быстрый-старт) · [Компоненты](#компоненты) · [API](#полный-публичный-api) · [Темы](#темы-и-доступность) · [Изменения](#что-исправлено)

</div>

---

## Интерфейс без визуального шума

Графитовые поверхности, мягкие границы, фиолетовый акцент, увеличенные интервалы и ясная типографика. Акцент выделяет активную вкладку, а не окрашивает всё окно. Свечение по умолчанию выключено. Библиотека не содержит игровой логики.

| Основа | Возможности |
| :--- | :--- |
| **Workspace** | Несколько окон, перетаскивание, изменение размера, сворачивание, прокручиваемая навигация |
| **Components** | 18 компонентов, колонки, группы, аккордеоны, программное управление |
| **Appearance** | 9 тем, собственные палитры, живое обновление цветов, reduced motion |
| **Control** | Именованные окна, поиск по флагам и названиям, Command Palette, события |
| **Persistence** | JSON-конфиги, сериализация Color3 и клавиш, файловые профили при наличии API среды |

### Файлы

- [`KrakenUI.lua`](KrakenUI.lua) — полная библиотека в запрошенном формате Lua; использует Roblox Luau API.
- [`KrakenUI.luau`](KrakenUI.luau) — идентичный исходник с расширением Luau для репозитория.
- [`Example.client.lua`](Example.client.lua) — демонстрация интерфейса для Roblox Studio.
- [`SmokeTest.client.lua`](SmokeTest.client.lua) — проверка основных сценариев в Roblox Studio.

> Это нативный Roblox GUI, не веб-интерфейс. Для визуальной проверки нужен Roblox Studio / Roblox-клиент. Обычный Lua 5.x и браузер не предоставляют Instance, Color3 и сервисы Roblox.

## Быстрый старт

### Roblox Studio — рекомендуемый способ

Скопируйте содержимое `KrakenUI.luau` в **ModuleScript** с именем `KrakenUI` внутри `ReplicatedStorage`. Создайте **LocalScript** в `StarterPlayerScripts`:

```lua
local KrakenLib = require(game:GetService("ReplicatedStorage"):WaitForChild("KrakenUI"))

local window = KrakenLib:Window({
    Name = "main",
    Title = "Kraken Workspace",
    SubTitle = "YOUR INTERFACE / YOUR RULES",
    Size = UDim2.fromOffset(720, 500),
})
window:Center()

local home = window:Tab({ Name = "Overview", Icon = "star" })
local section = home:Section({ Name = "Workspace" })
section:Badge({ Text = "READY" })
section:Toggle({ Name = "Notifications", Flag = "notifications", Default = true })
section:Slider({ Name = "Volume", Flag = "volume", Min = 0, Max = 100, Default = 60 })
section:Dropdown({ Name = "Quality", Flag = "quality", Options = { "Low", "High" }, Default = "High" })
section:Button({ Name = "Search controls", Callback = function()
    KrakenLib:CommandPalette()
end })

KrakenLib.Hotkeys:Bind("menu", Enum.KeyCode.RightShift, "Toggle", function()
    window:Toggle()
end)
```

### Среда с локальным загрузчиком

Только если среда действительно предоставляет `readfile` и `loadstring`:

```lua
local KrakenLib = assert(loadstring(readfile("KrakenUI.lua")))()
```

Стандартный Roblox LocalScript этих функций не предоставляет. Для опубликованных проектов используйте ModuleScript. Загруженный модуль **не создаёт окно автоматически**: вызовите `:Window()`.

## Конвенции

```lua
KrakenLib:Window(options)           -- методы объекта: двоеточие
KrakenLib.Theming:Use("Obsidian")   -- модуль через точку, метод через двоеточие
KrakenLib.Flags.volume             -- чтение данных через точку
KrakenLib.Window(KrakenLib, options) -- эквивалент явного вызова через точку
```

`Flag` — уникальная строка. Повторное использование существующего флага вызывает понятную ошибку. Обновляйте значения через `element:Set(...)` или `KrakenLib:SetFlag(...)`, а не прямой записью в `Flags`.

Аргументы `opts` / `o` — таблицы опций. Поля с `_` являются внутренними и не входят в стабильный API. Все обычные callback вызываются защищённо; их ошибки выводятся через `warn`.

## Полный публичный API

### KrakenLib

| Вызов | Результат / назначение |
| :--- | :--- |
| `:Window(opts)` | Window; `Title`, `SubTitle`, `Name`, `Size`, `Position`, `MinSize`, `MaxSize` |
| `:GetWindow(name)` | Window или nil |
| `:GetWindows()` | Копия массива окон |
| `:FocusWindow(name)` | Показывает и поднимает окно; boolean |
| `:CloseAll()` | Скрывает окна и их кнопки восстановления |
| `:SetVisible(boolean)` | Видимость всего ScreenGui, включая оверлеи |
| `:IsVisible()` | boolean; false до создания ScreenGui |
| `:GetElement(flag)` | Объект компонента или nil |
| `:GetFlag(flag)` | Значение или nil |
| `:SetFlag(flag, value, fireCallback?)` | `ok, error`; использует реальный setter компонента |
| `:OnFlagChanged(flag, callback)` | Возвращает функцию отписки; события изменений от интерактивных callback |
| `:Search(query)` | Отсортированный массив флагов; поиск по флагу и имени |
| `:ScrollToFlag(flag)` | Показывает окно, раскрывает секцию, активирует вкладку; boolean |
| `:CommandPalette(opts?)` | Поисковое окно; `Title`; до 30 результатов, поиск при подтверждении ввода |
| `:Notification(opts)` | Временное уведомление; `Title`, `Text`, `Icon`, `Duration` |
| `:Announcement(opts)` | Handle с `:Dismiss()`; `Title`, `Text`, `Icon`, `Duration`, `Dismissible`, `OnDismiss` |
| `:Modal(opts)` | Handle с `:Close()`; `Title`, `Text`, `AcceptText`, `CancelText`, `OnAccept`, `OnCancel` |
| `:ContextMenu()` | Menu с `:Attach(guiObject, items)` и `:Close()` |
| `:Loader(opts)` | Loader с `:Run(onDone)` |
| `:KeySystem(opts)` | KeySystem с `:Prompt(onSuccess)`, `:LoadSavedKey()`, `:SaveKey(key)` |
| `:Watermark(opts)` | Handle с `:Update(text)`, `:Destroy()` |
| `:KeybindList(opts)` | Handle с `:Refresh(entries)`, `:Destroy()`; `Title` |
| `:Settings(opts?)` | Окно настроек; `OnExport`, `OnImport` |
| `:KeybindEditor()` | Окно редактора; созданные действия публикуют `hotkey:<name>` |
| `:SetReducedMotion(boolean)` / `:GetReducedMotion()` | Мгновенные переходы вместо tween-анимаций |
| `:GetVersion()` | Строка версии |
| `:GetCapabilities()` | `{FileSystem, Clipboard, Sound, Client}` |
| `:Unload()` | Отключает отслеживаемые соединения, удаляет GUI, очищает состояние |

`KrakenLib.Version` — версия; `KrakenLib.Flags` — текущие значения. `Unload()` завершает жизненный цикл экземпляра. После него нужен **новый экземпляр библиотеки**; повторный `require` того же ModuleScript возвращает кэш, поэтому для повторной инициализации используйте новую копию ModuleScript. Для обычного закрытия используйте `Hide()`.

### Window

| Вызов | Назначение |
| :--- | :--- |
| `:Tab({Name, Icon})` | Создать вкладку |
| `:SetTitle(text)` / `:SetSubtitle(text)` | Заголовок / подпись |
| `:Show()` / `:Hide()` / `:Toggle()` | Управление видимостью |
| `:IsVisible()` | boolean |
| `:SetPosition(UDim2)` / `:GetPosition()` | Позиция |
| `:SetSize(UDim2)` / `:GetSize()` | Размер; при программной установке выбирайте допустимые размеры самостоятельно |
| `:Center()` | Центрировать текущий размер |
| `:GetTabs()` | Копия массива вкладок |
| `:GetTab(name)` | Первая вкладка с таким именем или nil |
| `:SelectTab(name)` | Активировать вкладку; boolean |
| `:Destroy()` | Удалить окно и его зарегистрированные элементы; повторный вызов безопасен |

Размер по умолчанию: 720 × 500. `MinSize` / `MaxSize` ограничивают изменение размера мышью. Для небольших экранов задавайте подходящий `Size`; автоматическая мобильная перекомпоновка не реализована.

### Tab, Section, контейнеры

| Объект | API |
| :--- | :--- |
| Tab | `:Activate()`, `:GetName()`, `:SetName(text)`, `:IsActive()`, `:ScrollTo(y)` |
| Tab | `:Section({Name, Icon, Collapsed, OnCollapse})`, `:Accordion()` |
| Accordion | `:Panel(sectionOptions)` → Section |
| Section | `:SetTitle(text)`, `:SetCollapsed(boolean, animated?)`, `:IsCollapsed()` |
| Section / Row cell / Group | `:GetBody()` → Frame; `:SetVisible(boolean)` управляет телом контейнера |
| Section / Row cell / Group | Все 18 конструкторов компонентов ниже |
| Section / Row cell / Group | `:Row(count)` → от 1 до 6 отдельных контейнеров |
| Section / Row cell / Group | `:Group({Name, Default, Flag, Callback})` → контейнер с `MasterToggle` |

```lua
local left, right = section:Row(2)
left:StatCard({ Name = "Profiles", Default = "12", Caption = "Available locally" })
right:StatCard({ Name = "Status", Default = "Ready", Caption = "All systems online" })
local group = section:Group({ Name = "Advanced", Default = false })
group:Stepper({ Name = "Retries", Min = 0, Max = 5, Default = 2 })
group.MasterToggle:Set(true)
```

### Компоненты

Все объекты компонентов имеют `Name`, `Flag`, `:SetVisible(boolean)`, `:IsVisible()`, `:Destroy()`. Методы `Get` / `Set` доступны **только там, где указаны**, а не у любого декоративного компонента.

| Конструктор | Опции помимо `Name`, `Flag` | Методы результата |
| :--- | :--- | :--- |
| `:Toggle(o)` | `Default`, `Callback`, `Hint` | `Get()`, `Set(boolean, fireCallback?)` |
| `:Slider(o)` | `Min`, `Max`, `Default`, `Decimals`, `Suffix`, `Callback`, `Hint` | `Get()`, `Set(number, fireCallback?)` |
| `:Dropdown(o)` | `Options`, `Default`, `Multi`, `Callback` | `Get()`, `Set(value, fireCallback?)`, `SetOptions(array)`, `Refresh(array?)` |
| `:Keybind(o)` | `Default`, `Mode`, `Callback` | `Get()` → key, mode, active; `Set(key, mode?)` |
| `:Colorpicker(o)` | `Default: Color3`, `Callback` | `Get()`, `Set(Color3, fireCallback?)` |
| `:Textbox(o)` | `Default`, `Placeholder`, `Numeric`, `Callback` | `Get()`, `Set(text)` |
| `:Button(o)` | `Callback` | `Get()` возвращает nil; нет Set |
| `:Label(o)` | `Text` | `Get()`, `Set(text)` |
| `:Divider()` | Нет | Только общие методы |
| `:Paragraph(o)` | `Title`, `Text` | `Get()`, `Set(text)` для текста тела |
| `:Radio(o)` | `Options`, `Default`, `Callback` | `Get()`, `Set(name, fireCallback?)` |
| `:Stepper(o)` | `Min`, `Max`, `Default`, `Step`, `Decimals`, `Suffix`, `Callback` | `Get()`, `Set(number, fireCallback?)` |
| `:ProgressBar(o)` | `Default` в диапазоне 0…1 | `Get()`, `Set(fraction)` |
| `:Table(o)` | `Columns`, `Rows`, `Sortable`, `Height` | `Get()`, `SetRows(rows)` |
| `:Image(o)` | `Image`, `Height`, `Caption` | `Get()`, `Set(assetId)` |
| **`:Badge(o)`** | `Text`, `Color` | `Get()`, `Set(text)` |
| **`:StatCard(o)`** | `Default`, `Caption` | `Get()`, `Set(text)`, `SetCaption(text)` |
| **`:Alert(o)`** | `Title`, `Text`, `Color` | `Get()`, `Set(text)` |

`Dropdown.Multi = true`: значение — массив строк. Одиночный Dropdown — строка либо nil. Неизвестные значения отбрасываются. `SetOptions()` заменяет список вариантов, `Refresh()` перерисовывает его.

`fireCallback = false` подавляет callback у Toggle, Slider, Dropdown, Radio, Stepper и Colorpicker. `Textbox:Set()` не вызывает callback. `Keybind:Set(key, mode)` использует второй параметр как режим, а не callback-флаг. `Get()` у StatCard возвращает отображаемую **строку**.

### Темы и доступность

**Obsidian** — новая тема по умолчанию. Также: **Pearl**, Void Purple, Cyber Blue, Sunset, Mono Dark, Mono Light, Nord, Dracula.

| `KrakenLib.Theming` | Контракт |
| :--- | :--- |
| `:List()` / `:Use(name)` / `:GetPreset()` | Список / применить / текущее имя |
| `:Get()` | Таблица `Accent, Bg, Panel, Text, SubText`; считайте её read-only |
| `:Register(name, colors)` | Все пять полей обязательны, тип Color3 |
| `:SetAccent(Color3)` | Изменить акцент |
| `:SetRadius(number)` / `:GetRadius()` | 0…20 |
| `:SetBorderThickness(number)` / `:GetBorderThickness()` | 0…3 |
| `:SetGlow(boolean)` / `:GetGlow()` | Свечение окон |
| `:SetAnimSpeed(number)` / `:GetAnimSpeed()` | 0…4; множитель для анимаций, использующих настройку |
| `:SetDensity(name)` / `:GetDensity()` | Compact, Normal, Comfortable; возвращает имя и таблицу отступов |
| `:OnChanged(callback)` | Функция отписки |
| `:Export()` / `:Import(json)` | JSON / boolean |

```lua
KrakenLib.Theming:Use("Obsidian")
KrakenLib.Theming:SetAccent(Color3.fromRGB(155, 130, 255))
KrakenLib:SetReducedMotion(true)
KrakenLib.Theming:Register("Custom", {
    Accent = Color3.fromRGB(70, 150, 255),
    Bg = Color3.fromRGB(17, 18, 23),
    Panel = Color3.fromRGB(25, 27, 34),
    Text = Color3.fromRGB(241, 242, 247),
    SubText = Color3.fromRGB(164, 169, 185),
})
```

Цвета обновляются у существующих объектов по токенам. Сложные состояния и пользовательские цвета необходимо проверить в своей теме. Радиусы и толщина границ применяются там, где конструктор использует эти настройки; это не глобальный CSS. Экспорт темы содержит имя пресета и настройки, **не определение пользовательской палитры**: зарегистрируйте её до импорта.

### Fonts, Icons, Sounds, Animations

| Модуль | Все публичные методы |
| :--- | :--- |
| `Fonts` | `List()`, `Register(name, fontFamilyAssetId, weight?, style?) → boolean`, `Resolve(name) → font, isFontFace`, `Apply(textInstance, name?, size?)`, `SetDefault(name?, size?)`, `GetDefault() → name, size` |
| `Icons` | `Get(name) → assetId?`, `Register(name, imageId)`, `List()` |
| `Sounds` | `SetEnabled(boolean)`, `GetEnabled()`, `SetVolume(0…1)`, `GetVolume()`, `Register(name, soundId)`, `List()`, `Play(name) → boolean` |
| `Animations` | `Register(name, fn)`, `List()`, `Play(instance, presetName, opts?)` |
| `Tooltip` | `Attach(guiObject, text)` |

`Sounds.Available` сообщает результат последней попытки API-воспроизведения, но не гарантирует загрузку или слышимость asset. Ошибка выводится один раз. Звуки выключены по умолчанию.

Встроенные звуки: `click`, `hover`, `toggleOn`, `toggleOff`, `notify`. Анимации: `FadeIn`, `FadeOut`, `Pulse`, `Shake`, `SlideInLeft`, `SlideInRight`, `SlideInTop`. Точные доступные ключи иконок и шрифтов возвращает `List()`.

`Fonts:Register` требует **Roblox Font Family Asset**, не изображение. Псевдонимы Verdana, Tahoma XP и Roboto в старом API являются приближениями встроенными шрифтами, а не загрузкой оригинальных гарнитур. Многие встроенные компоненты задают шрифт явно.

### Events и Hotkeys

```lua
local off = KrakenLib.Events:On("saved", function(name) print(name) end)
KrakenLib.Events:Once("ready", function() print("Only once") end)
KrakenLib.Events:Fire("saved", "default")
off()

local callback = function(value) print(value) end
KrakenLib.Events:On("event", callback)
KrakenLib.Events:Off("event", callback)
KrakenLib.Hotkeys:Bind("menu", Enum.KeyCode.RightShift, "Toggle", callback)
local bindings = KrakenLib.Hotkeys:List()
KrakenLib.Hotkeys:Unbind("menu")
```

Режимы глобальных Hotkeys: `Toggle` переключает состояние, `Hold` включает при нажатии и выключает при отпускании, `Always` сразу вызывает callback(true). `List()` возвращает записи `{Name, Key, Mode, Active}`. Элемент Keybind и глобальный Hotkeys — разные механизмы.

### Config

| Вызов | Результат |
| :--- | :--- |
| `Config:Export()` | JSON `{Version = 2, Flags = ...}`; Color3 и enum сериализуются с типом |
| `Config:Import(json)` | `ok, errors`; восстанавливает зарегистрированные элементы, неизвестные флаги пропускает |
| `Config:Save(name)` | `ok, error`; требует файловый API среды |
| `Config:Load(name)` | `ok, errors`; требует файловый API среды |
| `Config:List()` | Отсортированный массив имён профилей |
| `Config:Delete(name)` | `ok, error` |

Имя профиля: 1…64 ASCII-буквы, цифры, `_`, `-`. Путь по умолчанию: `KrakenUI/configs/<name>.json`. В Studio файловые операции недоступны; передайте JSON в собственный серверный слой сохранения. В библиотеке нет облачной синхронизации.

Импорт применяет значения последовательно и сообщает об ошибках; это **не атомарная транзакция**. Создайте элементы до импорта. Компоненты без Set, например Table, не являются сохраняемыми настройками. Для них передавайте данные через соответствующий API.

### Оверлеи и служебные интерфейсы

```lua
KrakenLib:Notification({ Title = "Saved", Text = "Profile updated", Icon = "success", Duration = 3 })
local banner = KrakenLib:Announcement({ Title = "Update", Text = "New workspace available", Dismissible = true })
banner:Dismiss()

local dialog = KrakenLib:Modal({
    Title = "Reset appearance?", Text = "Your custom colors will be replaced.",
    AcceptText = "Reset", CancelText = "Keep",
    OnAccept = function() KrakenLib.Theming:Use("Obsidian") end,
})
-- dialog:Close()

local loader = KrakenLib:Loader({ Title = "Workspace", Subtitle = "Initializing", Steps = {
    { Name = "Prepare", Weight = 1, Fn = function() task.wait(0.1) end },
    { Name = "Ready", Weight = 1 },
} })
loader:Run(function() print("Ready") end)

local watermark = KrakenLib:Watermark({ Text = "Kraken", UpdateInterval = 1, UpdateFn = function() return os.date("%H:%M:%S") end })
watermark:Update("Custom status")
local binds = KrakenLib:KeybindList({ Title = "Shortcuts" })
binds:Refresh({ { Name = "Menu", Key = "RightShift" } })

local menu = KrakenLib:ContextMenu()
menu:Attach(section:GetBody(), { { Name = "Reset theme", Icon = "refresh", Callback = function()
    KrakenLib.Theming:Use("Obsidian")
end } })
KrakenLib.Tooltip:Attach(section:GetBody(), "Workspace controls")
```

KeySystem предоставляет экран ввода, локальную проверку формата и callback `Validate(key) → boolean, message?`. Параметры включают `Title`, `BuyUrl`, `DiscordUrl`, `RateLimit = {Attempts, Window}`, `Validate`. Он **не является серверной авторизацией**: секреты и доверенные проверки должны оставаться на сервере. Локальный rate limit не защищает backend. URL-кнопки зависят от возможностей среды.

## Что исправлено

- Удалено недопустимое `GroupTransparency` у ScrollingFrame.
- Убрана анимация, которая делала фон секции прозрачным навсегда и конфликтовала с UIListLayout.
- Добавлен пересчёт высоты секции при изменении содержимого.
- Перетаскивание учитывает масштабную часть позиции и реальные границы контейнера, без фиктивной камеры 1920 × 1080.
- `table.clone` имеет локальный fallback, глобальная стандартная библиотека не изменяется.
- Добавлен `Dropdown:Set`, необходимый для восстановления конфигураций.
- Цвета и EnumItem корректно преобразуются для JSON-конфигураций.
- Улучшены сообщения об ошибках шрифтов и диагностика звука.
- Созданные редактором бинды подключаются к Hotkeys, удаление отвязывает действие.
- Поиск учитывает названия; переход открывает окно и секцию.
- При выгрузке дополнительно сбрасываются уведомления, drag-состояние и реестр биндов.
- Добавлены новые API окон, вкладок, элементов, тем, событий, конфигов и три визуальных компонента.

### Уточнения к приложенному аудиту

В исходнике GitHub очистка `_elements` и поле `Section._body` **уже существовали**. Добавлен публичный `GetBody()`, редактор больше не зависит от приватного поля. `JumpRequest` в библиотеке не найден; замена его произвольным Touch-событием не выполнялась, поскольку касание экрана не равно команде прыжка.

## Проверка и ограничения

Синтаксис проверяется компилятором Luau. `SmokeTest.client.lua` предназначен для реального клиентского запуска в Studio: создание компонентов, переключение вкладок, конфиги, темы и уничтожение окна. Наличие тестового файла не означает, что Roblox Studio запускался в среде разработки этого обновления.

Перед выпуском проверьте мышь и touch, многократное открытие/закрытие, темы, размеры экрана и разрешения на используемые assets. Не все исходные компоненты поддерживают полноценную клавиатурную навигацию и мобильную компоновку. Долгоживущие глобальные соединения окончательно отключаются через `Unload()`.

---

<div align="center">

**KrakenUI** · A quieter interface. A stronger foundation.

[Исходный репозиторий](https://github.com/GGgodd211/KrakenLib) · [Lua](KrakenUI.lua) · [Luau](KrakenUI.luau)

</div>
