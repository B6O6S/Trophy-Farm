-- Overdrive H On Top.

local shared = odh_shared_plugins

local my_own_tab = shared.CreateTab("Better ODH", "/B6O6S/Better-ODH/refs/heads/main/1793621588714")
local trickshot_section = my_own_tab:AddSection("Trickshot & Movement", "يلعن سمير")

--==================================================
-- SERVICES & SAFE CONTEXT
--==================================================

local getgenv = type(getgenv) == "function"
    and getgenv
    or function()
        return _G
    end

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = assert(
    Players.LocalPlayer,
    "LocalPlayer unavailable; run on the client"
)

local playerGui =
    LocalPlayer:FindFirstChildOfClass("PlayerGui")
    or LocalPlayer:WaitForChild("PlayerGui", 10)

assert(
    playerGui,
    "PlayerGui did not become available within 10 seconds"
)

-- Safe remote retrieval fallback
local toyEvent = (ctx and ctx.toyRemote) or ReplicatedStorage:FindFirstChild("ToyRemote") or ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ToyRemote")


--==================================================
-- GUI TRANSPARENCY STATE
--==================================================

local globalGuisTransparency = 0.1
local allStrokesAndElements = {}

local function updateAllGuisTransparency(val)
    globalGuisTransparency = val
    for _, item in ipairs(allStrokesAndElements) do
        if item and item.Parent then
            if item:IsA("UIStroke") then
                item.Transparency = val
            elseif item:IsA("TextButton") then
                item.TextTransparency = val
            end
        end
    end
end


--==================================================
-- GUI POSITION SAVING
--==================================================

local lockGuisPosition = false

local function getSavedSettings()

    local success, result = pcall(function()

        if readfile
            and isfile
            and isfile("ODH_GUI_Positions.json")
        then
            return HttpService:JSONDecode(
                readfile("ODH_GUI_Positions.json")
            )
        end

    end)

    local positions = {}

    if success and type(result) == "table" then

        for key, value in pairs(result) do

            if type(value) == "table" then

                local xs = tonumber(value[1])
                local xo = tonumber(value[2])
                local ys = tonumber(value[3])
                local yo = tonumber(value[4])

                if xs and xo and ys and yo then

                    positions[key] = UDim2.new(
                        xs,
                        xo,
                        ys,
                        yo
                    )

                end

            end

        end

    end

    return positions

end


local function saveSettings(settingsTbl)

    pcall(function()

        if writefile then

            local serialized = {}

            for key, value in pairs(settingsTbl) do

                if typeof(value) == "UDim2" then

                    serialized[key] = {
                        value.X.Scale,
                        value.X.Offset,
                        value.Y.Scale,
                        value.Y.Offset
                    }

                end

            end

            writefile(
                "ODH_GUI_Positions.json",
                HttpService:JSONEncode(serialized)
            )

        end

    end)

end


local guiPositions = getSavedSettings()


--==================================================
-- GLOBAL GUI COLOR
--==================================================

local currentGuiColor =
    Color3.fromRGB(255, 255, 255)

local strokesList = {}


local function updateAllStrokes(color)

    currentGuiColor = color

    for _, stroke in ipairs(strokesList) do

        if stroke and stroke.Parent then
            stroke.Color = color
        end

    end

end


trickshot_section:AddColorpicker(
    "GUI Border Color",
    Color3.fromRGB(255, 255, 255),
    function(color3rgb)
        updateAllStrokes(color3rgb)
    end
)


trickshot_section:AddToggle(
    "Lock All GUIs Positions",
    function(on)
        lockGuisPosition = on
    end
)


--==================================================
-- STRAFE / AUTOMATIC 360
--==================================================

local trickshotEnabled = false
local strafeEnabled = false
local strafeSpeed = 16
local spinSpeed = math.rad(15)
local spinning = false
local strafeDirection = 1


trickshot_section:AddToggle(
    "Enable Automatic 360 Trickshot",
    function(on)
        trickshotEnabled = on
    end
)


trickshot_section:AddToggle(
    "Enable Automatic Strafe",
    function(on)
        strafeEnabled = on
    end
)


trickshot_section:AddSlider(
    "Strafe Speed",
    4,
    32,
    strafeSpeed,
    function(v)
        strafeSpeed = v
    end
)


trickshot_section:AddSlider(
    "360 Spin Speed",
    1,
    50,
    math.deg(spinSpeed),
    function(v)
        spinSpeed = math.rad(v)
    end
)


--==================================================
-- JUMP BOOST
--==================================================

local jumpBoostEnabled = false
local jumpBoostGuiSize = 220
local humanoid
local jumpBoostActive = false
local originalJumpPower = 50

local screenGuiJump =
    CoreGui:FindFirstChild(
        "AutoJumpBoostDraggableGui"
    )

local frameJump
local buttonJump
local strokeJump

local defaultJumpPos =
    UDim2.new(1, -240, 1, -90)


if not screenGuiJump then

    screenGuiJump = Instance.new("ScreenGui")
    screenGuiJump.Name =
        "AutoJumpBoostDraggableGui"

    screenGuiJump.ResetOnSpawn = false
    screenGuiJump.Enabled = false
    screenGuiJump.Parent = CoreGui

    frameJump = Instance.new("Frame")

    frameJump.Size =
        UDim2.new(
            0,
            jumpBoostGuiSize,
            0,
            jumpBoostGuiSize
        )

    frameJump.Position =
        guiPositions.JumpPos
        or defaultJumpPos

    frameJump.BackgroundTransparency = 1
    frameJump.Parent = screenGuiJump

    local corner = Instance.new("UICorner")
    corner.CornerRadius =
        UDim.new(0, 16)
    corner.Parent = frameJump

    strokeJump = Instance.new("UIStroke")
    strokeJump.Color =
        currentGuiColor

    strokeJump.Thickness = 3.5
    strokeJump.Transparency = globalGuisTransparency
    strokeJump.Parent = frameJump

    table.insert(
        strokesList,
        strokeJump
    )
    table.insert(allStrokesAndElements, strokeJump)

    buttonJump = Instance.new("TextButton")

    buttonJump.Size =
        UDim2.new(1, 0, 1, 0)

    buttonJump.BackgroundTransparency = 1
    buttonJump.Text =
        "Jump Boost (OFF)"

    buttonJump.TextColor3 =
        Color3.fromRGB(
            255,
            255,
            255
        )

    buttonJump.TextTransparency = globalGuisTransparency

    buttonJump.TextSize =
        math.clamp(
            math.floor(
                jumpBoostGuiSize / 12
            ),
            10,
            36
        )

    buttonJump.Font =
        Enum.Font.GothamBold

    buttonJump.Parent =
        frameJump
    table.insert(allStrokesAndElements, buttonJump)

else

    frameJump =
        screenGuiJump:FindFirstChildOfClass(
            "Frame"
        )

    strokeJump =
        frameJump
        and frameJump:FindFirstChildOfClass(
            "UIStroke"
        )

    if strokeJump then
        table.insert(
            strokesList,
            strokeJump
        )
        table.insert(allStrokesAndElements, strokeJump)
    end

    buttonJump =
        frameJump
        and frameJump:FindFirstChildOfClass(
            "TextButton"
        )
    if buttonJump then
        table.insert(allStrokesAndElements, buttonJump)
    end

end


local draggingJump = false
local dragInputJump
local dragStartJump
local startPosJump
local movedJump = false


