--[[
    FC RECHAT V1 — Premium Social Frontend
    Made by: skzkahdjgjvjgufjhfjf

    Roblox Studio LocalScript.
    Place in StarterPlayer > StarterPlayerScripts.

    This is a client-side UI prototype. For normal Roblox experiences,
    use PlayerGui (not CoreGui) for game UI. CoreGui is Roblox-protected
    and is not available to ordinary Studio LocalScripts.

    Local prototype features:
      Home feed, stories, search, chat composer, local messages,
      message hold actions (Edit / Unsend / Copy-display),
      reactions, comments, bookmarks, profile editor, follow demo,
      people directory, Top 100 session leaderboard, notifications,
      themes, settings, draggable/minimize/lock/restore window,
      responsive scaling, owner tools preview, slash-command help,
      local post creation and feed interactions.

    Not included without server/backend:
      global chat, cross-server DMs/groups, persistent follows,
      secure moderation, global leaderboard, real clipboard access.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CONFIG = {
    Name = "FC RECHAT V1",
    Creator = "skzkahdjgjvjgufjhfjf",
    Owner = "skzkahdjgjvjgufjhfjf",
    Width = 720,
    Height = 540,
    HoldSeconds = 2,
    Background = Color3.fromRGB(15, 15, 21),
    Surface = Color3.fromRGB(25, 25, 34),
    Surface2 = Color3.fromRGB(36, 36, 48),
    Text = Color3.fromRGB(246, 246, 251),
    Muted = Color3.fromRGB(155, 155, 174),
    Pink = Color3.fromRGB(255, 65, 145),
    Red = Color3.fromRGB(255, 76, 96),
    Green = Color3.fromRGB(70, 220, 150),
}

local state = {
    theme = Color3.fromRGB(177, 75, 255),
    locked = false,
    minimized = false,
    tab = "Home",
    chatMode = "Global",
    selectedDM = nil,
    editing = nil,
    following = {},
    profiles = {},
    messages = {},
    posts = {},
    stories = {},
    groups = {},
    notifications = {},
    bookmarks = {},
    likes = {},
    comments = {},
    search = "",
    nextId = 0,
}

local function owner()
    return string.lower(player.Name) == string.lower(CONFIG.Owner)
end

local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    obj.Parent = parent
    return obj
end

local function corner(obj, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 12)}, obj)
end

local function outline(obj, color, thickness, transparency)
    return make("UIStroke", {
        Color = color or state.theme,
        Thickness = thickness or 1,
        Transparency = transparency or 0.1,
    }, obj)
end

local function addPadding(obj, n)
    make("UIPadding", {
        PaddingTop = UDim.new(0, n),
        PaddingBottom = UDim.new(0, n),
        PaddingLeft = UDim.new(0, n),
        PaddingRight = UDim.new(0, n),
    }, obj)
end

local function animate(obj, duration, props)
    local t = TweenService:Create(
        obj,
        TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

local function toast(title, message)
    table.insert(state.notifications, {
        title = title,
        text = message,
        time = os.time(),
        read = false,
    })
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = message,
            Duration = 3,
        })
    end)
end

local function label(parent, text, size, pos, textSize, color)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Size = size or UDim2.new(1, 0, 0, 24),
        Position = pos or UDim2.new(),
        Font = Enum.Font.Gotham,
        Text = text or "",
        TextSize = textSize or 13,
        TextColor3 = color or CONFIG.Text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)
end

local function button(parent, text, size, pos, callback, accent)
    local b = make("TextButton", {
        Size = size or UDim2.fromOffset(100, 34),
        Position = pos or UDim2.new(),
        BackgroundColor3 = accent and state.theme or CONFIG.Surface2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextSize = 12,
        TextColor3 = CONFIG.Text,
    }, parent)
    corner(b, 9)
    b.MouseEnter:Connect(function()
        animate(b, 0.12, {BackgroundColor3 = state.theme})
    end)
    b.MouseLeave:Connect(function()
        animate(b, 0.12, {
            BackgroundColor3 = accent and state.theme or CONFIG.Surface2
        })
    end)
    b.Activated:Connect(function()
        if callback then callback() end
    end)
    return b
end

local function textbox(parent, placeholder, size, pos)
    local t = make("TextBox", {
        Size = size,
        Position = pos or UDim2.new(),
        BackgroundColor3 = CONFIG.Surface2,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = placeholder,
        PlaceholderColor3 = CONFIG.Muted,
        Text = "",
        TextColor3 = CONFIG.Text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    }, parent)
    corner(t, 9)
    addPadding(t, 9)
    return t
end

local function avatar(parent, userId, size, pos)
    local image = ""
    pcall(function()
        image = Players:GetUserThumbnailAsync(
            userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150
        )
    end)
    local a = make("ImageLabel", {
        Size = size or UDim2.fromOffset(42, 42),
        Position = pos or UDim2.new(),
        BackgroundColor3 = CONFIG.Surface2,
        BorderSizePixel = 0,
        Image = image,
        ScaleType = Enum.ScaleType.Crop,
    }, parent)
    corner(a, 100)
    return a
