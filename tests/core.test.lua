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
