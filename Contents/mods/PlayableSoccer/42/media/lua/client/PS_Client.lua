require "PS_Core"
require "PS_Render"
require "PS_Projection"
require "PS_HUD"
require "PS_Setup"
require "PS_Motion"
require "ISUI/ISPanel"
require "ISUI/ISContextMenu"
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
    C.closeMenu();PSSetup.cancel()
    C.selected=nil;C.charge=nil;C.pendingItem=nil;C.pendingMode=nil;C.releaseGuard()
    C.moveSample=nil;C.lastTouch=nil;C.lastDribbleRequest=nil
end
function C.start(p,item,mode)
    if p~=player() or not item or item:getFullType()~="PlayableSoccer.SportsSoccerBall" then return end
    if not PSRender.available() then C.notice("UI_PS_RenderError");return end
    C.leave()
    C.pendingMode=mode=='match' and 'match' or 'practice'
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
    if command=="notice" then
        C.pendingItem=nil;C.pendingMode=nil;C.notice(args.key)
        PSSetup.receive(command,args);return
    end
    if command~="state" or not PSCore.finite(args.revision) or args.revision<C.revision then return end
    local samples={};local t=now();local setupId
    for _,b in pairs(args.balls or {}) do
        if b.id and PSCore.finite(b.x) and PSCore.finite(b.y) and PSCore.finite(b.z) and PSCore.finite(b.h) then
            local prior=C.samples[b.id]
            local touched=prior and b.kickSerial and b.kickSerial~=(prior.b.kickSerial or 0)
            -- Accepted touches immediately show the authoritative contact point.
            -- The next ordinary snapshot starts there, never behind the ack.
            samples[b.id]={a=not touched and prior and prior.b or b,b=b,at=t,duration=prior and math.min(250,math.max(1,t-prior.at)) or 1}
            if prior and b.dribble and b.kickSerial and b.kickSerial~=(prior.b.kickSerial or 0)
                and player() and b.kicker==owner(player()) then C.lastTouch=t end
            if prior and not b.dribble and b.kickSerial and b.kickSerial~=(prior.b.kickSerial or 0) and player() and b.kicker==owner(player()) then
                PSMotion.play(player(),b.lob==true,b.kickDx,b.kickDy)
            end
            if C.pendingItem==b.itemId and player() and b.owner==owner(player()) then
                if C.pendingMode=='match' then setupId=b.id else C.selected=b.id end
                C.pendingItem=nil;C.pendingMode=nil
            end
        end
    end
    C.state=args;C.samples=samples;C.revision=args.revision;C.receivedAt=t
    if C.selected and not C.ball(C.selected) then C.leave() end
    PSSetup.receive(command,args)
    if setupId then PSSetup.begin(setupId) end
