local C=PSClient
local item={getID=function() return 17 end,getFullType=function() return "PlayableSoccer.SportsSoccerBall" end}
local ball={id=1,itemId=17,owner="test",x=1,y=1,z=0,h=0,vx=0,vy=0,vz=0}
local function state(rev) C.receive("state",{revision=rev,balls={ball}}) end
local function place()
    local points={{0,-2},{0,2},{10,-2},{10,2}}
    for _,pt in ipairs(points) do
        PSProjection.screenToWorld=function() return pt[1],pt[2] end
        C.mouseDown()
    end
end
C.start(TEST.player,item,"match");state(1)
assert(PSSetup.active() and not C.selected,"create match enters real setup directly")
place()
assert(PSSetup.pending.submitted and TEST.sent[#TEST.sent].command=="configure")
C.receive("notice",{key="UI_PS_GoalsInvalid"})
assert(PSSetup.active() and #PSSetup.pending.points==0,"invalid setup stays editable")
place()
C.receive("notice",{key="UI_PS_GoalsReady"})
ball.match={phase="play",teams={test="A"},goals={}}
state(2)
assert(not PSSetup.active() and C.selected==1,"ack enters match without Escape")
C.keyPressed(Keyboard.KEY_ESCAPE);assert(C.menu and C.blocked())
C.keyPressed(Keyboard.KEY_ESCAPE);assert(not C.menu and C.selected==1)
PSSetup.begin(1);C.keyPressed(Keyboard.KEY_ESCAPE)
assert(not PSSetup.active() and C.selected==1,"cancel redefinition resumes old game")
PSSetup.begin(1);C.leave()
assert(not PSSetup.active() and not C.selected,"explicit leave cannot restore setup selection")
-- Immediate singleplayer replies may arrive inside configure dispatch.
C.start(TEST.player,item,"match");state(3)
local network=sendClientCommand
function sendClientCommand(p,module,command,args)
    if command=="configure" then
        C.receive("notice",{key="UI_PS_GoalsReady"});state(4)
    else network(p,module,command,args) end
end
place()
assert(not PSSetup.active() and C.selected==1,"synchronous configure reply survives click return")
print("PASS integrated match creation, rejection/retry, Escape and synchronous setup response")
