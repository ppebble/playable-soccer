if isClient() then return end
require 'PS_Core'
require 'PS_Match'
PSServer = {balls={},rates={},motion={},controls={},stunned={},revision=0,serial=0}
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
local cooldown={start=.5,kick=.15,control=0,tackle=.8,stop=.15,sync=.25,configure=.5,reset=.5,team=.5}
local function sampleMotion(p,t)
    local key=owner(p)
    local previous=S.motion[key]
    local current={x=p:getX(),y=p:getY(),z=p:getZ(),time=t,positionAt=t}
    if previous and previous.z==current.z then
        local elapsed=t-(previous.positionAt or previous.time)
        local dx,dy=current.x-previous.x,current.y-previous.y
        local length=math.sqrt(dx*dx+dy*dy)
        if elapsed>0 and elapsed<=.75 and length>.0001 and length<=elapsed*12 then
            current.dx=dx/length; current.dy=dy/length; current.speed=math.min(12,length/elapsed); current.movedAt=t
            if elapsed<=.15 and length<=1.2 then
                current.fromX=previous.x; current.fromY=previous.y; current.fromAt=previous.positionAt or previous.time
            end
        elseif length<=.0001 and previous.movedAt and t>=previous.movedAt and t-previous.movedAt<=.3 then
            current.dx=previous.dx; current.dy=previous.dy; current.speed=previous.speed; current.movedAt=previous.movedAt
        elseif length>.0001 and (elapsed<=0 or length>elapsed*12) then
            current.invalidMove=true
        end
        if length<=.0001 then
            current.positionAt=previous.positionAt or previous.time
            if previous.fromAt and t-previous.fromAt<=.15 then
                current.fromX=previous.fromX; current.fromY=previous.fromY; current.fromAt=previous.fromAt
            end
        end
    end
    S.motion[key]=current
    return current
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
local function clearPath(b,x,y,tx,ty)
    local bx,by,halt=S.collision(b,x,y,tx,ty)
    return not bx and not by and not halt
end
local function release(b,t)
    b.possession=nil; b.captureAfter=t+.35
    b.vx=0; b.vy=0; b.vz=0
end
local function downed(p)
    if (p.isOnFloor and p:isOnFloor()) or (p.isKnockedDown and p:isKnockedDown()) then return true end
    local state=p.getCurrentStateName and p:getCurrentStateName()
    local action=p.getCurrentActionContextStateName and p:getCurrentActionContextStateName()
    return (type(state)=='string' and string.find(string.lower(state),'getup',1,true)~=nil)
        or (type(action)=='string' and string.find(string.lower(action),'getup',1,true)~=nil)
end
local function participant(p,b,t)
    local key=owner(p); local control=S.controls[key]
    return mobile(p) and p:getZ()==b.z and control and control.id==b.id and t-control.at<=3
        and not (S.stunned[key] and S.stunned[key]>t)
        and not downed(p)
end
local function acquire(p,b,t)
    if not participant(p,b,t) then return false end
    local key=owner(p)
    for _,other in pairs(S.balls) do
        if other~=b and other.possession and other.possession.kind=='player' and other.possession.key==key then return false end
    end
    b.possession={kind='player',key=key}; b.h=0; b.vx=0; b.vy=0; b.vz=0
    return true
end
local function knockDown(p,b,t)
    local key=owner(p)
    S.stunned[key]=t+1.2
    b.tackleSerial=(b.tackleSerial or 0)+1; b.tackled=key; b.tackleAt=t
    release(b,t)
    emit(p,'tackled',{id=b.id,serial=b.tackleSerial})
end
local function zonesFor(match,b)
    local nx,ny=match.goals.A.nx,match.goals.A.ny
    local zones={}
    for _,spec in ipairs({{'tackle',-1},{'keeper',1}}) do
        local x,y=match.center.x-ny*4*spec[2],match.center.y+nx*4*spec[2]
        local clear=clearPoint(x,y,b.z) and clearPath(b,match.center.x,match.center.y,x,y)
        for _,offset in ipairs({{.9,0},{-.9,0},{0,.9},{0,-.9}}) do
            if not clearPoint(x+offset[1],y+offset[2],b.z) or not clearPath(b,x,y,x+offset[1],y+offset[2]) then clear=false end
        end
        if clear then zones[spec[1]]={x=x,y=y,r=.9} end
    end
    return zones
