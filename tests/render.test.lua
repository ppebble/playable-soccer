local s={}
local phase,heading=PSRender.updateSpin(s,{x=1,y=1,z=0})
assert(phase==0 and heading==0)
phase,heading=PSRender.updateSpin(s,{x=1.1,y=1,z=0})
assert(phase>0 and heading==270,"phase="..tostring(phase).." heading="..tostring(heading))
local phaseRest,headingRest=PSRender.updateSpin(s,{x=1.1,y=1,z=0})
assert(phaseRest==phase and headingRest==heading)
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
local _,reverse=PSRender.updateSpin(s,{x=12,y=1,z=1})
assert(reverse==90)
-- Arbitrary long sessions stay inside the finite 8 x 16 atlas palette.
local seen={};local count=0
for i=1,12000 do
    local angle=i*0.37
    local p,h=PSRender.updateSpin(s,{x=s.x+math.cos(angle)*.06,y=s.y+math.sin(angle)*.06,z=s.z})
    assert(p>=0 and p<360 and p%22.5==0)
    assert(h>=0 and h<360 and h%45==0)
    local key=tostring(p)..":"..tostring(h)
    if not seen[key] then seen[key]=true;count=count+1 end
end
assert(count<=128)
PSRender.clear()
for _ in pairs(PSRender.proxies) do error("proxy retained") end
for _ in pairs(PSRender.spins) do error("spin retained") end
print("PASS travel-driven model rotation, rest, correction and bounded atlas palette")
