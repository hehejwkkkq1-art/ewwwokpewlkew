-- Camera assist with optional elevated UI hosting where the runtime permits it.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RS=game:GetService("RunService")
local GS=game:GetService("GuiService")
local player=assert(Players.LocalPlayer,"Run on client")
local pg=assert(player:WaitForChild("PlayerGui",15),"PlayerGui unavailable")
local hosts={}
if type(gethui)=="function" then local ok,h=pcall(gethui);if ok and typeof(h)=="Instance" then hosts[#hosts+1]=h end end
pcall(function()hosts[#hosts+1]=game:GetService("CoreGui")end)
hosts[#hosts+1]=pg
local gui=Instance.new("ScreenGui")
gui.Name="CameraAimLock";gui.ResetOnSpawn=false;gui.DisplayOrder=2147483647
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local attached=false
for _,host in ipairs(hosts)do
    if pcall(function()gui.Parent=host;assert(gui.Parent==host)end)then attached=true;break end
end
assert(attached,"UI host unavailable")
for _,host in ipairs(hosts)do pcall(function()
    for _,v in ipairs(host:GetChildren())do if v~=gui and v.Name==gui.Name then v:Destroy()end end
end)end
local function makeAimSession()
    local self={enabled=false,focused=true,menu=false}
    function self:status(alive,cameraReady)
        if not self.enabled then return false,"Insert: menu | F8: stop" end
        if self.menu then return false,"Paused: Roblox menu open" end
        if not self.focused then return false,"Paused: window inactive" end
        if not alive then return false,"ON: waiting for respawn / new round" end
        if not cameraReady then return false,"ON: waiting for camera" end
        return true
    end
    return self
end

local session=makeAimSession()
local connections={}
local function on(signal,fn)local c=signal:Connect(fn);connections[#connections+1]=c;return c end
local function make(class,props)
    local v=Instance.new(class)
    for k,x in pairs(props)do if k~="Parent" then v[k]=x end end
    v.Parent=props.Parent;return v
end
local panel=make("Frame",{Parent=gui,Position=UDim2.fromOffset(16,70),Size=UDim2.fromOffset(300,450),
    BackgroundColor3=Color3.fromRGB(23,27,38),BorderSizePixel=0,Active=true})
local title=make("TextButton",{Parent=panel,Size=UDim2.new(1,0,0,30),Text="Aim Lock | drag to move",Font=Enum.Font.Code,
    TextSize=14,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(57,64,126),BorderSizePixel=0})
local scroll=make("ScrollingFrame",{Parent=panel,Position=UDim2.fromOffset(0,32),Size=UDim2.new(1,0,1,-70),
    BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,1100)})
local function button(y)
    return make("TextButton",{Parent=scroll,Position=UDim2.fromOffset(8,y-32),Size=UDim2.new(1,-16,0,32),Text="",
        Font=Enum.Font.Code,TextSize=14,TextColor3=Color3.fromRGB(230,233,242),BackgroundColor3=Color3.fromRGB(40,47,66),BorderSizePixel=0})
end
local toggle,partButton,visibleButton=button(38),button(76),button(114)
local teamButton=button(152)
local fireButton=button(190)
local info=make("TextLabel",{Parent=panel,Position=UDim2.new(0,8,1,-34),Size=UDim2.new(1,-16,0,32),
    BackgroundTransparency=1,Text="",Font=Enum.Font.Code,TextSize=11,TextWrapped=true,TextColor3=Color3.fromRGB(175,187,207)})
local mobile=make("TextButton",{Parent=gui,Position=UDim2.new(0,12,.55,0),Size=UDim2.fromOffset(45,38),Text="AL",
    Font=Enum.Font.Code,TextSize=14,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(57,64,126),BorderSizePixel=0,Visible=true})
local visibleOnly,mode,teamCheck,autoFire=true,1,false,false
local function makeAutoFire()
    local self={held=nil,last=-math.huge,token=0,error=nil}
    function self:release()
        self.token+=1
        local tool=self.held;self.held=nil
        if tool then pcall(function()tool:Deactivate()end)end
    end
    function self:tick(allowed,tool,now)
        if not allowed or not tool then self:release();return false end
        if self.held or now-self.last<.18 or not tool.Enabled then return false end
        self.last=now;self.token+=1
        local token=self.token
        self.held=tool
        local ok,err=pcall(function()tool:Activate()end)
        if not ok then self.error=tostring(err);self:release();return false end
        task.delay(.04,function()if self.token==token then self:release()end end)
        return true
    end
    return self
end

local fire=makeAutoFire()
local stableTarget=nil
local stableFrames=0
local locked,drag=nil,nil
local parts={{"Head","Head"},{"Body","UpperTorso","Torso","HumanoidRootPart"},{"Root","HumanoidRootPart","Torso"}}
local function refresh()
    toggle.Text="Aim Lock: "..(session.enabled and "ON" or "OFF")
    toggle.BackgroundColor3=session.enabled and Color3.fromRGB(44,105,78)or Color3.fromRGB(40,47,66)
    partButton.Text="Target: "..parts[mode][1].." >"
    visibleButton.Text="Visible Only: "..(visibleOnly and "ON" or "OFF")
    teamButton.Text="Team Check: "..(teamCheck and "ON" or "OFF")
    fireButton.Text="Auto Fire: "..(autoFire and "ON" or "OFF")
end
on(toggle.Activated,function()session.enabled=not session.enabled;locked=nil;refresh()end)
on(partButton.Activated,function()mode=mode%#parts+1;locked=nil;refresh()end)
on(visibleButton.Activated,function()visibleOnly=not visibleOnly;locked=nil;refresh()end)
on(teamButton.Activated,function()teamCheck=not teamCheck;locked=nil;refresh()end)
on(fireButton.Activated,function()autoFire=not autoFire;fire:release();refresh()end)
mobile.Size=UDim2.fromOffset(48,48)
make("UICorner",{Parent=mobile,CornerRadius=UDim.new(1,0)})
local bubbleDrag=nil
on(mobile.InputBegan,function(input)
    if bubbleDrag then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        bubbleDrag={input=input,start=input.Position,origin=mobile.AbsolutePosition,moved=false}
    end
end)
on(UIS.InputChanged,function(input)
    if not bubbleDrag then return end
    if input~=bubbleDrag.input and not(bubbleDrag.input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)then return end
    local delta=input.Position-bubbleDrag.start
    if Vector2.new(delta.X,delta.Y).Magnitude>6 then bubbleDrag.moved=true end
    if bubbleDrag.moved then
        local size=gui.AbsoluteSize
        mobile.Position=UDim2.fromOffset(math.clamp(bubbleDrag.origin.X+delta.X,0,math.max(0,size.X-48)),math.clamp(bubbleDrag.origin.Y+delta.Y,0,math.max(0,size.Y-48)))
    end
end)
on(UIS.InputEnded,function(input)
    if bubbleDrag and input==bubbleDrag.input then
        if not bubbleDrag.moved then panel.Visible=not panel.Visible end
        bubbleDrag=nil
    end
end)
on(UIS.WindowFocusReleased,function()bubbleDrag=nil end)
on(UIS.InputBegan,function(input)
    if input.KeyCode==Enum.KeyCode.F8 then session.enabled=false;locked=nil;refresh();return end
    if not UIS:GetFocusedTextBox() and input.KeyCode==Enum.KeyCode.Insert then panel.Visible=not panel.Visible end
end)
on(title.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        drag={input=input,start=input.Position,origin=panel.Position}
    end
end)
on(UIS.InputChanged,function(input)
    if not drag then return end
    if input~=drag.input and not(drag.input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)then return end
    local d=input.Position-drag.start;local size=gui.AbsoluteSize
    panel.Position=UDim2.fromOffset(math.clamp(drag.origin.X.Offset+d.X,0,math.max(0,size.X-300)),
        math.clamp(drag.origin.Y.Offset+d.Y,0,math.max(0,size.Y-450)))
end)
on(UIS.InputEnded,function(input)if drag and input==drag.input then drag=nil end end)
on(UIS.WindowFocusReleased,function()drag=nil;session.focused=false;locked=nil end)
on(UIS.WindowFocused,function()session.focused=true end)
on(player.CharacterAdded,function()drag=nil;locked=nil end)
on(player.CharacterRemoving,function()drag=nil;locked=nil end)
local function menuState(open)
    session.menu=open;drag=nil;locked=nil
    if open then panel.Visible=true end
end
on(GS.MenuOpened,function()menuState(true)end)
on(GS.MenuClosed,function()menuState(false)end)
menuState(GS.MenuIsOpen)
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
local function aimVisible(world,origin,target,character,params,excluded)
    local ignore=table.clone(excluded)
    local direction=target.Position-origin
    if direction.Magnitude<.01 then return true end
    for _=1,8 do
        params.FilterDescendantsInstances=ignore
        local hit=world:Raycast(origin,direction,params)
        if not hit or hit.Instance:IsDescendantOf(character) then return true end
        if hit.Instance:IsA("BasePart") and hit.Instance.Transparency>=.98 then
            ignore[#ignore+1]=hit.Instance
        else return false end
    end
    return false
end

local function sameAimTeam(a,b)
    if a.Team and b.Team then return a.Team==b.Team,"Team" end
    for _,key in ipairs({"TeamId","TeamID","teamId","TeamName","Team","team","Faction","SquadId"})do
        local x=a:GetAttribute(key);local y=b:GetAttribute(key)
        if x~=nil and y~=nil and typeof(x)==typeof(y) and (type(x)=="string" or type(x)=="number") then
            if x~="" and y~="" then return x==y,key end
        end
        local ac,bc=a.Character,b.Character
        x=ac and ac:GetAttribute(key);y=bc and bc:GetAttribute(key)
        if x~=nil and y~=nil and typeof(x)==typeof(y) and (type(x)=="string" or type(x)=="number")then
            if x~="" and y~="" then return x==y,"Character."..key end
        end
    end
    if not a.Neutral and not b.Neutral then return a.TeamColor==b.TeamColor,"TeamColor" end
    return nil,"unknown"
end

local teamUnknown=false
local function candidate(other,camera,requireOnscreen)
    if other==player or other.Parent~=Players then return nil end
    if teamCheck then
        local allied=sameAimTeam(player,other)
        if allied==nil then teamUnknown=true;return nil end
        if allied then return nil end
    end
    local character=other.Character
    local hum=character and character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health<=0 then return nil end
    local target=nil
    for i=2,#parts[mode]do
        local v=character:FindFirstChild(parts[mode][i])
        if v and v:IsA("BasePart")then target=v;break end
    end
    if not target then return nil end
    local point,inside=camera:WorldToViewportPoint(target.Position)
    if visibleOnly and (point.Z<=0 or(requireOnscreen and not inside))then return nil end
    if visibleOnly then
        local exclude={camera}
        if player.Character then exclude[#exclude+1]=player.Character end
        if not aimVisible(workspace,camera.CFrame.Position,target,character,params,exclude)then return nil end
    end
    return target,point
end
local bindName="CameraAimLock_"..player.UserId
local alive=true
gui.Destroying:Connect(function()
    alive=false;session.enabled=false;fire:release();RS:UnbindFromRenderStep(bindName)
    for _,c in ipairs(connections)do c:Disconnect()end
end)
RS:BindToRenderStep(bindName,Enum.RenderPriority.Last.Value+1,function()
    if not alive then return end
    local character=player.Character;local camera=workspace.CurrentCamera
    local hum=character and character:FindFirstChildOfClass("Humanoid")
    local ready,reason=session:status(hum~=nil and hum.Health>0,camera~=nil)
    if not ready then locked=nil;stableTarget=nil;stableFrames=0;fire:release();info.Text=reason;return end
    teamUnknown=false
    local target=locked and candidate(locked,camera,false)
    if not target then
        locked=nil;local best=math.huge;local center=camera.ViewportSize/2
        for _,other in ipairs(Players:GetPlayers())do
            local part,point=candidate(other,camera,true)
            if part then
                local offset=part.Position-camera.CFrame.Position
                local distance=offset.Magnitude>.01 and (1-camera.CFrame.LookVector:Dot(offset.Unit)) or 0
                if distance<best then best=distance;target=part;locked=other end
            end
        end
    end
    if target and locked then
        local origin=camera.CFrame.Position
        if(target.Position-origin).Magnitude>.01 then camera.CFrame=CFrame.lookAt(origin,target.Position)end
        if stableTarget==target then stableFrames+=1 else stableTarget=target;stableFrames=1 end
        local offset=target.Position-origin
        local aligned=offset.Magnitude>.01 and camera.CFrame.LookVector:Dot(offset.Unit)>=math.cos(math.rad(.5))
        local tool=character:FindFirstChildOfClass("Tool")
        local clear=false
        if autoFire and aligned and stableFrames>=2 then
            clear=aimVisible(workspace,origin,target,locked.Character,params,{character,camera})
        end
        fire:tick(autoFire and aligned and stableFrames>=2 and clear,tool,os.clock())
        info.Text="Locked: "..locked.DisplayName.." | "..parts[mode][1]
        if autoFire then info.Text=info.Text..(not tool and " | equip weapon" or not clear and " | fire waiting for visibility" or " | auto fire") end
        if fire.error then autoFire=false;info.Text="Auto Fire error: "..fire.error;fire.error=nil;refresh()end
    else stableTarget=nil;stableFrames=0;fire:release();info.Text=teamUnknown and "Team Check: no readable team data" or "No eligible loaded target"end
end)
refresh()

local ImportedESP=(function()
local EspSettings = {}

function EspSettings.create(environment, configuration)
	local color = environment.Color3
	local settings = {
		on = false, style = "Box", maxDist = 1000, murderer = true, sheriff = true, hero = true, innocent = true,
		noRole = false, visCheck = false, dimHidden = true, hiddenStyle = "Fade", smooth = 40, fade = true, fadeFrom = 60,
		box = true, boxStyle = "Corners", boxThickness = 1, cornerSize = 22, boxRound = 4, outline = true, boxFill = false,
		boxFillAlpha = 8, boxGlow = false, glowStrength = 25, gradient = false,
		gradientColour = color.fromRGB(255, 255, 255), pulse = false, pulseSpeed = 1.2, colorMode = "Role",
		customColour = color.fromRGB(245, 245, 245), hiddenColour = color.fromRGB(150, 155, 170),
		murdererColour = color.fromRGB(255, 64, 64), sheriffColour = color.fromRGB(80, 150, 255),
		heroColour = color.fromRGB(255, 210, 60), innocentColour = color.fromRGB(90, 230, 130),
		noRoleColour = color.fromRGB(176, 182, 204), skeleton = false, boneThick = 1.5, boneRole = true,
		boneColour = color.fromRGB(235, 235, 235), boneHidden = color.fromRGB(170, 140, 255), headDot = false,
		headScale = 80, lookLine = false, lookLength = 10, health = false, healthPosition = "Left", healthStyle = "Solid",
		barThickness = 2, barGap = 3, healthNum = false, smoothHealth = true, healthLow = color.fromRGB(235, 60, 60),
		healthHigh = color.fromRGB(90, 225, 120), name = true, nameMode = "Display name", roleText = true,
		weaponIcon = true, distance = false, textFont = "GothamSSm", textSize = 12, infoSize = 10, textOutline = true,
		textMatch = false, hideGameNames = true, textGrad = false, textGradStyle = "ESP Color",
		textGradA = color.fromRGB(255, 94, 160), textGradB = color.fromRGB(90, 200, 255), textGradAnim = true,
		textGradSpeed = 1, textGradAngle = 0, nameColour = color.fromRGB(250, 250, 250),
		infoColour = color.fromRGB(200, 205, 215), nameOffset = 3, labelWidth = 240, plate = false, plateStyle = "Flat",
		plateAlpha = 70, plateColour = color.fromRGB(20, 20, 24), chams = false, chamsStyle = "Soft", chamsAlpha = 45,
		chamsThrough = false, chamsRange = 60, chamsOutline = true, chamsEdgeAlpha = 85, chamsRole = true,
		chamsColour = color.fromRGB(255, 70, 70), chamsHidden = color.fromRGB(150, 110, 255),
		chamsEdge = color.fromRGB(255, 255, 255), chamsEdgeHidden = color.fromRGB(200, 180, 255), chamsAnim = "None",
		chamsSpeed = 1, chamsFlow = color.fromRGB(255, 200, 80), chamsFlash = true, chamsMaterial = "Flat", tracer = false,
		tracerFrom = "Bottom", tracerThickness = 1, tracerAlpha = 60, tracerRole = true,
		tracerColour = color.fromRGB(235, 235, 235), offscreen = false, radarStyle = "Arrow", ringRadius = 170,
		arrowSize = 9, ringText = false, fxTargets = "All", glowHalo = 60, glowCore = 85, sparkles = false,
		sparkleStyle = "Sparkles", sparkleRate = 14, skyBeam = false, murderBeam = false, brightness = 100,
		saturation = 100, opacity = 100, lineScale = 100, textScale = 100, rainbowSpeed = 1, rainbowSat = 65,
		murdererFocus = false, focusScale = 160, nearColour = color.fromRGB(255, 107, 107),
		farColour = color.fromRGB(116, 170, 255), seenColour = color.fromRGB(125, 222, 170), boxWidth = 50, boxPad = 0,
		boxColMode = "ESP", boxCol = color.fromRGB(255, 255, 255), boxAnim = "None", boxAnimSpeed = 1,
		boxGradStyle = "Two Color", boxGradAngle = 90, fillStyle = "Solid", fillColMode = "ESP",
		fillCol = color.fromRGB(255, 255, 255), glowSize = 5, glowColMode = "ESP", glowCol = color.fromRGB(255, 255, 255),
		outlineCol = color.fromRGB(0, 0, 0), outlineAlpha = 65, outlineSize = 2, nameWeight = "SemiBold",
		nameCase = "Normal", namePos = "Above", strokeSize = 0, strokeCol = color.fromRGB(5, 8, 13), distUnit = "Studs",
		roleStyle = "Full", plateRadius = 5, plateBorder = 1, plateGrad = false, chamsBright = 100, chamsShell = 100,
		chamsGradA = color.fromRGB(255, 120, 150), chamsGradB = color.fromRGB(110, 160, 255), chamsGradScroll = false,
		boneStyle = "Line", boneAlpha = 100, joints = false, jointSize = 3, boneGrad = false,
		boneTop = color.fromRGB(255, 255, 255), boneBottom = color.fromRGB(160, 170, 190), headStyle = "Ring",
		headFill = 25, headColMode = "ESP", headCol = color.fromRGB(255, 255, 255), lookThick = 1.5, lookColMode = "ESP",
		lookCol = color.fromRGB(255, 255, 255), tracerTo = "Feet", tracerStyle = "Line", tracerMurderer = false,
		arrowPulse = false, arrowName = false, trail = false, trailLife = 0.8, trailWidth = 1, trailStyle = "Fade",
		murdMat = "Same", sheriffMat = "Same", murdBox = "Same", limits = false, boxMaxDist = 0, nameMaxDist = 0,
		chamsMaxDist = 0, skelMaxDist = 0, distScale = false, nameIcon = false, weaponStyle = "Icon", infoBg = false,
		infoBgAlpha = 55, chamsEdgeRole = true, infoLayout = "Under Box", infoFont = "Same", infoCase = "Normal",
		textShadow = false, textOutlineAlpha = 60, outlineInner = false, chamsOverlay = false, markerPos = "Around Center",
		chamsHiddenDark = 30,
	}
	settings.on = configuration.rolesp and configuration.rolesp.on and true or false
	return settings
end

local EspText = {}
local ESP_ROLE_SHORT = {Murderer = "M", Sheriff = "S", Hero = "H", Innocent = "I"}

function EspText.create()
	return {upper = {}, upperCount = 0, distances = {}, distanceCount = 0,
		names = setmetatable({}, {__mode = "k"})}
end

function EspText.upper(state, value)
	if state.upperCount > 3000 then state.upper, state.upperCount = {}, 0 end
	local cached = state.upper[value]
	if cached then return cached end

	local result = string.upper(value)
	if string.find(result, "[\208\209]") then
		local characters = {}
		for _, code in utf8.codes(result) do
			if code >= 1072 and code <= 1103 then code -= 32 end
			if code == 1105 then code = 1025 end
			table.insert(characters, utf8.char(code))
		end
		result = table.concat(characters)
	end
	state.upper[value] = result
	state.upperCount += 1
	return result
end

function EspText.case(state, value, mode)
	if mode == "UPPER" then return EspText.upper(state, value) end
	if mode == "lower" then return string.lower(value) end
	return value
end

function EspText.role(state, role, mode, translate)
	local label = translate(role)
	if mode == "Short" then return ESP_ROLE_SHORT[role] or label:sub(1, 1) end
	if mode == "Upper" then return EspText.upper(state, label) end
	return label
end

function EspText.distance(state, distance, unit)
	local value = math.max(tonumber(distance) or 0, 0)
	local key = math.floor(value + 0.5)
	if unit == "Meters" then
		local meters = value * 0.28
		key = meters < 10 and -(math.floor(meters * 10 + 0.5) + 1) or math.floor(meters + 0.5) + 1000000
	end
	if state.distanceCount > 4000 then state.distances, state.distanceCount = {}, 0 end
	if state.distances[key] then return state.distances[key] end

	local text = tostring(math.floor(value + 0.5)) .. " st"
	if unit == "Meters" then
		local meters = value * 0.28
		text = meters < 10 and string.format("%.1f m", meters) or tostring(math.floor(meters + 0.5)) .. " m"
	end
	state.distances[key] = text
	state.distanceCount += 1
	return text
end

function EspText.clean(value)
	if type(value) ~= "string" then return "" end
	return (value:gsub("[%z\1-\31\127]", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

function EspText.name(state, player, mode)
	local name, display = player.Name, player.DisplayName
	local cached = state.names[player]
	if cached and cached.name == name and cached.display == display and cached.mode == mode then
		return cached.main, cached.second
	end

	local username, displayName = EspText.clean(name), EspText.clean(display)
	if username == "" then username = displayName end
	if username == "" then username = "Player" end
	if displayName == "" then displayName = username end
	local main, second = username, ""
	if mode == "Display name" then main = displayName end
	if mode == "Both" then
		main = displayName
		if displayName ~= username then second = "@" .. username end
	end
	state.names[player] = {name = name, display = display, mode = mode, main = main, second = second}
	return main, second
end

local EspColor = {}
local ESP_ROLE_COLORS = {Murderer = "murdererColour", Sheriff = "sheriffColour", Hero = "heroColour", Innocent = "innocentColour"}

function EspColor.create(environment, settings)
	return {environment = environment, settings = settings, white = environment.Color3.new(1, 1, 1),
		black = environment.Color3.new(0, 0, 0)}
end

function EspColor.key(color)
	return math.floor(color.R * 255 + 0.5) * 65536 + math.floor(color.G * 255 + 0.5) * 256 + math.floor(color.B * 255 + 0.5)
end

function EspColor.tone(state, color)
	local settings = state.settings
	local brightness, saturation = (settings.brightness or 100) / 100, (settings.saturation or 100) / 100
	if brightness == 1 and saturation == 1 then return color end
	if not state.tones or state.brightness ~= brightness or state.saturation ~= saturation then
		state.tones, state.brightness, state.saturation, state.count = {}, brightness, saturation, 0
	end

	local cache, key = state.tones, EspColor.key(color)
	if cache[key] then return cache[key] end
	local hue, sat, value = color:ToHSV()
	local adjusted = value * brightness
	local result = state.environment.Color3.fromHSV(hue, math.clamp(sat * saturation, 0, 1), math.clamp(adjusted, 0, 1))
	if adjusted > 1 then result = result:Lerp(state.white, math.clamp((adjusted - 1) * 0.6, 0, 0.6)) end
	state.count += 1
	if state.count > 4096 then state.tones = nil end
	cache[key] = result
	return result
end

function EspColor.ink(state, source, custom, color)
	if source == "Custom" then return EspColor.tone(state, custom or state.white) end
	if source == "White" then return EspColor.tone(state, state.white) end
	if source == "Light" then return color:Lerp(state.white, 0.45) end
	if source == "Dark" then return color:Lerp(state.black, 0.5) end
	return color
end

function EspColor.roleBase(state, role)
	return state.settings[ESP_ROLE_COLORS[role] or "noRoleColour"]
end

function EspColor.role(state, role)
	return EspColor.tone(state, EspColor.roleBase(state, role))
end

function EspColor.select(state, role, isVisible, distance)
	local settings, environment = state.settings, state.environment
	local color = EspColor.roleBase(state, role)
	if settings.colorMode == "Rainbow" then
		local hue = environment.os.clock() * 0.09 * (settings.rainbowSpeed or 1) % 1
		color = environment.Color3.fromHSV(hue, math.clamp((settings.rainbowSat or 65) / 100, 0, 1), 1)
	end
	if settings.colorMode == "Custom" then color = settings.customColour end
	if settings.colorMode == "Distance" then
		color = settings.nearColour:Lerp(settings.farColour, math.clamp((distance or 0) / math.max(settings.maxDist, 1), 0, 1))
	end
	if settings.colorMode == "Visibility" then color = isVisible and settings.seenColour or settings.hiddenColour end
	if settings.visCheck and settings.dimHidden and not isVisible and settings.hiddenStyle == "Grey" then color = settings.hiddenColour end
	return EspColor.tone(state, color)
end

function EspColor.cham(state, color)
	local brightness = (state.settings.chamsBright or 100) / 100
	if brightness > 1 then return color:Lerp(state.white, math.clamp((brightness - 1) * 0.6, 0, 0.6)) end
	if brightness < 1 then return color:Lerp(state.black, math.clamp(1 - brightness, 0, 0.85)) end
	return color
end

function EspColor.health(state, ratio)
	return state.settings.healthLow:Lerp(state.settings.healthHigh, math.clamp(ratio, 0, 1))
end

local EspBox = {}

function EspBox.create(context, parent, playerId)
	local environment = context.environment
	local function create(class, properties, owner)
		local object = environment.Instance.new(class)
		for key, value in properties do object[key] = value end
		object.Parent = owner
		return object
	end
	local function frame(owner, name, level)
		return create("Frame", {Name = name, BackgroundTransparency = 1, BorderSizePixel = 0,
			Active = false, Visible = false, ZIndex = level}, owner)
	end
	local function stroke(owner, thickness)
		return create("UIStroke", {Thickness = thickness, Color = environment.Color3.new(0, 0, 0),
			ApplyStrokeMode = environment.Enum.ApplyStrokeMode.Border, Transparency = 1}, owner)
	end
	local layer = frame(parent, "Player_" .. tostring(playerId), 2)
	layer.Size = environment.UDim2.fromScale(1, 1)
	local box, glow, outer = frame(layer, "Box", 3), frame(layer, "Glow", 2), frame(layer, "BoxOutline", 2)
	local edge = stroke(box, 1.5)
	local result = {layer = layer, box = box, edge = edge, glow = glow, outer = outer,
		fillGradient = create("UIGradient", {Rotation = 90}, box),
		edgeGradient = create("UIGradient", {Rotation = 90}, edge),
		round = create("UICorner", {CornerRadius = environment.UDim.new(0, 0)}, box),
		glowStroke = stroke(glow, 6), glowRound = create("UICorner", {}, glow),
		outerStroke = stroke(outer, 3.5), outerRound = create("UICorner", {}, outer),
		corners = {}, cornerGlow = {}, cornerEdge = {}}
	result.make = create
	result.frame = frame
	result.stroke = stroke
	EspBox.grow(context, result, 8)
	return result
end

function EspBox.grow(context, box, count)
	for index = #box.corners + 1, count do
		local function line(name, level)
			local frame = box.frame(box.layer, name, level)
			frame.AnchorPoint = context.environment.Vector2.new(0.5, 0.5)
			return {frame = frame, stroke = box.stroke(frame, 1)}
		end
		box.corners[index] = line("Corner" .. index, 4)
		box.cornerGlow[index] = line("CornerGlow" .. index, 2)
		box.cornerEdge[index] = box.frame(box.layer, "CornerEdge" .. index, 3)
	end
end

function EspBox.hideSegments(box, first)
	for index = first, #box.corners do
		box.corners[index].frame.Visible = false
		box.cornerGlow[index].frame.Visible = false
		box.cornerEdge[index].Visible = false
	end
end

function EspBox.sequence(context, first, second)
	local state, settings = context.colors, context.settings
	local isRoleFade = settings.boxGradStyle == "Role Fade"
	local key = isRoleFade and -EspColor.key(first) - 1 or EspColor.key(first) * 16777216 + EspColor.key(second)
	context.boxSequences = context.boxSequences or {}
	if context.boxSequences[key] then return context.boxSequences[key] end

	local colorSequence = context.environment.ColorSequence
	local result = isRoleFade and colorSequence.new(first:Lerp(state.white, 0.25), first) or colorSequence.new(first, second)
	context.boxSequenceCount = (context.boxSequenceCount or 0) + 1
	if context.boxSequenceCount > 512 then context.boxSequences, context.boxSequenceCount = {}, 0 end
	context.boxSequences[key] = result
	return result
end

function EspBox.animation(context, player)
	local settings = context.settings
	if settings.boxAnim ~= "Pulse" and settings.boxAnim ~= "Breathe" then return 1, 0 end
	local time = context.environment.os.clock() * (settings.boxAnimSpeed or 1) + (player and player.UserId % 89 * 0.37 or 0)
	if settings.boxAnim == "Pulse" then return 0.7 + 0.3 * (0.5 + 0.5 * math.sin(time * 4.2)), 0 end
	return 1, 0.5 + 0.5 * math.sin(time * 2.6)
end

function EspBox.inner(context, box)
	if box.inner then return box.inner end
	box.inner = box.frame(box.layer, "BoxInner", 3)
	box.innerStroke = box.stroke(box.inner, 1)
	box.innerRound = box.make("UICorner", {}, box.inner)
	box.innerGrad = box.make("UIGradient", {Rotation = 90}, box.innerStroke)
	return box.inner
end

function EspBox.quantize(value)
	return math.floor(value * 200 + 0.5) / 200
end

function EspBox.fill(context, box, base, gradient, opacity)
	local environment, settings = context.environment, context.settings
	local color = EspColor.ink(context.colors, settings.fillColMode, settings.fillCol, base)
	local second = settings.gradient and gradient or color
	local key = (settings.gradient and 1 or 2) * 1000000000000000 + EspColor.key(color) * 16777216 + EspColor.key(second)
	if box.fillKey ~= key or box.fillGS ~= settings.boxGradStyle then
		box.fillKey, box.fillGS = key, settings.boxGradStyle
		box.fillGradient.Color = settings.gradient and EspBox.sequence(context, color, second) or environment.ColorSequence.new(color)
	end
	local style = settings.fillStyle or "Solid"
	if box.fillStyleOn == style then return end
	box.fillStyleOn = style
	local sequence = environment.NumberSequence
	local fills = {Solid = function() return sequence.new(0) end,
		["Fade Down"] = function() return sequence.new(0, 1) end,
		["Fade Up"] = function() return sequence.new(1, 0) end}
	box.fillGradient.Transparency = (fills[style] or fills.Solid)()
	box.fillGradient.Rotation = 90
end

function EspBox.edge(context, box, base, gradient, opacity, thickness, rotation)
	local environment, settings = context.environment, context.settings
	local key = EspColor.key(base) * 16777216 + EspColor.key(gradient)
	if box.edgeKey ~= key or box.edgeGS ~= settings.boxGradStyle or box.edgeG ~= settings.gradient then
		box.edgeKey, box.edgeGS, box.edgeG = key, settings.boxGradStyle, settings.gradient
		box.edgeGradient.Color = settings.gradient and EspBox.sequence(context, base, gradient) or environment.ColorSequence.new(base)
		if box.innerGrad then box.innerGrad.Color = box.edgeGradient.Color end
	end
	local fade = settings.gradient and settings.boxGradStyle == "Role Fade"
	if box.edgeFade ~= fade then
		box.edgeFade = fade
		box.edgeGradient.Transparency = fade and environment.NumberSequence.new(0, 0.7) or environment.NumberSequence.new(0)
	end
	box.edgeGradient.Rotation = rotation
	box.edge.Color = context.colors.white
	box.edge.Thickness = math.clamp(thickness, 0.5, 8)
	box.edge.Transparency = EspBox.quantize(1 - opacity)
end

function EspBox.innerStyle(context, box, rect, style, opacity, thickness, rotation, hasOutline)
	local environment, settings = context.environment, context.settings
	local offset, stroke = 0, box.innerStroke
	if style == "Double" then
		EspBox.inner(context, box)
		stroke = box.innerStroke
		box.innerGrad.Color = box.edgeGradient.Color
		offset = math.floor(thickness + 2.5)
		box.innerRound.CornerRadius = environment.UDim.new(0, math.max(0, math.clamp(settings.boxRound, 0, 20) - offset))
		stroke.Color = context.colors.white
		stroke.Thickness = math.max(1, thickness * 0.6)
		stroke.Transparency = EspBox.quantize(1 - opacity * 0.45)
		box.innerGrad.Rotation = rotation
	end
	if style ~= "Double" and hasOutline then
		EspBox.inner(context, box)
		stroke = box.innerStroke
		box.innerGrad.Color = environment.ColorSequence.new(context.colors.white)
		offset = math.max(1, math.floor((settings.outlineSize or 1) * 0.5 + 0.5))
		local radius = style == "Rounded" and math.max(0, math.clamp(settings.boxRound, 0, 20) - offset) or 0
		box.innerRound.CornerRadius = environment.UDim.new(0, radius)
		stroke.Color = settings.outlineCol or context.colors.black
		stroke.Thickness = offset
		stroke.Transparency = EspBox.quantize(1 - opacity * math.clamp((settings.outlineAlpha or 65) / 100, 0, 1))
	end
	box.inner.Position = environment.UDim2.fromOffset(rect.x + offset, rect.y + offset)
	box.inner.Size = environment.UDim2.fromOffset(math.max(2, rect.w - offset * 2), math.max(2, rect.h - offset * 2))
	box.inner.Visible = true
end

function EspBox.segments(context, box, rectangle, thickness, style)
	local x, y, width, height = rectangle.x, rectangle.y, rectangle.w, rectangle.h
	local line = math.max(1, math.floor(thickness + 0.5))
	local length = math.min(math.max(math.min(width, height) * math.clamp(context.settings.cornerSize, 5, 50) / 100, 4), math.min(width, height) * 0.45)
	length = math.max(line + 1, math.floor(length + 0.5))
	local segments
	if style == "Corners" then
		segments = {{x, y, length, line}, {x, y, line, length}, {x + width - length, y, length, line},
			{x + width - line, y, line, length}, {x, y + height - line, length, line}, {x, y + height - length, line, length},
			{x + width - length, y + height - line, length, line}, {x + width - line, y + height - length, line, length}}
	end
	if style == "Brackets" then
		local endWidth = math.max(line + 1, math.floor(math.min(length, width * 0.3) + 0.5))
		segments = {{x, y, line, height}, {x, y, endWidth, line}, {x, y + height - line, endWidth, line},
			{x + width - line, y, line, height}, {x + width - endWidth, y, endWidth, line},
			{x + width - endWidth, y + height - line, endWidth, line}}
	end
	box.segs = box.segs or {}
	for index, values in segments do
		local entry = box.segs[index] or {}
		entry[1], entry[2], entry[3], entry[4] = values[1], values[2], values[3], values[4]
		box.segs[index] = entry
	end
	EspBox.grow(context, box, #segments)
	EspBox.hideSegments(box, #segments + 1)
end

function EspBox.draw(context, box, rectangle, color, alpha, player, focus)
	local environment, settings = context.environment, context.settings
	local style = settings.boxStyle or "Corners"
	if box.role == "Murderer" and settings.murdBox and settings.murdBox ~= "Same" then style = settings.murdBox end
	local isVisible = settings.box == true and not box.boxOff
	local segmented = style == "Corners" or style == "Brackets"
	local full = isVisible and not segmented
	local glow = settings.boxGlow == true or focus == true
	local innerOutline = full and style ~= "Double" and settings.outline == true and settings.outlineInner == true
	if not isVisible or not segmented then EspBox.hideSegments(box, 1) end
	if box.inner and not (full and (style == "Double" or innerOutline)) then box.inner.Visible = false end
	box.box.Visible, box.glow.Visible, box.outer.Visible = isVisible, full and glow, full and settings.outline
	if not isVisible then return end

	local animation, expansion = EspBox.animation(context, player)
	local extra = expansion > 0 and math.floor(expansion * 2 + 0.5) or 0
	local padding = math.floor(tonumber(settings.boxPad) or 0)
	local rect = {x = rectangle.x - extra, y = rectangle.y - extra, w = rectangle.w + extra * 2, h = rectangle.h + extra * 2}
	if padding ~= 0 then
		rect = {x = rect.x - padding, y = rect.y - padding, w = math.max(4, rect.w + padding * 2), h = math.max(4, rect.h + padding * 2)}
	end
	local opacity = alpha * animation
	local base = EspColor.ink(context.colors, settings.boxColMode, settings.boxCol, color)
	local gradient = settings.gradient and EspColor.tone(context.colors, settings.gradientColour) or base
	local thickness = (tonumber(settings.boxThickness) or 1) * (settings.lineScale or 100) / 100 * (context.lineWidthFactor or 1)
	if focus then thickness *= (settings.focusScale or 160) / 100 end
	local position, size = environment.UDim2.fromOffset(rect.x, rect.y), environment.UDim2.fromOffset(rect.w, rect.h)
	box.box.Position, box.box.Size = position, size
	local radius = (style == "Rounded" or style == "Double") and math.clamp(settings.boxRound, 0, 20) or 0
	local corner = environment.UDim.new(0, radius)
	box.round.CornerRadius, box.glowRound.CornerRadius, box.outerRound.CornerRadius = corner, corner, corner
	local rotation = math.floor(settings.boxGradAngle or 90) % 360
	if full and settings.outline then
		box.outer.Position, box.outer.Size = position, size
		box.outerStroke.Color = settings.outlineCol or context.colors.black
		box.outerStroke.Thickness = thickness + (settings.outlineSize or 2)
		box.outerStroke.Transparency = EspBox.quantize(1 - opacity * math.clamp((settings.outlineAlpha or 65) / 100, 0, 1))
	end
	box.box.BackgroundColor3 = context.colors.white
	box.box.BackgroundTransparency = settings.boxFill and EspBox.quantize(1 - math.clamp(settings.boxFillAlpha / 100, 0, 1) * opacity) or 1
	if settings.boxFill then EspBox.fill(context, box, base, gradient, opacity) end
	if full then EspBox.edge(context, box, base, gradient, opacity, thickness, rotation) end
	if not full then box.edge.Transparency = 1 end
	if full and glow then EspBox.glow(context, box, position, size, base, opacity, thickness, focus) end
	if full and (style == "Double" or innerOutline) then EspBox.innerStyle(context, box, rect, style, opacity, thickness, rotation, innerOutline) end
	if segmented then EspBox.segments(context, box, rect, thickness, style) end
end

function EspBox.glow(context, box, position, size, base, opacity, thickness, focus)
	local settings = context.settings
	local pulse = settings.pulse and 0.72 + math.sin(context.environment.os.clock() * settings.pulseSpeed * math.pi * 2) * 0.28 or 1
	if focus and not settings.pulse then pulse = 0.75 + math.sin(context.environment.os.clock() * 5) * 0.25 end
	local strength = math.clamp(settings.glowStrength / 100, 0, 0.6)
	if focus and not settings.boxGlow then strength = 0.3 end
	box.glow.Position, box.glow.Size = position, size
	box.glowStroke.Color = EspColor.ink(context.colors, settings.glowColMode, settings.glowCol, base)
	box.glowStroke.Thickness = thickness + (settings.glowSize or 5) * (settings.lineScale or 100) / 100 * (context.lineWidthFactor or 1)
	box.glowStroke.Transparency = EspBox.quantize(1 - opacity * strength * pulse)
end

local EspRole = {}

function EspRole.create(clock)return {clock=clock,parts=setmetatable({},{__mode="k"})}end
function EspRole.of()return nil end
function EspRole.shown()return true end
function EspRole.weaponOf(state,player)
    local tool=player.Character and player.Character:FindFirstChildOfClass("Tool")
    return tool and tool.Name or nil,tool~=nil
end
function EspRole.partsOf(state, character)
	local now, parts = state.clock(), state.parts[character]
	if parts and parts.root and parts.hum then
		if now - parts.at < 1 and parts.root.Parent == character and parts.hum.Parent == character then return parts end
	end
	if parts and (not parts.root or not parts.hum) and now - parts.at < 0.25 then return parts end
	parts = parts or {}
	parts.at = now
	parts.hum = character:FindFirstChildOfClass("Humanoid")
	parts.root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	parts.head = character:FindFirstChild("Head") or parts.root
	state.parts[character] = parts
	return parts
end

local EspProjection = {}

function EspProjection.create(environment)
	return {environment = environment, bounds = setmetatable({}, {__mode = "k"}), partKinds = {}}
end

function EspProjection.bounds(state, character, root)
	local now, bounds = state.environment.os.clock(), state.bounds[character]
	if bounds and now - bounds.at <= 0.15 then return bounds.top, bounds.bottom end

	local top, bottom
	for _, part in character:GetChildren() do
		local isPart = state.partKinds[part.ClassName]
		if isPart == nil then
			isPart = part:IsA("BasePart")
			state.partKinds[part.ClassName] = isPart
		end
		if not isPart then continue end
		local half, position = part.Size.Y * 0.5, part.Position.Y
		local high, low = position + half, position - half
		top = top and math.max(top, high) or high
		bottom = bottom and math.min(bottom, low) or low
	end

	local y = root.Position.Y
	bounds = {at = now, top = (top or y + 3) - y, bottom = (bottom or y - 3) - y}
	state.bounds[character] = bounds
	return bounds.top, bounds.bottom
end

function EspProjection.point(state, camera, position)
	local projection = state.projection
	if projection and projection.enabled then
		local point = projection.frame:PointToObjectSpace(position)
		local depth = -point.Z
		if depth > 0.08 then
			return state.environment.Vector3.new(projection.centerX + point.X / depth * projection.focal,
				projection.centerY - point.Y / depth * projection.focal, depth)
		end
	end
	return camera:WorldToViewportPoint(position)
end

function EspProjection.project(state, character, root, camera, boxWidth)
	local top, bottom = EspProjection.bounds(state, character, root)
	local position = root.Position
	local vector = state.environment.Vector3
	local upper = EspProjection.point(state, camera, vector.new(position.X, position.Y + top + 0.12, position.Z))
	local lower = EspProjection.point(state, camera, vector.new(position.X, position.Y + bottom - 0.08, position.Z))
	if upper.Z <= 0.08 or lower.Z <= 0.08 then return nil end

	local viewport = camera.ViewportSize
	local height = math.abs(lower.Y - upper.Y)
	if height < 2 or height > viewport.Y * 4 then return nil end
	local width = height * math.clamp((boxWidth or 50) / 100, 0.2, 1)
	local x, y = (upper.X + lower.X) * 0.5 - width * 0.5, math.min(upper.Y, lower.Y)
	if x + width < 0 or x > viewport.X or y + height < 0 or y > viewport.Y then return nil end
	if width < 12 then x, width = x - (12 - width) * 0.5, 12 end
	if height < 22 then y, height = y - (22 - height) * 0.5, 22 end
	return {x = x, y = y, w = width, h = height}
end

function EspProjection.smooth(record, rectangle, viewport, smooth, delta, center)
	local factor = math.clamp(smooth, 0, 95) / 100
	local alpha = factor > 0 and 1 - factor ^ (math.clamp(delta or 1 / 60, 0.001, 0.1) * 60) or 1
	center = center or {X = rectangle.x + rectangle.w * 0.5, Y = rectangle.y + rectangle.h * 0.5}
	local relative = {x = rectangle.x - center.X, y = rectangle.y - center.Y, w = rectangle.w, h = rectangle.h}
	local previous = record.rect and record.rel
	if previous then
		local difference = math.abs(relative.x - previous.x) + math.abs(relative.y - previous.y)
			+ math.abs(relative.w - previous.w) + math.abs(relative.h - previous.h)
		if difference < math.max(viewport.X, viewport.Y) * 0.35 then
			for _, key in {"x", "y", "w", "h"} do relative[key] = previous[key] + (relative[key] - previous[key]) * alpha end
		end
	end

	record.rel = relative
	record.rect = {x = center.X + relative.x, y = center.Y + relative.y, w = relative.w, h = relative.h}
	local value = record.rect
	return {x = math.floor(value.x + 0.5), y = math.floor(value.y + 0.5),
		w = math.max(1, math.floor(value.w + 0.5)), h = math.max(1, math.floor(value.h + 0.5))}
end

function EspProjection.inView(state, camera, position)
	if (position - camera.CFrame.Position).Magnitude <= 12 then return true end
	local point, viewport = EspProjection.point(state, camera, position), camera.ViewportSize
	local marginX, marginY = viewport.X * 0.35, viewport.Y * 0.35
	return not (point.Z < -6 or point.X < -marginX or point.X > viewport.X + marginX
		or point.Y < -marginY or point.Y > viewport.Y + marginY), point
end

function EspProjection.alpha(settings, distance, isVisible)
	local alpha = settings.visCheck and settings.dimHidden and not isVisible and settings.hiddenStyle ~= "Grey" and 0.72 or 1
	if settings.fade then
		local start = settings.maxDist * math.clamp(settings.fadeFrom, 10, 95) / 100
		if distance > start then alpha *= math.clamp(1 - (distance - start) / math.max(settings.maxDist - start, 1), 0.45, 1) end
	end
	return alpha * math.clamp((settings.opacity or 100) / 100, 0.05, 1)
end

function EspProjection.visible(context, origin, target, character)
	local environment, workspace = context.environment, context.workspace
	local parameters = environment.RaycastParams.new()
	parameters.FilterType = environment.Enum.RaycastFilterType.Exclude
	local ignored = {character, workspace.CurrentCamera}
	if context.player.Character then table.insert(ignored, context.player.Character) end
	parameters.FilterDescendantsInstances = ignored
	parameters.IgnoreWater = true
	local direction = target.Position - origin
	if direction.Magnitude < 0.05 then return true end

	for _ = 1, 6 do
		local hit = workspace:Raycast(origin, direction, parameters)
		if not hit then return true end
		if hit.Instance.Transparency < 0.3 then return false end
		table.insert(ignored, hit.Instance)
		parameters.FilterDescendantsInstances = ignored
	end
	return false
end

local EspLabel = {}
local ESP_FONT_ENUM = {
	Fredoka = "FredokaOne", ["Luckiest Guy"] = "LuckiestGuy", Bangers = "Bangers", Cartoon = "Cartoon", Arcade = "Arcade",
	["Sci-Fi"] = "SciFi", Michroma = "Michroma", Jura = "Jura", Sarpanch = "Sarpanch", Oswald = "Oswald", Ubuntu = "Ubuntu",
	Nunito = "Nunito", Roboto = "Roboto", ["Roboto Condensed"] = "RobotoCondensed", Titillium = "TitilliumWeb",
	["Builder Sans"] = "BuilderSans", Arimo = "Arimo", Highway = "Highway", ["Denk One"] = "DenkOne", Creepster = "Creepster",
	["Permanent Marker"] = "PermanentMarker", Kalam = "Kalam", ["Indie Flower"] = "IndieFlower", ["Patrick Hand"] = "PatrickHand",
	Amatic = "AmaticSC", ["Special Elite"] = "SpecialElite", ["Grenze Gotisch"] = "GrenzeGotisch", Bodoni = "Bodoni",
	Merriweather = "Merriweather", Garamond = "Garamond", Antique = "Antique", Fantasy = "Fantasy", Montserrat = "Montserrat",
	Code = "RobotoMono", ["Source Sans"] = "SourceSans",
}

function EspLabel.root(state)
	if state.labelGui and state.labelGui.Parent then return state.labelGui end
	local context, environment = state.context, state.context.environment
	local holder = context.coreGui
	if not holder or not holder.Parent then holder = context.player:FindFirstChildOfClass("PlayerGui") end
	if not holder then return nil end
	local gui = environment.Instance.new("ScreenGui")
	gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn = "PulseESP2Text", true, false
	gui.DisplayOrder, gui.ZIndexBehavior = 10, environment.Enum.ZIndexBehavior.Sibling
	gui.Parent = holder
	state.labelGui, state.labels = gui, {}
	return gui
end

function EspLabel.create(state, player)
	local gui = EspLabel.root(state)
	if not gui then return nil end
	local environment = state.context.environment
	local function create(class, properties, parent)
		local object = environment.Instance.new(class)
		for key, value in properties do object[key] = value end
		object.Parent = parent
		return object
	end
	local function frame(name)
		return create("Frame", {Name = name, BorderSizePixel = 0, BackgroundTransparency = 1,
			Active = false, Visible = false}, gui)
	end
	local function label(parent, name)
		local enum = environment.Enum
		return create("TextLabel", {Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
			RichText = false, TextScaled = false, TextWrapped = false, TextTruncate = enum.TextTruncate.AtEnd,
			TextXAlignment = enum.TextXAlignment.Center, TextYAlignment = enum.TextYAlignment.Center,
			TextStrokeColor3 = environment.Color3.fromRGB(5, 8, 13), Text = "", ZIndex = 3}, parent)
	end
	local top, bottom = frame("Name_" .. tostring(player.UserId)), frame("Info_" .. tostring(player.UserId))
	local weaponShadow = create("ImageLabel", {Name = "WeaponShadow", BackgroundTransparency = 1, BorderSizePixel = 0,
		ScaleType = environment.Enum.ScaleType.Fit, ImageColor3 = state.colors.black, Visible = false, ZIndex = 2}, bottom)
	local weapon = create("ImageLabel", {Name = "Weapon", BackgroundTransparency = 1, BorderSizePixel = 0,
		ScaleType = environment.Enum.ScaleType.Fit, Visible = false, ZIndex = 3}, bottom)
	local result = {top = top, bottom = bottom, name = label(top, "Name"), handle = label(top, "Username"),
		role = label(bottom, "Role"), distance = label(bottom, "Distance"), weaponText = label(bottom, "wtext"),
		weapon = weapon, weaponShadow = weaponShadow,
		measures = {}, createLabel = label}
	state.labels[player] = result
	return result
end

function EspLabel.font(state, name, weight)
	local environment = state.context.environment
	local enum, font = environment.Enum, environment.Font
	state.fontFaces = state.fontFaces or {}
	state.fontFaces[name] = state.fontFaces[name] or {}
	local key = weight or enum.FontWeight.Medium
	if state.fontFaces[name][key] then return state.fontFaces[name][key] end

	local families = {Gotham = "GothamSSm", GothamSSm = "GothamSSm", Code = "RobotoMono",
		["Source Sans"] = "SourceSansPro", Montserrat = "Montserrat"}
	local family, result = families[name], nil
	if not family and ESP_FONT_ENUM[name] then
		local ok, face = pcall(function() return font.fromEnum(enum.Font[ESP_FONT_ENUM[name]]) end)
		if ok and face then
			result = face
			if weight then
				local made, weighted = pcall(font.new, face.Family, weight)
				if made and weighted then result = weighted end
			end
		end
	end
	if not result and (family or not ESP_FONT_ENUM[name]) then
		local ok, face = pcall(font.new, "rbxasset://fonts/families/" .. (family or "GothamSSm") .. ".json", key)
		if ok then result = face end
	end
	result = result or font.fromEnum(enum.Font.GothamMedium)
	state.fontFaces[name][key] = result
	return result
end

function EspLabel.metricFont(state, name)
	local enum = state.context.environment.Enum
	local ok, value = pcall(function()
		local id = ESP_FONT_ENUM[name]
		return id and enum.Font[id]
	end)
	return ok and value or enum.Font.GothamMedium
end

function EspLabel.measure(state, labels, key, text, size, font, limit)
	local cached = labels.measures[key]
	if cached and cached.text == text and cached.size == size and cached.font == font and cached.limit == limit then
		return cached.width, cached.height
	end
	local context, environment = state.context, state.context.environment
	local ok, result = pcall(function()
		return context.textService:GetTextSize(text, size, font, environment.Vector2.new(100000, 100000))
	end)
	local width = ok and math.ceil(result.X) or math.min(limit, #text * size * 0.55)
	local height = ok and math.ceil(result.Y) or size + 3
	width, height = math.min(math.max(width + 2, 1), limit), math.max(height + 2, size + 3)
	labels.measures[key] = {text = text, size = size, font = font, limit = limit, width = width, height = height}
	return width, height
end

function EspLabel.position(state, frame, rect, width, height, y)
	local environment = state.context.environment
	local viewport = state.viewport
	local center = rect.x + rect.w * 0.5
	local x = math.clamp(center - width * 0.5, 4, math.max(4, viewport.X - 4 - width))
	y = math.clamp(y, 4, math.max(4, viewport.Y - 4 - height))
	frame.Position = environment.UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	frame.Size, frame.Visible = environment.UDim2.fromOffset(width, height), true
	return y
end

function EspLabel.text(state, label, options)
	local environment, settings = state.context.environment, state.settings
	label.Visible = options.text ~= ""
	if options.text == "" then return end
	label.Text, label.FontFace, label.TextSize = options.text, options.font, options.size
	label.TextColor3, label.TextTransparency = options.color, 1 - options.opacity
	local outline = settings.textOutline == false and 1 or EspBox.quantize(1 - options.opacity * math.clamp((tonumber(settings.textOutlineAlpha) or 60) / 100, 0, 1))
	label.TextStrokeTransparency = outline
	label.Position = environment.UDim2.fromOffset(options.x, options.y)
	label.Size = environment.UDim2.fromOffset(options.width, options.height)
end

function EspLabel.name(state, labels, player, rectangle, infoY, style)
	local settings, environment = state.settings, state.context.environment
	if not settings.name then labels.top.Visible = false; return infoY end
	local main, handle = EspText.name(state.text, player, settings.nameMode)
	main = EspText.case(state.text, main, settings.nameCase)
	if handle ~= "" then handle = EspText.case(state.text, handle, settings.nameCase) end
	local available = math.max(1, style.limit - 4)
	local nameWidth, nameHeight = EspLabel.measure(state, labels, "name", main, style.nameSize, style.metricFont, available)
	local handleWidth, handleHeight = 0, 0
	if handle ~= "" then handleWidth, handleHeight = EspLabel.measure(state, labels, "handle", handle, style.infoSize, style.metricFont, available) end
	local width, height = math.min(style.limit, math.max(nameWidth, handleWidth) + 4), nameHeight + handleHeight
	local y = rectangle.y - (tonumber(settings.nameOffset) or 3) - height
	if settings.namePos == "Below" then y = infoY end
	local placed = EspLabel.position(state, labels.top, rectangle, width, height, y)
	labels.top.BackgroundColor3 = EspColor.tone(state.colors, settings.plateColour)
	labels.top.BackgroundTransparency = 1
	local weights = environment.Enum.FontWeight
	local font = EspLabel.font(state, settings.textFont, weights[settings.nameWeight or "SemiBold"] or weights.SemiBold)
	EspLabel.text(state, labels.name, {text = main, font = font, size = style.nameSize, color = style.nameColor,
		opacity = style.opacity, x = 2, y = 0, width = math.max(1, width - 4), height = nameHeight})
	EspLabel.text(state, labels.handle, {text = handle, font = EspLabel.font(state, settings.textFont, weights.Medium),
		size = style.infoSize, color = style.infoColor, opacity = style.opacity, x = 2, y = nameHeight,
		width = math.max(1, width - 4), height = handleHeight})
	if settings.namePos == "Below" then return placed + height + 2 end
	return infoY
end

function EspLabel.info(state, labels, rectangle, infoY, data, style)
	local settings, environment = state.settings, state.context.environment
	local scale = math.clamp(rectangle.h / 110, 0.75, 1)
	local textSize = math.max(math.floor((style.infoSize + 1) * scale + 0.5), 9)
	local iconSize, gap = math.max(math.floor((style.infoSize + 4) * scale + 0.5), 11), math.max(math.floor(5 * scale + 0.5), 3)
	local entries = {}
	if data.ghostTag then
		if not labels.ghost then labels.ghost = labels.createLabel(labels.bottom, "ghost") end
		local ghost = data.ghostTag
		if settings.infoCase == "UPPER" then ghost = EspText.upper(state.text, ghost) end
		table.insert(entries, {kind = "ghost", text = ghost, color = data.roleColor:Lerp(state.colors.white, 0.2), padding = 12})
	end
	if settings.roleText and data.role then
		local role = EspText.role(state.text, data.role, settings.roleStyle, state.context.translation.tr)
		if settings.infoCase == "UPPER" then role = EspText.upper(state.text, role) end
		table.insert(entries, {kind = "role", text = role, color = data.roleColor:Lerp(state.colors.white, 0.2)})
	end
	if settings.weaponIcon and data.weapon and settings.weaponStyle ~= "Text" then
		table.insert(entries, {kind = "weapon", icon = data.weapon == "Knife" and "sword" or "crosshair", color = data.roleColor, dim = not data.equipped})
	end
	if settings.weaponIcon and data.weapon and settings.weaponStyle ~= "Icon" then
		local weapon = state.context.translation.tr(data.weapon)
		if settings.infoCase == "UPPER" then weapon = EspText.upper(state.text, weapon) end
		local color = data.equipped and data.roleColor:Lerp(state.colors.white, 0.2)
			or data.roleColor:Lerp(environment.Color3.fromRGB(188, 188, 188), 0.5)
		table.insert(entries, {kind = "weaponText", text = weapon, color = color})
	end
	if settings.distance and type(data.distance) == "number" then
		local distance = EspText.distance(state.text, data.distance, settings.distUnit)
		if settings.infoCase == "UPPER" then distance = EspText.upper(state.text, distance) end
		table.insert(entries, {kind = "distance", text = distance, color = style.infoColor})
	end
	local total, height = 0, 0
	for index, entry in entries do
		if entry.text then
			entry.width, entry.height = EspLabel.measure(state, labels, entry.kind, entry.text, textSize, style.metricFont, style.limit)
			if entry.padding then entry.width = math.min(entry.width + entry.padding, style.limit) end
		end
		if entry.icon then entry.width, entry.height = iconSize, iconSize end
		total += entry.width + (index > 1 and gap or 0)
		height = math.max(height, entry.height)
	end
	labels.role.Visible, labels.distance.Visible, labels.weaponText.Visible = false, false, false
	labels.weapon.Visible, labels.weaponShadow.Visible = false, false
	if labels.ghost then labels.ghost.Visible = false end
	if total <= 0 or height <= 0 then labels.bottom.Visible = false; return end
	EspLabel.position(state, labels.bottom, rectangle, total, height, infoY - 1)
	local x = 0
	for _, entry in entries do
		local y = math.floor((height - entry.height) * 0.5 + 0.5)
		if entry.text then
			local label = labels[entry.kind]
			EspLabel.text(state, label, {text = entry.text, font = EspLabel.font(state, settings.textFont, environment.Enum.FontWeight.SemiBold),
				size = textSize, color = entry.color, opacity = style.opacity, x = x, y = y, width = entry.width, height = entry.height})
		end
		if entry.icon then EspLabel.icon(state, labels, entry, style.opacity, x, y) end
		x += entry.width + gap
	end
end

function EspLabel.icon(state, labels, entry, opacity, x, y)
	local environment = state.context.environment
	local icon, shadow = labels.weapon, labels.weaponShadow
	if labels.icon ~= entry.icon then
		labels.icon = entry.icon
		pcall(function() state.context.nova.Icons.apply(icon, entry.icon) end)
		shadow.Image, shadow.ImageRectOffset, shadow.ImageRectSize = icon.Image, icon.ImageRectOffset, icon.ImageRectSize
	end
	local strength = entry.dim and 0.72 or 1
	icon.Position, icon.Size = environment.UDim2.fromOffset(x, y), environment.UDim2.fromOffset(entry.width, entry.height)
	icon.ImageColor3, icon.ImageTransparency, icon.Visible = entry.color, EspBox.quantize(1 - opacity * strength), true
	shadow.Position, shadow.Size = environment.UDim2.fromOffset(x + 1, y + 1), environment.UDim2.fromOffset(entry.width, entry.height)
	shadow.ImageTransparency, shadow.Visible = EspBox.quantize(1 - opacity * 0.7 * strength), state.settings.textOutline ~= false
end

function EspLabel.update(state, player, rectangle, data)
	if data.alpha <= 0 or state.viewport.X < 12 or state.viewport.Y < 12 then EspLabel.hide(state, player); return end
	local labels = state.labels[player]
	if not labels or not labels.top.Parent then labels = EspLabel.create(state, player) end
	if not labels then return end
	local settings, environment = state.settings, state.context.environment
	local opacity = EspBox.quantize(math.clamp(0.35 + math.clamp(data.alpha, 0, 1) * 0.65, 0, 1))
	local function textSize(value) return math.max(6, math.floor(value * (settings.textScale or 100) / 100 + 0.5)) end
	local style = {opacity = opacity, nameSize = textSize(math.clamp(tonumber(settings.textSize) or 12, 9, 28)) + (data.focus and 2 or 0),
		infoSize = textSize(math.clamp(tonumber(settings.infoSize) or 10, 8, 24)),
		limit = math.min(math.max(tonumber(settings.labelWidth) or 240, 40), math.max(1, state.viewport.X - 8)),
		metricFont = EspLabel.metricFont(state, settings.textFont)}
	style.nameColor = settings.textMatch and data.color or EspColor.tone(state.colors, settings.nameColour)
	style.infoColor = settings.textMatch and data.color or EspColor.tone(state.colors, settings.infoColour)
	local infoY = EspLabel.name(state, labels, player, rectangle, rectangle.y + rectangle.h + 5, style)
	EspLabel.info(state, labels, rectangle, infoY, data, style)
end

function EspLabel.gameNames(state)
	local player, settings = state.context.player, state.settings
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if settings.on and settings.name and settings.hideGameNames then
		if state.savedNameDistance == nil then
			local distance = humanoid and humanoid.NameDisplayDistance or player.NameDisplayDistance
			state.savedNameDistance = distance and distance > 0 and distance or 100
		end
		if player.NameDisplayDistance ~= 0 then pcall(function() player.NameDisplayDistance = 0 end) end
		if humanoid and humanoid.NameDisplayDistance ~= 0 then pcall(function() humanoid.NameDisplayDistance = 0 end) end
		return
	end
	EspLabel.restoreNames(state)
end

function EspLabel.restoreNames(state)
	if state.savedNameDistance == nil then return end
	local player, distance = state.context.player, state.savedNameDistance
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	pcall(function() player.NameDisplayDistance = distance end)
	if humanoid then pcall(function() humanoid.NameDisplayDistance = distance end) end
	state.savedNameDistance = nil
end

function EspLabel.hide(state, player)
	local labels = state.labels[player]
	if not labels then return end
	labels.top.Visible, labels.bottom.Visible = false, false
end

function EspLabel.release(state, player)
	local labels = state.labels[player]
	if not labels then return end
	pcall(function() labels.top:Destroy() end)
	pcall(function() labels.bottom:Destroy() end)
	state.labels[player] = nil
end

local EspLine = {}

function EspLine.create(context, object, name, level)
	local frame = object.frame(object.layer, name, level or 4)
	frame.AnchorPoint = context.environment.Vector2.new(0.5, 0.5)
	return {frame = frame, stroke = object.stroke(frame, 1)}
end

function EspLine.draw(context, line, options)
	local environment, settings = context.environment, context.settings
	local from, to = options.from, options.to
	local dx, dy = to.X - from.X, to.Y - from.Y
	local length = math.sqrt(dx * dx + dy * dy)
	local precision = length < 60 and 1 or 4
	line.frame.Position = environment.UDim2.fromOffset(math.floor((from.X + to.X) * 0.5 + 0.5), math.floor((from.Y + to.Y) * 0.5 + 0.5))
	line.frame.Size = environment.UDim2.fromOffset(math.max(math.floor(length + 0.5), 1), math.max(1, math.floor(options.width + 0.5)))
	line.frame.Rotation = math.floor(math.deg(math.atan2(dy, dx)) * precision + 0.5) / precision
	line.frame.BackgroundColor3, line.frame.BackgroundTransparency = options.color, EspBox.quantize(1 - options.alpha)
	line.stroke.Enabled, line.stroke.Transparency = not not options.outline, 1
	if options.outline then
		line.stroke.Color = settings.outlineCol or context.colors.black
		line.stroke.Transparency = EspBox.quantize(1 - math.min(options.alpha * 1.15 * math.clamp((settings.outlineAlpha or 65) / 65, 0, 1.5), 1))
	end
	line.frame.Visible = true
end

local EspTracer = {}

function EspTracer.create(context, box)
	return EspLine.create(context, box, "Tracer")
end

function EspTracer.origin(state, camera)
	local environment, settings = state.context.environment, state.settings
	local viewport = camera.ViewportSize
	if settings.tracerFrom == "Top" then return environment.Vector2.new(viewport.X * 0.5, 2) end
	if settings.tracerFrom == "Middle" then return environment.Vector2.new(viewport.X * 0.5, viewport.Y * 0.5) end
	if settings.tracerFrom == "Mouse" then return state.context.inputService:GetMouseLocation() end
	if settings.tracerFrom == "Character" then
		local character = state.context.player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local position = camera:WorldToViewportPoint(root.Position - environment.Vector3.new(0, 2.6, 0))
			if position.Z > 0.08 then return environment.Vector2.new(position.X, position.Y) end
		end
	end
	return environment.Vector2.new(viewport.X * 0.5, viewport.Y - 2)
end

function EspTracer.point(state, camera, position)
	local environment, settings = state.context.environment, state.settings
	local viewport = camera.ViewportSize
	local point = camera.CFrame:PointToObjectSpace(position)
	local magnitude = math.sqrt(point.X * point.X + point.Z * point.Z)
	local x, y = 0, -1
	if magnitude >= 0.001 then x, y = point.X / magnitude, point.Z / magnitude end
	local avatar = settings.radarStyle == "Avatar"
	local half = math.clamp(settings.arrowSize, 5, 26) * (avatar and 3 or 2) * 0.5 * (avatar and 1 or math.sqrt(2))
	local marginX, marginY = math.max(half, settings.ringText and 36 or 0) + 4, half + (settings.ringText and 19 or 0) + 4
	local available = math.max(0, math.min(viewport.X * 0.5 - marginX, viewport.Y * 0.5 - marginY))
	local radius = math.clamp(settings.ringRadius, math.min(60, available), available)
	if settings.markerPos == "Screen Edge" then
		local width = math.max(20, viewport.X * 0.5 - marginX - 26)
		local height = math.max(20, viewport.Y * 0.5 - marginY - 26)
		radius = math.min(width / math.max(math.abs(x), 0.0001), height / math.max(math.abs(y), 0.0001))
	end
	return environment.Vector2.new(viewport.X * 0.5 + x * radius, viewport.Y * 0.5 + y * radius), math.deg(math.atan2(y, x)) + 90
end

function EspTracer.draw(state, object, origin, target, color, alpha, role)
	local environment, settings, context = state.context.environment, state.settings, state.boxContext
	local line = object.tracer
	if settings.tracerMurderer and role ~= "Murderer" then line.frame.Visible = false; return end
	local tint = settings.tracerRole and color or EspColor.tone(state.colors, settings.tracerColour)
	local fade = settings.tracerStyle == "Fade"
	local width = (tonumber(settings.tracerThickness) or 1) * (settings.lineScale or 100) / 100 * (context.lineWidthFactor or 1)
	EspLine.draw(context, line, {from = origin, to = target, width = width, color = tint,
		alpha = alpha * settings.tracerAlpha / 100, outline = settings.outline and not fade})
	if not fade and not object.tracerGrad then return end
	if not object.tracerGrad then
		local keypoint = environment.NumberSequenceKeypoint
		object.tracerGrad = object.make("UIGradient", {Transparency = environment.NumberSequence.new({keypoint.new(0, 0.95),
			keypoint.new(0.6, 0.4), keypoint.new(1, 0)})}, line.frame)
	end
	object.tracerGrad.Enabled = fade
end

local EspSkeleton = {}
local ESP_RIGS = {
	R15 = {
		points = {{"Head"}, {"UpperTorso", "NeckRigAttachment", joint = true}, {"UpperTorso", "WaistRigAttachment"},
			{"LowerTorso", "LeftHipRigAttachment", "RightHipRigAttachment", joint = true},
			{"LeftUpperArm", "LeftShoulderRigAttachment", joint = true}, {"LeftLowerArm", "LeftElbowRigAttachment", joint = true},
			{"LeftHand", "LeftGripAttachment"}, {"RightUpperArm", "RightShoulderRigAttachment", joint = true},
			{"RightLowerArm", "RightElbowRigAttachment", joint = true}, {"RightHand", "RightGripAttachment"},
			{"LeftUpperLeg", "LeftHipRigAttachment", joint = true}, {"LeftLowerLeg", "LeftKneeRigAttachment", joint = true},
			{"LeftFoot", "LeftFootAttachment"}, {"RightUpperLeg", "RightHipRigAttachment", joint = true},
			{"RightLowerLeg", "RightKneeRigAttachment", joint = true}, {"RightFoot", "RightFootAttachment"}},
		bones = {{1, 2}, {2, 3}, {3, 4}, {2, 5}, {5, 6}, {6, 7}, {2, 8}, {8, 9}, {9, 10}, {4, 11}, {11, 12}, {12, 13}, {4, 14}, {14, 15}, {15, 16}},
	},
	R6 = {
		points = {{"Head"}, {"Torso", 0, 0.5, joint = true}, {"Torso", 0, -0.5, joint = true},
			{"Left Arm", 0, 0.25, joint = true}, {"Left Arm", 0, -0.5}, {"Right Arm", 0, 0.25, joint = true},
			{"Right Arm", 0, -0.5}, {"Left Leg", 0, 0.5, joint = true}, {"Left Leg", 0, -0.5},
			{"Right Leg", 0, 0.5, joint = true}, {"Right Leg", 0, -0.5}},
		bones = {{1, 2}, {2, 3}, {2, 4}, {4, 5}, {2, 6}, {6, 7}, {3, 8}, {8, 9}, {3, 10}, {10, 11}},
	},
}

function EspSkeleton.references(character, rig)
	local result = {}
	for index, point in rig.points do
		local part = character:FindFirstChild(point[1])
		local reference = false
		if part and part:IsA("BasePart") then
			reference = {part = part}
			if type(point[2]) == "number" then reference.x, reference.y = point[2], point[3] end
			if type(point[2]) == "string" then
				local attachment = part:FindFirstChild(point[2])
				local other = point[3] and part:FindFirstChild(point[3])
				if attachment and attachment:IsA("Attachment") then
					reference = {att = attachment, att2 = other and other:IsA("Attachment") and other or nil}
				end
			end
		end
		result[index] = reference
	end
	return result
end

function EspSkeleton.position(environment, reference)
	if reference.att then
		if reference.att2 then return (reference.att.WorldPosition + reference.att2.WorldPosition) * 0.5 end
		return reference.att.WorldPosition
	end
	local part = reference.part
	if reference.x then
		return part.CFrame:PointToWorldSpace(environment.Vector3.new(part.Size.X * reference.x, part.Size.Y * reference.y, 0))
	end
	return part.Position
end

function EspSkeleton.baseColor(state, object, color)
	if object.seen == false then return EspColor.tone(state.colors, state.settings.boneHidden) end
	if state.settings.boneRole then return color end
	return EspColor.tone(state.colors, state.settings.boneColour)
end

function EspSkeleton.perf(state)
	if state.settings.perfMode == false then return false end
	if state.settings.perfMode == true then return true end
	if state.touchPerf ~= nil then return state.touchPerf end
	local isTouch = false
	pcall(function()
		local input, globals = state.context.inputService, state.context.environment.getgenv()
		isTouch = input.TouchEnabled and not input.KeyboardEnabled or globals.NOVA_FORCE_TOUCH == true
	end)
	state.touchPerf = isTouch
	return isTouch
end

function EspSkeleton.line(state, object, field, index)
	object[field] = object[field] or {}
	local line = object[field][index]
	if line then return line end
	local isGlow = field == "boneGlows"
	local name = (isGlow and "BoneGlow" or "Bone") .. index
	line = EspLine.create(state.context, object, name, isGlow and 3 or 4)
	object.make("UICorner", {CornerRadius = state.context.environment.UDim.new(1, 0)}, line.frame)
	object[field][index] = line
	return line
end

function EspSkeleton.joint(state, object, index, position, color, alpha)
	local environment, settings = state.context.environment, state.settings
	object.joints = object.joints or {}
	local joint = object.joints[index]
	if not joint then
		local frame = object.frame(object.layer, "Joint" .. index, 5)
		frame.AnchorPoint = environment.Vector2.new(0.5, 0.5)
		object.make("UICorner", {CornerRadius = environment.UDim.new(1, 0)}, frame)
		joint = {frame = frame, stroke = object.stroke(frame, 1)}
		object.joints[index] = joint
	end
	local width = (tonumber(settings.jointSize or 3) or 1) * (settings.lineScale or 100) / 100 * (state.boxContext.lineWidthFactor or 1)
	local size = math.max(2, math.floor(width + 0.5))
	joint.frame.Position = environment.UDim2.fromOffset(math.floor(position.X + 0.5), math.floor(position.Y + 0.5))
	joint.frame.Size = environment.UDim2.fromOffset(size, size)
	joint.frame.BackgroundColor3, joint.frame.BackgroundTransparency = color, EspBox.quantize(1 - alpha)
	joint.stroke.Enabled, joint.stroke.Transparency = settings.outline == true, 1
	if settings.outline then
		joint.stroke.Color = settings.outlineCol or state.colors.black
		joint.stroke.Transparency = EspBox.quantize(1 - alpha * 0.5)
	end
	joint.frame.Visible = true
end

function EspSkeleton.hide(object)
	for _, field in {"bones", "boneGlows", "joints"} do
		for _, item in object[field] or {} do item.frame.Visible = false end
	end
end

function EspSkeleton.draw(state, object, character, rectangle, color, alpha, camera)
	local settings, environment = state.settings, state.context.environment
	if not settings.skeleton or object.skelOff then EspSkeleton.hide(object); return end
	local rig = character:FindFirstChild("UpperTorso") and ESP_RIGS.R15 or ESP_RIGS.R6
	local now, cache = environment.os.clock(), object.skeletonCache
	if not cache or cache.character ~= character or cache.rig ~= rig or now - cache.at > 2 then
		cache = {character = character, rig = rig, at = now, references = EspSkeleton.references(character, rig)}
		object.skeletonCache = cache
	end
	local points = {}
	for index, reference in cache.references do
		if not reference then continue end
		local point = EspProjection.point(state.projection, camera, EspSkeleton.position(environment, reference))
		if point.Z > 0.08 then points[index] = point end
	end
	local base = EspSkeleton.baseColor(state, object, color)
	local scale = (settings.lineScale or 100) / 100 * (state.boxContext.lineWidthFactor or 1)
	local width = math.max(1, math.floor((tonumber(settings.boneThick) or 1) * scale + 0.5))
	local opacity = alpha * math.clamp((settings.boneAlpha or 100) / 100, 0, 1)
	local glow = settings.boneStyle == "Soft Glow" and not EspSkeleton.perf(state)
	local glowWidth = math.floor(width * 2.6 + 1.5)
	local trim = EspSkeleton.headTrim(state, rectangle, scale)
	local count, glowCount = 0, 0
	for _, bone in rig.bones do
		local first, second = points[bone[1]], points[bone[2]]
		if not first or not second then continue end
		local dx, dy = second.X - first.X, second.Y - first.Y
		local length = math.sqrt(dx * dx + dy * dy)
		local headTrim = bone[1] == 1 and trim or 0
		if length <= headTrim + 0.75 then continue end
		local unitX, unitY = dx / length, dy / length
		local startOffset = headTrim > 0 and headTrim or -width * 0.5
		local from = {X = first.X + unitX * startOffset, Y = first.Y + unitY * startOffset}
		local to = {X = second.X + unitX * width * 0.5, Y = second.Y + unitY * width * 0.5}
		local tint = EspSkeleton.color(state, rectangle, base, (first.Y + second.Y) * 0.5)
		count += 1
		EspLine.draw(state.boxContext, EspSkeleton.line(state, object, "bones", count),
			{from = from, to = to, color = tint, width = width, alpha = opacity, outline = settings.outline and not glow and width >= 2})
		if not glow then continue end
		glowCount += 1
		local glowStart = headTrim > 0 and headTrim or -glowWidth * 0.5
		EspLine.draw(state.boxContext, EspSkeleton.line(state, object, "boneGlows", glowCount), {
			from = {X = first.X + unitX * glowStart, Y = first.Y + unitY * glowStart},
			to = {X = second.X + unitX * glowWidth * 0.5, Y = second.Y + unitY * glowWidth * 0.5},
			color = tint, width = glowWidth, alpha = opacity * 0.16, outline = false,
		})
	end
	local jointCount = 0
	if settings.joints then
		for index, point in rig.points do
			if not point.joint or not points[index] then continue end
			jointCount += 1
			local tint = EspSkeleton.color(state, rectangle, base, points[index].Y)
			EspSkeleton.joint(state, object, jointCount, points[index], tint, opacity)
		end
	end
	for _, entry in {{"bones", count}, {"boneGlows", glowCount}, {"joints", jointCount}} do
		local items = object[entry[1]] or {}
		for index = entry[2] + 1, #items do items[index].frame.Visible = false end
	end
end

function EspSkeleton.headTrim(state, rectangle, scale)
	local settings = state.settings
	if not settings.headDot then return 0 end
	local size = math.floor(math.clamp(rectangle.w * 0.28 * (settings.headScale or 100) / 100, 3, 120) + 0.5)
	if settings.headStyle == "Dot" then size = math.max(4, math.floor(size * 0.35 + 0.5)) end
	return size * 0.5 + (settings.headStyle == "Dot" and 0.5 or 1.5 * scale * 0.5)
end

function EspSkeleton.color(state, rectangle, base, y)
	if not state.settings.boneGrad then return base end
	local top, bottom = EspColor.tone(state.colors, state.settings.boneTop), EspColor.tone(state.colors, state.settings.boneBottom)
	local cache = state.skeletonGradient
	if not cache or cache.top ~= top or cache.bottom ~= bottom then
		cache = {top = top, bottom = bottom, values = {}}
		state.skeletonGradient = cache
	end
	local index = math.floor(math.clamp((y - rectangle.y) / math.max(rectangle.h, 1), 0, 1) * 40 + 0.5)
	if not cache.values[index] then cache.values[index] = top:Lerp(bottom, index / 40) end
	return cache.values[index]
end

local EspHead = {}

function EspHead.create(state, object)
	local environment = state.context.environment
	local head = object.frame(object.layer, "Head", 4)
	head.AnchorPoint = environment.Vector2.new(0.5, 0.5)
	object.make("UICorner", {CornerRadius = environment.UDim.new(1, 0)}, head)
	object.head, object.headStroke = head, object.stroke(head, 1.5)
end

function EspHead.draw(state, object, head, rectangle, color, alpha, camera)
	local environment, settings = state.context.environment, state.settings
	if not settings.headDot then
		if object.head then object.head.Visible = false end
		return
	end
	local point = EspProjection.point(state.projection, camera, head.Position)
	if point.Z <= 0.08 then
		if object.head then object.head.Visible = false end
		return
	end
	if not object.head then EspHead.create(state, object) end
	local style = settings.headStyle or "Ring"
	local size = math.floor(math.clamp(rectangle.w * 0.28 * (settings.headScale or 100) / 100, 3, 120) + 0.5)
	if style == "Dot" then size = math.max(4, math.floor(size * 0.35 + 0.5)) end
	local base = settings.skeleton and EspSkeleton.baseColor(state, object, color) or color
	local tint = EspColor.ink(state.colors, settings.headColMode, settings.headCol, base)
	object.head.Position = environment.UDim2.fromOffset(math.floor(point.X + 0.5), math.floor(point.Y + 0.5))
	object.head.Size = environment.UDim2.fromOffset(size, size)
	object.head.BackgroundColor3 = tint
	local fill = style == "Filled" and math.clamp((settings.headFill or 25) / 100, 0, 1) or (style == "Dot" and 1 or 0)
	object.head.BackgroundTransparency = fill > 0 and EspBox.quantize(1 - alpha * fill) or 1
	object.headStroke.Color = style == "Dot" and (settings.outlineCol or state.colors.black) or tint
	object.headStroke.Thickness = style == "Dot" and 1 or 1.5 * (settings.lineScale or 100) / 100 * (state.boxContext.lineWidthFactor or 1)
	object.headStroke.Transparency = style == "Dot" and (settings.outline and EspBox.quantize(1 - alpha * 0.5) or 1) or EspBox.quantize(1 - alpha)
	object.head.Visible = true
end

function EspHead.look(state, object, head, color, alpha, camera)
	local settings, environment = state.settings, state.context.environment
	if not settings.lookLine then
		if object.look then object.look.frame.Visible = false end
		return
	end
	local from = EspProjection.point(state.projection, camera, head.Position)
	local to = EspProjection.point(state.projection, camera, head.Position + head.CFrame.LookVector * settings.lookLength)
	if from.Z <= 0.08 or to.Z <= 0.08 then
		if object.look then object.look.frame.Visible = false end
		return
	end
	if not object.look then object.look = EspLine.create(state.context, object, "Look") end
	local width = (tonumber(settings.lookThick or 1.5) or 1) * (settings.lineScale or 100) / 100 * (state.boxContext.lineWidthFactor or 1)
	local tint = EspColor.ink(state.colors, settings.lookColMode, settings.lookCol, color)
	EspLine.draw(state.boxContext, object.look, {from = from, to = to, color = tint, width = width, alpha = alpha, outline = settings.outline})
end

local EspChams = {}

function EspChams.materials(environment)
	local material = environment.Enum.Material
	return {
		Shaded = {material.SmoothPlastic, 1.02, 0.95, 0}, Glow = {material.Neon, 1.02, 0.7, 0},
		["Glow Outline"] = {material.Neon, 1.05, 0.3, 0}, Iridescent = {material.ForceField, 1.03, 0.9, 0},
		["Water Flow"] = {material.ForceField, 1.03, 0.9, 0}, Glossy = {material.SmoothPlastic, 1.02, 0.95, 0.65},
		Glass = {material.Glass, 1.03, 0.8, 0.25}, ForceField = {material.ForceField, 1.03, 0.95, 0},
		Gradient = {material.SmoothPlastic, 1.02, 0.85, 0}, Ghost = {material.SmoothPlastic, 1.03, 0.4, 0.15},
		Metallic = {material.Foil, 1.02, 0.95, 0.3}, Metal = {material.Metal, 1.02, 0.95, 0.15},
		Chrome = {material.SmoothPlastic, 1.02, 0.95, 0.55}, Crystal = {material.Glass, 1.04, 0.7, 0.5},
		Ice = {material.Ice, 1.03, 0.85, 0.25}, Lava = {material.CrackedLava, 1.02, 0.95, 0},
		Wireframe = {material.SmoothPlastic, 1.01, 1, 0},
	}
end

function EspChams.close(color, target)
	if math.abs(color.R - target.R) + math.abs(color.G - target.G) + math.abs(color.B - target.B) < 0.004 then return target end
	return color
end

function EspChams.targets(state, options)
	local settings = state.settings
	local role = EspColor.role(state.colors, options.role)
	local darkness = math.clamp((tonumber(settings.chamsHiddenDark) or 30) / 100, 0, 0.9)
	local fill = settings.chamsColour
	if not options.seen then fill = settings.chamsHidden end
	if settings.chamsRole then
		fill = role
		if not options.seen then fill = role:Lerp(state.colors.black, darkness) end
	end
	local edge = options.seen and settings.chamsEdge or settings.chamsEdgeHidden
	if settings.chamsRole and settings.chamsEdgeRole ~= false then
		edge = role:Lerp(state.colors.white, 0.25)
		if not options.seen then edge = role:Lerp(state.colors.black, darkness * 0.6) end
	end
	return fill, edge
end

function EspChams.animate(state, options, previous)
	local settings = state.settings
	local now = state.context.environment.os.clock()
	local fill, edge = EspChams.targets(state, options)
	local saved = previous or {fill = fill, edge = edge, seen = options.seen, flash = 0, born = now, at = now}
	local elapsed = math.clamp(now - saved.at, 0, 0.1)
	saved.at = now
	local blend = 1 - math.exp(-10 * elapsed)
	saved.fill = EspChams.close(saved.fill:Lerp(fill, blend), fill)
	saved.edge = EspChams.close(saved.edge:Lerp(edge, blend), edge)
	if options.seen and not saved.seen and settings.chamsFlash then saved.flash = 1 end
	saved.seen = options.seen
	saved.flash = math.max(0, saved.flash - elapsed * 2.2)

	local phase = settings.chamsAnim ~= "None" and 0.5 + 0.5 * math.sin(now * settings.chamsSpeed * math.pi * 2 + options.player.UserId % 89 * 0.41) or 0
	local fillFactor, edgeFactor, color = 1, 1, saved.fill
	if settings.chamsAnim == "Pulse" then fillFactor = 0.45 + 0.55 * phase end
	if settings.chamsAnim == "Breathe" then edgeFactor = 0.3 + 0.7 * phase end
	if settings.chamsAnim == "Flow" then color = color:Lerp(settings.chamsFlow, phase) end
	if saved.flash > 0 then color = color:Lerp(state.colors.white, saved.flash * 0.55) end
	color = EspColor.cham(state.colors, color)
	return saved, {fill = color, edge = saved.edge, fillFactor = fillFactor, edgeFactor = edgeFactor,
		born = math.clamp((now - saved.born) / 0.35, 0, 1), now = now}
end

function EspChams.material(state, role)
	local settings = state.settings
	local name = settings.chamsMaterial
	if role == "Murderer" and settings.murdMat and settings.murdMat ~= "Same" then name = settings.murdMat end
	if (role == "Sheriff" or role == "Hero") and settings.sheriffMat and settings.sheriffMat ~= "Same" then name = settings.sheriffMat end
	local specification = state.chamsMaterials[name]
	if settings.chamsStyle == "Glow" then
		name = "Core"
		specification = {state.context.environment.Enum.Material.Neon, 1.02, 0.85, 0}
	end
	if not specification then return nil, nil, nil end
	local scale = math.clamp((settings.chamsShell or 100) / 100, 1, 1.4)
	if scale ~= 1 then
		return name .. "@" .. tostring(math.floor(scale * 100 + 0.5)),
			{specification[1], specification[2] * scale, specification[3], specification[4]}, name
	end
	return name, specification, name
end

function EspChams.plan(state, options, saved)
	local settings, environment = state.settings, state.context.environment
	local through = settings.chamsThrough
	if through and (settings.chamsRange or 60) < 300 then
		local root = options.character:FindFirstChild("HumanoidRootPart")
		through = root ~= nil and (root.Position - options.cameraPosition).Magnitude <= (settings.chamsRange or 60)
	end
	local animation
	saved, animation = EspChams.animate(state, options, saved)
	local opacity = math.clamp(settings.chamsAlpha / 100, 0, 1)
	if settings.chamsStyle == "Outline" then opacity = 0 end
	if settings.chamsStyle == "Soft" then opacity *= 0.65 end
	local material, spec, kind = EspChams.material(state, options.role)
	local isGlow = settings.chamsStyle == "Glow"
	local showModel = (options.seen or through) and options.inView ~= false
	local modelColor = animation.fill
	if isGlow then modelColor = modelColor:Lerp(state.colors.white, 0.08) end
	if not isGlow and (kind == "Glow" or kind == "Glow Outline") then modelColor = modelColor:Lerp(state.colors.black, 0.42) end
	local modelAlpha = options.alpha * animation.born * animation.fillFactor
	if isGlow then modelAlpha *= math.clamp((settings.glowCore or 85) / 100, 0, 1) end

	local edge = animation.edge
	local edgeTransparency = settings.chamsOutline and 1 - options.alpha * animation.born * settings.chamsEdgeAlpha / 100 * animation.edgeFactor or 1
	if kind == "Glow Outline" then edge, edgeTransparency = animation.fill, 1 - options.alpha * animation.born * animation.edgeFactor end
	if isGlow then
		edge = animation.fill:Lerp(state.colors.white, 0.45)
		edgeTransparency = 1 - options.alpha * animation.born * 0.55 * animation.edgeFactor
	end
	local fillTransparency = material and 1 or EspBox.quantize(1 - math.clamp(opacity * animation.fillFactor + saved.flash * 0.35, 0, 1) * options.alpha * animation.born)
	edgeTransparency = EspBox.quantize(edgeTransparency)
	local haloStrength = math.clamp(settings.glowHalo / 100, 0, 1)
	local haloPulse = 0.8 + 0.2 * math.sin(animation.now * 2.2 + options.player.UserId % 89 * 0.41)
	return saved, {
		through = through, fill = animation.fill, edge = edge, fillTransparency = fillTransparency,
		edgeTransparency = edgeTransparency, enabled = options.inView ~= false and not (fillTransparency >= 0.995 and edgeTransparency >= 0.995),
		material = material, specification = spec, showModel = showModel, modelColor = modelColor, modelAlpha = modelAlpha,
		showHalo = (isGlow or settings.chamsOverlay) and showModel and haloStrength * 0.44 >= 0.07 and (haloStrength >= 0.28 or (options.distance or 0) <= 110),
		haloAlpha = options.alpha * animation.born * haloStrength * haloPulse * 2.2,
	}
end

local EspChamModel = {}

function EspChamModel.root(state)
	local environment, camera = state.context.environment, state.context.workspace.CurrentCamera
	if not camera then return nil end
	if state.modelFolder and state.modelFolder.Parent == camera then return state.modelFolder end
	if state.modelFolder then pcall(function() state.modelFolder:Destroy() end) end
	for _, object in camera:GetChildren() do
		if object.Name == "PulseESPModels" then pcall(function() object:Destroy() end) end
	end
	local folder = environment.Instance.new("Folder")
	folder.Name, folder.Parent = "PulseESPModels", camera
	state.modelFolder = folder
	return folder
end

function EspChamModel.pool(state, store, player)
	state.modelPool = state.modelPool or setmetatable({}, {__mode = "k"})
	state.modelPool[store] = state.modelPool[store] or {}
	local group = state.modelPool[store]
	group[player] = group[player] or {at = state.context.environment.os.clock(), items = {}}
	return group[player]
end

function EspChamModel.poolKey(part)
	local size = part.Size
	local key = part.Name .. "|" .. part.ClassName .. "|" .. string.format("%.3f,%.3f,%.3f", size.X, size.Y, size.Z)
	if part.ClassName == "MeshPart" then return key .. "|" .. tostring(part.MeshId) end
	local mesh = part:FindFirstChildWhichIsA("SpecialMesh")
	if not mesh then return key end
	local scale = mesh.Scale
	return key .. "|" .. tostring(mesh.MeshId) .. "|" .. mesh.MeshType.Name .. "|" .. string.format("%.3f,%.3f,%.3f", scale.X, scale.Y, scale.Z)
end

function EspChamModel.purge(state, player)
	for _, group in state.modelPool or {} do
		for owner, pool in group do
			if player and owner ~= player then continue end
			for _, items in pool.items do
				for _, item in items do pcall(function() item:Destroy() end) end
			end
			group[owner] = nil
		end
	end
end

function EspChamModel.sweep(state)
	local now = state.context.environment.os.clock()
	for _, group in state.modelPool or {} do
		for player, pool in group do
			if not (type(player) ~= "table" and player.Parent == nil or now - pool.at > 45) then continue end
			for _, items in pool.items do
				for _, item in items do pcall(function() item:Destroy() end) end
			end
			group[player] = nil
		end
	end
end

function EspChamModel.drop(state, store, player)
	local model = store[player]
	if not model then return end
	for _, connection in model.connections do pcall(function() connection:Disconnect() end) end
	local pool = model.kind ~= "Wireframe" and model.keys and EspChamModel.pool(state, store, player) or nil
	for index, clone in model.clones do
		local key = pool and model.keys[index]
		if not key or not clone.Parent then pcall(function() clone:Destroy() end); continue end
		pcall(function() clone.Transparency = 1 end)
		pool.items[key] = pool.items[key] or {}
		table.insert(pool.items[key], clone)
	end
	if pool then pool.at = state.context.environment.os.clock() end
	store[player] = nil
end

function EspChamModel.cloneable(part)
	if not part:IsA("BasePart") or part.Name == "HumanoidRootPart" then return false end
	if part.Transparency >= 0.95 or part.LocalTransparencyModifier >= 0.95 then return false end
	if part:FindFirstChildWhichIsA("WrapLayer") then return false end
	local accessory = part:FindFirstAncestorWhichIsA("Accessory")
	if accessory and accessory:FindFirstChildWhichIsA("WrapLayer", true) then return false end
	return true
end

function EspChamModel.clone(state, source, specification, folder, pool)
	local environment = state.context.environment
	local key = pool and EspChamModel.poolKey(source)
	local items = key and pool.items[key]
	local clone = items and table.remove(items)
	while clone and clone.Parent ~= folder do
		pcall(function() clone:Destroy() end)
		clone = table.remove(items)
	end
	local mesh, meshScale
	if clone then
		mesh = clone:FindFirstChildWhichIsA("SpecialMesh")
		if mesh then
			local sourceMesh = source:FindFirstChildWhichIsA("SpecialMesh")
			meshScale = sourceMesh and sourceMesh.Scale or mesh.Scale
		end
	end
	if not clone then
		local archivable = source.Archivable
		source.Archivable = true
		local ok, result = pcall(function() return source:Clone() end)
		source.Archivable = archivable
		if not ok or not result then return nil end
		clone = result
		if clone:FindFirstChildWhichIsA("SpecialMesh") then
			for _, child in clone:GetChildren() do
				if child:IsA("SpecialMesh") then
					child.TextureId = ""
					mesh = child
					continue
				end
				child:Destroy()
			end
		end
		if not mesh then clone:ClearAllChildren() end
		if mesh then meshScale = mesh.Scale end
		if clone:IsA("MeshPart") then pcall(function() clone.TextureID = "" end) end
		clone.Name = "M"
	end

	local scale, size
	if mesh and mesh.MeshType == environment.Enum.MeshType.FileMesh then
		scale = meshScale * specification[2]
		mesh.Scale = scale
	end
	if not scale then
		size = source.Size * specification[2]
		clone.Size = size
	end
	clone.Anchored, clone.CanCollide, clone.CanQuery, clone.CanTouch, clone.CastShadow = true, false, false, false, false
	clone.Material, clone.Reflectance, clone.Transparency = specification[1], specification[4], 1
	if clone.Parent ~= folder then clone.Parent = folder end
	return {clone = clone, mesh = mesh and scale and mesh or nil, scale = scale, size = size, key = key}
end

function EspChamModel.build(state, character, material, specification, folder, pool)
	local environment = state.context.environment
	local kind = tostring(material):match("^[^@]+")
	local model = {material = material, kind = kind, specification = specification, character = character,
		root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"),
		sources = {}, clones = {}, sizes = {}, meshes = {}, scales = {}, cframes = {}, boxes = {}, keys = {}, scale = 1, connections = {}}
	if kind == "Wireframe" then pool = nil end
	for _, source in character:GetDescendants() do
		if not EspChamModel.cloneable(source) then continue end
		local result = EspChamModel.clone(state, source, specification, folder, pool)
		if not result then continue end
		local index = #model.clones + 1
		model.sources[index], model.clones[index], model.keys[index] = source, result.clone, result.key
		model.sizes[index], model.meshes[index], model.scales[index] = result.size, result.mesh, result.scale
		if kind == "Wireframe" and source.Parent == character and source.Name ~= "HumanoidRootPart" then
			local outline = environment.Instance.new("SelectionBox")
			outline.Adornee, outline.LineThickness, outline.SurfaceTransparency, outline.Transparency = result.clone, 0.02, 1, 1
			outline.Parent, model.boxes[index] = result.clone, outline
		end
	end
	local function dirty(object)
		if (object:IsA("BasePart") or object:IsA("Accessory") or object:IsA("WrapLayer") or object:IsA("SpecialMesh")) and not model.dirty then
			model.dirty = environment.os.clock()
		end
	end
	table.insert(model.connections, character.DescendantAdded:Connect(dirty))
	table.insert(model.connections, character.DescendantRemoving:Connect(dirty))
	return model
end

function EspChamModel.resize(model, scale)
	model.scale = scale
	for index, clone in model.clones do
		local mesh = model.meshes[index]
		if mesh then mesh.Scale = model.scales[index] * scale end
		if not mesh then clone.Size = model.sizes[index] * scale end
	end
	for _, box in model.boxes do box.LineThickness = 0.02 * scale end
end

function EspChamModel.paint(state, model, color, transparency, now)
	local settings, environment = state.settings, state.context.environment
	local rootY = model.root and model.root.Parent and model.root.Position.Y or 0
	local top, bottom
	if model.kind == "Gradient" then
		top = EspColor.cham(state.colors, EspColor.tone(state.colors, settings.chamsGradA))
		bottom = EspColor.cham(state.colors, EspColor.tone(state.colors, settings.chamsGradB))
	end
	for index, clone in model.clones do
		local tint = color
		if model.kind == "Iridescent" then tint = environment.Color3.fromHSV((now * 0.12 * (settings.chamsSpeed or 1) + index * 0.012) % 1, 0.38, 1) end
		if model.kind == "Gradient" then
			local source = model.sources[index]
			local fraction = source and source.Parent and math.clamp((source.Position.Y - (rootY - 3)) / 5.6, 0, 1) or 0.5
			if settings.chamsGradScroll then fraction = math.abs((fraction + now * 0.2 * (settings.chamsSpeed or 1)) % 1 * 2 - 1) end
			tint = bottom:Lerp(top, fraction)
		end
		clone.Color, clone.Transparency = tint, transparency
	end
end

function EspChamModel.show(state, model, visible, color, alpha)
	if not visible then
		if model.shown == false then return end
		for _, clone in model.clones do clone.Transparency = 1 end
		for _, box in model.boxes do box.Transparency = 1 end
		model.shown = false
		return
	end
	local now, wasShown = state.context.environment.os.clock(), model.shown == true
	if wasShown and now - (model.propertiesAt or 0) < 1 / 30 then return end
	model.propertiesAt = now
	local transparency = 1 - math.clamp(model.specification[3] * alpha, 0, 1)
	if model.kind == "Wireframe" then
		model.shown = true
		if not wasShown or model.lastTint ~= color or math.abs((model.lastTransparency or -1) - transparency) >= 0.01 then
			model.lastTint, model.lastTransparency = color, transparency
			for _, box in model.boxes do box.Color3, box.Transparency = color, transparency end
		end
		return
	end
	if model.kind == "Iridescent" or model.kind == "Gradient" then
		model.shown, model.lastTint, model.lastTransparency = true, nil, nil
		EspChamModel.paint(state, model, color, transparency, now)
		return
	end
	local colorChanged = not wasShown or model.lastTint ~= color
	local transparencyChanged = not wasShown or math.abs((model.lastTransparency or -1) - transparency) >= 0.01
	if not colorChanged and not transparencyChanged then return end
	model.shown = true
	if colorChanged then
		model.lastTint = color
		for _, clone in model.clones do clone.Color = color end
	end
	if transparencyChanged then
		model.lastTransparency = transparency
		for _, clone in model.clones do clone.Transparency = transparency end
	end
end

function EspChamModel.step(state, options)
	local store, player = options.store, options.player
	local model, now = store[player], state.context.environment.os.clock()
	local stale = not model or model.character ~= options.character or model.material ~= options.material or not model.character.Parent
		or model.dirty ~= nil and now - model.dirty > 0.35
	if stale then
		if not options.visible then EspChamModel.drop(state, store, player); return end
		if (state.modelBudget or 0) <= 0 then
			if model and model.character == options.character then
				model.view = options.inView
				EspChamModel.show(state, model, options.visible, options.color, options.alpha)
			end
			return
		end
		state.modelBudget -= 1
		EspChamModel.drop(state, store, player)
		local folder = EspChamModel.root(state)
		if not folder or not options.material or not options.specification then return end
		model = EspChamModel.build(state, options.character, options.material, options.specification, folder, EspChamModel.pool(state, store, player))
		store[player] = model
		EspChamModel.bind(state)
	end
	model.view = options.inView
	EspChamModel.show(state, model, options.visible, options.color, options.alpha)
end

function EspChamModel.placeStore(state, store, camera)
	local environment, workspace = state.context.environment, state.context.workspace
	local position, viewport = camera.CFrame.Position, camera.ViewportSize
	for _, model in store do
		local root = model.root
		local parked = not (root and root.Parent)
		if model.shown and not parked then
			if model.view ~= nil then parked = model.view == false end
			if model.view == nil and (root.Position - position).Magnitude > 12 then
				local point = camera:WorldToViewportPoint(root.Position)
				local marginX, marginY = viewport.X * 0.35, viewport.Y * 0.35
				parked = point.Z < -6 or point.X < -marginX or point.X > viewport.X + marginX or point.Y < -marginY or point.Y > viewport.Y + marginY
			end
		end
		if model.shown and parked and not model.parked then
			model.parked = true
			local frames, frame = {}, environment.CFrame.new(0, 30000, 0)
			for index = 1, #model.clones do frames[index] = frame end
			pcall(function() workspace:BulkMoveTo(model.clones, frames, environment.Enum.BulkMoveMode.FireCFrameChanged) end)
		end
		if not model.shown or parked then continue end
		model.parked = nil
		if state.settings.chamsThrough and root and root.Parent then
			local distance = math.max((root.Position - position).Magnitude, 0.01)
			local scale = math.min(1, 2.5 / distance)
			if scale >= 1 and model.scale < 1 then EspChamModel.resize(model, 1) end
			if scale < 1 and (model.scale >= 1 or distance * model.scale < 1.9 or distance * model.scale > 3.25) then EspChamModel.resize(model, scale) end
		end
		if not state.settings.chamsThrough and model.scale ~= 1 then EspChamModel.resize(model, 1) end
		for index, source in model.sources do
			local frame = source.CFrame
			if model.scale < 1 then frame = frame.Rotation + (frame.Position * model.scale + position * (1 - model.scale)) end
			model.cframes[index] = frame
		end
		pcall(workspace.BulkMoveTo, workspace, model.clones, model.cframes, environment.Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function EspChamModel.bind(state)
	if state.modelsBound then return end
	local runService, environment = state.context.runService, state.context.environment
	local name = "PulseESP2ModelPlace"
	state.modelsBound = name
	pcall(function() runService:UnbindFromRenderStep(name) end)
	runService:BindToRenderStep(name, environment.Enum.RenderPriority.Last.Value, function()
		pcall(function()
			local camera = state.context.workspace.CurrentCamera
			if not camera then return end
			EspChamModel.placeStore(state, state.models, camera)
			EspChamModel.placeStore(state, state.halos, camera)
		end)
	end)
end

function EspChamModel.unbind(state)
	if not state.modelsBound then return end
	pcall(function() state.context.runService:UnbindFromRenderStep(state.modelsBound) end)
	state.modelsBound = nil
end

function EspChams.drop(state, player)
	local highlight = state.highlights[player]
	if highlight then pcall(function() highlight:Destroy() end) end
	state.highlights[player], state.chamStates[player] = nil, nil
	EspChamModel.drop(state, state.models, player)
	EspChamModel.drop(state, state.halos, player)
end

function EspChams.clear(state)
	for player in state.highlights do EspChams.drop(state, player) end
	for player in state.models do EspChamModel.drop(state, state.models, player) end
	for player in state.halos do EspChamModel.drop(state, state.halos, player) end
end

function EspChams.apply(state, options)
	if not state.settings.chams then EspChams.drop(state, options.player); return end
	local context, environment = state.context, state.context.environment
	local remote = environment.getgenv().__pulseRemoteSkin
	local replacement = remote and remote.list[options.player] and remote.list[options.player].model
	if replacement and replacement.Parent then options.character = replacement end
	local highlight = state.highlights[options.player]
	if not highlight or not highlight.Parent then
		highlight = environment.Instance.new("Highlight")
		highlight.Name, highlight.Enabled = "PulseESP2Cham", false
		local holder = context.coreGui
		if not holder or not holder.Parent then holder = context.player:FindFirstChildOfClass("PlayerGui") end
		highlight.Parent = holder or options.character
		state.highlights[options.player], state.chamStates[options.player] = highlight, nil
	end
	local previous = state.chamStates[options.player]
	if options.inView == false and previous and previous.adorned == nil then
		local model, halo = state.models[options.player], state.halos[options.player]
		if not (model and model.shown or halo and halo.shown) then return end
	end
	local saved, plan = EspChams.plan(state, options, previous)
	state.chamStates[options.player] = saved
	if plan.material then
		EspChamModel.step(state, {store = state.models, player = options.player, character = options.character,
			visible = plan.showModel, color = plan.modelColor, alpha = plan.modelAlpha, material = plan.material,
			specification = plan.specification, inView = options.inView})
	end
	if not plan.material and state.models[options.player] then EspChamModel.drop(state, state.models, options.player) end
	if state.settings.chamsStyle == "Glow" or state.settings.chamsOverlay then
		EspChamModel.step(state, {store = state.halos, player = options.player, character = options.character,
			visible = plan.showHalo, color = plan.fill, alpha = plan.haloAlpha, material = "Halo",
			specification = {environment.Enum.Material.Neon, 1.16, 0.2, 0}, inView = options.inView})
	end
	if state.settings.chamsStyle ~= "Glow" and not state.settings.chamsOverlay and state.halos[options.player] then
		EspChamModel.drop(state, state.halos, options.player)
	end
	if not plan.enabled then
		if saved.adorned ~= nil then highlight.Adornee, saved.adorned = nil, nil end
		highlight.Enabled = false
		return
	end
	if saved.adorned ~= options.character then highlight.Adornee, saved.adorned = options.character, options.character end
	highlight.FillColor, highlight.OutlineColor = plan.fill, plan.edge
	highlight.FillTransparency, highlight.OutlineTransparency = plan.fillTransparency, plan.edgeTransparency
	highlight.DepthMode = plan.through and environment.Enum.HighlightDepthMode.AlwaysOnTop or environment.Enum.HighlightDepthMode.Occluded
	highlight.Enabled = true
end

local EspRadar = {}
local ESP_ARROW_ASSETS = {
	fill = "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAADKklEQVR42u3dL1BiURTHccexOAZng2OiSHEMjsGhSJHiUKRIkSJJihQpazKtZSmSSCQtmkgkGolEIrGJtImkxZmzj/Eyssif9+fee+6973dmvs2Z97yfDSy8g2tEtIb4wiEAAAAIAABAAAAAAgAAEAAAYFNbIgAwdScCAEMbXn9FGwDQX4W+pgIA/Q2nAIYA0FuZvk8ZAPoazAEYAEBPJVo8JQCor78EoA8AtRVp9RQBoK6eD4AeANRUIP9TAID8ugEAugCQW56CTx4A8uqEAOgAQE45Cj85AESvHQGgDYBoZSn6ZAEQvpYEgBYAwpUheZMBQPCaEgGaAAhWmuRPGgD+e1UA8AoAf6VI3aQAsLpnhQDPAFjeEamfIwAsrqEBoAGA+R2QvjkAwPfqGgHqAPi/JOmfJAC+qjEA1ADwWYL4JgEAoiojQDXuALteH4wAH+IeYgvwQPzzEFeAH15vBgC8iXuJHcA9mTP3cQMYL9aNDAIYcS37cS7XmTZ3cQGYLNeZNizLftzLdaZNJQ4AQ4MBhq4DlMn8KbsMMLAAYOAqQInsmZKLAH2LAPquARTJvim6BNCzEKDnCkCB7J2CCwBdiwG6tgPkyf7J2wzQcQCgYytAjtyZnI0AbQ0H8yhSPW3bALKk/vnO/anr7Wt4rjRrE0BL0SG8eB0vue6x+BkV07IFIKPolz8NcA+niv4RZGwAaEp+BXIe4V7OJb8Sa5oOkJb4NsClxPu6lPh2SNpkgKjLdX+8rhW+MrsW1yBTlv1MWa4bfyB+q/Gt8duIDwakTAQIs1z3Tp8PRW0yfDa9Ka79TozLfpzLdb+9dgx4OntH3AtxLPtxLNeN14P2DFyP3Qu4JtUwBcDvct2T16EF3090KO6VdCz76ViuG792PrHwC2JPfPyfps4NkFzxBtaZxd/OPulsxRuLSU6A2oJPkS4cOPjZLhZ8ulfjAkjMeZTjysGDn+1qziM2CQ6A6tTzlDcxOPjZbqaec63qBtgVSw0/vdZjePiT1sUZjMIu+4W98C+v7Rgf/Gzb4kzwh9wIfz8AAQAACAAAQAAAAAIAABAAAIAAYCjAP5FhtP24QRzDAAAAAElFTkSuQmCC",
	rim = "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAADhUlEQVR42u2dMUgbYRTHxaE4FIduxUEcxCFFCCgEh4AQEAJCwCEgBoSAICgOghBwEgoixaEgFBxKhpKhZChkKBFKhpKhZGkGS8DiUJxcdHMQXx/0Qdu06l3uu/ve+773h98SYu7d+ymGcP/LEAAMKfbQJagAFaCoABWgqIBQvEAOkBPigB5TAQmwDfdnWwXEywo8nhUVEB+9AAJ6KiAeyhA8ZRVgnm4IAV0VYJYShE9JBZijM4CAjgowQxEGT1EFRKcdQUBbBUSjANFTUAGD0zIgoKUCBiMP5pJXAeFpGhTQVAHhyIH55FRAcBoxCGiogGBkIb5kVcDj1GMUUFcBD5OB+JNRAfdTS0BATQX8nzQkl7QK+JdqggKqKuBvUpB8UirgN8cWBByrgF9Mgr1MqgCAI4sCjnwXMA72M+6zgEMGAg59FfAcuWMg4I5m8U7APvDJvm8CniE3jATc0EzeCNgDftnzRcBT5JqhgGuazXkBu8A3u64LeIJcMhZwSTM6K2AH+GfHZQEXAgRcuCpgC+Rky0UB54IEnLsmYB3kZd0lAT2BAnquCCiD3JRdENAVLKArXUAJ5KckWUDHAQEdqQKK4E6KEgW0HRLQliagAO6lIElAy0EBLSkC8uBu8hIENB0W0OQuIAfuJ8dZQMMDAQ2uArLgT7IcBdQ9ElDnJiAD/iXDSUDNQwE1LgLS4G/SHARUPRZQtS0gBZqUTQHHuv9oZT+p5TpumbQh4Ej3DpHLfpLLddwynqSAQyYn/YoAqWU/qeW6N8jEHzNN0GMgrewnrVz3Dpl+YLZpeg5IKftJKdd9QOZCzDlHPwPcy37cy3WfkIUI79QW6DWAa9mPa7nuC7Jk8KPyJXpN4Fb241au+4asxnit0iodA7iU/biU634gGwmWRTbomGC77Ge7XHeFVJBhC3XZYTr2FVgs+9kq190iL5FRBvcrGqVZbsFC2S/IgJuGB3uNjDG8YewYzWYymyYEmLrQ6i0yJeAbO6ZoVkjiQq4gA51GHOI9MiPwKxNnaPYoOTUhYNALbT8i8wIX3888nQvEcUFvkAEqIQ/6GVl0YPH9LNK5hUnFhIAR5CzAwb4iyw4uvp9lOtfHcka7M/I2dPYBCd+RNQ8W388anft9y581/VHECP1JteifSzPI2ywP2KRdnNJuKkF+8/UrzfXm3YoKUAGKLkEFqABFBfgr4CdsheUuxgSmnQAAAABJRU5ErkJggg==",
	shade = "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAANZklEQVR42u2d93cV1RbHIXBJkAcmIaQAob8gwUcNQSCQUBRQihjKIzQpgjTBCNKbCAKBgEoXUBIFpBuQLlWKFEGk5P01vH3X+pz3zjrr3pt2Z+YE8sN3icOcvffs8/3OnX3mbKbaixcvqlUiVBfUEPgEkYIoEMmxGpxTaa6pMiW+pqC2oK4gRhAniAdxHKvLOTUry0RUhuRHwPB6ggaCxoIWghTBGyCFY405px5jIqomoGKoAaP97G4k+KegvSBdkCHIBBkca885jRhTGxtVE1BO5vvv77GCJoK2grcE/QSDBcMF/wbDOdaPc9oyJhYbEVUTUPZ7fi1BtCBZ8CYsHyTIEXwkmC3IBbM5lsM5GYxJxkYtW38TbL711BEkCtoIesDwCYK5gmWCtYI8sJZjczlnMGPaYKOOrbcim9nvv300F6QJBgjGw/YvBd8K9gkKwT6Ofck54xmTho1YW1VgM/uTBKmCXtzjZwq+EGwXHBAUCc6BIo5t55yZjOmFjSRbVWAr+2NgbmfBQMGHggWCfBj/q+C64A9wnWOFnLOAMQOx0Ryb1qnA9nu/yf5dgmOCK4L7gifgPseOcY6pAmt/C2ybAMX+ZjB3AD+qnws2wfAzgluCx4Ji8JhjZzhnE2MmYKMzNpUKqiYgyHO/zv6egmzBDBi9E4ZfhvFPBf8BTzl2mXN2MmYGNnoaKoiomoDA7I+GqZ20Jx/F/gKN/X/BfDUBxRxTKijQVKCeiDphO9omFdjE/tcECaztZGjsXwWjjwZhfyAVHGXMKk0FGdhOwFdE1QT8Hz6Y2RSm9oe58wUbYbT/KedmAPabKrjJuQWMnY+t/thuii9f1QQEZ/8HgumClYIdpWB/MBXswMZ0bFqnAtvY31HwjmCcxv79pWB/MBXs11QwDtsdbVKBTexvzfrNMI39/sr2iOA3wb0S2K+r4B5jjmBDqWAYPlrbogIb2P86S8c6++exyOZn8GmN/c9LMQHPNRWcxkYeNnUVNMG371WdgAhemMQb7P9YsKKc7A+lghXY1lUQTwwRr+IE6OzvIHhbMFbwmWCD4AcY/LvgUSnZr6vgEWNPY2sDtsfiq4MNKrCB/f73ud0F7wumwdRtgsOCSzD5SRmSr/CEsZewtQ3b0/DVHd+eqsBr9idr7B9jsP9UOdkfSAWnDBWM0VSQ7KUKvGR/A439Q2HmcoP9d8vJfl0Fdw0VLMfXUE0FDbxSgRcTUJNtI8nsYugHI/1vstYLvoexNyrAflMFN7D5PT5y8dmPGJKJqebLPgHVNfb7t490g4lTeae7VfCz4GIY2G+q4CK2t+JrKr67EYtSQfWXeQIU+xvDvL7sZPgUZu7j9WI42B9IBUX4WI/PHGJoT0yuq8Bt9kdp7Pfv3xnCdpJlvFQ/FGb2B1LBIXwtw/cQYlEqiHJTBV6xvx3MGw0T1xnsfxgm9usqeGioYB2+RxNLOy9U4Db7/ZtoWxnsX6qx/wIv2cPJfl0Ff+BDqWCpoYJWxOiaCtxkf12N/X1gnn8j1VeCvYJf2N0QbvabKriOr734nkssfTQV1HVLBV6wvys716YIlgi+ERzU2P93CUvO5UUxtpUKDuJ7CbEMJjZXVeAm+/07lv8F0/wbaue4yP6SVDCHmPoQYyO3VOAW++sLWsIw/+bZyQb7zzvM/kAqOG+oYDKxdSXW+m6owI2NVor9/t3KvTX2+zfU7hGcFFwT/Cl45mDyFZ7h6xq+9xCLUkFvYlUqqFFZJ6A6XSqK/eka+xcLvmY/p5+Jd1xgv6mCO/g+QCyLNRWkayqIdFIFTrP/H4KGGvtHCT4RrPGI/aFUsIbYRmkqaMg11KhsE6CzvwWMek8wCaZt8Yj9oVSwhdgmEWs6sTuqAjfY728XyhKM1Nj/neCE4KoH7DdVcJVYvtNUMJKY2zqtAifZHwuDumjsXwTTfmJfvxfsD6SCc8S0hRiVCrpwDbFOqcBJ9ifBoEwYNZsOlt0WsD+YCnYT42xizuQakpxSgRvsf1cwUbBQsFlj/21ti7lXE6C2tt/WVLCZWCcSu6MqcLq9yM+gEYJZGvuPw7gHHrNfV8EDYjquqWAWsWc62ebkdHOdai9S7P9RcNYS9gdSwVliVCpQbU6ONfu50VznZ9JqWoeO00pkC/tNFVwhxl3EPMvpZj83m+sU+29ZxH5TBbc0FbjS7OdFc51t7A+kAtea/bxsrrNtAjxp9vO6uc42uN7s53VznY0qcLXZz4bmOptV4Hiznw3NdbaqwJVmP1ua62xXgWPNfrY019muAsea/WxqrrNRBY43+9nUXGcbXGn2s625rjKoIKzNfrY119moAkeb/WxsrrMNjjb72dhcZ7MKwt7sZ2tznY0qcKTZz9bmOltVEPZmP5ub62xVQVib/WxurrNZBWFr9rO9ua6k5YJnoNgDFYSl2c/25rpQif+bTVV/8mc3JiLszX6VobnOTIBK/B12N1/jz2oinruggrA1+1WG5jqV+Cf4UP9U8Xm2lp/kz+qfMn7Iuc9dbnMqV7Of7c11KvGPuPdex98v+N4DDnLsAufcZYwTExHWZj9bm+uesxCmEn+DH74iZL+Xi14LvuHYIc65yBg1EU8davyucLOfbc11xSTrL9Zffqf6PMWzt/pOwDruu3PBUo6p7wr8zJhL2LiHzadhjDMszX62NNfpib/PGvxvrEAeZv1lK8/dy3jq+Ih77mj+/Cl/t55zf2DsaWzdxHa4JiIszX5eN9epR8rHJOcW72F/Zf19P2vwG1h7yaXyzOGJoy8YwrGpnLOcMduxcQSbl/FxH5/PKhh7hZv9vGqu0xP/gKRcYS/OUXYi7OAN1EpWHqex7jKUtZduPG2048/9+LsxnPsZY/OwVYDtM/i6he+KTESFm/3cbq4zi6jb7Ms/y060QvbhbGIvznzewY7lDdTbrDyq74U1Bur7Yt05ZxhjpmNjFTZ34uMYPq8SQ3mLuQo3+7nVXFccoIi6SlfKcXYj72JH8hfsRJvBPpwPeP/ag3X3FFYd1Rfz1Bf2kvm7Dpz7DmPHY+tzbOfj60d8nyMWs5grdqPZz43mOrOIugZbTmBvNw0Rq9kOPpPNsNlsgsrg5XdrXv3F8+JDfTNSfWPydf6uCed2ZGx/bE3A9gJ8bcb3T8RyntjKWsxVqNnPyea6QNXrBe6VB7hfboEti2iG+JCt4APZCNuJDVBN2f6hEu8zXnpEcExNRAJj3sBGT2wOx8csfK4hhj3EdFIr5soyEeVu9gu00aoZLTnlba4zq1dVRKnqdS9PC2u5V34CU0bisxf+2xBLInG9FiDxgd7a+Tg3mrHNsJWG7XfxNQnfi4nla2JTVbVZzIWaiNI0+6Vpm3p95gSo208c99EeyHYmci1Nc12xVr3qRVSRUUR9RcEyh8e1Ucg0C6mm0omSyD78OuxCjijj69NajI3BVnNsd8HXe/ieTCxLiE0v5oqMYu5RiBoiULPfanKYTU5TyPH/bkPmG6942JJJMZHLY1xBiOa6UNXrYV7fbTWq1ynYH8SjWjoSbYFMY8uZ+FATEYvtFvhKx/cgYpliVNVbif1wKatqs9mvgNzlYj+T3Mbrb8zMCUiAJb0pbObx1HCAe6O+0SpU9XqESnSbUUSp6nUw6yVdeU5uyVNCLPfIyDB+HVt9hTsS27H4aonvrsQyWKuq9WJuG9dypBRVtdrIdYGc5ZPDHHKaSo5DTkAbJDqaQDby7Kyefh7jSC+iVPV6VKte89g/YxZRfVkzb8eKYSOekcOd+JImoj6+WxHLW8RmFnMruBZVVR81quoHRk7U01Ahucsll1nkNugE6L8BqtFCNVir5//LOLiH1FT1ekyrXjdSgc5jC99YNjCp6lUvouJYJ4ly8XvwaiKi8B1nFHOqqn6f2D/mWlZybaqqPqZV1bfJyR1ypOoB1fCtGjuC/gaopyDVZmrWAPnM/glm9wL3Ob2IMqvXcUb1GqiIinrh3fff1Xfqo4IUc3pVPS5AVa0Xc2fJyTlytJ+cmbWAanP1haoD1BpQFq36M7gf5jOrhdzfCvilz9eKKL167c8vv15EqcTX9jDxwSaitjYRejHXg2vRq2pVzOWTgwJyUkiO8snZDHKYFWxNKNQ6UBrl/GgMLUJSG3GQRxALjSJqQIAiKj5EEWXTx+R8RlVtFnMDjGJuITnIIycbydEicjaaHKYFWw8KthaUiBTTMTACKc3iR2Ue/51JoTGCSrMXvbSqiEooQxFl20SoYi5BK+Y6c40DueaJ5EDPySxyNYLcpZPLxJLWgpQKfEgxiYFpWuGSzazm8GybTZWXyXmpWvUaU8kSH2oiYrSqOpVrzeTas8lFDrnJ1grLNHKYRE59Ja2G6v/uQz2ctuD+1YVf8iyeaTO5P6ZR2DTHUUyYiiibJkKvqpO41rZcew9y0ZvcZJCrN8ldIrmsVdoXMroS1PNyQ5ymIMVU/psCK5K0IqqWjZ8OfxGefw+jllbMJXHtgXLSnJyp+sZX1nfCgQqXGJ5hE0A8/x/tQhFl0yfX9ZxEk4N4LS9x5KpUOSmLUx8Ga2uI5PjLnnjHclIexyaqveKoUE6qVSXQ26+p/hcoIQAYkehx5QAAAABJRU5ErkJggg==",
}

function EspRadar.texture(state, name)
	state.arrowTextures = state.arrowTextures or {}
	local cached = state.arrowTextures[name]
	if cached ~= nil then return cached or nil end
	state.arrowTextures[name] = false
	local environment, encoded = state.context.environment, ESP_ARROW_ASSETS[name]
	if not encoded or type(environment.getcustomasset) ~= "function" or type(environment.writefile) ~= "function" then return nil end
	local ok, asset = pcall(function()
		local bytes = buffer.tostring(OfflineFiles._decodeBuffer(encoded))
		if #bytes < 60 then return nil end
		if type(environment.makefolder) == "function" then
			if type(environment.isfolder) ~= "function" or not environment.isfolder("PulseHub") then pcall(environment.makefolder, "PulseHub") end
		end
		local path = "PulseHub/esp-arrow-" .. name .. "-" .. tostring(#bytes) .. ".png"
		if type(environment.isfile) ~= "function" or not environment.isfile(path) then environment.writefile(path, bytes) end
		return environment.getcustomasset(path)
	end)
	if ok and type(asset) == "string" and asset ~= "" then state.arrowTextures[name] = asset; return asset end
	return nil
end

function EspRadar.layers(state, frame, create)
	local environment = state.context.environment
	local shade, rim, fill = EspRadar.texture(state, "shade"), EspRadar.texture(state, "rim"), EspRadar.texture(state, "fill")
	if not shade or not rim or not fill then return nil end
	local function image(name, asset, level, color)
		return create("ImageLabel", {Name = name, BackgroundTransparency = 1, Image = asset, ImageColor3 = color,
			AnchorPoint = environment.Vector2.new(0.5, 0.5), Position = environment.UDim2.fromScale(0.5, 0.5),
			Size = environment.UDim2.fromScale(1.45, 1.45), ScaleType = environment.Enum.ScaleType.Stretch,
			ZIndex = level, Visible = false}, frame)
	end
	local shadow = image("ArrowShade", shade, 11, state.colors.black)
	shadow.Position = environment.UDim2.new(0.5, 0, 0.5, 1)
	local outline, body = image("ArrowRim", rim, 12, state.colors.black), image("ArrowFill", fill, 13, state.colors.white)
	create("UIGradient", {Rotation = 90, Color = environment.ColorSequence.new(state.colors.white, environment.Color3.fromRGB(184, 184, 184))}, body)
	return {shade = shadow, rim = outline, fill = body}
end

function EspRadar.create(state, player)
	local environment, parent = state.context.environment, state.createGui()
	local function create(class, properties, owner)
		local object = environment.Instance.new(class)
		for key, value in properties do object[key] = value end
		object.Parent = owner
		return object
	end
	local function stroke(owner, thickness)
		return create("UIStroke", {Thickness = thickness, Color = state.colors.black,
			ApplyStrokeMode = environment.Enum.ApplyStrokeMode.Border, Transparency = 1}, owner)
	end
	local frame = create("Frame", {Name = "Radar_" .. tostring(player.UserId), BackgroundTransparency = 1,
		BorderSizePixel = 0, Active = false, Visible = false, ZIndex = 10, AnchorPoint = environment.Vector2.new(0.5, 0.5),
		BackgroundColor3 = environment.Color3.fromRGB(28, 30, 38)}, parent)
	create("UICorner", {CornerRadius = environment.UDim.new(1, 0)}, frame)
	local dotStroke = stroke(frame, 1)
	local image = create("ImageLabel", {Name = "Avatar", BackgroundTransparency = 1, Size = environment.UDim2.fromScale(1, 1),
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(player.UserId) .. "&w=60&h=60", ZIndex = 11}, frame)
	create("UICorner", {CornerRadius = environment.UDim.new(1, 0)}, image)
	local edge = stroke(image, 1.5)
	local arrow = create("TextLabel", {BackgroundTransparency = 1, Size = environment.UDim2.fromScale(1, 1), Text = "▲",
		RichText = false, Font = environment.Enum.Font.GothamBlack, TextScaled = true, TextStrokeTransparency = 0, ZIndex = 11}, frame)
	local text = create("TextLabel", {BackgroundTransparency = 1, AnchorPoint = environment.Vector2.new(0.5, 0),
		Position = environment.UDim2.new(0.5, 0, 1, 3), Size = environment.UDim2.fromOffset(150, 16), TextSize = 11,
		Font = environment.Enum.Font.GothamBold, RichText = false, TextStrokeTransparency = 0.3, ZIndex = 11}, frame)
	local radar = {frame = frame, image = image, edge = edge, arrow = arrow, text = text, dotStroke = dotStroke,
		layers = EspRadar.layers(state, frame, create)}
	state.radars[player] = radar
	return radar
end

function EspRadar.show(state, options)
	local environment, settings = state.context.environment, state.settings
	local radar = state.radars[options.player]
	if not radar or not radar.frame.Parent then radar = EspRadar.create(state, options.player) end
	local style = settings.radarStyle or "Arrow"
	local isAvatar, isDot = style == "Avatar", style == "Dot"
	local isArrow = not isAvatar and not isDot
	local size = math.clamp(settings.arrowSize, 5, 26) * (isAvatar and 3 or 2)
	if isDot then size *= 0.5 end
	if settings.arrowPulse then size *= 1 + 0.12 * math.sin(environment.os.clock() * 4 + options.player.UserId % 89 * 0.4) end
	size = math.max(4, math.floor(size + 0.5))
	local opacity = EspBox.quantize(1 - options.alpha)
	local rotation = math.floor(options.angle * 2 + 0.5) / 2
	radar.frame.Position = environment.UDim2.fromOffset(math.floor(options.position.X + 0.5), math.floor(options.position.Y + 0.5))
	radar.frame.Size = environment.UDim2.fromOffset(size, size)
	radar.image.Visible, radar.arrow.Visible = isAvatar, isArrow and not radar.layers
	if radar.layers then
		local layers = radar.layers
		layers.shade.Visible, layers.rim.Visible, layers.fill.Visible = isArrow, isArrow, isArrow
		if isArrow then
			layers.fill.ImageColor3, layers.fill.ImageTransparency = options.color, opacity
			layers.rim.ImageTransparency = EspBox.quantize(1 - options.alpha * 0.85)
			layers.shade.ImageTransparency = EspBox.quantize(1 - options.alpha * 0.5)
			layers.shade.Rotation, layers.rim.Rotation, layers.fill.Rotation = rotation, rotation, rotation
		end
	end
	radar.image.ImageTransparency = opacity
	if isDot then
		radar.frame.BackgroundColor3, radar.frame.BackgroundTransparency = options.color, opacity
		radar.dotStroke.Color = settings.outlineCol or state.colors.black
		radar.dotStroke.Transparency = EspBox.quantize(1 - options.alpha * 0.5)
	end
	if not isDot then
		radar.frame.BackgroundColor3 = environment.Color3.fromRGB(28, 30, 38)
		radar.frame.BackgroundTransparency = isAvatar and EspBox.quantize(1 - options.alpha * 0.92) or 1
		radar.dotStroke.Transparency = 1
	end
	radar.edge.Color, radar.edge.Transparency = options.color, opacity
	if isArrow and not radar.layers then
		radar.arrow.TextColor3, radar.arrow.TextTransparency, radar.arrow.Rotation = options.color, opacity, rotation
	end
	radar.text.Visible = settings.ringText or settings.arrowName
	if radar.text.Visible then
		radar.text.TextColor3, radar.text.TextTransparency = options.color, opacity
		local name = settings.arrowName and EspText.name(state.text, options.player, settings.nameMode) or ""
		local distance = settings.ringText and EspText.distance(state.text, options.distance, settings.distUnit) or ""
		radar.text.Text = name ~= "" and distance ~= "" and name .. "  " .. distance or name .. distance
	end
	radar.frame.Visible = true
end

function EspRadar.hide(state, player)
	local radar = state.radars[player]
	if radar then radar.frame.Visible = false end
end

function EspRadar.drop(state, player)
	local radar = state.radars[player]
	if radar then pcall(function() radar.frame:Destroy() end) end
	state.radars[player] = nil
end

function EspRadar.clear(state)
	for player in state.radars do EspRadar.drop(state, player) end
end

local EspFeature = {}

function EspFeature.create(context)
	local environment, globals = context.environment, context.environment.getgenv()
	if globals.__pulseESP2Stop then pcall(globals.__pulseESP2Stop) end
	local settings = EspSettings.create(environment, context.configuration)
	local state = {context = context, settings = settings, role = EspRole.create(environment.os.clock),
		projection = EspProjection.create(environment), objects = {}, labels = {}, retryAt = {}, colorHandles = {}, text = EspText.create(),
		highlights = {}, chamStates = {}, models = {}, halos = {}, radars = {}, skipDelta = setmetatable({}, {__mode = "k"}),
		chamsMaterials = EspChams.materials(environment)}
	state.createGui = function() return EspFeature.root(state) end
	state.colors = EspColor.create(environment, settings)
	state.boxContext = {environment = environment, settings = settings, colors = state.colors}
	settings.I = state
	settings.onChange = function(key)
		if key == "on" and not settings.on then EspFeature.hideAll(state) end
		if key == "offscreen" and not settings.offscreen or key == "radarStyle" then EspRadar.clear(state) end
		if key == "chams" and not settings.chams or key == "chamsMaterial" or key == "chamsStyle" or key == "chamsShell" then
			EspChams.clear(state)
		end
	end
	settings.stop = function() EspFeature.stop(state) end
	globals.__pulseESP2, globals.__pulseESP2Stop = settings, settings.stop

	local event = context.runService.PreRender or context.runService.RenderStepped
	state.connection = context.connect(event, function(delta)
		local ok, raised = pcall(EspFeature.step, state, delta)
		if not ok then state.lastError = tostring(raised) end
	end)
	context.connect(context.players.PlayerRemoving, function(player) EspFeature.release(state, player) end)
	return state
end

function EspFeature.root(state)
	if state.gui and state.gui.Parent then return state.gui end
	local context, environment = state.context, state.context.environment
	local holder = context.coreGui
	if not holder or not holder.Parent then holder = context.player:FindFirstChildOfClass("PlayerGui") end
	local gui = environment.Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "PulseESP2", false, true
	gui.DisplayOrder, gui.ZIndexBehavior = 9, environment.Enum.ZIndexBehavior.Sibling
	gui.Parent = holder
	state.gui = gui
	return gui
end

function EspFeature.release(state, player)
	local object = state.objects[player]
	if object then pcall(function() object.layer:Destroy() end) end
	state.objects[player], state.retryAt[player] = nil, nil
	EspChams.drop(state, player)
	EspChamModel.purge(state, player)
	EspRadar.drop(state, player)
	EspLabel.release(state, player)
end

function EspFeature.hide(state, player)
	local object = state.objects[player]
	if not object then return end
	object.layer.Visible = false
	EspLabel.hide(state, player)
	EspRadar.hide(state, player)
	object.rect, object.rel, object.hpRatio, object.drawState = nil, nil, nil, nil
end

function EspFeature.hideAll(state)
	EspChams.clear(state)
	for player in state.objects do EspFeature.hide(state, player) end
end

function EspFeature.stop(state)
	pcall(EspLabel.restoreNames, state)
	EspChams.clear(state)
	EspChamModel.purge(state)
	EspChamModel.unbind(state)
	EspRadar.clear(state)
	if state.modelFolder then pcall(function() state.modelFolder:Destroy() end) end
	if state.connection then pcall(function() state.connection:Disconnect() end) end
	for player in state.objects do EspFeature.release(state, player) end
	if state.gui then pcall(function() state.gui:Destroy() end) end
	if state.labelGui then pcall(function() state.labelGui:Destroy() end) end
	state.gui, state.labelGui = nil, nil
end

function EspFeature.prepareProjection(state, camera)
	local frame, viewport = camera.CFrame, camera.ViewportSize
	local centerX, centerY = viewport.X * 0.5, viewport.Y * 0.5
	local focal = centerY / math.tan(math.rad(camera.FieldOfView) * 0.5)
	local point = frame.Position + frame.LookVector * 20 + frame.RightVector * 3 + frame.UpVector * 2
	local projected, localPoint = camera:WorldToViewportPoint(point), frame:PointToObjectSpace(point)
	local depth = -localPoint.Z
	local enabled = false
	if depth > 0.08 then
		local x, y = centerX + localPoint.X / depth * focal, centerY - localPoint.Y / depth * focal
		enabled = math.abs(x - projected.X) < 0.5 and math.abs(y - projected.Y) < 0.5 and math.abs(depth - projected.Z) < 0.05
	end
	state.projection.projection = {frame = frame, centerX = centerX, centerY = centerY, focal = focal, enabled = enabled}
end

function EspFeature.update(state, player, roles, camera, delta)
	local context, settings = state.context, state.settings
	local character = player.Character
	local parts = character and EspRole.partsOf(state.role, character)
	local humanoid, root = parts and parts.hum, parts and parts.root
	local role = EspRole.of(state.role, player, roles)
	if not character or not root or not humanoid or humanoid.Health <= 0 or not EspRole.shown(settings, role) then
		EspFeature.hide(state, player)
		EspChams.drop(state, player)
		return
	end

	local distance = (root.Position - camera.CFrame.Position).Magnitude
	if distance > settings.maxDist then EspFeature.hide(state, player); EspChams.drop(state, player); return end
	local object = state.objects[player]
	if not object or not object.layer.Parent then
		object = EspBox.create(state.boxContext, EspFeature.root(state), player.UserId)
		object.tracer = EspTracer.create(state.context, object)
		state.objects[player] = object
	end
	if object.character ~= character then
		object.character, object.rect, object.rel, object.hpRatio = character, nil, nil, nil
	end
	local now = context.environment.os.clock()
	local inView, viewPoint = EspProjection.inView(state.projection, camera, root.Position)
	if (settings.visCheck or (settings.chams or settings.skeleton) and inView) and (not object.seenAt or now - object.seenAt > 0.12) then
		object.seen = EspProjection.visible(context, camera.CFrame.Position, parts.head or root, character)
		object.seenAt = now
	end
	local isVisible = not settings.visCheck or object.seen ~= false
	local color = EspColor.select(state.colors, role, isVisible, distance)
	local alpha = EspProjection.alpha(settings, distance, isVisible)
	object.role = role
	object.boxOff = settings.limits and (tonumber(settings.boxMaxDist) or 0) > 0 and distance > settings.boxMaxDist
	object.skelOff = settings.limits and (tonumber(settings.skelMaxDist) or 0) > 0 and distance > settings.skelMaxDist
	state.boxContext.lineWidthFactor = settings.distScale and math.clamp(90 / math.max(distance, 1), 0.55, 1.6) or 1
	local isGhost = type(player) == "table" and player.Ghost == true
	local exceedsChamLimit = settings.limits and (tonumber(settings.chamsMaxDist) or 0) > 0 and distance > settings.chamsMaxDist
	if isGhost or exceedsChamLimit then EspChams.drop(state, player) end
	if not isGhost and not exceedsChamLimit then
		EspChams.apply(state, {player = player, character = character, role = role, seen = object.seen ~= false,
			alpha = alpha, inView = inView, distance = distance, cameraPosition = camera.CFrame.Position})
	end
	local rectangle = EspProjection.project(state.projection, character, root, camera, settings.boxWidth)
	if not rectangle then
		EspLabel.hide(state, player)
		object.rect, object.rel, object.drawState = nil, nil, nil
		local target, angle = EspTracer.point(state, camera, root.Position)
		if settings.offscreen then
			EspRadar.show(state, {player = player, position = target, angle = angle, color = color, distance = distance, alpha = alpha})
		end
		if not settings.offscreen then EspRadar.hide(state, player) end
		if not settings.tracer then
			object.layer.Visible = false
			return
		end
		object.box.Visible, object.glow.Visible, object.outer.Visible = false, false, false
		if object.inner then object.inner.Visible = false end
		if object.head then object.head.Visible = false end
		if object.look then object.look.frame.Visible = false end
		EspSkeleton.hide(object)
		EspBox.hideSegments(object, 1)
		state.boxContext.lineWidthFactor = settings.distScale and math.clamp(90 / math.max(distance, 1), 0.55, 1.6) or 1
		EspTracer.draw(state, object, EspTracer.origin(state, camera), target, color, alpha, role)
		object.layer.Visible = true
		return
	end
	EspRadar.hide(state, player)
	local point = viewPoint or EspProjection.point(state.projection, camera, root.Position)
	local focus = settings.murdererFocus == true and role == "Murderer"
	local frame = {character = character, rectangle = rectangle, point = point, color = color, alpha = alpha, focus = focus, delta = delta}
	if EspFeature.shouldSkip(state, object, frame) then return end
	local elapsed = EspFeature.rememberFrame(object, frame)
	local center = point.Z > 0.08 and {X = point.X, Y = point.Y} or nil
	rectangle = EspProjection.smooth(object, rectangle, camera.ViewportSize, settings.smooth, elapsed, center)
	object.layer.Visible = true
	EspBox.draw(state.boxContext, object, rectangle, color, alpha, player, focus)
	if rectangle.h < (EspSkeleton.perf(state) and 48 or 26) then object.skelOff = true end
	EspSkeleton.draw(state, object, character, rectangle, color, alpha, camera)
	EspHead.draw(state, object, parts.head or root, rectangle, color, alpha, camera)
	EspHead.look(state, object, parts.head or root, color, alpha, camera)
	if settings.tracer then
		local targetY = rectangle.y + rectangle.h
		if settings.tracerTo == "Center" then targetY = rectangle.y + rectangle.h * 0.5 end
		if settings.tracerTo == "Head" then targetY = rectangle.y end
		local target = context.environment.Vector2.new(rectangle.x + rectangle.w * 0.5, targetY)
		EspTracer.draw(state, object, EspTracer.origin(state, camera), target, color, alpha, role)
	end
	if not settings.tracer then object.tracer.frame.Visible = false end
	local exceedsNameLimit = settings.limits and (tonumber(settings.nameMaxDist) or 0) > 0 and distance > settings.nameMaxDist
	if exceedsNameLimit then EspLabel.hide(state, player); return end
	local weapon, equipped = EspRole.weaponOf(state.role, player, role)
	EspLabel.update(state, player, rectangle, {alpha = alpha, color = color, role = role,
		roleColor = EspColor.role(state.colors, role), weapon = weapon, equipped = equipped, distance = distance, focus = focus,
		ghostTag = isGhost and player.GhostTag or nil})
end

function EspFeature.shouldSkip(state, object, options)
	local previous = object.drawState
	if not previous or state.settings.skipFrames == false or previous.n >= 1 or previous.character ~= options.character then return false end
	if options.rectangle.h >= 160 or previous.color ~= options.color or previous.alpha ~= options.alpha or previous.focus ~= options.focus then return false end
	if math.abs(options.point.X - previous.x) >= 1 or math.abs(options.point.Y - previous.y) >= 1 then return false end
	if math.abs(options.rectangle.h - previous.height) >= 1 or math.abs(options.rectangle.w - previous.width) >= 1 then return false end
	previous.n, previous.delta = previous.n + 1, previous.delta + options.delta
	return true
end

function EspFeature.rememberFrame(object, options)
	local previous = object.drawState
	local elapsed = options.delta + (previous and previous.delta or 0)
	object.drawState = {n = 0, delta = 0, character = options.character, x = options.point.X, y = options.point.Y,
		height = options.rectangle.h, width = options.rectangle.w, color = options.color, alpha = options.alpha, focus = options.focus}
	return elapsed
end

function EspFeature.step(state, delta)
	pcall(EspLabel.gameNames, state)
	if not state.settings.on then EspFeature.hideAll(state); return end
	local context = state.context
	local camera = context.workspace.CurrentCamera
	if not camera then EspFeature.hideAll(state); return end
	state.viewport = camera.ViewportSize
	state.projection.projection = nil
	pcall(EspFeature.prepareProjection, state, camera)

	local roles, present, now = context.roles(), {}, context.environment.os.clock()
	state.modelBudget = 1
	if not state.poolSweepAt or now >= state.poolSweepAt then
		state.poolSweepAt = now + 5
		pcall(EspChamModel.sweep, state)
	end
	state.frameNumber = (state.frameNumber or 0) + 1
	local index, performance = 0, EspSkeleton.perf(state)
	for _, player in context.players:GetPlayers() do
		if player == context.player then continue end
        if context.teamCheck() then
            local allied=context.sameTeam(context.player,player)
            if allied~=false then EspFeature.hide(state,player);EspChams.drop(state,player);continue end
        end
		present[player] = true
		index += 1
		if performance and (index + state.frameNumber) % 2 == 1 and state.objects[player] then
			state.skipDelta[player] = (state.skipDelta[player] or 0) + delta
			continue
		end
		if state.retryAt[player] and now < state.retryAt[player] then continue end
		local elapsed = delta + (state.skipDelta[player] or 0)
		state.skipDelta[player] = nil
		local ok, raised = pcall(EspFeature.update, state, player, roles, camera, elapsed)
		if not ok then
			state.lastError, state.retryAt[player] = tostring(raised), now + 0.5
			EspFeature.hide(state, player)
			EspChams.drop(state, player)
		end
		if ok then state.retryAt[player] = nil end
	end
	for _, player in state.settings.extraPlayers or {} do
		present[player] = true
		local ok, raised = pcall(EspFeature.update, state, player, roles, camera, delta)
		if not ok then state.lastError = tostring(raised) end
	end
	for player in state.objects do if not present[player] then EspFeature.release(state, player) end end
end


return EspFeature
end)()
local espEnvironment=setmetatable({getgenv=function()return {}end},{__index=getfenv(0)})
local espContext={environment=espEnvironment,configuration={},connect=on,players=Players,player=player,
    workspace=workspace,runService=RS,inputService=UIS,coreGui=gui.Parent,textService=game:GetService("TextService"),
    translation={tr=function(value)return value end},nova={Icons={apply=function()end}},
    roles=function()return {}end,teamCheck=function()return teamCheck end,sameTeam=sameAimTeam}
local esp=ImportedESP.create(espContext)
espContext.settings=esp.settings;espContext.colors=esp.colors
local opts=esp.settings
opts.colorMode="Custom";opts.roleText=false;opts.weaponStyle="Text"
opts.chamsRole=false;opts.boneRole=false;opts.tracerRole=false
opts.hideGameNames=false;opts.chamsThrough=true;opts.chamsRange=2000
local espY=228
local function espToggle(field,label)
    local row=button(espY);espY+=38
    local function labelRow()row.Text=label..": "..(opts[field] and "ON" or "OFF")end
    labelRow()
    on(row.Activated,function()opts[field]=not opts[field];opts.onChange(field);labelRow()end)
end
espToggle("on","ESP")
espToggle("box","ESP Boxes")
espToggle("chams","ESP Chams")
espToggle("chamsThrough","Chams Through Walls")
espToggle("name","ESP Names")
espToggle("distance","ESP Distance")
espToggle("weaponIcon","ESP Weapon Text")
espToggle("skeleton","ESP Skeleton")
espToggle("tracer","ESP Tracers")
espToggle("offscreen","ESP Offscreen Markers")
espToggle("headDot","ESP Head Circle")
espToggle("lookLine","ESP Look Direction")
espToggle("visCheck","ESP Visibility Check")
espToggle("boxFill","ESP Box Fill")
espToggle("boxGlow","ESP Box Glow")
local function espCycle(field,label,values)
    local row=button(espY);espY+=38
    local index=table.find(values,opts[field])or 1
    row.Text=label..": "..tostring(opts[field]).." >"
    on(row.Activated,function()
        index=index%#values+1;opts[field]=values[index];opts.onChange(field)
        row.Text=label..": "..tostring(opts[field]).." >"
    end)
end
espCycle("boxStyle","Box Style",{"Corners","Full","Rounded","Double","Brackets"})
espCycle("chamsStyle","Chams Style",{"Soft","Outline","Solid","Glow"})
espCycle("chamsMaterial","Chams Material",{"Flat","Shaded","Metallic","Glow","Glass","ForceField","Gradient","Ghost","Wireframe"})
espCycle("colorMode","ESP Color Mode",{"Custom","Rainbow","Distance","Visibility"})
espCycle("maxDist","ESP Max Distance",{250,500,1000,2000,5000})
espCycle("textSize","ESP Text Size",{10,12,14,16,18})
espCycle("boxThickness","ESP Line Width",{1,1.5,2,3})
on(gui.Destroying,function()esp.settings.stop()end)
local errorShown=nil
on(RS.Heartbeat,function()
    if esp.lastError and esp.lastError~=errorShown then
        errorShown=esp.lastError;warn("[Imported ESP] "..errorShown)
    end
end)