end
local function keeperCapture(b,t)
    local zone=b.match and b.match.testZones and b.match.testZones.keeper
    if not b.possession and zone and b.h<=.12 and (not b.zoneGrace or t>=b.zoneGrace)
        and (not b.captureAfter or t>=b.captureAfter)
        and (b.x-zone.x)^2+(b.y-zone.y)^2<=zone.r^2
        and clearPath(b,zone.x,zone.y,b.x,b.y) then
        b.possession={kind='zone',key='keeper'}; b.h=0; b.vx=0; b.vy=0; b.vz=0
        return true
    end
    return false
end
local function tackle(p,b,args,t)
    if not participant(p,b,t) or not b.possession or b.h>.12 then return false end
    if not C.finite(args.dx) or not C.finite(args.dy) or math.abs(args.dx)>1 or math.abs(args.dy)>1 then return false end
    local length=math.sqrt(args.dx^2+args.dy^2)
    if length<.001 then return false end
    local dx,dy=b.x-p:getX(),b.y-p:getY(); local distance=math.sqrt(dx*dx+dy*dy)
    if distance>1.4 or (distance>.01 and (dx*args.dx+dy*args.dy)/(distance*length)<.5)
        or not clearPath(b,p:getX(),p:getY(),b.x,b.y) then return false end
    if b.possession.kind=='player' then
        if b.possession.key==owner(p) then return false end
        local teams=b.match and b.match.teams
        if teams and teams[owner(p)] and teams[owner(p)]==teams[b.possession.key] then return false end
        local victim
        for _,other in ipairs(players()) do if owner(other)==b.possession.key then victim=other end end
        if not victim then release(b,t); return false end
        if (victim:getX()-p:getX())^2+(victim:getY()-p:getY())^2>1.8^2
            or not clearPath(b,p:getX(),p:getY(),victim:getX(),victim:getY()) then return false end
        knockDown(victim,b,t)
    else
        release(b,t); b.zoneGrace=t+.6
    end
    if distance<=.8 then acquire(p,b,t) end
    return true
