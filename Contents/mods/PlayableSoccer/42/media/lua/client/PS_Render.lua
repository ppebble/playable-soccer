-- Detached presentation proxies: never addToWorld, add to a square, or transmit.
-- B42's exposed IsoWorldInventoryObject.render delegates to the native 3D drawer.
-- The drawer itself is not exposed to Lua. Native render ordering needs live QA.
PSRender = {proxies={}}
local R=PSRender
function R.clear() R.proxies={} end
function R.available() return getCore():isOption3DGroundItem() end
function R.draw(balls)
    if #balls>0 and not R.available() then R.clear();return false end
    local p=getSpecificPlayer(0)
    if not p or (getPlayer and getPlayer()~=p) then return end
    local retained={}
    for _,b in pairs(balls) do
        if math.floor(p:getZ())==b.z and (p:getX()-b.x)^2+(p:getY()-b.y)^2<1600 then
            local square=getCell():getGridSquare(math.floor(b.x),math.floor(b.y),b.z)
            if square and square:isCanSee(0) then
                local proxy=R.proxies[b.id]
                if not proxy then
                    -- Never pass the player's real inventory item to this constructor:
                    -- it clears that item's container. This fresh item stays detached.
                    local item=instanceItem("PlayableSoccer.SportsSoccerBall")
                    if item then
                        proxy=IsoWorldInventoryObject.new(item,square,0.5,0.5,0)
                        -- Sprite fallback can register an object-picker entry. Keep
                        -- only native 3D presentation; an empty sprite has no fallback.
                        proxy:setSprite(IsoSprite.new())
                    end
                end
                if proxy then
                    proxy:setSquare(square)
                    -- setOffset sends native network sync; use the plain field setters.
                    proxy:setOffX(b.x-math.floor(b.x))
                    proxy:setOffY(b.y-math.floor(b.y))
                    proxy:setOffZ(math.max(0,b.h))
                    proxy:setAlphaAndTarget(0,1)
                    R.color=R.color or ColorInfo.new(1,1,1,1)
                    proxy:render(math.floor(b.x),math.floor(b.y),b.z,R.color,false,false,nil)
                    retained[b.id]=proxy
                end
            end
        end
    end
    R.proxies=retained
    return true
end
