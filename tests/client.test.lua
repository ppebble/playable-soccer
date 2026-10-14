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
C.keyPressed(Keyboard.KEY_ESCAPE);assert(C.menu and C.selected==1 and not TEST.banned and C.blocked())
C.keyPressed(Keyboard.KEY_ESCAPE);assert(not C.menu and C.selected==1)
C.leave()
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
-- A match start is a setup transition only after its authoritative ball exists.
C.leave();C.start(TEST.player,item,'match');assert(C.pendingMode=='match' and not C.selected)
C.receive('state',state(30));assert(TEST.setup==1 and not C.selected and not C.pendingMode)
assert(TEST.setupReceived=='state')
C.leave();assert(not TEST.setup)
-- Synchronous singleplayer start acknowledgments must use the same ordering.
local oldClient=isClient
function isClient() return false end
PSServer={command=function(p,command,args) assert(command=='start');C.receive('state',state(31)) end}
C.start(TEST.player,item,'match');assert(TEST.setup==1 and not C.selected and not C.pendingItem)
isClient=oldClient;PSServer=nil;C.leave()
TEST.x=1;TEST.y=1;TEST.dead=false;TEST.typing=false
local match=state(32);match.balls[1].match={phase='play'}
C.receive('state',match);C.selected=1;C.update(TEST.player);C.charge={}
C.openMenu();assert(C.menu and not C.guard and not C.charge and C.blocked())
local function option(menu,key)
    for _,o in ipairs(menu.options) do if o.label==key then return o end end
