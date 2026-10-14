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
