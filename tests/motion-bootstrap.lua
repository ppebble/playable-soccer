function require() end
TEST={queue={queue={}},localPlayer=true}
TEST.player={isLocalPlayer=function() return TEST.localPlayer end,isDead=function() return TEST.dead end,getVehicle=function() return TEST.vehicle end,isMoving=function() return TEST.moving end}
ISBaseTimedAction={}
function ISBaseTimedAction:derive() local o={};setmetatable(o,{__index=self});return o end
function ISBaseTimedAction:new(player) return setmetatable({character=player},{__index=self}) end
function ISBaseTimedAction:forceStop() TEST.stopped=true end
function ISBaseTimedAction:stop() TEST.queue.queue={} end
function ISBaseTimedAction:perform() TEST.queue.queue={} end
function ISBaseTimedAction:setActionAnim(name) if TEST.error then error('animation failure') end;TEST.anim=name end
ISTimedActionQueue={getTimedActionQueue=function() return TEST.queue end,add=function(action) TEST.queue.queue[1]=action end}
TEST.native={setUseProgressBar=function(self,v) TEST.bar=v end,setBlockMovementEtc=function(self,v) TEST.block=v end}

MOTION={state="movement",localPlayer=true}
local function getter(key,default) return function() local v=MOTION[key];if v==nil then return default end;return v end end
local function setter(key) return function(self,v) MOTION[key]=v end end
motionPlayer={isLocalPlayer=getter("localPlayer",true),isDead=getter("dead",false),getVehicle=getter("vehicle",nil),
    isKnockedDown=getter("knocked",false),isOnFloor=getter("floor",false),getCurrentActionContextStateName=getter("state","idle"),
    getIgnoreMovement=getter("locked",false),isSitOnGround=getter("sitting",false),isSittingOnFurniture=getter("furniture",false),
    hasHitReaction=getter("hit",false),getVariableBoolean=getter("fallRecovery",false),
    setRunning=setter("running"),setSprinting=setter("sprinting"),setMoving=setter("moving"),
    setHitFromBehind=setter("behind"),setFallOnFront=setter("front"),setKnockedDown=setter("knocked")}
motionPlayer.getX=function() return 10 end
motionPlayer.getY=function() return 20 end
motionPlayer.faceLocation=function(self,x,y) MOTION.facing={x=x,y=y} end
