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
M.send(other,'kick',{id=1,dx=1,dy=0,power=1}); assert(b.vx>0 and b.vz>0,'other nearby players can kick')
local acceptedKickSpeed=b.vx
S.command(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==acceptedKickSpeed,'rate limit')
other.x=20
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==acceptedKickSpeed,'range validation')
other.x=.5; other.z=1
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==acceptedKickSpeed,'floor validation')
other.z=0; other.dead=true
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==acceptedKickSpeed,'alive validation')
other.dead=false; other.vehicle={}
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==acceptedKickSpeed,'on-foot validation')
other.vehicle=nil
M.wall=function(a,c) return (a.x<1 and c.x>=1) or (c.x<1 and a.x>=1) end
other.x=1.1
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==acceptedKickSpeed,'wall blocks near-ball kick')
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
assert(b.x<=16*.25*1.4 and S.balls[1]==b,'tick stall must not teleport or expire ball')
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
matchBall.x=8;matchBall.h=1;matchBall.vx=3
M.send(other,'reset',{id=2});assert(matchBall.x==8,'practice reset owner only')
M.send(p,'reset',{id=2})
assert(matchBall.x==.5 and matchBall.h==0 and matchBall.vx==0,'practice reset restores original spawn')
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
assert(matchBall.vz>0 and matchBall.lob and matchBall.kickPower==1 and matchBall.kicker=='other' and matchBall.kickSerial==1,'accepted lob and kicker metadata')
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
local function advance(seconds)
    M.time=M.time+seconds*1000; M.tick()
end
local function resetTest()
    S.controls={};S.stunned={};S.motion={}
    p.x=5;p.y=0;p.z=0;p.faceX=1;p.faceY=0;p.onFloor=false;p.knockedDown=false;p.stateName=nil
    other.x=5;other.y=0;other.z=0;other.faceX=1;other.faceY=0
    M.players={p,other};M.wall=nil
    M.send(p,'reset',{id=2})
    advance(.4)
end
local function register(who)
    M.send(who,'control',{id=2,active=true})
end
local function heldBy(who)
    return matchBall.possession and matchBall.possession.kind=='player' and matchBall.possession.key==who:getUsername()
