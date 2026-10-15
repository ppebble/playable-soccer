assert(not PSMotion.play(nil,false,1,0))
TEST.localPlayer=false;assert(not PSMotion.play(TEST.player,false,1,0));TEST.localPlayer=true
for _,field in ipairs({'dead','vehicle','moving'}) do
    TEST[field]=true;assert(not PSMotion.play(TEST.player,false,1,0));TEST[field]=nil
end
assert(PSMotion.play(TEST.player,false,1,0))
local action=TEST.queue.queue[1]
assert(not PSMotion.play(TEST.player,true,0,1)) -- never displace another queued action
action.action=TEST.native;action:start()
assert(TEST.anim=='PS_KickGesture' and TEST.bar==false and TEST.block==false)
assert(action.maxTime==32 and action:adjustMaxTime(32)==32)
assert(action.stopOnWalk and action.stopOnRun and action.stopOnAim)
assert(action.stop==ISBaseTimedAction.stop and action.perform==ISBaseTimedAction.perform)
assert(action.complete==nil) -- retain native B42 remote animation action path
action:animEvent('AttackCollisionCheck','Stomp') -- intentionally inert
TEST.moving=true;action:update();assert(TEST.stopped);TEST.moving=nil
action:stop();assert(#TEST.queue.queue==0)
assert(PSMotion.play(TEST.player,true,0,1))
local lob=TEST.queue.queue[1];lob.action=TEST.native;lob:start();assert(TEST.anim=='PS_KickGesture')
TEST.dead=true;TEST.stopped=false;lob:update();assert(TEST.stopped);TEST.dead=nil
lob:perform();assert(#TEST.queue.queue==0)
TEST.error=true;TEST.stopped=false;lob:start();assert(TEST.stopped)
print('PASS soccer cosmetic motion queue isolation, cancellation, inherited cleanup and error fallback')

assert(PSMotion.fall(motionPlayer))
assert(MOTION.knocked and not MOTION.front and not MOTION.behind)
assert(MOTION.running==false and MOTION.sprinting==false and MOTION.moving==false)
assert(PSMotion.isDown(motionPlayer))
assert(not PSMotion.fall(motionPlayer))
for _,flag in ipairs({"dead","vehicle","floor","locked","sitting","furniture","hit","fallRecovery"}) do
    MOTION={state="idle",localPlayer=true};MOTION[flag]=true
    assert(not PSMotion.fall(motionPlayer),flag)
    assert(MOTION.knocked==nil)
end
for _,state in ipairs({"climbfence","climbwindow","actions","falling","getup","onground","falldown"}) do
    MOTION={state=state,localPlayer=true}
    assert(not PSMotion.fall(motionPlayer),state)
end
MOTION={state="idle",localPlayer=false};assert(not PSMotion.fall(motionPlayer))
MOTION={state="getup",localPlayer=true};assert(PSMotion.isDown(motionPlayer))
MOTION={state="run",localPlayer=true};assert(PSMotion.fall(motionPlayer))
assert(not PSMotion.fall(nil) and not PSMotion.isDown(nil))
print("PASS local native knockdown request and competing-state guards; animation playback not run")
-- Tackle attempts animate even without a server hit, while locomotion is free.
TEST.error=nil;TEST.stopped=false;TEST.queue.queue={}
PSClient={selected=7,blocked=function() return MOTION.menu end}
MOTION={state='movement',localPlayer=true,running=true,moving=true}
assert(PSMotion.tackleMilliseconds==667)
assert(PSMotion.tackle(motionPlayer,3,4))
local tackle=TEST.queue.queue[1]
assert(getmetatable(tackle).__index==PS_TackleAction)
assert(tackle.ballId==7 and tackle.maxTime==20 and tackle:adjustMaxTime(20)==20)
assert(not tackle.stopOnWalk and not tackle.stopOnRun and not tackle.stopOnAim)
tackle.action=TEST.native;tackle:start()
assert(TEST.anim=='PS_PowerTackle' and TEST.block==false and TEST.bar==false)
assert(math.abs(MOTION.facing.x-10.6)<.00001 and math.abs(MOTION.facing.y-20.8)<.00001)
assert(MOTION.moving and MOTION.running) -- never stop or teleport the player
assert(tackle.complete==nil) -- Diagnostic wrappers delegate native cleanup below.
tackle:animEvent('AttackCollisionCheck','Shove')
tackle:update();assert(not TEST.stopped)
assert(not PSMotion.tackle(motionPlayer,1,0)) -- preserve existing queued action
for _,field in ipairs({'dead','vehicle','knocked','floor','hit','menu'}) do
    MOTION[field]=true;TEST.stopped=false;tackle:update();assert(TEST.stopped,field);MOTION[field]=nil
end
PSClient.selected=8;TEST.stopped=false;tackle:update();assert(TEST.stopped)
PSClient.selected=nil;assert(not tackle:isValid());PSClient.selected=7
tackle:stop();assert(#TEST.queue.queue==0)
assert(not PSMotion.tackle(motionPlayer,0,0))
assert(not PSMotion.tackle(motionPlayer,0/0,1))
assert(not PSMotion.tackle(motionPlayer,math.huge,1))
MOTION.localPlayer=false;assert(not PSMotion.tackle(motionPlayer,1,0));MOTION.localPlayer=true
assert(PSMotion.tackle(motionPlayer,1,0));tackle=TEST.queue.queue[1];tackle.action=TEST.native
TEST.error=true;TEST.stopped=false;tackle:start();assert(TEST.stopped);TEST.error=nil
tackle:perform();assert(#TEST.queue.queue==0)
print('PASS shoulder gesture queue, movement, cancellation, direction and inherited cleanup')
-- Animation selection uses only accepted normalized server power.
TEST.queue.queue={};TEST.error=nil;TEST.moving=nil;TEST.dead=nil;TEST.vehicle=nil;TEST.localPlayer=true
for _,case in ipairs({{power=.899,strong=false},{power=.9,strong=true},{power=1,strong=true},
    {power=-1,strong=false},{power=1.001,strong=false},{power=math.huge,strong=false},
    {power=0/0,strong=false},{power='1',strong=false},{strong=false}}) do
    for _,lob in ipairs({false,true}) do
        assert(PSMotion.play(TEST.player,lob,1,0,case.power))
        local kick=TEST.queue.queue[1];kick.action=TEST.native;kick:start()
        assert(TEST.anim==(case.strong and 'PS_StrongKickGesture' or 'PS_KickGesture'))
        assert(kick.maxTime==32 and kick.stopOnWalk==not case.strong and kick.stopOnRun==not case.strong and kick.stopOnAim)
        assert(kick.stop==ISBaseTimedAction.stop and kick.perform==ISBaseTimedAction.perform)
        kick:perform()
    end
end
print('PASS accepted-power strong/light variant boundaries and unchanged action cleanup')
TEST.moving=true
assert(not PSMotion.play(TEST.player,false,1,0,.899)) -- light behavior unchanged
assert(PSMotion.play(TEST.player,false,1,0,.9))
local movingStrong=TEST.queue.queue[1];movingStrong.action=TEST.native;movingStrong:start()
TEST.stopped=false;movingStrong:update()
assert(not TEST.stopped and TEST.block==false and TEST.anim=='PS_StrongKickGesture')
assert(not PSMotion.play(TEST.player,false,1,0,1)) -- never displace queued actions
movingStrong:perform();TEST.moving=nil
-- Soccer-only fall selection survives entry, clears on recovery/reset/timeout.
PSMotion.resetFalls()
MOTION={state='movement',localPlayer=true,time=1000}
assert(PSMotion.fall(motionPlayer) and MOTION.PS_SoccerFall)
PSMotion.updateFall(motionPlayer);assert(MOTION.PS_SoccerFall)
MOTION.state='knockeddown';PSMotion.updateFall(motionPlayer);assert(MOTION.PS_SoccerFall)
MOTION.state='getup';MOTION.knocked=false;PSMotion.updateFall(motionPlayer)
assert(not MOTION.PS_SoccerFall)
MOTION={state='idle',localPlayer=true,time=1000};assert(PSMotion.fall(motionPlayer))
MOTION.time=6001;PSMotion.updateFall(motionPlayer);assert(not MOTION.PS_SoccerFall)
MOTION={state='idle',localPlayer=true,time=1000};assert(PSMotion.fall(motionPlayer))
PSMotion.resetFalls();assert(not MOTION.PS_SoccerFall)
MOTION={state='idle',localPlayer=true,time=1000};assert(PSMotion.fall(motionPlayer))
MOTION.dead=true;PSMotion.updateFall(motionPlayer);assert(not MOTION.PS_SoccerFall)
print('PASS isolated soccer-fall selection lifecycle and recovery cleanup')
MOTION={state='idle',localPlayer=true};PSClient.selected=11;PSClient.blocked=function() return false end
TEST.queue.queue={};TEST.error=nil;PSMotion.tackleDiagnosticCount=0;MOTION_LOGS={}
assert(PSMotion.tackle(motionPlayer,1,0))
local diagnosticAction=TEST.queue.queue[1];diagnosticAction.action=TEST.native
diagnosticAction:start();diagnosticAction:update();diagnosticAction:update();diagnosticAction:perform()
assert(#MOTION_LOGS==4 and string.find(MOTION_LOGS[1],'queued') and string.find(MOTION_LOGS[2],'start')
    and string.find(MOTION_LOGS[3],'update action=PS_PowerTackle') and string.find(MOTION_LOGS[4],'perform'))
assert(string.find(MOTION_LOGS[1],'reason=-') and string.find(MOTION_LOGS[2],'reason=-'))
for i=2,6 do assert(not PSMotion.tackle(motionPlayer,0,0)) end
assert(#MOTION_LOGS==8) -- only first five attempts logged; no frame spam.
