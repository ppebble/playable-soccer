local C=PSClient
local function state(revision,x)
    return {revision=revision,balls={{id=1,itemId=17,owner="test",x=x or 1,y=1,z=0,h=0,vx=0,vy=0,vz=0}}}
end
local item={getID=function() return 17 end,getFullType=function() return "PlayableSoccer.SportsSoccerBall" end}
C.start(TEST.player,item)
assert(TEST.sent[1].command=="start" and TEST.sent[1].args.itemId==17)
assert(C.isItemActive(TEST.player,item))
C.receive("state",state(1));assert(C.selected==1)
TEST.buttons[0]=true;C.mouseDown();assert(C.charge)
TEST.time=1450;TEST.buttons[0]=false;C.update(TEST.player)
assert(TEST.sent[#TEST.sent].command=="kick" and TEST.sent[#TEST.sent].args.power==0.5)
assert(TEST.sent[#TEST.sent].args.lob==false and TEST.sent[#TEST.sent].args.dx==7)
assert(TEST.banned)
TEST.buttons[0]=true;C.mouseDown();TEST.buttons[1]=true;C.update(TEST.player);assert(not C.charge)
TEST.buttons[1]=false
TEST.buttons[0]=false
TEST.buttons[1]=true;C.rightDown();assert(C.charge.lob and C.charge.button==1 and TEST.captured[1])
TEST.time=TEST.time+450;TEST.buttons[1]=false
ISObjectClickHandler.rdownObject={};TEST.rightObject={};C.rightUp()
assert(ISObjectClickHandler.rdownObject==nil and TEST.rightObject==nil)
C.update(TEST.player);assert(TEST.sent[#TEST.sent].command=="kick" and TEST.sent[#TEST.sent].args.lob==true)
TEST.typing=true;C.mouseDown();C.update(TEST.player);assert(not C.charge and not TEST.banned)
TEST.typing=false;TEST.paused=true;C.mouseDown();assert(not C.charge);TEST.paused=false
TEST.uis={{isVisible=function() return true end,isConsumeMouseEvents=function() return true end,isPointOver=function() return true end}}
C.mouseDown();assert(not C.charge);TEST.uis={}
TEST.queue={true};C.mouseDown();assert(not C.charge);TEST.queue={}
-- Only the owned cosmetic action may keep dribble input and RMB capture alive.
TEST.queue={setmetatable({},PS_KickAction)};C.update(TEST.player)
assert(not C.blocked() and TEST.banned)
TEST.buttons[1]=true;C.rightDown();assert(C.charge and C.charge.lob)
C.keyPressed(Keyboard.KEY_ESCAPE);TEST.buttons[1]=false;C.rightUp()
TEST.queue={setmetatable({},PS_KickAction),{Type="PS_KickAction"}}
C.update(TEST.player);assert(C.blocked() and not TEST.banned)
TEST.queue={}
TEST.drag=true;C.mouseDown();assert(not C.charge);TEST.drag=nil
TEST.time=1500;C.receive("state",state(2,2))
TEST.time=1625;local pos=C.positions()[1];assert(pos.x>1 and pos.x<2)
C.receive("state",state(1,99));assert(C.ball(1).x==2)
PSRender.draw(C.positions());assert(TEST.renders==1 and TEST.lastItem~=item and TEST.lastItem.type=="PlayableSoccer.SportsSoccerBall")
assert(PSRender.proxies[1])
PSRender.draw({});assert(not PSRender.proxies[1])
-- Out of reach still owns soccer controls; Escape restores native input.
C.receive("state",state(3,8));C.update(TEST.player);assert(TEST.banned and C.ball(1))
C.stop();assert(C.selected==nil and TEST.sent[#TEST.sent].command=="stop")
C.receive("state",{revision=4,balls={}});assert(not C.isItemActive(TEST.player,item))
-- Explicit owner stop remains reachable after leaving input mode.
C.receive("state",state(5,8));C.leave()
local menu={options={},addOption=function(self,label,target,callback) self.options[#self.options+1]={label=label,target=target,callback=callback} end}
C.context(0,menu,{},false)
local stop
for _,o in ipairs(menu.options) do if o.label=="UI_PS_StopBall" then stop=o end end
assert(stop);stop.callback(stop.target);assert(TEST.sent[#TEST.sent].args.id==1)
C.receive("state",{revision=6,balls={}})
C.start(TEST.player,item);TEST.time=TEST.time+5001;C.update(TEST.player)
assert(not C.pendingItem and C.message=="UI_PS_StartFailed")
-- Restoring an existing combat restriction must not enable attacking.
C.receive("state",state(7));C.selected=1;TEST.banned=true;C.update(TEST.player)
C.leave();assert(TEST.banned);TEST.banned=false
Events.OnGameStart.callback()
assert(C.overlay.background==false and C.overlay.consume==false)
assert(C.overlay.instantiated and C.overlay.wantMouse==false)
C.overlay:render();assert(TEST.hudRendered)
assert(C.overlay.width==0 and C.overlay.height==0)
TEST.width=1600;TEST.height=900;C.overlay:render()
assert(C.overlay.width==0 and C.overlay.height==0)
for _,name in ipairs({'onMouseDown','onMouseUp','onRightMouseDown','onRightMouseUp','onMouseMove','onMouseWheel'}) do
    assert(C.overlay[name](C.overlay,0,0)==false, 'HUD must explicitly pass '..name)
end
C.overlay:prerender() -- No draw methods provided: a background draw would fail.
TEST.no3D=true
C.start(TEST.player,item);assert(not C.pendingItem and C.message=="UI_PS_RenderError")
assert(PSRender.draw({{id=1,x=1,y=1,z=0,h=0}})==false)
TEST.no3D=false
-- Exact prior force-aim/attack values restored at UI, death, and explicit exit.
C.receive("state",state(8));C.selected=1;TEST.forceAim=true;C.update(TEST.player)
assert(not TEST.forceAim)
TEST.typing=true;C.update(TEST.player);assert(TEST.forceAim and not TEST.banned)
TEST.typing=false;TEST.forceAim=false;C.update(TEST.player)
TEST.buttons[1]=true;C.rightDown();C.keyPressed(Keyboard.KEY_ESCAPE)
assert(not C.charge and C.selected==1)
C.keyPressed(Keyboard.KEY_ESCAPE);assert(not C.selected and not TEST.banned)
TEST.buttons[1]=false;ISObjectClickHandler.rdownObject={};C.rightUp();assert(not ISObjectClickHandler.rdownObject)
local ordinaryClick={};ISObjectClickHandler.rdownObject=ordinaryClick;C.rightUp();assert(ISObjectClickHandler.rdownObject==ordinaryClick)
C.selected=1;C.update(TEST.player);TEST.dead=true;C.update(TEST.player);assert(not C.guard and not TEST.banned);TEST.dead=false
TEST.noProjection=true;C.mouseDown();assert(not C.charge);TEST.noProjection=false
C.leave();TEST.setup=true;C.mouseDown();assert(TEST.setupClicked and not C.charge)
C.keyPressed(Keyboard.KEY_ESCAPE);assert(not TEST.setup)
-- Accepted local kick serial triggers once; sync replay must not animate again.
local accepted=state(9);accepted.balls[1].kickSerial=1;accepted.balls[1].kicker="test";accepted.balls[1].kickDx=1;accepted.balls[1].kickDy=0;accepted.balls[1].lob=true
C.receive("state",accepted);assert(TEST.motions==1 and TEST.motionLob)
C.receive("state",accepted);assert(TEST.motions==1)
-- Running contact is world movement, independent of cursor, and rate bounded.
C.leave();C.selected=1;TEST.running=true;TEST.moving=true;TEST.time=10000
C.receive("state",state(10));C.update(TEST.player)
TEST.time=10020;TEST.x=1.1;C.update(TEST.player)
assert(TEST.sent[#TEST.sent].command=="dribble" and TEST.sent[#TEST.sent].args.dx==1 and TEST.sent[#TEST.sent].args.dy==0)
local sent=#TEST.sent
TEST.time=10040;TEST.x=1.2;C.update(TEST.player);assert(#TEST.sent==sent)
TEST.time=10420;TEST.x=1.3;C.update(TEST.player);assert(#TEST.sent==sent) -- stale delta
TEST.time=10440;TEST.x=1.4;C.update(TEST.player);assert(#TEST.sent==sent+1)
sent=#TEST.sent;C.lastTouch=nil;TEST.running=false
TEST.time=10460;TEST.x=1.5;C.update(TEST.player);assert(#TEST.sent==sent) -- walking
TEST.running=true;C.ball(1).h=.01;TEST.time=10480;TEST.x=1.6;C.update(TEST.player);assert(#TEST.sent==sent)
C.ball(1).h=0;TEST.buttons[0]=true;TEST.time=10500;TEST.x=1.7;C.update(TEST.player);assert(#TEST.sent==sent)
TEST.buttons[0]=false;TEST.time=10520;TEST.x=1.9;C.update(TEST.player);assert(#TEST.sent==sent) -- no contact
TEST.x=1.1;TEST.running=false;TEST.sprinting=true;C.moveSample=nil;C.update(TEST.player)
TEST.time=10540;TEST.y=1.1;C.update(TEST.player)
assert(TEST.sent[#TEST.sent].command=="dribble" and TEST.sent[#TEST.sent].args.dx==0 and TEST.sent[#TEST.sent].args.dy==1)
local contact=state(11);contact.balls[1].kickSerial=2;contact.balls[1].kicker='test';contact.balls[1].dribble=true
C.receive('state',contact);assert(TEST.motions==1)
local goal=state(12,2);goal.balls[1].match={phase='goal'};TEST.time=10700
C.receive('state',goal);assert(C.positions()[1].x==2 and not C.ready())
local restart=state(13,1);restart.balls[1].match={phase='play'};TEST.time=10750
C.receive('state',restart);assert(C.positions()[1].x==1)
print("PASS client charge, cancellation, UI gates, interpolation and detached proxy")
-- Acquisition follows displayed/latest positions; attempts are not accepted touches.
C.leave();C.selected=1;TEST.running=true;TEST.sprinting=false;TEST.moving=false
TEST.x=1;TEST.y=1;TEST.time=20000;C.lastSync=TEST.time
C.receive('state',state(20,1));C.update(TEST.player)
TEST.time=20020;TEST.x=1.05
C.receive('state',state(21,4));C.update(TEST.player)
assert(TEST.sent[#TEST.sent].command=='dribble','visible contact may request against newer distant sample')
assert(C.lastTouch==nil,'request must not spend accepted-touch cooldown')
TEST.time=20120;TEST.x=2.5;C.moveSample={x=2.4,y=1,z=0,at=20100}
local attemptCount=#TEST.sent
C.update(TEST.player)
assert(#TEST.sent==attemptCount+1,'approach retries in100ms despite1.4sample-ready boundary')
local ack=state(22,2.6);ack.balls[1].kickSerial=9;ack.balls[1].kicker='test';ack.balls[1].dribble=true
C.receive('state',ack);assert(C.lastTouch==TEST.time)
TEST.time=20220;TEST.x=2.7;C.moveSample={x=2.6,y=1,z=0,at=20200}
attemptCount=#TEST.sent;C.update(TEST.player);assert(#TEST.sent==attemptCount,'accepted touch suppresses further retries')
TEST.time=20520;TEST.x=2.8;C.moveSample={x=2.7,y=1,z=0,at=20500}
C.update(TEST.player);assert(#TEST.sent==attemptCount+1,'accepted cooldown expires after400ms')
C.lastTouch=nil;C.lastDribbleRequest=nil;TEST.time=25000;C.lastSync=TEST.time
TEST.x=2.9;C.moveSample={x=2.8,y=1,z=0,at=24980}
attemptCount=#TEST.sent;C.update(TEST.player);assert(#TEST.sent==attemptCount,'stale state never requests contact')
print('PASS dribble acquisition, retries, accepted acknowledgment and freshness')