end
-- SP fallback name is deliberate throughout this fixture.
local ownerKey='local:0'
resetTest();advance(.1)
assert(not matchBall.possession,'nearby nonparticipants never pick up')
register(p);advance(.05)
assert(matchBall.possession and matchBall.possession.key==ownerKey,'selected participant acquires resting ball')
local x=matchBall.x
p.x=p.x+.1;advance(.05)
assert(matchBall.x>x and matchBall.x-x<=1.60001,'holder follow is bounded, not teleporting')
local serial=matchBall.kickSerial
M.send(other,'kick',{id=2,dx=1,dy=0,power=0})
assert(matchBall.kickSerial==serial,'foreign player cannot shoot possessed ball')
M.send(p,'kick',{id=2,dx=1,dy=0,power=0})
assert(not matchBall.possession and matchBall.kickSerial==serial+1,'holder shot releases possession')
matchBall.vx=0;matchBall.vy=0;matchBall.x=p.x
advance(.2);assert(not matchBall.possession,'global pickup grace after shot')
advance(.2);assert(not matchBall.possession,'shooter-specific grace exceeds global grace')
advance(.25);assert(matchBall.possession,'shooter can regain after grace')
M.send(p,'control',{id=2,active=false});assert(not matchBall.possession,'leaving mode releases immediately')
resetTest();register(p);advance(.01)
advance(3.1);assert(not matchBall.possession,'expired heartbeat releases')
resetTest();register(p);advance(.01);M.players={other};advance(.1)
assert(not matchBall.possession,'disconnect releases without deleting ball')
resetTest();register(p);advance(.01);p.x=20;advance(.1)
assert(not matchBall.possession and matchBall.x<7,'holder teleport never drags ball remotely')
resetTest();register(p);advance(.01)
M.wall=function(a,b) return a.x~=b.x end
p.faceX=-1;S.motion={};advance(.1)
assert(matchBall.possession and math.abs(matchBall.x-p.x)<.001,'blocked forward offset keeps ball at feet')
p.x=4.8;matchBall.x=5.2;S.motion={};advance(.1)
assert(matchBall.possession and matchBall.x==5.2,'brief wall obstruction cannot pull ball through')
advance(.26);assert(not matchBall.possession and matchBall.x==5.2,'persistent separation by wall releases ball')
resetTest();p.onFloor=true;register(p);advance(.1);assert(not matchBall.possession,'downed participant cannot acquire')
p.onFloor=false;p.stateName='PlayerGetUpState';advance(.1);assert(not matchBall.possession,'get-up transition cannot acquire')
p.stateName=nil;advance(.1);assert(matchBall.possession,'standing participant may acquire')
-- Opponent tackle consumes cooldown even on a miss, then steals at close range.
resetTest();register(p);register(other);advance(.01)
assert(matchBall.possession.key==ownerKey)
other.x=matchBall.x-.4;other.y=matchBall.y
M.send(other,'tackle',{id=2,dx=-1,dy=0})
assert(matchBall.possession.key==ownerKey,'wrong-direction tackle misses')
S.command(other,'tackle',{id=2,dx=1,dy=0})
assert(matchBall.possession.key==ownerKey,'miss consumes tackle cooldown')
advance(.81);other.x=matchBall.x-.4;S.command(other,'tackle',{id=2,dx=1,dy=0})
assert(heldBy(other) and S.stunned[ownerKey]>M.time/1000,'valid opponent tackle steals and stuns victim')
local fall
for _,packet in ipairs(M.packets) do if packet.command=='tackled' then fall=packet end end
assert(fall and fall.args.id==2 and fall.args.serial==matchBall.tackleSerial,'victim receives dedicated fall event')
serial=matchBall.kickSerial
M.send(p,'kick',{id=2,dx=1,dy=0,power=0});assert(matchBall.kickSerial==serial,'stunned victim cannot shoot')
resetTest();matchBall.match.teams.other='A';register(p);register(other);advance(.01)
other.x=matchBall.x-.4
M.send(other,'tackle',{id=2,dx=1,dy=0});assert(matchBall.possession.key==ownerKey,'teammate tackle is ignored')
matchBall.match.teams.other='B'
resetTest();register(p);advance(.01);other.x=matchBall.x-.4
M.send(other,'tackle',{id=2,dx=1,dy=0});assert(matchBall.possession.key==ownerKey,'unregistered bystander cannot tackle')
-- Configure creates independent clear test circles and reports unavailable sites.
resetTest();M.send(p,'configure',config)
local zones=matchBall.match.testZones
assert(zones.tackle and zones.keeper and zones.tackle.r==.9)
local keeper=zones.keeper
advance(.4) -- Configuration/reset capture grace expires before the incoming pass.
matchBall.x=keeper.x-.8;matchBall.y=keeper.y;matchBall.h=0;matchBall.vx=8;matchBall.vy=0
advance(.01)
assert(matchBall.possession and matchBall.possession.kind=='zone','keeper captures incoming loose pass even above player pickup speed')
local captureX=matchBall.x;advance(.1);assert(matchBall.x==captureX,'keeper capture never teleports to center')
other.x=matchBall.x-.4;other.y=matchBall.y;register(other)
M.send(other,'tackle',{id=2,dx=1,dy=0})
assert(heldBy(other),'registered player can steal from keeper zone')
-- Wait past steal grace while still inside the keeper circle, then shoot out.
advance(.65)
assert(heldBy(other),'keeper does not take a held ball after steal grace')
local shotX=matchBall.x
M.send(other,'kick',{id=2,dx=1,dy=0,power=0})
assert(not matchBall.possession,'keeper holder can release a shot')
advance(.1)
assert(not matchBall.possession and matchBall.x>shotX,'shot travels inside keeper zone during global capture grace')
advance(.2)
assert(not matchBall.possession,'keeper respects entire shot capture grace')
resetTest();register(p);advance(.01)
local tackleZone=matchBall.match.testZones.tackle
-- Move a carried ball and holder into the test area without a remote follow.
p.x=tackleZone.x;p.y=tackleZone.y;matchBall.x=p.x+.1;matchBall.y=p.y;S.motion={}
advance(.05)
assert(not matchBall.possession and S.stunned[ownerKey]>M.time/1000,'tackle zone knocks down entering holder')
resetTest();register(p);advance(.01);M.send(p,'reset',{id=2})
assert(not matchBall.possession and matchBall.x==5,'reset clears possession')
resetTest();register(p);advance(.01)
p.x=9.8;p.y=0;matchBall.x=9.8;matchBall.y=0;S.motion={}
advance(.1)
assert(matchBall.match.phase=='goal' and not matchBall.possession,'carried goal uses swept scoring and clears possession')
advance(2.1);assert(matchBall.x==5 and not matchBall.possession,'goal restart remains loose with grace')
resetTest();M.missing=function(x,y) return y>=3 end
M.send(p,'configure',config)
assert(matchBall.match.testZones.tackle and not matchBall.match.testZones.keeper,'unavailable keeper zone omitted independently')
local unavailable=false
for _,packet in ipairs(M.packets) do if packet.command=='notice' and packet.args.key=='UI_PS_TestZonesUnavailable' then unavailable=true end end
assert(unavailable,'zone placement failure is communicated')
M.missing=nil
print('PASS possession participation, follow, shot release, tackle, stun and test zones')
resetTest();S.command(p,'control',{id=2,active=true});advance(.01)
assert(matchBall.possession)
S.command(p,'control',{id=2,active=false})
S.command(p,'control',{id=2,active=true})
assert(not matchBall.possession and S.controls[ownerKey].id==2,'same-frame leave and return both apply')
resetTest();p.x=4.8;matchBall.x=5.2
M.wall=function(a,b) return a.x~=b.x end
register(p);advance(.01)
assert(not matchBall.possession,'nearby pickup cannot cross wall')
resetTest();register(p);matchBall.h=.01;matchBall.vz=1;advance(.01)
assert(not matchBall.possession,'airborne loose ball not automatically picked up')
matchBall.h=0;matchBall.vz=0;matchBall.vx=8;matchBall.x=p.x;advance(.01)
assert(not matchBall.possession,'fast loose shot not automatically picked up')
resetTest();register(p);register(other);advance(.01)
matchBall.x=5.2;other.x=4.8
M.wall=function(a,b) return a.x~=b.x end
M.send(other,'tackle',{id=2,dx=1,dy=0})
assert(matchBall.possession.key==ownerKey,'tackle cannot cross wall')
M.wall=nil
resetTest();register(p);advance(.01)
M.send(other,'start',{itemId=200})
local second=S.balls[3];assert(second)
S.command(p,'control',{id=3,active=true})
assert(not matchBall.possession,'switching selected ball releases old possession')
advance(.01)
assert(second.possession and second.possession.key==ownerKey and not matchBall.possession,'one selected player owns only one ball')
S.command(p,'control',{id=2,active=false})
assert(S.controls[ownerKey].id==3,'stale leave for previous ball cannot cancel new control')
local prior=S.revision
S.command(p,'control',{id=3,active=true})
assert(S.revision==prior,'same-selection heartbeat does not broadcast redundant state')
print('PASS control transitions, single-ball ownership, wall and airborne pickup boundaries')

