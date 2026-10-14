-- Detached presentation proxies: never addToWorld, add to a square, or transmit.
-- B42's exposed IsoWorldInventoryObject.render delegates to the native 3D drawer.
-- The drawer itself is not exposed to Lua. Native render ordering needs live QA.
PSRender = {proxies={},spins={}}
local R=PSRender
function R.clear() R.proxies={};R.spins={} end
function R.available() return getCore():isOption3DGroundItem() end
-- Cosmetic rolling comes from interpolated travel, never feeds server physics.
-- The native item atlas keys exact Euler angles. Bound the palette to 8 headings
-- x 16 phases instead of creating another cached texture every rendered frame.
local phaseStep=360/16
local radiansToDegrees=180/math.pi
function R.updateSpin(s,b)
    if s.x and s.z==b.z then
        local dx,dy=b.x-s.x,b.y-s.y
        local distance=math.sqrt(dx*dx+dy*dy)
        if distance>0.00001 and distance<2 then
            s.phase=((s.phase or 0)+distance/0.11*radiansToDegrees)%360
            -- Kahlua remainder preserves a negative sign; offset before modulo.
            local heading=(math.atan2(dy,dx)*radiansToDegrees+270)%360
            s.heading=(math.floor(heading/45+0.5)*45)%360
        end
    end
    s.x,s.y,s.z=b.x,b.y,b.z
    s.phase=s.phase or 0;s.heading=s.heading or 0
    return (math.floor(s.phase/phaseStep+0.5)*phaseStep)%360,s.heading
end
function R.draw(balls)
    if #balls>0 and not R.available() then R.clear();return false end
    local p=getSpecificPlayer(0)
    if not p or (getPlayer and getPlayer()~=p) then return end
    local retained,spins={},{}
    for _,b in pairs(balls) do
        if math.floor(p:getZ())==b.z and (p:getX()-b.x)^2+(p:getY()-b.y)^2<1600 then
            local square=getCell():getGridSquare(math.floor(b.x),math.floor(b.y),b.z)
            if square and square:isCanSee(0) then
                local proxy=R.proxies[b.id]
                local spin=R.spins[b.id]
                if not proxy then
                    -- Never pass the player's real inventory item to this constructor:
                    -- it clears that item's container. This fresh item stays detached.
                    local item=instanceItem("PlayableSoccer.SportsSoccerBall")
                    if item then
                        proxy=IsoWorldInventoryObject.new(item,square,0.5,0.5,0)
                        spin={item=item}
                        -- Sprite fallback can register an object-picker entry. Keep
                        -- only native 3D presentation; an empty sprite has no fallback.
                        proxy:setSprite(IsoSprite.new())
                    end
                end
                if proxy then
                    local phase,heading=R.updateSpin(spin,b)
                    -- Native renderer maps world Z to its vertical model axis.
                    -- Roll around a horizontal axis, then orient it to travel.
                    spin.item:setWorldXRotation(phase)
                    spin.item:setWorldYRotation(0)
                    spin.item:setWorldZRotation(heading)
                    proxy:setSquare(square)
                    -- setOffset sends native network sync; use the plain field setters.
                    proxy:setOffX(b.x-math.floor(b.x))
                    proxy:setOffY(b.y-math.floor(b.y))
                    proxy:setOffZ(math.max(0,b.h))
                    proxy:setAlphaAndTarget(0,1)
                    R.color=R.color or ColorInfo.new(1,1,1,1)
                    proxy:render(math.floor(b.x),math.floor(b.y),b.z,R.color,false,false,nil)
                    retained[b.id]=proxy
                    spins[b.id]=spin
                end
            end
        end
    end
    R.proxies=retained;R.spins=spins
    return true
end
