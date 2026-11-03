local table_insert = table.insert
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({_tasks = {}, _destroyed = false}, Maid)
end

function Maid:GiveTask(task)
    if self._destroyed then
        self:_cleanupTask(task)
        return
    end
    table_insert(self._tasks, task)
    return task
end

function Maid:GiveTasks(...)
    for _, task in ipairs({...}) do
        self:GiveTask(task)
    end
end

function Maid:_cleanupTask(task)
    local taskType = typeof(task)
    if taskType == "RBXScriptConnection" then
        task:Disconnect()
    elseif taskType == "Instance" then
        task:Destroy()
    elseif taskType == "function" then
        task()
    elseif taskType == "table" and type(task.Destroy) == "function" then
        task:Destroy()
    end
end

function Maid:DoCleaning()
    if self._destroyed then return end
    self._destroyed = true
    for _, task in ipairs(self._tasks) do
        self:_cleanupTask(task)
    end
    self._tasks = {}
end

function Maid:Destroy()
    self:DoCleaning()
end

local RootMaid = Maid.new()
local shared = odh_shared_plugins

task.spawn(function()
    shared.load_from_github_url("/aux0on/CrashHandler/refs/heads/main/Prevention.lua")
end)

if shared.game_name ~= "Murder Mystery 2" then return end

local gp = shared.CreateTab("Firefly Shield", "/B6O6S/Better-ODH/refs/heads/main/1793620542467")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

--=========================================================
-- FIREFLY SLOT DEFINITIONS
--=========================================================
local slots = {
    { key = "TL", label = "Top-Left", x = -1.0, y = 1.0, z = 0 },
    { key = "TC", label = "Top-Center", x = 0.0, y = 1.0, z = 0 },
    { key = "TR", label = "Top-Right", x = 1.0, y = 1.0, z = 0 },
    { key = "ML", label = "Middle-Left", x = -1.0, y = 0.0, z = 0 },
    { key = "MC", label = "Middle-Center", x = 0.0, y = 0.0, z = 0 },
    { key = "MR", label = "Middle-Right", x = 1.0, y = 0.0, z = 0 },
    { key = "BC", label = "Bottom-Center", x = 0.0, y = -1.0, z = 0 },
}

--=========================================================
-- CONFIG
--=========================================================
local config = {
    offset = 2.0,
    height = 0,
    followSpeed = 12,
    maxFireflies = 50,
    rescanTime = 1.0,
    blockRange = 50,
    threatTimeout = 0.3,
    lineLength = 20,
    lineBackOffset = 4,
    staticStartOffset = 2,
    staticLineLength = 25,
    staticTimeout = 15,
    shapeMode = "Penis", -- Default layout locked to Penis as requested
    shapeForwardOffset = 2.0,
    shapeHeightOffset = 0.0,
    shapeRotation = 0,
    targetPlayer = nil,
    bangSpeed = 12,
}

local features = {
    enabled = false,
    blockKnives = false,
    blockKnivesStatic = false,
    autoFireflies = false,
    removeLights = true,
    enableShape = false,        
    giveShieldToTarget = false,
    bangPlayer = false,
}

--=========================================================
-- STATE
--=========================================================
local fireflyList = {}
local tracked = {}
local throwingKnives = {}
local smoothDir = nil
local accumulator = 0
local isRunning = false
local loopMaid = Maid.new()
local activeThreat = nil
local activeStaticLine = nil

local cachedThreatRoot = nil
local lastThreatUpdate = 0
local autoFireflyMaid = Maid.new()
local autoFireflyThread = nil

--=========================================================
-- HELPERS
--=========================================================
local function killMovers(part)
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") or child:IsA("AlignPosition") or child:IsA("AlignOrientation") then
            child:Destroy()
        end
    end
end

local function removeLights(obj)
    if not features.removeLights then return end
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("Light") or child:IsA("ParticleEmitter") then
            child:Destroy()
        end
    end
end

local function getTargetRoot()
    if features.giveShieldToTarget or features.bangPlayer then
        if config.targetPlayer and config.targetPlayer.Character then
            return config.targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        end
    end
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- Shape Layout Generator (Locked to Penis configuration)
local function getShapeOffsets(count)
    local offsets = {}

    -- 3 balls: center normal, left & right dropped down
    table.insert(offsets, Vector3.new(0, 0, 0))
    table.insert(offsets, Vector3.new(-0.38, -0.35, 0))
    table.insert(offsets, Vector3.new(0.38, -0.35, 0))

    -- Straight horizontal shaft pointing forward (👉)
    local shaftCount = math.max(1, count - 3)
    for i = 1, shaftCount do
        local zSpacing = -0.35 * i
        table.insert(offsets, Vector3.new(0, 0, zSpacing))
    end
    return offsets
