require "PS_Projection"
PSSetup={}
local S=PSSetup
local function owner(p)
    local name=p:getUsername()
    return name and name~="" and name or "local:"..tostring(p:getPlayerNum())
end
function S.active() return S.pending~=nil end
function S.cancel()
    local pending=S.pending
    S.pending=nil
    if pending and PSClient.ball(pending.id) then PSClient.selected=pending.id end
end
function S.receive(command,args)
    local pending=S.pending
    if not pending or not pending.submitted then return end
    if command=="notice" and args.key=="UI_PS_GoalsInvalid" then
        pending.points={};pending.submitted=nil;pending.accepted=nil
    elseif command=="notice" and args.key=="UI_PS_GoalsReady" then
        pending.accepted=true
    elseif command=="state" and pending.accepted then
        S.cancel()
    end
end
function S.update()
    local pending=S.pending
    if pending and pending.submitted and getTimestampMs()-pending.submitted>5000 then
        pending.submitted=nil;pending.points={};pending.accepted=nil
        PSClient.notice("UI_PS_SetupTimeout")
    end
end
function S.validLine(a,b)
    if not a or not b then return false end
    local length=math.sqrt((b.x-a.x)^2+(b.y-a.y)^2)
    return length>=2 and length<=10
end
function S.begin(id)
    local C=PSClient
    if not PSProjection.available() then C.notice("UI_PS_CameraUnsupported"); return end
    local b=C.ball(id)
    if not b then return end
    C.leave()
    S.pending={id=id,z=b.z,points={}}
    C.notice("UI_PS_Place1")
end
function S.click(button)
    if not S.pending then return false end
    if S.pending.submitted then return true end
    if button~=0 then S.cancel();return true end
    local C,p=PSClient,getSpecificPlayer(0)
    if not p or C.blocked() then return true end
    local pending=S.pending
    if math.floor(p:getZ())~=pending.z then S.cancel();return true end
    local x,y=PSProjection.screenToWorld(0,getMouseX(),getMouseY(),pending.z)
    if not x then C.notice("UI_PS_CameraUnsupported");return true end
    local points=pending.points
    local point={x=x,y=y}
    if (#points==1 or #points==3) and not S.validLine(points[#points],point) then
        C.notice("UI_PS_LineInvalid");return true
    end
    points[#points+1]=point
    if #points==4 then
        local center={x=(points[1].x+points[2].x+points[3].x+points[4].x)/4,
            y=(points[1].y+points[2].y+points[3].y+points[4].y)/4}
        pending.submitted=getTimestampMs()
        C.notice("UI_PS_SetupWaiting")
        C.send("configure",{id=pending.id,
            goalA={ax=points[1].x,ay=points[1].y,bx=points[2].x,by=points[2].y},
            goalB={ax=points[3].x,ay=points[3].y,bx=points[4].x,by=points[4].y},center=center})

    else C.notice("UI_PS_Place"..tostring(#points+1)) end
    return true
end
function S.menu(index,context,C)
    if index~=0 then return end
    local p=getSpecificPlayer(index)
    if not p then return end
    for _,b in pairs(C.state.balls or {}) do
        if b.owner==owner(p) then
            context:addOption(getText("UI_PS_ConfigureGoals"),b.id,S.begin)
            if b.match then
                context:addOption(getText("UI_PS_ResetBall"),b.id,function(id) C.send("reset",{id=id}) end)
            end
        end
    end
    local b=C.ball(C.selected)
    if not b then
        local distance=64
        for _,candidate in pairs(C.state.balls or {}) do
            local d=(candidate.x-p:getX())^2+(candidate.y-p:getY())^2
            if candidate.match and candidate.z==math.floor(p:getZ()) and d<distance then
                b=candidate;distance=d
            end
        end
    end
    if b and b.match then
        context:addOption(getText("UI_PS_TeamA"),b.id,function(id) C.selected=id;C.send("team",{id=id,team="A"}) end)
        context:addOption(getText("UI_PS_TeamB"),b.id,function(id) C.selected=id;C.send("team",{id=id,team="B"}) end)
    end
end
