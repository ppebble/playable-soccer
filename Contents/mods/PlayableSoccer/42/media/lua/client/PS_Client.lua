require "PS_Core"
require "PS_Render"
require "PS_Projection"
require "PS_HUD"
require "PS_Setup"
require "PS_Motion"
require "ISUI/ISPanel"
require "TimedActions/ISTimedActionQueue"
PSClient={state={balls={}},revision=-1,samples={},lastSync=0}
local C=PSClient
local function now() return getTimestampMs() end
local function player() return getSpecificPlayer(0) end
local function owner(p)
    local name=p:getUsername()
    return name and name~="" and name or "local:"..tostring(p:getPlayerNum())
end
function C.notice(key)
    C.message=getText(key);C.messageUntil=now()+5000
end
function C.send(command,args)
    local p=player();if not p then return end
    if isClient() then sendClientCommand(p,"PlayableSoccer",command,args or {})
    elseif PSServer then PSServer.command(p,command,args or {})
    else C.notice("UI_PS_NoServer") end
end
function C.releaseGuard()
    local g=C.guard;C.guard=nil
    if g then
        g.player:setBannedAttacking(g.previous)
        g.player:nullifyAiming()
        g.player:setForceAim(g.forceAim)
    end
end
function C.leave()
    C.selected=nil;C.charge=nil;C.pendingItem=nil;C.releaseGuard()
    PSSetup.cancel()
end
function C.start(p,item)
    if p~=player() or not item or item:getFullType()~="PlayableSoccer.SportsSoccerBall" then return end
    if not PSRender.available() then C.notice("UI_PS_RenderError");return end
    C.pendingItem=item:getID();C.pendingAt=now();C.send("start",{itemId=item:getID()})
end
function C.stop(id)
    id=id or C.selected
    if id then C.send("stop",{id=id}) end
    C.leave()
end
function C.isItemActive(p,item)
    if not p or not item then return false end
    if C.pendingItem==item:getID() then return true end
    for _,b in pairs(C.state.balls) do
        if b.itemId==item:getID() then return true end
    end
    return false
end
function C.ball(id)
    for _,b in pairs(C.state.balls) do if b.id==id then return b end end
end
function C.receive(command,args)
    args=args or {}
    if command=="notice" then C.pendingItem=nil;C.notice(args.key);return end
    if command~="state" or not PSCore.finite(args.revision) or args.revision<C.revision then return end
    local samples={};local t=now()
    for _,b in pairs(args.balls or {}) do
        if b.id and PSCore.finite(b.x) and PSCore.finite(b.y) and PSCore.finite(b.z) and PSCore.finite(b.h) then
            local prior=C.samples[b.id]
            samples[b.id]={a=prior and prior.b or b,b=b,at=t,duration=prior and math.min(250,math.max(1,t-prior.at)) or 1}
            if prior and b.kickSerial and b.kickSerial~=(prior.b.kickSerial or 0) and player() and b.kicker==owner(player()) then
                PSMotion.play(player(),b.lob==true,b.kickDx,b.kickDy)
            end
            if C.pendingItem==b.itemId and player() and b.owner==owner(player()) then
                C.selected=b.id;C.pendingItem=nil
            end
        end
    end
    C.state=args;C.samples=samples;C.revision=args.revision;C.receivedAt=t
    if C.selected and not C.ball(C.selected) then C.leave() end