end

local function getLayoutOffsets(count)
    local offsets = {}
    if count <= #slots then
        for i = 1, count do
            local s = slots[i]
            table.insert(offsets, Vector3.new(s.x, s.y, s.z))
        end
        return offsets
    end
    local cols = math.ceil(math.sqrt(count))
    local rows = math.ceil(count / cols)
    local stepX = (cols > 1) and (2 / (cols - 1)) or 0
    local stepY = (rows > 1) and (2 / (rows - 1)) or 0
    for i = 0, count - 1 do
        local row = math.floor(i / cols)
        local col = i % cols
        local x = -1 + (col * stepX)
        local y = -1 + (row * stepY)
        local itemsInLastRow = count % cols
        if row == rows - 1 and itemsInLastRow > 0 and itemsInLastRow < cols then
            local shift = (cols - itemsInLastRow) * stepX / 2
            x = x + shift
        end
        table.insert(offsets, Vector3.new(x, y, 0))
    end
    return offsets
end

local function hasKillerTool(container)
    if not container then return false end
    for _, item in ipairs(container:GetChildren()) do
        if item:IsA("Tool") and item.Name:lower():find("knife", 1, true) then
            return true
        end
    end
    return false
end

local function findThreatRoot(myRoot)
    local best, bestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if root and hum and hum.Health > 0 then
                    if hasKillerTool(char) or hasKillerTool(plr:FindFirstChildOfClass("Backpack")) then
                        local dist = (root.Position - myRoot.Position).Magnitude
                        if dist < bestDist then
                            bestDist, best = dist, root
                        end
                    end
                end
            end
        end
    end
    return best
end

local function getCachedThreatRoot(myRoot)
    local now = tick()
    if now - lastThreatUpdate > 0.5 then
        lastThreatUpdate = now
        cachedThreatRoot = findThreatRoot(myRoot)
    end
    return cachedThreatRoot
end

local function getThreatDir(myRoot)
    local threat = getCachedThreatRoot(myRoot)
    if threat and threat.Parent then
        local flat = Vector3.new(
            threat.Position.X - myRoot.Position.X,
            0,
            threat.Position.Z - myRoot.Position.Z
        )
        if flat.Magnitude > 0.05 then
            return flat.Unit
        end
    end
    local look = myRoot.CFrame.LookVector
    local behind = Vector3.new(-look.X, 0, -look.Z)
    if behind.Magnitude < 0.05 then
        behind = Vector3.new(0, 0, 1)
    end
    return behind.Unit
end

local function findNearestKnife(myRoot)
    local best, bestDist = nil, math.huge
    for obj, _ in pairs(throwingKnives) do
        if obj and obj.Parent then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = (part.Position - myRoot.Position).Magnitude
                if dist <= config.blockRange and dist < bestDist then
                    bestDist = dist
                    local vel = part.AssemblyLinearVelocity
                    local dir = (vel.Magnitude > 1) and vel.Unit or part.CFrame.LookVector
                    best = {
                        part = part,
                        obj = obj,
                        pos = part.Position,
                        dir = dir,
                    }
                end
            end
        else
            throwingKnives[obj] = nil
        end
    end
    return best
end

local function applyMovingBlock(threat)
    local count = #fireflyList
    if count == 0 then return end
    local dir = threat.dir
    local lineStart = threat.pos - dir * config.lineBackOffset
    local lineEnd = lineStart + dir * config.lineLength
    for i, obj in ipairs(fireflyList) do
        if obj and obj.Parent then
            local t = (count > 1) and ((i - 1) / (count - 1)) or 0.5
            obj.CFrame = CFrame.new(lineStart:Lerp(lineEnd, t))
            obj.Anchored = true
            obj.CanCollide = true
        end
    end
end

local function applyStaticLine(lineData)
    local count = #fireflyList
    if count == 0 then return end
    local startPos = lineData.start + lineData.dir * config.staticStartOffset
    local endPos = startPos + lineData.dir * config.staticLineLength
    for i, obj in ipairs(fireflyList) do
        if obj and obj.Parent then
            local t = (count > 1) and ((i - 1) / (count - 1)) or 0.5
            obj.CFrame = CFrame.new(startPos:Lerp(endPos, t))
            obj.Anchored = true
            obj.CanCollide = true
        end
    end
end

