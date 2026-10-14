local C=PSCore
checks=0
local nativeAssert=assert
local function assert(value,message) checks=checks+1; return nativeAssert(value,message) end
assert(C.finite(0) and not C.finite(0/0) and not C.finite(math.huge) and not C.finite('1'))
assert(not C.newBall(0/0,0,0) and not C.newBall(0,0,.1))
local b=assert(C.newBall(.5,.5,0)); b.id=7
assert(not C.kick(b,0,0,1) and not C.kick(b,1,0,1.1) and not C.kick(b,1,0,0/0))
assert(not C.kick(b,math.huge,1,1))
assert(not C.step(b,math.huge) and b.x==.5)
assert(C.kick(b,1,0,1))
local hits=0
local function room(ball,fx,fy,tx,ty)
    assert(math.abs(tx-fx)<=.081 and math.abs(ty-fy)<=.081,'unbounded collision segment')
    local x=tx<0 or tx>1; local y=ty<0 or ty>1
    if x or y then hits=hits+1 end
    return x,y
end
for i=1,400 do assert(C.step(b,.25,room)); assert(b.x>=0 and b.x<=1) end
assert(hits>=3,'must bounce repeatedly without disappearing')
assert(b.id==7 and b.vx==0 and b.vy==0 and b.h==0)
local restX=b.x
for i=1,100 do C.step(b,.25,room) end
assert(b.x==restX and b.id==7,'rest must retain identity and position')
assert(C.kick(b,-1,0,.1)); C.step(b,.1,room)
assert(b.x~=restX,'resting ball must be re-kickable')
local falling=assert(C.newBall(0,0,0)); falling.h=2; falling.vz=2
local bounces=0; local previous=falling.vz
for i=1,1500 do
    C.step(falling,.01)
    if previous<0 and falling.vz>0 then bounces=bounces+1 end
    previous=falling.vz
    assert(falling.h>=0)
end
assert(bounces>=2 and falling.h==0 and falling.vz==0)
local halted=assert(C.newBall(0,0,0)); C.kick(halted,1,0,1)
C.step(halted,.1,function() return false,false,true end)
assert(halted.x==0 and halted.vx==0 and halted.vz==0)
local coarse=assert(C.newBall(.5,.5,0)); C.kick(coarse,1,1,1)
C.step(coarse,100,room)
assert(coarse.x>=0 and coarse.x<=1 and coarse.y>=0 and coarse.y<=1)
local paused=assert(C.newBall(0,0,0)); C.kick(paused,1,0,1)
assert(not C.step(paused,0) and paused.x==0)
assert(not C.step(paused,-1) and paused.x==0)
C.step(paused,3600)
assert(paused.x<=4,'wall clock stalls must not advance an hour of travel')
print('PASS soccer core persistent physics')
local frozen=C.newBall(5,0,0); frozen.h=.2; frozen.vx=10; frozen.vz=1; frozen.match={phase='goal'}
C.step(frozen,.25)
assert(frozen.x==5 and frozen.h==.2 and frozen.vx==0 and frozen.vz==0,'goal pause freezes client extrapolation including gravity')
local invalid=C.newBall(0,0,0)
assert(not C.kick(invalid,1,0,1,'yes'),'lob flag must be boolean')
coreMeasurements={}
for _,dt in ipairs({.01,.05,.25}) do
    for _,loft in ipairs({false,true}) do
        local ranges={}
        for _,power in ipairs({0,.5,.8,1}) do
            local shot=C.newBall(0,0,0); assert(C.kick(shot,1,0,power,loft))
            local peak=0
            for i=1,math.ceil(20/dt) do
                C.step(shot,dt,nil,function(ball) peak=math.max(peak,ball.h) end)
            end
            local target=loft and (.65+17.75*power^1.4) or (1.5+16.9*power)
            local targetPeak=loft and (.7+2.9*power) or (power>=.8 and (.02+.13*(power-.8)/.2) or 0)
            assert(math.abs(shot.x-target)<.001,'charge must map to stopping distance independent of timestep/loft')
            assert(math.abs(peak-targetPeak)<.03,'loft peak must match intended world-floor height')
            assert(shot.vx==0 and shot.h==0 and shot.vz==0,'shots land and rest without deletion')
            if power==1 then assert(shot.x>=18 and shot.x<=20,'full-range street soccer bound') end
            if loft and power==0 then assert(peak>.68 and shot.x<.66,'right tap must rise high nearby') end
            ranges[power]=shot.x
            coreMeasurements[#coreMeasurements+1]=string.format('dt=%.2f %s p=%.1f distance=%.4f peak=%.4f',dt,loft and 'RIGHT' or 'LEFT',power,shot.x,peak)
        end
        if not loft then assert(math.abs(ranges[.5]-(ranges[0]+ranges[1])/2)<.001,'left half-charge is half-way in distance') end
    end
end
local below=C.newBall(0,0,0); C.kick(below,1,0,.799,false); assert(below.vz==0,'left stays ground below80percent')
local threshold=C.newBall(0,0,0); C.kick(threshold,1,0,.8,false); assert(threshold.vz>0,'left gains slight lift at80percent')
local touch=C.newBall(0,0,0)
assert(not C.dribble(touch,1,0,0/0) and not C.dribble(touch,1,0,-1) and not C.dribble(touch,1,0,13))
assert(not C.dribble(touch,0,0,3) and not C.dribble(touch,math.huge,0,3))
assert(C.dribble(touch,1,0,0) and touch.vx==6 and touch.vz==0,'minimum ground touch speed')
assert(C.dribble(touch,1,0,5) and touch.vx==7.5,'touch outpaces running speed')
assert(C.dribble(touch,1,0,12) and touch.vx==12,'touch speed is bounded')
touch.h=.001; assert(not C.dribble(touch,1,0,5),'airborne contact prohibited')
touch.h=0; touch.vz=.001; assert(not C.dribble(touch,1,0,5),'rising contact prohibited')
touch.vz=0; touch.match={phase='goal'}; assert(not C.dribble(touch,1,0,5),'goal pause contact prohibited')
print('PASS distance-based charge, high right lob, slight strong-left lift and running dribble')
