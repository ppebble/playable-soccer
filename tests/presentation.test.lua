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
TEST.ball.match.testZones={tackle={x=1,y=3,r=1.25},keeper={x=9,y=3,r=1.25}}
TEST.ball.possession={kind="zone",key="keeper"}
TEST.texts={};TEST.draws={};PSHUD.render(TEST.panel,PSClient)
local tackleZone,keeperZone,zoneOwner=false,false,false
for _,entry in ipairs(TEST.texts) do
    if entry.text=="UI_PS_TackleZone" then tackleZone=true end
    if entry.text=="UI_PS_KeeperZone" then keeperZone=true end
    if entry.text=="UI_PS_ZonePossession" then zoneOwner=true end
end
check(tackleZone and keeperZone and zoneOwner,"both world zones and simulated possession labeled")
check(#TEST.draws>=98,"both zone perimeters rendered without interactive UI panels")
TEST.ball.possession={kind="player",key="owner"};TEST.texts={}
PSHUD.render(TEST.panel,PSClient)
local holder=false
for _,entry in ipairs(TEST.texts) do if entry.text=="UI_PS_Possessionowner" then holder=true end end
check(holder,"server holder name displayed")

TEST.ball.match.testZones.shooter={x=8,y=4,r=.9}
TEST.ball.possession={kind="zone",key="shooter"};TEST.texts={}
PSHUD.render(TEST.panel,PSClient)
local shotZone,shotOwner=false,false
for _,entry in ipairs(TEST.texts) do
    if entry.text=="UI_PS_ShooterZone" then shotZone=true end
    if entry.text=="UI_PS_ShooterPossession" then shotOwner=true end
end
check(shotZone and shotOwner,"goal B shot zone and pending shot labeled")