if buttonJump and frameJump then

    buttonJump.InputBegan:Connect(function(input)

        if
            input.UserInputType
                == Enum.UserInputType.Touch

            or input.UserInputType
                == Enum.UserInputType.MouseButton1
        then

            if not lockGuisPosition then

                draggingJump = true
                movedJump = false

                dragStartJump =
                    input.Position

                startPosJump =
                    frameJump.Position

                local connection

                connection =
                    input.Changed:Connect(
                        function()

                            if
                                input.UserInputState
                                    == Enum.UserInputState.End
                            then

                                draggingJump = false

                                if connection then
                                    connection:Disconnect()
                                end

                                guiPositions.JumpPos =
                                    frameJump.Position

                                saveSettings(
                                    guiPositions
                                )

                            end

                        end
                    )

            else

                movedJump = false

            end

        end

    end)


    buttonJump.InputChanged:Connect(function(input)

        if lockGuisPosition then
            return
        end

        if
            input.UserInputType
                == Enum.UserInputType.Touch

            or input.UserInputType
                == Enum.UserInputType.MouseMovement
        then

            dragInputJump = input

        end

    end)


    UIS.InputChanged:Connect(function(input)

        if lockGuisPosition then
            return
        end

        if
            input == dragInputJump
            and draggingJump
        then

            local delta =
                input.Position
                - dragStartJump

            if
                math.abs(delta.X) > 5
                or math.abs(delta.Y) > 5
            then
                movedJump = true
            end

            frameJump.Position =
                UDim2.new(
                    startPosJump.X.Scale,
                    startPosJump.X.Offset
                        + delta.X,

                    startPosJump.Y.Scale,
                    startPosJump.Y.Offset
                        + delta.Y
                )

        end

    end)


    buttonJump.Activated:Connect(function()

        if movedJump then
            return
        end

        jumpBoostActive =
            not jumpBoostActive


        if jumpBoostActive then

            buttonJump.Text = "Ready"

            buttonJump.TextColor3 =
                Color3.fromRGB(
                    50,
                    255,
                    50
                )

            if strokeJump then
                strokeJump.Color =
                    Color3.fromRGB(
                        50,
                        200,
                        50
                    )
            end

            if humanoid then

                originalJumpPower =
                    humanoid.JumpPower

                humanoid.JumpPower = 125

            end

        else

            buttonJump.Text =
                "Jump Boost (OFF)"

            buttonJump.TextColor3 =
                Color3.fromRGB(
                    255,
                    255,
                    255
                )

            if strokeJump then
                strokeJump.Color =
                    currentGuiColor
            end

            if humanoid then
                humanoid.JumpPower =
                    originalJumpPower
            end

        end

    end)

end


local function setupHumanoid(h)

    humanoid = h

    if not jumpBoostActive then
        originalJumpPower =
            h.JumpPower
    else
        h.JumpPower = 125
    end

    h:GetPropertyChangedSignal("Jump"):Connect(
        function()

            if
                jumpBoostActive
                and h.Jump
            then

                task.wait(0.1)

                jumpBoostActive = false

                if buttonJump then

                    buttonJump.Text =
                        "Jump Boost (OFF)"

                    buttonJump.TextColor3 =
                        Color3.fromRGB(
                            255,
                            255,
                            255
                        )

                end

                if strokeJump then
                    strokeJump.Color =
                        currentGuiColor
                end

                if humanoid then
                    humanoid.JumpPower =
                        originalJumpPower
                end

            end

        end
    )

end


if
    LocalPlayer.Character
    and LocalPlayer.Character:FindFirstChild(
        "Humanoid"
    )
then

    setupHumanoid(
        LocalPlayer.Character.Humanoid
    )

end


LocalPlayer.CharacterAdded:Connect(function(char)

    setupHumanoid(
        char:WaitForChild(
            "Humanoid"
        )
    )

end)


trickshot_section:AddToggle(
    "Enable Jump Boost Button",
    function(on)

        jumpBoostEnabled = on

        if screenGuiJump then

            screenGuiJump.Enabled = on

            if on and frameJump then

                frameJump.Position =
                    guiPositions.JumpPos
                    or defaultJumpPos

            end

        end


        if not on and frameJump then

            frameJump.Position =
                defaultJumpPos

            guiPositions.JumpPos =
                defaultJumpPos

            saveSettings(
                guiPositions
            )

        end


        if not on and jumpBoostActive then

            jumpBoostActive = false

            if buttonJump then

                buttonJump.Text =
                    "Jump Boost (OFF)"

                buttonJump.TextColor3 =
                    Color3.fromRGB(
                        255,
                        255,
                        255
                    )

            end

            if strokeJump then
                strokeJump.Color =
                    currentGuiColor
            end

            if humanoid then
                humanoid.JumpPower =
                    originalJumpPower
            end

        end

    end
)


trickshot_section:AddSlider(
    "Jump Boost GUI Size",
    50,
    300,
    jumpBoostGuiSize,
    function(v)

        jumpBoostGuiSize = v

        if frameJump then

            frameJump.Size =
                UDim2.new(
                    0,
                    jumpBoostGuiSize,
                    0,
                    jumpBoostGuiSize
                )

        end

        if buttonJump then

            buttonJump.TextSize =
                math.clamp(
                    math.floor(
                        jumpBoostGuiSize / 12
                    ),
                    10,
                    36
                )

        end

    end
)


--==================================================
-- AUTOMATIC STRAFE / 360
--==================================================

RunService.RenderStepped:Connect(function(delta)

    local char =
        LocalPlayer.Character

    if not char then
        return
    end

    local HRP =
        char:FindFirstChild(
            "HumanoidRootPart"
        )

    local h =
        char:FindFirstChildOfClass(
            "Humanoid"
        )

    if not HRP or not h then
        return
    end


    if strafeEnabled then

        local moveVec =
            HRP.CFrame.RightVector
            * strafeDirection

        HRP.CFrame =
            HRP.CFrame
            + moveVec.Unit
            * strafeSpeed
            * delta

        strafeDirection =
            (tick() % 1 < 0.5)
            and 1
            or -1

    end


    if trickshotEnabled then

        local state =
            h:GetState()

        if
            state
                == Enum.HumanoidStateType.Freefall
        then

            spinning = true

        elseif
            spinning
            and state
                == Enum.HumanoidStateType.Landed
        then

            spinning = false

        end


        if spinning then

            HRP.CFrame =
                HRP.CFrame
                * CFrame.Angles(
                    0,
                    spinSpeed,
                    0
                )

        end

    end

end)


--==================================================
-- WALLHOP
--==================================================

local wallhopEnabled = false
local backToNormalEnabled = false
local selectedLookDirection = "Back"
local InfiniteJumpEnabled = true

local wallRaycastParams =
    RaycastParams.new()

wallRaycastParams.FilterType =
    Enum.RaycastFilterType.Exclude


local function performWallhop()

    local character =
        LocalPlayer.Character

    if not character then
        return
    end

    local hrp =
        character:FindFirstChild(
            "HumanoidRootPart"
        )

    local h =
        character:FindFirstChildOfClass(
            "Humanoid"
        )

    if
        not hrp
        or not h
        or h:GetState()
            == Enum.HumanoidStateType.Dead
    then
        return
    end

    wallRaycastParams.FilterDescendantsInstances =
        {
            character
        }

    local res =
        Workspace:Raycast(
            hrp.Position,
            hrp.CFrame.LookVector * 3,
            wallRaycastParams
        )

    if res then

        InfiniteJumpEnabled = false

        h:ChangeState(
            Enum.HumanoidStateType.Jumping
        )

        if backToNormalEnabled then

            local rotAngle = math.pi

            if selectedLookDirection
                == "Right"
            then

                rotAngle =
                    -math.pi / 2

            elseif selectedLookDirection
                == "Left"
            then

                rotAngle =
                    math.pi / 2

            end

            hrp.CFrame =
                hrp.CFrame
                * CFrame.Angles(
                    0,
                    rotAngle,
                    0
                )

            task.wait(0.15)

            hrp.CFrame =
                hrp.CFrame
                * CFrame.Angles(
                    0,
                    (
                        selectedLookDirection
                            == "Back"
                        and math.pi

                        or selectedLookDirection
                            == "Right"
                        and math.pi / 2

                        or -math.pi / 2
                    ),
                    0
                )

        else

            hrp.CFrame =
                hrp.CFrame
                * CFrame.Angles(
                    0,
                    -1,
                    0
                )

            task.wait(0.1)

            hrp.CFrame =
                hrp.CFrame
                * CFrame.Angles(
                    0,
                    1,
                    0
                )

        end

        task.wait(0.1)

        InfiniteJumpEnabled = true

    end

end


