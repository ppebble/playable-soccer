local M,S=ServerMock,PSServer
checks=0
local nativeAssert=assert
local function assert(value,message) checks=checks+1; return nativeAssert(value,message) end
local p=M.player('owner',.5,.5,100)
local other=M.player('other',.5,.5,200)
local outsider={}
local idlePackets=#M.packets
M.tick(); M.time=M.time+1000; M.tick()
assert(#M.packets==idlePackets,'no idle state flood without practice balls')
S.command(outsider,'start',{itemId=100}); assert(S.serial==0)
M.send(p,'start',{itemId=200}); assert(S.serial==0,'foreign item forbidden')
p.items[1]=M.item(100,'Base.SoccerBall')
M.send(p,'start',{itemId=100}); assert(S.serial==0,'exact sports type required')
p.items[1]=M.item(100)
M.square(0,0,0).floor=false
M.send(p,'start',{itemId=100}); assert(S.serial==0,'no unsupported spawn')
M.square(0,0,0).floor=true
M.send(p,'start',{itemId=100})
local b=assert(S.balls[1]); assert(b.itemId==100 and b.owner=='owner' and #p.items==1)
assert(S.isItemActive(p,p.items[1]))
M.send(p,'start',{itemId=100}); assert(S.serial==1,'one ball per owner')
M.send(other,'stop',{id=1}); assert(S.balls[1]==b,'only owner may end')
M.send(other,'kick',{id=1,dx=1,dy=0,power=math.huge}); assert(b.vx==0)
M.send(other,'kick',{id=1,dx=1,dy=0,power=1}); assert(b.vx==PSCore.maxSpeed,'other nearby players can kick')
S.command(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==PSCore.maxSpeed,'rate limit')
other.x=20
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==PSCore.maxSpeed,'range validation')
other.x=.5; other.z=1
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==PSCore.maxSpeed,'floor validation')
other.z=0; other.dead=true
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==PSCore.maxSpeed,'alive validation')
other.dead=false; other.vehicle={}
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==PSCore.maxSpeed,'on-foot validation')
other.vehicle=nil
M.wall=function(a,c) return (a.x<1 and c.x>=1) or (c.x<1 and a.x>=1) end
other.x=1.1
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==PSCore.maxSpeed,'wall blocks near-ball kick')
M.tick(); M.time=M.time+250; M.tick()
assert(b.x<1 and b.vx<0,'wall reflection authoritative')
local bx,by,halt=S.collision(b,.5,.5,5.5,.5)
assert(bx and not halt,'adapter sweeps intermediate tiles')
M.wall=nil
M.missing=function(x) return x>=1 end
b.x=.95; b.y=.5; b.vx=16; b.vy=0
M.time=M.time+250; M.tick()
assert(b.x<1 and b.vx==0 and S.balls[1]==b,'unloaded terrain stops and retains ball')
M.missing=nil; M.square(1,0,0).floor=false
bx,by,halt=S.collision(b,.95,.5,1.1,.5); assert(halt,'unsupported floor safely blocks')
M.square(1,0,0).floor=true
M.square(1,1,0).solid=true
bx,by,halt=S.collision(b,.95,.95,1.05,1.05)
assert(bx and by and not halt,'solid diagonal corner must block both axes')
M.square(1,1,0).solid=false
-- A long real-world pause may advance at most one bounded quarter-second.
b.x=0; b.y=0; b.vx=16; b.vy=0
M.time=M.time+3600000; M.tick()
assert(b.x<=4 and S.balls[1]==b,'tick stall must not teleport or expire ball')
M.players={other}; other.x=30
for i=1,1000 do M.time=M.time+250; M.tick() end
assert(S.balls[1]==b,'disconnect and age do not remove ball')
M.players={p,other}; p.x=1000; p.z=2
M.send(p,'sync',{})
local packet=M.packets[#M.packets]; assert(packet.args.balls[1].itemId==100,'far owner retains handle')
M.send(p,'stop',{id=1}); assert(S.balls[1]==nil and #p.items==1)
assert(not S.isItemActive(p,p.items[1]))
M.mp=false; p.x=.5; p.z=0; p.name=''
M.send(p,'start',{itemId=100}); assert(S.balls[2].owner=='local:0')
M.send(p,'sync',{}); assert(M.packets[#M.packets].sp,'singleplayer response routing')
print('PASS soccer server authority, collision and persistent session')
local matchBall=S.balls[2]
p.x=5; p.y=0; other.x=5; other.y=0
local config={id=2,goalA={ax=0,ay=-2,bx=0,by=2},goalB={ax=10,ay=-2,bx=10,by=2},center={x=5,y=0}}
M.send(other,'configure',config); assert(not matchBall.match,'owner-only setup')
config.center.x=0/0
M.send(p,'configure',config); assert(not matchBall.match,'reject NaN setup')
config.center.x=5
M.unloaded=true
M.send(p,'configure',config); assert(not matchBall.match,'loaded setup required')
M.unloaded=false
M.square(0,0,0).solid=true
M.send(p,'configure',config); assert(not matchBall.match,'goal mouth must be clear')
M.square(0,0,0).solid=false
M.wall=function(a,c) return (a.x<0 and c.x>=0) or (c.x<0 and a.x>=0) end
M.send(p,'configure',config); assert(not matchBall.match,'wall across goal rejected')
M.wall=nil; p.x=100
M.send(p,'configure',config); assert(not matchBall.match,'setup must be nearby')
p.x=5
M.send(p,'configure',config)
assert(matchBall.match and matchBall.x==5 and matchBall.match.teams['local:0']=='A')
M.send(other,'team',{id=2,team='B'}); assert(matchBall.match.teams.other=='B')
M.send(other,'team',{id=2,team='C'}); assert(matchBall.match.teams.other=='B')
M.send(p,'sync',{})
local snapshot=M.packets[#M.packets].args.balls[1].match
snapshot.center.x=99; snapshot.teams.other='A'
assert(matchBall.match.center.x==5 and matchBall.match.teams.other=='B','SP packets must not alias nested authoritative state')
M.send(other,'kick',{id=2,dx=1,dy=0,power=1,lob=true})
assert(matchBall.vz==PSCore.maxSpeed*.5/PSCore.tilesPerFloor and matchBall.lob and matchBall.kicker=='other' and matchBall.kickSerial==1)
matchBall.x=9.8; matchBall.h=0; matchBall.vz=0; matchBall.vx=16; matchBall.vy=0
S.lastTick=M.time/1000; M.time=M.time+100; M.tick()
assert(matchBall.match.phase=='goal' and matchBall.match.scoreA==1)
other.x=matchBall.x
M.send(other,'kick',{id=2,dx=-1,dy=0,power=1}); assert(matchBall.vx==0,'no kicks during goal pause')
M.send(other,'reset',{id=2}); assert(matchBall.match.phase=='goal','owner-only reset')
M.time=M.time+2000; M.tick()
assert(S.balls[2]==matchBall and matchBall.id==2 and matchBall.x==5 and matchBall.match.phase=='play','automatic reset retains identity')
matchBall.x=100; matchBall.vx=1
M.send(p,'reset',{id=2})
assert(matchBall.x==5 and matchBall.vx==0 and matchBall.match.scoreA==1,'owner rescues stuck ball without clearing score')
print('PASS soccer authoritative match setup, teams, lob, pause and SP snapshots')
other.x=5; other.y=0; other.running=true; other.moving=true
S.motion={}
local initialSerial=matchBall.kickSerial
M.send(other,'dribble',{id=2,dx=1,dy=0,power=1,lob=true})
assert(matchBall.vx==PSCore.minSpeed and matchBall.vz==0 and matchBall.dribble,'running touch ignores client power and lob')
assert(matchBall.kickSerial==initialSerial+1)
S.command(other,'dribble',{id=2,dx=1,dy=0}); assert(matchBall.kickSerial==initialSerial+1,'dribble cooldown')
local function denied(args,message)
    local serial=matchBall.kickSerial
    M.send(other,'dribble',args or {id=2,dx=1,dy=0})
    assert(matchBall.kickSerial==serial,message)
end
other.running=false; denied(nil,'walking cannot auto dribble')
other.sprinting=true; other.moving=false; denied(nil,'stationary run flag cannot dribble')
other.moving=true
denied({id=2,dx=0/0,dy=0},'NaN direction')
denied({id=2,dx=2,dy=0},'oversized direction')
denied({id=2,dx=-1,dy=0},'backward spoof against facing')
matchBall.h=.01; denied(nil,'no airborne dribble'); matchBall.h=0
matchBall.vz=.01; denied(nil,'no lifting ball touch'); matchBall.vz=0
other.x=6; denied(nil,'contact range stricter than manual kick'); other.x=5
other.z=1; denied(nil,'same floor required'); other.z=0
matchBall.match.phase='goal'; denied(nil,'no goal-pause dribble'); matchBall.match.phase='play'
other.x=5.2; matchBall.x=4.8
M.wall=function(a,c) return a.x~=c.x end
denied(nil,'wall blocks automatic touch'); M.wall=nil
other.x=5; matchBall.x=5
S.motion={}; M.time=M.time+600; M.tick()
-- Server observes westward movement while facing still points east.
other.x=4.9; matchBall.x=4.9; M.time=M.time+100; M.tick()
local serial=matchBall.kickSerial
S.command(other,'dribble',{id=2,dx=1,dy=0})
assert(matchBall.kickSerial==serial,'measured movement overrides stale facing')
M.time=M.time+401; other.x=4.8; matchBall.x=4.8; matchBall.h=0; matchBall.vz=0
S.command(other,'dribble',{id=2,dx=-1,dy=0})
assert(matchBall.vx==-PSCore.minSpeed and matchBall.kickSerial==serial+1,'sprinting dribble follows server-observed movement')
-- A scoring tick publishes the frozen state immediately even inside cadence.
matchBall.x=9.98; matchBall.y=0; matchBall.h=0; matchBall.vz=0; matchBall.vx=16; matchBall.vy=0
matchBall.match.crossings={}; S.lastTick=M.time/1000; S.lastPublish=M.time/1000
local revision=S.revision
M.time=M.time+10; M.tick()
assert(matchBall.match.phase=='goal' and matchBall.vx==0 and S.revision>revision,'goal immediately freezes and publishes')
local scoredX=matchBall.x
M.time=M.time+100; M.tick()
assert(matchBall.x==scoredX and matchBall.vx==0,'goal ball stays frozen until reset')
print('PASS bounded running dribble authority and immediate goal freeze')
-- Rejected requests consume only the 80ms request budget, not touch cooldown.
matchBall.match.phase='play'; matchBall.x=5; matchBall.y=0; matchBall.h=0; matchBall.vz=0; matchBall.vx=0
other.x=6; other.y=0; other.running=true; other.sprinting=false; other.moving=true
M.time=M.time+1000; S.motion={}
serial=matchBall.kickSerial
S.command(other,'dribble',{id=2,dx=1,dy=0})
assert(matchBall.kickSerial==serial,'approach alone must not kick')
M.time=M.time+100; other.x=5.6
S.command(other,'dribble',{id=2,dx=-1,dy=0})
assert(matchBall.kickSerial==serial+1,'rejected approach retries before400ms')
M.time=M.time+100
S.command(other,'dribble',{id=2,dx=-1,dy=0})
assert(matchBall.kickSerial==serial+1,'accepted contact retains400ms cooldown')
local function prepareSweep(startX)
    M.time=M.time+1000; S.motion={}; matchBall.x=5; matchBall.y=0
    matchBall.h=0; matchBall.vz=0; matchBall.vx=0; matchBall.vy=0
    other.x=startX; other.y=0; other.moving=true; other.faceX=1
    S.lastTick=M.time/1000; M.tick()
    return matchBall.kickSerial
end
serial=prepareSweep(4.8)
M.time=M.time+100; other.x=5.9; other.moving=false
S.command(other,'dribble',{id=2,dx=1,dy=0})
assert(matchBall.kickSerial==serial+1,'recent swept contact survives missed frame and delayed moving flag')
serial=prepareSweep(4.8)
M.time=M.time+200; other.x=5.9
S.command(other,'dribble',{id=2,dx=1,dy=0})
assert(matchBall.kickSerial==serial,'stale swept contact rejected')
serial=prepareSweep(3.9)
M.time=M.time+100; other.x=5.9
S.command(other,'dribble',{id=2,dx=1,dy=0})
assert(matchBall.kickSerial==serial,'teleport segment cannot grant contact')
serial=prepareSweep(4.8)
M.time=M.time+100; other.x=5.9
M.wall=function(a,b) return a.x~=b.x end
S.command(other,'dribble',{id=2,dx=1,dy=0})
assert(matchBall.kickSerial==serial,'swept player path cannot cross wall')
M.wall=nil
serial=prepareSweep(4.8)
M.time=M.time+100; other.x=5.9; matchBall.h=.01
S.command(other,'dribble',{id=2,dx=1,dy=0})
assert(matchBall.kickSerial==serial,'swept contact cannot touch airborne ball')
serial=prepareSweep(5.8)
M.time=M.time+100; other.x=6.5
S.command(other,'dribble',{id=2,dx=1,dy=0})
assert(matchBall.kickSerial==serial,'swept historical contact cannot kick remotely')
print('PASS retry budget, accepted cooldown, swept contact and rejection boundaries')
