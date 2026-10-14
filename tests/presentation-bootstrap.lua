function require() end
checks=0
function check(ok,msg) checks=checks+1;assert(ok,msg) end
TEST={commands={},time=1000,draws={},texts={}}
function getTimestampMs() return TEST.time end
function getCore() return {getScreenWidth=function() return 1280 end} end
function screenToIsoX(i,x,y,z) return x/10 end
function screenToIsoY(i,x,y,z) return y/10 end
function isoToScreenX(i,x,y,z) return x*10 end
function isoToScreenY(i,x,y,z) return y*10-z*40 end
function getMouseX() return TEST.mx or 50 end
function getMouseY() return TEST.my or 50 end
function getText(key,arg) return key..(arg and tostring(arg) or "") end
UIFont={Small=1,Large=2}
TEST.player={getUsername=function() return "owner" end,getX=function() return 5 end,getY=function() return 5 end,getZ=function() return 0 end}
function getSpecificPlayer() return TEST.player end
function getCell() return {getGridSquare=function() return {isCanSee=function() return true end} end} end
TEST.ball={id=1,owner="owner",x=5,y=5,z=0,h=0}
PSClient={state={balls={TEST.ball}},selected=1}
function PSClient.ball(id) if id==1 then return TEST.ball end end
function PSClient.positions() return {TEST.ball} end
function PSClient.leave() PSClient.selected=nil;PSSetup.cancel() end
function PSClient.notice(key) PSClient.message=key;PSClient.messageUntil=TEST.time+5000 end
function PSClient.blocked() return TEST.blocked end
function PSClient.send(command,args) TEST.commands[#TEST.commands+1]={command=command,args=args} end
TEST.panel={drawRect=function(self,x,y,w,h,a,r,g,b) TEST.draws[#TEST.draws+1]={x=x,y=y,w=w,h=h} end,
drawProgressBar=function(self,x,y,w,h,f,color) TEST.bar={x=x,y=y,w=w,h=h,power=f,color=color} end,
drawTextCentre=function(self,text,x,y) TEST.texts[#TEST.texts+1]={text=text,x=x,y=y} end}