trickshot_section:AddToggle(
    "Enable Wallhop",
    function(on)
        wallhopEnabled = on
    end
)


trickshot_section:AddToggle(
    "Back To Normal position after jump",
    function(on)
        backToNormalEnabled = on
    end
)


trickshot_section:AddDropdown(
    "Wallhop Look Direction",
    {
        "Back",
        "Right",
        "Left"
    },
    function(sel)
        selectedLookDirection = sel
    end
)


trickshot_section:AddKeybind(
    "Wallhop Jump Key",
    "J",
    performWallhop
)


UIS.JumpRequest:Connect(function()

    if
        wallhopEnabled
        and InfiniteJumpEnabled
    then
        performWallhop()
    end

end)


--==================================================
-- TOYS (FIXED AUTO-SPAWN RESPAWN)
--==================================================

local finalToyEventRef = toyEvent

local autoSpawnToysEnabled = false
local selectedToy1 = "None"
local selectedToy2 = "None"

local availableToysList = {
    "None"
}


local function getToysFolder()
    local bp = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
    if not bp then return nil end
    return bp:FindFirstChild("Toys") or bp:WaitForChild("Toys", 2)
end


local function updateAvailableToys()
    local toysFolder = getToysFolder()
    local list = { "None" }

    if toysFolder then
        for _, toy in ipairs(toysFolder:GetChildren()) do
            table.insert(list, toy.Name)
        end
    end

    availableToysList = list
end


updateAvailableToys()


local function spawnSelectedToys()
    if not autoSpawnToysEnabled or not finalToyEventRef then
        return
    end

    task.spawn(function()
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        char:WaitForChild("Humanoid", 5)

        local toysFolder = nil
        local startTime = tick()
        while tick() - startTime < 3 do
            toysFolder = getToysFolder()
            if toysFolder and #toysFolder:GetChildren() > 0 then
                break
            end
            task.wait(0.2)
        end

        task.wait(0.5)

        if selectedToy1 and selectedToy1 ~= "None" then
            pcall(function()
                finalToyEventRef:InvokeServer(selectedToy1)
            end)
            task.wait(0.4)
        end

        if selectedToy2 and selectedToy2 ~= "None" then
            pcall(function()
                finalToyEventRef:InvokeServer(selectedToy2)
            end)
        end
    end)
end


LocalPlayer.CharacterAdded:Connect(function(newChar)
    task.spawn(spawnSelectedToys)
end)


trickshot_section:AddToggle(
    "Auto Spawn Toys On Respawn",
    function(on)
        autoSpawnToysEnabled = on

        if on then
            updateAvailableToys()
            spawnSelectedToys()
        end
    end
)


trickshot_section:AddDropdown(
    "Select Toy Slot 1",
    availableToysList,
    function(sel)
        selectedToy1 = sel
    end
)


trickshot_section:AddDropdown(
    "Select Toy Slot 2",
    availableToysList,
    function(sel)
        selectedToy2 = sel
    end
)


--==================================================
-- BOMB JUMP
--==================================================

local screenGuiBomb =
    CoreGui:FindFirstChild(
        "AutoSequenceJumpDraggableGui"
    )

local frameBomb
local buttonBomb
local strokeBomb

local bombJumpGuiSize = 220
local showBombJumpGui = false

local bombUseMode =
    "Toggle To Use Bomb"

local selectedBombType = "Bomb"

-- Hides the GUI cooldown display completely.
local noGuiTimerBomb = false

-- Bomb sequence delay.
local BOMB_ACTION_DELAY = 0.1

local defaultBombPos =
    UDim2.new(
        1,
        -240,
        1,
        -210
    )


if not screenGuiBomb then

    screenGuiBomb =
        Instance.new(
            "ScreenGui"
        )

    screenGuiBomb.Name =
        "AutoSequenceJumpDraggableGui"

    screenGuiBomb.ResetOnSpawn = false
    screenGuiBomb.Enabled = false
    screenGuiBomb.Parent = CoreGui

    frameBomb =
        Instance.new(
            "Frame"
        )

    frameBomb.Size =
        UDim2.new(
            0,
            bombJumpGuiSize,
            0,
            bombJumpGuiSize
                * (100 / 220)
        )

    frameBomb.Position =
        guiPositions.BombPos
        or defaultBombPos

    frameBomb.BackgroundTransparency = 1
    frameBomb.Parent =
        screenGuiBomb

    local corner =
        Instance.new(
            "UICorner"
        )

    corner.CornerRadius =
        UDim.new(
            0,
            22
        )

    corner.Parent =
        frameBomb

    strokeBomb =
        Instance.new(
            "UIStroke"
        )

    strokeBomb.Color =
        currentGuiColor

    strokeBomb.Thickness = 3.5
    strokeBomb.Transparency = globalGuisTransparency
    strokeBomb.Parent =
        frameBomb

    table.insert(
        strokesList,
        strokeBomb
    )
    table.insert(allStrokesAndElements, strokeBomb)

    buttonBomb =
        Instance.new(
            "TextButton"
        )

    buttonBomb.Size =
        UDim2.new(
            1,
            0,
            1,
            0
        )

    buttonBomb.BackgroundTransparency = 1

    buttonBomb.Text =
        "Bomb Jump (OFF)"

    buttonBomb.TextColor3 =
        Color3.fromRGB(
            255,
            255,
            255
        )

    buttonBomb.TextTransparency = globalGuisTransparency

    buttonBomb.TextSize =
        math.clamp(
            math.floor(
                bombJumpGuiSize / 12
            ),
            9,
            28
        )

    buttonBomb.Font =
        Enum.Font.GothamBold

    buttonBomb.Parent =
        frameBomb
    table.insert(allStrokesAndElements, buttonBomb)

else

    frameBomb =
        screenGuiBomb:FindFirstChildOfClass(
            "Frame"
        )

    strokeBomb =
        frameJump
        and frameJump:FindFirstChildOfClass(
            "UIStroke"
        )

    if strokeBomb then
        table.insert(
            strokesList,
            strokeBomb
        )
        table.insert(allStrokesAndElements, strokeBomb)
    end

    buttonBomb =
        frameBomb
        and frameBomb:FindFirstChildOfClass(
            "TextButton"
        )
    if buttonBomb then
        table.insert(allStrokesAndElements, buttonBomb)
    end

end


local isActiveBomb = false
local hasTriggeredBomb = false
local isWaitingTimerBomb = false
local timerTokenBomb = 0

local draggingBomb = false
local dragInputBomb
local dragStartBomb
local startPosBomb
local movedBomb = false


if buttonBomb and frameBomb then

    buttonBomb.InputBegan:Connect(function(input)

        if
            input.UserInputType
                == Enum.UserInputType.Touch

            or input.UserInputType
                == Enum.UserInputType.MouseButton1
        then

            if not lockGuisPosition then

                draggingBomb = true
                movedBomb = false

                dragStartBomb =
                    input.Position

                startPosBomb =
                    frameBomb.Position

                local connection

                connection =
                    input.Changed:Connect(
                        function()

                            if
                                input.UserInputState
                                    == Enum.UserInputState.End
                            then

                                draggingBomb = false

                                if connection then
                                    connection:Disconnect()
                                end

                                guiPositions.BombPos =
                                    frameBomb.Position

                                saveSettings(
                                    guiPositions
                                )

                            end

                        end
                    )

            else

                movedBomb = false

            end

        end

    end)


    buttonBomb.InputChanged:Connect(function(input)

        if lockGuisPosition then
            return
        end

        if
            input.UserInputType
                == Enum.UserInputType.Touch

            or input.UserInputType
                == Enum.UserInputType.MouseMovement
        then

            dragInputBomb = input

        end

    end)


    UIS.InputChanged:Connect(function(input)

        if lockGuisPosition then
            return
        end

        if
            input == dragInputBomb
            and draggingBomb
        then

            local delta =
                input.Position
                - dragStartBomb

            if
                math.abs(delta.X) > 5
                or math.abs(delta.Y) > 5
            then
                movedBomb = true
            end

            frameBomb.Position =
                UDim2.new(
                    startPosBomb.X.Scale,
                    startPosBomb.X.Offset
                        + delta.X,

                    startPosBomb.Y.Scale,
                    startPosBomb.Y.Offset
                        + delta.Y
                )

        end

    end)