end
function C.positions()
    local out={};local t=now()
    for id,s in pairs(C.samples) do
        local a,b=s.a,s.b
        local f=math.min(1,math.max(0,(t-s.at)/s.duration))
        local phaseA=a.match and a.match.phase
        local phaseB=b.match and b.match.phase
        if phaseB=='goal' or phaseA~=phaseB or a.z~=b.z or (a.x-b.x)^2+(a.y-b.y)^2>16 then f=1 end
        out[#out+1]={id=id,x=a.x+(b.x-a.x)*f,y=a.y+(b.y-a.y)*f,z=b.z,h=a.h+(b.h-a.h)*f}
    end
    return out
end
function C.blocked()
    if C.menu then return true end
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
        and (not b.match or b.match.phase=='play')
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
    if C.menu then C.closeMenu()
    elseif PSSetup.active() then PSSetup.cancel()
    elseif C.charge then C.charge=nil
    elseif C.selected then C.openMenu() end
end
function C.closeMenu()
    local menu=C.menu;C.menu=nil
    if menu then menu:hideAndChildren() end
end
function C.join(id,team)
    local b=C.ball(id);local p=player()
    if not b or not p or math.floor(p:getZ())~=b.z or (p:getX()-b.x)^2+(p:getY()-b.y)^2>64 then return end
    C.leave();C.selected=id
    if b.match and (team=='A' or team=='B') then C.send('team',{id=id,team=team}) end
end
function C.joinMenu(context)
    local p=player();if not p then return end
    for _,b in ipairs(C.state.balls) do
        if math.floor(p:getZ())==b.z and (p:getX()-b.x)^2+(p:getY()-b.y)^2<=64 then
            local id=b.id
            if b.match then
                for _,team in ipairs({'A','B'}) do
                    local choice=team
                    local label=getText('UI_PS_JoinMatch')..' #'..tostring(id)..' ('..tostring(b.owner)..') · '..getText('UI_PS_Team'..team)
                    context:addOption(label,nil,function() C.join(id,choice) end)
                end
            else
                context:addOption(getText('UI_PS_JoinBall')..' #'..tostring(id),nil,function() C.join(id) end)
            end
        end
    end
end
function C.openMenu()
    local p=player();local b=C.ball(C.selected)
    if not p or not b then return end
    C.closeMenu();C.charge=nil;C.releaseGuard()
    local menu=ISContextMenu.get(0,math.floor(getCore():getScreenWidth()/2),math.floor(getCore():getScreenHeight()/3))
    C.menu=menu
    menu:addOption(getText('UI_PS_SoccerMenu'),nil,nil).notAvailable=true
    menu:addOption(getText('UI_PS_Resume'),nil,C.closeMenu)
    if b.match then
        for _,team in ipairs({'A','B'}) do
            local choice=team
            menu:addOption(getText('UI_PS_Team'..team),nil,function() C.closeMenu();C.send('team',{id=b.id,team=choice}) end)
        end
    end
    if b.owner==owner(p) then
        menu:addOption(getText('UI_PS_ResetBall'),nil,function() C.closeMenu();C.send('reset',{id=b.id}) end)
        menu:addOption(getText('UI_PS_ConfigureGoals'),nil,function() C.closeMenu();PSSetup.begin(b.id) end)
        menu:addOption(getText('UI_PS_StopBall'),b.id,C.stop)
    end
    menu:addOption(getText('UI_PS_LeaveBall'),nil,C.leave)
end
function C.update(p)
    if p~=player() then return end
    if C.menu and not C.menu:isVisible() then C.menu=nil end
    PSSetup.update()
    local t=now();local previous=C.moveSample
    C.moveSample={x=p:getX(),y=p:getY(),z=p:getZ(),at=t}
    if C.rightCaptured and not isMouseButtonDown(1) then C.rightUp() end
    if C.pendingItem and now()-(C.pendingAt or 0)>5000 then C.pendingItem=nil;C.pendingMode=nil;C.notice("UI_PS_StartFailed") end
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
                    C.lastTouch=t
                    C.send("kick",{id=b.id,dx=x-b.x,dy=y-b.y,lob=charge.lob,power=PSCore.chargePower(now()-charge.at)})
                end
            end
        end
    end
    if previous and previous.z==p:getZ() and t-previous.at<=250 and C.inputActive()
        and not C.charge and not isMouseButtonDown(0) and not isMouseButtonDown(1)
        and (p:isRunning() or p:isSprinting())
        and (not C.lastTouch or t-C.lastTouch>=400)
        and (not C.lastDribbleRequest or t-C.lastDribbleRequest>=100) then
        local b=C.ball(C.selected)
        local dx,dy=p:getX()-previous.x,p:getY()-previous.y
        local distance=dx*dx+dy*dy
        -- This is intent acquisition, not a local kick. Include the displayed
        -- interpolation and a small approach margin; the server still requires
        -- actual .8-tile contact or a validated short swept contact.
        local near=(p:getX()-b.x)^2+(p:getY()-b.y)^2<=1.6^2
        if not near then
            for _,shown in ipairs(C.positions()) do
                if shown.id==b.id and (p:getX()-shown.x)^2+(p:getY()-shown.y)^2<=1.6^2 then near=true end
            end
        end
        if b.z==math.floor(p:getZ()) and (not b.match or b.match.phase=='play')
            and b.h==0 and b.vz==0 and PSRender.available() and PSProjection.available()
            and near and distance>0.000001 and distance<1.5^2 then
            local length=math.sqrt(distance);C.lastDribbleRequest=t
            C.send("dribble",{id=b.id,dx=dx/length,dy=dy/length})
        end
    end
    if now()-C.lastSync>2000 then C.lastSync=now();C.send("sync",{}) end
end
function C.context(index,context,objects,test)
    if index~=0 or test then return end
    local p=player();if not p then return end
    PSSetup.menu(index,context,C)
    C.joinMenu(context)
    if C.selected then
        context:addOption(getText("UI_PS_LeaveBall"),nil,C.leave)
    end
    for _,b in pairs(C.state.balls) do
        if b.owner==owner(p) then context:addOption(getText("UI_PS_StopBall"),b.id,C.stop) end
    end
end
local Overlay=ISPanel:derive("PSOverlay")
-- Native right-click dispatch treats a Lua nil return as consumed even when
-- consumeMouseEvents=false. Every HUD mouse callback must explicitly pass.
function Overlay:onMouseDown() return false end
function Overlay:onMouseUp() return false end
function Overlay:onRightMouseDown() return false end
function Overlay:onRightMouseUp() return false end
function Overlay:onMouseMove() return false end
function Overlay:onMouseWheel() return false end
local function ownsEscape()
    local p=player()
    return p and not p:isDead() and not (isGamePaused and isGamePaused())
        and not getCore():isDoingTextEntry() and (C.menu~=nil or PSSetup.active() or C.selected~=nil or C.charge~=nil)
end
function Overlay:onKeyPress(key)
    if key==Keyboard.KEY_ESCAPE then self.escapeConsumed=ownsEscape() and true or false end
end
function Overlay:onKeyRelease(key)
    if key~=Keyboard.KEY_ESCAPE then return end
    -- Native UIElement queries isKeyConsumed AFTER this callback. Retain the
    -- press latch even when leaving soccer clears selected/charge/setup.
    self.escapeConsumed=self.escapeConsumed or (ownsEscape() and true or false)
    if self.escapeConsumed then C.keyPressed(key) end
end
function Overlay:isKeyConsumed(key)
    return key==Keyboard.KEY_ESCAPE and self.escapeConsumed==true
end
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
    -- Inventory world-drop and other UI hit tests ignore consumeMouseEvents.
    -- A top-level zero-area panel can draw HUD coordinates without owning any
    -- screen area; keyboard delivery does not require a mouse hit rectangle.
    C.overlay=Overlay:new(0,0,0,0)
    C.overlay.background=false
    C.overlay:initialise()
    C.overlay:setWantMouseEvents(false)
    C.overlay:setWantKeyEvents(true)
    C.overlay:instantiate()
    C.overlay:addToUIManager()
    C.send("sync",{})
end)
Events.OnServerCommand.Add(function(module,command,args) if module=="PlayableSoccer" then C.receive(command,args) end end)
Events.OnMouseDown.Add(C.mouseDown)
Events.OnRightMouseDown.Add(C.rightDown)
Events.OnRightMouseUp.Add(C.rightUp)
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