end

local function profileFor(plr)
    local id = plr and plr.UserId or player.UserId
    if not state.profiles[id] then
        state.profiles[id] = {
            userId = id,
            username = plr and plr.Name or player.Name,
            displayName = plr and plr.DisplayName or player.DisplayName,
            bio = "Welcome to FC RECHAT V1 ✨",
            followers = 0,
        }
    end
    return state.profiles[id]
end

local function clear(frame)
    for _, child in ipairs(frame:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding")
            and not child:IsA("UIGridLayout") then
            child:Destroy()
        end
    end
end

local function makeScroll(parent, size, pos)
    local sc = make("ScrollingFrame", {
        Size = size or UDim2.fromScale(1, 1),
        Position = pos or UDim2.new(),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = state.theme,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
    }, parent)
    local layout = make("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, sc)
    addPadding(sc, 5)
    return sc
end

local function heading(parent, title, subtitle)
    local f = make("Frame", {
        Size = UDim2.new(1, -8, 0, subtitle and 62 or 38),
        BackgroundColor3 = CONFIG.Surface,
        BorderSizePixel = 0,
    }, parent)
    corner(f, 11)
    label(f, title, UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 5), 16).Font =
        Enum.Font.GothamBold
    if subtitle then
        label(f, subtitle, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 31),
            10, CONFIG.Muted)
    end
    return f
end

local old = playerGui:FindFirstChild("FC_RECHAT_V1")
if old then old:Destroy() end

-- Standard Roblox game UI belongs in PlayerGui. CoreGui is protected.
local gui = make("ScreenGui", {
    Name = "FC_RECHAT_V1",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 50,
}, playerGui)

local main = make("Frame", {
    Name = "MainWindow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(CONFIG.Width, CONFIG.Height),
    BackgroundColor3 = CONFIG.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
corner(main, 16)
local mainStroke = outline(main, state.theme, 1.5, 0.08)
local scale = make("UIScale", {Scale = 1}, main)

local header = make("Frame", {
    Size = UDim2.new(1, 0, 0, 52),
    BackgroundColor3 = CONFIG.Surface,
    BorderSizePixel = 0,
}, main)
label(header, "✦ FC RECHAT V1", UDim2.new(1, -260, 1, 0),
    UDim2.fromOffset(15, 0), 17).Font = Enum.Font.GothamBold
label(header, "● LOCAL MODE", UDim2.fromOffset(100, 20),
    UDim2.new(1, -285, 0, 16), 9, CONFIG.Green).TextXAlignment =
    Enum.TextXAlignment.Right

local minimize = button(header, "—", UDim2.fromOffset(30, 30),
    UDim2.new(1, -108, 0, 11))
local lock = button(header, "🔓", UDim2.fromOffset(30, 30),
    UDim2.new(1, -72, 0, 11))
local close = button(header, "×", UDim2.fromOffset(30, 30),
    UDim2.new(1, -36, 0, 11))

local sidebar = make("ScrollingFrame", {
    Name = "HorizontalNavigation",
    Position = UDim2.fromOffset(8, 56),
    Size = UDim2.new(1, -16, 0, 42),
    BackgroundColor3 = CONFIG.Surface,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollingDirection = Enum.ScrollingDirection.X,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.X,
}, main)
corner(sidebar, 10)
local navLayout = make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, sidebar)
navLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    sidebar.CanvasSize = UDim2.fromOffset(navLayout.AbsoluteContentSize.X + 10, 0)
end)
addPadding(sidebar, 5)

