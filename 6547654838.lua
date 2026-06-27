local Orion = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Orion/main/source'))()

local Window = Orion:MakeWindow({
	Title = "Silent Aim",
	HidePremium = false,
	SaveConfig = false,
	ConfigFolder = "SilentAimConfig"
})

local MainTab = Window:MakeTab({
	Name = "Main",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

local SilentAimEnabled = false
local Target = {}
local Mode = "Mouse"
local Method = "Raycast"
local MethodRay = "All"
local IgnoredScripts = {"ControlScript", "ControlModule"}
local Range = 150
local HitChance = 85
local HeadshotChance = 65
local AutoFire = false
local AutoFireShootDelay = 0.1
local AutoFireMode = "RootPart"
local fireoffset = CFrame.identity
local Wallbang = false
local CircleObject = nil
local Projectile = false
local ProjectileSpeed = 1000
local ProjectileGravity = 192.6
local TargetPlayers = true
local TargetNPCs = false
local TargetWalls = false
local rand = Random.new()
local mouseClicked = false
local delayCheck = tick()
local oldnamecall = nil
local oldray = nil
local gameCamera = workspace.CurrentCamera
local RaycastWhitelist = RaycastParams.new()
RaycastWhitelist.FilterType = Enum.RaycastFilterType.Include
local ProjectileRaycast = RaycastParams.new()
ProjectileRaycast.RespectCanCollide = true
local targetinfo = {Targets = {}}
local inputService = game:GetService("UserInputService")

local CircleColorHue = 0
local CircleColorSat = 1
local CircleColorVal = 1
local CircleTransparency = 0.5
local CircleFilled = false
local RangeCircleEnabled = false

local function splitString(str)
	local parts = {}
	for part in string.gmatch(str, "[^,]+") do
		table.insert(parts, tonumber(part:gsub("^%s*(.-)%s*$", "%1")) or 0)
	end
	return parts
end

local function canClick()
	if not game:IsLoaded() then return false end
	local player = game.Players.LocalPlayer
	if not player or not player.Character or not player.Character:FindFirstChild("Humanoid") then return false end
	if player.Character.Humanoid.Health <= 0 then return false end
	return true
end

local function getEntities(origin, targetPart, obj)
	if rand:NextNumber(0, 100) > (AutoFire and 100 or HitChance) then return nil end
	local part = (rand:NextNumber(0, 100) < (AutoFire and 100 or HeadshotChance)) and "Head" or "RootPart"
	local entities = {}
	if TargetPlayers then
		for _, player in ipairs(game.Players:GetPlayers()) do
			if player ~= game.Players.LocalPlayer and player.Character and player.Character:FindFirstChild(part) then
				local dist = (player.Character[part].Position - origin).Magnitude
				if dist <= Range then
					if not TargetWalls then
						local ray = Ray.new(origin, (player.Character[part].Position - origin).Unit * dist)
						local hit = workspace:FindPartOnRay(ray, obj or {})
						if not hit then
							table.insert(entities, {Entity = player, Part = player.Character[part], Origin = origin})
						end
					else
						table.insert(entities, {Entity = player, Part = player.Character[part], Origin = origin})
					end
				end
			end
		end
	end
	if TargetNPCs then
		for _, npc in ipairs(workspace:GetDescendants()) do
			if npc:IsA("Model") and npc:FindFirstChild("Humanoid") and npc:FindFirstChild(part) then
				local dist = (npc[part].Position - origin).Magnitude
				if dist <= Range then
					if not TargetWalls then
						local ray = Ray.new(origin, (npc[part].Position - origin).Unit * dist)
						local hit = workspace:FindPartOnRay(ray, obj or {})
						if not hit then
							table.insert(entities, {Entity = npc, Part = npc[part], Origin = origin})
						end
					else
						table.insert(entities, {Entity = npc, Part = npc[part], Origin = origin})
					end
				end
			end
		end
	end
	if #entities == 0 then return nil end
	local closest = nil
	local closestDist = math.huge
	for _, ent in ipairs(entities) do
		local dist = (ent.Part.Position - origin).Magnitude
		if dist < closestDist then
			closestDist = dist
			closest = ent
		end
	end
	return closest.Entity, closest.Part, closest.Origin
end

local function getTarget(origin, obj)
	local ent, targetPart, _ = getEntities(origin, nil, obj)
	if ent then
		targetinfo.Targets[ent] = tick() + 1
		if Projectile then
			ProjectileRaycast.FilterDescendantsInstances = {gameCamera, ent.Character or ent}
			ProjectileRaycast.CollisionGroup = targetPart.CollisionGroup
		end
	end
	return ent, targetPart, origin
end

local function solveTrajectory(origin, speed, gravity, targetPos, targetVel, worldGravity, hipHeight, _, raycastParams)
	local g = worldGravity or 196.2
	local v = speed or 1000
	local target = targetPos - Vector3.new(0, hipHeight or 0, 0)
	local relative = target - origin
	local horizontal = Vector3.new(relative.X, 0, relative.Z)
	local hMagnitude = horizontal.Magnitude
	if hMagnitude == 0 then return target end
	local vertical = relative.Y
	local timeToTarget = hMagnitude / v
	local drop = 0.5 * g * timeToTarget * timeToTarget
	local finalY = vertical + drop
	local direction = Vector3.new(horizontal.X, finalY, horizontal.Z).Unit
	local solution = origin + (direction * hMagnitude)
	if raycastParams then
		local ray = Ray.new(origin, (solution - origin).Unit * (solution - origin).Magnitude)
		local hit = workspace:FindPartOnRayWithWhitelist(ray, raycastParams.FilterDescendantsInstances or {})
		if hit then
			return nil
		end
	end
	return solution
end

local Hooks = {
	FindPartOnRayWithIgnoreList = function(args)
		local ent, targetPart, origin = getTarget(args[1].Origin, {args[2]})
		if not ent then return end
		if Wallbang then
			return {targetPart, targetPart.Position, targetPart:GetClosestPointOnSurface(origin), targetPart.Material}
		end
		args[1] = Ray.new(origin, CFrame.lookAt(origin, targetPart.Position).LookVector * args[1].Direction.Magnitude)
	end,
	Raycast = function(args)
		if MethodRay ~= "All" and args[3] and args[3].FilterType ~= Enum.RaycastFilterType[MethodRay] then return end
		local ent, targetPart, origin = getTarget(args[1])
		if not ent then return end
		args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
		if Wallbang then
			RaycastWhitelist.FilterDescendantsInstances = {targetPart}
			args[3] = RaycastWhitelist
		end
	end,
	ScreenPointToRay = function(args)
		local ent, targetPart, origin = getTarget(gameCamera.CFrame.Position)
		if not ent then return end
		local direction = CFrame.lookAt(origin, targetPart.Position)
		if Projectile then
			local calc = solveTrajectory(origin, ProjectileSpeed, ProjectileGravity, targetPart.Position, targetPart.Velocity or Vector3.zero, workspace.Gravity, ent.HipHeight or 0, nil, ProjectileRaycast)
			if not calc then return end
			direction = CFrame.lookAt(origin, calc)
		end
		return {Ray.new(origin + (args[3] and direction.LookVector * args[3] or Vector3.zero), direction.LookVector)}
	end,
	Ray = function(args)
		local ent, targetPart, origin = getTarget(args[1])
		if not ent then return end
		if Projectile then
			local calc = solveTrajectory(origin, ProjectileSpeed, ProjectileGravity, targetPart.Position, targetPart.Velocity or Vector3.zero, workspace.Gravity, ent.HipHeight or 0, nil, ProjectileRaycast)
			if not calc then return end
			args[2] = CFrame.lookAt(origin, calc).LookVector * args[2].Magnitude
		else
			args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
		end
	end
}
Hooks.FindPartOnRayWithWhitelist = Hooks.FindPartOnRayWithIgnoreList
Hooks.FindPartOnRay = Hooks.FindPartOnRayWithIgnoreList
Hooks.ViewportPointToRay = Hooks.ScreenPointToRay

function EnableSilentAim()
	if SilentAimEnabled then return end
	SilentAimEnabled = true
	if CircleObject then
		CircleObject.Visible = SilentAimEnabled and Mode == "Mouse"
	end
	if Method == "Ray" then
		oldray = hookfunction(Ray.new, function(origin, direction)
			if checkcaller() then return oldray(origin, direction) end
			local calling = getcallingscript()
			if calling then
				local list = #IgnoredScripts > 0 and IgnoredScripts or {"ControlScript", "ControlModule"}
				if table.find(list, tostring(calling)) then
					return oldray(origin, direction)
				end
			end
			local args = {origin, direction}
			Hooks.Ray(args)
			return oldray(unpack(args))
		end)
	else
		oldnamecall = hookmetamethod(game, "__namecall", function(...)
			if getnamecallmethod() ~= Method then return oldnamecall(...) end
			if checkcaller() then return oldnamecall(...) end
			local calling = getcallingscript()
			if calling then
				local list = #IgnoredScripts > 0 and IgnoredScripts or {"ControlScript", "ControlModule"}
				if table.find(list, tostring(calling)) then
					return oldnamecall(...)
				end
			end
			local self, args = ..., {select(2, ...)}
			local res = Hooks[Method](args)
			if res then return unpack(res) end
			return oldnamecall(self, unpack(args))
		end)
	end
	game:GetService("RunService").Heartbeat:Connect(function()
		if not SilentAimEnabled then return end
		if CircleObject then
			CircleObject.Position = inputService:GetMouseLocation()
		end
		if AutoFire then
			local origin = AutoFireMode == "Camera" and gameCamera.CFrame or (game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("RootPart") and game.Players.LocalPlayer.Character.RootPart.CFrame or CFrame.identity)
			local ent, _, _ = getEntities((origin * fireoffset).Position, "Head")
			local isActive = game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
			if isActive and canClick() then
				if ent and delayCheck < tick() then
					if mouseClicked then
						game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game:GetService("UserInputService").GetMouseLocation, 1)
						delayCheck = tick() + AutoFireShootDelay
					else
						game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, game:GetService("UserInputService").GetMouseLocation, 1)
					end
					mouseClicked = not mouseClicked
				else
					if mouseClicked then
						game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game:GetService("UserInputService").GetMouseLocation, 1)
					end
					mouseClicked = false
				end
			end
		end
	end)
