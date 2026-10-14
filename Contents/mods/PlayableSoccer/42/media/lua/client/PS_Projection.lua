require "PS_Core"

-- All screen/world conversion lives here. A future camera adapter must supply
-- both directions; gameplay, goals and scoring remain world-space data.
PSProjection = {}
local P=PSProjection
function P.register(adapter)
    if adapter~=nil and (type(adapter)~="table" or type(adapter.screenToWorld)~="function"
        or type(adapter.worldToScreen)~="function") then return false end
    P.adapter=adapter
    return true
end
function P.available()
    -- Do not guess a world position using vanilla projection under Viewpoint.
    return P.adapter~=nil or Viewpoint==nil
end
local function result(ok,x,y)
    if ok and PSCore.finite(x) and PSCore.finite(y) then return x,y end
end
function P.screenToWorld(index,x,y,z)
    if not P.available() then return nil end
    if P.adapter then return result(pcall(P.adapter.screenToWorld,index,x,y,z)) end
    return result(pcall(function() return screenToIsoX(index,x,y,z),screenToIsoY(index,x,y,z) end))
end
function P.worldToScreen(index,x,y,z)
    if not P.available() then return nil end
    if P.adapter then return result(pcall(P.adapter.worldToScreen,index,x,y,z)) end
    return result(pcall(function() return isoToScreenX(index,x,y,z),isoToScreenY(index,x,y,z) end))
end
