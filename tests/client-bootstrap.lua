function require() end
local function event() local e={};e.Add=function(callback) e.callback=callback end;return e end
Events={OnGameStart=event(),OnServerCommand=event(),OnMouseDown=event(),OnPlayerUpdate=event(),OnFillWorldObjectContextMenu=event(),OnPostRender=event(),OnPlayerDeath=event(),OnMainMenuEnter=event()}
ISPanel={derive=function()
    local panel={}
    function panel:new() return setmetatable({},{__index=self}) end
    function panel:initialise() end
    function panel:setConsumeMouseEvents(v) self.consume=v end
    function panel:addToUIManager() end
    function panel:removeFromUIManager() end
    return panel
end}
TEST={time=1000,buttons={},sent={},uis={},registered=0,renders=0}
function getTimestampMs() return TEST.time end
TEST.player={getX=function() return 1 end,getY=function() return 1 end,getZ=function() return 0 end,getUsername=function() return "test" end,isDead=function() return TEST.dead end,getVehicle=function() return nil end,isBannedAttacking=function() return TEST.banned or false end,setBannedAttacking=function(self,b) TEST.banned=b end}
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
function getCore() return {isOption3DGroundItem=function() return not TEST.no3D end,isDoingTextEntry=function() return TEST.typing end,getScreenWidth=function() return 1280 end,getScreenHeight=function() return 720 end} end
ISTimedActionQueue={getTimedActionQueue=function() return {queue=TEST.queue or {}} end}
UIManager={getUI=function() return {size=function() return #TEST.uis end,get=function(self,i) return TEST.uis[i+1] end} end}
TEST.square={isCanSee=function() return true end}
function getCell() return {getDrag=function() return TEST.drag end,getGridSquare=function() return TEST.square end} end
function instanceItem(t) return {type=t} end
ColorInfo={new=function() return {} end}
IsoSprite={new=function() return {empty=true} end}
IsoWorldInventoryObject={new=function(item,square,x,y,z)
    TEST.lastItem=item
    return {setSprite=function(self,sprite) assert(sprite.empty);TEST.emptySprite=true end,setSquare=function() end,setOffset=function() error("Must not sync detached proxy") end,setOffX=function() end,setOffY=function() end,setOffZ=function() end,setAlphaAndTarget=function() end,render=function() assert(TEST.emptySprite);TEST.renders=TEST.renders+1 end,
        addToWorld=function() error("Must never register proxy") end}
end}