local content = make("Frame", {
    Position = UDim2.new(0, 8, 0, 106),
    Size = UDim2.new(1, -16, 1, -114),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, main)

local floating = button(gui, "⚡", UDim2.fromOffset(54, 54),
    UDim2.new(1, -72, 0.72, 0), function()
        state.minimized = false
        main.Visible = true
        floating.Visible = false
        animate(main, 0.18, {Size = UDim2.fromOffset(CONFIG.Width, CONFIG.Height)})
    end)
floating.Visible = false
floating.TextSize = 24
outline(floating, state.theme, 2, 0)

local function draggable(handle, target)
    local dragging, startInput, startPos, activeInput = false, nil, nil, nil
    handle.InputBegan:Connect(function(input)
        if state.locked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, startInput, startPos, activeInput = true, input.Position,
                target.Position, input
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            activeInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and activeInput and input == activeInput then
            local delta = input.Position - startInput
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end
draggable(header, main)
draggable(floating, floating)

local renderTab

local function addMessage(text, chatKey)
    state.nextId += 1
    local m = {
        id = state.nextId,
        author = player.Name,
        userId = player.UserId,
        text = text,
        time = os.time(),
        chat = chatKey or state.chatMode,
        reactions = {},
        edited = false,
    }
    table.insert(state.messages, m)
    return m
end

local function messageActions(message)
    local popup = make("Frame", {
        Size = UDim2.fromOffset(270, 48),
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -8),
        BackgroundColor3 = CONFIG.Surface2,
        BorderSizePixel = 0,
        ZIndex = 40,
    }, main)
    corner(popup, 10)
    outline(popup, state.theme, 1, 0.1)

    for i, action in ipairs({"Edit", "Unsend", "Copy"}) do
        local b = button(popup, action, UDim2.new(1/3, -6, 1, -8),
            UDim2.new((i - 1)/3, 2, 0, 4), function()
                popup:Destroy()
                if action == "Edit" then
                    if message.userId ~= player.UserId then
                        toast("FC RECHAT", "You can only edit your own messages.")
                        return
                    end
                    state.editing = message
                    state.tab = "Chat"
                    state.chatMode = message.chat
                    renderTab()
                elseif action == "Unsend" then
                    if message.userId ~= player.UserId then
                        toast("FC RECHAT", "You can only unsend your own messages.")
                        return
                    end
                    for idx, m in ipairs(state.messages) do
                        if m.id == message.id then
                            table.remove(state.messages, idx)
                            break
                        end
                    end
                    renderTab()
                else
                    local panel = make("Frame", {
                        Size = UDim2.new(1, -36, 0, 115),
                        Position = UDim2.new(0, 18, 0.5, -58),
                        BackgroundColor3 = CONFIG.Surface,
                        ZIndex = 50,
                    }, main)
                    corner(panel, 12)
                    label(panel, "Copy text manually", UDim2.new(1, -20, 0, 24),
                        UDim2.fromOffset(10, 5), 13)
                    local t = textbox(panel, "", UDim2.new(1, -20, 0, 45),
                        UDim2.fromOffset(10, 32))
                    t.Text = message.text
                    t.TextEditable = false
                    t.ZIndex = 51
                    local c = button(panel, "Close", UDim2.fromOffset(68, 25),
                        UDim2.new(1, -78, 1, -32), function() panel:Destroy() end)
                    c.ZIndex = 51
                end
            end)
        b.ZIndex = 41
    end
end

local function renderHome()
    clear(content)
    heading(content, "Your Feed", "Catch up with your community • local preview")

    local storyFrame = make("Frame", {
        Size = UDim2.new(1, -8, 0, 104),
        BackgroundColor3 = CONFIG.Surface,
        BorderSizePixel = 0,
    }, content)
    corner(storyFrame, 12)
    label(storyFrame, "STORIES", UDim2.new(1, -20, 0, 20),
        UDim2.fromOffset(10, 5), 10).Font = Enum.Font.GothamBold

    local storyRow = make("ScrollingFrame", {
        Position = UDim2.fromOffset(6, 29),
        Size = UDim2.new(1, -12, 0, 66),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
    }, storyFrame)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 7),
    }, storyRow)

    button(storyRow, "＋ Add story", UDim2.fromOffset(95, 52), nil, function()
        table.insert(state.stories, {
            author = player.Name, text = "New story", time = os.time()
        })
        toast("Stories", "Story added for this session.")
        renderHome()
    end, true)

    for _, story in ipairs(state.stories) do
        button(storyRow, "◉ " .. story.author, UDim2.fromOffset(105, 52), nil,
            function() toast("Story", story.text) end)
    end

    local postComposer = make("Frame", {
        Size = UDim2.new(1, -8, 0, 90),
        BackgroundColor3 = CONFIG.Surface,
        BorderSizePixel = 0,
    }, content)
    corner(postComposer, 12)
    local postBox = textbox(postComposer, "What's happening? Share a post...",
        UDim2.new(1, -100, 0, 42), UDim2.fromOffset(8, 8))
    button(postComposer, "Post", UDim2.fromOffset(78, 42),
        UDim2.new(1, -86, 0, 8), function()
            if postBox.Text:gsub("%s+", "") == "" then return end
            state.nextId += 1
            table.insert(state.posts, {
                id = state.nextId,
                author = player.Name,
                userId = player.UserId,
                text = postBox.Text,
                time = os.time(),
            })
            toast("Feed", "Post created in this session.")
            renderHome()
        end, true)
    label(postComposer, "Posts are currently visible only in this client.",
        UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 58), 10, CONFIG.Muted)

    local feed = makeScroll(content, UDim2.new(1, -8, 1, -220))
    for i = #state.posts, 1, -1 do
        local post = state.posts[i]
        local card = make("Frame", {
            Size = UDim2.new(1, -8, 0, 145),
            BackgroundColor3 = CONFIG.Surface,
            BorderSizePixel = 0,
        }, feed)
        corner(card, 12)
        avatar(card, post.userId, UDim2.fromOffset(38, 38), UDim2.fromOffset(10, 9))
        label(card, "@" .. post.author, UDim2.new(1, -62, 0, 22),
            UDim2.fromOffset(56, 8), 12, state.theme).Font = Enum.Font.GothamBold
        label(card, post.text, UDim2.new(1, -22, 0, 50),
            UDim2.fromOffset(11, 52), 13)
        button(card, state.likes[post.id] and "♥ Liked" or "♡ Like",
            UDim2.fromOffset(80, 28), UDim2.fromOffset(10, 108), function()
                state.likes[post.id] = not state.likes[post.id]
                renderHome()
            end)
        button(card, "Comment", UDim2.fromOffset(88, 28),
            UDim2.fromOffset(98, 108), function()
                toast("Comments", "Comment UI can be connected to the backend.")
            end)
        button(card, state.bookmarks[post.id] and "★ Saved" or "☆ Save",
            UDim2.fromOffset(82, 28), UDim2.fromOffset(192, 108), function()
                state.bookmarks[post.id] = not state.bookmarks[post.id]
                renderHome()
            end)
    end
