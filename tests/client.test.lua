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
assert(TEST.banned)
TEST.buttons[0]=true;C.mouseDown();TEST.buttons[1]=true;C.update(TEST.player);assert(not C.charge)
TEST.buttons[1]=false
TEST.typing=true;C.mouseDown();C.update(TEST.player);assert(not C.charge and not TEST.banned)
TEST.typing=false;TEST.paused=true;C.mouseDown();assert(not C.charge);TEST.paused=false
TEST.uis={{isVisible=function() return true end,isConsumeMouseEvents=function() return true end,isPointOver=function() return true end}}
C.mouseDown();assert(not C.charge);TEST.uis={}
TEST.queue={true};C.mouseDown();assert(not C.charge);TEST.queue={}
TEST.drag=true;C.mouseDown();assert(not C.charge);TEST.drag=nil
TEST.time=1500;C.receive("state",state(2,2))
TEST.time=1625;local pos=C.positions()[1];assert(pos.x>1 and pos.x<2)
C.receive("state",state(1,99));assert(C.ball(1).x==2)
PSRender.draw(C.positions());assert(TEST.renders==1 and TEST.lastItem~=item and TEST.lastItem.type=="PlayableSoccer.SportsSoccerBall")
assert(PSRender.proxies[1])
PSRender.draw({});assert(not PSRender.proxies[1])
-- Moving out of reach restores the prior attack policy, without deleting ball.
C.receive("state",state(3,8));C.update(TEST.player);assert(not TEST.banned and C.ball(1))
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
C.overlay:prerender() -- No draw methods provided: a background draw would fail.
TEST.no3D=true
C.start(TEST.player,item);assert(not C.pendingItem and C.message=="UI_PS_RenderError")
assert(PSRender.draw({{id=1,x=1,y=1,z=0,h=0}})==false)
TEST.no3D=false
print("PASS client charge, cancellation, UI gates, interpolation and detached proxy")