local function collectFireflies()
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name == "Firefly" and not tracked[obj] then
                if #fireflyList >= config.maxFireflies then break end
                tracked[obj] = true
                table.insert(fireflyList, obj)
                killMovers(obj)
                removeLights(obj)
                pcall(function()
                    if obj:GetNetworkOwner() ~= LocalPlayer then
                        obj:SetNetworkOwner(LocalPlayer)
                    end
                    obj.Anchored = true
                    obj.CanCollide = false
                end)
            end
        end
        for i = #fireflyList, 1, -1 do
            local obj = fireflyList[i]
            if not obj or not obj.Parent then
                if obj then tracked[obj] = nil end
                table.remove(fireflyList, i)
            end
        end
    end)
end

local function updateFireflies(dt)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if features.blockKnivesStatic then
        local knife = findNearestKnife(root)
        if activeStaticLine then
            local timedOut = (tick() - activeStaticLine.startTime) > config.staticTimeout
            local lostContact = not knife and (tick() - activeStaticLine.lastSeenTime) > config.threatTimeout
            if timedOut or lostContact then
                activeStaticLine = nil
            else
                if knife then
                    activeStaticLine.lastSeenTime = tick()
                end
                applyStaticLine(activeStaticLine)
                return
            end
        else
            if knife then
                activeStaticLine = {
                    start = knife.pos,
                    dir = knife.dir,
                    startTime = tick(),
                    lastSeenTime = tick(),
                }
                applyStaticLine(activeStaticLine)
                return
            end
        end
    end

    if not features.blockKnivesStatic and features.blockKnives then
        local threat = findNearestKnife(root)
        if threat then
            activeThreat = { time = tick() }
            applyMovingBlock(threat)
            return
        elseif activeThreat and (tick() - activeThreat.time) < config.threatTimeout then
            return
        else
            activeThreat = nil
        end
    end

    local count = #fireflyList
    if count == 0 then return end

    -- Bang Player Animation Logic (Strictly from the back, going back and forth)
    if features.bangPlayer then
        local targetRoot = getTargetRoot()
        if targetRoot then
            local thrustOffset = math.sin(tick() * config.bangSpeed) * 1.2
            local basePos = targetRoot.Position - (targetRoot.CFrame.LookVector * (1.5 + thrustOffset)) + Vector3.new(0, config.height + config.shapeHeightOffset, 0)
            local lookCFrame = CFrame.new(basePos, basePos + targetRoot.CFrame.LookVector * 10) * CFrame.Angles(0, math.rad(config.shapeRotation), 0)
            
            local offsets = getShapeOffsets(count)
            for i, obj in ipairs(fireflyList) do
                if obj and obj.Parent then
                    local offset3D = offsets[i]
                    if offset3D then
                        obj.CFrame = lookCFrame * CFrame.new(offset3D)
                        obj.CanCollide = false
                    end
                end
            end
            return
        end
    end

    -- If custom shape mode is enabled via toggle
    if features.enableShape then
        local targetRoot = getTargetRoot()
        if targetRoot then
            local basePos = targetRoot.Position + Vector3.new(0, config.height + config.shapeHeightOffset, 0) + (targetRoot.CFrame.LookVector * config.shapeForwardOffset)
            local lookCFrame = CFrame.new(basePos, basePos + targetRoot.CFrame.LookVector * 10) * CFrame.Angles(0, math.rad(config.shapeRotation), 0)

            local offsets = getShapeOffsets(count)
            for i, obj in ipairs(fireflyList) do
                if obj and obj.Parent then
                    local offset3D = offsets[i]
                    if offset3D then
                        obj.CFrame = lookCFrame * CFrame.new(offset3D)
                        obj.CanCollide = false
                    end
                end
            end
            return
        end
    end

    -- Normal shield behavior
    local targetDir = getThreatDir(root)
    if smoothDir then
        local alpha = math.clamp(config.followSpeed * dt, 0, 1)
        local blended = smoothDir:Lerp(targetDir, alpha)
        if blended.Magnitude > 0.001 then
            smoothDir = blended.Unit
        end
    else
        smoothDir = targetDir
    end

    local dir = smoothDir
    local rotation = CFrame.lookAt(Vector3.zero, -dir)
    local center = root.Position + Vector3.new(0, config.height, 0) + dir * config.offset
    local offsets = getLayoutOffsets(count)

    for i, obj in ipairs(fireflyList) do
        if obj and obj.Parent then
            local offset3D = offsets[i]
            if offset3D then
                obj.CFrame = CFrame.new(center + (rotation * offset3D))
                obj.CanCollide = false
            end
        end
    end
end

