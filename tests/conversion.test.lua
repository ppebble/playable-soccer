local player=Mock.player()
local original=Mock.item("Base.SoccerBall")
player.inventory:AddItem(original)
original.favorite=true; original.customName=true; original.name="Our ball"
original.customWeight=true; original.weight=1.2; original.mod.marker="keep"
player.primary=original
local action=PS_ConvertBall:new(player,original)
check(action:isValid(),"owned soccer ball valid")
check(action:complete(),"conversion succeeds")
local sports=player.primary
check(sports:getFullType()=="PlayableSoccer.SportsSoccerBall","dedicated FullType")
check(not player.inventory:contains(original) and player.inventory:contains(sports),"one replacement only")
check(sports.condition==3 and sports.conditionMax==5 and sports.repaired==2,"condition retained")
check(sports.favorite and sports.name=="Our ball" and sports.customName,"favorite name retained")
check(sports.weight==1.2 and sports.customWeight and sports.mod.marker=="keep","weight metadata retained")
check(not action:complete() and Mock.sent==1,"repeated completion cannot duplicate")
sports.active=true
check(not PS_ConvertBall:new(player,sports):complete(),"active game ball cannot convert")
sports.active=false
check(PS_ConvertBall:new(player,sports):complete(),"reverse conversion")
check(player.primary:getFullType()=="Base.SoccerBall" and player.primary.mod.marker=="keep","round trip")
local replacement=player.primary
local queued=PS_ConvertBall:new(player,replacement)
player.inventory:Remove(replacement)
check(not queued:complete(),"lost ownership rejected at completion")
player.inventory:AddItem(replacement)
Mock.failFactory=true
check(not PS_ConvertBall:new(player,replacement):complete() and player.inventory:contains(replacement),"factory failure preserves original")
Mock.failFactory=false
check(PS_ConvertBall.targetType(Mock.item("Throwing.SoccerBall"))==nil,"upstream throwing ball untouched")
check(PS_ConvertBall.targetType(Mock.item("Base.Baseball"))==nil,"other sports untouched")
replacement.slot=1
check(not PS_ConvertBall:new(player,replacement):isValid(),"attached item rejected")
replacement.slot=-1
player.dead=true
check(not PS_ConvertBall:new(player,replacement):isValid(),"dead player rejected")
player.dead=false
Mock.current=player
local context={options={}}
function context:addOption(label,target,fn,item) local o={label=label}; self.options[#self.options+1]=o; return o end
PS_BallMenu.fill(0,context,{replacement,{items={replacement}}})
check(#context.options==1,"stacked context entries deduplicated")
print("PASS conversion round trip, ownership races, active lock, loss prevention")
