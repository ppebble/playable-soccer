require "PS_ConvertBall"
require "PS_Client"
require "TimedActions/ISTimedActionQueue"
require "ISUI/ISInventoryPaneContextMenu"

PS_BallMenu = {}

function PS_BallMenu.owns(player, item)
    if not player or not item then return false end
    local container = item:getContainer()
    return container and ((container == player:getInventory() and container:contains(item))
        or (container.isInCharacterInventory and container:isInCharacterInventory(player)))
end

function PS_BallMenu.convert(player, item)
    if not PS_BallMenu.owns(player, item) or not PS_ConvertBall.targetType(item)
        or PS_ConvertBall.active(player, item) then return end
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    ISTimedActionQueue.add(PS_ConvertBall:new(player, item))
end

function PS_BallMenu.start(player, item)
    -- Main inventory requirement is explicit; do not race an asynchronous transfer.
    if item:getContainer() == player:getInventory() then PSClient.start(player, item) end
end

function PS_BallMenu.createMatch(player, item)
    if item:getContainer() == player:getInventory() then PSClient.start(player, item, "match") end
end

function PS_BallMenu.fill(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)
    if not player or player:isDead() or player:getVehicle() then return end
    local seen = {}
    local sportsFound = false
    for _, entry in ipairs(items) do
        local item = entry
        if type(entry) == "table" and entry.items then item = entry.items[1] end
        local target = PS_ConvertBall.targetType(item)
        if target and not seen[item] and PS_BallMenu.owns(player, item) then
            seen[item] = true
            local active = PS_ConvertBall.active(player, item)
            local key = target == "Base.SoccerBall" and "ContextMenu_PS_ConvertBack" or "ContextMenu_PS_ConvertSports"
            local option = context:addOption(getText(key), player, PS_BallMenu.convert, item)
            if option then option.notAvailable = active or item:getAttachedSlot() ~= -1 end
            if item:getFullType() == "PlayableSoccer.SportsSoccerBall" then
                sportsFound = true
                local start = context:addOption(getText("ContextMenu_PS_Start"), player, PS_BallMenu.start, item)
                if start then start.notAvailable = active or item:getContainer() ~= player:getInventory() end
                local match = context:addOption(getText("ContextMenu_PS_CreateMatch"), player, PS_BallMenu.createMatch, item)
                if match then match.notAvailable = active or item:getContainer() ~= player:getInventory() end
            end
        end
    end
    if sportsFound then PSClient.joinMenu(context) end
end

Events.OnFillInventoryObjectContextMenu.Add(PS_BallMenu.fill)