end

local function renderChat()
    clear(content)
    heading(content, "Messages", "Local demo • real-time messaging requires server networking")

    local modeBar = make("Frame", {
        Size = UDim2.new(1, -8, 0, 36),
        BackgroundTransparency = 1,
    }, content)
    local modes = {
        {"Global", "Global"},
        {"Direct", "Direct"},
        {"Groups", "Groups"},
    }
    for i, pair in ipairs(modes) do
        button(modeBar, pair[1], UDim2.new(1/3, -5, 1, 0),
            UDim2.new((i - 1)/3, 0, 0, 0), function()
                state.chatMode = pair[2]
                state.selectedDM = nil
                state.editing = nil
                renderChat()
            end, state.chatMode == pair[2])
    end

    if state.chatMode == "Direct" and not state.selectedDM then
        local search = textbox(content, "Search current-server players...",
            UDim2.new(1, -8, 0, 38))
        local list = makeScroll(content, UDim2.new(1, -8, 1, -150))
        local function fill(query)
            clear(list)
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and string.find(string.lower(p.Name),
                    string.lower(query), 1, true) then
                    button(list, "@" .. p.Name .. "  ·  Open DM",
                        UDim2.new(1, -8, 0, 40), nil, function()
                            state.selectedDM = p.Name
                            renderChat()
                        end)
                end
            end
        end
        search:GetPropertyChangedSignal("Text"):Connect(function()
            fill(search.Text)
        end)
        fill("")
        return
    elseif state.chatMode == "Groups" then
        button(content, "＋ Create local group", UDim2.new(1, -8, 0, 38),
            nil, function()
                local groupName = "Group " .. tostring(#state.groups + 1)
                local members = {player.Name}
                for _, candidate in ipairs(Players:GetPlayers()) do
                    if candidate ~= player and state.following[candidate.UserId] then
                        table.insert(members, candidate.Name)
                    end
                end
                if #members < 2 then
                    toast("Groups", "Follow at least one player in this server before creating a group.")
                    return
                end
                table.insert(state.groups, {name = groupName, members = members})
                toast("Groups", groupName .. " created with followed players only.")
                renderChat()
            end, true)
        for _, g in ipairs(state.groups) do
            button(content, "👥 " .. g.name .. "  •  " .. #g.members .. " members",
                UDim2.new(1, -8, 0, 38), nil, function()
                    toast("Groups", "Group membership and group chat need a backend.")
                end)
        end
        return
    end

    local chatKey = state.chatMode == "Direct" and ("DM:" .. tostring(state.selectedDM))
        or "Global"

    if state.chatMode == "Direct" and state.selectedDM then
        button(content, "← Back to conversations", UDim2.new(1, -8, 0, 30),
            nil, function()
                state.selectedDM = nil
                renderChat()
            end)
        heading(content, "@" .. state.selectedDM, "Direct message preview")
    end

    local list = makeScroll(content, UDim2.new(1, -8, 1, -170))
    for _, m in ipairs(state.messages) do
        if m.chat == chatKey then
            local card = make("Frame", {
                Size = UDim2.new(1, -8, 0, 72),
                BackgroundColor3 = CONFIG.Surface,
                BorderSizePixel = 0,
            }, list)
            corner(card, 10)
            avatar(card, m.userId, UDim2.fromOffset(34, 34), UDim2.fromOffset(8, 10))
            label(card, "@" .. m.author .. (m.edited and " · edited" or ""),
                UDim2.new(1, -65, 0, 20), UDim2.fromOffset(50, 6), 11, state.theme)
                .Font = Enum.Font.GothamBold
            label(card, m.text, UDim2.new(1, -65, 0, 35),
                UDim2.fromOffset(50, 27), 12)
            local startTime = 0
            local startObject
            card.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    startTime = os.clock()
                    startObject = input
                    task.delay(CONFIG.HoldSeconds, function()
                        if startTime > 0 then
                            messageActions(m)
                            startTime = 0
                        end
                    end)
                end
            end)
            card.InputEnded:Connect(function(input)
                if input == startObject then startTime = 0 end
            end)
            button(card, "♥", UDim2.fromOffset(28, 24),
                UDim2.new(1, -34, 0, 5), function()
                    m.reactions[player.UserId] = not m.reactions[player.UserId]
                    toast("Reaction", "Reaction updated locally.")
                end).TextColor3 = CONFIG.Red
        end
    end

    local composer = make("Frame", {
        Size = UDim2.new(1, -8, 0, 94),
        Position = UDim2.new(0, 0, 1, -96),
        BackgroundColor3 = CONFIG.Surface,
        BorderSizePixel = 0,
    }, content)
    corner(composer, 11)
    local input = textbox(composer, "Message... use @username to mention",
        UDim2.new(1, -90, 0, 42), UDim2.fromOffset(8, 8))
    if state.editing then input.Text = state.editing.text end
    local send = button(composer, "Send", UDim2.fromOffset(70, 42),
        UDim2.new(1, -78, 0, 8), function()
            local text = input.Text
            if text:gsub("%s+", "") == "" then return end
            if state.editing then
                if state.editing.userId == player.UserId then
                    state.editing.text = text
                    state.editing.edited = true
                end
                state.editing = nil
            else
                addMessage(text, chatKey)
                for username in text:gmatch("@([%w_]+)") do
                    toast("Mention", "Mention detected: @" .. username)
                end
                if text:sub(1, 1) == "/" then
                    local command = text:match("^/(%S+)")
                    if command == "help" then
                        toast("Commands", "/help /profile /follow /settings /clear")
                    elseif command == "profile" then
                        state.tab = "Profile"
                        renderTab()
                        return
                    elseif command == "settings" then
                        state.tab = "Settings"
                        renderTab()
                        return
                    elseif command == "clear" then
                        for i = #state.messages, 1, -1 do
                            if state.messages[i].chat == chatKey
                                and state.messages[i].userId == player.UserId then
                                table.remove(state.messages, i)
                            end
                        end
                    else
                        toast("Commands", "Unknown command. Try /help")
                    end
                end
            end
            renderChat()
        end, true)
    input.FocusLost:Connect(function(enter)
        if enter then send:Activate() end
    end)