local function startFireflies()
    if isRunning then return end
    isRunning = true
    smoothDir = nil
    accumulator = 0
    fireflyList = {}
    tracked = {}
    activeThreat = nil
    activeStaticLine = nil
    throwingKnives = {}

    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name:lower() == "throwingknife" then
            throwingKnives[obj] = true
        end
    end

    loopMaid:GiveTask(Workspace.ChildAdded:Connect(function(child)
        if child.Name:lower() == "throwingknife" then
            throwingKnives[child] = true
        end
    end))

    loopMaid:GiveTask(Workspace.ChildRemoved:Connect(function(child)
        if throwingKnives[child] then
            throwingKnives[child] = nil
        end
    end))

    loopMaid:GiveTask(RunService.Heartbeat:Connect(function(dt)
        accumulator = accumulator + dt
        if accumulator > config.rescanTime then
            accumulator = 0
            collectFireflies()
        end
        updateFireflies(dt)
    end))
end

local function stopFireflies()
    isRunning = false
    loopMaid:DoCleaning()
    loopMaid = Maid.new()
    for _, obj in ipairs(fireflyList) do
        if obj and obj.Parent then
            pcall(function()
                obj.Anchored = false
                obj.CanCollide = true
                obj:SetNetworkOwner(nil)
            end)
        end
    end
    fireflyList = {}
    tracked = {}
    throwingKnives = {}
    smoothDir = nil
    activeThreat = nil
    activeStaticLine = nil
end

--=========================================================
-- AUTO FIREFLIES FUNCTIONALITY
--=========================================================
local function useFireflyToy()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    
    local tool = (char and char:FindFirstChild("Fireflies")) or (backpack and backpack:FindFirstChild("Fireflies"))
    
    if not tool then
        pcall(function()
            local remote = ReplicatedStorage:WaitForChild("Remotes", 2)
            if remote then
                remote = remote:WaitForChild("Extras", 2)
                if remote then
                    remote = remote:WaitForChild("ReplicateToy", 2)
                    if remote then
                        remote:InvokeServer("Fireflies")
                    end
                end
            end
        end)
        task.wait(0.3)
        backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        tool = (char and char:FindFirstChild("Fireflies")) or (backpack and backpack:FindFirstChild("Fireflies"))
    end

    if tool and char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:EquipTool(tool)
            task.wait(0.1)
            
            local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            VirtualUser:Button1Down(screenCenter, Camera.CFrame)
            task.delay(0.02, function()
                VirtualUser:Button1Up(screenCenter, Camera.CFrame)
            end)
            
            task.wait(0.2)
            if tool.Parent == char then
                tool.Parent = backpack
            end
        end
    end
end

local function startAutoFireflies()
    autoFireflyMaid:DoCleaning()
    
    local function runLoop()
        while features.autoFireflies do
            useFireflyToy()
            
            local elapsed = 0
            while elapsed < 16 and features.autoFireflies do
                task.wait(0.5)
                elapsed = elapsed + 0.5
            end
        end
    end

    if autoFireflyThread then
        task.cancel(autoFireflyThread)
    end
    autoFireflyThread = task.spawn(runLoop)

    autoFireflyMaid:GiveTask(LocalPlayer.CharacterAdded:Connect(function(newChar)
        if features.autoFireflies then
            local humanoid = newChar:WaitForChild("Humanoid", 5)
            if humanoid then
                task.wait(1.2)
                if features.autoFireflies then
                    if autoFireflyThread then
                        task.cancel(autoFireflyThread)
                    end
                    autoFireflyThread = task.spawn(runLoop)
                end
            end
        end
    end))
end

local function stopAutoFireflies()
    if autoFireflyThread then
        task.cancel(autoFireflyThread)
        autoFireflyThread = nil
    end
    autoFireflyMaid:DoCleaning()
end

--=========================================================
-- UI SECTIONS
--=========================================================
local mainSection = gp:AddSection("Firefly Shield", "Main")

mainSection:AddToggle("Enable Firefly Shield", function(bool)
    features.enabled = bool
    if bool then
        startFireflies()
    else
        stopFireflies()
    end
end)

mainSection:AddToggle("Enable Block Thrown Knives", function(bool)
    features.blockKnives = bool
    if not bool then activeThreat = nil end
end)

mainSection:AddToggle("Block Throw Static", function(bool)
    features.blockKnivesStatic = bool
    if not bool then activeStaticLine = nil end
end)

mainSection:AddToggle("Auto Fireflies", function(bool)
    features.autoFireflies = bool
    if bool then
        startAutoFireflies()
    else
        stopAutoFireflies()
    end
end)

mainSection:AddToggle("Remove Firefly Lights", function(bool)
    features.removeLights = bool
end)

