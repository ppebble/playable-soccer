require "PS_Projection"
require "PS_Core"
require "PS_Setup"
PSHUD={}
local H=PSHUD
local function project(x,y,z) return PSProjection.worldToScreen(0,x,y,z) end
local function marker(panel,x,y,z,label,r,g,b)
    local sx,sy=project(x,y,z)
    if not sx then return end
    panel:drawRect(sx-4,sy-24,8,24,.95,r,g,b)
    panel:drawTextCentre(label,sx,sy-45,r,g,b,1,UIFont.Small)
end
local function line(panel,g,z,r,b)
    local width=math.sqrt((g.bx-g.ax)^2+(g.by-g.ay)^2)
    local n=math.max(1,math.ceil(width*8))
    for i=0,n do
        local x,y=project(g.ax+(g.bx-g.ax)*i/n,g.ay+(g.by-g.ay)*i/n,z)
        if x then panel:drawRect(x-1,y-1,3,3,.7,r,.6,b) end
    end
end
local function testZone(panel,zone,z,label,red,green,blue)
    if not zone then return end
    -- Use the same world-space radius as the authoritative contact check.
    for i=0,47 do
        local angle=i*math.pi*2/48
        local x,y=project(zone.x+math.cos(angle)*zone.r,zone.y+math.sin(angle)*zone.r,z)
        if x then panel:drawRect(x-1,y-1,3,3,.85,red,green,blue) end
    end
    local x,y=project(zone.x,zone.y,z)
    if x then
        panel:drawRect(x-3,y-3,6,6,.85,red,green,blue)
        panel:drawTextCentre(getText(label),x,y-24,red,green,blue,1,UIFont.Small)
    end
