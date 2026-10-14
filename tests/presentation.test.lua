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
PSSetup.begin(1);check(PSSetup.active(),"start five-point placement")
TEST.blocked=true;PSSetup.click(0);check(#PSSetup.pending.points==0,"UI click not placed")
TEST.blocked=false
for i=1,5 do TEST.mx=i*10;TEST.my=i*20;PSSetup.click(0) end
check(not PSSetup.active() and #TEST.commands==1,"single submit after fifth point")
local sent=TEST.commands[1]
check(sent.command=="configure" and sent.args.goalA.ax==1 and sent.args.goalB.bx==4 and sent.args.center.x==5,"world coordinates sent")
PSSetup.begin(1);PSSetup.click(1);check(not PSSetup.active(),"right cancel")
PSClient.selected=1;PSClient.charge={at=550,lob=true};PSClient.message="hello";PSClient.messageUntil=2000
PSHUD.render(TEST.panel,PSClient)
local title,bar,message=false,false,false
for _,t in ipairs(TEST.texts) do
    if t.text=="UI_PS_Practice" then title=t.x==640 and t.y==30 end
    if t.text=="hello" then message=t.x==640 and t.y==148 end
end
for _,d in ipairs(TEST.draws) do if d.x==520 and d.y==95 and d.w==120 then bar=true end end
check(title and message,"title and message twelve o'clock")
check(bar,"half-charge visible at top center")
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
