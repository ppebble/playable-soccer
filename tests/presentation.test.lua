local P=PSProjection
local x,y=P.screenToWorld(0,50,60,0)
check(x==5 and y==6,"default world conversion")
Viewpoint={Mouse={}}
check(not P.available() and P.screenToWorld(0,1,1,0)==nil,"unknown camera fails closed")
check(not P.register({screenToWorld=function() end}),"incomplete camera adapter rejected")
check(P.register({screenToWorld=function() return 20,30 end,worldToScreen=function() return 200,300 end}),"complete camera adapter accepted")
x,y=P.screenToWorld(0,1,1,0);check(x==20 and y==30,"camera adapter world result")
x,y=P.worldToScreen(0,1,1,0);check(x==200 and y==300,"camera adapter screen result")
P.register({screenToWorld=function() error("bad camera") end,worldToScreen=function() return 0/0,1 end})
check(P.screenToWorld(0,1,1,0)==nil and P.worldToScreen(0,1,1,0)==nil,"invalid camera no fallback")
P.register(nil)
PSSetup.begin(1);check(not PSSetup.active(),"no placement under unsupported camera")
Viewpoint=nil
PSSetup.begin(1);check(PSSetup.active(),"start two goal-line placement")
TEST.blocked=true;PSSetup.click(0);check(#PSSetup.pending.points==0,"UI click not placed")
TEST.blocked=false
TEST.mx=10;TEST.my=20;PSSetup.click(0)
TEST.mx=11;PSSetup.click(0)
check(#PSSetup.pending.points==1 and #TEST.commands==0,"short goal line retries endpoint")
TEST.mx=50;PSSetup.click(0)
TEST.my=120;PSSetup.click(0)
TEST.mx=10;PSSetup.click(0)
check(PSSetup.active() and PSSetup.pending.submitted and #TEST.commands==1,"fourth point waits for server")
PSSetup.click(0);check(#TEST.commands==1,"waiting cannot duplicate submit")
PSSetup.receive("state",{});check(PSSetup.active(),"old state cannot complete setup")
PSSetup.receive("notice",{key="UI_PS_GoalsReady"})
PSSetup.receive("state",{});check(not PSSetup.active() and PSClient.selected==1,"accepted setup resumes controls")
local sent=TEST.commands[1]
check(sent.command=="configure" and sent.args.goalA.ax==1 and sent.args.goalB.bx==1 and sent.args.center.x==3 and sent.args.center.y==7,"goal lines and automatic midpoint sent")
PSSetup.begin(1);PSSetup.click(1);check(not PSSetup.active() and PSClient.selected==1,"right cancel resumes play")
PSSetup.begin(1);PSSetup.pending.submitted=TEST.time
PSSetup.receive("notice",{key="UI_PS_GoalsInvalid"})
check(PSSetup.active() and not PSSetup.pending.submitted and #PSSetup.pending.points==0,"rejected placement retries directly")
PSSetup.pending.submitted=TEST.time;TEST.time=TEST.time+5001;PSSetup.update()
check(PSSetup.active() and not PSSetup.pending.submitted,"lost reply allows retry")
PSSetup.cancel();TEST.time=1000
PSClient.selected=1;PSClient.charge={at=775,lob=true};PSClient.message="hello";PSClient.messageUntil=2000
PSHUD.render(TEST.panel,PSClient)
local title,bar,message=false,false,false
for _,t in ipairs(TEST.texts) do
    if t.text=="UI_PS_Practice" then title=t.x==640 and t.y==30 end
    if t.text=="hello" then message=t.x==640 and t.y==178 end
end
bar=TEST.bar.x==490 and TEST.bar.y==95 and TEST.bar.w==300 and TEST.bar.power==.5
check(title and message,"title and message twelve o'clock")
check(bar,"half-charge visible at top center")
PSClient.charge.at=TEST.time-450;PSHUD.render(TEST.panel,PSClient)
check(TEST.bar.power==1 and TEST.bar.color.r==1,"full charge uses maximum color")
PSClient.charge.at=TEST.time-9000;PSHUD.render(TEST.panel,PSClient)
check(TEST.bar.power==1,"holding beyond maximum never overfills")
PSClient.charge.lob=false;PSClient.charge.at=TEST.time-360;TEST.texts={}
PSHUD.render(TEST.panel,PSClient)
local lifted=false
for _,t in ipairs(TEST.texts) do if string.find(t.text,"UI_PS_LowShot",1,true) then lifted=true end end
check(lifted,"left kick at eighty percent is labeled as a lifted shot")
PSClient.charge=nil;PSHUD.render(TEST.panel,PSClient)
check(TEST.bar.power==0,"idle gauge remains visible empty")
TEST.draws={};TEST.ball.h=.6
PSHUD.render(TEST.panel,PSClient)
local floorShadow,airGuide=false,false
for _,d in ipairs(TEST.draws) do
    if math.abs(d.y-50)<2 and d.x<50 and d.x+d.w>50 then
        floorShadow=true;check(d.w<=14,"shadow diameter stays small")
    end
    if d.x==49 and d.y<44 and d.w==2 then airGuide=true end
end
check(floorShadow and not airGuide,"airborne ball has only a small floor shadow")
TEST.ball.h=0
TEST.draws={};PSHUD.render(TEST.panel,PSClient)
for _,d in ipairs(TEST.draws) do
    check(not (math.abs(d.y-50)<2 and d.x<50 and d.x+d.w>50),"grounded ball has no added shadow")
end
TEST.ball.match={scoreA=2,scoreB=1,phase="goal",lastScoringTeam="A",goals={}}
TEST.texts={};PSHUD.render(TEST.panel,PSClient)
check(TEST.texts[1].text=="A  2  :  1  B" and TEST.texts[2].text=="UI_PS_GoalA","score and goal message")
PSClient.selected=nil
local menu={options={}}
function menu:addOption(label,target,fn) self.options[label]={target=target,fn=fn} end
PSSetup.menu(0,menu,PSClient)
check(menu.options.UI_PS_TeamB~=nil,"team menu reachable after leaving mouse capture")
local option=menu.options.UI_PS_TeamB;option.fn(option.target)
check(PSClient.selected==1 and TEST.commands[#TEST.commands].args.team=="B","team selection resumes controls")

TEST.ball.match.phase="play"
TEST.ball.possession={kind="player",key="owner"};TEST.texts={};TEST.draws={}
PSHUD.render(TEST.panel,PSClient)
local holder=false
for _,entry in ipairs(TEST.texts) do if entry.text=="UI_PS_Possessionowner" then holder=true end end
check(holder,"server holder name displayed")
local normalDraws=#TEST.draws
-- Legacy development state cannot expose test decorations or virtual owners.
TEST.ball.match.testZones={tackle={x=1,y=3,r=1.25},keeper={x=9,y=3,r=1.25},
    shooter={x=8,y=4,r=.9},passer={x=2,y=0,r=.9}}
for _,key in ipairs({"keeper","shooter","passer"}) do
    TEST.ball.possession={kind="zone",key=key};TEST.texts={};TEST.draws={}
    PSHUD.render(TEST.panel,PSClient)
    local free=false
    for _,entry in ipairs(TEST.texts) do
        check(not string.find(entry.text,"Zone") and not string.find(entry.text,"Possession"),"no test zone or simulated owner label")
        if entry.text=="UI_PS_FreeBall" then free=true end
    end
    check(free and #TEST.draws==normalDraws,"legacy zones add no decoration or virtual owner status")
end
TEST.ball.possession=nil

-- Solo practice needs only one line and uses the captured starting position.
TEST.commands={};TEST.ball.match=nil
PSSetup.begin(1,"practice")
check(PSSetup.pending.mode=="practice" and PSSetup.pending.center.x==5,"practice stores restart anchor at setup start")
TEST.mx=10;TEST.my=10;PSSetup.click(0)
check(#PSSetup.pending.points==1 and PSClient.message=="UI_PS_PracticePlace2","practice prompts for second endpoint")
TEST.mx=50;PSSetup.click(0)
local practice=TEST.commands[1]
check(#TEST.commands==1 and PSSetup.pending.submitted,"one line submits practice after two clicks")
check(practice.args.mode=="practice" and practice.args.goalB==nil and practice.args.center.x==5 and practice.args.center.y==5,"practice sends one goal and original restart position")
PSSetup.receive("notice",{key="UI_PS_PracticeGoalsInvalid"})
check(not PSSetup.pending.submitted and #PSSetup.pending.points==0,"practice rejection allows redraw")
TEST.mx=10;PSSetup.click(0);TEST.mx=50;PSSetup.click(0)
PSSetup.receive("notice",{key="UI_PS_PracticeReady"});PSSetup.receive("state",{})
check(not PSSetup.active(),"practice acknowledgment resumes controls")
TEST.ball.match={mode="practice",scoreA=8,scoreB=0,phase="play",goals={A={ax=1,ay=1,bx=5,by=1}}}
PSClient.selected=1;TEST.texts={};PSHUD.render(TEST.panel,PSClient)
check(TEST.texts[1].text=="UI_PS_PracticeScore8","solo goal count supports more than five goals without team scoreboard")
local unlimited=false
for _,entry in ipairs(TEST.texts) do if entry.text=="UI_PS_PracticeRule" then unlimited=true end end
check(unlimited,"practice explicitly shows manual ending rule")
menu.options={};PSSetup.menu(0,menu,PSClient)
check(not menu.options.UI_PS_TeamA and not menu.options.UI_PS_TeamB and menu.options.UI_PS_ConfigurePracticeGoal,"practice hides team selection and offers one-goal setup")
TEST.ball.match={mode="match",scoreA=5,scoreB=2,phase="finished",winner="A",goals={}}
TEST.texts={};PSHUD.render(TEST.panel,PSClient)
check(TEST.texts[1].text=="A  5  :  2  B" and TEST.texts[2].text=="UI_PS_MatchFinishedA","finished match shows final score and winner")
local five=false
for _,entry in ipairs(TEST.texts) do if entry.text=="UI_PS_FirstToFive" then five=true end end
check(five,"competitive HUD shows five-goal rule")
