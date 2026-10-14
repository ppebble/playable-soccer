function require() end
local function event() local e={};e.Add=function(callback) e.callback=callback end;return e end
Events={OnGameStart=event(),OnServerCommand=event(),OnMouseDown=event(),OnPlayerUpdate=event(),OnFillWorldObjectContextMenu=event(),OnPostRender=event(),OnPlayerDeath=event(),OnMainMenuEnter=event()}
Events.OnRightMouseDown=event();Events.OnRightMouseUp=event();Events.OnKeyPressed=event()
ISPanel={derive=function()
    local panel={}
    function panel:new(x,y,w,h) return setmetatable({width=w,height=h},{__index=self}) end
    function panel:initialise() end
    function panel:instantiate() self.instantiated=true;self.consume=self.wantMouse end
    function panel:setWantMouseEvents(v) self.wantMouse=v end
    function panel:setWantKeyEvents(v) self.wantKey=v end
    function panel:setWidth(v) self.width=v end
    function panel:setHeight(v) self.height=v end
    function panel:addToUIManager() end
    function panel:removeFromUIManager() end
    return panel
end}
TEST={time=1000,buttons={},sent={},uis={},registered=0,renders=0}
function getTimestampMs() return TEST.time end
TEST.player={getX=function() return TEST.x or 1 end,getY=function() return TEST.y or 1 end,getZ=function() return 0 end,getUsername=function() return "test" end,isDead=function() return TEST.dead end,getVehicle=function() return nil end,isBannedAttacking=function() return TEST.banned or false end,setBannedAttacking=function(self,b) TEST.banned=b end}
TEST.player.isPlayerMoving=function() return TEST.moving end
TEST.player.isRunning=function() return TEST.running end
TEST.player.isSprinting=function() return TEST.sprinting end
TEST.player.isForceAim=function() return TEST.forceAim or false end
TEST.player.setForceAim=function(self,v) TEST.forceAim=v end
TEST.player.nullifyAiming=function() TEST.forceAim=false;TEST.aiming=false end
Mouse={UIBlockButtonDown=function(b) TEST.captured=TEST.captured or {};TEST.captured[b]=true end}
Keyboard={KEY_ESCAPE=1}
ISObjectClickHandler={}
PSProjection={available=function() return not TEST.noProjection end,screenToWorld=function(i,x,y,z) if TEST.noProjection then return end;return x,y end}
PSSetup={active=function() return TEST.setup end,cancel=function() TEST.setup=nil end,click=function() TEST.setupClicked=true end,menu=function() end}
PSSetup.begin=function(id) assert(PSClient.ball(id),'setup must see installed authoritative state');PSClient.leave();TEST.setup=id end
PSSetup.receive=function(command,args) TEST.setupReceived=command end
PSSetup.update=function() end
ISContextMenu={get=function()
    local menu={visible=true,options={}}
    function menu:addOption(label,target,callback)
        local option={label=label,target=target,callback=callback};self.options[#self.options+1]=option;return option
    end
    function menu:hideAndChildren() self.visible=false end
    function menu:isVisible() return self.visible end
    return menu
end}
PSHUD={render=function() TEST.hudRendered=true end}
PSMotion={play=function(p,lob,dx,dy) TEST.motions=(TEST.motions or 0)+1;TEST.motionLob=lob end}
PS_KickAction={}
function getSpecificPlayer() return TEST.player end
function getPlayer() return TEST.player end
function isClient() return true end
function sendClientCommand(p,module,command,args) TEST.sent[#TEST.sent+1]={command=command,args=args} end
function getText(k) return k end
function isGamePaused() return TEST.paused end
function isMouseButtonDown(b) return TEST.buttons[b] end
function getMouseX() return 8 end
function getMouseY() return 1 end
function screenToIsoX(i,x,y,z) return x end
function screenToIsoY(i,x,y,z) return y end
function getCore() return {isOption3DGroundItem=function() return not TEST.no3D end,isDoingTextEntry=function() return TEST.typing end,getScreenWidth=function() return TEST.width or 1280 end,getScreenHeight=function() return TEST.height or 720 end} end
ISTimedActionQueue={getTimedActionQueue=function() return {queue=TEST.queue or {}} end}
UIManager={getUI=function() return {size=function() return #TEST.uis end,get=function(self,i) return TEST.uis[i+1] end} end}
UIManager.setRightDownObject=function(v) TEST.rightObject=v end
TEST.square={isCanSee=function() return true end}
function getCell() return {getDrag=function() return TEST.drag end,getGridSquare=function() return TEST.square end} end
function instanceItem(t) return {type=t,setWorldXRotation=function() end,setWorldYRotation=function() end,setWorldZRotation=function() end} end
ColorInfo={new=function() return {} end}
IsoSprite={new=function() return {empty=true} end}
IsoWorldInventoryObject={new=function(item,square,x,y,z)
    TEST.lastItem=item
    return {setSprite=function(self,sprite) assert(sprite.empty);TEST.emptySprite=true end,setSquare=function() end,setOffset=function() error("Must not sync detached proxy") end,setOffX=function() end,setOffY=function() end,setOffZ=function() end,setAlphaAndTarget=function() end,render=function() assert(TEST.emptySprite);TEST.renders=TEST.renders+1 end,
        addToWorld=function() error("Must never register proxy") end}
end}
