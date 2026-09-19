# KrakenUI

Самостоятельная, переиспользуемая GUI-библиотека для executor-скриптов (Roblox Luau).
Один файл (`KrakenUI.luau`), без `require`, без внешних модулей, без asset-зависимостей,
кроме обычных `rbxassetid` иконок. Внутри — **только UI-фреймворк**: окна, вкладки,
секции, элементы управления, тема, шрифты, иконки, лоадер, нотификации, key-screen,
окно настроек и редактор биндов. Никакой игровой логики (ESP/aimbot/hooks и т.п.) в файле нет.

> **Про "SVG-иконки":** Roblox не рендерит SVG в UI. `Library.Icons` работает через обычные
> растровые `rbxassetid`-изображения. API (`Get/Register/List`) сделан таким же, каким его
> обычно описывают в ТЗ, но это не SVG-движок — просто удобная обёртка.

---

## Установка

```lua
local Library = loadstring(readfile("KrakenUI.luau"))()
-- или, если у тебя loadstring по http/файлу:
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/GGgodd211/KrakenLib/refs/heads/main/KrakenUI.luau"))()
```

Библиотека самодостаточна: подключённая в пустой скрипт, она не падает и готова к использованию сразу.

---

## Быстрый старт

```lua
local Library = loadstring(readfile("KrakenUI.luau"))()

local win = Library:Window({ Title = "My Script", SubTitle = "v1.0" })
local tab = win:Tab({ Name = "Главная", Icon = "settings" })
local sec = tab:Section({ Name = "Пример", Icon = "star" })

sec:Toggle({ Name = "Включить фичу", Flag = "MyToggle", Default = false, Callback = function(v)
    print("Toggle:", v)
end })

sec:Slider({ Name = "Скорость", Min = 0, Max = 10, Decimals = 1, Suffix = "x", Flag = "Speed", Default = 1 })

Library:Notification({ Title = "Готово", Text = "Библиотека загружена", Icon = "success" })
```

---

## Оглавление