end

local function renderProfile()
    clear(content)
    local p = profileFor(player)
    local card = make("Frame", {
        Size = UDim2.new(1, -8, 0, 130),
        BackgroundColor3 = CONFIG.Surface,
        BorderSizePixel = 0,
    }, content)
    corner(card, 12)
    avatar(card, player.UserId, UDim2.fromOffset(74, 74), UDim2.fromOffset(14, 14))
    label(card, player.DisplayName, UDim2.new(1, -110, 0, 25),
        UDim2.fromOffset(100, 14), 17).Font = Enum.Font.GothamBold
    label(card, "@" .. player.Name, UDim2.new(1, -110, 0, 20),
        UDim2.fromOffset(100, 40), 12, state.theme)
    label(card, tostring(p.followers) .. " followers  •  " ..
        tostring(#Players:GetPlayers()) .. " players here",
        UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 99), 11)

    heading(content, "Edit profile", "Changes are saved for this client session.")
    local display = textbox(content, "Display name", UDim2.new(1, -8, 0, 38))
    display.Text = p.displayName
    local bio = textbox(content, "Bio (max 160 characters)",
        UDim2.new(1, -8, 0, 70))
    bio.Text = p.bio
    button(content, "Save profile", UDim2.new(1, -8, 0, 38), nil, function()
        p.displayName = display.Text:sub(1, 40)
        p.bio = bio.Text:sub(1, 160)
        toast("Profile", "Profile updated locally.")
        renderProfile()
    end, true)
    button(content, "Refresh Roblox avatar", UDim2.new(1, -8, 0, 36), nil,
        function()
            toast("Profile", "Avatar comes from your Roblox account.")
            renderProfile()
        end)
end

local function renderPeople()
    clear(content)
    heading(content, "Discover people", "Only players currently in this server can be followed in this local session.")
    local search = textbox(content, "Search username...", UDim2.new(1, -8, 0, 38))
    local list = makeScroll(content, UDim2.new(1, -8, 1, -115))
    local function fill(q)
        clear(list)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and string.find(string.lower(p.Name), string.lower(q), 1, true) then
                local row = make("Frame", {
                    Size = UDim2.new(1, -8, 0, 64),
                    BackgroundColor3 = CONFIG.Surface,
                    BorderSizePixel = 0,
                }, list)
                corner(row, 10)
                avatar(row, p.UserId, UDim2.fromOffset(42, 42), UDim2.fromOffset(8, 10))
                label(row, p.DisplayName .. "\n@" .. p.Name,
                    UDim2.new(1, -145, 1, 0), UDim2.fromOffset(58, 0), 11)
                local following = state.following[p.UserId] == true
                button(row, following and "Following" or "Follow",
                    UDim2.fromOffset(82, 32), UDim2.new(1, -91, 0.5, -16), function()
                        state.following[p.UserId] = not following
                        local prof = profileFor(p)
                        prof.followers = math.max(0, prof.followers + (following and -1 or 1))
                        toast("Follow", following and ("Unfollowed @" .. p.Name)
                            or ("Following @" .. p.Name))
                        fill(search.Text)
                    end, not following)
            end
        end
    end
    search:GetPropertyChangedSignal("Text"):Connect(function() fill(search.Text) end)
    fill("")