end


local function getBombToolName()

    return selectedBombType
        == "Gold Bomb"
        and "GoldBomb"
        or "FakeBomb"

end


--==================================================
-- BOMB JUMP ACTION
--==================================================

local function executeBombJumpAction(
    isToggleMode
)

    if isWaitingTimerBomb then
        return
    end

    local character =
        LocalPlayer.Character

    if not character then
        return
    end

    local h =
        character:FindFirstChildOfClass(
            "Humanoid"
        )

    local rootPart =
        character:FindFirstChild(
            "HumanoidRootPart"
        )

    if
        not h
        or not rootPart
        or not strokeBomb
        or not buttonBomb
    then
        return
    end

    hasTriggeredBomb = true
    isActiveBomb = false


    task.spawn(function()

        local toolName =
            getBombToolName()

        local backpack =
            LocalPlayer:FindFirstChild(
                "Backpack"
            )

        local tool =
            character:FindFirstChild(
                toolName
            )
            or (
                backpack
                and backpack:FindFirstChild(
                    toolName
                )
            )


        --==================================================
        -- TOGGLE TO USE BOMB
        --==================================================

        if isToggleMode then

            -- FIRST JUMP
            h:ChangeState(
                Enum.HumanoidStateType.Jumping
            )

            h.Jump = true

            task.wait(
                BOMB_ACTION_DELAY
            )


            if tool then

                -- EQUIP
                if tool.Parent == backpack then

                    pcall(function()
                        h:EquipTool(tool)
                    end)

                end

                task.wait(
                    BOMB_ACTION_DELAY
                )


                -- USE
                if toyEvent then
                    pcall(function()
                        toyEvent:InvokeServer(
                            toolName
                        )
                    end)
                end

                pcall(function()
                    tool:Activate()
                end)

                pcall(function()

                    local vu =
                        game:GetService(
                            "VirtualUser"
                        )

                    vu:Button1Down(
                        Vector2.zero
                    )

                    vu:Button1Up(
                        Vector2.zero
                    )

                end)

                task.wait(
                    BOMB_ACTION_DELAY
                )

            end


            -- SECOND JUMP
            h:ChangeState(
                Enum.HumanoidStateType.Jumping
            )

            h.Jump = true

            task.wait(
                BOMB_ACTION_DELAY
            )


            -- UNEQUIP
            if
                tool
                and tool.Parent == character
            then

                pcall(function()
                    h:UnequipTools()
                end)

                if
                    tool.Parent == character
                    and backpack
                then

                    pcall(function()
                        tool.Parent = backpack
                    end)

                end

            end


        --==================================================
        -- CLICK TO USE BOMB
        --==================================================

        else

            if not tool then
                return
            end


            -- EQUIP
            if tool.Parent == backpack then

                pcall(function()
                    h:EquipTool(tool)
                end)

            end


            task.wait(
                BOMB_ACTION_DELAY
            )


            -- USE
            if toyEvent then
                pcall(function()
                    toyEvent:InvokeServer(
                        toolName
                    )
                end)
            end

            pcall(function()
                tool:Activate()
            end)

            pcall(function()

                local vu =
                    game:GetService(
                        "VirtualUser"
                    )

                vu:Button1Down(
                    Vector2.zero
                )

                vu:Button1Up(
                    Vector2.zero
                )

            end)


            -- JUMP
            h:ChangeState(
                Enum.HumanoidStateType.Jumping
            )

            h.Jump = true


            task.wait(
                BOMB_ACTION_DELAY
            )


            -- UNEQUIP
            if
                tool.Parent == character
            then

                pcall(function()
                    h:UnequipTools()
                end)

                if
                    tool.Parent == character
                    and backpack
                then

                    pcall(function()
                        tool.Parent = backpack
                    end)

                end

            end

        end


        --==================================================
        -- GUI COOLDOWN / NO TIMER CHECK (Optimized)
        --==================================================

        isWaitingTimerBomb = true

        if not noGuiTimerBomb then

            if strokeBomb then
                strokeBomb.Color =
                    Color3.fromRGB(
                        255,
                        0,
                        0
                    )
            end

        end


        local currentToken =
            timerTokenBomb

        local waitTime =
            selectedBombType
                == "Gold Bomb"
            and 3.2
            or 21.7

        local startTime =
            tick()


        while true do

            if
                timerTokenBomb
                    ~= currentToken
            then
                return
            end

            local elapsed =
                tick()
                - startTime

            local remaining =
                waitTime
                - elapsed

            if remaining <= 0 then
                break
            end


            if not noGuiTimerBomb then

                if buttonBomb then

                    buttonBomb.Text =
                        string.format(
                            "Wait (%.1fs)",
                            remaining
                        )

                    buttonBomb.TextColor3 =
                        Color3.fromRGB(
                            255,
                            0,
                            0
                        )

                end
                task.wait(0.05)
            else
                break
            end

        end


        if
            timerTokenBomb
                ~= currentToken
        then
            return
        end

        isWaitingTimerBomb = false
        hasTriggeredBomb = false

        if buttonBomb then

            buttonBomb.Text =
                bombUseMode
                    == "Toggle To Use Bomb"
                and "Bomb Jump (OFF)"
                or "Bomb Jump"

            buttonBomb.TextColor3 =
                Color3.fromRGB(
                    255,
                    255,
                    255
                )

        end

        if strokeBomb then
            strokeBomb.Color =
                currentGuiColor
        end

    end)

end


--==================================================
-- BOMB GUI BUTTON
--==================================================

if buttonBomb then

    buttonBomb.Activated:Connect(
        function()

            if
                movedBomb
                or isWaitingTimerBomb
            then
                return
            end


            local toolName =
                getBombToolName()


            if bombUseMode
                == "Toggle To Use Bomb"
            then

                isActiveBomb =
                    not isActiveBomb


                if buttonBomb then

                    buttonBomb.Text =
                        isActiveBomb
                        and "Ready"
                        or "Bomb Jump (OFF)"

                    buttonBomb.TextColor3 =
                        isActiveBomb
                        and Color3.fromRGB(
                            50,
                            255,
                            50
                        )
                        or Color3.fromRGB(
                            255,
                            255,
                            255
                        )

                end


                if strokeBomb then

                    strokeBomb.Color =
                        isActiveBomb
                        and Color3.fromRGB(
                            50,
                            200,
                            50
                        )
                        or currentGuiColor

                end


                hasTriggeredBomb = false


                if isActiveBomb and toyEvent then

                    pcall(function()

                        toyEvent:InvokeServer(
                            toolName
                        )

                    end)

                end


            elseif bombUseMode
                == "Click To Use Bomb"
            then

                executeBombJumpAction(
                    false
                )

            end

        end
    )

end


--==================================================
-- BOMB CHARACTER SETUP
--==================================================

local function setupCharacterBomb(
    character
)

    local h =
        character:WaitForChild(
            "Humanoid"
        )

    timerTokenBomb =
        timerTokenBomb + 1

    isWaitingTimerBomb = false
    hasTriggeredBomb = false

    if buttonBomb and strokeBomb then

        buttonBomb.Text =
            (
                bombUseMode
                    == "Toggle To Use Bomb"
                and not isActiveBomb
            )
            and "Bomb Jump (OFF)"
            or "Bomb Jump"

        buttonBomb.TextColor3 =
            Color3.fromRGB(
                255,
                255,
                255
            )

        strokeBomb.Color =
            currentGuiColor

    end


    h.StateChanged:Connect(
        function(
            oldState,
            newState
        )

            if
                bombUseMode
                    ~= "Toggle To Use Bomb"

                or not isActiveBomb

                or hasTriggeredBomb

                or isWaitingTimerBomb
            then
                return
            end


            if
                newState
                    == Enum.HumanoidStateType.Jumping
            then

                executeBombJumpAction(
                    true
                )

            elseif
                newState
                    == Enum.HumanoidStateType.Landed
                and not isWaitingTimerBomb
            then

                hasTriggeredBomb = false

            end

        end
    )

