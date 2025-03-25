-- HHUB UI Library v3.0
local HHUB = {
    Version = "3.0",
    Elements = {},
    Windows = {},
    Notifications = {},
    Styles = {
        Window = {
            Background = Color3.fromRGB(38, 38, 38),
            HeaderColor = Color3.fromRGB(50, 50, 50),
            TabColor = Color3.fromRGB(65, 65, 65),
            TextColor = Color3.fromRGB(255, 255, 255),
            HeaderHeight = 30,
            TabHeight = 25,
            ResizeHandleSize = 10
        },
        Toggle = {
            Width = 45,
            Height = 25,
            OnColor = Color3.fromRGB(66, 99, 250),
            OffColor = Color3.fromRGB(77, 77, 77),
            ThumbColor = Color3.fromRGB(255, 255, 255),
            AnimationDuration = 0.3
        },
        Button = {
            Background = Color3.fromRGB(66, 99, 250),
            TextColor = Color3.fromRGB(255, 255, 255),
            HoverColor = Color3.fromRGB(85, 115, 255)
        },
        Notification = {
            Background = Color3.fromRGB(45, 45, 45),
            TextColor = Color3.fromRGB(255, 255, 255),
            Duration = 3
        }
    },
    Animations = {},
    Active = true,
    ZIndexCounter = 100
}

--[[ Internal Core Systems ]]--
local DrawingLib = Drawing or (syn and syn.Drawing)
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Metatables
local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

--[[ Animation Controller ]]--
local Animation = {
    Active = {},
    Easing = {
        Linear = function(t) return t end,
        OutBack = function(t)
            local s = 1.70158
            return (t - 1) * (t - 1) * ((s + 1) * (t - 1) + s) + 1
        end,
        OutElastic = function(t)
            local p = 0.3
            return math.pow(2, -10 * t) * math.sin((t - p/4) * (2 * math.pi)/p) + 1
        end
    }
}

function Animation:Add(instance, properties, duration, easing, callback)
    table.insert(self.Active, {
        Instance = instance,
        Properties = properties,
        StartTime = tick(),
        Duration = duration,
        Easing = easing or "Linear",
        Callback = callback
    })
end

function Animation:Update()
    local now = tick()
    for i = #self.Active, 1, -1 do
        local anim = self.Active[i]
        local progress = math.clamp((now - anim.StartTime) / anim.Duration, 0, 1)
        local eased = self.Easing[anim.Easing](progress)
        
        for prop, target in pairs(anim.Properties) do
            local current = anim.Instance[prop]
            if typeof(current) == "number" then
                anim.Instance[prop] = current + (target - current) * eased
            elseif typeof(current) == "Color3" then
                anim.Instance[prop] = current:Lerp(target, eased)
            elseif typeof(current) == "Vector2" then
                anim.Instance[prop] = current:Lerp(target, eased)
            end
        end

        if progress >= 1 then
            table.remove(self.Active, i)
            if anim.Callback then pcall(anim.Callback) end
        end
    end
end

--[[ Window Methods ]]--
function Window:AddTab(name)
    local tab = setmetatable({
        Name = name,
        Elements = {},
        Visible = false,
        Parent = self
    }, Tab)
    
    -- Create tab button
    tab.Button = self:CreateElement("TextButton", {
        Text = name,
        Position = Vector2.new(10 + (#self.Tabs * 80), 5),
        Size = Vector2.new(70, 20),
        BackgroundColor = HHUB.Styles.Window.TabColor,
        TextColor = HHUB.Styles.Window.TextColor,
        OnClick = function()
            self:SwitchTab(name)
        end
    })
    
    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then
        self:SwitchTab(name)
    end
    return tab
end

function Window:SwitchTab(name)
    for _, tab in pairs(self.Tabs) do
        tab.Visible = (tab.Name == name)
        tab.Button.BackgroundColor = tab.Visible 
            and HHUB.Styles.Button.Background 
            or HHUB.Styles.Window.TabColor
    end
    self.CurrentTab = name
    self:UpdateLayout()
end

function Window:UpdateLayout()
    local yOffset = HHUB.Styles.Window.HeaderHeight + 10
    for _, element in pairs(self.Elements) do
        if element.ParentTab == self.CurrentTab then
            element.Position = Vector2.new(10, yOffset)
            element.Visible = true
            yOffset += element.Size.Y + 5
        else
            element.Visible = false
        end
    end
end

function Window:CreateElement(type, properties)
    local element = {
        Type = type,
        Visible = true,
        ParentTab = self.CurrentTab,
        ZIndex = HHUB.ZIndexCounter,
        Destroy = function(self)
            for _, drawing in pairs(self.Drawings) do
                drawing:Remove()
            end
        end
    }
    
    HHUB.ZIndexCounter += 1
    
    -- Create drawing objects
    if type == "TextButton" then
        element.Drawings = {
            Background = DrawingLib.new("Square"),
            Text = DrawingLib.new("Text")
        }
        -- Setup properties...
    end
    
    table.insert(self.Elements, element)
    return element
end

--[[ Public API ]]--
function HHUB:Init()
    RunService.Heartbeat:Connect(function(delta)
        Animation:Update()
        self:ProcessInput()
        self:DrawNotifications()
    end)
end

function HHUB:CreateWindow(options)
    local window = setmetatable({
        Name = options.Name or "HHUB Window",
        Position = options.Position or Vector2.new(100, 100),
        Size = options.Size or Vector2.new(300, 400),
        Tabs = {},
        Elements = {},
        ZIndex = 100
    }, Window)
    
    -- Create window frame
    window.MainFrame = window:CreateElement("Frame", {
        Size = window.Size,
        Position = window.Position,
        BackgroundColor = HHUB.Styles.Window.Background
    })
    
    table.insert(HHUB.Windows, window)
    return window
end

function HHUB:CreateToggle(options)
    local toggle = {
        State = options.Default or false,
        Position = options.Position,
        Size = Vector2.new(HHUB.Styles.Toggle.Width, HHUB.Styles.Toggle.Height),
        Drawings = {
            Track = DrawingLib.new("Square"),
            Thumb = DrawingLib.new("Circle")
        }
    }
    
    function toggle:SetState(value)
        self.State = value
        Animation:Add(self.Drawings.Thumb, {
            Position = value 
                and Vector2.new(self.Position.X + self.Size.X - 10, self.Position.Y + 10)
                or Vector2.new(self.Position.X + 10, self.Position.Y + 10)
        }, HHUB.Styles.Toggle.AnimationDuration, "OutElastic")
        
        Animation:Add(self.Drawings.Track, {
            Color = value and HHUB.Styles.Toggle.OnColor or HHUB.Styles.Toggle.OffColor
        }, 0.2, "Linear")
    end
    
    -- Initial setup
    toggle:SetState(toggle.State)
    return toggle
end

function HHUB:Notify(text, duration)
    table.insert(self.Notifications, {
        Text = text,
        Created = tick(),
        Duration = duration or HHUB.Styles.Notification.Duration
    })
end

function HHUB:Unload()
    for _, window in pairs(HHUB.Windows) do
        window:Destroy()
    end
    self.Active = false
end

return HHUB
