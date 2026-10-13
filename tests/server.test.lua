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
M.send(other,'kick',{id=1,dx=1,dy=0,power=1}); assert(b.vx==16,'other nearby players can kick')
S.command(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==16,'rate limit')
other.x=20
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==16,'range validation')
other.x=.5; other.z=1
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==16,'floor validation')
other.z=0; other.dead=true
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==16,'alive validation')
other.dead=false; other.vehicle={}
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==16,'on-foot validation')
other.vehicle=nil
M.wall=function(a,c) return (a.x<1 and c.x>=1) or (c.x<1 and a.x>=1) end
other.x=1.1
M.send(other,'kick',{id=1,dx=-1,dy=0,power=1}); assert(b.vx==16,'wall blocks near-ball kick')
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