end


if LocalPlayer.Character then

    setupCharacterBomb(
        LocalPlayer.Character
    )

end


LocalPlayer.CharacterAdded:Connect(
    setupCharacterBomb
)


--==================================================
-- SHOW BOMB JUMP GUI
--==================================================

trickshot_section:AddToggle(
    "Show Bomb Jump Button",
    function(on)

        showBombJumpGui = on

        if screenGuiBomb then

            screenGuiBomb.Enabled = on

            if on and frameBomb then

                frameBomb.Position =
                    guiPositions.BombPos
                    or defaultBombPos

            end

        end


        if not on and frameBomb then

            frameBomb.Position =
                defaultBombPos

            guiPositions.BombPos =
                defaultJumpPos

            saveSettings(
                guiPositions
            )

        end

    end
)


--==================================================
-- BOMB TYPE
--==================================================

trickshot_section:AddDropdown(
    "Choose Bomb Type",
    {
        "Bomb",
        "Gold Bomb"
    },
    function(sel)

        selectedBombType = sel

        isActiveBomb = false
        hasTriggeredBomb = false

    end
)


--==================================================
-- BOMB USAGE MODE
--==================================================

trickshot_section:AddDropdown(
    "Bomb Usage Mode",
    {
        "Toggle To Use Bomb",
        "Click To Use Bomb"
    },
    function(sel)

        bombUseMode = sel

        isActiveBomb = false
        hasTriggeredBomb = false

        if
            not isWaitingTimerBomb
            and buttonBomb
            and strokeBomb
        then

            buttonBomb.Text =
                bombUseMode
                    == "Toggle To Use Bomb"
                and "Bomb Jump (OFF)"
                or "Bomb Jump"

            buttonBomb.TextColor3 =
                Color3.fromRGB(
                    255,
                    255,
                    255
                )

            strokeBomb.Color =
                currentGuiColor

        end

    end
)


--==================================================
-- NO GUI TIMER
--==================================================

trickshot_section:AddToggle(
    "No GUI Timer ( Not Recommended )",
    function(on)

        noGuiTimerBomb = on

        if on and isWaitingTimerBomb then

            if buttonBomb then

                buttonBomb.Text =
                    bombUseMode
                        == "Toggle To Use Bomb"
                    and "Bomb Jump (OFF)"
                    or "Bomb Jump"

                buttonBomb.TextColor3 =
                    Color3.fromRGB(
                        255,
                        255,
                        255
                    )

            end

            if strokeBomb then
                strokeBomb.Color =
                    currentGuiColor
            end

        end

    end
)


--==================================================
-- BOMB JUMP KEYBIND
--==================================================

trickshot_section:AddKeybind(
    "Bomb Jump Keybind",
    "B",
    function()

        if isWaitingTimerBomb then
            return
        end


        if bombUseMode
            == "Toggle To Use Bomb"
        then

            isActiveBomb = true
            hasTriggeredBomb = false

            if buttonBomb then

                buttonBomb.Text =
                    "Ready"

                buttonBomb.TextColor3 =
                    Color3.fromRGB(
                        50,
                        255,
                        50
                    )

            end


            if strokeBomb then

                strokeBomb.Color =
                    Color3.fromRGB(
                        50,
                        200,
                        50
                    )

            end


            executeBombJumpAction(true)

        else

            executeBombJumpAction(
                false
            )

        end

    end
)


--==================================================
-- BOMB GUI SIZE
--==================================================

trickshot_section:AddSlider(
    "Bomb Jump GUI Size",
    50,
    300,
    bombJumpGuiSize,
    function(v)

        bombJumpGuiSize = v

        if frameBomb then

            frameBomb.Size =
                UDim2.new(
                    0,
                    bombJumpGuiSize,
                    0,
                    bombJumpGuiSize
                        * (100 / 220)
                )

        end

        if buttonBomb then

            buttonBomb.TextSize =
                math.clamp(
                    math.floor(
                        bombJumpGuiSize / 12
                    ),
                    9,
                    28
                )

        end

    end
)


--==================================================
-- FLICK / TRICKSHOT GUI
--==================================================

local flickGui =
    CoreGui:FindFirstChild(
        "AutoFlickShootDraggableGui"
    )

local flickFrame
local flickButton
local flickStroke

local flickGuiSize = 220
local showFlickGui = false

local flickReloading = false

local FLICK_RELOAD_TIME = 2.7

local flickWallCheckEnabled = false
local flickMode = "Smooth"
local smoothTrickshotSpeed = 10 
local instantTrickshotSpeed = 0.01 
local whitelistFriendsEnabled = false

local selectedTrickShotType =
    "Flick Shoot"

local defaultFlickPos =
    UDim2.new(
        1,
        -240,
        1,
        -330
    )


--==================================================
-- FLICK GUI CREATE / REUSE
--==================================================

if not flickGui then

    flickGui =
        Instance.new(
            "ScreenGui"
        )

    flickGui.Name =
        "AutoFlickShootDraggableGui"

    flickGui.ResetOnSpawn = false
    flickGui.Enabled = false
    flickGui.Parent = CoreGui

    flickFrame =
        Instance.new(
            "Frame"
        )

    flickFrame.Name =
        "FlickFrame"

    flickFrame.Size =
        UDim2.new(
            0,
            flickGuiSize,
            0,
            flickGuiSize
                * (100 / 220)
        )

    flickFrame.Position =
        guiPositions.FlickPos
        or defaultFlickPos

    flickFrame.BackgroundTransparency = 1
    flickFrame.Parent = flickGui

    local corner =
        Instance.new(
            "UICorner"
        )

    corner.CornerRadius =
        UDim.new(
            0,
            22
        )

    corner.Parent =
        flickFrame

    flickStroke =
        Instance.new(
            "UIStroke"
        )

    flickStroke.Color =
        currentGuiColor

    flickStroke.Thickness = 3.5
    flickStroke.Transparency = globalGuisTransparency
    flickStroke.Parent =
        flickFrame

    table.insert(
        strokesList,
        flickStroke
    )
    table.insert(allStrokesAndElements, flickStroke)

    flickButton =
        Instance.new(
            "TextButton"
        )

    flickButton.Name =
        "FlickButton"

    flickButton.Size =
        UDim2.new(
            1,
            0,
            1,
            0
        )

    flickButton.BackgroundTransparency = 1

    flickButton.Text =
        "Flick Shoot"

    flickButton.TextColor3 =
        Color3.fromRGB(
            255,
            255,
            255
        )

    flickButton.TextTransparency = globalGuisTransparency

    flickButton.TextSize =
        math.clamp(
            math.floor(
                flickGuiSize / 12
            ),
            9,
            28
        )

    flickButton.Font =
        Enum.Font.GothamBold

    flickButton.Parent =
        flickFrame
    table.insert(allStrokesAndElements, flickButton)

else

    flickFrame =
        flickGui:FindFirstChild(
            "FlickFrame"
        )
        or flickGui:FindFirstChildOfClass(
            "Frame"
        )

    if flickFrame then

        flickStroke =
            flickFrame:FindFirstChildOfClass(
                "UIStroke"
            )

        if flickStroke then
            table.insert(
                strokesList,
                flickStroke
            )
            table.insert(allStrokesAndElements, flickStroke)
        end

        flickButton =
            flickFrame:FindFirstChild(
                "FlickButton"
            )
            or flickFrame:FindFirstChildOfClass(
                "TextButton"
            )
        if flickButton then
            table.insert(allStrokesAndElements, flickButton)
        end

    end

end


--==================================================
-- MURDERER DETECTION
--==================================================

local function hasMurdererTool(plr)

    if not plr then
        return false
    end

    local character =
        plr.Character

    local backpack =
        plr:FindFirstChild(
            "Backpack"
        )


    local function checkContainer(container)

        if not container then
            return false
        end

        if
            container:FindFirstChild("Knife")
            or container:FindFirstChild("Knife_Local")
        then
            return true
        end

        return false

    end


    if checkContainer(character) then
        return true
    end

    if checkContainer(backpack) then
        return true
    end

    return false