-- Sustained running and network-style batched movement must not drop possession.
local function beginFollowTest()
    resetTest();register(p);advance(.01)
    matchBall.match=nil -- keep the running fixture out of goals and test zones
end
local originalMatch=matchBall.match
for _,speed in ipairs({4,8,12}) do
    matchBall.match=originalMatch;beginFollowTest()
    for i=1,180 do
        S.command(p,'control',{id=2,active=true})
        p.x=p.x+speed/60;advance(1/60)
        assert(matchBall.possession and matchBall.possession.key==ownerKey,'sustained sprint retains holder')
        if i>15 then assert(math.abs(matchBall.x-(p.x+.55))<.01,'ball stays at forward offset at sprint speed') end
    end
end
matchBall.match=originalMatch;beginFollowTest()
for batch=1,8 do
    for i=1,24 do S.command(p,'control',{id=2,active=true});advance(1/60) end
    p.x=p.x+3.2;advance(1/60)
    assert(matchBall.possession,'400ms position batch must allow catch-up beyond old two-tile cutoff')
end
for i=1,24 do S.command(p,'control',{id=2,active=true});advance(1/60) end
assert(math.abs(matchBall.x-p.x-.55)<.01,'batched updates converge to the feet')
-- Turn sharply, stop, and tolerate a small same-time position correction.
p.faceX=-1;p.x=p.x-.2;advance(1/60)
assert(matchBall.possession,'sharp reversal retains ownership')
for i=1,30 do S.command(p,'control',{id=2,active=true});advance(1/60) end
assert(math.abs(matchBall.x-p.x+.55)<.01,'stopped ball settles ahead of new facing')
p.x=p.x+.5;M.tick();assert(matchBall.possession,'same-timestamp correction is not an automatic release')
-- Repeated lag cannot retain a ball indefinitely, and remote teleports still fail.
for i=1,12 do
    S.command(p,'control',{id=2,active=true})
    p.x=matchBall.x+3;p.faceX=1;advance(.1)
end
assert(not matchBall.possession,'persistent excessive lag eventually releases')
matchBall.match=originalMatch;beginFollowTest()
local beforeTeleport=matchBall.x;p.x=p.x+20;advance(.01)
assert(not matchBall.possession and matchBall.x==beforeTeleport,'large teleport cannot drag the ball')
matchBall.match=originalMatch
print('PASS sustained sprint, batched updates, sharp turn, corrections, lag expiry and teleport boundaries')

M.send(p,'reset',{id=2});p.x=matchBall.x;p.y=matchBall.y
M.send(p,'kick',{id=2,dx=1,dy=0,power=.9,lob=false})
assert(matchBall.kickPower==.9,'server publishes accepted high shot power')
M.send(p,'kick',{id=2,dx=1,dy=0,power=2,lob=false})
assert(matchBall.kickPower==.9,'rejected power cannot change animation metadata')
M.send(p,'kick',{id=2,dx=1,dy=0,power=.2,lob=true})
assert(matchBall.kickPower==.2,'light kick replaces previous strong power metadata')