end

function DisableSilentAim()
	if not SilentAimEnabled then return end
	SilentAimEnabled = false
	if oldnamecall then
		hookmetamethod(game, "__namecall", oldnamecall)
		oldnamecall = nil
	end
	if oldray then
		hookfunction(Ray.new, oldray)
		oldray = nil
	end
	if CircleObject then
		CircleObject.Visible = false
	end
end

local CoreSection = MainTab:AddSection({
	Name = "Core Settings"
})

CoreSection:AddToggle({
	Name = "Silent Aim",
	Default = false,
	Callback = function(Value)
		if Value then
			EnableSilentAim()
		else
			DisableSilentAim()
		end
	end
})

CoreSection:AddDropdown({
	Name = "Aim Mode",
	Default = "Mouse",
	Options = {"Mouse", "Position"},
	Callback = function(Value)
		Mode = Value
		if CircleObject and SilentAimEnabled then
			CircleObject.Visible = Mode == "Mouse"
		end
	end
})

CoreSection:AddDropdown({
	Name = "Raycast Method",
	Default = "Raycast",
	Options = {"FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "ScreenPointToRay", "ViewportPointToRay", "Raycast", "Ray"},
	Callback = function(Value)
		Method = Value
		if SilentAimEnabled then
			DisableSilentAim()
			EnableSilentAim()
		end
	end
})

CoreSection:AddDropdown({
	Name = "Raycast Filter Type",
	Default = "All",
	Options = {"All", "Exclude", "Include"},
	Callback = function(Value)
		MethodRay = Value
	end
})

CoreSection:AddTextbox({
	Name = "Ignored Scripts",
	Default = "ControlScript, ControlModule",
	TextDisappear = false,
	Callback = function(Text)
		local split = {}
		for word in string.gmatch(Text, "[^,]+") do
			table.insert(split, word:gsub("^%s*(.-)%s*$", "%1"))
		end
		IgnoredScripts = split
	end
})

CoreSection:AddSlider({
	Name = "Range",
	Min = 1,
	Max = 1000,
	Default = 150,
	Increment = 1,
	Suffix = " studs",
	Callback = function(Value)
		Range = Value
		if CircleObject then
			CircleObject.Radius = Value
		end
	end
})

CoreSection:AddSlider({
	Name = "Hit Chance",
	Min = 0,
	Max = 100,
	Default = 85,
	Increment = 1,
	Suffix = " %",
	Callback = function(Value)
		HitChance = Value
	end
})

CoreSection:AddSlider({
	Name = "Headshot Chance",
	Min = 0,
	Max = 100,
	Default = 65,
	Increment = 1,
	Suffix = " %",
	Callback = function(Value)
		HeadshotChance = Value
	end
})

local AutoSection = MainTab:AddSection({
	Name = "Auto Fire"
})

AutoSection:AddToggle({
	Name = "Auto Fire",
	Default = false,
	Callback = function(Value)
		AutoFire = Value
	end
})

AutoSection:AddSlider({
	Name = "Shot Delay",
	Min = 0,
	Max = 1,
	Default = 0.1,
	Increment = 0.01,
	Suffix = " s",
	Callback = function(Value)
		AutoFireShootDelay = Value
	end
})

AutoSection:AddDropdown({
	Name = "Auto Fire Origin",
	Default = "RootPart",
	Options = {"RootPart", "Camera"},
	Callback = function(Value)
		AutoFireMode = Value
	end
})

AutoSection:AddTextbox({
	Name = "Offset (x, y, z)",
	Default = "0, 0, 0",
	TextDisappear = false,
	Callback = function(Text)
		local suc, res = pcall(function()
			return CFrame.new(unpack(splitString(Text)))
		end)
		if suc then fireoffset = res end
	end
})

local TargetSection = MainTab:AddSection({
	Name = "Target Filtering"
})

TargetSection:AddToggle({
	Name = "Target Players",
	Default = true,
	Callback = function(Value)
		TargetPlayers = Value
	end
})

TargetSection:AddToggle({
	Name = "Target NPCs",
	Default = false,
	Callback = function(Value)
		TargetNPCs = Value
	end
})

TargetSection:AddToggle({
	Name = "Ignore Walls",
	Default = false,
	Callback = function(Value)
		TargetWalls = Value
	end
})

TargetSection:AddToggle({
	Name = "Wallbang",
	Default = false,
	Callback = function(Value)
		Wallbang = Value
	end
})

local ProjectileSection = MainTab:AddSection({
	Name = "Projectile Physics"
})

ProjectileSection:AddToggle({
	Name = "Projectile Prediction",
	Default = false,
	Callback = function(Value)
		Projectile = Value
	end
})

ProjectileSection:AddSlider({
	Name = "Projectile Speed",
	Min = 1,
	Max = 1000,
	Default = 1000,
	Increment = 1,
	Suffix = " studs/s",
	Callback = function(Value)
		ProjectileSpeed = Value
	end
})

ProjectileSection:AddSlider({
	Name = "Projectile Gravity",
	Min = 0,
	Max = 192.6,
	Default = 192.6,
	Increment = 0.1,
	Callback = function(Value)
		ProjectileGravity = Value
	end
})

local VisualSection = MainTab:AddSection({
	Name = "Visual Feedback"
})

VisualSection:AddToggle({
	Name = "Range Circle",
	Default = false,
	Callback = function(Value)
		RangeCircleEnabled = Value
		if Value then
			CircleObject = Drawing.new('Circle')
			CircleObject.Filled = CircleFilled
			CircleObject.Color = Color3.fromHSV(CircleColorHue, CircleColorSat, CircleColorVal)
			CircleObject.Position = game:GetService("GuiService"):GetMouseLocation()
			CircleObject.Radius = Range
			CircleObject.NumSides = 100
			CircleObject.Transparency = 1 - CircleTransparency
			CircleObject.Visible = SilentAimEnabled and Mode == "Mouse"
		else
			pcall(function()
				if CircleObject then
					CircleObject.Visible = false
					CircleObject:Remove()
					CircleObject = nil
				end
			end)
		end
	end
})

VisualSection:AddSlider({
	Name = "Circle Hue",
	Min = 0,
	Max = 1,
	Default = 0,
	Increment = 0.01,
	Callback = function(Value)
		CircleColorHue = Value
		if CircleObject then
			CircleObject.Color = Color3.fromHSV(CircleColorHue, CircleColorSat, CircleColorVal)
		end
	end
})

VisualSection:AddSlider({
	Name = "Circle Saturation",
	Min = 0,
	Max = 1,
	Default = 1,
	Increment = 0.01,
	Callback = function(Value)
		CircleColorSat = Value
		if CircleObject then
			CircleObject.Color = Color3.fromHSV(CircleColorHue, CircleColorSat, CircleColorVal)
		end
	end
})

VisualSection:AddSlider({
	Name = "Circle Value",
	Min = 0,
	Max = 1,
	Default = 1,
	Increment = 0.01,
	Callback = function(Value)
		CircleColorVal = Value
		if CircleObject then
			CircleObject.Color = Color3.fromHSV(CircleColorHue, CircleColorSat, CircleColorVal)
		end
	end
})

VisualSection:AddSlider({
	Name = "Circle Transparency",
	Min = 0,
	Max = 1,
	Default = 0.5,
	Increment = 0.01,
	Callback = function(Value)
		CircleTransparency = Value
		if CircleObject then
			CircleObject.Transparency = 1 - CircleTransparency
		end
	end
})

VisualSection:AddToggle({
	Name = "Circle Filled",
	Default = false,
	Callback = function(Value)
		CircleFilled = Value
		if CircleObject then
			CircleObject.Filled = CircleFilled
		end
	end
})

Orion:Init()