end


local function isMurderer(plr)

    if
        not plr
        or plr == LocalPlayer
    then
        return false
    end


    local roleAttribute =
        plr:GetAttribute("Role")

    if
        type(roleAttribute) == "string"
        and string.lower(roleAttribute)
            == "murderer"
    then
        return true
    end


    local currentRole =
        plr:GetAttribute("CurrentRole")

    if
        type(currentRole) == "string"
        and string.lower(currentRole)
            == "murderer"
    then
        return true
    end


    if hasMurdererTool(plr) then
        return true
    end


    return false

end


--==================================================
-- FRIEND CHECK
--==================================================

local function isFriend(plr)

    if not plr then
        return false
    end

    if plr == LocalPlayer then
        return false
    end

    local success, result =
        pcall(function()

            return LocalPlayer:IsFriendsWith(
                plr.UserId
            )

        end)

    return success and result == true

end


--==================================================
-- WALL CHECK
--==================================================

local function hasClearTarget(
    targetPlayer
)

    if not flickWallCheckEnabled then
        return true
    end

    local localChar =
        LocalPlayer.Character

    if not localChar then
        return false
    end

    local localHrp =
        localChar:FindFirstChild(
            "HumanoidRootPart"
        )

    if not localHrp then
        return false
    end

    if
        not targetPlayer
        or not targetPlayer.Character
    then
        return false
    end

    local targetHrp =
        targetPlayer.Character:FindFirstChild(
            "HumanoidRootPart"
        )

    if not targetHrp then
        return false
    end

    local params =
        RaycastParams.new()

    params.FilterType =
        Enum.RaycastFilterType.Exclude

    params.FilterDescendantsInstances = {
        localChar,
        targetPlayer.Character
    }

    local direction =
        targetHrp.Position
        - localHrp.Position

    local result =
        Workspace:Raycast(
            localHrp.Position,
            direction,
            params
        )

    return result == nil

end


--==================================================
-- NEW MURDERER FINDER
--==================================================

local function findMurderer()

    local localChar =
        LocalPlayer.Character

    local localHrp =
        localChar
        and localChar:FindFirstChild(
            "HumanoidRootPart"
        )

    if not localHrp then
        return nil
    end


    for _, plr in ipairs(
        Players:GetPlayers()
    ) do

        if
            plr ~= LocalPlayer
            and isMurderer(plr)
        then

            local character =
                plr.Character

            local targetHrp =
                character
                and character:FindFirstChild(
                    "HumanoidRootPart"
                )

            local targetHumanoid =
                character
                and character:FindFirstChildOfClass(
                    "Humanoid"
                )

            if
                targetHrp
                and targetHumanoid
                and targetHumanoid.Health > 0
            then

                if hasClearTarget(plr) then
                    return plr
                end

            end

        end

    end

    return nil

end


--==================================================
-- FIRST PERSON
--==================================================

local function isFirstPerson()

    local camera =
        workspace.CurrentCamera

    local character =
        LocalPlayer.Character

    if
        not camera
        or not character
    then
        return false
    end

    local head =
        character:FindFirstChild(
            "Head"
        )

    if not head then
        return false
    end

    return (
        camera.CFrame.Position
        - head.Position
    ).Magnitude <= 1

end


--==================================================
-- SHIFTLOCK
--==================================================

local function isShiftlock()

    return UIS.MouseBehavior
        == Enum.MouseBehavior.LockCenter

end


--==================================================
-- CAMERA SNAP CHECK
--==================================================

local function shouldSnapCamera()

    return isFirstPerson()
        or isShiftlock()

end


--==================================================
-- SMOOTH FLICK
--==================================================

local function smoothFlick(
    hrp,
    humanoid,
    targetPosition,
    cam,
    useCamera
)

    if
        not hrp
        or not targetPosition
    then
        return
    end

    local curPos =
        hrp.Position

    local targetPos =
        Vector3.new(
            targetPosition.X,
            curPos.Y,
            targetPosition.Z
        )

    local dir =
        targetPos - curPos

    if dir.Magnitude <= 0.01 then
        return
    end

    dir = dir.Unit

    local targetHRPCFrame =
        CFrame.lookAt(
            curPos,
            curPos + dir
        )

    local speed =
        math.max(
            smoothTrickshotSpeed,
            1
        )

    local duration =
        math.clamp(
            0.28
                / speed
                * 10,
            0.08,
            0.35
        )


    if useCamera and cam then

        local targetCameraCFrame =
            CFrame.lookAt(
                cam.CFrame.Position,
                targetPosition
            )

        local startCameraCFrame =
            cam.CFrame

        local startTime =
            tick()

        while
            tick() - startTime
                < duration
        do

            if
                not cam
                or not cam.Parent
            then
                break
            end

            local alpha =
                math.clamp(
                    (
                        tick()
                        - startTime
                    )
                    / duration,
                    0,
                    1
                )

            alpha =
                alpha
                * alpha
                * (3 - 2 * alpha)

            cam.CFrame =
                startCameraCFrame:Lerp(
                    targetCameraCFrame,
                    alpha
                )

            RunService.RenderStepped:Wait()

        end

        if cam then
            cam.CFrame =
                targetCameraCFrame
        end

    else

        local startCFrame =
            hrp.CFrame

        local startTime =
            tick()

        while
            tick() - startTime
                < duration
        do

            if not hrp.Parent then
                break
            end

            local alpha =
                math.clamp(
                    (
                        tick()
                        - startTime
                    )
                    / duration,
                    0,
                    1
                )

            alpha =
                alpha
                * alpha
                * (3 - 2 * alpha)

            hrp.CFrame =
                startCFrame:Lerp(
                    targetHRPCFrame,
                    alpha
                )

            RunService.RenderStepped:Wait()

        end

        if hrp.Parent then
            hrp.CFrame =
                targetHRPCFrame
        end

    end

end


--==================================================
-- GUN FINDER
--==================================================

local function getGun()

    local character =
        LocalPlayer.Character

    if not character then
        return nil
    end

    local gun =
        character:FindFirstChild(
            "Gun"
        )

    if
        gun
        and gun:IsA("Tool")
    then
        return gun
    end


    local backpack =
        LocalPlayer:FindFirstChild(
            "Backpack"
        )

    if backpack then

        gun =
            backpack:FindFirstChild(
                "Gun"
            )

        if
            gun
            and gun:IsA("Tool")
        then
            return gun
        end

    end

    return nil

end


--==================================================
-- GUN EQUIP
--==================================================

local function equipGun()

    local character =
        LocalPlayer.Character

    if not character then
        return nil
    end

    local h =
        character:FindFirstChildOfClass(
            "Humanoid"
        )

    if not h then
        return nil
    end

    local backpack =
        LocalPlayer:FindFirstChild(
            "Backpack"
        )

    local gun =
        character:FindFirstChild(
            "Gun"
        )
        or (
            backpack
            and backpack:FindFirstChild(
                "Gun"
            )
        )

    if not gun then
        return nil
    end

    if gun.Parent == backpack then

        pcall(function()
            h:EquipTool(gun)
        end)

        task.wait()

    end

    if gun.Parent == character then
        return gun
    end

    return nil

end


--==================================================
-- SHOOT GUN
--==================================================

local function shootGun()

    local character =
        LocalPlayer.Character

    if not character then
        return false
    end

    local gun =
        character:FindFirstChild(
            "Gun"
        )

    if
        not gun
        or not gun:IsA("Tool")
    then
        return false
    end

    pcall(function()
        gun:Activate()
    end)

    pcall(function()

        local vu =
            game:GetService(
                "VirtualUser"
            )

        vu:Button1Down(
            Vector2.zero
        )

        vu:Button1Up(
            Vector2.zero
        )

    end)

    return true

end


--==================================================
-- RELOAD FUNCTION / NO TIMER CHECK (Optimized)
--==================================================