end

local function renderLeaderboard()
    clear(content)
    heading(content, "🏆 Top 100", "Session follower counts only; global rankings need a backend.")
    local list = makeScroll(content, UDim2.new(1, -8, 1, -80))
    local ranking = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local followerCount = 0
        for _, followedId in pairs(state.following) do
            if followedId == p.UserId then followerCount += 1 end
        end
        table.insert(ranking, {player = p, followers = followerCount})
    end
    table.sort(ranking, function(a, b)
        if a.followers == b.followers then return a.player.Name < b.player.Name end
        return a.followers > b.followers
    end)
    for i, item in ipairs(ranking) do
        if i > 100 then break end
        local row = make("Frame", {
            Size = UDim2.new(1, -8, 0, 54),
            BackgroundColor3 = CONFIG.Surface,
            BorderSizePixel = 0,
        }, list)
        corner(row, 9)
        label(row, "#" .. i, UDim2.fromOffset(42, 44),
            UDim2.fromOffset(7, 5), 16).Font = Enum.Font.GothamBold
        avatar(row, item.player.UserId, UDim2.fromOffset(38, 38),
            UDim2.fromOffset(48, 8))
        label(row, (profileFor(item.player).tag and "[" .. profileFor(item.player).tag .. "] " or "") .. item.player.DisplayName .. "\n@" .. item.player.Name,
            UDim2.new(1, -160, 1, 0), UDim2.fromOffset(94, 0), 11)
        label(row, tostring(item.followers) .. " followers",
            UDim2.fromOffset(100, 40), UDim2.new(1, -105, 0, 7), 10, state.theme)
    end
end

local function renderNotifications()
    clear(content)
    heading(content, "Notifications", "Mentions and activity from this session.")
    button(content, "Mark all as read", UDim2.new(1, -8, 0, 35), nil, function()
        for _, n in ipairs(state.notifications) do n.read = true end
        toast("Notifications", "Marked as read.")
    end)
    for i = #state.notifications, 1, -1 do
        local n = state.notifications[i]
        heading(content, n.title, n.text)
    end
    if #state.notifications == 0 then heading(content, "You're all caught up ✨", "No notifications yet.") end
end

local function renderThemes()
    clear(content)
    heading(content, "Appearance", "Choose an accent for the whole interface.")
    local themes = {
        {"Purple", Color3.fromRGB(177, 75, 255)},
        {"Pink", Color3.fromRGB(255, 65, 145)},
        {"Ruby Red", Color3.fromRGB(240, 50, 75)},
        {"Ocean Blue", Color3.fromRGB(45, 150, 255)},
        {"Neon Green", Color3.fromRGB(50, 220, 120)},
        {"Teal", Color3.fromRGB(45, 210, 200)},
        {"Gold", Color3.fromRGB(255, 190, 60)},
        {"Orange", Color3.fromRGB(255, 125, 55)},
        {"Ice Cyan", Color3.fromRGB(120, 235, 255)},
        {"Royal Blue", Color3.fromRGB(75, 90, 255)},
    }
    for _, entry in ipairs(themes) do
        button(content, "●   " .. entry[1], UDim2.new(1, -8, 0, 35), nil, function()
            state.theme = entry[2]
            mainStroke.Color = state.theme
            floating.TextColor3 = state.theme
            toast("Theme", entry[1] .. " applied.")
            renderThemes()
        end)
    end
    button(content, "RGB Accent", UDim2.new(1, -8, 0, 35), nil, function()
        state.rgb = not state.rgb
        if state.rgb then
            toast("RGB", "RGB accent animation enabled.")
        else
            toast("RGB", "RGB accent animation disabled.")
        end
    end)
end

local function renderSettings()
    clear(content)
    heading(content, "Settings", "Customize your FC RECHAT experience.")
    button(content, "Lock / unlock window", UDim2.new(1, -8, 0, 36), nil, function()
        state.locked = not state.locked
        lock.Text = state.locked and "🔒" or "🔓"
        toast("Window", state.locked and "Window locked." or "Window unlocked.")
    end)
    button(content, "Reset window position", UDim2.new(1, -8, 0, 36), nil, function()
        main.Position = UDim2.fromScale(0.5, 0.5)
        toast("Window", "Position reset.")
    end)
    button(content, "Clear local messages", UDim2.new(1, -8, 0, 36), nil, function()
        table.clear(state.messages)
        state.editing = nil
        toast("Chat", "Local message history cleared.")
    end)
    button(content, "Clear local feed", UDim2.new(1, -8, 0, 36), nil, function()
        table.clear(state.posts)
        table.clear(state.stories)
        toast("Feed", "Local feed and stories cleared.")
    end)
    button(content, "Open themes", UDim2.new(1, -8, 0, 36), nil, function()
        state.tab = "Themes"
        renderTab()
    end)
    heading(content, "Privacy & limitations",
        "This frontend does not send messages or profile data to other players.")
    heading(content, "Made by " .. CONFIG.Creator,
        "FC RECHAT V1 • local prototype")
