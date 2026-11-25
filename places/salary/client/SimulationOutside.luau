-- Studio-only outdoor pilot. Ordinary walking, prompt input, and public remotes only.
local RS = game:GetService("ReplicatedStorage")
local Pathfinding = game:GetService("PathfindingService")
local Outside = {}
function Outside.run(S, player, remotes, Log)
 if not S.enabled() or not S.outside then return end
 local destination, phase, trip, currentDay = "roof", "work", 0, -1
 local pendingFloor = nil
 local visitedOutside = false
 local menuReceived = false
 local PPS = game:GetService("ProximityPromptService")
 local shown = {}
 PPS.PromptShown:Connect(function(p) shown[p] = true end)
 PPS.PromptHidden:Connect(function(p) shown[p] = nil end)
 local characterReadyAt = math.huge
 local function ready(c)
  c:WaitForChild("HumanoidRootPart"); characterReadyAt = os.clock()+2
 end
 player.CharacterAdded:Connect(ready)
 if player.Character then task.spawn(ready,player.Character) end
 local function log(kind, fields)
  fields = fields or {}; fields.kind = kind; fields.source = "studio_measured"
  fields.time = workspace:GetServerTimeNow(); fields.day = RS:GetAttribute("SalaryDay")
  fields.strategy = S.strategies[math.max(1, fields.day or 1)]; fields.trip = trip
  Log.write(fields)
 end
 local function body()
  local c = player.Character
  return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
 end
 local function stopped()
  return RS:GetAttribute("SimulationDone") or player:GetAttribute("Fired")
 end
 local function commonEvent()
  local e, stage = RS:GetAttribute("SalaryEvent"), RS:GetAttribute("SalaryEventStage") or ""
  return (e == "drill" or e == "workshop") and stage ~= "" and stage ~= "done"
 end
 local function floor()
  local r = body(); if not r then return "missing" end
  if r.Position.Y > 250 then return if r.Position.X < 150 then "roof" else "cabin" end
  return if r.Position.Z > 700 then "lobby" else "office"
 end
 local function stand()
  local r, h = body()
  if h and h.SeatPart then
   h.Sit = false; h.Jump = true
   local deadline=os.clock()+1
   repeat task.wait(0.1) until not h.SeatPart or os.clock()>deadline
   if r then
    -- Walk backwards out of the chair before planning from the aisle.
    local back=Vector3.new(-r.CFrame.LookVector.X,0,-r.CFrame.LookVector.Z)
    h:MoveTo(r.Position+back*5)
    task.wait(0.8)
   end
  end
 end
 local function walk(target, label, seconds)
  local r,h = body(); if not r or not h or stopped() then return false end
  stand()
  local start = os.clock(); local initial = r.Position; local originFloor = floor()
  local path = Pathfinding:CreatePath({AgentRadius=1.5,AgentHeight=5,AgentCanJump=true})
  local ok = pcall(function() path:ComputeAsync(r.Position, target) end)
  local status = tostring(path.Status)
  if ok and path.Status == Enum.PathStatus.Success then
   for _, w in path:GetWaypoints() do
    if floor() ~= originFloor or stopped() or commonEvent() or RS:GetAttribute("SalaryPhase") == "offwork" or os.clock()-start > seconds then break end
    if w.Action == Enum.PathWaypointAction.Jump then h.Jump=true end
    h:MoveTo(w.Position)
    local untilAt = math.min(os.clock()+4,start+seconds)
    repeat task.wait(0.1) until (Vector2.new(r.Position.X-w.Position.X,r.Position.Z-w.Position.Z)).Magnitude<2 or os.clock()>untilAt or stopped() or floor()~=originFloor
    if os.clock()>untilAt or floor()~=originFloor then break end
   end
  end
  local reached=(r.Position-target).Magnitude<6
  h:MoveTo(r.Position)
  log("outside_navigation",{label=label,pathStatus=status,reached=reached,seconds=os.clock()-start,position={r.Position.X,r.Position.Y,r.Position.Z},target={target.X,target.Y,target.Z},moved=(r.Position-initial).Magnitude})
  return reached
 end
 local function prompt(p)
  local r=body()
  if not p or not r or not p.Parent:IsA("BasePart") then return false end
  -- Rotate only the camera, as a player would look at the interaction target.
  local camera=workspace.CurrentCamera
  if camera then camera.CFrame=CFrame.lookAt(camera.CFrame.Position,p.Parent.Position) end
  local deadline=os.clock()+1
  repeat task.wait(0.1) until shown[p] or os.clock()>deadline
  local distance=(r.Position-p.Parent.Position).Magnitude
  log("outside_prompt",{object=p.ObjectText,shown=shown[p]==true,enabled=p.Enabled,serviceEnabled=PPS.Enabled,distance=distance,maxDistance=p.MaxActivationDistance,position={r.Position.X,r.Position.Y,r.Position.Z}})
  if not p.Enabled or not PPS.Enabled or not shown[p] or distance>p.MaxActivationDistance then return false end
  p:InputHoldBegin(); task.wait(math.max(0.25,p.HoldDuration+0.2));p:InputHoldEnd()
  return true
 end
 local function approach(part, label, force)
  local r=body(); if not r then return false end
  local p=part:FindFirstChildWhichIsA("ProximityPrompt")
  if not force and p and shown[p] and (r.Position-part.Position).Magnitude<=math.min(4,p.MaxActivationDistance) then return true end
  local vectors={Vector3.new(0,0,-3),Vector3.new(0,0,3),Vector3.new(-3,0,0),Vector3.new(3,0,0)}
  table.sort(vectors,function(a,b) return (part.Position+a-r.Position).Magnitude<(part.Position+b-r.Position).Magnitude end)
  for _,v in vectors do
   if walk(Vector3.new(part.Position.X+v.X,r.Position.Y,part.Position.Z+v.Z),label,16) then
    if not p then return true end
    local camera=workspace.CurrentCamera
    if camera then camera.CFrame=CFrame.lookAt(camera.CFrame.Position,part.Position) end
    task.wait(0.3)
    if shown[p] then return true end
   end
   if commonEvent() or stopped() then return false end
  end
  log("outside_navigation_failed",{label=label});return false
 end
 local function findPart(test)
  local r=body();local best,dist=nil,math.huge
  for _,x in workspace:GetDescendants() do
   if x:IsA("BasePart") and test(x) then
    local d=if r then (r.Position-x.Position).Magnitude else 0
    if d<dist then best=x;dist=d end
   end
  end
  return best
 end
 local function desk()
  return findPart(function(x) return x:IsA("Seat") and x:GetAttribute("OwnerId")==player.UserId end)
 end
 local function elevator()
  local f=floor()
  return findPart(function(x)
   local p=x:FindFirstChildWhichIsA("ProximityPrompt")
   if not p or not string.find(p.ObjectText,"엘리베이터",1,true) then return false end
   return (f=="office" and x.Position.Y<100 and x.Position.Z<200)
    or (f=="roof" and x.Name=="RoofElevatorDoor")
    or (f=="lobby" and x.Position.Z>700 and (if S.company=="nunchi" then x.Position.X>150 else x.Position.X< -150))
  end)
 end
 remotes.ElevatorMenu.OnClientEvent:Connect(function(from, options)
  menuReceived=true
  log("outside_menu",{from=from,pending=pendingFloor})
  if not pendingFloor then return end
  for _,option in options do
   if option.id==pendingFloor then
    log("outside_elevator_request",{from=from,to=pendingFloor})
    remotes.ElevatorGo:FireServer(pendingFloor);return
   end
  end
 end)
 remotes.Notify.OnClientEvent:Connect(function(message) log("outside_notice",{message=tostring(message)}) end)
 remotes.ElevatorRide.OnClientEvent:Connect(function(info)
  log("outside_elevator",{withBoss=info.withBoss,result=info.result,toRoof=info.toRoof})
  if info.result or not info.withBoss then return end
  -- React only after the same warning becomes visible in the normal HUD, plus 0.5 s.
  for _,event in info.events do
   task.delay(math.max(0,info.start+event.t-info.warn+0.5-workspace:GetServerTimeNow()),function()
    if not stopped() then remotes.ElevatorDodge:FireServer(event.kind=="look",workspace:GetServerTimeNow()) end
   end)
  end
 end)
 local function ride(to)
  if floor()==to then return true end
  if floor()=="missing" or floor()=="cabin" then return false end
  local stairs=S.outsideRoute=="stairs" and to=="office" and floor()=="lobby"
  local part=if stairs then findPart(function(x)
   local p=x:FindFirstChildWhichIsA("ProximityPrompt")
   return p and p.ObjectText=="계단" and x.Position.Z>700
  end) else elevator()
  if not part then log("outside_navigation_failed",{label="transport_missing",floor=floor()});return false end
  for attempt=1,3 do
   if not approach(part,if stairs then "stairs_office" else "elevator_"..to,attempt>1) then return false end
   pendingFloor=to;menuReceived=false
   local begin=os.clock()
   local sent=prompt(part:FindFirstChildWhichIsA("ProximityPrompt"))
   if sent then
    repeat task.wait(0.1) until menuReceived or stairs or os.clock()-begin>2 or stopped()
    if menuReceived or stairs then
     repeat task.wait(0.25) until floor()==to or os.clock()-begin>18 or stopped() or commonEvent()
    end
   end
   pendingFloor=nil
   local success=floor()==to
   log("outside_arrival",{destination=to,route=if stairs then "stairs" else "elevator",success=success,seconds=os.clock()-begin,attempt=attempt,inputSent=sent,menuReceived=menuReceived})
   if success then return true end
   if stopped() or commonEvent() then return false end
  end
  return false
 end
 local readyAt=os.clock()+3
 local outingAt, recoveredAt=0,0
 while not RS:GetAttribute("SimulationDone") do
  task.wait(0.25)
  local day=RS:GetAttribute("SalaryDay") or 0
  if day~=currentDay then
   currentDay=day;destination="lobby";phase="work";trip=0
   log("outside_plan",{destination=destination,returnGauge=55,returnSuspicion=45,recoverGauge=5,minimumWork=true})
  end
  if RS:GetAttribute("SalaryWaiting") and RS:GetAttribute("SimulationReady") and player:GetAttribute("Rank") and os.clock()>math.max(readyAt,characterReadyAt) then
   remotes.ClockIn:FireServer("desk");continue
  end
  if stopped() or RS:GetAttribute("SalaryPhase")=="offwork" or not RS:GetAttribute("SimulationReady") then continue end
  if commonEvent() or os.clock()<characterReadyAt or floor()=="missing" then continue end
  local away=player:GetAttribute("AwayGauge") or 0
  local suspicion=player:GetAttribute("Suspicion") or 0
  local quota=(player:GetAttribute("WorkSeconds") or 0)>=(player:GetAttribute("WorkQuota") or 85)
  local minute=RS:GetAttribute("SalaryMinute") or 0
  if phase=="work" or phase=="recover" then
   if not player:GetAttribute("Seated") then
    if floor()~="office" then ride("office") else
     local seat=desk();if seat and approach(seat,"desk") then prompt(seat:FindFirstChild("SitPrompt")) end
    end
   else
    remotes.SetAction:FireServer("work")
    if quota and away<=5 and suspicion<=10 and RS:GetAttribute("SalaryEvent")~="blackout" then
     trip+=1;phase="outbound";outingAt=os.clock();visitedOutside=false
     log("outside_departure",{destination=destination,workSeconds=player:GetAttribute("WorkSeconds"),quota=player:GetAttribute("WorkQuota"),away=away})
     stand()
    end
   end
  elseif phase=="outbound" then
   if ride(destination) then visitedOutside=true;phase="explore";recoveredAt=os.clock() else phase="return" end
  elseif phase=="explore" then
   -- Return budget reserves time for walking, lift travel, and sitting down.
   local lunchReturn=minute>=770 and minute<800
   if away>=55 or suspicion>=45 or lunchReturn or os.clock()-outingAt>90 then
    log("outside_return",{away=away,suspicion=suspicion,elapsed=os.clock()-outingAt,reason=if lunchReturn then "lunch" elseif suspicion>=45 then "suspicion" elseif away>=55 then "away" else "time_budget"})
    phase="return";stand()
   elseif floor()~=destination then phase="return"
   elseif os.clock()-recoveredAt>6 then
    recoveredAt=os.clock()
    if destination=="roof" then
     local lounger=findPart(function(x) return x:IsA("Seat") and x.Name=="Lounger" end)
     local _,h=body()
     if lounger and h and not h.SeatPart then
      if approach(lounger,"lounger") then prompt(lounger:FindFirstChild("SitPrompt"));log("outside_activity",{activity="lounger_requested"}) end
     end
    else
     local r=body()
     local target=if S.company=="nunchi" then Vector3.new(64,6,822) else Vector3.new(-74,5,930)
     local reached=walk(target,"park_walk",16)
     if not reached then
      for _,offset in {Vector3.new(0,0,6),Vector3.new(6,0,0),Vector3.new(-6,0,0)} do
       if stopped() or (player:GetAttribute("AwayGauge") or 0)>=55 then break end
       if walk(target+offset,"park_cover_alternative",12) then reached=true;break end
      end
     end
     log("outside_cover_attempt",{reached=reached})
    end
   end
  elseif phase=="return" then
   if floor()~="office" then ride("office") else
    local seat=desk();if seat and approach(seat,"desk_return") then prompt(seat:FindFirstChild("SitPrompt")) end
    if player:GetAttribute("Seated") then
     log(if visitedOutside then "outside_trip_done" else "outside_trip_aborted",{seconds=os.clock()-outingAt,away=away,suspicion=suspicion});phase="recover"
    end
   end
  end
 end
end
return Outside