end
assert(option(C.menu,'UI_PS_ResetBall') and option(C.menu,'UI_PS_ConfigureGoals') and option(C.menu,'UI_PS_StopBall'))
local team=option(C.menu,'UI_PS_TeamB');team.callback(team.target)
assert(not C.menu and TEST.sent[#TEST.sent].command=='team' and TEST.sent[#TEST.sent].args.team=='B')
C.openMenu();local resume=option(C.menu,'UI_PS_Resume');resume.callback();assert(not C.menu and C.selected==1)
C.ball(1).owner='someone';C.openMenu()
assert(not option(C.menu,'UI_PS_StopBall') and not option(C.menu,'UI_PS_ResetBall'))
local leave=option(C.menu,'UI_PS_LeaveBall');leave.callback();assert(not C.menu and not C.selected)
local nearby=ISContextMenu.get();C.joinMenu(nearby);assert(#nearby.options==2)
nearby.options[2].callback();assert(C.selected==1 and TEST.sent[#TEST.sent].args.team=='B')
C.openMenu();C.menu:hideAndChildren();C.update(TEST.player);assert(not C.menu,'outside-dismissed menu releases soccer block')
C.openMenu();Events.OnPlayerDeath.callback(TEST.player);assert(not C.menu and not C.selected)
print('PASS match start state ordering, SP reentrancy, soccer menu ownership/teams and cleanup')
-- Registration is a heartbeat, never a client-authored possession or auto kick.
TEST.time=40000;TEST.x=1;TEST.y=1;TEST.running=true;TEST.moving=true
C.receive('state',state(40));C.selected=1;C.lastSync=TEST.time;C.update(TEST.player)
assert(TEST.sent[#TEST.sent].command=='control' and TEST.sent[#TEST.sent].args.active==true)
local count=#TEST.sent;TEST.time=40500;TEST.x=1.1;C.update(TEST.player);assert(#TEST.sent==count)
TEST.time=41000;C.update(TEST.player);assert(#TEST.sent==count+1 and TEST.sent[#TEST.sent].command=='control')
C.openMenu();assert(TEST.sent[#TEST.sent].command=='control' and TEST.sent[#TEST.sent].args.active==false)
C.closeMenu();C.update(TEST.player);assert(TEST.sent[#TEST.sent].args.active==true)
for _,packet in ipairs(TEST.sent) do assert(packet.command~='dribble','legacy automatic dribble must not be sent') end
local b=C.ball(1);b.possession={kind='player',key='other'}
assert(not C.ready());C.mouseDown();assert(not C.charge)
b.possession={kind='zone',key='keeper'};assert(not C.ready())
b.possession={kind='player',key='test'};assert(C.ready())
b.possession=nil;assert(C.ready())
local heldState=state(41,1.2);heldState.balls[1].possession={kind='player',key='test'}
C.receive('state',heldState);assert(C.positions()[1].x==1.2,'new holder snaps to authoritative position')
TEST.time=TEST.time+100
local followingHeld=state(42,1.3);followingHeld.balls[1].possession={kind='player',key='test'}
C.receive('state',followingHeld);assert(C.positions()[1].x==1.2,'same holder keeps interpolation')
TEST.time=TEST.time+50;assert(C.positions()[1].x>1.2 and C.positions()[1].x<1.3,'same holder moves smoothly between samples')
b=C.ball(1);b.possession=nil
-- Tackle follows the cursor and is locally rate limited; possession remains server-owned.
local ui=C.overlay;local space=Keyboard.KEY_SPACE;TEST.keys={[space]=true}
ui:onKeyPress(space);assert(ui:isKeyConsumed(space) and TEST.sent[#TEST.sent].command=='tackle')
assert(TEST.sent[#TEST.sent].args.dx==1 and TEST.sent[#TEST.sent].args.dy==0 and b.possession==nil,'far cursor sends normalized server-compatible direction')
count=#TEST.sent;ui:onKeyPress(space);assert(#TEST.sent==count)
C.openMenu();assert(TEST.banned,'opening menu cannot leak held native shove')
C.leave();assert(TEST.banned,'leaving while Space held retains only press-scoped ban')
TEST.keys[space]=false;ui:onKeyRelease(space);assert(ui:isKeyConsumed(space) and not TEST.banned,'release restores prior ban while UI press remains consumed')
ui:onKeyPress(space);assert(not ui:isKeyConsumed(space),'next ordinary space returns to shove')
C.selected=1;TEST.time=42000;C.receivedAt=TEST.time;C.update(TEST.player)
C.receive('tackled',{id=1,serial=1});assert(TEST.falls==1 and C.message=='UI_PS_Tackled' and not C.controlId and C.blocked())
C.receive('tackled',{id=1,serial=1});C.receive('tackled',{id=1,serial=0});assert(TEST.falls==1)
C.receive('tackled',{id=1,serial=0/0});assert(TEST.falls==1)
count=#TEST.sent;ui:onKeyPress(space);assert(ui:isKeyConsumed(space) and not C.ready() and #TEST.sent==count,'recovery consumes Space without tackling')
ui:onKeyRelease(space)
TEST.time=43500;TEST.down=true;C.receivedAt=TEST.time;assert(C.blocked())
TEST.down=false;TEST.gettingUp=true;assert(C.blocked());TEST.gettingUp=false
TEST.onFloor=true;assert(C.blocked());TEST.onFloor=false
C.update(TEST.player);assert(C.controlId==1)
TEST.typing=true;C.update(TEST.player);assert(not C.controlId);TEST.typing=false
C.update(TEST.player);TEST.noProjection=true;C.update(TEST.player);assert(not C.controlId);TEST.noProjection=false
C.leave();assert(not C.controlId)
C.selected=1;C.receivedAt=TEST.time;TEST.keys[space]=true;ui:onKeyPress(space);C.leave();assert(TEST.banned)
TEST.keys[space]=false;C.update(TEST.player);assert(not C.spaceGuard and not TEST.banned,'lost release recovered by raw key polling')
C.selected=1;TEST.keys[space]=true;ui:onKeyPress(space);Events.OnPlayerDeath.callback(TEST.player)
assert(not C.spaceGuard and not TEST.banned,'death restores press-scoped ban')
C.selected=1;C.openMenu();count=#TEST.sent;TEST.keys[space]=true;ui:onKeyPress(space)
assert(ui:isKeyConsumed(space) and TEST.banned and #TEST.sent==count,'new Space press in soccer menu blocks shove without tackle')
TEST.keys[space]=false;ui:onKeyRelease(space);assert(not TEST.banned)
C.leave();TEST.setup=true;TEST.keys[space]=true;ui:onKeyPress(space)
assert(ui:isKeyConsumed(space) and TEST.banned and #TEST.sent==count,'setup consumes Space without tackle')
TEST.keys[space]=false;ui:onKeyRelease(space);C.leave();ui:onKeyPress(space)
assert(not ui:isKeyConsumed(space) and not TEST.banned,'Space outside soccer remains native')
C.selected=1;TEST.typing=true;ui:onKeyPress(space)
assert(not ui:isKeyConsumed(space) and not TEST.banned,'text entry Space remains untouched');TEST.typing=false;C.leave()
print('PASS possession ownership, control heartbeat/cleanup, tackle latch and direct local fall deduplication')
-- Mere UI hover never releases participation, while action inputs stay gated.
TEST.time=50000;C.receive('state',state(50));C.selected=1;C.lastSync=TEST.time;C.update(TEST.player)
assert(C.controlId==1)
TEST.uis={{isVisible=function() return true end,isConsumeMouseEvents=function() return true end,isPointOver=function() return true end}}
count=#TEST.sent;TEST.time=50100;C.update(TEST.player)
assert(C.controlId==1 and #TEST.sent==count,'hover while running must not release server possession')
C.mouseDown();C.rightDown();C.tackle()
assert(not C.charge and #TEST.sent==count,'hover still blocks kick/lob/tackle intents')
TEST.time=51000;C.update(TEST.player)
assert(C.controlId==1 and TEST.sent[#TEST.sent].command=='control' and TEST.sent[#TEST.sent].args.active==true,'heartbeat survives hover')
TEST.uis={};C.update(TEST.player);assert(C.controlId==1)
C.openMenu();assert(not C.controlId and TEST.sent[#TEST.sent].args.active==false)
C.closeMenu();C.update(TEST.player);assert(C.controlId==1)
TEST.drag=true;C.update(TEST.player);assert(not C.controlId,'drag remains blocking');TEST.drag=nil
C.update(TEST.player);TEST.queue={{}};C.update(TEST.player);assert(not C.controlId,'unrelated action remains blocking');TEST.queue={}
C.update(TEST.player);C.ball(1).z=1;C.update(TEST.player);assert(not C.controlId,'floor changes release registration');C.ball(1).z=0
C.update(TEST.player);C.leave();assert(not C.controlId and TEST.sent[#TEST.sent].args.active==false)
print('PASS stable hover participation, gated actions and explicit release boundaries')