local function startReload()

    task.spawn(function()

        local startTime =
            tick()

        while
            tick() - startTime
                < FLICK_RELOAD_TIME
        do

            local remaining =
                FLICK_RELOAD_TIME
                - (
                    tick()
                    - startTime
                )

            if flickButton then
                if not noGuiTimerBomb then
                    flickButton.Text =
                        string.format(
                            "Wait (%.1fs)",
                            math.max(
                                remaining,
                                0
                            )
                        )

                    flickButton.TextColor3 =
                        Color3.fromRGB(
                            255,
                            0,
                            0
                        )
                    task.wait(0.05)
                else
                    flickButton.Text = selectedTrickShotType
                    flickButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                    break
                end
            else
                break
            end

        end


        flickReloading = false

        if flickButton then

            flickButton.Text =
                selectedTrickShotType

            flickButton.TextColor3 =
                Color3.fromRGB(
                    255,
                    255,
                    255
                )

        end

        if flickStroke then
            flickStroke.Color =
                currentGuiColor
        end

    end)

end


--==================================================
-- FLICK SHOOT METHOD
--==================================================

local function executeFlickShoot()

    if flickReloading then
        return
    end

    local char =
        LocalPlayer.Character

    if not char then
        return
    end

    local h, hrp =
        char:FindFirstChildOfClass(
            "Humanoid"
        ),
        char:FindFirstChild(
            "HumanoidRootPart"
        )

    if not h or not hrp then
        return
    end

    if h.Health <= 0 then
        return
    end


    local targetPlayer =
        findMurderer()


    if
        not targetPlayer
        or not targetPlayer.Character
    then

        if flickButton then

            flickButton.Text =
                flickWallCheckEnabled
                and "No Clear Target"
                or "No Murderer Found"

            flickButton.TextColor3 =
                Color3.fromRGB(
                    255,
                    80,
                    80
                )

            task.delay(
                1,
                function()

                    if
                        flickButton
                        and not flickReloading
                    then

                        flickButton.Text =
                            "Flick Shoot"

                        flickButton.TextColor3 =
                            Color3.fromRGB(
                                255,
                                255,
                                255
                            )

                    end

                end
            )

        end

        return

    end


    if
        whitelistFriendsEnabled
        and isFriend(targetPlayer)
    then

        if flickButton then

            flickButton.Text =
                "Friend Is Murderer"

            flickButton.TextColor3 =
                Color3.fromRGB(
                    255,
                    80,
                    80
                )

            task.delay(
                1,
                function()

                    if
                        flickButton
                        and not flickReloading
                    then

                        flickButton.Text =
                            "Flick Shoot"

                        flickButton.TextColor3 =
                            Color3.fromRGB(
                                255,
                                255,
                                255
                            )

                    end

                end
            )

        end

        return

    end


    local targetHrp =
        targetPlayer.Character:FindFirstChild(
            "HumanoidRootPart"
        )

    if not targetHrp then
        return
    end


    local backpack =
        LocalPlayer:FindFirstChild(
            "Backpack"
        )

    local gunTool =
        char:FindFirstChild("Gun")
        or (
            backpack
            and backpack:FindFirstChild("Gun")
        )


    if not gunTool then

        if flickButton then

            flickButton.Text =
                "No Gun Found"

            flickButton.TextColor3 =
                Color3.fromRGB(
                    255,
                    80,
                    80
                )

            task.delay(
                1,
                function()

                    if
                        flickButton
                        and not flickReloading
                    then

                        flickButton.Text =
                            "Flick Shoot"

                        flickButton.TextColor3 =
                            Color3.fromRGB(
                                255,
                                255,
                                255
                            )

                    end

                end
            )

        end

        return

    end


    if gunTool.Parent == backpack then

        h:EquipTool(
            gunTool
        )

        task.wait()

    end


    local origLook =
        hrp.CFrame.LookVector

    local cam =
        workspace.CurrentCamera

    local useCamera =
        shouldSnapCamera()

    local origCamCFrame =
        cam
        and useCamera
        and cam.CFrame
        or nil


    local curPos =
        hrp.Position

    local targetPos =
        Vector3.new(
            targetHrp.Position.X,
            hrp.Position.Y,
            targetHrp.Position.Z
        )

    local dir =
        targetPos - curPos


    if dir.Magnitude > 0.01 then

        dir = dir.Unit

        if flickMode == "Smooth" then

            smoothFlick(
                hrp,
                h,
                targetHrp.Position,
                cam,
                useCamera
            )

        else

            local startTime = tick()
            local duration = math.clamp(instantTrickshotSpeed, 0.01, 5)
            
            while tick() - startTime < duration do
                if not hrp.Parent or not targetHrp.Parent then break end
                
                local currentCurPos = hrp.Position
                local currentTargetPos = Vector3.new(targetHrp.Position.X, currentCurPos.Y, targetHrp.Position.Z)
                local currentDir = (currentTargetPos - currentCurPos)
                
                if currentDir.Magnitude > 0.01 then
                    hrp.CFrame = CFrame.lookAt(currentCurPos, currentCurPos + currentDir.Unit)
                    if cam and useCamera then
                        cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetHrp.Position)
                    end
                end
                RunService.RenderStepped:Wait()
            end

        end

    end


    gunTool:Activate()


    pcall(function()

        local vu =
            game:GetService(
                "VirtualUser"
            )

        vu:Button1Down(
            Vector2.zero
        )

        vu:Button1Up(
            Vector2.zero
        )

    end)


    task.wait(0.15)


    local restorePos =
        hrp.Position

    local flatLook =
        Vector3.new(
            origLook.X,
            0,
            origLook.Z
        )


    if flatLook.Magnitude > 0.01 then

        flatLook =
            flatLook.Unit

        hrp.CFrame =
            CFrame.lookAt(
                restorePos,
                restorePos + flatLook
            )

    end


    if
        cam
        and origCamCFrame
        and useCamera
    then

        cam.CFrame =
            origCamCFrame

    end


    if
        gunTool.Parent == char
    then

        gunTool.Parent =
            backpack

    end


    flickReloading = true

    if not noGuiTimerBomb then
        if flickStroke then

            flickStroke.Color =
                Color3.fromRGB(
                    255,
                    0,
                    0
                )

        end
    end

    task.spawn(
        startReload
    )

end


--==================================================
-- 360 SHOOT
--==================================================