0. [Новое (v2): 13 новых пунктов API](#новое-v2-13-новых-пунктов-api)
1. [Library:Window](#librarywindow)
2. [Window:Tab](#windowtab)
3. [Tab:Section](#tabsection)
4. [Элементы секции](#элементы-секции)
   - [Toggle](#sectiontoggle)
   - [Slider](#sectionslider)
   - [Dropdown](#sectiondropdown)
   - [Keybind](#sectionkeybind)
   - [Colorpicker](#sectioncolorpicker)
   - [Textbox](#sectiontextbox)
   - [Button](#sectionbutton)
   - [Label](#sectionlabel)
   - [Divider / Paragraph](#sectiondivider--sectionparagraph)
5. [Library:Notification](#librarynotification)
6. [Library:Loader](#libraryloader)
7. [Library:KeySystem](#librarykeysystem)
8. [Library:Watermark](#librarywatermark)
9. [Library:KeybindList](#librarykeybindlist)
10. [Library.Tooltip](#librarytooltip)
11. [Library.Theming](#librarytheming)
12. [Library.Fonts](#libraryfonts)
13. [Library.Icons](#libraryicons)
14. [Library.Config](#libraryconfig)
15. [Library:Settings](#librarysettings)
16. [Library:KeybindEditor](#librarykeybindeditor)
17. [Library:Search](#librarysearch)
18. [Library.Flags / Library._elements](#libraryflags--library_elements)
19. [Library:Unload](#libraryunload)

---

## Новое (v2): 13 новых пунктов API

Все новые методы вызываются через тот же объект, что и остальная библиотека — как ты его
назовёшь, не важно: `local KrakenLib = loadstring(readfile("KrakenUI.luau"))()`, дальше
везде `KrakenLib:Modal(...)`, `KrakenLib.Events`, `KrakenLib:Window(...)` и т.д. — единый
стиль: **действия** — через двоеточие (`:Window`, `:Modal`, `:ContextMenu`), **постоянные
подмодули с состоянием** — через точку (`.Theming`, `.Icons`, `.Events`, `.Hotkeys`).

### 1. Library.Events — глобальная шина событий

```lua
local unsubscribe = KrakenLib.Events:On("PlayerDied", function(reason)
    print("Игрок умер:", reason)
end)
KrakenLib.Events:Fire("PlayerDied", "fall damage")
unsubscribe() -- KrakenLib.Events:Off("PlayerDied", fn) — то же самое явно
```

### 2. Library.Hotkeys — глобальный менеджер хоткеев

Не привязан к конкретному GUI-элементу, работает даже если меню закрыто/свёрнуто.

```lua
KrakenLib.Hotkeys:Bind("ToggleMenu", Enum.KeyCode.RightShift, "Toggle", function(active)
    print("Меню:", active)
end)
KrakenLib.Hotkeys:List()     -- -> {{Name=,Key=,Mode=,Active=},...}
KrakenLib.Hotkeys:Unbind("ToggleMenu")
```

### 3. Library:Modal(opts) — диалог подтверждения/алерта

```lua
KrakenLib:Modal({
    Title = "Сбросить настройки?",
    Text = "Все значения вернутся к значениям по умолчанию.",
    AcceptText = "Сбросить", CancelText = "Отмена",
    OnAccept = function() print("сброшено") end,
    OnCancel = function() print("отменено") end,
})
```

### 4. Library:ContextMenu() — меню по ПКМ

```lua
local menu = KrakenLib:ContextMenu()
menu:Attach(someGuiObject, {
    { Name = "Копировать", Icon = "copy", Callback = function() end },
    { Name = "Удалить", Icon = "trash", Callback = function() end },
})
```

### 5. Section:Radio(opts) — инлайн radio-группа

```lua
sec:Radio({
    Name = "Режим прицеливания", Options = { "Голова", "Грудь", "Ближайшая кость" },
    Default = "Голова", Flag = "AimMode", Callback = function(value) end,
})
```

### 6. Section:Stepper(opts) — числовой степпер с кнопками −/+

```lua
sec:Stepper({
    Name = "FOV", Min = 60, Max = 120, Step = 5, Default = 90, Flag = "FOV",
    Callback = function(value) end,
})
```

### 7. Section:ProgressBar(opts) — встраиваемый прогресс-бар

В отличие от `Library:Loader`, не создаёт оверлей — обычный элемент внутри секции.

```lua
local bar = sec:ProgressBar({ Name = "Загрузка скина", Default = 0 })
bar:Set(0.65) -- 0..1, анимированно
```

### 8. Section:Table(opts) — таблица данных с сортировкой

```lua
local tbl = sec:Table({
    Name = "Игроки", Columns = { "Ник", "Дистанция" }, Sortable = true,
    Rows = { { ["Ник"] = "Alex", ["Дистанция"] = 42 }, { ["Ник"] = "Bob", ["Дистанция"] = 15 } },
})
tbl:SetRows({ { ["Ник"] = "Carl", ["Дистанция"] = 8 } }) -- обновить данные
```

### 9. Section:Row(count) — горизонтальная раскладка колонок

```lua
local left, right = sec:Row(2)
left:Toggle({ Name = "Левый тоггл" })
right:Toggle({ Name = "Правый тоггл" })
```

Каждая «ячейка» — это такой же диспетчер элементов, как и сама секция: доступны
`Toggle/Slider/Dropdown/.../Row/Group` рекурсивно.

### 10. Section:Group(opts) — зависимая группа (условная видимость)

Мастер-тоггл показывает/прячет вложенные элементы — удобно для блоков вида
«включить ESP» → появляются настройки ESP.

```lua
local espGroup = sec:Group({ Name = "Включить ESP", Default = false, Flag = "ESPEnabled" })
espGroup:Colorpicker({ Name = "Цвет обводки", Default = Color3.new(1, 0, 0) })
espGroup:Slider({ Name = "Толщина", Min = 1, Max = 5, Default = 1 })
```

### 11. Tab:Accordion() — взаимоисключающие секции

Группа секций, где раскрыта только одна: открытие панели автоматически сворачивает остальные.

```lua
local acc = tab:Accordion()
local p1 = acc:Panel({ Name = "Профиль A" })
local p2 = acc:Panel({ Name = "Профиль B" })
p1:Button({ Name = "Применить A" })
p2:Button({ Name = "Применить B" })
```

### 12. Library:GetWindow(name) / Library:CloseAll()

```lua
KrakenLib:Window({ Name = "main", Title = "MyScript" })
local win = KrakenLib:GetWindow("main")
KrakenLib:CloseAll() -- скрыть все открытые окна библиотеки
```

### 13. Library:ScrollToFlag(flag) — программная навигация к элементу

Переключает нужную вкладку, плавно скроллит к элементу и на секунду подсвечивает его рамкой
акцентного цвета. Отлично сочетается с `Library:Search`.

```lua
local results = KrakenLib:Search("offset")
if results[1] then
    KrakenLib:ScrollToFlag(results[1])
end
```

---

## Library:Window

Создаёт главное окно: drag, resize (8 направлений), сворачивание в "пузырь", сброс позиции,
плавный fade-in, неоновый glow-бордер по акцентному цвету темы.

```lua
local win = Library:Window({
    Title    = "My Script",       -- заголовок
    SubTitle = "v1.0",            -- подзаголовок (необязательно)
    Size     = UDim2.new(0, 620, 0, 420), -- необязательно
    MinSize  = Vector2.new(420, 280),     -- необязательно, мин. размер при resize
    MaxSize  = Vector2.new(1100, 800),    -- необязательно, макс. размер при resize
})
```

Возвращает объект `Window` с методом `:Tab(opts)`.

---

## Window:Tab

Вкладка слева в окне. Умеет: fade+slide переход, иконку, анимированную активную полосу,
stagger fade-in содержимого при открытии.

```lua
local tab = win:Tab({
    Name = "Главная",     -- название вкладки
    Icon = "settings",    -- необязательно, ключ из Library.Icons
})
```

Возвращает объект `Tab` с методом `:Section(opts)`.

---

## Tab:Section

Карточка-секция со сворачиваемым заголовком (клик по заголовку сворачивает/разворачивает
с анимацией высоты и поворотом стрелки).

```lua
local sec = tab:Section({
    Name      = "Комбат",     -- название секции
    Icon      = "target",     -- необязательно
    Collapsed = false,        -- необязательно, стартовое состояние
    OnCollapse = function(isCollapsed) end, -- необязательно, колбэк на переключение
})
```

Возвращает объект `Section` со всеми методами создания элементов ниже.

Каждый метод создания элемента принимает `Flag` (необязательно) — под этим ключом значение
элемента появится в `Library.Flags[flag]` и элемент станет доступен в `Library._elements[flag]`.

---

## Элементы секции

### Section:Toggle

```lua
local el = sec:Toggle({
    Name     = "Включить фичу",
    Default  = false,
    Flag     = "MyToggle",             -- необязательно
    Callback = function(value) end,    -- вызывается при каждом изменении
})

el:Get()               -- -> boolean
el:Set(true)            -- программно включить (вызовет Callback)
el:Set(true, false)     -- программно включить без вызова Callback
```

### Section:Slider

Поддерживает десятичные значения, ручной ввод числа (TextBox рядом с ползунком),
клавиатуру (стрелки влево/вправо ± шаг, Shift ×10), суффикс, hint-подпись снизу.

```lua
local el = sec:Slider({
    Name      = "Offset Y",
    Min       = -10,
    Max       = 10,
    Default   = 0,
    Decimals  = 1,          -- количество знаков после запятой
    Increment = 0.1,        -- шаг (необязательно, по умолчанию считается из Decimals)
    Suffix    = "м",        -- необязательно, отображаемая единица
    Hint      = "shifts server position vertically (-10..+10)", -- необязательно, серый текст снизу
    Flag      = "OffsetY",
    Callback  = function(value) end,
})

el:Get()          -- -> number
el:Set(4.2)        -- clamp по Min/Max, округление по Decimals, вызовет Callback
el:Set(4.2, false) -- без вызова Callback
```

Ручной ввод в поле: Enter подтверждает, Escape отменяет и возвращает прежнее значение,
потеря фокуса (blur) подтверждает введённое значение. Локаль: запятая автоматически
преобразуется в точку.

### Section:Dropdown

Одиночный или множественный выбор, поиск по списку, программное обновление опций.

```lua
local el = sec:Dropdown({
    Name     = "Оружие",
    Options  = { "Нож", "Пистолет", "Винтовка" },
    Default  = "Нож",            -- для Multi = true: массив значений, например {"Нож","Пистолет"}
    Multi    = false,            -- true = множественный выбор (чекбоксы)
    Flag     = "Weapon",
    Callback = function(valueOrList) end,
})

el:Get()                 -- single: string|nil ; multi: массив выбранных строк
el:SetOptions({ "A", "B" })  -- полностью заменить список опций
el:Refresh({ "A", "B" })     -- то же самое (перерисовать список, опционально с новыми опциями)
```

### Section:Keybind

Три режима: `Toggle` / `Hold` / `Always` (переключаются кликом по кнопке режима).
Приём любой клавиши клавиатуры или ПКМ мыши (клик по кнопке клавиши → нажми нужную клавишу).

```lua
local el = sec:Keybind({
    Name     = "Открыть меню",
    Default  = Enum.KeyCode.RightShift, -- необязательно
    Mode     = "Toggle",                -- "Toggle" | "Hold" | "Always"
    Callback = function(isActive) end,  -- boolean
})

local keyCode, mode, active = el:Get()
el:Set(Enum.KeyCode.F, "Hold")
```

### Section:Colorpicker

HSV-панель + HEX-ввод, открывается кликом по квадрату цвета.

```lua
local el = sec:Colorpicker({
    Name     = "Цвет ESP",
    Default  = Color3.fromRGB(255, 0, 0),
    Flag     = "EspColor",
    Callback = function(color3) end,
})

el:Get()               -- -> Color3
el:Set(Color3.new(0,1,0))
```

### Section:Textbox

```lua
local el = sec:Textbox({
    Name        = "Ник для поиска",
    Placeholder = "Введите ник...",
    Default     = "",
    Numeric     = false,           -- true = фильтрует ввод только под числа/минус/точку
    Flag        = "SearchName",
    Callback    = function(text, enterPressed) end,
})

el:Get()          -- -> string
el:Set("test")
```

### Section:Button

```lua
sec:Button({
    Name     = "Сбросить настройки",
    Callback = function() end,
})
```

### Section:Label

```lua
local el = sec:Label({ Text = "Просто текст" })
el:Set("Новый текст")
el:Get()
```

### Section:Divider / Section:Paragraph

```lua
sec:Divider() -- тонкая горизонтальная линия-разделитель

local p = sec:Paragraph({
    Title = "Инструкция",
    Text  = "Длинный многострочный текст с переносом слов...",
})
p:Set("Новый текст параграфа")
p:Get()
```

---

## Library:Notification

Стек уведомлений в правом нижнем углу, fade-in/out, автозакрытие.

```lua
Library:Notification({
    Title    = "Готово",
    Text     = "Операция выполнена успешно",
    Icon     = "success",  -- "info" | "success" | "warning" | "error"
    Duration = 4,          -- секунды до авто-скрытия
})
```

---

## Library:Loader

Детальный многоэтапный экран загрузки: общая полоса + список этапов с иконками-статусами,
мини-консоль лога, кнопка «Пропустить» (появляется через 3 сек), плавный fade-out по завершении.

```lua
local loader = Library:Loader({
    Title    = "Kraken.market",
    Subtitle = "Инициализация...",
    Steps = {
        { Name = "Проверка ключа...",       Weight = 8,  Fn = function() task.wait(0.1) end },
        { Name = "Загрузка ядра...",        Weight = 12, Fn = function() task.wait(0.2) end },
        { Name = "Инициализация...",        Weight = 12 }, -- без Fn — просто пауза 0.05с
        -- ... остальные этапы
    },
})

loader:Run(function()
    print("Загрузка завершена, показываем меню")
end)
```

`Weight` — вес этапа в общей полосе (проценты считаются автоматически по сумме весов).
`Fn` — необязательная функция этапа; ошибки внутри `Fn` перехватываются и логируются через `warn`,
не прерывая загрузку. Каждый этап держится минимум 150 мс для плавности, даже если выполнился мгновенно.

---

## Library:KeySystem

Универсальный (не привязанный к конкретной защите) экран ввода лицензионного ключа:
живая валидация формата `XXXX-XXXX-XXXX` с debounce 400 мс, rate-limit, автосохранение
валидного ключа на диск (если executor поддерживает `writefile`/`readfile`), кнопки
«Купить ключ» / Discord (копируют ссылку в буфер обмена).

```lua
local ks = Library:KeySystem({
    Title      = "Введите ключ доступа",
    Subtitle   = "Ключ можно получить у разработчика.",
    SaveFolder = "MyScript",             -- папка для key.txt, по умолчанию "KrakenUI"
    BuyUrl     = "https://example.com/buy",
    DiscordUrl = "https://discord.gg/example",
    RateLimit  = { Attempts = 5, Window = 60 }, -- 5 попыток / 60 секунд
    Validate   = function(key)
        -- своя проверка (локальная или через HTTP-запрос к своему API)
        if key == "AAAA-BBBB-CCCC" then
            return true
        end
        return false, "Неверный ключ"
    end,
})

ks:Prompt(function(validKey)
    print("Доступ разрешён:", validKey)
    -- здесь: показываем Library:Window(...) и т.д.
end)
```

---

## Library:Watermark

Компактная draggable-плашка со статус-текстом. Содержимое полностью задаёт вызывающий код.

```lua
local wm = Library:Watermark({
    Text           = "MyScript | загрузка...",
    UpdateInterval = 1, -- секунд между обновлениями через UpdateFn
    UpdateFn       = function()
        return ("MyScript | %d FPS | Ping %dms"):format(60, 20)
    end,
})

wm:Update("Текст вручную")
wm:Destroy()
```

---

## Library:KeybindList

Draggable-плашка со списком «активных» биндов. Данные (какие бинды показывать) передаёт
вызывающий код — библиотека не хранит игровые фичи.

```lua
local kl = Library:KeybindList({ Title = "Активные бинды" })

kl:Refresh({
    { Name = "Меню",    Key = "RightShift" },
    { Name = "Спринт",  Key = "LeftShift" },
})

kl:Destroy()
```

---

## Library.Tooltip

Подсказка для любого `GuiObject`, следует за курсором при наведении.

```lua
-- element._inst или любой GuiObject, который тебе доступен
Library.Tooltip:Attach(someGuiObject, "Это подсказка")
```

---

## Library.Theming

Управление темой: 7 готовых пресетов, акцентный цвет, радиус скруглений, толщина бордера,
скорость анимаций, плотность интерфейса, свечение (glow). Подписка на изменения через `OnChanged`.

```lua
Library.Theming:List()                    -- -> {"Cyber Blue","Dracula","Mono Dark","Mono Light","Nord","Sunset","Void Purple"}
Library.Theming:Use("Cyber Blue")         -- применить пресет
Library.Theming:SetAccent(Color3.fromRGB(255, 80, 80))
Library.Theming:Get()                     -- -> { Accent, Bg, Panel, Text, SubText }

Library.Theming:SetRadius(14)             -- 0..20
Library.Theming:GetRadius()

Library.Theming:SetBorderThickness(2)     -- 0..3
Library.Theming:GetBorderThickness()

Library.Theming:SetGlow(true)             -- вкл/выкл неоновое свечение окна
Library.Theming:GetGlow()

Library.Theming:SetAnimSpeed(0.6)         -- множитель длительности твинов (меньше = быстрее)
Library.Theming:GetAnimSpeed()

Library.Theming:SetDensity("Compact")     -- "Compact" | "Normal" | "Comfortable"
Library.Theming:GetDensity()              -- -> name, {row=, section=, pad=}

local unsubscribe = Library.Theming:OnChanged(function(colors)
    print("Тема изменилась:", colors.Accent)
end)
unsubscribe() -- отписаться
```

---

## Library.Fonts

Встроенные пресеты шрифтов + регистрация кастомных через Roblox Font Family asset.

```lua
Library.Fonts:List()  -- -> {"Bangers","Code","Fondamento",...,"Gotham","Gotham Bold",...}

-- Кастомный шрифт: assetId — ссылка на Font Family JSON, загруженный в Roblox
-- (см. Roblox Studio -> Font Manager -> Upload)
local ok = Library.Fonts:Register("MyFont", "rbxassetid://1234567890", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

Library.Fonts:SetDefault("MyFont", 14)   -- имя и/или размер по умолчанию для всей библиотеки
Library.Fonts:GetDefault()               -- -> name, size

-- Применить шрифт к произвольному TextLabel/TextButton/TextBox вручную:
Library.Fonts:Apply(someTextLabel, "Gotham Bold", 13)
```

---

## Library.Icons

Обёртка над растровыми `rbxassetid`-иконками (см. примечание про SVG в начале README).

```lua
Library.Icons:Get("settings")                     -- -> "rbxassetid://..."
Library.Icons:Register("myicon", "rbxassetid://0000000000")
Library.Icons:List()                               -- -> отсортированный массив имён

-- Использование в Tab/Section:
tab:Section({ Name = "Пример", Icon = "myicon" })
```

Встроенные ключи (минимум): `settings, cog, search, close, minimize, restore, chevronUp,
chevronDown, chevronLeft, chevronRight, key, lock, unlock, info, warning, error, success,
star, heart, bolt, save, load, trash, copy, paste, refresh, filter, palette, sliders, tabs,
keyboard, mouse, edit, plus, shield, friend, bag, eye`.

---

## Library.Config

Сохранение/загрузка `Library.Flags` в JSON-файл на диске (если executor поддерживает
`writefile`/`readfile`/`listfiles`/`delfile`).

```lua
Library.Config:Save("profile1")   -- -> true/false
Library.Config:Load("profile1")   -- -> true/false, применяет значения ко всем элементам с Flag
Library.Config:List()             -- -> {"profile1", "profile2", ...}
Library.Config:Delete("profile1") -- -> true/false
```

---

## Library:Settings

Готовое окно «Настройки скрипта»: пресеты темы, акцентный цвет, радиус, толщина бордера,
скорость анимаций, плотность, выбор/регистрация шрифта, размер шрифта, поведение (клавиша
меню, автозапуск, язык и т.д.), сброс темы, экспорт UI-конфига в буфер обмена.

```lua
local settingsWindow = Library:Settings({
    OnExport = function(jsonString) end, -- необязательный колбэк при экспорте конфига
})
```

---

## Library:KeybindEditor

Готовое окно «Редактор биндов»: добавление своих биндов (имя действия, режим
Toggle/Hold/Always, клавиша), список зарегистрированных биндов с удалением и подсветкой
конфликтов (два бинда на одной клавише).

```lua
local editorWindow = Library:KeybindEditor()

-- Все добавленные пользователем бинды доступны здесь:
for _, bind in ipairs(Library._binds) do
    print(bind.Name, bind.Mode, bind.Key)
end
```

---

## Library:Search

Простой поиск по зарегистрированным флагам (подстрока, без учёта регистра).

```lua
local results = Library:Search("offset")  -- -> {"OffsetX", "OffsetY", "UGOffsetY", ...}
for _, flag in ipairs(results) do
    local element = Library._elements[flag]
    print(flag, element:Get())
end
```

---

## Library.Flags / Library._elements

- `Library.Flags[flag]` — текущее значение элемента с этим `Flag` (число/строка/boolean/Color3/…).
- `Library._elements[flag]` — сам объект элемента (`:Get()`, `:Set()` и т.д.), удобно для
  программного управления GUI без хранения локальных ссылок.

```lua
print(Library.Flags.OffsetY)                 -- 4.2
Library._elements.OffsetY:Set(-4.2)
```

---

## Library:Unload

Отключает все обработчики событий, уничтожает `ScreenGui`, очищает `Library.Flags` и
`Library._elements`. Вызывать при полной выгрузке скрипта.

```lua
Library:Unload()
```

---

## Полный пример

```lua
local Library = loadstring(readfile("KrakenUI.luau"))()

Library.Theming:Use("Cyber Blue")
Library.Theming:SetDensity("Comfortable")

local ks = Library:KeySystem({
    Title    = "Введите ключ",
    Validate = function(key) return key == "DEMO-DEMO-DEMO" end,
})

ks:Prompt(function()
    local loader = Library:Loader({
        Title = "MyScript",
        Steps = {
            { Name = "Загрузка ядра...",   Weight = 30, Fn = function() task.wait(0.2) end },
            { Name = "Инициализация UI...", Weight = 40, Fn = function() task.wait(0.2) end },
            { Name = "Готово",              Weight = 30 },
        },
    })

    loader:Run(function()
        local win = Library:Window({ Title = "MyScript", SubTitle = "v1.0" })

        local tabMain = win:Tab({ Name = "Главная", Icon = "settings" })
        local sec = tabMain:Section({ Name = "Основное", Icon = "star" })

        sec:Toggle({ Name = "Пример тоггла", Flag = "Example", Default = false })
        sec:Slider({ Name = "Пример слайдера", Min = 0, Max = 100, Decimals = 1, Suffix = "%", Flag = "ExampleSlider" })
        sec:Divider()
        sec:Paragraph({ Title = "Инфо", Text = "Это демонстрационная секция." })

        local tabSettings = win:Tab({ Name = "Настройки", Icon = "cog" })
        tabSettings:Section({ Name = "GUI" }):Button({
            Name = "Открыть настройки библиотеки",
            Callback = function() Library:Settings() end,
        })

        Library:Watermark({ Text = "MyScript | загружен" })
        Library:Notification({ Title = "MyScript", Text = "Готов к работе", Icon = "success" })
    end)
end)
```
