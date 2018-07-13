--[[
    Load
]]
function OnLoad()
    if _G[myHero.charName] then
        _G[myHero.charName]()
        TheBrutalizer()
    end
end

--[[
    Engine
]]
function GetDistanceSqr(p1, p2)
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return (dx * dx + dz * dz)
end

function GetDistance(p1, p2)
    return math.sqrt(GetDistanceSqr(p1, p2))
end

function GetDistance2D(p1,p2)
    return math.sqrt((p2.x - p1.x)*(p2.x - p1.x) + (p2.y - p1.y)*(p2.y - p1.y))
end

function GetMode()
	if _G.gsoSDK then
        return _G.gsoSDK.Orbwalker:GetMode()
    end
end

function SetAttacks(bool)
	if _G.gsoSDK then
        _G.gsoSDK.Orbwalker.AttackEnabled = bool
    end
end

function GetTarget(range,type)
    local target
    local enemyList
    if _G.gsoSDK then
        if type == 0 then
            enemyList = _G.gsoSDK.ObjectManager:GetEnemyHeroes(range, false, "attack")
        elseif type == 1 then
            enemyList = _G.gsoSDK.ObjectManager:GetEnemyHeroes(range, false, "spell")
        end
        target = _G.gsoSDK.TargetSelector:GetTarget(enemyList, true)
    end
    return target
end

function MPpercent(unit)
    return unit.mana / unit.maxMana * 100
end

function HPpercent(unit)
    return unit.health / unit.maxHealth * 100
end

function ValidTarget(unit)
	return unit.health > 0 and unit.isTargetable and unit.visible and not unit.dead
end

function HasBuff(unit, buffName)
	for i = 1, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and buff.count > 0 and buff.name:lower() == buffName:lower() then 
			return true
		end
	end
	return false
end

function MinionsAround(pos, range, team)
    local Count = 0
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team == team and ValidTarget(minion) and GetDistance(pos,minion.pos) <= range then
            Count = Count + 1
        end
    end
    return Count
end

function HeroesAround(pos, range, team)
    local Count = 0
	for i = 1, Game.HeroCount() do
		local hero = Game.Hero(i)
		if hero and hero.team == team and not hero.dead and GetDistance(pos, hero.pos) < range then
			Count = Count + 1
		end
	end
	return Count
end

