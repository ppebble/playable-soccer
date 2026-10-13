require "TimedActions/ISBaseTimedAction"

PS_ConvertBall = ISBaseTimedAction:derive("PS_ConvertBall")

function PS_ConvertBall.targetType(item)
    if not item then return nil end
    local kind = item:getFullType()
    if kind == "Base.SoccerBall" then return "PlayableSoccer.SportsSoccerBall" end
    if kind == "PlayableSoccer.SportsSoccerBall" then return "Base.SoccerBall" end
end

function PS_ConvertBall.active(player, item)
    if PSServer and PSServer.isItemActive then return PSServer.isItemActive(player, item) end
    if PSClient and PSClient.isItemActive then return PSClient.isItemActive(player, item) end
    return false
end

function PS_ConvertBall:isValid()
    return not self.done and self.character and not self.character:isDead()
        and not self.character:getVehicle() and PS_ConvertBall.targetType(self.item) ~= nil
        and self.item:getContainer() == self.character:getInventory()
        and self.character:getInventory():contains(self.item)
        and self.item:getAttachedSlot() == -1
        and not PS_ConvertBall.active(self.character, self.item)
end

function PS_ConvertBall:perform()
    ISBaseTimedAction.perform(self)
end

function PS_ConvertBall:complete()
    -- B42 action authority revalidates ownership at completion, after any transfer.
    if not self:isValid() then return false end
    local old = self.item
    local replacement = instanceItem(PS_ConvertBall.targetType(old))
    if not replacement then return false end
    replacement:setConditionMax(old:getConditionMax())
    replacement:setConditionNoSound(old:getCondition())
    replacement:setHaveBeenRepaired(old:getHaveBeenRepaired())
    replacement:copyTimesRepairedFrom(old)
    replacement:copyTimesHeadRepairedFrom(old)
    replacement:setFavorite(old:isFavorite())
    if old:hasModData() then replacement:copyModData(old:getModData()) end
    if old:isCustomName() then
        replacement:setName(old:getName())
        replacement:setCustomName(true)
    end
    if old:isCustomWeight() then
        replacement:setActualWeight(old:getActualWeight())
        replacement:setCustomWeight(true)
    end
    local primary = self.character:getPrimaryHandItem() == old
    local secondary = self.character:getSecondaryHandItem() == old
    local inventory = self.character:getInventory()
    inventory:AddItem(replacement)
    if primary then self.character:setPrimaryHandItem(replacement) end
    if secondary then self.character:setSecondaryHandItem(replacement) end
    inventory:Remove(old)
    self.done = true
    sendReplaceItemInContainer(inventory, old, replacement)
    replaceItemInContainer(inventory, old, replacement)
    if primary or secondary then sendEquip(self.character) end
    return true
end

function PS_ConvertBall:getDuration() return 1 end

function PS_ConvertBall:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end
