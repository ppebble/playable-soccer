function require() end
checks = 0
function check(value, label) checks=checks+1; assert(value, label) end
ISBaseTimedAction = {}
function ISBaseTimedAction:derive() local t={}; t.__index=t; setmetatable(t,{__index=self}); return t end
function ISBaseTimedAction:new(character) return setmetatable({character=character},{__index=self}) end
function ISBaseTimedAction:perform() end
Mock = {sent=0, equipped=0, queued={}}
function Mock.item(kind)
    local item={kind=kind, slot=-1, mod={}, condition=3, conditionMax=5, repaired=2, name=kind, weight=1}
    function item:getFullType() return self.kind end
    function item:getContainer() return self.container end
    function item:getAttachedSlot() return self.slot end
    function item:getCondition() return self.condition end
    function item:setConditionNoSound(v) self.condition=v end
    function item:getConditionMax() return self.conditionMax end
    function item:setConditionMax(v) self.conditionMax=v end
    function item:getHaveBeenRepaired() return self.repaired end
    function item:setHaveBeenRepaired(v) self.repaired=v end
    function item:copyTimesRepairedFrom(v) self.repairs=v.repairs end
    function item:copyTimesHeadRepairedFrom(v) self.headRepairs=v.headRepairs end
    function item:isFavorite() return self.favorite end
    function item:setFavorite(v) self.favorite=v end
    function item:hasModData() return true end
    function item:getModData() return self.mod end
    function item:copyModData(v) for k,x in pairs(v) do self.mod[k]=x end end
    function item:isCustomName() return self.customName end
    function item:setCustomName(v) self.customName=v end
    function item:getName() return self.name end
    function item:setName(v) self.name=v end
    function item:isCustomWeight() return self.customWeight end
    function item:setCustomWeight(v) self.customWeight=v end
    function item:getActualWeight() return self.weight end
    function item:setActualWeight(v) self.weight=v end
    return item
end
function instanceItem(kind) if not Mock.failFactory then return Mock.item(kind) end end
function Mock.player()
    local player={inventory={items={}}}
    function player.inventory:AddItem(item) self.items[item]=true; item.container=self; return item end
    function player.inventory:Remove(item) self.items[item]=nil; item.container=nil end
    function player.inventory:contains(item) return self.items[item] == true end
    function player:isDead() return self.dead end
    function player:getVehicle() return self.vehicle end
    function player:getInventory() return self.inventory end
    function player:getPrimaryHandItem() return self.primary end
    function player:getSecondaryHandItem() return self.secondary end
    function player:setPrimaryHandItem(v) self.primary=v end
    function player:setSecondaryHandItem(v) self.secondary=v end
    return player
end
PSServer={isItemActive=function(player,item) return item.active == true end}
PSClient={start=function(player,item) Mock.started=item end}
function sendReplaceItemInContainer() Mock.sent=Mock.sent+1 end
function replaceItemInContainer() end
function sendEquip() Mock.equipped=Mock.equipped+1 end
ISTimedActionQueue={add=function(a) Mock.queued[#Mock.queued+1]=a end}
ISInventoryPaneContextMenu={transferIfNeeded=function() end}
Events={OnFillInventoryObjectContextMenu={Add=function(fn) Mock.fill=fn end}}
function getSpecificPlayer() return Mock.current end
function getText(key) return key end