mainSection:AddToggle("Enable Shape", function(bool)
    features.enableShape = bool
end)

-- Player Target Selector Section using AddPlayerDropdown (Includes Bang Options)
local targetSection = gp:AddSection("Player Targeting", "Fireflies")

pcall(function()
    targetSection:AddPlayerDropdown("Select Target Player", function(player)
        config.targetPlayer = player
    end)
end)

targetSection:AddToggle("Give Shield To Target Player", function(bool)
    features.giveShieldToTarget = bool
end)

targetSection:AddToggle("Bang Player (Penis Animation)", function(bool)
    features.bangPlayer = bool
    if bool then
        features.enableShape = true
    end
end)

targetSection:AddSlider("Bang Speed", 1, 30, config.bangSpeed, function(v)
    config.bangSpeed = v
end)

-- Dedicated Shape Adjustments Section
local shapeAdjustSection = gp:AddSection("Shape Adjustments", "Fireflies")
shapeAdjustSection:AddSlider("Shape Distance", 0.5, 5.0, config.shapeForwardOffset, function(v) config.shapeForwardOffset = v end)
shapeAdjustSection:AddSlider("Shape Height Offset", -4, 4, config.shapeHeightOffset, function(v) config.shapeHeightOffset = v end)
shapeAdjustSection:AddSlider("Shape Rotation", 0, 360, config.shapeRotation, function(v) config.shapeRotation = v end)

local function addFireflySliders(section, slot)
    section:AddSlider(slot.label .. " X", -5, 5, slot.x, function(v) slot.x = v end)
    section:AddSlider(slot.label .. " Y", -5, 5, slot.y, function(v) slot.y = v end)
    section:AddSlider(slot.label .. " Z", -5, 5, slot.z, function(v) slot.z = v end)
end

local topSection = gp:AddSection("Top Row", "Fireflies")
addFireflySliders(topSection, slots[1])
addFireflySliders(topSection, slots[2])
addFireflySliders(topSection, slots[3])

local midSection = gp:AddSection("Middle Row", "Fireflies")
addFireflySliders(midSection, slots[4])
addFireflySliders(midSection, slots[5])
addFireflySliders(midSection, slots[6])

local bottomSection = gp:AddSection("Bottom Row", "Fireflies")
addFireflySliders(bottomSection, slots[7])

-- Global Settings Section
local globalSection = gp:AddSection("Global Settings", "Fireflies")
globalSection:AddSlider("Distance From Character", 0.5, 5.0, config.offset, function(v) config.offset = v end)
globalSection:AddSlider("Height Offset", -4, 4, config.height, function(v) config.height = v end)
globalSection:AddSlider("Follow Speed", 1, 30, config.followSpeed, function(v) config.followSpeed = v end)
globalSection:AddSlider("Max Fireflies", 1, 100, config.maxFireflies, function(v) config.maxFireflies = math.floor(v) end)

local movingBlockSection = gp:AddSection("Moving Knife Block", "Fireflies")
movingBlockSection:AddSlider("Trigger Range", 10, 120, config.blockRange, function(v) config.blockRange = v end)
movingBlockSection:AddSlider("Line Length", 5, 60, config.lineLength, function(v) config.lineLength = v end)
movingBlockSection:AddSlider("Line Back Offset", 0, 20, config.lineBackOffset, function(v) config.lineBackOffset = v end)
movingBlockSection:AddSlider("Return Delay (s)", 0, 1, config.threatTimeout, function(v) config.threatTimeout = v end)

local staticBlockSection = gp:AddSection("Static Knife Block", "Fireflies")
staticBlockSection:AddSlider("Trigger Range", 10, 120, config.blockRange, function(v) config.blockRange = v end)
staticBlockSection:AddSlider("Start Offset", 0, 15, config.staticStartOffset, function(v) config.staticStartOffset = v end)
staticBlockSection:AddSlider("Line Length", 5, 60, config.staticLineLength, function(v) config.staticLineLength = v end)
staticBlockSection:AddSlider("Return Delay (s)", 0, 1, config.threatTimeout, function(v) config.threatTimeout = v end)
staticBlockSection:AddSlider("Hard Timeout (s)", 1, 60, config.staticTimeout, function(v) config.staticTimeout = v end)

--=========================================================
-- CLEANUP ON UNLOAD
--=========================================================
RootMaid:GiveTask(function()
    features.enabled = false
    features.blockKnives = false
    features.blockKnivesStatic = false
    features.autoFireflies = false
    features.enableShape = false
    features.giveShieldToTarget = false
    features.bangPlayer = false
    stopFireflies()
    stopAutoFireflies()
end)
