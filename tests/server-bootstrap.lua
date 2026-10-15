ServerMock={time=10000,players={},packets={},squares={},mp=true}
local M=ServerMock
local function list(t) return {size=function() return #t end,get=function(_,i) return t[i+1] end} end
function isClient() return false end
function isServer() return M.mp end
function require(name) assert(name=='PS_Core' or name=='PS_Match') end
function getTimestampMs() return M.time end
function getOnlinePlayers() return list(M.players) end
function getSpecificPlayer(i) return M.players[i+1] end
function sendServerCommand(p,module,command,args)
    assert(module=='PlayableSoccer'); M.packets[#M.packets+1]={p=p,command=command,args=args}
end
PSClient={receive=function(command,args) M.packets[#M.packets+1]={command=command,args=args,sp=true} end}
Events={OnTick={Add=function(f) M.tick=f end},OnClientCommand={Add=function(f) M.command=f end}}
function M.square(x,y,z)
    local key=x..':'..y..':'..z
    if not M.squares[key] then
        M.squares[key]={x=x,y=y,z=z,floor=true,
            TreatAsSolidFloor=function(self) return self.floor end,
            isSolid=function(self) return self.solid or false end,
            isSolidTrans=function(self) return self.trans or false end,
            isBlockedTo=function(self,other)
                return self.blocked or other.blocked or (M.wall and M.wall(self,other)) or false
            end}
    end
    return M.squares[key]
end
function getCell() return {getGridSquare=function(_,x,y,z)
    if M.unloaded or (M.missing and M.missing(x,y,z)) then return nil end
    return M.square(x,y,z)
end} end
function M.item(id,kind)
    return {getID=function() return id end,getFullType=function() return kind or 'PlayableSoccer.SportsSoccerBall' end}
end
function M.player(name,x,y,id)
    local p={name=name,x=x,y=y,z=0,items={M.item(id)}}
    function p:getUsername() return self.name end
    function p:getPlayerNum() return 0 end
    function p:getX() return self.x end
    function p:getY() return self.y end
    function p:getZ() return self.z end
    function p:isDead() return self.dead end
    function p:isOnFloor() return self.onFloor end
    function p:isKnockedDown() return self.knockedDown end
    function p:getCurrentStateName() return self.stateName end
    function p:getVehicle() return self.vehicle end
    function p:isRunning() return self.running or false end
    function p:isSprinting() return self.sprinting or false end
    function p:isPlayerMoving() return self.moving or false end
    function p:getForwardDirectionX() return self.faceX or 1 end
    function p:getForwardDirectionY() return self.faceY or 0 end
    function p:getInventory() return {getItems=function() return list(self.items) end} end
    M.players[#M.players+1]=p
    return p
end
function M.send(p,c,args) M.time=M.time+600; M.command('PlayableSoccer',c,p,args or {}) end

Perks={Strength="Strength",Aiming="Aiming"}
function addXp(p,perk,amount) p.xp=p.xp or {};p.xp[perk]=(p.xp[perk] or 0)+amount end