end
local function possessionTick(b,dt,t,all)
    if b.possession then
        if b.possession.kind=='zone' then return true end
        local holder
        for _,p in ipairs(all) do if owner(p)==b.possession.key then holder=p end end
        if not holder or not participant(holder,b,t) or (holder:getX()-b.x)^2+(holder:getY()-b.y)^2>4 then release(b,t);return true end
        local zone=b.match and b.match.testZones and b.match.testZones.tackle
        if zone and (holder:getX()-zone.x)^2+(holder:getY()-zone.y)^2<=zone.r^2
            and clearPath(b,holder:getX(),holder:getY(),zone.x,zone.y) then knockDown(holder,b,t);return true end
        local motion=S.motion[owner(holder)]
        if motion and motion.invalidMove then release(b,t);return true end
        local dx,dy=holder:getForwardDirectionX(),holder:getForwardDirectionY()
        if motion and motion.dx then dx=motion.dx;dy=motion.dy end
        if not C.finite(dx) or not C.finite(dy) or dx*dx+dy*dy<.001 then release(b,t);return true end
        local length=math.sqrt(dx*dx+dy*dy)
        local tx,ty=holder:getX()+dx/length*.55,holder:getY()+dy/length*.55
        if not clearPath(b,holder:getX(),holder:getY(),tx,ty) or not clearPath(b,b.x,b.y,tx,ty) then release(b,t);return true end
        local mx,my=tx-b.x,ty-b.y;local distance=math.sqrt(mx*mx+my*my)
        local fraction=distance>0 and math.min(1,12*math.min(dt,.25)/distance) or 0
        local x,y=b.x,b.y;b.x=x+mx*fraction;b.y=y+my*fraction
        b.h=0;b.vx=0;b.vy=0;b.vz=0
        if PSMatch.segment(b,x,y,0,t) then release(b,t) end
        return true
    end
    if keeperCapture(b,t) then return true end
    if b.h~=0 or b.vz~=0 or b.vx^2+b.vy^2>16 or (b.captureAfter and t<b.captureAfter) then return false end
    for _,p in ipairs(all) do
        local key=owner(p)
        if not (b.shooter==key and b.shooterAfter and t<b.shooterAfter)
            and (p:getX()-b.x)^2+(p:getY()-b.y)^2<=.8^2 and participant(p,b,t)
            and clearPath(b,p:getX(),p:getY(),b.x,b.y) and acquire(p,b,t) then return true end
    end
    return false
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
    if command=='control' then
        local previous=S.controls[key]
        if args.active==false then
            if not S.controls[key] or S.controls[key].id~=args.id then return end
            S.controls[key]=nil
            for _,b in pairs(S.balls) do if b.possession and b.possession.kind=='player' and b.possession.key==key then release(b,t) end end
        elseif args.active==true then
            local b=integer(args.id) and S.balls[args.id]
            if not b or not mobile(p) or p:getZ()~=b.z or (p:getX()-b.x)^2+(p:getY()-b.y)^2>10000 then return end
            for _,held in pairs(S.balls) do if held.id~=b.id and held.possession and held.possession.kind=='player' and held.possession.key==key then release(held,t) end end
            S.controls[key]={id=b.id,at=t}
        else return end
        if not previous or args.active==false or previous.id~=args.id then publishAll() end
        return
    end
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
        b.spawn={x=b.x,y=b.y}
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
        match.teams[key]='A'; b.match=match;release(b,t); PSMatch.reset(b)
        match.testZones=zonesFor(match,b)
        emit(p,'notice',{key='UI_PS_GoalsReady'})
        if not match.testZones.tackle or not match.testZones.keeper then emit(p,'notice',{key='UI_PS_TestZonesUnavailable'}) end
    elseif command=='reset' then
        local b=integer(args.id) and S.balls[args.id]
        if not b or b.owner~=key or p:getZ()~=b.z then return end
        local center=b.match and b.match.center or b.spawn
        if not center or not clearPoint(center.x,center.y,b.z) then return end
        release(b,t)
        if b.match then PSMatch.reset(b)
        else b.x=center.x;b.y=center.y;b.h=0;b.vx=0;b.vy=0;b.vz=0 end
        emit(p,'notice',{key='UI_PS_BallReset'})
    elseif command=='team' then
        local b=integer(args.id) and S.balls[args.id]
        if not b or not b.match or p:getZ()~=b.z or (args.team~='A' and args.team~='B') then return end
        if (p:getX()-b.match.center.x)^2+(p:getY()-b.match.center.y)^2>1600 then return end
        local count=0; for _ in pairs(b.match.teams) do count=count+1 end
        if count>=64 and not b.match.teams[key] then return end
        b.match.teams[key]=args.team
    elseif command=='tackle' then
        local b=integer(args.id) and S.balls[args.id]
        if not b or (b.match and b.match.phase~='play') or not tackle(p,b,args,t) then return end
    elseif command=='kick' then
        local b=integer(args.id) and S.balls[args.id]
        if not b or p:getZ()~=b.z or (b.match and b.match.phase~='play') or (S.stunned[key] and t<S.stunned[key]) then return end
        if b.possession and (b.possession.kind~='player' or b.possession.key~=key) then return end
        if downed(p) or (b.possession and not participant(p,b,t)) then return end
        if (p:getX()-b.x)^2+(p:getY()-b.y)^2>C.kickRange^2 or not clearPath(b,p:getX(),p:getY(),b.x,b.y) then return end
        if not C.kick(b,args.dx,args.dy,args.power,args.lob) then return end
        b.possession=nil;b.captureAfter=t+.35;b.shooter=key;b.shooterAfter=t+.6
        local length=math.sqrt(args.dx^2+args.dy^2)
        b.kickSerial=(b.kickSerial or 0)+1;b.kicker=key
        b.kickDx=args.dx/length;b.kickDy=args.dy/length;b.lob=args.lob==true;b.dribble=false
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
    local live={};local all=players()
    for _,p in ipairs(all) do
        if mobile(p) then sampleMotion(p,t); live[owner(p)]=true end
    end
    for key in pairs(S.motion) do if not live[key] then S.motion[key]=nil end end
    for key,control in pairs(S.controls) do if not live[key] or t-control.at>3 then S.controls[key]=nil end end
    for key,untilTime in pairs(S.stunned) do if t>=untilTime then S.stunned[key]=nil end end
    local scored=false
    for _,b in pairs(S.balls) do
        if b.match and b.match.phase=='goal' then
            if b.possession then release(b,t) end
            if t>=b.match.resetAt and clearPoint(b.match.center.x,b.match.center.y,b.z) then release(b,t);PSMatch.reset(b) end
        else
            if not possessionTick(b,dt,t,all) then
                C.step(b,dt,S.collision,function(ball,x,y,h)
                    if PSMatch.segment(ball,x,y,h,t) then release(ball,t);scored=true; return true end
                    return keeperCapture(ball,t)
                end)
            elseif b.match and b.match.phase=='goal' then scored=true end
        end
    end
    if scored or not S.lastPublish or t-S.lastPublish>=.1 then S.lastPublish=t; publishAll() end
end
Events.OnClientCommand.Add(function(mod,command,p,args) if mod==module then S.command(p,command,args) end end)
Events.OnTick.Add(S.tick)
