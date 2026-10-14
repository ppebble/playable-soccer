require 'TimedActions/ISBaseTimedAction'
require 'TimedActions/ISTimedActionQueue'

-- Cosmetic foot gesture: an owned, event-free node references the native
-- downward stamp clip. This is NOT a custom forward soccer kick animation.
-- Native timed-action cleanup owns PerformingAction and remote replication.
PS_KickAction = ISBaseTimedAction:derive('PS_KickAction')
function PS_KickAction:isValid()
    local p = self.character
    return p and not p:isDead() and not p:getVehicle() and not p:isMoving()
end
function PS_KickAction:start()
    local ok = pcall(function()
        self.action:setUseProgressBar(false)
        self.action:setBlockMovementEtc(false)
        self:setActionAnim('PS_KickGesture')
    end)
    if not ok then self:forceStop() end
end
function PS_KickAction:update()
    if not self:isValid() then self:forceStop() end
end
function PS_KickAction:animEvent(event, parameter) end
function PS_KickAction:adjustMaxTime(time) return time end
function PS_KickAction:new(player)
    local o = ISBaseTimedAction.new(self, player)
    -- 5920/4800 seconds at 1.5 speed plus blend-out fits in 32 ticks.
    o.maxTime = 32
    o.stopOnWalk, o.stopOnRun, o.stopOnAim = true, true, true
    return o
end

PSMotion = {}
function PSMotion.play(player, lob, dx, dy)
    -- Only the local accepted kicker queues an action. B42 replicates native
    -- action animation; observers must not queue actions for other players.
    local ok, played, reason = pcall(function()
        if not player or not player:isLocalPlayer() then return false, 'player' end
        local action = PS_KickAction:new(player)
        if not action:isValid() then return false, 'state' end
        local queue = ISTimedActionQueue.getTimedActionQueue(player)
        if not queue or not queue.queue or #queue.queue > 0 then return false, 'busy' end
        ISTimedActionQueue.add(action)
        return true
    end)
    if not ok then return false, 'unavailable' end
    return played, reason
end
return PSMotion