end

local function renderOwner()
    clear(content)
    if not owner() then
        heading(content, "Restricted", "Owner controls are unavailable for this account.")
        return
    end
    heading(content, "🛡 Owner Console", "Moderation preview only; no actions are executed.")
    local target = textbox(content, "Target username...", UDim2.new(1, -8, 0, 38))
    local reason = textbox(content, "Reason (optional)...", UDim2.new(1, -8, 0, 38))
    for _, action in ipairs({"Preview Kick", "Preview Ban", "Preview Mute", "Preview Unban"}) do
        button(content, action, UDim2.new(1, -8, 0, 36), nil, function()
            local found
            for _, p in ipairs(Players:GetPlayers()) do
                if string.lower(p.Name) == string.lower(target.Text) then found = p break end
            end
            if not found then
                toast("Owner", "Player not found in this server.")
            else
                toast("Moderation preview", action .. " @" .. found.Name ..
                    (reason.Text ~= "" and (": " .. reason.Text) or "") ..
                    " — no action executed.")
            end
        end)
    end
    heading(content, "Custom role tags", "Local-only label editor. Use legitimate tags; server verification is required for real permissions.")
    local tagTarget = textbox(content, "Username to tag...", UDim2.new(1, -8, 0, 36))
    local tagName = textbox(content, "Tag name (GOD / DADDY / OWNER / CREATOR / FOUNDER / ADMIN / HEAD ADMIN / HERO / BAAP)", UDim2.new(1, -8, 0, 36))
    button(content, "Apply local tag", UDim2.new(1, -8, 0, 34), nil, function()
        local found
        for _, p in ipairs(Players:GetPlayers()) do if string.lower(p.Name) == string.lower(tagTarget.Text) then found = p break end end
        if not found then toast("Tags", "Player not found in this server.")
        elseif tagName.Text:gsub("%s+", "") == "" then toast("Tags", "Enter a tag name first.")
        else state.profiles[found.UserId] = state.profiles[found.UserId] or profileFor(found); state.profiles[found.UserId].tag = string.upper(tagName.Text); toast("Tags", "Local tag set: " .. string.upper(tagName.Text) .. " • no server authority changed.") end
    end, true)
    heading(content, "Admin music", "Enter an audio asset ID you are allowed to use. Only this client hears the demo audio.")
    local musicId = textbox(content, "Sound asset ID...", UDim2.new(1, -8, 0, 36))
    button(content, "Play music", UDim2.new(1, -8, 0, 34), nil, function()
        local id = musicId.Text:match("%d+")
        if not id then toast("Music", "Enter a numeric audio asset ID."); return end
        local sound = gui:FindFirstChild("FCAdminMusic") or Instance.new("Sound")
        sound.Name = "FCAdminMusic"; sound.Parent = gui; sound.SoundId = "rbxassetid://" .. id; sound.Volume = 0.35; sound.Looped = true
        pcall(function() sound:Play() end)
        toast("Music", "Requested local playback for asset " .. id)
    end, true)
    button(content, "Stop music", UDim2.new(1, -8, 0, 32), nil, function()
        local sound = gui:FindFirstChild("FCAdminMusic"); if sound then sound:Stop() end
    end)
    heading(content, "Slash commands", "/help • /profile • /settings • /clear • /follow • /unfollow • /tag • /music")
    heading(content, "Security",
        "Real moderation must be enforced by a server Script with verified owner permissions.")
end

local function renderBookmarks()
    clear(content)
    heading(content, "Saved posts", "Bookmarks from this client session.")
    local count = 0
    for _, post in ipairs(state.posts) do
        if state.bookmarks[post.id] then
            count += 1
            heading(content, "@" .. post.author, post.text)
        end
    end
    if count == 0 then heading(content, "Nothing saved yet", "Tap ☆ Save on a feed post.") end
end

local function renderAI()
    clear(content)
    heading(content, "✧ FC AI", "Local assistant demo • replies are generated from simple rules.")
    local transcript = makeScroll(content, UDim2.new(1, -8, 1, -132))
    local function reply(userText)
        local q = string.lower(userText)
        local answer
        if q:find("hello") or q:find("hi") then answer = "Hey! Welcome to FC RECHAT V1. What are we building today?"
        elseif q:find("help") then answer = "Try /help in chat, visit Explore to follow people, or open Settings to customize your UI."
        elseif q:find("roblox") then answer = "For a real multiplayer social app, use server-validated RemoteEvents and save data through a secure server DataStore."
        elseif q:find("tag") then answer = "Custom tags in this prototype are local UI labels. Server-side permissions are required to verify roles securely."
        elseif q:find("music") then answer = "Use an audio asset you have permission to use. In this demo, music controls are available in the Owner console."
        else answer = "I’m FC AI, your in-app helper. Ask about commands, profiles, tags, music, or Roblox Studio setup." end
        heading(transcript, "You", userText)
        heading(transcript, "FC AI", answer)
    end
    local entry = textbox(content, "Ask FC AI anything...", UDim2.new(1, -92, 0, 42), UDim2.new(0, 0, 1, -48))
    button(content, "Ask", UDim2.fromOffset(78, 42), UDim2.new(1, -82, 1, -48), function()
        if entry.Text:gsub("%s+", "") == "" then return end
        local q = entry.Text; entry.Text = ""; reply(q)
    end, true)
