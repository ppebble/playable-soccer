require "PS_Projection"
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
function H.render(panel,C)
    local cx=getCore():getScreenWidth()/2
    local selected=C.ball(C.selected)
    local width=math.min(720,getCore():getScreenWidth()-32)
    if selected then
        panel:drawRect(cx-width/2,24,width,98,.82,.04,.07,.09)
        local m=selected.match
        local title=m and ("A  "..tostring(m.scoreA).."  :  "..tostring(m.scoreB).."  B") or getText("UI_PS_Practice")
        panel:drawTextCentre(title,cx,30,1,.95,.78,1,UIFont.Large)
        local detail=m and m.phase=="goal" and getText("UI_PS_Goal",m.lastScoringTeam or "") or getText("UI_PS_Controls")
        panel:drawTextCentre(detail,cx,65,.7,.9,1,1,UIFont.Small)
        if C.charge then
            local power=math.min(1,math.max(0,(getTimestampMs()-C.charge.at)/900))
            panel:drawRect(cx-121,94,242,16,.9,0,0,0)
            panel:drawRect(cx-120,95,240*power,14,1,.25,.8,.35)
            panel:drawTextCentre(getText(C.charge.lob and "UI_PS_Lob" or "UI_PS_Ground"),cx,124,1,1,1,1,UIFont.Small)
        end
    end
    if C.message and getTimestampMs()<(C.messageUntil or 0) then
        panel:drawTextCentre(C.message,cx,selected and 148 or 30,1,.85,.4,1,UIFont.Small)
    end
    -- Projection-dependent decorations never feed back into authoritative physics.
    if not PSProjection.available() then return end
    local p=getSpecificPlayer(0)
    if not p then return end
    for _,b in pairs(C.state.balls or {}) do
        if b.match and math.floor(p:getZ())==b.z then
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
    end
    for _,b in ipairs(C.positions()) do
        if b.z==math.floor(p:getZ()) then
            local square=getCell():getGridSquare(math.floor(b.x),math.floor(b.y),b.z)
            if square and square:isCanSee(0) then
                local sx,sy=project(b.x,b.y,b.z)
                if sx then panel:drawRect(sx-5,sy-2,10,4,.45,0,0,0) end
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
