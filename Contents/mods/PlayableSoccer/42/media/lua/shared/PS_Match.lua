require 'PS_Core'
PSMatch={radius=.10,goalHeight=.8,pauseSeconds=2}
local M,C=PSMatch,PSCore
local function point(p)
    return type(p)=='table' and C.finite(p.x) and C.finite(p.y)
        and math.abs(p.x)<=100000 and math.abs(p.y)<=100000
end
local function side(g,x,y) return (x-g.ax)*g.nx+(y-g.ay)*g.ny end
local function goal(g,center)
    if type(g)~='table' or not point({x=g.ax,y=g.ay}) or not point({x=g.bx,y=g.by}) then return nil end
    local dx,dy=g.bx-g.ax,g.by-g.ay
    local width=math.sqrt(dx*dx+dy*dy)
    if width<2 or width>10 then return nil end
    local r={ax=g.ax,ay=g.ay,bx=g.bx,by=g.by,nx=-dy/width,ny=dx/width,width=width}
    local distance=side(r,center.x,center.y)
    if math.abs(distance)<2 then return nil end
    if distance<0 then r.nx=-r.nx; r.ny=-r.ny end
    return r
end
-- Coordinate-only contract: camera projection belongs exclusively to the client.
function M.configure(a,b,center)
    if not point(center) then return nil end
    local ga,gb=goal(a,center),goal(b,center)
    if not ga or not gb then return nil end
    -- Every opposite post must lie well inside the facing half-plane. This
    -- rejects intersecting/overlapping mouths and center-outside setups.
    if ga.nx*gb.nx+ga.ny*gb.ny>-.25
        or side(ga,gb.ax,gb.ay)<2 or side(ga,gb.bx,gb.by)<2
        or side(gb,ga.ax,ga.ay)<2 or side(gb,ga.bx,ga.by)<2 then return nil end
    for _,g in ipairs({ga,gb}) do
        for _,p in ipairs({{x=g.ax,y=g.ay},{x=g.bx,y=g.by}}) do
            if (p.x-center.x)^2+(p.y-center.y)^2>1600 then return nil end
        end
    end
    return {goals={A=ga,B=gb},center={x=center.x,y=center.y},scoreA=0,scoreB=0,teams={},crossings={},phase='play'}
end
function M.reset(ball)
    local match=ball.match
    if not match then return false end
    ball.x=match.center.x; ball.y=match.center.y
    ball.h=0; ball.vx=0; ball.vy=0; ball.vz=0
    match.phase='play'; match.resetAt=nil; match.lastScoringTeam=nil; match.crossings={}
    return true
end
local function crossed(g,ball,x,y,h,entries,key)
    local from,to=side(g,x,y),side(g,ball.x,ball.y)
    local radius=M.radius
    local function fits(t)
        local cx,cy=x+(ball.x-x)*t,y+(ball.y-y)*t
        local along=((cx-g.ax)*(g.bx-g.ax)+(cy-g.ay)*(g.by-g.ay))/g.width
        local height=h+(ball.h-h)*t
        return along>=radius and along<=g.width-radius and height>=0
            and height+radius*2/C.tilesPerFloor<=M.goalHeight
    end
    if to>=0 then entries[key]=nil end
    -- A partial crossing remains eligible only while it stays inside the
    -- mouth, including height. Leaving then re-entering behind the line
    -- cannot restore an entry without a fresh field-side crossing.
    if entries[key] and from<0 and (not fits(0) or not fits(1)) then entries[key]=nil end
    -- Remember a valid field-to-goal entry across substeps. A ball that passes
    -- outside a post then moves sideways behind it must never become a goal.
    if from>=0 and to<0 then entries[key]=fits(-from/(to-from)) end
    if from<=-radius or to>-radius or to>=from then return false end
    local result=entries[key] and fits((-radius-from)/(to-from))
    entries[key]=nil
    return result==true
end
function M.segment(ball,x,y,h,time)
    local match=ball.match
    if not match or match.phase~='play' then return false end
    for _,defender in ipairs({'A','B'}) do
        if crossed(match.goals[defender],ball,x,y,h,match.crossings,defender) then
            local scorer=defender=='A' and 'B' or 'A'
            match['score'..scorer]=match['score'..scorer]+1
            match.phase='goal'; match.lastScoringTeam=scorer; match.resetAt=time+M.pauseSeconds
            ball.vx=0; ball.vy=0; ball.vz=0
            return true
        end
    end
    return false
end