local function execute360Shoot()

    if flickReloading then
        return
    end

    local character =
        LocalPlayer.Character

    if not character then
        return
    end

    local h =
        character:FindFirstChildOfClass(
            "Humanoid"
        )

    local hrp =
        character:FindFirstChild(
            "HumanoidRootPart"
        )

    if
        not h
        or not hrp
        or h.Health <= 0
    then
        return
    end


    local targetPlayer =
        findMurderer()

    if
        not targetPlayer
        or not targetPlayer.Character
    then

        if flickButton then

            flickButton.Text =
                flickWallCheckEnabled
                and "No Clear Target"
                or "No Murderer Found"

            task.delay(
                1,
                function()

                    if
                        flickButton
                        and not flickReloading
                    then
                        flickButton.Text =
                            "360 Shoot"
                    end

                end
            )

        end

        return

    end


    local target =
        targetPlayer.Character:FindFirstChild(
            "HumanoidRootPart"
        )

    if not target then
        return
    end


    local gun =
        equipGun()

    if not gun then

        if flickButton then

            flickButton.Text =
                "No Gun Found"

            task.delay(
                1,
                function()

                    if
                        flickButton
                        and not flickReloading
                    then
                        flickButton.Text =
                            "360 Shoot"
                    end

                end
            )

        end

        return

    end


    flickReloading = true

    if not noGuiTimerBomb then
        if flickStroke then
            flickStroke.Color =
                Color3.fromRGB(
                    255,
                    0,
                    0
                )
        end
    end


    local camera =
        workspace.CurrentCamera

    local useCamera =
        shouldSnapCamera()


    if
        useCamera
        and camera
    then

        local originalCameraCFrame =
            camera.CFrame

        local originalCameraType =
            camera.CameraType

        local originalCameraSubject =
            camera.CameraSubject

        camera.CameraType =
            Enum.CameraType.Scriptable


        local startPosition =
            originalCameraCFrame.Position

        local originalRotation =
            originalCameraCFrame
            - originalCameraCFrame.Position


        local speed =
            math.max(
                smoothTrickshotSpeed,
                1
            )

        local duration =
            math.clamp(
                1.1 / speed,
                0.08,
                1.1
            )

        local startTime =
            tick()


        while
            tick() - startTime
                < duration
        do

            if
                not target.Parent
            then
                break
            end

            local alpha =
                math.clamp(
                    (
                        tick()
                        - startTime
                    )
                    / duration,
                    0,
                    1
                )

            local angle =
                math.rad(360)
                * alpha

            camera.CFrame =
                CFrame.new(
                    startPosition
                )
                * CFrame.Angles(
                    0,
                    angle,
                    0
                )
                * originalRotation

            RunService.RenderStepped:Wait()

        end


        if target.Parent then

            camera.CFrame =
                CFrame.lookAt(
                    camera.CFrame.Position,
                    target.Position
                )

        end


        RunService.RenderStepped:Wait()

        gun:Activate()

        pcall(function()

            local vu =
                game:GetService(
                    "VirtualUser"
                )

            vu:Button1Down(
                Vector2.zero
            )

            vu:Button1Up(
                Vector2.zero
            )

        end)


        task.wait(0.04)


        camera =
            workspace.CurrentCamera

        if camera then

            camera.CFrame =
                originalCameraCFrame

            camera.CameraType =
                originalCameraType

            if originalCameraSubject then

                camera.CameraSubject =
                    originalCameraSubject

            end

        end

    else

        local originalCFrame =
            hrp.CFrame

        local speed =
            math.max(
                smoothTrickshotSpeed,
                1
            )

        local duration =
            math.clamp(
                1.1 / speed,
                0.08,
                1.1
            )

        local startTime =
            tick()


        while
            tick() - startTime
                < duration
        do

            local alpha =
                math.clamp(
                    (
                        tick()
                        - startTime
                    )
                    / duration,
                    0,
                    1
                )

            hrp.CFrame =
                originalCFrame
                * CFrame.Angles(
                    0,
                    math.rad(360)
                        * alpha,
                    0
                )

            RunService.RenderStepped:Wait()

        end


        hrp.CFrame =
            CFrame.lookAt(
                hrp.Position,
                Vector3.new(
                    target.Position.X,
                    hrp.Position.Y,
                    target.Position.Z
                )
            )

        RunService.RenderStepped:Wait()

        gun:Activate()

        pcall(function()

            local vu =
                game:GetService(
                    "VirtualUser"
                )

            vu:Button1Down(
                Vector2.zero
            )

            vu:Button1Up(
                Vector2.zero
            )

        end)

        task.wait(0.04)

    end


    if gun.Parent == character then
        gun.Parent = LocalPlayer.Backpack
    end


    task.spawn(
        startReload
    )

end


--==================================================
-- MAIN TRICKSHOT DISPATCHER
--==================================================

local function executeTrickShotAction()

    if flickReloading then
        return
    end


    if selectedTrickShotType
        == "Flick Shoot"
    then

        executeFlickShoot()

    elseif selectedTrickShotType
        == "360 Shoot"
    then

        execute360Shoot()

    end

end


--==================================================
-- FLICK GUI DRAGGING
--==================================================

local draggingFlick = false
local dragInputFlick
local dragStartFlick
local startPosFlick
local movedFlick = false


if flickButton and flickFrame then

    flickButton.InputBegan:Connect(
        function(input)

            if
                input.UserInputType
                    == Enum.UserInputType.Touch

                or input.UserInputType
                    == Enum.UserInputType.MouseButton1
            then

                if not lockGuisPosition then

                    draggingFlick = true
                    movedFlick = false

                    dragStartFlick =
                        input.Position

                    startPosFlick =
                        flickFrame.Position


                    local connection

                    connection =
                        input.Changed:Connect(
                            function()

                                if
                                    input.UserInputState
                                        == Enum.UserInputState.End
                                then

                                    draggingFlick = false

                                    if connection then
                                        connection:Disconnect()
                                    end

                                    guiPositions.FlickPos =
                                        flickFrame.Position

                                    saveSettings(
                                        guiPositions
                                    )

                                end

                            end
                        )

                else

                    movedFlick = false

                end

            end

        end
    )


    flickButton.InputChanged:Connect(
        function(input)

            if lockGuisPosition then
                return
            end

            if
                input.UserInputType
                    == Enum.UserInputType.Touch

                or input.UserInputType
                    == Enum.UserInputType.MouseMovement
            then

                dragInputFlick = input

            end

        end
    )


    UIS.InputChanged:Connect(
        function(input)

            if lockGuisPosition then
                return
            end

            if
                input == dragInputFlick
                and draggingFlick
            then

                local delta =
                    input.Position
                    - dragStartFlick


                if
                    math.abs(delta.X) > 5
                    or math.abs(delta.Y) > 5
                then

                    movedFlick = true

                end


                flickFrame.Position =
                    UDim2.new(
                        startPosFlick.X.Scale,
                        startPosFlick.X.Offset
                            + delta.X,

                        startPosFlick.Y.Scale,
                        startPosFlick.Y.Offset
                            + delta.Y
                    )

            end

        end
    )


    flickButton.Activated:Connect(
        function()

            if movedFlick then
                return
            end

            if flickReloading then
                return
            end

            executeTrickShotAction()

        end
    )

end


--==================================================
-- TRICKSHOT SETTINGS
--==================================================

trickshot_section:AddToggle(
    "Show Trick Shot GUI",
    function(on)

        showFlickGui = on

        if flickGui then

            flickGui.Enabled = on

            if on and flickFrame then

                flickFrame.Position =
                    guiPositions.FlickPos
                    or defaultFlickPos

            end

        end


        if not on and flickFrame then

            flickFrame.Position =
                defaultFlickPos

            guiPositions.FlickPos =
                defaultFlickPos

            saveSettings(
                guiPositions
            )

        end

    end
)


trickshot_section:AddDropdown(
    "Trick Shot Type",
    {
        "Flick Shoot",
        "360 Shoot"
    },
    function(sel)

        selectedTrickShotType =
            sel

        if
            flickButton
            and not flickReloading
        then

            flickButton.Text =
                sel

        end

    end
)


trickshot_section:AddDropdown(
    "Trickshot Method",
    {
        "Instant",
        "Smooth"
    },
    function(sel)

        flickMode = sel

    end
)


trickshot_section:AddSlider(
    "Instant Trickshot",
    0.01,
    5,
    instantTrickshotSpeed,
    function(v)
        instantTrickshotSpeed = v
    end
)


trickshot_section:AddSlider(
    "Smooth Trickshot Speed",
    1,
    30,
    smoothTrickshotSpeed,
    function(v)

        smoothTrickshotSpeed = v

    end
)


trickshot_section:AddToggle(
    "Flick Wall Check",
    function(on)

        flickWallCheckEnabled = on

    end
)


trickshot_section:AddToggle(
    "Whitelist Friends",
    function(on)

        whitelistFriendsEnabled = on

    end
)


trickshot_section:AddKeybind(
    "Trick Shot Keybind",
    "Q",
    executeTrickShotAction
)


trickshot_section:AddSlider(
    "Trick Shot GUI Size",
    50,
    300,
    flickGuiSize,
    function(v)

        flickGuiSize = v

        if flickFrame then

            flickFrame.Size =
                UDim2.new(
                    0,
                    flickGuiSize,
                    0,
                    flickGuiSize
                        * (100 / 220)
                )

        end

        if flickButton then

            flickButton.TextSize =
                math.clamp(
                    math.floor(
                        flickGuiSize / 12
                    ),
                    9,
                    28
                )

        end

    end
)


--==================================================
-- GUIS TRANSPARENCY SLIDER
--==================================================

trickshot_section:AddSlider(
    "Guis transparency",
    1,
    10,
    1,
    function(v)
        local mappedTransparency = v / 10
        updateAllGuisTransparency(mappedTransparency)
    end
)
