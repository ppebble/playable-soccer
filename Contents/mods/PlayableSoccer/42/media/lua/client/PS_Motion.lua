require 'TimedActions/ISBaseTimedAction'
require 'TimedActions/ISTimedActionQueue'

-- Cosmetic foot gesture: an owned, event-free node references the native
-- downward stamp clip. This is NOT a custom forward soccer kick animation.
-- Native timed-action cleanup owns PerformingAction and remote replication.
PS_KickAction = ISBaseTimedAction:derive('PS_KickAction')
function PS_KickAction:isValid()
    local p = self.character
    return p and not p:isDead() and not p:getVehicle() and (self.strong or not p:isMoving())
end
function PS_KickAction:start()
    local ok = pcall(function()
        self.action:setUseProgressBar(false)
        self.action:setBlockMovementEtc(false)
        self:setActionAnim(self.animName)
    end)
    if not ok then self:forceStop() end
end
function PS_KickAction:update()
    if not self:isValid() then self:forceStop() end
end
function PS_KickAction:animEvent(event, parameter) end
function PS_KickAction:adjustMaxTime(time) return time end
function PS_KickAction:new(player, power)
    local o = ISBaseTimedAction.new(self, player)
    -- 5920/4800 seconds at 1.5 speed plus blend-out fits in 32 ticks.
    o.maxTime = 32
    local strong=type(power)=='number' and power==power and power>=.9 and power<=1
    o.strong=strong
    o.animName=strong and 'PS_StrongKickGesture' or 'PS_KickGesture'
    o.stopOnWalk, o.stopOnRun, o.stopOnAim = not strong, not strong, true
    return o
end

PSMotion = {}
function PSMotion.play(player, lob, dx, dy, power)
    -- Only the local accepted kicker queues an action. B42 replicates native
    -- action animation; observers must not queue actions for other players.
    local ok, played, reason = pcall(function()
        if not player or not player:isLocalPlayer() then return false, 'player' end
        local action = PS_KickAction:new(player, power)
        if not action:isValid() then return false, 'state' end
        local queue = ISTimedActionQueue.getTimedActionQueue(player)
        if not queue or not queue.queue or #queue.queue > 0 then return false, 'busy' end
        ISTimedActionQueue.add(action)
        return true
    end)
    if not ok then return false, 'unavailable' end
    return played, reason
end
-- A local animation/state request only. Soccer authority and downed duration
-- stay on the server. Never call Hit, falling damage, or drop equipment here.

local M=PSMotion
local standing={idle=true,movement=true,run=true,sprint=true,aim=true,
    ["aim-sneak"]=true,["aim-strafe"]=true,slowidleblend=true,
    turningIdle180=true,turningMovement180=true,turningAim180=true}
function M.isDown(p)
    if not p then return false end
    local state=p:getCurrentActionContextStateName()
    return p:isKnockedDown() or p:isOnFloor() or state=="knockeddown"
        or state=="getup" or state=="falldown" or state=="falling" or state=="onground"
end
function M.fall(p)
    -- Avoid taking ownership of a climb, furniture, vehicle, action or an
    -- existing real injury. Remote players retain their native network owner.
    if not p or not p:isLocalPlayer() or p:isDead() or p:getVehicle()
        or M.isDown(p) or p:getIgnoreMovement() or p:isSitOnGround()
        or p:isSittingOnFurniture() or p:hasHitReaction()
        or p:getVariableBoolean("bGetUpFromFall")
        or not standing[p:getCurrentActionContextStateName()] then return false end
    p:setRunning(false)
    p:setSprinting(false)
    p:setMoving(false)
    p:setHitFromBehind(false)
    p:setFallOnFront(false)
    -- The registered bKnockedDown callback enters the installed knockeddown
    -- graph; fallSit selects the backward reaction when fromBehind is false.
    -- Native state enter/exit own movement locking and the getup transition.
    p:setKnockedDown(true)
    return true
end

-- Shoulder gesture only: no attack/shove events and no root displacement.
M.tackleMilliseconds=500
PS_TackleAction=ISBaseTimedAction:derive('PS_TackleAction')
function PS_TackleAction:isValid()
    local p=self.character
    return p and p:isLocalPlayer() and not p:isDead() and not p:getVehicle()
        and not M.isDown(p) and not p:hasHitReaction()
        and PSClient and self.ballId~=nil and PSClient.selected==self.ballId
        and (not PSClient.blocked or not PSClient.blocked())
end
function PS_TackleAction:start()
    if not self:isValid() then self:forceStop();return end
    local ok=pcall(function()
        self.action:setUseProgressBar(false)
        self.action:setBlockMovementEtc(false)
        -- A single facing request; ordinary locomotion keeps control thereafter.
        self.character:faceLocation(self.character:getX()+self.dx,self.character:getY()+self.dy)
        self:setActionAnim('PS_ShoulderTackle')
    end)
    if not ok then self:forceStop() end
end
function PS_TackleAction:update()
    if not self:isValid() then self:forceStop() end
end
function PS_TackleAction:animEvent(event,parameter) end
function PS_TackleAction:adjustMaxTime(time) return time end
function PS_TackleAction:new(p,dx,dy)
    local o=ISBaseTimedAction.new(self,p)
    o.maxTime=15
    o.stopOnWalk,o.stopOnRun,o.stopOnAim=false,false,false
    o.ballId=PSClient and PSClient.selected
    o.dx,o.dy=dx,dy
    return o
end
function M.tackle(p,dx,dy)
    local ok,played,reason=pcall(function()
        if not p or not p:isLocalPlayer() then return false,'player' end
        if type(dx)~='number' or type(dy)~='number' or dx~=dx or dy~=dy
            or math.abs(dx)>10000 or math.abs(dy)>10000 then return false,'direction' end
        local length=math.sqrt(dx*dx+dy*dy)
        if length<.00001 then return false,'direction' end
        local action=PS_TackleAction:new(p,dx/length,dy/length)
        if not action:isValid() then return false,'state' end
        local queue=ISTimedActionQueue.getTimedActionQueue(p)
        if not queue or not queue.queue or #queue.queue>0 then return false,'busy' end
        ISTimedActionQueue.add(action)
        return true
    end)
    if not ok then return false,'unavailable' end
    return played,reason
end
return PSMotion
