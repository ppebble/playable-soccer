PSCore = PSCore or {}
local C = PSCore
C.maxDistance = 23.92
C.motionRate = 1.4
C.groundDrag = 3
C.airDrag = C.groundDrag
C.maxSpeed = math.sqrt(2*C.groundDrag*C.maxDistance)
C.kickRange = 1.4
C.dribbleRange = .8
C.chargeMilliseconds = 900
function C.chargePower(elapsed)
    return math.min(1,math.max(0,elapsed/C.chargeMilliseconds))
end
-- x/y use horizontal tile units; h/vz use world floor units. One rendered
-- floor spans approximately three horizontal tiles vertically.
C.tilesPerFloor = 3
C.gravity = 9.81 / C.tilesPerFloor
function C.finite(n)
    return type(n)=='number' and n==n and n>-math.huge and n<math.huge
end
function C.newBall(x,y,z)
    if not C.finite(x) or not C.finite(y) or not C.finite(z) or z~=math.floor(z) then return nil end
    return {x=x,y=y,z=z,h=0,vx=0,vy=0,vz=0}
end
local function valid(b)
    if type(b)~='table' then return false end
    for _,k in ipairs({'x','y','z','h','vx','vy','vz'}) do if not C.finite(b[k]) then return false end end
    return b.h>=0 and math.abs(b.vx)<=64 and math.abs(b.vy)<=64 and math.abs(b.vz)<=64
end
function C.kick(b,dx,dy,power,lob)
    if not valid(b) or not C.finite(dx) or not C.finite(dy) or not C.finite(power)
        or (lob~=nil and type(lob)~='boolean') or power<0 or power>1 or math.abs(dx)>100000 or math.abs(dy)>100000 then return false end
    local length=math.sqrt(dx*dx+dy*dy)
    if length<.00001 or b.h>.35 then return false end
    -- Charge controls travel distance, not speed. Equal air/ground drag keeps
    -- the landing height independent from final horizontal stopping distance.
    local distance=lob and (.65+(C.maxDistance-.65)*power^1.4) or (1.5+(C.maxDistance-1.5)*power)
    local peak=0
    if lob then peak=.7+2.9*power
    elseif power>=.8 then peak=.02+.13*(power-.8)/.2 end
    -- Reserve a small part of the range for forward motion on first landing.
    b.landingRange=lob and math.min(.4,distance*.3) or nil
    b.landingDx=lob and dx/length or nil; b.landingDy=lob and dy/length or nil
    local speed=math.sqrt(2*C.groundDrag*(distance-(b.landingRange or 0)))
    b.vx=dx/length*speed; b.vy=dy/length*speed; b.vz=math.sqrt(2*C.gravity*peak)
    b.rollDrag=C.groundDrag
    return true
end
function C.dribble(b,dx,dy,runnerSpeed)
    if not valid(b) or b.h~=0 or b.vz~=0 or (b.match and b.match.phase~='play')
        or not C.finite(runnerSpeed) or runnerSpeed<0 or runnerSpeed>12 then return false end
    if not C.kick(b,dx,dy,0,false) then return false end
    local length=math.sqrt(dx*dx+dy*dy)
    local speed=math.min(12,math.max(6,runnerSpeed+2.5))
    b.vx=dx/length*speed; b.vy=dy/length*speed; b.vz=0
    b.rollDrag=C.groundDrag*2 -- Half the previous touch distance, not half speed.
    return true
end
-- Collision callback checks each short segment. The optional third return value
-- freezes the ball at unavailable terrain instead of reflecting into the void.
function C.step(b,dt,collision,onSegment)
    if not valid(b) or not C.finite(dt) or dt<=0 then return false end
    if b.match and b.match.phase=='goal' then b.vx=0; b.vy=0; b.vz=0; return true end
    -- Bound catch-up after stalls. Never teleport a ball across a long pause.
    -- Speed up the whole trajectory without changing its range or apex.
    dt=math.min(dt,.25)*C.motionRate
    local speed=math.sqrt(b.vx*b.vx+b.vy*b.vy)
    local count=math.max(1,math.ceil(dt*120),math.ceil(speed*dt/.08))
    local slice=dt/count
    for _=1,count do
        local landed=false
        local fx,fy,fh=b.x,b.y,b.h
        local v=math.sqrt(b.vx*b.vx+b.vy*b.vy)
        local drag=b.rollDrag or C.groundDrag
        local travelTime=math.min(slice,v/drag)
        local travel=v*travelTime-.5*drag*travelTime*travelTime
        local scale=v>0 and travel/v or 0
        local tx,ty=b.x+b.vx*scale,b.y+b.vy*scale
        local bx,by,halt=false,false,false
        if collision then bx,by,halt=collision(b,b.x,b.y,tx,ty) end
        if halt then b.vx=0; b.vy=0; b.vz=0; b.h=0; return true end
        if bx then b.vx=-b.vx*.72 else b.x=tx end
        if by then b.vy=-b.vy*.72 else b.y=ty end
        if b.h>0 or b.vz~=0 then
            b.vz=b.vz-C.gravity*slice; b.h=b.h+b.vz*slice
            if b.h<=0 then
                landed=true
                b.h=0; b.vz=-b.vz*.48
                if b.vz<.3/C.tilesPerFloor then b.vz=0 end
            end
        end
        do
            local v=math.sqrt(b.vx*b.vx+b.vy*b.vy)
            if v>0 then
                local nextV=math.max(0,v-drag*slice)
                if nextV<.03 then nextV=0 end
                b.vx=b.vx*nextV/v; b.vy=b.vy*nextV/v
            end
        end
        if b.landingRange then
            local horizontal=math.sqrt(b.vx*b.vx+b.vy*b.vy)
            if horizontal>0 then
                b.landingDx=b.vx/horizontal; b.landingDy=b.vy/horizontal
            end
            if landed then
                local forward=math.sqrt(horizontal*horizontal+2*drag*b.landingRange)
                b.vx=b.landingDx*forward; b.vy=b.landingDy*forward
                b.landingRange=nil; b.landingDx=nil; b.landingDy=nil
            end
        end
        if onSegment and onSegment(b,fx,fy,fh) then return true end
    end
    return true
end
