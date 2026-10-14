local C,M=PSCore,PSMatch
checks=0
local nativeAssert=assert
local function assert(value,message) checks=checks+1; return nativeAssert(value,message) end
local a={ax=0,ay=-2,bx=0,by=2}
local z={ax=10,ay=-2,bx=10,by=2}
local center={x=5,y=0}
local function ball()
    local b=C.newBall(5,0,0); b.id=9; b.match=assert(M.configure(a,z,center)); return b
end
assert(not M.configure(a,z,{x=-1,y=0}),'center must be inside')
assert(not M.configure(a,z,{x=0/0,y=0}),'finite coordinates')
assert(not M.configure({ax=0,ay=0,bx=0,by=1},z,center),'minimum width')
assert(not M.configure({ax=0,ay=-6,bx=0,by=6},z,center),'maximum width')
assert(not M.configure(a,{ax=-1,ay=0,bx=3,by=0},center),'intersecting lines')
local b=ball(); b.x=-.2
assert(M.segment(b,.2,0,0,5) and b.match.scoreB==1 and b.match.phase=='goal','whole ball crossing A scores B')
assert(not M.segment(b,.2,0,0,5) and b.match.scoreB==1,'no double score')
assert(b.match.resetAt==7 and b.match.lastScoringTeam=='B')
M.reset(b); assert(b.id==9 and b.x==5 and b.h==0 and b.match.scoreB==1 and b.match.phase=='play')
b=ball(); b.x=10.2
assert(M.segment(b,9.8,0,0,0) and b.match.scoreA==1,'opposite goal scores A')
b=ball(); b.x=.2
assert(not M.segment(b,-.2,0,0,0),'reverse crossing does not score')
b=ball(); b.x=-.05
assert(not M.segment(b,.2,0,0,0),'ball not fully over line')
b=ball(); b.x=-.2; b.y=1.95
assert(not M.segment(b,.2,1.95,0,0),'whole ball must fit between posts')
b=ball(); b.x=-.2; b.h=.8
assert(not M.segment(b,.2,0,.8,0),'over goal height')
b=ball(); b.x=-.2; b.h=.4
assert(M.segment(b,.2,0,.4,0),'airborne goal below height')
b=ball(); b.x=-.2; b.y=3
assert(not M.segment(b,-.2,1,0,0),'sideways behind goal')
b=ball(); b.x=-.15; b.y=1.4
assert(not M.segment(b,.05,2.2,0,0),'diagonal entry outside post cannot score behind it')
b=ball(); b.x=-.04
assert(not M.segment(b,.1,0,0,0),'partial crossing waits')
b.x=-.12
assert(M.segment(b,-.04,0,0,0),'full crossing is remembered across substeps')
local function move(ball,x,y,h)
    local fx,fy,fh=ball.x,ball.y,ball.h
    ball.x=x; ball.y=y; ball.h=h
    return M.segment(ball,fx,fy,fh,0)
end
b=ball(); b.x=.1
assert(not move(b,-.04,0,0))
for i=1,50 do assert(not move(b,-.04,i*.05,0)) end
for i=49,0,-1 do assert(not move(b,-.04,i*.05,0)) end
assert(not move(b,-.12,0,0),'partial crossing invalid after sideways aperture exit')
b=ball(); b.x=.1
assert(not move(b,-.04,0,0))
for i=1,16 do assert(not move(b,-.04,0,i*.05)) end
for i=15,0,-1 do assert(not move(b,-.04,0,i*.05)) end
assert(not move(b,-.12,0,0),'partial crossing invalid after above-goal exit')
b=ball(); b.x=.5; b.vx=-16
C.step(b,.2,nil,function(ball,x,y,h) return M.segment(ball,x,y,h,1) end)
assert(b.match.scoreB==1 and b.vx==0,'substep scoring stops before further movement')
print('PASS soccer swept goals, height, direction, pause and reset identity')