end
function C.positions()
    local out={};local t=now()
    for id,s in pairs(C.samples) do
        local a,b=s.a,s.b
        local f=math.min(1,math.max(0,(t-s.at)/s.duration))
        if a.z~=b.z or (a.x-b.x)^2+(a.y-b.y)^2>16 then f=1 end
        out[#out+1]={id=id,x=a.x+(b.x-a.x)*f,y=a.y+(b.y-a.y)*f,z=b.z,h=a.h+(b.h-a.h)*f}
    end
    return out
end
function C.blocked()
    local p=player()
    if not p or p:isDead() or p:getVehicle() or (isGamePaused and isGamePaused()) or getCore():isDoingTextEntry() then return true end
    local q=ISTimedActionQueue.getTimedActionQueue(p)
    if q then
        for _,action in ipairs(q.queue) do
            -- Our event-free foot gesture must not interrupt dribbling input.
            -- Exact class identity leaves every unrelated timed action gated.
            if not PS_KickAction or getmetatable(action)~=PS_KickAction then return true end
        end
    end
    if getCell():getDrag(0) then return true end
    local uis=UIManager.getUI()
    for i=0,uis:size()-1 do
        local ui=uis:get(i)
        if ui~= (C.overlay and C.overlay.javaObject) and ui:isVisible() and ui:isConsumeMouseEvents() and ui:isPointOver(getMouseX(),getMouseY()) then return true end
    end
    return false
end
function C.ready()
    local p=player();local b=C.ball(C.selected)
    return p and b and C.receivedAt and now()-C.receivedAt<3000 and math.floor(p:getZ())==b.z
        and PSRender.available() and PSProjection.available() and not PSSetup.active() and b.h<=.35 and (p:getX()-b.x)^2+(p:getY()-b.y)^2<=PSCore.kickRange^2 and not C.blocked()
end
function C.inputActive()
    return C.selected and C.ball(C.selected) and C.receivedAt and now()-C.receivedAt<3000
        and not PSSetup.active() and not C.blocked()
end
function C.capture(button)
    -- Native capture affects key bindings, not the raw button used by our gauge.
    -- The engine clears this press-scoped capture when the button is released.
    Mouse.UIBlockButtonDown(button)
end
function C.guardInput(p)
    if not C.guard then C.guard={player=p,previous=p:isBannedAttacking(),forceAim=p:isForceAim()} end
    p:setBannedAttacking(true);p:nullifyAiming()
    if isMouseButtonDown(0) then C.capture(0) end
    if isMouseButtonDown(1) then C.capture(1) end
end
function C.beginCharge(button)
    if not C.inputActive() then return end
    C.guardInput(player());C.capture(button)
    if button==1 then C.rightCaptured=true end
    if C.ready() and not C.charge and not isMouseButtonDown(1-button) then
        C.charge={at=now(),id=C.selected,button=button,lob=button==1}
    end
end
function C.mouseDown()
    if PSSetup.active() then PSSetup.click(0);return end
    C.beginCharge(0)
end
function C.rightDown()
    if PSSetup.active() and not C.blocked() then
        C.rightCaptured=true;C.capture(1);PSSetup.cancel();return
    end
    C.beginCharge(1)
end
function C.rightUp()
    if C.rightCaptured then
        -- OnRightMouseUp precedes the native object's right-up callback.
        -- Cancel only the click we captured, including after Escape/UI/death.
        if ISObjectClickHandler then ISObjectClickHandler.rdownObject=nil end
        UIManager.setRightDownObject(nil)
        C.rightCaptured=nil
    end
end
function C.keyPressed(key)
    if key~=Keyboard.KEY_ESCAPE then return end
    if PSSetup.active() then PSSetup.cancel()
    elseif C.charge then C.charge=nil
    elseif C.selected then C.leave() end
end
function C.update(p)
    if p~=player() then return end
    if C.rightCaptured and not isMouseButtonDown(1) then C.rightUp() end
    if C.pendingItem and now()-(C.pendingAt or 0)>5000 then C.pendingItem=nil;C.notice("UI_PS_StartFailed") end
    if C.inputActive() then C.guardInput(p)
    else C.charge=nil;C.releaseGuard() end
    if not C.ready() then C.charge=nil end
    if C.charge then
        if isMouseButtonDown(1-C.charge.button) then C.charge=nil
        elseif not isMouseButtonDown(C.charge.button) then
            local charge=C.charge;C.charge=nil
            local b=C.ball(charge.id)
            if b then
                local x,y=PSProjection.screenToWorld(0,getMouseX(),getMouseY(),b.z)
                if PSCore.finite(x) and PSCore.finite(y) then
                    C.send("kick",{id=b.id,dx=x-b.x,dy=y-b.y,lob=charge.lob,power=math.min(1,math.max(0,(now()-charge.at)/900))})
                end
            end
        end
    end
    if now()-C.lastSync>2000 then C.lastSync=now();C.send("sync",{}) end
end
function C.context(index,context,objects,test)
    if index~=0 or test then return end
    local p=player();if not p then return end
    PSSetup.menu(index,context,C)
    local nearest,distance=nil,64
    for _,b in pairs(C.state.balls) do
        local d=(p:getX()-b.x)^2+(p:getY()-b.y)^2
        if math.floor(p:getZ())==b.z and d<distance then nearest=b;distance=d end
    end
    if nearest then context:addOption(getText("UI_PS_JoinBall"),nearest,function(b) C.leave();C.selected=b.id end) end
    if C.selected then
        context:addOption(getText("UI_PS_LeaveBall"),nil,C.leave)
    end
    for _,b in pairs(C.state.balls) do
        if b.owner==owner(p) then context:addOption(getText("UI_PS_StopBall"),b.id,C.stop) end
    end
end
local Overlay=ISPanel:derive("PSOverlay")
function Overlay:prerender() end -- HUD only; never draw ISPanel's fullscreen background.
function Overlay:render()
    PSHUD.render(self,C)
end
function C.reset()
    C.leave();C.rightUp();C.state={balls={}};C.samples={};C.revision=-1;C.receivedAt=nil;PSRender.clear()
    if C.overlay then C.overlay:removeFromUIManager();C.overlay=nil end
end
Events.OnGameStart.Add(function()
    C.reset()
    C.overlay=Overlay:new(0,0,0,0)
    C.overlay.background=false
    C.overlay:initialise();C.overlay:instantiate();C.overlay:setWantMouseEvents(false);C.overlay:setConsumeMouseEvents(false);C.overlay:addToUIManager()
    C.send("sync",{})
end)
Events.OnServerCommand.Add(function(module,command,args) if module=="PlayableSoccer" then C.receive(command,args) end end)
Events.OnMouseDown.Add(C.mouseDown)
Events.OnRightMouseDown.Add(C.rightDown)
Events.OnRightMouseUp.Add(C.rightUp)
Events.OnKeyPressed.Add(C.keyPressed)
Events.OnPlayerUpdate.Add(C.update)
Events.OnFillWorldObjectContextMenu.Add(C.context)
Events.OnPostRender.Add(function()
    if C.receivedAt and now()-C.receivedAt<5000 then
        local ok,result=pcall(PSRender.draw,C.positions())
        if (not ok or result==false) and not C.renderError then C.renderError=true;print("[PlayableSoccer] render: "..tostring(result));C.notice("UI_PS_RenderError")
        elseif ok and result==true then C.renderError=nil end
    else PSRender.clear() end
end)
Events.OnPlayerDeath.Add(function(p) if p==player() then C.leave() end end)
Events.OnMainMenuEnter.Add(C.reset)