function GetHeroesInRange(r)
    local Heroes = {}
    for i = 1, Game.HeroCount() do 
        local Hero = Game.Hero(i)
        local bR = Hero.boundingRadius
        if Hero.team ~= myHero.team and ValidTarget(Hero) and GetDistanceSqr(Hero.pos, myHero.pos) - bR * bR < r then 
            Heroes[#Heroes + 1] = Hero 
        end
    end
    return Heroes
end

function ExcludeFurthest(average,lst,sTar)
    local removeID = 1 
    for i = 2, #lst do 
        if GetDistanceSqr(average, lst[i].pos) > GetDistanceSqr(average, lst[removeID].pos) then 
            removeID = i 
        end 
    end 

    local Newlst = {}
    for i = 1, #lst do 
        if (sTar and lst[i].networkID == sTar.networkID) or i ~= removeID then 
            Newlst[#Newlst + 1] = lst[i]
        end
    end
    return Newlst 
end

function GetBestCircularCastPos(r,lst,s,d,sTar)
    local average = {x = 0, y = 0, z = 0, count = 0}
    local point = nil 
    if #lst == 0 then 
        if sTar then return sTar:GetPrediction(s, d), 0 end 
        return 
    end

    for i = 1, #lst do 
        local org = lst[i]:GetPrediction(s, d)
        average.x = average.x + org.x 
        average.y = average.y + org.y 
        average.z = average.z + org.z 
        average.count = average.count + 1
    end 

    if sTar and sTar.type ~= lst[1].type then 
        local org = sTar:GetPrediction(s, d)
        average.x = average.x + org.x 
        average.y = average.y + org.y 
        average.z = average.z + org.z 
        average.count = average.count + 1
    end

    average.x = average.x/average.count 
    average.y = average.y/average.count 
    average.z = average.z/average.count 

    local InRange = 0 
    for i = 1, #lst do 
        if GetDistanceSqr(average, lst[i].pos) < r then 
            InRange = InRange + 1 
        end
    end

    local point = Vector(average.x, average.y, average.z)	

    if InRange == #lst then 
        return point, InRange
    else 
        return GetBestCircularCastPos(r, ExcludeFurthest(average, lst),s,d,sTar)
    end
end

local dashSpell = {
    ["sionr"] = true,
    ["warwickr"] = true,
    ["vir"] = true,
    ["tristanaw"] = true,
    ["shyvanatransformleap"] = true,
    ["powerball"] = true,
    ["leonazenithblade"] = true,
    ["galioe"] = true,
    ["galior"] = true,
    ["blindmonkqone"] = true,
    ["alphastrike"] = true,
    ["nautilusanchordragmissile"] = true,
    ["caitlynentrapment"] = true,
    ["bandagetoss"] = true,
    ["ekkoeattack"] = true,
    ["ekkor"] = true,
    ["evelynne"] = true,
    ["evelynne2"] = true,
    ["evelynnr"] = true,
    ["ezrealarcaneshift"] = true,
    ["crowstorm"] = true,
    ["tahmkenchnewr"] = true,
    ["shenr"] = true,
    ["graveschargeshot"] = true,
    ["jarvanivdragonstrike"] = true,
    ["hecarimrampattack"] = true,
    ["illaoiwattack"] = true,
    ["riftwalk"] = true,
    ["katarinae"] = true,
    ["pantheonrjump"] = true
}

local Waypoints = {}

function OnTick()
    SaveWaypoints(_G.gsoSDK.ObjectManager:GetEnemyHeroes(15000, false, "immortal"))
end
      
function GetWaypoints(unit)
    local path = unit.pathing
    return { IsMoving = path.hasMovePath, Path = path.endPos, Tick = Game.Timer() }
end
      
function SaveWaypointsSingle(unit)
    local unitID = unit.networkID
    if not Waypoints[unitID] then
        Waypoints[unitID] = GetWaypoints(unit)
        return
    end
    local currentWaypoints = GetWaypoints(unit)
    local currentWaypointsT = Waypoints[unitID]
    if currentWaypoints.IsMoving ~= currentWaypointsT.IsMoving then
        Waypoints[unitID] = currentWaypoints
        return
    end
    if currentWaypoints.IsMoving then
        local xx = currentWaypoints.Path.x
        local zz = currentWaypoints.Path.z
        local xxT = currentWaypointsT.Path.x
        local zzT = currentWaypointsT.Path.z
        if xx ~= xxT or zz ~= zzT then
            Waypoints[unitID] = currentWaypoints
        end
    end
end
      
function SaveWaypoints(enemyList)
    for i = 1, #enemyList do
        local unit = enemyList[i]
        SaveWaypointsSingle(unit)
    end
end
      
function ClosestPointOnLineSegment(p, p1, p2)
    local px,pz = p.x, p.z
    local ax,az = p1.x, p1.z
    local bx,bz = p2.x, p2.z
    local bxax = bx - ax
    local bzaz = bz - az
    local t = ((px - ax) * bxax + (pz - az) * bzaz) / (bxax * bxax + bzaz * bzaz)
    if t < 0 then
        return p1, false
    elseif t > 1 then
        return p2, false
    else
        return { x = ax + t * bxax, z = az + t * bzaz }, true
    end
end
      
function IsMinionCollision(unit, spellData, prediction)
    local width = spellData.radius * 0.77
    local enemyMinions = _G.gsoSDK.ObjectManager:GetEnemyMinions(2000, false)
    local mePos = myHero.pos
    for i = 1, #enemyMinions do
        local minion = enemyMinions[i]
        if minion ~= unit then
            local bbox = minion.boundingRadius
            local predWidth = width + bbox + 20
            local minionPos = minion.pos
            local point,onLineSegment = ClosestPointOnLineSegment(minionPos, prediction and unit:GetPrediction(spellData.speed,spellData.delay) or unit.pos, myHero.pos)
            local x = minionPos.x - point.x
            local z = minionPos.z - point.z
            if onLineSegment and x * x + z * z < predWidth * predWidth then
                return true
            end
            local mPathing = minion.pathing
            if mPathing.hasMovePath then
                local minionPosPred = minionPos:Extended(mPathing.endPos, spellData.delay + (mePos:DistanceTo(minionPos) / spellData.speed))
                point,onLineSegment = ClosestPointOnLineSegment(minionPosPred, prediction and unit:GetPrediction(spellData.speed,spellData.delay) or unit.pos, myHero.pos)
                local xx = minionPosPred.x - point.x
                local zz = minionPosPred.z - point.z
                if onLineSegment and xx * xx + zz * zz < predWidth * predWidth then
                    return true
                end
            end
        end
    end
    return false
end
      
function IsCollision(unit, spellData)
    if unit:GetCollision(spellData.radius, spellData.speed, spellData.delay) > 0 or IsMinionCollision(unit, spellData) or IsMinionCollision(unit, spellData, true) then
        return true
    end
    return false
end     

function IsImmobile(unit, delay)
    for i = 0, unit.buffCount do
          local buff = unit:GetBuff(i)
          if buff and buff.count > 0 and buff.duration > delay then
                local bType = buff.type
                if bType == 5 or bType == 11 or bType == 21 or bType == 22 or bType == 24 or bType == 29 or buff.name == "recall" then
                      return true
                end
          end
    end
    return false
end

function ImmobileTime(unit)
    local iT = 0
    for i = 0, unit.buffCount do
          local buff = unit:GetBuff(i)
          if buff and buff.count > 0 then
                local bType = buff.type
                if bType == 5 or bType == 11 or bType == 21 or bType == 22 or bType == 24 or bType == 29 or buff.name == "recall" then
                      local bDuration = buff.duration
                      if bDuration > iT then
                            iT = bDuration
                      end
                end
          end
    end
    return iT
end

function IsSlowed(unit, delay)
    for i = 0, unit.buffCount do
          local buff = unit:GetBuff(i)
          if from and buff.count > 0 and buff.type == 10 and buff.duration >= delay then
                return true
          end
    end
    return false
end

function GetInterceptionTime(source, startP, endP, unitspeed, spellspeed)
    local sx = source.x
    local sy = source.z
    local ux = startP.x
    local uy = startP.z
    local dx = endP.x - ux
    local dy = endP.z - uy
    local magnitude = math.sqrt(dx * dx + dy * dy)
    dx = (dx / magnitude) * unitspeed
    dy = (dy / magnitude) * unitspeed
    local a = (dx * dx) + (dy * dy) - (spellspeed * spellspeed)
    local b = 2 * ((ux * dx) + (uy * dy) - (sx * dx) - (sy * dy))
    local c = (ux * ux) + (uy * uy) + (sx * sx) + (sy * sy) - (2 * sx * ux) - (2 * sy * uy)
    local d = (b * b) - (4 * a * c)
    if d > 0 then
            local t1 = (-b + math.sqrt(d)) / (2 * a)
            local t2 = (-b - math.sqrt(d)) / (2 * a)
            return math.max(t1, t2)
    end
    if d >= 0 and d < 0.00001 then
            return -b / (2 * a)
    end
    return 0.00001
end

function GetPrediction(unit, from, spellData)
    local CastPos
    local hitChance = 1
    local unitPos = unit.pos
    local unitID = unit.networkID
    SaveWaypointsSingle(unit)
    local radius = spellData.radius
    local speed = spellData.speed
    local sType = spellData.sType
    local collision = spellData.collision
    local range = spellData.range - 35
    if sType == "line" and radius > 0 then
        range = range - radius * 0.5
    end
    local interceptionTime = speed < 10000 and GetInterceptionTime(from, unitPos, unit.pathing.endPos, unit.ms, speed) or 0
    local latency = _G.gsoSDK.OrbwalkerMenu.orb.clat.enabled:Value() and _G.gsoSDK.OrbwalkerMenu.orb.clat.latvalue:Value() * 0.001 or Game.Latency() * 0.001
    local delay = spellData.delay + interceptionTime
    local fromToUnit = from:DistanceTo(unitPos) / speed
    if collision and IsCollision(unit, spellData) then
        return false
    end
    if unit.pathing.isDashing then
        return false
    end
    local isCastingSpell = unit.activeSpell and unit.activeSpell.valid
    if isCastingSpell and dashSpell[unit.activeSpell.name:lower()] then
        return false
    end
    local isImmobile = IsImmobile(unit, 0)
    if unit.pathing.hasMovePath and Waypoints[unitID].IsMoving and not isImmobile and not isCastingSpell then
        local endPos = unit.pathing.endPos
        local UnitEnd = GetDistanceSqr(unitPos, endPos)
        if Game.Timer() - Waypoints[unitID].Tick < 0.175 or Game.Timer() - Waypoints[unitID].Tick > 1.25 or UnitEnd > 4000000 or from:AngleBetween(unitPos, endPos) < 25 or IsSlowed(unit, delay + fromToUnit) then
            hitChance = 2
        end
        CastPos = radius > 0 and unit:GetPrediction(math.huge,delay):Extended(unitPos, radius * 0.5) or unit:GetPrediction(math.huge,delay)
    elseif isImmobile or isCastingSpell then
        CastPos = unit.pos
        if IsImmobile(unit, delay + fromToUnit - 0.1) or (isCastingSpell and unit.activeSpell.castEndTime - Game.Timer() > 0.15) then
            hitChance = 2
        end
    elseif not unit.pathing.hasMovePath and not Waypoints[unitID].IsMoving and Game.Timer() - Waypoints[unitID].Tick > 0.77 then
        CastPos = unit.pos
    end
    if not CastPos or not CastPos:ToScreen().onScreen then
        return false
    end
    if GetDistanceSqr(from, CastPos) > range * range then
        return false
    end
    return CastPos, hitChance
end

--[[
    Libs
]]
require "DamageLib"
require "MapPosition"

--[[
    Localizations
]]
local version = 0.3

local Icon = {
    TB              = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/TheBrutalizer.png",

    Kayle           = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/Kayle.png",
    KayleQ          = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/KayleQ.png",
    KayleW          = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/KayleW.png",
    KayleE          = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/KayleE.png",
    KayleR          = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/KayleR.png",

    Quinn           = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/Quinn.png",
    QuinnQ          = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/QuinnQ.png",
    QuinnW          = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/QuinnW.png",
    QuinnE          = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/QuinnE.png",
    QuinnR          = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/QuinnR.png",

    Vladimir       = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/Vladimir.png",
    VladimirQ      = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/VladimirQ.png",
    VladimirW      = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/VladimirW.png",
    VladimirE      = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/VladimirE.png",
    VladimirR      = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/VladimirR.png",
}

--[[
    Kayle
]]
class "Kayle"

function Kayle:__init()
    self:SetSpells()
    self:Config()
    function OnTick() self:Tick() end
end

function Kayle:SetSpells()
    Q = {range = 650}
    W = {range = 900}
    E = {range = 525 + myHero.boundingRadius + 35, spread = 150}
    R = {range = 900}
end

function Kayle:Config()
    tbKayle = MenuElement({id = "tbKayle", name = "The Brutalizer: v"..version.." [Kayle]", type = MENU, leftIcon = Icon.Kayle})

    tbKayle:MenuElement({id = "Q", name = "Q - Reckoning", leftIcon = Icon.KayleQ, type = MENU})
    tbKayle:MenuElement({id = "W", name = "W - Divine Blessing", leftIcon = Icon.KayleW, type = MENU})
    tbKayle:MenuElement({id = "E", name = "E - Righteous Fury", leftIcon = Icon.KayleE, type = MENU})
    tbKayle:MenuElement({id = "R", name = "R - Intervention", leftIcon = Icon.KayleR, type = MENU})

    tbKayle.Q:MenuElement({id = "AA", name = "Only after AA (if in range)", value = true})
    tbKayle.Q:MenuElement({id = "MS", name = "Only if enemy ms is higher", value = false})

    tbKayle.W:MenuElement({id = "HP", name = "HP% to self cast [?]", value = 40, min = -1, max = 100, tooltip = "set -1 to disable"})
    tbKayle.W:MenuElement({id = "AHP", name = "HP% to ally cast [?]", value = 40, min = -1, max = 100, tooltip = "set -1 to disable"})
    for i = 1, Game.HeroCount() do
        local ally = Game.Hero(i)
        if ally and not ally.isMe and ally.team == myHero.team then
            tbKayle.W:MenuElement({id = ally.charName, name = ally.charName, value = true, leftIcon = "https://raw.githubusercontent.com/definitelynotgod/Zestorer/master/HeroIcons/"..ally.charName..".png"})
        end
    end

    tbKayle.E:MenuElement({id = "", name = "...", type = SPACE})

    tbKayle.R:MenuElement({id = "HP", name = "HP% to self cast [?]", value = 15, min = -1, max = 100, tooltip = "set -1 to disable"})
    tbKayle.R:MenuElement({id = "AHP", name = "HP% to ally cast [?]", value = 15, min = -1, max = 100, tooltip = "set -1 to disable"})
    for i = 1, Game.HeroCount() do
        local ally = Game.Hero(i)
        if ally and not ally.isMe and ally.team == myHero.team then
            tbKayle.R:MenuElement({id = ally.charName, name = ally.charName, value = true, leftIcon = "https://raw.githubusercontent.com/definitelynotgod/Zestorer/master/HeroIcons/"..ally.charName..".png"})
        end
    end
end

function Kayle:Tick()
    if myHero.dead then return end
    local mode = GetMode()
    self:Auto()
    if mode =="Combo" and tb.Combo.Enable:Value() and MPpercent(myHero) >= tb.Combo.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
        self:Combo()
    elseif mode =="Harass" and tb.Harass.Enable:Value() and MPpercent(myHero) >= tb.Harass.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
        self:Harass()
    elseif mode =="Clear" and tb.Laneclear.Enable:Value() and MPpercent(myHero) >= tb.Laneclear.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
        self:Laneclear()
    elseif mode =="Lasthit" and tb.Lasthit.Enable:Value() and MPpercent(myHero) >= tb.Lasthit.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
        self:Lasthit()
    elseif mode =="Flee" and tb.Flee.Enable:Value() and MPpercent(myHero) >= tb.Flee.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
        self:Flee()
    end
end

function Kayle:Auto()
    if Game.CanUseSpell(_R) == 0 then
        self:AutoR()
    end
    if Game.CanUseSpell(_W) == 0 then
        self:AutoW()
    end
end

function Kayle:AutoR()
    if HeroesAround(myHero.pos, 1600, 300 - myHero.team) ~= 0 then
        if HPpercent(myHero) <= tbKayle.R.HP:Value() then
            Control.CastSpell(HK_R, myHero)
        end
    end
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.team == myHero.team and ValidTarget(hero) and not hero.isMe and GetDistance(hero.pos,myHero.pos) <= R.range then
            if HeroesAround(hero.pos, 900, 300 - myHero.team) ~= 0 then
                if HPpercent(hero) <= tbKayle.R.AHP:Value() and tbKayle.R[hero.charName]:Value() then
                    Control.CastSpell(HK_R, hero)
                end
            end
        end
    end
end

function Kayle:AutoW()
    if HeroesAround(myHero.pos, 1600, 300 - myHero.team) ~= 0 then
        if HPpercent(myHero) <= tbKayle.W.HP:Value() then
            Control.CastSpell(HK_W, myHero)
        end
    end
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.team == myHero.team and ValidTarget(hero) and not hero.isMe and GetDistance(hero.pos,myHero.pos) <= W.range then
            if HeroesAround(hero.pos, 900, 300 - myHero.team) ~= 0 then
                if HPpercent(hero) <= tbKayle.W.AHP:Value() and tbKayle.W[hero.charName]:Value() then
                    Control.CastSpell(HK_W, hero)
                end
            end
        end
    end
end

function Kayle:Combo()
    if tb.Combo.Q:Value() then
        local target = GetTarget(Q.range,1)
        self:Qlogic(target,true)
    end
    if tb.Combo.E:Value() then
        local target = GetTarget(E.range,1)
        self:Elogic(target)
    end
    if tb.Combo.W:Value() then
        local target = GetTarget(E.range + 200,1)
        self:Wlogic(target)
    end
end

function Kayle:Harass()
    if tb.Harass.Q:Value() then
        local target = GetTarget(Q.range,1)
        self:Qlogic(target,true)
    end
    if tb.Harass.E:Value() then
        local target = GetTarget(E.range,1)
        self:Elogic(target)
    end
    if tb.Harass.W:Value() then
        local target = GetTarget(850,1)
        self:Wlogic(target)
    end
end

function Kayle:Laneclear()
    if tb.Laneclear.Q:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and ValidTarget(minion) then
                self:Qlogic(minion,false)
            end
        end
    end
    if tb.Laneclear.E:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and ValidTarget(minion) and MinionsAround(minion.pos, E.spread, 300) + MinionsAround(minion.pos, E.spread, 300 - myHero.team) >= tb.Laneclear.Minions:Value() then
                self:Elogic(minion)
            end
        end
    end
end

function Kayle:Lasthit()
    if tb.Lasthit.Q:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            local level = myHero:GetSpellData(_Q).level
            local damage = getdmg("Q",minion,myHero,1,level)
            if minion and minion.team == 300 - myHero.team and ValidTarget(minion) and damage > minion.health then
                self:Qlogic(minion,false)
            end
        end
    end
end

function Kayle:Flee()
    if tb.Flee.Q:Value() then
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and hero.team == 300 - myHero.team and ValidTarget(hero) then
                self:Qlogic(hero,false)
            end
        end
    end
    if tb.Flee.W:Value() and Game.CanUseSpell(_W) == 0 then
        Control.CastSpell(HK_W,myHero)
    end
end

function Kayle:Qlogic(target,check)
    if target and GetDistance(target.pos,myHero.pos) <= Q.range and Game.CanUseSpell(_Q) == 0 then
        if (myHero.ms >= target.ms and tbKayle.Q.MS:Value()) or (myHero.attackData.state ~= STATE_WINDDOWN and GetDistance(target.pos,myHero.pos) <= myHero.range + myHero.boundingRadius + 35) then
            return
        end
        Control.CastSpell(HK_Q, target)
    end
end

function Kayle:Wlogic(target)
    if target and Game.CanUseSpell(_W) == 0 and HPpercent(myHero) < 90 then
        if Game.CanUseSpell(_E) == 0 or HasBuff(myHero,"judicatorrighteousfury") then
            if GetDistance(target.pos,myHero.pos) > 650 then
                Control.CastSpell(HK_W,myHero)
            end
        end
    end
end

function Kayle:Elogic(target)
    if target and GetDistance(target.pos,myHero.pos) <= E.range and Game.CanUseSpell(_E) == 0 then
        Control.CastSpell(HK_E)
    end
end

--[[
    Quinn
]]
class "Quinn"

function Quinn:__init()
    self:SetSpells()
    self:Config()
    function OnTick() self:Tick() end
end

function Quinn:SetSpells()
    Q = {delay = 0.25, speed = 1550, radius = 60, range = 1025, effectradius = 210, collision = true}
    W = {range = 2100}
    E = {range = 675}
end

function Quinn:Config()
    tbQuinn = MenuElement({id = "tbQuinn", name = "The Brutalizer: v"..version.." [Quinn]", type = MENU, leftIcon = Icon.Quinn})

    tbQuinn:MenuElement({id = "Q", name = "Q - Blinding Assault", leftIcon = Icon.QuinnQ, type = MENU})
    tbQuinn:MenuElement({id = "W", name = "W - Heightened Senses", leftIcon = Icon.QuinnW, type = MENU})
    tbQuinn:MenuElement({id = "E", name = "E - Vault", leftIcon = Icon.QuinnE, type = MENU})
    tbQuinn:MenuElement({id = "R", name = "R - Behind Enemy Lines", leftIcon = Icon.QuinnR, type = MENU})

    tbQuinn.Q:MenuElement({id = "", name = "...", type = SPACE})

    tbQuinn.W:MenuElement({id = "B", name = "Auto reveal enemy in bush", value = true})

    tbQuinn.E:MenuElement({id = "", name = "...", type = SPACE})

    tbQuinn.R:MenuElement({id = "", name = "...", type = SPACE})
end

function Quinn:Tick()
    if myHero.dead then return end
    local mode = GetMode()
    if mode =="Combo" and tb.Combo.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP then
        self:Combo()
    elseif mode =="Harass" and tb.Harass.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP then
        self:Harass()
    elseif mode =="Clear" and tb.Laneclear.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP then
        self:Laneclear()
    end
end

function Quinn:Combo()
    if tb.Combo.E:Value() then
        local target = GetTarget(E.range,0)
        self:Elogic(target)
    end
    if tb.Combo.Q:Value() then
        local target = GetTarget(Q.range,0)
        self:Qlogic(target)
    end
    if tbQuinn.W.B:Value() then
        self:Wlogic()
    end
end

function Quinn:Harass()
    if tb.Harass.E:Value() then
        local target = GetTarget(E.range,0)
        self:Elogic(target)
    end
    if tb.Harass.Q:Value() then
        local target = GetTarget(Q.range,0)
        self:Qlogic(target)
    end
    if tbQuinn.W.B:Value() then
        self:Wlogic()
    end
end

function Quinn:Laneclear()
    if tb.Laneclear.Q:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and ValidTarget(minion) and MinionsAround(minion.pos, Q.effectradius, 300) + MinionsAround(minion.pos, Q.effectradius, 300 - myHero.team) >= tb.Laneclear.Minions:Value() then
                self:Qlogic(minion)
            end
        end
    end
end

function Quinn:Qlogic(target)
    if Game.CanUseSpell(_Q) == 0 then
        if target and target.type == Obj_AI_Hero then
            if target.team ~= myHero.team and ValidTarget(target) then
                local CastPos, hitChance = GetPrediction(target, myHero.pos, Q)
                if hitChance and hitChance >= 2 and GetDistance(CastPos,myHero.pos) <= Q.range then
                    Control.CastSpell(HK_Q, CastPos)
                end
            end
        end
        if target and target.type == Obj_AI_Minion and GetDistance(target.pos,myHero.pos) <= Q.range then
            Control.CastSpell(HK_Q, target.pos)
        end
    end
end

local LastPositions = {}
function Quinn:Wlogic()
    if not Game.CanUseSpell(_W) == 0 then return end
    for i = 1, Game.HeroCount() do	
		local hero = Game.Hero(i)
		if not hero.dead and hero.visible and hero.isEnemy then
			LastPositions[hero.networkID] = {pos = hero.pos, posTo = hero.posTo, dir = hero.dir, time = Game.Timer() }
		end
	end	
	for i = 1, Game.HeroCount() do	
		local hero = Game.Hero(i)
		if not hero.dead and not hero.visible and hero.isEnemy and hero.distance < 2100 then
			local lastPosInfo = LastPositions[hero.networkID]
			if lastPosInfo and Game.Timer() - lastPosInfo.time < 3 then
				local inBush = false
				local Senses
				for i = 1, 10 do
					local checkPos = lastPosInfo.pos + lastPosInfo.dir*20*i
					if GetDistance(checkPos,myHero.pos) <= 2100 and MapPosition:inBush(checkPos) then
						Senses = checkPos
						inBush = true
						break
					end
				end
				if inBush then
					Control.CastSpell(HK_W)
					break
				end
			end
		end
	end
end

function Quinn:Elogic(target)
    if target and GetDistance(target.pos,myHero.pos) <= E.range and Game.CanUseSpell(_E) == 0 then
        Control.CastSpell(HK_E, target)
    end
end

--[[
    Vladimir
]]
class "Vladimir"

function Vladimir:__init()
    self:SetSpells()
    self:Config()
    self.startedE = Game.Timer()
    function OnTick() self:Tick() end
end

function Vladimir:SetSpells()
    Q = {range = 600}
    W = {range = 300}
    E = {range = 600}
    R = {range = 700, delay = 0.389, radius = 350, speed = math.huge}
end

function Vladimir:Config()
    tbVladimir = MenuElement({id = "tbVladimir", name = "The Brutalizer: v"..version.." [Vladimir]", type = MENU, leftIcon = Icon.Vladimir})

    tbVladimir:MenuElement({id = "Q", name = "Q - Transfusion", leftIcon = Icon.VladimirQ, type = MENU})
    tbVladimir:MenuElement({id = "W", name = "W - Sanguine Pool", leftIcon = Icon.VladimirW, type = MENU})
    tbVladimir:MenuElement({id = "E", name = "E - Tides of Blood", leftIcon = Icon.VladimirE, type = MENU})
    tbVladimir:MenuElement({id = "R", name = "R - Hemoplague", leftIcon = Icon.VladimirR, type = MENU})

    tbVladimir.Q:MenuElement({id = "", name = "...", type = SPACE})

    tbVladimir.W:MenuElement({id = "MS", name = "Only if enemy ms is higher", value = true})

    tbVladimir.E:MenuElement({id = "", name = "...", type = SPACE})

    tbVladimir.R:MenuElement({id = "X", name = "Enemy count", value = 2, min = 1, max = 5})
    tbVladimir.R:MenuElement({id = "LS", name = "Life Saver [?]", value = 25, min = -1, max = 100, tooltip = "Set -1 to disable"})
end

function Vladimir:Tick()
    if myHero.dead then return end
    self:AutoR()
    local mode = GetMode()
    if mode =="Combo" and tb.Combo.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP and not Control.IsKeyDown(HK_E) then
        self:Combo()
    elseif mode =="Harass" and tb.Harass.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP and not Control.IsKeyDown(HK_E) then
        self:Harass()
    elseif mode =="Clear" and tb.Laneclear.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP and not Control.IsKeyDown(HK_E) then
        self:Laneclear()
    elseif mode =="Lasthit" and tb.Lasthit.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP and not Control.IsKeyDown(HK_E) then
        self:Lasthit()
    end

    if not HasBuff(myHero,"vladimire") and Control.IsKeyDown(HK_E) and Game.Timer() - self.startedE >= 1 then
        Control.KeyUp(HK_E)
    end

    if HasBuff(myHero,"vladimirsanguinepool") or HasBuff(myHero,"vladimire") then
        SetAttacks(false)
    else
        SetAttacks(true)
    end
end

function Vladimir:Combo()
    if tb.Combo.R:Value() then
        self:Rlogic()
    end
    if tb.Combo.E:Value() then
        local target = GetTarget(E.range,1)
        self:Elogic(target)
    end
    if tb.Combo.Q:Value() then
        local target = GetTarget(Q.range,1)
        self:Qlogic(target)
    end
    if tb.Combo.W:Value() then
        local target = GetTarget(W.range,1)
        self:Wlogic(target)
    end
end

function Vladimir:Harass()
    if tb.Harass.R:Value() then
        self:Rlogic()
    end
    if tb.Harass.E:Value() then
        local target = GetTarget(E.range,1)
        self:Elogic(target)
    end
    if tb.Harass.Q:Value() then
        local target = GetTarget(Q.range,1)
        self:Qlogic(target)
    end
    if tb.Harass.W:Value() then
        local target = GetTarget(W.range,1)
        self:Wlogic(target)
    end
end

function Vladimir:Laneclear()
    if tb.Laneclear.Q:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and ValidTarget(minion) then
                self:Qlogic(minion)
            end
        end
    end
    if tb.Laneclear.E:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and ValidTarget(minion) and MinionsAround(myHero.pos, E.range, 300) + MinionsAround(myHero.pos, E.range, 300 - myHero.team) >= tb.Laneclear.Minions:Value() then
                self:Elogic(minion)
            end
        end
    end
end

function Vladimir:Lasthit()
    if tb.Lasthit.Q:Value() then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            local level = myHero:GetSpellData(_Q).level
            local damage = getdmg("Q",minion,myHero,1,level)
            if minion and minion.team == 300 - myHero.team and ValidTarget(minion) and damage > minion.health then
                self:Qlogic(minion)
            end
        end
    end
end

function Vladimir:Qlogic(target)
    if target and GetDistance(target.pos,myHero.pos) <= Q.range and Game.CanUseSpell(_Q) == 0 then
        Control.CastSpell(HK_Q, target)
    end
end

function Vladimir:Wlogic(target)
    if target and GetDistance(target.pos,myHero.pos) <= W.range and Game.CanUseSpell(_W) == 0 then
        if myHero.ms >= target.ms and tbVladimir.W.MS:Value() then
            return
        end
        Control.CastSpell(HK_W)
    end
end

function Vladimir:Elogic(target)
    if target and GetDistance(target.pos,myHero.pos) <= E.range and Game.CanUseSpell(_E) == 0 and not myHero.isChanneling and Game.Timer() - self.startedE >= 3 then
        if target.type == Obj_AI_Hero and target:GetCollision(E.radius, E.speed, E.delay) ~= 0 then return end
        SetAttacks(false)
        Control.KeyDown(HK_E)
        self.startedE = Game.Timer()
    end
end

function Vladimir:Rlogic()
    if Game.CanUseSpell(_R) == 0 then
        local sTar
        local target = GetTarget(R.range,1)
        if target then 
            sTar = target 
        end
        local sqr = {range = R.range * R.range, radius = R.radius * R.radius}
        local list = GetHeroesInRange(sqr.range)
        local Pos, Count = GetBestCircularCastPos(sqr.radius,list,R.speed,R.delay,sTar)
        if Pos and Pos:To2D().onScreen and Count >= tbVladimir.R.X:Value() then
            Control.CastSpell(HK_R, Pos)
        end
    end
end

function Vladimir:AutoR()
    if Game.CanUseSpell(_R) == 0 and HPpercent(myHero) <= tbVladimir.R.LS:Value() then
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and hero.team ~= myHero.team and ValidTarget(hero) then
                local CastPos, hitChance = GetPrediction(hero, myHero.pos, R)
                if hitChance and hitChance >= 2 and GetDistance(CastPos,myHero.pos) <= R.range then
                    Control.CastSpell(HK_R, CastPos)
                end
            end
        end
    end
end

--[[
    Core
]]
class "TheBrutalizer"

function TheBrutalizer:__init()
    self:Config()
    function OnDraw() self:Draw() end
end

function TheBrutalizer:Config()
    tb = MenuElement({id = "tb", name = "The Brutalizer: v"..version.." [Core]", type = MENU, leftIcon = Icon.TB})

    tb:MenuElement({id = "Combo", name = "Combo", type = MENU})
    tb:MenuElement({id = "Harass", name = "Harass", type = MENU})
    tb:MenuElement({id = "Laneclear", name = "Laneclear", type = MENU})
    tb:MenuElement({id = "Lasthit", name = "Lasthit", type = MENU})
    tb:MenuElement({id = "Flee", name = "Flee", type = MENU})
    tb:MenuElement({id = "Draw", name = "Draw", type = MENU})


    tb.Combo:MenuElement({id = "Enable", name = "Enable Combo", value = true, key = string.byte("+"), toggle = true})
    tb.Combo:MenuElement({id = "Mana", name = "Combo MP%", value = -1, min = -1, max = 100})
    tb.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
    tb.Combo:MenuElement({id = "W", name = "Use W", value = true})
    tb.Combo:MenuElement({id = "E", name = "Use E", value = true})
    tb.Combo:MenuElement({id = "R", name = "Use R", value = true})

    tb.Harass:MenuElement({id = "Enable", name = "Enable Harass", value = true, key = string.byte("S"), toggle = true})
    tb.Harass:MenuElement({id = "Mana", name = "Harass MP%", value = -1, min = -1, max = 100})
    tb.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
    tb.Harass:MenuElement({id = "W", name = "Use W", value = true})
    tb.Harass:MenuElement({id = "E", name = "Use E", value = true})
    tb.Harass:MenuElement({id = "R", name = "Use R", value = true})

    tb.Laneclear:MenuElement({id = "Enable", name = "Enable Laneclear", value = true, key = string.byte("A"), toggle = true})
    tb.Laneclear:MenuElement({id = "Mana", name = "Laneclear MP%", value = -1, min = -1, max = 100})
    tb.Laneclear:MenuElement({id = "Minions", name = "Laneclear Minions", value = 2, min = 1, max = 10})
    tb.Laneclear:MenuElement({id = "Q", name = "Use Q", value = true})
    tb.Laneclear:MenuElement({id = "W", name = "Use W", value = true})
    tb.Laneclear:MenuElement({id = "E", name = "Use E", value = true})
    tb.Laneclear:MenuElement({id = "R", name = "Use R", value = true})

    tb.Lasthit:MenuElement({id = "Enable", name = "Enable Lasthit", value = true, key = string.byte("A"), toggle = true})
    tb.Lasthit:MenuElement({id = "Mana", name = "Lasthit MP%", value = -1, min = -1, max = 100})
    tb.Lasthit:MenuElement({id = "Q", name = "Use Q", value = true})
    tb.Lasthit:MenuElement({id = "W", name = "Use W", value = true})
    tb.Lasthit:MenuElement({id = "E", name = "Use E", value = true})
    tb.Lasthit:MenuElement({id = "R", name = "Use R", value = true})

    tb.Flee:MenuElement({id = "Enable", name = "Enable Flee", value = true, key = string.byte("+"), toggle = true})
    tb.Flee:MenuElement({id = "Mana", name = "Flee MP%", value = -1, min = -1, max = 100})
    tb.Flee:MenuElement({id = "Q", name = "Use Q", value = true})
    tb.Flee:MenuElement({id = "W", name = "Use W", value = true})
    tb.Flee:MenuElement({id = "E", name = "Use E", value = true})
    tb.Flee:MenuElement({id = "R", name = "Use R", value = true})

    
    tb.Draw:MenuElement({id = "Q", name = "Q", type = MENU})
    tb.Draw.Q:MenuElement({id = "Enable", name = "Enable", value = true})
    tb.Draw.Q:MenuElement({id = "Alpha", name = "Opacity", value = 255, min = 0, max = 255})
    tb.Draw.Q:MenuElement({id = "Width", name = "Width", value = 3, min = 1, max = 5})
    tb.Draw.Q:MenuElement({id = "Red", name = "Red", value = 0, min = 0, max = 255})
    tb.Draw.Q:MenuElement({id = "Green", name = "Green", value = 0, min = 0, max = 255})
    tb.Draw.Q:MenuElement({id = "Blue", name = "Blue", value = 255, min = 0, max = 255})

    tb.Draw:MenuElement({id = "W", name = "W", type = MENU})
    tb.Draw.W:MenuElement({id = "Enable", name = "Enable", value = true})
    tb.Draw.W:MenuElement({id = "Alpha", name = "Opacity", value = 255, min = 0, max = 255})
    tb.Draw.W:MenuElement({id = "Width", name = "Width", value = 3, min = 1, max = 5})
    tb.Draw.W:MenuElement({id = "Red", name = "Red", value = 0, min = 0, max = 255})
    tb.Draw.W:MenuElement({id = "Green", name = "Green", value = 255, min = 0, max = 255})
    tb.Draw.W:MenuElement({id = "Blue", name = "Blue", value = 0, min = 0, max = 255})

    tb.Draw:MenuElement({id = "E", name = "E", type = MENU})
    tb.Draw.E:MenuElement({id = "Enable", name = "Enable", value = true})
    tb.Draw.E:MenuElement({id = "Alpha", name = "Opacity", value = 255, min = 0, max = 255})
    tb.Draw.E:MenuElement({id = "Width", name = "Width", value = 3, min = 1, max = 5})
    tb.Draw.E:MenuElement({id = "Red", name = "Red", value = 255, min = 0, max = 255})
    tb.Draw.E:MenuElement({id = "Green", name = "Green", value = 255, min = 0, max = 255})
    tb.Draw.E:MenuElement({id = "Blue", name = "Blue", value = 0, min = 0, max = 255})

    tb.Draw:MenuElement({id = "R", name = "R", type = MENU})
    tb.Draw.R:MenuElement({id = "Enable", name = "Enable", value = true})
    tb.Draw.R:MenuElement({id = "Alpha", name = "Opacity", value = 255, min = 0, max = 255})
    tb.Draw.R:MenuElement({id = "Width", name = "Width", value = 3, min = 1, max = 5})
    tb.Draw.R:MenuElement({id = "Red", name = "Red", value = 255, min = 0, max = 255})
    tb.Draw.R:MenuElement({id = "Green", name = "Green", value = 0, min = 0, max = 255})
    tb.Draw.R:MenuElement({id = "Blue", name = "Blue", value = 0, min = 0, max = 255})


    tb.Draw:MenuElement({id = "Combo", name = "Combo", type = MENU})
    tb.Draw.Combo:MenuElement({id = "Text", name = "Text Enabled", value = false})
    tb.Draw.Combo:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    tb.Draw.Combo:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    tb.Draw.Combo:MenuElement({id = "yPos", name = "Text Y Position", value = -140, min = -1000, max = 1000, step = 10})

    tb.Draw:MenuElement({id = "Harass", name = "Harass", type = MENU})
    tb.Draw.Harass:MenuElement({id = "Text", name = "Text Enabled", value = true})
    tb.Draw.Harass:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    tb.Draw.Harass:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    tb.Draw.Harass:MenuElement({id = "yPos", name = "Text Y Position", value = -140, min = -1000, max = 1000, step = 10})

    tb.Draw:MenuElement({id = "Laneclear", name = "Laneclear", type = MENU})
    tb.Draw.Laneclear:MenuElement({id = "Text", name = "Text Enabled", value = true})
    tb.Draw.Laneclear:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    tb.Draw.Laneclear:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    tb.Draw.Laneclear:MenuElement({id = "yPos", name = "Text Y Position", value = -130, min = -1000, max = 1000, step = 10})

    tb.Draw:MenuElement({id = "Lasthit", name = "Lasthit", type = MENU})
    tb.Draw.Lasthit:MenuElement({id = "Text", name = "Text Enabled", value = false})
    tb.Draw.Lasthit:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    tb.Draw.Lasthit:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    tb.Draw.Lasthit:MenuElement({id = "yPos", name = "Text Y Position", value = -130, min = -1000, max = 1000, step = 10})

    tb.Draw:MenuElement({id = "Flee", name = "Flee", type = MENU})
    tb.Draw.Flee:MenuElement({id = "Text", name = "Text Enabled", value = false})
    tb.Draw.Flee:MenuElement({id = "Size", name = "Text Size", value = 10, min = 1, max = 100})
    tb.Draw.Flee:MenuElement({id = "xPos", name = "Text X Position", value = -50, min = -1000, max = 1000, step = 10})
    tb.Draw.Flee:MenuElement({id = "yPos", name = "Text Y Position", value = -120, min = -1000, max = 1000, step = 10})
end

local range = {
    ["Kayle"] = {Q = 650, W = 900, E = 525 + myHero.boundingRadius + 35, R = 900},
    ["Vladimir"] = {Q = 600, W = 300, E = 600, R = 700},
    ["Quinn"] = {Q = 1025, W = 2100, E = 675, R = 0},
}

function TheBrutalizer:Draw()
    local textPos = myHero.pos:To2D()
    if tb.Draw.Combo.Text:Value() then
        local size = tb.Draw.Combo.Size:Value()
        local xPos = tb.Draw.Combo.xPos:Value()
        local yPos = tb.Draw.Combo.yPos:Value()
        if tb.Combo.Enable:Value() then
            Draw.Text("Combo ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
        else
            Draw.Text("Combo OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
    if tb.Draw.Harass.Text:Value() then
        local size = tb.Draw.Harass.Size:Value()
        local xPos = tb.Draw.Harass.xPos:Value()
        local yPos = tb.Draw.Harass.yPos:Value()
        if tb.Harass.Enable:Value() then
            Draw.Text("Harass ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
        else
            Draw.Text("Harass OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
    if tb.Draw.Laneclear.Text:Value() then
        local size = tb.Draw.Laneclear.Size:Value()
        local xPos = tb.Draw.Laneclear.xPos:Value()
        local yPos = tb.Draw.Laneclear.yPos:Value()
        if tb.Laneclear.Enable:Value() then
            Draw.Text("Laneclear ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
        else
            Draw.Text("Laneclear OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
    if tb.Draw.Lasthit.Text:Value() then
        local size = tb.Draw.Lasthit.Size:Value()
        local xPos = tb.Draw.Lasthit.xPos:Value()
        local yPos = tb.Draw.Lasthit.yPos:Value()
        if tb.Lasthit.Enable:Value() then
            Draw.Text("Lasthit ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
        else
            Draw.Text("Lasthit OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end
    if tb.Draw.Flee.Text:Value() then
        local size = tb.Draw.Flee.Size:Value()
        local xPos = tb.Draw.Flee.xPos:Value()
        local yPos = tb.Draw.Flee.yPos:Value()
        if tb.Flee.Enable:Value() then
            Draw.Text("Flee ON", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 000, 255, 000))
        else
            Draw.Text("Flee OFF", size, textPos.x + xPos, textPos.y + yPos, Draw.Color(255, 255, 000, 000))
        end
    end

	if myHero.dead then return end
    if tb.Draw.Q.Enable:Value() and Game.CanUseSpell(_Q) == 0 then
        local Width = tb.Draw.Q.Width:Value()
        local Alpha = tb.Draw.Q.Alpha:Value()
        local Red = tb.Draw.Q.Red:Value()
        local Green = tb.Draw.Q.Green:Value()
        local Blue = tb.Draw.Q.Blue:Value()
		Draw.Circle(myHero.pos, range[myHero.charName].Q, Width, Draw.Color(Alpha,Red,Green,Blue))
	end
	if tb.Draw.W.Enable:Value() and Game.CanUseSpell(_W) == 0 then
        local Width = tb.Draw.W.Width:Value()
        local Alpha = tb.Draw.W.Alpha:Value()
        local Red = tb.Draw.W.Red:Value()
        local Green = tb.Draw.W.Green:Value()
        local Blue = tb.Draw.W.Blue:Value()
		Draw.Circle(myHero.pos, range[myHero.charName].W, Width, Draw.Color(Alpha,Red,Green,Blue))
	end
	if tb.Draw.E.Enable:Value() and Game.CanUseSpell(_E) == 0 then
        local Width = tb.Draw.E.Width:Value()
        local Alpha = tb.Draw.E.Alpha:Value()
        local Red = tb.Draw.E.Red:Value()
        local Green = tb.Draw.E.Green:Value()
        local Blue = tb.Draw.E.Blue:Value()
		Draw.Circle(myHero.pos, range[myHero.charName].E, Width, Draw.Color(Alpha,Red,Green,Blue))
    end
    if tb.Draw.R.Enable:Value() and Game.CanUseSpell(_R) == 0 then
        local Width = tb.Draw.R.Width:Value()
        local Alpha = tb.Draw.R.Alpha:Value()
        local Red = tb.Draw.R.Red:Value()
        local Green = tb.Draw.R.Green:Value()
        local Blue = tb.Draw.R.Blue:Value()
		Draw.Circle(myHero.pos, range[myHero.charName].R, Width, Draw.Color(Alpha,Red,Green,Blue))
	end
end






if gsoOrbwalkerLoaded then return end
gsoOrbwalkerLoaded = true





if _G.gsoSDK then
      _G.gsoSDK.OrbwalkerMenu = nil
      _G.gsoSDK.Cursor = nil
      _G.gsoSDK.TargetSelector = nil
      _G.gsoSDK.Farm = nil
      _G.gsoSDK.ObjectManager = nil
      _G.gsoSDK.Orbwalker = nil
else
      _G.gsoSDK = {
            OrbwalkerMenu = nil,
            Cursor = nil,
            TargetSelector = nil,
            Farm = nil,
            ObjectManager = nil,
            Orbwalker = nil
      }
end





local debugMode = false
local myHero = myHero
local GetTickCount = GetTickCount
local MathSqrt = math.sqrt
local DrawText = Draw.Text
local GameTimer = Game.Timer
local DrawColor = Draw.Color
local DrawCircle = Draw.Circle
local ControlKeyUp = Control.KeyUp
local ControlKeyDown = Control.KeyDown
local ControlIsKeyDown = Control.IsKeyDown
local ControlMouseEvent = Control.mouse_event
local ControlSetCursorPos = Control.SetCursorPos
local GameCanUseSpell = Game.CanUseSpell
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local GameTurretCount = Game.TurretCount
local GameTurret = Game.Turret
local GameObjectCount = Game.ObjectCount
local GameObject = Game.Object
local GameIsChatOpen = Game.IsChatOpen
local GameLatency = Game.Latency





-- [ cursor class ]
class "gsoCursor"

      -- [ init ]
      function gsoCursor:__init()
            self.CursorReady = true
            self.ExtraSetCursor = nil
            self.SetCursorPos = nil
      end
      
      -- [ is cursor ready ]
      function gsoCursor:IsCursorReady()
            if self.CursorReady and not self.SetCursorPos and not self.ExtraSetCursor then
                  return true
            end
            return false
      end
      
      -- [ draw menu ]
      function gsoCursor:CreateDrawMenu(menu)
            _G.gsoSDK.OrbwalkerMenu.gsodraw:MenuElement({name = "Cursor Pos",  id = "cursor", type = MENU})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.cursor:MenuElement({name = "Enabled",  id = "enabled", value = false})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.cursor:MenuElement({name = "Color",  id = "color", color = DrawColor(255, 153, 0, 76)})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.cursor:MenuElement({name = "Width",  id = "width", value = 3, min = 1, max = 10})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.cursor:MenuElement({name = "Radius",  id = "radius", value = 150, min = 1, max = 300})
      end
      
      -- [ set cursor ]
      function gsoCursor:SetCursor(cPos, castPos, delay)
            self.ExtraSetCursor = castPos
            self.CursorReady = false
            self.SetCursorPos = { EndTime = GameTimer() + delay, Action = function() ControlSetCursorPos(cPos.x, cPos.y) end, Active = true }
      end
      
      -- [ tick ]
      function gsoCursor:Tick()
            if self.SetCursorPos then
                  if self.SetCursorPos.Active and GameTimer() > self.SetCursorPos.EndTime then
                        self.SetCursorPos.Action()
                        self.SetCursorPos.Active = false
                        self.ExtraSetCursor = nil
                  elseif not self.SetCursorPos.Active and GameTimer() > self.SetCursorPos.EndTime + 0.025 then
                        self.CursorReady = true
                        self.SetCursorPos = nil
                  end
            end
            if self.ExtraSetCursor then
                  ControlSetCursorPos(self.ExtraSetCursor)
            end
      end
      
      -- [ draw ]
      function gsoCursor:Draw()
            if _G.gsoSDK.OrbwalkerMenu.gsodraw.cursor.enabled:Value() then
                  DrawCircle(mousePos, _G.gsoSDK.OrbwalkerMenu.gsodraw.cursor.radius:Value(), _G.gsoSDK.OrbwalkerMenu.gsodraw.cursor.width:Value(), _G.gsoSDK.OrbwalkerMenu.gsodraw.cursor.color:Value())
            end
      end





-- [ target selector class ]
class "gsoTS"

      -- [ init ]
      function gsoTS:__init()
            -- Last LastHit Minion
            self.LastHandle = 0
            -- Last LaneClear Minion
            self.LastLCHandle = 0
            self.SelectedTarget = nil
            self.LastSelTick = 0
            self.LastHeroTarget = nil
            self.FarmMinions = {}
            self.Priorities = {
                  ["Aatrox"] = 3, ["Ahri"] = 2, ["Akali"] = 2, ["Alistar"] = 5, ["Amumu"] = 5, ["Anivia"] = 2, ["Annie"] = 2, ["Ashe"] = 1, ["AurelionSol"] = 2, ["Azir"] = 2,
                  ["Bard"] = 3, ["Blitzcrank"] = 5, ["Brand"] = 2, ["Braum"] = 5, ["Caitlyn"] = 1, ["Camille"] = 3, ["Cassiopeia"] = 2, ["Chogath"] = 5, ["Corki"] = 1,
                  ["Darius"] = 4, ["Diana"] = 2, ["DrMundo"] = 5, ["Draven"] = 1, ["Ekko"] = 2, ["Elise"] = 3, ["Evelynn"] = 2, ["Ezreal"] = 1, ["Fiddlesticks"] = 3, ["Fiora"] = 3,
                  ["Fizz"] = 2, ["Galio"] = 5, ["Gangplank"] = 2, ["Garen"] = 5, ["Gnar"] = 5, ["Gragas"] = 4, ["Graves"] = 2, ["Hecarim"] = 4, ["Heimerdinger"] = 3, ["Illaoi"] =  3,
                  ["Irelia"] = 3, ["Ivern"] = 5, ["Janna"] = 4, ["JarvanIV"] = 3, ["Jax"] = 3, ["Jayce"] = 2, ["Jhin"] = 1, ["Jinx"] = 1, ["Kalista"] = 1, ["Karma"] = 2, ["Karthus"] = 2,
                  ["Kassadin"] = 2, ["Katarina"] = 2, ["Kayle"] = 2, ["Kayn"] = 2, ["Kennen"] = 2, ["Khazix"] = 2, ["Kindred"] = 2, ["Kled"] = 4, ["KogMaw"] = 1, ["Leblanc"] = 2,
                  ["LeeSin"] = 3, ["Leona"] = 5, ["Lissandra"] = 2, ["Lucian"] = 1, ["Lulu"] = 3, ["Lux"] = 2, ["Malphite"] = 5, ["Malzahar"] = 3, ["Maokai"] = 4, ["MasterYi"] = 1,
                  ["MissFortune"] = 1, ["MonkeyKing"] = 3, ["Mordekaiser"] = 2, ["Morgana"] = 3, ["Nami"] = 3, ["Nasus"] = 4, ["Nautilus"] = 5, ["Nidalee"] = 2, ["Nocturne"] = 2,
                  ["Nunu"] = 4, ["Olaf"] = 4, ["Orianna"] = 2, ["Ornn"] = 4, ["Pantheon"] = 3, ["Poppy"] = 4, ["Quinn"] = 1, ["Rakan"] = 3, ["Rammus"] = 5, ["RekSai"] = 4,
                  ["Renekton"] = 4, ["Rengar"] = 2, ["Riven"] = 2, ["Rumble"] = 2, ["Ryze"] = 2, ["Sejuani"] = 4, ["Shaco"] = 2, ["Shen"] = 5, ["Shyvana"] = 4, ["Singed"] = 5,
                  ["Sion"] = 5, ["Sivir"] = 1, ["Skarner"] = 4, ["Sona"] = 3, ["Soraka"] = 3, ["Swain"] = 3, ["Syndra"] = 2, ["TahmKench"] = 5, ["Taliyah"] = 2, ["Talon"] = 2,
                  ["Taric"] = 5, ["Teemo"] = 2, ["Thresh"] = 5, ["Tristana"] = 1, ["Trundle"] = 4, ["Tryndamere"] = 2, ["TwistedFate"] = 2, ["Twitch"] = 1, ["Udyr"] = 4, ["Urgot"] = 4,
                  ["Varus"] = 1, ["Vayne"] = 1, ["Veigar"] = 2, ["Velkoz"] = 2, ["Vi"] = 4, ["Viktor"] = 2, ["Vladimir"] = 3, ["Volibear"] = 4, ["Warwick"] = 4, ["Xayah"] = 1,
                  ["Xerath"] = 2, ["XinZhao"] = 3, ["Yasuo"] = 2, ["Yorick"] = 4, ["Zac"] = 5, ["Zed"] = 2, ["Ziggs"] = 2, ["Zilean"] = 3, ["Zoe"] = 2, ["Zyra"] = 2
            }
            self.PriorityMultiplier = {
                  [1] = 1,
                  [2] = 1.15,
                  [3] = 1.3,
                  [4] = 1.45,
                  [5] = 1.6,
                  [6] = 1.75
            }
      end
      
      -- [ get selected target ]
      function gsoTS:GetSelectedTarget()
            return self.SelectedTarget
      end
      
      -- [ create priority menu ]
      function gsoTS:CreatePriorityMenu(charName)
            local priority = self.Priorities[charName] ~= nil and self.Priorities[charName] or 5
            _G.gsoSDK.OrbwalkerMenu.ts.priority:MenuElement({ id = charName, name = charName, value = priority, min = 1, max = 5, step = 1 })
      end
      
      -- [ create menu ]
      function gsoTS:CreateMenu(menu)
            _G.gsoSDK.OrbwalkerMenu:MenuElement({name = "Target Selector", id = "ts", type = MENU, leftIcon = "https://raw.githubusercontent.com/gamsteron/GoSExt/master/Icons/ts.png" })
                  _G.gsoSDK.OrbwalkerMenu.ts:MenuElement({ id = "Mode", name = "Mode", value = 1, drop = { "Auto", "Closest", "Least Health", "Least Priority" } })
                  _G.gsoSDK.OrbwalkerMenu.ts:MenuElement({ id = "priority", name = "Priorities", type = MENU })
                        _G.gsoSDK.ObjectManager:OnEnemyHeroLoad(function(hero) self:CreatePriorityMenu(hero.charName) end)
                  _G.gsoSDK.OrbwalkerMenu.ts:MenuElement({ id = "selected", name = "Selected Target", type = MENU })
                        _G.gsoSDK.OrbwalkerMenu.ts.selected:MenuElement({ id = "enable", name = "Enable", value = true })
                  _G.gsoSDK.OrbwalkerMenu.ts:MenuElement({name = "LastHit Mode", id = "lasthitmode", value = 1, drop = { "Accuracy", "Fast" } })
                  _G.gsoSDK.OrbwalkerMenu.ts:MenuElement({name = "LaneClear Should Wait Time", id = "shouldwaittime", value = 200, min = 0, max = 1000, step = 50, tooltip = "Less Value = Faster LaneClear" })
                  _G.gsoSDK.OrbwalkerMenu.ts:MenuElement({name = "LaneClear Harass", id = "laneset", value = true })
      end
      
      -- [ create draw menu ]
      function gsoTS:CreateDrawMenu(menu)
            _G.gsoSDK.OrbwalkerMenu.gsodraw:MenuElement({name = "Selected Target",  id = "selected", type = MENU})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.selected:MenuElement({name = "Enabled",  id = "enabled", value = true})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.selected:MenuElement({name = "Color",  id = "color", color = DrawColor(255, 204, 0, 0)})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.selected:MenuElement({name = "Width",  id = "width", value = 3, min = 1, max = 10})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.selected:MenuElement({name = "Radius",  id = "radius", value = 150, min = 1, max = 300})
            _G.gsoSDK.OrbwalkerMenu.gsodraw:MenuElement({name = "LastHitable Minion",  id = "lasthit", type = MENU})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.lasthit:MenuElement({name = "Enabled",  id = "enabled", value = true})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.lasthit:MenuElement({name = "Color",  id = "color", color = DrawColor(150, 255, 255, 255)})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.lasthit:MenuElement({name = "Width",  id = "width", value = 3, min = 1, max = 10})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.lasthit:MenuElement({name = "Radius",  id = "radius", value = 50, min = 1, max = 100})
            _G.gsoSDK.OrbwalkerMenu.gsodraw:MenuElement({name = "Almost LastHitable Minion",  id = "almostlasthit", type = MENU})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.almostlasthit:MenuElement({name = "Enabled",  id = "enabled", value = true})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.almostlasthit:MenuElement({name = "Color",  id = "color", color = DrawColor(150, 239, 159, 55)})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.almostlasthit:MenuElement({name = "Width",  id = "width", value = 3, min = 1, max = 10})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.almostlasthit:MenuElement({name = "Radius",  id = "radius", value = 50, min = 1, max = 100})
      end
      
      -- [ get target ]
      function gsoTS:GetTarget(enemyHeroes, dmgAP)
            local selectedID
            if _G.gsoSDK.OrbwalkerMenu.ts.selected.enable:Value() and self.SelectedTarget then
                  selectedID = self.SelectedTarget.networkID
            end
            local result = nil
            local num = 10000000
            local mode = _G.gsoSDK.OrbwalkerMenu.ts.Mode:Value()
            for i = 1, #enemyHeroes do
                  local x
                  local unit = enemyHeroes[i]
                  if selectedID and unit.networkID == selectedID then
                        return self.SelectedTarget
                  elseif mode == 1 then
                        local unitName = unit.charName
                        local multiplier = self.PriorityMultiplier[_G.gsoSDK.OrbwalkerMenu.ts.priority[unitName] and _G.gsoSDK.OrbwalkerMenu.ts.priority[unitName]:Value() or 6]
                        local def = dmgAP and multiplier * (unit.magicResist - myHero.magicPen) or multiplier * (unit.armor - myHero.armorPen)
                        if def > 0 then
                              def = dmgAP and myHero.magicPenPercent * def or myHero.bonusArmorPenPercent * def
                        end
                        x = ( ( unit.health * multiplier * ( ( 100 + def ) / 100 ) ) - ( unit.totalDamage * unit.attackSpeed * 2 ) ) - unit.ap
                  elseif mode == 2 then
                        x = unit.pos:DistanceTo(myHero.pos)
                  elseif mode == 3 then
                        x = unit.health
                  elseif mode == 4 then
                        local unitName = unit.charName
                        x = _G.gsoSDK.OrbwalkerMenu.ts.priority[unitName] and _G.gsoSDK.OrbwalkerMenu.ts.priority[unitName]:Value() or 6
                  end
                  if x < num then
                        num = x
                        result = unit
                  end
            end
            return result
      end
      
      -- [ get last hero target ]
      function gsoTS:GetLastHeroTarget()
            return self.LastHeroTarget
      end
      
      -- [ get farm minions ]
      function gsoTS:GetFarmMinions()
            return self.FarmMinions
      end
      
      -- [ get combo target ]
      function gsoTS:GetComboTarget()
            local comboT = self:GetTarget(_G.gsoSDK.ObjectManager:GetEnemyHeroes(myHero.range+myHero.boundingRadius - 35, true, "attack"), false)
            if comboT ~= nil then
                  self.LastHeroTarget = comboT
            end
            return comboT
      end
      
      -- [ get lasthit target ]
      function gsoTS:GetLastHitTarget()
            local min = 10000000
            local result = nil
            for i = 1, #self.FarmMinions do
                  local enemyMinion = self.FarmMinions[i]
                  if enemyMinion.LastHitable and enemyMinion.PredictedHP < min then
                        min = enemyMinion.PredictedHP
                        result = enemyMinion.Minion
                  end
            end
            if result ~= nil then
                  self.LastHandle = result.handle
            end
            return result
      end
      
      -- [ get laneclear target ]
      function gsoTS:GetLaneClearTarget()
            local enemyTurrets = _G.gsoSDK.ObjectManager:GetEnemyTurrets(myHero.range+myHero.boundingRadius - 35, true)
            for i = 1, #enemyTurrets do
                  return enemyTurrets[i]
            end
            if _G.gsoSDK.OrbwalkerMenu.ts.laneset:Value() then
                  local result = self:GetComboTarget()
                  if result then return result end
            end
            local result = nil
            if _G.gsoSDK.Farm:CanLaneClearTime() then
                  local min = 10000000
                  for i = 1, #self.FarmMinions do
                        local enemyMinion = self.FarmMinions[i]
                        if enemyMinion.PredictedHP < min then
                              min = enemyMinion.PredictedHP
                              result = enemyMinion.Minion
                        end
                  end
            end
            if result ~= nil then
                  self.LastLCHandle = result.handle
            end
            return result
      end
      
      -- [ get closest enemy ]
      function gsoTS:GetClosestEnemy(enemyList, maxDistance)
            local result = nil
            for i = 1, #enemyList do
                  local hero = enemyList[i]
                  local distance = myHero.pos:DistanceTo(hero.pos)
                  if distance < maxDistance then
                        maxDistance = distance
                        result = hero
                  end
            end
            return result
      end
      
      -- [ immobile time ]
      function gsoTS:ImmobileTime(unit)
            local iT = 0
            for i = 0, unit.buffCount do
                  local buff = unit:GetBuff(i)
                  if buff and buff.count > 0 then
                        local bType = buff.type
                        if bType == 5 or bType == 11 or bType == 21 or bType == 22 or bType == 24 or bType == 29 or buff.name == "recall" then
                              local bDuration = buff.duration
                              if bDuration > iT then
                                    iT = bDuration
                              end
                        end
                  end
            end
            return iT
      end
      
      -- [ get immobile enemy ]
      function gsoTS:GetImmobileEnemy(enemyList, maxDistance)
            local result = nil
            local num = 0
            for i = 1, #enemyList do
                  local hero = enemyList[i]
                  local distance = myHero.pos:DistanceTo(hero.pos)
                  local iT = self:ImmobileTime(hero)
                  if distance < maxDistance and iT > num then
                        num = iT
                        result = hero
                  end
            end
            return result
      end
      
      -- [ tick ]
      function gsoTS:Tick()
            local enemyMinions = _G.gsoSDK.ObjectManager:GetEnemyMinions(myHero.range + myHero.boundingRadius - 35, true)
            local allyMinions = _G.gsoSDK.ObjectManager:GetAllyMinions(1500, false)
            local lastHitMode = _G.gsoSDK.OrbwalkerMenu.ts.lasthitmode:Value() == 1 and "accuracy" or "fast"
            local cacheFarmMinions = {}
            for i = 1, #enemyMinions do
                  local enemyMinion = enemyMinions[i]
                  local FlyTime = myHero.attackData.windUpTime + ( myHero.pos:DistanceTo(enemyMinion.pos) / myHero.attackData.projectileSpeed )
                  cacheFarmMinions[#cacheFarmMinions+1] = _G.gsoSDK.Farm:SetLastHitable(enemyMinion, FlyTime, myHero.totalDamage, lastHitMode, allyMinions)
            end
            self.FarmMinions = cacheFarmMinions
      end
      
      -- [ wnd msg ]
      function gsoTS:WndMsg(msg, wParam)
            if msg == WM_LBUTTONDOWN and _G.gsoSDK.OrbwalkerMenu.ts.selected.enable:Value() and GetTickCount() > self.LastSelTick + 100 then
                  self.SelectedTarget = nil
                  local num = 10000000
                  local enemyList = _G.gsoSDK.ObjectManager:GetEnemyHeroes(99999999, false, "immortal")
                  for i = 1, #enemyList do
                        local unit = enemyList[i]
                        local distance = mousePos:DistanceTo(unit.pos)
                        if distance < 150 and distance < num then
                              self.SelectedTarget = unit
                              num = distance
                        end
                  end
                  self.LastSelTick = GetTickCount()
            end
      end
      
      -- [ draw ]
      function gsoTS:Draw()
            if _G.gsoSDK.OrbwalkerMenu.gsodraw.selected.enabled:Value() then
                  if self.SelectedTarget and not self.SelectedTarget.dead and self.SelectedTarget.isTargetable and self.SelectedTarget.visible and self.SelectedTarget.valid then
                        DrawCircle(self.SelectedTarget.pos, _G.gsoSDK.OrbwalkerMenu.gsodraw.selected.radius:Value(), _G.gsoSDK.OrbwalkerMenu.gsodraw.selected.width:Value(), _G.gsoSDK.OrbwalkerMenu.gsodraw.selected.color:Value())
                  end
            end
            if _G.gsoSDK.OrbwalkerMenu.gsodraw.lasthit.enabled:Value() or _G.gsoSDK.OrbwalkerMenu.gsodraw.almostlasthit.enabled:Value() then
                  for i = 1, #self.FarmMinions do
                        local minion = self.FarmMinions[i]
                        if minion.LastHitable and _G.gsoSDK.OrbwalkerMenu.gsodraw.lasthit.enabled:Value() then
                              DrawCircle(minion.Minion.pos, _G.gsoSDK.OrbwalkerMenu.gsodraw.lasthit.radius:Value(), _G.gsoSDK.OrbwalkerMenu.gsodraw.lasthit.width:Value(), _G.gsoSDK.OrbwalkerMenu.gsodraw.lasthit.color:Value())
                        elseif minion.AlmostLastHitable and _G.gsoSDK.OrbwalkerMenu.gsodraw.almostlasthit.enabled:Value() then
                              DrawCircle(minion.Minion.pos, _G.gsoSDK.OrbwalkerMenu.gsodraw.almostlasthit.radius:Value(), _G.gsoSDK.OrbwalkerMenu.gsodraw.almostlasthit.width:Value(), _G.gsoSDK.OrbwalkerMenu.gsodraw.almostlasthit.color:Value())
                        end
                  end
            end
      end





-- [ farm class ]
class "gsoFarm"

      -- [ init ]
      function gsoFarm:__init()
            self.ActiveAttacks = {}
            self.ShouldWait = false
            self.ShouldWaitTime = 0
            self.IsLastHitable = false
      end
      
      -- [ prediction pos ]
      function gsoFarm:PredPos(speed, pPos, unit)
            if unit.pathing.hasMovePath then
                  local uPos = unit.pos
                  local ePos = unit.pathing.endPos
                  local distUP = pPos:DistanceTo(uPos)
                  local distEP = pPos:DistanceTo(ePos)
                  local unitMS = unit.ms
                  if distEP > distUP then
                        return uPos:Extended(ePos, 25+(unitMS*(distUP / (speed - unitMS))))
                  else
                        return uPos:Extended(ePos, 25+(unitMS*(distUP / (speed + unitMS))))
                  end
            end
            return unit.pos
      end
      
      -- [ upate active attacks ]
      function gsoFarm:UpdateActiveAttacks()
            for k1, v1 in pairs(self.ActiveAttacks) do
                  local count = 0
                  for k2, v2 in pairs(self.ActiveAttacks[k1]) do
                        count = count + 1
                        if v2.Speed == 0 and (not v2.Ally or v2.Ally.dead) then
                              self.ActiveAttacks[k1] = nil
                              break
                        end
                        if not v2.Canceled then
                              local ranged = v2.Speed > 0
                              if ranged then
                                    self.ActiveAttacks[k1][k2].FlyTime = v2.Ally.pos:DistanceTo(self:PredPos(v2.Speed, v2.Pos, v2.Enemy)) / v2.Speed
                              end
                              local latency = _G.gsoSDK.OrbwalkerMenu.orb.clat.enabled:Value() and _G.gsoSDK.OrbwalkerMenu.orb.clat.latvalue:Value() * 0.001 or GameLatency() * 0.001
                              local projectileOnEnemy = 0.025 + latency
                              if GameTimer() > v2.StartTime + self.ActiveAttacks[k1][k2].FlyTime - projectileOnEnemy or not v2.Enemy or v2.Enemy.dead then
                                    self.ActiveAttacks[k1][k2] = nil
                              elseif ranged then
                                    self.ActiveAttacks[k1][k2].Pos = v2.Ally.pos:Extended(v2.Enemy.pos, ( GameTimer() - v2.StartTime ) * v2.Speed)
                              end
                        end
                  end
                  if count == 0 then
                        self.ActiveAttacks[k1] = nil
                  end
            end
      end
      
      -- [ set lasthitable ]
      function gsoFarm:SetLastHitable(enemyMinion, time, damage, mode, allyMinions)
            if mode == "fast" then
                  local hpPred = self:MinionHpPredFast(enemyMinion, allyMinions, time)
                  local lastHitable = hpPred - damage < 0
                  if lastHitable then self.IsLastHitable = true end
                  local almostLastHitable = lastHitable and false or self:MinionHpPredFast(enemyMinion, allyMinions, myHero.attackData.animationTime * 3) - damage < 0
                  if almostLastHitable then
                        self.ShouldWait = true
                        self.ShouldWaitTime = GameTimer()
                  end
                  return { LastHitable =  lastHitable, Unkillable = hpPred < 0, AlmostLastHitable = almostLastHitable, PredictedHP = hpPred, Minion = enemyMinion }
            elseif mode == "accuracy" then
                  local hpPred = self:MinionHpPredAccuracy(enemyMinion, time)
                  local lastHitable = hpPred - damage < 0
                  if lastHitable then self.IsLastHitable = true end
                  local almostLastHitable = lastHitable and false or self:MinionHpPredFast(enemyMinion, allyMinions, myHero.attackData.animationTime * 3) - damage < 0
                  if almostLastHitable then
                        self.ShouldWait = true
                        self.ShouldWaitTime = GameTimer()
                  end
                  return { LastHitable =  lastHitable, Unkillable = hpPred < 0, AlmostLastHitable = almostLastHitable, PredictedHP = hpPred, Minion = enemyMinion }
            end
      end
      
      -- [ can lasthit ]
      function gsoFarm:CanLastHit()
            return self.IsLastHitable
      end
      
      -- [ can laneclear ]
      function gsoFarm:CanLaneClear()
            return not self.ShouldWait
      end
      
      -- [ can laneclear time ]
      function gsoFarm:CanLaneClearTime()
            local shouldWait = _G.gsoSDK.OrbwalkerMenu.ts.shouldwaittime:Value() * 0.001
            return GameTimer() > self.ShouldWaitTime + shouldWait
      end
      
      -- [ minion hp pred fast ]
      function gsoFarm:MinionHpPredFast(unit, allyMinions, time)
            local unitHandle, unitPos, unitHealth = unit.handle, unit.pos, unit.health
            for i = 1, #allyMinions do
                  local allyMinion = allyMinions[i]
                  if allyMinion.attackData.target == unitHandle then
                        local minionDmg = (allyMinion.totalDamage*(1+allyMinion.bonusDamagePercent))-unit.flatDamageReduction
                        local flyTime = allyMinion.attackData.projectileSpeed > 0 and allyMinion.pos:DistanceTo(unitPos) / allyMinion.attackData.projectileSpeed or 0
                        local endTime = (allyMinion.attackData.endTime - allyMinion.attackData.animationTime) + flyTime + allyMinion.attackData.windUpTime
                        endTime = endTime > GameTimer() and endTime or endTime + allyMinion.attackData.animationTime + flyTime
                        while endTime - GameTimer() < time do
                              unitHealth = unitHealth - minionDmg
                              endTime = endTime + allyMinion.attackData.animationTime + flyTime
                        end
                  end
            end
            return unitHealth
      end
      
      -- [ minion hp pred accuracy ]
      function gsoFarm:MinionHpPredAccuracy(unit, time)
            local unitHealth, unitHandle = unit.health, unit.handle
            for allyID, allyActiveAttacks in pairs(self.ActiveAttacks) do
                  for activeAttackID, activeAttack in pairs(self.ActiveAttacks[allyID]) do
                        if not activeAttack.Canceled and unitHandle == activeAttack.Enemy.handle then
                              local endTime = activeAttack.StartTime + activeAttack.FlyTime
                              if endTime > GameTimer() and endTime - GameTimer() < time then
                                    unitHealth = unitHealth - activeAttack.Dmg
                              end
                        end
                  end
            end
            return unitHealth
      end
      
      -- [ tick ]
      function gsoFarm:Tick(allyMinions, enemyMinions)
            for i = 1, #allyMinions do
                  local allyMinion = allyMinions[i]
                  if allyMinion.attackData.endTime > GameTimer() then
                        for j = 1, #enemyMinions do
                              local enemyMinion = enemyMinions[j]
                              if enemyMinion.handle == allyMinion.attackData.target then
                                    local flyTime = allyMinion.attackData.projectileSpeed > 0 and allyMinion.pos:DistanceTo(enemyMinion.pos) / allyMinion.attackData.projectileSpeed or 0
                                    if not self.ActiveAttacks[allyMinion.handle] then
                                          self.ActiveAttacks[allyMinion.handle] = {}
                                    end
                                    if GameTimer() < (allyMinion.attackData.endTime - allyMinion.attackData.windDownTime) + flyTime then
                                          if allyMinion.attackData.projectileSpeed > 0 then
                                                if GameTimer() > allyMinion.attackData.endTime - allyMinion.attackData.windDownTime then
                                                      if not self.ActiveAttacks[allyMinion.handle][allyMinion.attackData.endTime] then
                                                            self.ActiveAttacks[allyMinion.handle][allyMinion.attackData.endTime] = {
                                                                  Canceled = false,
                                                                  Speed = allyMinion.attackData.projectileSpeed,
                                                                  StartTime = allyMinion.attackData.endTime - allyMinion.attackData.windDownTime,
                                                                  FlyTime = flyTime,
                                                                  Pos = allyMinion.pos:Extended(enemyMinion.pos, allyMinion.attackData.projectileSpeed * ( GameTimer() - ( allyMinion.attackData.endTime - allyMinion.attackData.windDownTime ) ) ),
                                                                  Ally = allyMinion,
                                                                  Enemy = enemyMinion,
                                                                  Dmg = (allyMinion.totalDamage*(1+allyMinion.bonusDamagePercent))-enemyMinion.flatDamageReduction
                                                            }
                                                      end
                                                elseif allyMinion.pathing.hasMovePath then
                                                      self.ActiveAttacks[allyMinion.handle][allyMinion.attackData.endTime] = {
                                                            Canceled = true,
                                                            Ally = allyMinion
                                                      }
                                                end
                                          elseif not self.ActiveAttacks[allyMinion.handle][allyMinion.attackData.endTime] then
                                                self.ActiveAttacks[allyMinion.handle][allyMinion.attackData.endTime] = {
                                                      Canceled = false,
                                                      Speed = allyMinion.attackData.projectileSpeed,
                                                      StartTime = (allyMinion.attackData.endTime - allyMinion.attackData.windDownTime) - allyMinion.attackData.windUpTime,
                                                      FlyTime = allyMinion.attackData.windUpTime,
                                                      Pos = allyMinion.pos,
                                                      Ally = allyMinion,
                                                      Enemy = enemyMinion,
                                                      Dmg = (allyMinion.totalDamage*(1+allyMinion.bonusDamagePercent))-enemyMinion.flatDamageReduction
                                                }
                                          end
                                    end
                                    break
                              end
                        end
                  end
            end
            self:UpdateActiveAttacks()
            self.IsLastHitable = false
            self.ShouldWait = false
      end





-- [ object manager class ]
class "gsoOB"

      -- [ init ]
      function gsoOB:__init()
            self.ClassLoadT = GameTimer()
            self.LoadedChamps = false
            self.AllyHeroes = {}
            self.EnemyHeroes = {}
            self.AllyHeroLoad = {}
            self.EnemyHeroLoad = {}
            self.UndyingBuffs = { ["zhonyasringshield"] = true }
            self.EnemyBarracks = {}
            self.EnemyNexus = nil
            self.BuildingsLoaded = false
      end
      
      -- [ on ally hero load ]
      function gsoOB:OnAllyHeroLoad(func)
            self.AllyHeroLoad[#self.AllyHeroLoad+1] = func
      end
      
      -- [ on enemy hero load ]
      function gsoOB:OnEnemyHeroLoad(func)
            self.EnemyHeroLoad[#self.EnemyHeroLoad+1] = func
      end
      
      -- [ is unit valid ]
      function gsoOB:IsUnitValid(unit, range, bb)
            local extraRange = bb and unit.boundingRadius or 0
            if  unit.pos:DistanceTo(myHero.pos) < range + extraRange and not unit.dead and unit.isTargetable and unit.valid and unit.visible then
                  return true
            end
            return false
      end
      
      -- [ is unit valid - no visible check ]
      function gsoOB:IsUnitValid_invisible(unit, range, bb)
            local extraRange = bb and unit.boundingRadius or 0
            if  unit.pos:DistanceTo(myHero.pos) < range + extraRange and not unit.dead and unit.isTargetable and unit.valid then
                  return true
            end
            return false
      end
      
      -- [ is hero immortal ]
      function gsoOB:IsHeroImmortal(unit, jaxE)
            local hp = 100 * ( unit.health / unit.maxHealth )
            if self.UndyingBuffs["JaxCounterStrike"] ~= nil then self.UndyingBuffs["JaxCounterStrike"] = jaxE end
            if self.UndyingBuffs["kindredrnodeathbuff"] ~= nil then self.UndyingBuffs["kindredrnodeathbuff"] = hp < 10 end
            if self.UndyingBuffs["UndyingRage"] ~= nil then self.UndyingBuffs["UndyingRage"] = hp < 15 end
            if self.UndyingBuffs["ChronoShift"] ~= nil then self.UndyingBuffs["ChronoShift"] = hp < 15; self.UndyingBuffs["chronorevive"] = hp < 15 end
            for i = 0, unit.buffCount do
                  local buff = unit:GetBuff(i)
                  if buff and buff.count > 0 and self.UndyingBuffs[buff.name] then
                        return true
                  end
            end
            return false
      end
      
      -- [ get ally heroes ]
      function gsoOB:GetAllyHeroes(range, bb)
            local result = {}
            for i = 1, GameHeroCount() do
                  local hero = GameHero(i)
                  if hero and hero.team == myHero.team and self:IsUnitValid(hero, range, bb) then
                        result[#result+1] = hero
                  end
            end
            return result
      end
      
      -- [ get enemy heroes ]
      function gsoOB:GetEnemyHeroes(range, bb, state)
            local result = {}
            if state == "spell" then
                  for i = 1, GameHeroCount() do
                        local hero = GameHero(i)
                        if hero and hero.team ~= myHero.team and self:IsUnitValid(hero, range, bb) and not self:IsHeroImmortal(hero, false) then
                              result[#result+1] = hero
                        end
                  end
            elseif state == "attack" then
                  for i = 1, GameHeroCount() do
                        local hero = GameHero(i)
                        if hero and hero.team ~= myHero.team and self:IsUnitValid(hero, range, bb) and not self:IsHeroImmortal(hero, true) then
                              result[#result+1] = hero
                        end
                  end
            elseif state == "immortal" then
                  for i = 1, GameHeroCount() do
                        local hero = GameHero(i)
                        if hero and hero.team ~= myHero.team and self:IsUnitValid(hero, range, bb) then
                              result[#result+1] = hero
                        end
                  end
            elseif state == "spell_invisible" then
                  for i = 1, GameHeroCount() do
                        local hero = GameHero(i)
                        if hero and hero.team ~= myHero.team and self:IsUnitValid_invisible(hero, range, bb) then
                              result[#result+1] = hero
                        end
                  end
            end
            return result
      end
      
      -- [ get ally turrets ]
      function gsoOB:GetAllyTurrets(range, bb)
            local result = {}
            for i = 1, GameTurretCount() do
                  local turret = GameTurret(i)
                  if turret and turret.team == myHero.team and self:IsUnitValid(turret, range, bb)  then
                        result[#result+1] = turret
                  end
            end
            return result
      end
      
      -- [ get enemy turrets ]
      function gsoOB:GetEnemyTurrets(range, bb)
            local result = {}
            for i = 1, GameTurretCount() do
                  local turret = GameTurret(i)
                  if turret and turret.team ~= myHero.team and self:IsUnitValid(turret, range, bb) and not turret.isImmortal then
                        result[#result+1] = turret
                  end
            end
            for i = 1, #self.EnemyBarracks do
                  local barrack = self.EnemyBarracks[i]
                  if barrack and not barrack.dead and barrack.isTargetable and barrack.visible and barrack.pos:DistanceTo(myHero.pos) < myHero.range + 270 then
                        result[#result+1] = barrack
                  end
            end
            if self.EnemyNexus and not self.EnemyNexus.dead and self.EnemyNexus.isTargetable and self.EnemyNexus.visible and self.EnemyNexus.pos:DistanceTo(myHero.pos) < myHero.range + 380 then
                  result[#result+1] = self.EnemyNexus
            end
            return result
      end
      
      -- [ get ally minions ]
      function gsoOB:GetAllyMinions(range, bb)
            local result = {}
            for i = 1, GameMinionCount() do
                  local minion = GameMinion(i)
                  if minion and minion.team == myHero.team and self:IsUnitValid(minion, range, bb) then
                        result[#result+1] = minion
                  end
            end
            return result
      end
      
      -- [ get enemy minions ]
      function gsoOB:GetEnemyMinions(range, bb)
            local result = {}
            for i = 1, GameMinionCount() do
                  local minion = GameMinion(i)
                  if minion and minion.team ~= myHero.team and self:IsUnitValid(minion, range, bb) and not minion.isImmortal then
                        result[#result+1] = minion
                  end
            end
            return result
      end
      
      -- [ tick ]
      function gsoOB:Tick()
            for i = 1, GameHeroCount() do end
            for i = 1, GameTurretCount() do end
            for i = 1, GameMinionCount() do end
            if self.LoadedChamps then return end
            for i = 1, GameHeroCount() do
                  local hero = GameHero(i)
                  local eName = hero.charName
                  if eName and #eName > 0 then
                        local isNewHero = true
                        if hero.team ~= myHero.team then
                              for j = 1, #self.EnemyHeroes do
                                    if hero == self.EnemyHeroes[j] then
                                          isNewHero = false
                                          break
                                    end
                              end
                              if isNewHero then
                                    self.EnemyHeroes[#self.EnemyHeroes+1] = hero
                                    if eName == "Kayle" then self.UndyingBuffs["JudicatorIntervention"] = true
                                    elseif eName == "Taric" then self.UndyingBuffs["TaricR"] = true
                                    elseif eName == "Kindred" then self.UndyingBuffs["kindredrnodeathbuff"] = true
                                    elseif eName == "Zilean" then self.UndyingBuffs["ChronoShift"] = true; self.UndyingBuffs["chronorevive"] = true
                                    elseif eName == "Tryndamere" then self.UndyingBuffs["UndyingRage"] = true
                                    elseif eName == "Jax" then self.UndyingBuffs["JaxCounterStrike"] = true; gsoIsJax = true
                                    elseif eName == "Fiora" then self.UndyingBuffs["FioraW"] = true
                                    elseif eName == "Aatrox" then self.UndyingBuffs["aatroxpassivedeath"] = true
                                    elseif eName == "Vladimir" then self.UndyingBuffs["VladimirSanguinePool"] = true
                                    elseif eName == "KogMaw" then self.UndyingBuffs["KogMawIcathianSurprise"] = true
                                    elseif eName == "Karthus" then self.UndyingBuffs["KarthusDeathDefiedBuff"] = true
                                    end
                              end
                        else
                              for j = 1, #self.AllyHeroes do
                                    if hero == self.AllyHeroes[j] then
                                          isNewHero = false
                                          break
                                    end
                              end
                              if isNewHero then
                                    self.AllyHeroes[#self.AllyHeroes+1] = hero
                              end
                        end
                  end
            end
            if GameTimer() > self.ClassLoadT + 3 then
                  if not self.BuildingsLoaded then
                        for i = 1, GameObjectCount() do
                              local object = GameObject(i)
                              if object ~= nil and object.isEnemy then
                                    local oType = object.type
                                    if oType == Obj_AI_Barracks then
                                          self.EnemyBarracks[#self.EnemyBarracks+1] = object
                                    elseif oType == Obj_AI_Nexus then
                                          self.EnemyNexus = object
                                    end
                              end
                        end
                        self.BuildingsLoaded = true
                  end
                  local numOfHeroes = 5
                  if #self.AllyHeroes == 1 then
                        numOfHeroes = 1
                  end
                  if #self.AllyHeroes == numOfHeroes and #self.EnemyHeroes == numOfHeroes then
                        self.LoadedChamps = true
                        for i = 1, #self.AllyHeroes do
                              for j = 1, #self.AllyHeroLoad do
                                    self.AllyHeroLoad[j](self.AllyHeroes[i])
                              end
                        end
                        for i = 1, #self.EnemyHeroes do
                              for j = 1, #self.EnemyHeroLoad do
                                    self.EnemyHeroLoad[j](self.EnemyHeroes[i])
                              end
                        end
                  end
            end
      end





-- [ orbwalker class ]
class "gsoOrbwalker"

      -- [ init ]
      function gsoOrbwalker:__init()
            -- attack
            self.WaitForResponse = false
            self.AttackStartTime = 0
            self.AttackEndTime = 0
            self.AttackCastEndTime = 0
            self.AttackLocalStart = 0
            self.AttackSpeed = myHero.attackSpeed
            self.AttackWindUp = myHero.attackData.windUpTime
            self.AttackAnim = myHero.attackData.animationTime
            -- move
            self.LastMoveLocal = 0
            self.LastMoveTime = 0
            self.LastMovePos = myHero.pos
            -- mouse
            self.LastMouseDown = 0
            -- callbacks
            self.OnPreAttackC = {}
            self.OnPostAttackC = {}
            self.OnAttackC = {}
            self.OnPreMoveC = {}
            -- debug
            self.TestCount = 0
            self.TestStartTime = 0
            -- other
            self.PostAttackBool = false
            self.AttackEnabled = true
            self.MovementEnabled = true
            self.IsTeemo = false
            self.IsBlindedByTeemo = false
            self.ResetAttack = false
            _G.gsoSDK.ObjectManager:OnEnemyHeroLoad(function(hero) if hero.charName == "Teemo" then self.IsTeemo = true end end)
            self.CanAttackC = function() return true end
            self.CanMoveC = function() return true end
      end
      
      -- [ create menu ]
      function gsoOrbwalker:CreateMenu()
            _G.gsoSDK.OrbwalkerMenu:MenuElement({name = "Orbwalker", id = "orb", type = MENU, leftIcon = "https://raw.githubusercontent.com/gamsteron/GoSExt/master/Icons/orb.png" })
                  _G.gsoSDK.OrbwalkerMenu.orb:MenuElement({name = "Player Attack Move Click", id = "aamoveclick", key = string.byte("[")})
                  _G.gsoSDK.OrbwalkerMenu.orb:MenuElement({name = "Keys", id = "keys", type = MENU})
                        _G.gsoSDK.OrbwalkerMenu.orb.keys:MenuElement({name = "Combo Key", id = "combo", key = string.byte(" ")})
                        _G.gsoSDK.OrbwalkerMenu.orb.keys:MenuElement({name = "Harass Key", id = "harass", key = string.byte("C")})
                        _G.gsoSDK.OrbwalkerMenu.orb.keys:MenuElement({name = "LastHit Key", id = "lasthit", key = string.byte("X")})
                        _G.gsoSDK.OrbwalkerMenu.orb.keys:MenuElement({name = "LaneClear Key", id = "laneclear", key = string.byte("V")})
                        _G.gsoSDK.OrbwalkerMenu.orb.keys:MenuElement({name = "Flee Key", id = "flee", key = string.byte("Z")})
                  _G.gsoSDK.OrbwalkerMenu.orb:MenuElement({ name = "Custom Latency", id = "clat", type = MENU })
                        _G.gsoSDK.OrbwalkerMenu.orb.clat:MenuElement({name = "Enabled",  id = "enabled", value = false})
                        _G.gsoSDK.OrbwalkerMenu.orb.clat:MenuElement({name = "Latency", id = "latvalue", value = 67, min = 0, max = 200, step = 1 })
                  _G.gsoSDK.OrbwalkerMenu.orb:MenuElement({name = "Extra WindUp Delay", tooltip = "Less Value = Better KITE", id = "windupdelay", value = 0, min = 0, max = 50, step = 5 })
                  _G.gsoSDK.OrbwalkerMenu.orb:MenuElement({name = "Extra Anim Delay", tooltip = "Less Value = Better DPS [ for me 80 is ideal ] - lower value than 80 cause slow KITE ! Maybe for your PC ideal value is 0 ? You need test it in debug mode.", id = "animdelay", value = 80, min = 0, max = 150, step = 10 })
                  _G.gsoSDK.OrbwalkerMenu.orb:MenuElement({name = "Extra LastHit Delay", tooltip = "Less Value = Faster Last Hit Reaction", id = "lhDelay", value = 0, min = 0, max = 50, step = 1 })
                  _G.gsoSDK.OrbwalkerMenu.orb:MenuElement({name = "Extra Move Delay", tooltip = "Less Value = More Movement Clicks Per Sec", id = "humanizer", value = 120, min = 120, max = 300, step = 10 })
                  _G.gsoSDK.OrbwalkerMenu.orb:MenuElement({name = "Extra Server Timeout", tooltip = "Less Value = Faster reaction after bad response from server", id = "timeout", value = 100, min = 0, max = 200, step = 10 })
                  _G.gsoSDK.OrbwalkerMenu.orb:MenuElement({name = "Debug Mode", tooltip = "Will Print Some Data", id = "enabled", value = false})
      end
      
      -- [ create draw menu ]
      function gsoOrbwalker:CreateDrawMenu(menu)
            _G.gsoSDK.OrbwalkerMenu.gsodraw:MenuElement({name = "MyHero Attack Range", id = "me", type = MENU})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.me:MenuElement({name = "Enabled",  id = "enabled", value = true})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.me:MenuElement({name = "Color",  id = "color", color = DrawColor(255, 255, 255, 255)})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.me:MenuElement({name = "Width",  id = "width", value = 3, min = 1, max = 10})
            _G.gsoSDK.OrbwalkerMenu.gsodraw:MenuElement({name = "Enemy Attack Range", id = "he", type = MENU})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.he:MenuElement({name = "Enabled",  id = "enabled", value = true})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.he:MenuElement({name = "Color",  id = "color", color = DrawColor(255, 255, 0, 0)})
                  _G.gsoSDK.OrbwalkerMenu.gsodraw.he:MenuElement({name = "Width",  id = "width", value = 3, min = 1, max = 10})
      end
      
      -- [ check teemo blind ]
      function gsoOrbwalker:CheckTeemoBlind()
            for i = 0, myHero.buffCount do
                  local buff = myHero:GetBuff(i)
                  if buff and buff.count > 0 and buff.name:lower() == "blindingdart" and buff.duration > 0 then
                        return true
                  end
            end
            return false
      end
      
      -- [ is before attack ]
      function gsoOrbwalker:IsBeforeAttack(multipier)
            if GameTimer() > self.AttackLocalStart + multipier * myHero.attackData.animationTime then
                  return true
            else
                  return false
            end
      end
      
      -- [ on pre attack ]
      function gsoOrbwalker:OnPreAttack(func)
            self.OnPreAttackC[#self.OnPreAttackC+1] = func
      end
      
      -- [ on post attack ]
      function gsoOrbwalker:OnPostAttack(func)
            self.OnPostAttackC[#self.OnPostAttackC+1] = func
      end
      
      -- [ on attack ]
      function gsoOrbwalker:OnAttack(func)
            self.OnAttackC[#self.OnAttackC+1] = func
      end
      
      -- [ on pre movement ]
      function gsoOrbwalker:OnPreMovement(func)
            self.OnPreMoveC[#self.OnPreMoveC+1] = func
      end
      
      -- [ get mode ]
      function gsoOrbwalker:GetMode()
            if _G.gsoSDK.OrbwalkerMenu.orb.keys.combo:Value() then
                  return "Combo"
            elseif _G.gsoSDK.OrbwalkerMenu.orb.keys.harass:Value() then
                  return "Harass"
            elseif _G.gsoSDK.OrbwalkerMenu.orb.keys.lasthit:Value() then
                  return "Lasthit"
            elseif _G.gsoSDK.OrbwalkerMenu.orb.keys.laneclear:Value() then
                  return "Clear"
            elseif _G.gsoSDK.OrbwalkerMenu.orb.keys.flee:Value() then
                  return "Flee"
            else
                  return "None"
            end
      end
      
      -- [ draw ]
      function gsoOrbwalker:Draw()
            if _G.gsoSDK.OrbwalkerMenu.gsodraw.me.enabled:Value() and myHero.pos:ToScreen().onScreen then
                  DrawCircle(myHero.pos, myHero.range + myHero.boundingRadius + 35, _G.gsoSDK.OrbwalkerMenu.gsodraw.me.width:Value(), _G.gsoSDK.OrbwalkerMenu.gsodraw.me.color:Value())
            end
            if _G.gsoSDK.OrbwalkerMenu.gsodraw.he.enabled:Value() then
                  local enemyHeroes = _G.gsoSDK.ObjectManager:GetEnemyHeroes(99999999, false, "immortal")
                  for i = 1, #enemyHeroes do
                        local enemy = enemyHeroes[i]
                        if enemy.pos:ToScreen().onScreen then
                              DrawCircle(enemy.pos, enemy.range + enemy.boundingRadius + 35, _G.gsoSDK.OrbwalkerMenu.gsodraw.he.width:Value(), _G.gsoSDK.OrbwalkerMenu.gsodraw.he.color:Value())
                        end
                  end
            end
      end
      
      -- [ can attack event ]
      function gsoOrbwalker:CanAttackEvent(func)
            self.CanAttackC = func
      end
      
      -- [ can move event ]
      function gsoOrbwalker:CanMoveEvent(func)
            self.CanMoveC = func
      end
      
      -- [ attack ]
      function gsoOrbwalker:Attack(unit)
            self.WaitForResponse = true
            self.ResetAttack = false
            _G.gsoSDK.Cursor:SetCursor(cursorPos, unit.pos, 0.06)
            ControlSetCursorPos(unit.pos)
            local attackKey = _G.gsoSDK.OrbwalkerMenu.orb.aamoveclick:Key()
            ControlKeyDown(attackKey)
            ControlKeyUp(attackKey)
            self.LastMoveLocal = 0
            self.AttackLocalStart = GameTimer()
      end
      
      -- [ move ]
      function gsoOrbwalker:Move()
            if ControlIsKeyDown(2) then self.LastMouseDown = GameTimer() end
            self.LastMovePos = mousePos
            ControlMouseEvent(MOUSEEVENTF_RIGHTDOWN)
            ControlMouseEvent(MOUSEEVENTF_RIGHTUP)
            self.LastMoveLocal = GameTimer() + _G.gsoSDK.OrbwalkerMenu.orb.humanizer:Value() * 0.001
            self.LastMoveTime = GameTimer()
      end
      
      -- [ move to pos ]
      function gsoOrbwalker:MoveToPos(pos)
            if ControlIsKeyDown(2) then self.LastMouseDown = GameTimer() end
            _G.gsoSDK.Cursor:SetCursor(cursorPos, pos, 0.06)
            ControlSetCursorPos(pos)
            ControlMouseEvent(MOUSEEVENTF_RIGHTDOWN)
            ControlMouseEvent(MOUSEEVENTF_RIGHTUP)
            self.LastMoveLocal = GameTimer() + _G.gsoSDK.OrbwalkerMenu.orb.humanizer:Value() * 0.001
            self.LastMoveTime = GameTimer()
      end
      
      -- [ can attack ]
      function gsoOrbwalker:CanAttack()
            if not self.CanAttackC() then return false end
            if self.IsBlindedByTeemo then
                  return false
            end
            -- wait for response from server
            if self.WaitForResponse then
                  return false
            end
            if self.ResetAttack then
                  if GameTimer() < self.AttackLocalStart + 0.3 then
                        self.ResetAttack = false
                        return false
                  end
                  return true
            end
            local menuAnim = _G.gsoSDK.OrbwalkerMenu.orb.animdelay:Value() * 0.001
            local latency = _G.gsoSDK.OrbwalkerMenu.orb.clat.enabled:Value() and _G.gsoSDK.OrbwalkerMenu.orb.clat.latvalue:Value() * 0.001 or GameLatency() * 0.001
            if GameTimer() < self.AttackStartTime + myHero.attackData.animationTime + menuAnim - 0.15 - latency then
                  return false
            end
            return true
      end
      
      -- [ can move ]
      function gsoOrbwalker:CanMove(extraDelay)
            local onlyMove = extraDelay == 0
            if onlyMove and not self.CanMoveC() then return false end
            -- wait for response from server
            if self.WaitForResponse then
                  return false
            end
            if onlyMove and GameTimer() < self.AttackLocalStart + myHero.attackData.windUpTime then
                  return false
            end
            local menuWindUp = _G.gsoSDK.OrbwalkerMenu.orb.windupdelay:Value() * 0.001
            local latency = _G.gsoSDK.OrbwalkerMenu.orb.clat.enabled:Value() and _G.gsoSDK.OrbwalkerMenu.orb.clat.latvalue:Value() * 0.001 or GameLatency() * 0.001
            if GameTimer() < self.AttackCastEndTime + menuWindUp + extraDelay - latency then
                  return false
            end
            return true
      end
      
      -- [ attack move ]
      function gsoOrbwalker:AttackMove(unit)
            if self.AttackEnabled and unit and unit.pos:ToScreen().onScreen and self:CanAttack() then
                  local args = { Target = unit, Process = true }
                  for i = 1, #self.OnPreAttackC do
                        self.OnPreAttackC[i](args)
                  end
                  if args.Process and args.Target and not args.Target.dead and args.Target.isTargetable and args.Target.valid then
                        self:Attack(args.Target)
                        self.PostAttackBool = true
                  end
            elseif self.MovementEnabled and self:CanMove(0) then
                  if self.PostAttackBool then
                        for i = 1, #self.OnPostAttackC do
                              self.OnPostAttackC[i]()
                        end
                        self.PostAttackBool = false
                  end
                  if GameTimer() > self.LastMoveLocal then
                        local args = { Target = nil, Process = true }
                        for i = 1, #self.OnPreMoveC do
                              self.OnPreMoveC[i](args)
                        end
                        if args.Process then
                              if not args.Target then
                                    self:Move()
                              elseif args.Target.x then
                                    self:MoveToPos(args.Target)
                              elseif args.Target.pos then
                                    self:MoveToPos(args.Target.pos)
                              else
                                    assert(false, "Gamsteron OnPreMovement Event: expected Vector !")
                              end
                        end
                  end
            end
      end
      
      -- [ tick ]
      function gsoOrbwalker:Tick()
            --[[local baseAnimationTime = myHero.attackSpeed * (1 / myHero.attackData.animationTime / myHero.attackSpeed)
            local baseWindUpTime = myHero.attackData.windUpTime / myHero.attackData.animationTime
            local animationTime = 1 / baseAnimationTime
            local windUpTime = animationTime * baseWindUpTime
            print(tostring(animationTime) .. " " .. tostring(myHero.attackData.animationTime))
            print(tostring(windUpTime) .. " " .. tostring(myHero.attackData.windUpTime))--]]
            if _G.Orbwalker.Enabled:Value() then _G.Orbwalker.Enabled:Value(false) end
            if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Loaded and _G.SDK.Orbwalker.Menu.Enabled:Value() then _G.SDK.Orbwalker.Menu.Enabled:Value(false) end
            if self.IsTeemo then self.IsBlindedByTeemo = self:CheckTeemoBlind() end
            local meAAData = myHero.attackData
            if meAAData.endTime > self.AttackEndTime then
                  self.WaitForResponse = false
                  for i = 1, #self.OnAttackC do
                        self.OnAttackC[i]()
                  end
                  self.AttackSpeed = myHero.attackSpeed
                  self.AttackWindUp = meAAData.windUpTime
                  self.AttackAnim = meAAData.animationTime
                  self.AttackStartTime = meAAData.endTime - meAAData.animationTime
                  self.AttackEndTime = meAAData.endTime
                  self.AttackCastEndTime = meAAData.endTime - meAAData.windDownTime
                  if _G.gsoSDK.OrbwalkerMenu.orb.enabled:Value() then
                        if self.TestCount == 0 then
                              self.TestStartTime = GameTimer()
                        end
                        self.TestCount = self.TestCount + 1
                        if self.TestCount == 5 then
                              print("5 attacks in time: " .. tostring(GameTimer() - self.TestStartTime) .. "[sec]")
                              self.TestCount = 0
                              self.TestStartTime = 0
                        end
                  end
            end
            --
            if self.WaitForResponse then
                  local menuTimeout = _G.gsoSDK.OrbwalkerMenu.orb.timeout:Value() * 0.001
                  local latency = _G.gsoSDK.OrbwalkerMenu.orb.clat.enabled:Value() and _G.gsoSDK.OrbwalkerMenu.orb.clat.latvalue:Value() * 0.001 or GameLatency() * 0.001
                  if GameTimer() > self.AttackLocalStart + 0.12 + menuTimeout + latency then
                        --print("timeout " .. tostring(GameTimer()))
                        self.WaitForResponse = false
                  end
            end
            --
            local isEvading = ExtLibEvade and ExtLibEvade.Evading
            if not _G.gsoSDK.Cursor:IsCursorReady() or GameIsChatOpen() or isEvading then
                  return
            end
            if _G.gsoSDK.OrbwalkerMenu.orb.keys.combo:Value() then
                  self:AttackMove(_G.gsoSDK.TargetSelector:GetComboTarget())
            elseif _G.gsoSDK.OrbwalkerMenu.orb.keys.harass:Value() then
                  if _G.gsoSDK.Farm:CanLastHit() then
                        self:AttackMove(_G.gsoSDK.TargetSelector:GetLastHitTarget())
                  else
                        self:AttackMove(_G.gsoSDK.TargetSelector:GetComboTarget())
                  end
            elseif _G.gsoSDK.OrbwalkerMenu.orb.keys.lasthit:Value() then
                  self:AttackMove(_G.gsoSDK.TargetSelector:GetLastHitTarget())
            elseif _G.gsoSDK.OrbwalkerMenu.orb.keys.laneclear:Value() then
                  if _G.gsoSDK.Farm:CanLastHit() then
                        self:AttackMove(_G.gsoSDK.TargetSelector:GetLastHitTarget())
                  elseif _G.gsoSDK.Farm:CanLaneClear() then
                        self:AttackMove(_G.gsoSDK.TargetSelector:GetLaneClearTarget())
                  else
                        self:AttackMove()
                  end
            elseif _G.gsoSDK.OrbwalkerMenu.orb.keys.flee:Value() then
                  if self.MovementEnabled and GameTimer() > self.LastMoveLocal and self:CanMove(0) then
                        self:Move()
                  end
            elseif GameTimer() < self.LastMouseDown + 1 then
                  ControlMouseEvent(MOUSEEVENTF_RIGHTDOWN)
                  self.LastMouseDown = 0
            end
      end





Callback.Add('Load', function()
      _G.gsoSDK.OrbwalkerMenu = MenuElement({name = "gsoOrbwalker", id = "gsoorbwalker", type = MENU, leftIcon = "https://raw.githubusercontent.com/gamsteron/GoSExt/master/Icons/rsz_gsoorbwalker.png" })
      -- LOAD LIBS
      _G.gsoSDK.Cursor = gsoCursor()
      _G.gsoSDK.ObjectManager = gsoOB()
      _G.gsoSDK.Farm = gsoFarm()
      _G.gsoSDK.TargetSelector = gsoTS()
      _G.gsoSDK.Orbwalker = gsoOrbwalker()
      -----------------------------------------------------------
      _G.gsoSDK.TargetSelector:CreateMenu()
      _G.gsoSDK.Orbwalker:CreateMenu()
      _G.gsoSDK.OrbwalkerMenu:MenuElement({name = "Drawings", id = "gsodraw", leftIcon = "https://raw.githubusercontent.com/gamsteron/GoSExt/master/Icons/circles.png", type = MENU })
      _G.gsoSDK.OrbwalkerMenu.gsodraw:MenuElement({name = "Enabled",  id = "enabled", value = true})
      _G.gsoSDK.TargetSelector:CreateDrawMenu()
      _G.gsoSDK.Cursor:CreateDrawMenu()
      _G.gsoSDK.Orbwalker:CreateDrawMenu()
      Callback.Add('Tick', function()
            _G.gsoSDK.ObjectManager:Tick()
            _G.gsoSDK.Cursor:Tick()
            local enemyMinions = _G.gsoSDK.ObjectManager:GetEnemyMinions(1500, false)
            local allyMinions = _G.gsoSDK.ObjectManager:GetAllyMinions(1500, false)
            _G.gsoSDK.Farm:Tick(allyMinions, enemyMinions)
            _G.gsoSDK.TargetSelector:Tick()
            _G.gsoSDK.Orbwalker:Tick()
      end)
      Callback.Add('WndMsg', function(msg, wParam)
            _G.gsoSDK.TargetSelector:WndMsg(msg, wParam)
      end)
      Callback.Add('Draw', function()
            if not _G.gsoSDK.OrbwalkerMenu.gsodraw.enabled:Value() then return end
            _G.gsoSDK.TargetSelector:Draw()
            _G.gsoSDK.Cursor:Draw()
            _G.gsoSDK.Orbwalker:Draw()
      end)
end)

function OnTick() Fix() end

function CatchMinion()
    local Count = 0
    for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		if minion and minion.team ~= myHero.team and GetDistance(Game.cursorPos(), minion.pos) < minion.boundingRadius + 50 then
			Count = Count + 1
		end
	end
	return Count
end

function CatchTurret()
    local Count = 0
	for i = 1, Game.TurretCount() do
		local turret = Game.Turret(i)
		if turret and turret.team ~= myHero.team and GetDistance(Game.cursorPos(), turret.pos) < turret.boundingRadius + 50 then
			Count = Count + 1
		end
	end
	return Count
end

function Fix()
    if _G.gsoSDK then
        if _G.gsoSDK.Orbwalker:GetMode() == "Combo" then
            if CatchMinion() ~= 0 then
                _G.gsoSDK.Orbwalker.MovementEnabled = false
            elseif CatchTurret() ~= 0 then
                _G.gsoSDK.Orbwalker.MovementEnabled = false
            else
                _G.gsoSDK.Orbwalker.MovementEnabled = true
            end
        else
            _G.gsoSDK.Orbwalker.MovementEnabled = true
        end
    end
end