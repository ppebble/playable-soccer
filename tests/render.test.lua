local s={}
local phase=PSRender.updateSpin(s,{x=1,y=1,z=0})
assert(phase==0)
phase=PSRender.updateSpin(s,{x=1.1,y=1,z=0})
assert(phase>0)
local phaseRest=PSRender.updateSpin(s,{x=1.1,y=1,z=0})
assert(phaseRest==phase)
-- Airborne horizontal travel rotates too; height alone is not a roll input.
local airborne=PSRender.updateSpin(s,{x=1.2,y=1,z=0,h=2})
assert(airborne~=phase)
local vertical=PSRender.updateSpin(s,{x=1.2,y=1,z=0,h=3})
assert(vertical==airborne)
-- Server correction/teleport must not create spurious revolutions.
local afterCorrection=PSRender.updateSpin(s,{x=12,y=1,z=0})
assert(afterCorrection==airborne)
local afterFloor=PSRender.updateSpin(s,{x=12.1,y=1,z=1})
assert(afterFloor==airborne)
local reverse=PSRender.updateSpin(s,{x=12,y=1,z=1})
assert(reverse~=afterFloor)
-- Arbitrary long sessions stay inside the finite 16-orientation atlas palette.
local seen={};local count=0
for i=1,12000 do
    local angle=i*0.37
    local p=PSRender.updateSpin(s,{x=s.x+math.cos(angle)*.06,y=s.y+math.sin(angle)*.06,z=s.z})
    assert(p>=0 and p<360 and p%22.5==0)
    local key=tostring(p)
    if not seen[key] then seen[key]=true;count=count+1 end
end
assert(count<=16)
PSRender.clear()
for _ in pairs(PSRender.proxies) do error("proxy retained") end
for _ in pairs(PSRender.spins) do error("spin retained") end
-- Draw through the proxy and inspect the native setter inputs. Travel changes
-- yaw only; x/y/z offsets continue to be driven solely by the ball position.
local originalFactory=instanceItem
local originalProxyFactory=IsoWorldInventoryObject.new
local rotations={}
local offsets={}
IsoWorldInventoryObject.new=function(item,square,x,y,z)
    local proxy=originalProxyFactory(item,square,x,y,z)
    proxy.setOffX=function(self,v) offsets.x=v end
    proxy.setOffY=function(self,v) offsets.y=v end
    proxy.setOffZ=function(self,v) offsets.z=v end
    return proxy
end
instanceItem=function(t)
    local item=originalFactory(t)
    item.setWorldXRotation=function(self,v) rotations.x=v end
    item.setWorldYRotation=function(self,v) rotations.y=v end
    item.setWorldZRotation=function(self,v) rotations.z=v end
    return item
end
PSRender.draw({{id=91,x=1,y=1,z=0,h=0}})
PSRender.draw({{id=91,x=1.1,y=1,z=0,h=0}})
assert(rotations.x==0 and rotations.y==0 and rotations.z>0)
assert(math.abs(offsets.x-.1)<.000001 and offsets.y==0 and offsets.z==0)
local yaw=rotations.z
PSRender.draw({{id=91,x=1.1,y=1,z=0,h=0}})
assert(rotations.x==0 and rotations.y==0 and rotations.z==yaw)
PSRender.draw({{id=91,x=1.1,y=1,z=0,h=.4}})
assert(math.abs(offsets.x-.1)<.000001 and offsets.y==0 and offsets.z==.4)
assert(rotations.x==0 and rotations.y==0 and rotations.z==yaw)
instanceItem=originalFactory;IsoWorldInventoryObject.new=originalProxyFactory;PSRender.clear()
print("PASS vertical-only cosmetic spin, rest, correction and bounded atlas palette")