end

renderTab = function()
    if state.tab == "Home" then renderHome()
    elseif state.tab == "Chat" then renderChat()
    elseif state.tab == "Groups" then state.chatMode = "Groups"; renderChat()
    elseif state.tab == "Profile" then renderProfile()
    elseif state.tab == "People" or state.tab == "Follow" then renderPeople()
    elseif state.tab == "Leaderboard" then renderLeaderboard()
    elseif state.tab == "AI" then renderAI()
    elseif state.tab == "Notifications" then renderNotifications()
    elseif state.tab == "Themes" then renderThemes()
    elseif state.tab == "Settings" then renderSettings()
    elseif state.tab == "Owner" then renderOwner()
    elseif state.tab == "Saved" then renderBookmarks()
    else renderHome() end
end

local nav = {
    {"⌂  Home", "Home"},
    {"▤  Explore", "People"},
    {"＋  Create", "Create"},
    {"♡  Follow", "Follow"},
    {"✉  Messages", "Chat"},
    {"▣  Groups", "Groups"},
    {"◉  Profile", "Profile"},
    {"★  Saved", "Saved"},
    {"♛  Top 100", "Leaderboard"},
    {"♧  Notifications", "Notifications"},
    {"◈  Themes", "Themes"},
    {"✧  FC AI", "AI"},
    {"⚙  Settings", "Settings"},
}
if owner() then table.insert(nav, {"🛡  Owner", "Owner"}) end

for i, item in ipairs(nav) do
    local b = button(sidebar, item[1], UDim2.fromOffset(108, 30), nil, function()
        if item[2] == "Create" then
            state.tab = "Home"
            renderTab()
            toast("Create", "Use the post composer at the top of Home.")
        else
            state.tab = item[2]
            renderTab()
        end
    end)
    b.LayoutOrder = i
    b.TextXAlignment = Enum.TextXAlignment.Center
    b.LayoutOrder = i
end

minimize.Activated:Connect(function()
    state.minimized = true
    main.Visible = false
    floating.Visible = true
end)
lock.Activated:Connect(function()
    state.locked = not state.locked
    lock.Text = state.locked and "🔒" or "🔓"
    toast("Window", state.locked and "Window locked." or "Window unlocked.")
end)
close.Activated:Connect(function()
    gui:Destroy()
end)

local function resize()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local v = camera.ViewportSize
    scale.Scale = math.clamp(math.min((v.X - 18) / CONFIG.Width,
        (v.Y - 35) / CONFIG.Height, 1), 0.42, 1)
end
resize()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
end

Players.PlayerAdded:Connect(function(p)
    toast("Player Online", "@" .. p.Name .. " joined this server.")
    if state.tab == "People" or state.tab == "Follow" or state.tab == "Leaderboard" then
        task.defer(renderTab)
    end
end)
Players.PlayerRemoving:Connect(function(p)
    toast("Player Offline", "@" .. p.Name .. " left this server.")
    if state.tab == "People" or state.tab == "Follow" or state.tab == "Leaderboard" then
        task.defer(renderTab)
    end
end)

-- Optional RP metadata remotes, only if this experience exposes them.
task.spawn(function()
    local re = ReplicatedStorage:WaitForChild("RE", 8)
    if not re or not gui.Parent then return end
    local nameRemote = re:FindFirstChild("1RPNam1eTex1t")
    local colorRemote = re:FindFirstChild("1RPNam1eColo1r")
    if nameRemote and colorRemote then
        pcall(function()
            nameRemote:FireServer("RolePlayName", "FC RECHAT V1")
            nameRemote:FireServer("RolePlayBio", "Welcome dear, " .. player.Name)
        end)
        task.spawn(function()
            while gui.Parent do
                task.wait(0.2)
                local c = Color3.fromHSV((os.clock() % 5) / 5, 1, 1)
                pcall(function()
                    colorRemote:FireServer("PickingRPNameColor", c)
                    colorRemote:FireServer("PickingRPBioColor", c)
                end)
            end
        end)
    end
end)

-- Optional RGB accent animation.
task.spawn(function()
    while gui.Parent do
        task.wait(0.06)
        if state.rgb then
            local c = Color3.fromHSV((os.clock() * 0.12) % 1, 0.85, 1)
            mainStroke.Color = c
            floating.TextColor3 = c
        elseif mainStroke.Color ~= state.theme then
            mainStroke.Color = state.theme
        end
    end
end)

renderTab()
toast(CONFIG.Name, "Premium frontend loaded • Made by " .. CONFIG.Creator)
print("[FC RECHAT V1] Premium local frontend initialized.")
