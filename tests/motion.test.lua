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