end
function H.render(panel,C)
    local cx=getCore():getScreenWidth()/2
    local selected=C.ball(C.selected)
    local width=math.min(720,getCore():getScreenWidth()-32)
    if selected then
        panel:drawRect(cx-width/2,24,width,142,.82,.04,.07,.09)
        local m=selected.match
        local practice=m and m.mode=="practice"
        local title=practice and getText("UI_PS_PracticeScore",m.scoreA or 0) or m and ("A  "..tostring(m.scoreA).."  :  "..tostring(m.scoreB).."  B") or getText("UI_PS_Practice")
        panel:drawTextCentre(title,cx,30,1,.95,.78,1,UIFont.Large)
        local detail=getText("UI_PS_Controls")
        if m and m.phase=="finished" then detail=getText("UI_PS_MatchFinished",m.winner or "")
        elseif m and m.phase=="goal" then
            detail=practice and getText("UI_PS_PracticeGoal") or getText("UI_PS_Goal",m.lastScoringTeam or "")
        end
        panel:drawTextCentre(detail,cx,65,.7,.9,1,1,UIFont.Small)
        local power=C.charge and PSCore.chargePower(getTimestampMs()-C.charge.at) or 0
        local barWidth=math.min(300,width-24)
        local color=power>=1 and {a=1,r=1,g=.75,b=.2} or {a=1,r=.25,g=.8,b=.35}
        panel:drawRect(cx-barWidth/2-1,94,barWidth+2,20,1,.65,.65,.65)
        panel:drawProgressBar(cx-barWidth/2,95,barWidth,18,power,color)
        local possession=selected.possession
        local label=getText("UI_PS_FreeBall")
        if possession then
            local zoneLabel="UI_PS_ZonePossession"
            if possession.key=="shooter" then zoneLabel="UI_PS_ShooterPossession"
            elseif possession.key=="passer" then zoneLabel="UI_PS_PasserPossession" end
            label=possession.kind=="zone" and getText(zoneLabel) or getText("UI_PS_Possession",possession.key)
        end
        if C.charge then
            local kind=C.charge.lob and "UI_PS_Lob" or (power>=.8 and "UI_PS_LowShot" or "UI_PS_Ground")
            label=getText(kind).."  "..tostring(math.floor(power*100)).."%"
            if power>=1 then label=label.."  "..getText("UI_PS_ChargeMax") end
        end
        panel:drawTextCentre(label,cx,116,1,1,1,1,UIFont.Small)
        local rule=m and getText(practice and "UI_PS_PracticeRule" or "UI_PS_FirstToFive") or getText("UI_PS_ChargeRange")
        panel:drawTextCentre(rule,cx,140,.8,.85,.9,1,UIFont.Small)
    end
    if PSSetup.pending then
        local pending=PSSetup.pending
        local prefix=pending.mode=="practice" and "UI_PS_PracticePlace" or "UI_PS_Place"
        local key=pending.submitted and "UI_PS_SetupWaiting" or (prefix..tostring(#pending.points+1))
        panel:drawTextCentre(getText(key),cx,60,1,.95,.78,1,UIFont.Small)
    end
    if C.message and getTimestampMs()<(C.messageUntil or 0) then
        panel:drawTextCentre(C.message,cx,selected and 178 or 30,1,.85,.4,1,UIFont.Small)
    end
    -- Projection-dependent decorations never feed back into authoritative physics.
    if not PSProjection.available() then return end
    local p=getSpecificPlayer(0)
    if not p then return end
    for _,b in pairs(C.state.balls or {}) do
        if b.match and math.floor(p:getZ())==b.z then
            local zones=b.match.testZones or {}
            testZone(panel,zones.tackle,b.z,"UI_PS_TackleZone",1,.45,.2)
            testZone(panel,zones.keeper,b.z,"UI_PS_KeeperZone",.3,.8,1)
            testZone(panel,zones.shooter,b.z,"UI_PS_ShooterZone",.85,.4,1)
            testZone(panel,zones.passer,b.z,"UI_PS_PasserZone",.3,1,.45)
            for team,g in pairs(b.match.goals or {}) do
                local red=team=="A" and .25 or 1
                local blue=team=="A" and 1 or .25
                marker(panel,g.ax,g.ay,b.z,team,red,.65,blue)
                marker(panel,g.bx,g.by,b.z,team,red,.65,blue)
                line(panel,g,b.z,red,blue)
            end
        end
    end
    local pending=PSSetup.pending
    if pending then
        for i,pt in ipairs(pending.points) do marker(panel,pt.x,pt.y,pending.z,tostring(i),1,.8,.2) end
        local x,y=PSProjection.screenToWorld(0,getMouseX(),getMouseY(),pending.z)
        if x then marker(panel,x,y,pending.z,"+",1,.8,.2) end
        for i=1,#pending.points,2 do
            local a=pending.points[i]
            local b=pending.points[i+1] or (x and {x=x,y=y})
            if b then
                local valid=PSSetup.validLine(a,b)
                line(panel,{ax=a.x,ay=a.y,bx=b.x,by=b.y},pending.z,valid and .25 or 1,valid and 1 or .2)
                local sx,sy=project((a.x+b.x)/2,(a.y+b.y)/2,pending.z)
                if sx then
                    local length=math.sqrt((b.x-a.x)^2+(b.y-a.y)^2)
                    panel:drawTextCentre(string.format("%.1f / 2–10",length),sx,sy-20,1,1,1,1,UIFont.Small)
                end
            end
        end
    end
    for _,b in ipairs(C.positions()) do
        if b.z==math.floor(p:getZ()) and (b.h or 0)>.025 then
            local square=getCell():getGridSquare(math.floor(b.x),math.floor(b.y),b.z)
            if square and square:isCanSee(0) then
                local sx,sy=project(b.x,b.y,b.z)
                if sx then
                    -- Project a tile-space footprint so the shadow follows zoom,
                    -- but never lift it with the airborne display item.
                    local ex=project(b.x+.07,b.y-.07,b.z)
                    local radius=math.max(1,math.min(7,ex and math.abs(ex-sx) or 3))
                    local height=math.max(0,b.h or 0)
                    radius=radius/(1+height*.2)
                    local alpha=math.min(1,(height-.025)/.06)*math.max(.12,.32-height*.15)
                    for row=-1,1 do
                        local half=radius*(row==0 and 1 or .7)
                        local strip=math.max(1,radius/4)
                        panel:drawRect(sx-half,sy+(row-.5)*strip,half*2,strip,alpha,0,0,0)
                    end
                end
            end
        end
    end
    if selected and C.charge then
        local x,y=PSProjection.screenToWorld(0,getMouseX(),getMouseY(),selected.z)
        if x then
            local dx,dy=x-selected.x,y-selected.y
            local length=math.sqrt(dx*dx+dy*dy)
            if length>.01 then
                for i=1,10 do
                    local sx,sy=project(selected.x+dx/length*i*.12,selected.y+dy/length*i*.12,selected.z)
                    if sx then panel:drawRect(sx-1,sy-1,3,3,.85,.3,1,.4) end
                end
            end
        end
    end
end
