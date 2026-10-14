if isClient() then return end
require 'PS_Core'
require 'PS_Match'
PSServer = {balls={},rates={},motion={},revision=0,serial=0}
local S,C=PSServer,PSCore
local module='PlayableSoccer'
local function now() return getTimestampMs()/1000 end
local function players()
    local out={}
    if isServer() then
        local all=getOnlinePlayers()
        for i=0,all:size()-1 do out[#out+1]=all:get(i) end
    else
        for i=0,3 do local p=getSpecificPlayer(i); if p then out[#out+1]=p end end
    end
    return out
end
local function owner(p)
    local name=p:getUsername()
    if name and name~='' then return name end
    return 'local:'..tostring(p:getPlayerNum())
end
local function emit(p,command,args)
    if isServer() then sendServerCommand(p,module,command,args)
    elseif PSClient then PSClient.receive(command,args) end
end
local function integer(n) return C.finite(n) and n==math.floor(n) and math.abs(n)<=9007199254740991 end
local function square(x,y,z) return getCell():getGridSquare(math.floor(x),math.floor(y),z) end
local function supported(sq) return sq and sq:TreatAsSolidFloor() end
local function solid(sq) return sq:isSolid() or sq:isSolidTrans() end
local function edge(a,b) return a~=b and (a:isBlockedTo(b) or b:isBlockedTo(a)) end
-- Resolve X then Y, including a diagonal corner guard. Core limits segments to
-- 0.08 tiles; this adapter also sweeps callers such as kick line-of-sight checks.
function S.collision(ball,fx,fy,tx,ty)
    local steps=math.max(1,math.ceil(math.max(math.abs(tx-fx),math.abs(ty-fy))/.08))
    local px,py=fx,fy
    for i=1,steps do
        local nx,ny=fx+(tx-fx)*i/steps,fy+(ty-fy)*i/steps
        local a=square(px,py,ball.z)
        local x=square(nx,py,ball.z)
        local y=square(px,ny,ball.z)
        local target=square(nx,ny,ball.z)
        if not supported(a) or not supported(x) or not supported(y) or not supported(target) then return false,false,true end
        local bx=solid(x) or edge(a,x)
        local by=solid(y) or edge(a,y)
        if not bx and not by and (solid(target) or edge(x,target) or edge(y,target)) then bx=true; by=true end
        if bx or by then return bx,by,false end
        px,py=nx,ny
    end
    return false,false,false
end
local function publish(p)
    local state={revision=S.revision,balls={}}
    for _,b in pairs(S.balls) do
        -- Owners retain their session handle even when far away or on another floor.
        local dx,dy=p:getX()-b.x,p:getY()-b.y
        if b.owner==owner(p) or (p:getZ()==b.z and dx*dx+dy*dy<=10000) then
            local function clone(value)
                if type(value)~='table' then return value end
                local result={}; for k,v in pairs(value) do result[k]=clone(v) end
                return result
            end
            local copy=clone(b)
            state.balls[#state.balls+1]=copy
        end
    end
    emit(p,'state',state)
end
local function publishAll()
    S.revision=S.revision+1
    for _,p in ipairs(players()) do publish(p) end
end
function S.isItemActive(p,item)
    if not p or not item then return false end
    for _,b in pairs(S.balls) do
        if b.itemId==item:getID() then return true end
    end
    return false
end
local function startItem(p,id)
    if not integer(id) then return nil end
    local items=p:getInventory():getItems()
    for i=0,items:size()-1 do
        local item=items:get(i)
        if item:getID()==id and item:getFullType()=='PlayableSoccer.SportsSoccerBall' then return item end
    end
end
local function mobile(p)
    return not p:isDead() and not p:getVehicle() and C.finite(p:getX()) and C.finite(p:getY()) and integer(p:getZ())
end
local cooldown={start=.5,kick=.15,dribble=.4,stop=.15,sync=.25,configure=.5,reset=.5,team=.5}
local function sampleMotion(p,t)
    local key=owner(p)
    local previous=S.motion[key]
    local current={x=p:getX(),y=p:getY(),z=p:getZ(),time=t}
    if previous and previous.z==current.z then
        local elapsed=t-previous.time
        local dx,dy=current.x-previous.x,current.y-previous.y
        local length=math.sqrt(dx*dx+dy*dy)
        if elapsed>0 and elapsed<=.75 and length>.0001 and length<=elapsed*12 then
            current.dx=dx/length; current.dy=dy/length; current.movedAt=t
        elseif previous.movedAt and t-previous.movedAt<=.3 then
            current.dx=previous.dx; current.dy=previous.dy; current.movedAt=previous.movedAt
        end
    end
    S.motion[key]=current
    return current
end
local function dribbleDirection(p,args,t)
    if not (p:isRunning() or p:isSprinting()) or not p:isPlayerMoving() then return nil end
    if not C.finite(args.dx) or not C.finite(args.dy) or math.abs(args.dx)>1 or math.abs(args.dy)>1 then return nil end
    local length=math.sqrt(args.dx*args.dx+args.dy*args.dy)
    if length<.0001 then return nil end
    local dx,dy=args.dx/length,args.dy/length
    local motion=sampleMotion(p,t)
    local sx,sy=motion.dx,motion.dy
    if not sx then sx=p:getForwardDirectionX(); sy=p:getForwardDirectionY() end
    if not C.finite(sx) or not C.finite(sy) then return nil end
    local sl=math.sqrt(sx*sx+sy*sy)
    if sl<.0001 or (dx*sx+dy*sy)/sl<.5 then return nil end
    -- Server direction wins; input is only an intent compatible with it.
    return sx/sl,sy/sl
end
local function clearPoint(x,y,z)
    local sq=square(x,y,z)
    return supported(sq) and not solid(sq)
end
local function clearGoal(g,z)
    local samples=math.ceil(g.width/.2)
    for i=0,samples do
        local x,y=g.ax+(g.bx-g.ax)*i/samples,g.ay+(g.by-g.ay)*i/samples
        if not clearPoint(x,y,z) then return false end
        local bx,by,halt=S.collision({z=z},x+g.nx*.2,y+g.ny*.2,x-g.nx*.2,y-g.ny*.2)
        if bx or by or halt then return false end
    end
    return true
end
function S.command(p,command,args)
    if not p or not cooldown[command] then return end
    local connected=false
    for _,other in ipairs(players()) do if other==p then connected=true end end
    if not connected then return end
    local key,t=owner(p),now()
    local rates=S.rates[key] or {}; S.rates[key]=rates
    if rates[command] and t-rates[command]<cooldown[command] then return end
    rates[command]=t
    args=type(args)=='table' and args or {}
    if command=='sync' then publish(p); return end
    if command=='stop' then
        local b=integer(args.id) and S.balls[args.id]
        if not b or b.owner~=key then return end
        S.balls[b.id]=nil; publishAll(); return
    end
    if not mobile(p) then return end
    if command=='start' then
        local item=startItem(p,args.itemId)
        if not item then return end
        local count=0
        for _,b in pairs(S.balls) do
            if b.owner==key or b.itemId==item:getID() then publish(p); return end
            count=count+1
        end
        if count>=32 then emit(p,'notice',{key='UI_PS_TooManyBalls'}); return end
        local sq=square(p:getX(),p:getY(),p:getZ())
        if not supported(sq) or solid(sq) then return end
        local b=C.newBall(p:getX(),p:getY(),p:getZ())
        if not b then return end
        S.serial=S.serial+1; b.id=S.serial; b.owner=key; b.itemId=item:getID()
        S.balls[b.id]=b
    elseif command=='configure' then
        local b=integer(args.id) and S.balls[args.id]
        if not b or b.owner~=key or p:getZ()~=b.z then return end
        local function invalid() emit(p,'notice',{key='UI_PS_GoalsInvalid'}) end
        local match=PSMatch.configure(args.goalA,args.goalB,args.center)
        if not match then invalid(); return end
        for _,point in ipairs({match.center,{x=match.goals.A.ax,y=match.goals.A.ay},
            {x=match.goals.A.bx,y=match.goals.A.by},{x=match.goals.B.ax,y=match.goals.B.ay},
            {x=match.goals.B.bx,y=match.goals.B.by}}) do
            if (point.x-p:getX())^2+(point.y-p:getY())^2>1600 then invalid(); return end
        end
        if not clearPoint(match.center.x,match.center.y,b.z)
            or not clearGoal(match.goals.A,b.z) or not clearGoal(match.goals.B,b.z) then invalid(); return end
        match.teams[key]='A'; b.match=match; PSMatch.reset(b)
        emit(p,'notice',{key='UI_PS_GoalsReady'})
    elseif command=='reset' then
        local b=integer(args.id) and S.balls[args.id]
        if not b or b.owner~=key or not b.match or p:getZ()~=b.z then return end
        if not clearPoint(b.match.center.x,b.match.center.y,b.z) then return end
        PSMatch.reset(b)
        emit(p,'notice',{key='UI_PS_BallReset'})
    elseif command=='team' then
        local b=integer(args.id) and S.balls[args.id]
        if not b or not b.match or p:getZ()~=b.z or (args.team~='A' and args.team~='B') then return end
        if (p:getX()-b.match.center.x)^2+(p:getY()-b.match.center.y)^2>1600 then return end
        local count=0; for _ in pairs(b.match.teams) do count=count+1 end
        if count>=64 and not b.match.teams[key] then return end
        b.match.teams[key]=args.team
    elseif command=='kick' or command=='dribble' then
        local b=integer(args.id) and S.balls[args.id]
        if not b or p:getZ()~=b.z or (b.match and b.match.phase~='play') then return end
        local dx,dy=p:getX()-b.x,p:getY()-b.y
        local range=command=='dribble' and C.dribbleRange or C.kickRange
        if dx*dx+dy*dy>range*range then return end
        local kx,ky,power,lob=args.dx,args.dy,args.power,args.lob
        if command=='dribble' then
            if b.h~=0 or b.vz~=0 or (rates.kick and t-rates.kick<.4) then return end
            kx,ky=dribbleDirection(p,args,t)
            if not kx then return end
            power=C.dribblePower; lob=false
        end
        local bx,by,halt=S.collision(b,p:getX(),p:getY(),b.x,b.y)
        if bx or by or halt or not C.kick(b,kx,ky,power,lob) then return end
        local length=math.sqrt(kx*kx+ky*ky)
        b.kickSerial=(b.kickSerial or 0)+1; b.kicker=key
        b.kickDx=kx/length; b.kickDy=ky/length; b.lob=lob==true
        b.dribble=command=='dribble'
    end
    publishAll()
end
function S.tick()
    local t=now()
    local dt=S.lastTick and math.max(0,t-S.lastTick) or 0
    S.lastTick=t
    local hasBall=false
    for _ in pairs(S.balls) do hasBall=true; break end
    if not hasBall then return end
    local live={}
    for _,p in ipairs(players()) do
        if mobile(p) then sampleMotion(p,t); live[owner(p)]=true end
    end
    for key in pairs(S.motion) do if not live[key] then S.motion[key]=nil end end
    local scored=false
    for _,b in pairs(S.balls) do
        if b.match and b.match.phase=='goal' then
            if t>=b.match.resetAt and clearPoint(b.match.center.x,b.match.center.y,b.z) then PSMatch.reset(b) end
        else
            C.step(b,dt,S.collision,function(ball,x,y,h)
                if PSMatch.segment(ball,x,y,h,t) then scored=true; return true end
                return false
            end)
        end
    end
    if scored or not S.lastPublish or t-S.lastPublish>=.1 then S.lastPublish=t; publishAll() end
end
Events.OnClientCommand.Add(function(mod,command,p,args) if mod==module then S.command(p,command,args) end end)
Events.OnTick.Add(S.tick)
