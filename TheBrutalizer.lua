-- Twisted Fate -> Cho'Gath -> Veigar

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
      if _G.SDK then
            if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
                return "Combo"
            elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
                return "Harass"	
            elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
                return "Clear"
            elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
                return "Lasthit"
            elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
                return "Flee"
            end
            return ""
      end
	if _G.gsoSDK then
            return _G.gsoSDK.Orbwalker:GetMode()
      end
end

function SetAttacks(bool)
	if _G.gsoSDK then
            _G.gsoSDK.Orbwalker.AttackEnabled = bool
      elseif _G.SDK then
	      _G.SDK.Orbwalker:SetAttack(bool)
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
      elseif _G.SDK and _G.SDK.TargetSelector then
            if type == 0 then
                  target = _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL)
	      else
	            target = _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL)
            end
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

function EnemyMinionsAround(pos, range)
      local Count = 0
      for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and ValidTarget(minion) and GetDistance(pos,minion.pos) <= range then
                  Count = Count + 1
            end
      end
      return Count
end

function EnemyHeroesAround(pos, range)
      local Count = 0
	for i = 1, Game.HeroCount() do
		local hero = Game.Hero(i)
		if hero and hero.team ~= myHero.team and not hero.dead and GetDistance(pos, hero.pos) < range then
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
      local enemyHeroes
      if _G.gsoSDK then
            enemyHeroes = _G.gsoSDK.ObjectManager:GetEnemyHeroes(15000, false, "immortal")
      elseif _G.SDK then
            enemyHeroes = _G.SDK.ObjectManager:GetEnemyHeroes(15000)
      end
      SaveWaypoints(enemyHeroes)
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

function VectorPointProjectionOnLineSegment(v1, v2, v)
	local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
      local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
      local pointLine = { x = ax + rL * (bx - ax), y = ay + rL * (by - ay) }
      local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
      local isOnSegment = rS == rL
      local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), y = ay + rS * (by - ay)}
	return pointSegment, pointLine, isOnSegment
end

function SquaredDist(Pos1, Pos2)
	local Pos2 = Pos2 or myHero.pos
	local dx = Pos1.x - Pos2.x
	local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
	return dx^2 + dz^2
end

function GetMinionCollisionCount(StartPos, EndPos, Width, Target)
	local Count = 0
	for i = 1, Game.MinionCount() do
		local m = Game.Minion(i)
		if m and not m.isAlly then
			local w = Width + m.boundingRadius
			local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(StartPos, EndPos, m.pos)
			if isOnSegment and SquaredDist(pointSegment, m.pos) < w^2 and SquaredDist(StartPos, EndPos) > SquaredDist(StartPos, m.pos) then
				Count = Count + 1
			end
		end
	end
	return Count
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
      local enemyMinions
      if _G.gsoSDK then
            enemyMinions = _G.gsoSDK.ObjectManager:GetEnemyMinions(2000, false)
      elseif _G.SDK then
            enemyMinions = _G.SDK.ObjectManager:GetEnemyMinions(2000)
      end
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
      local latency = Game.Latency() * 0.001
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
local version = 0.6

local Icon = {
      TB                = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/TheBrutalizer.png",

      Chogath           = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/Chogath.png",
      ChogathQ          = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/ChogathQ.png",
      ChogathW          = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/ChogathW.png",
      ChogathE          = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/ChogathE.png",
      ChogathR          = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/ChogathR.png",

      Kayle             = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/Kayle.png",
      KayleQ            = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/KayleQ.png",
      KayleW            = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/KayleW.png",
      KayleE            = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/KayleE.png",
      KayleR            = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/KayleR.png",

      Quinn             = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/Quinn.png",
      QuinnQ            = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/QuinnQ.png",
      QuinnW            = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/QuinnW.png",
      QuinnE            = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/QuinnE.png",
      QuinnR            = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/QuinnR.png",

      Teemo             = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/Teemo.png",
      TeemoQ            = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/TeemoQ.png",
      TeemoW            = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/TeemoW.png",
      TeemoE            = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/TeemoE.png",
      TeemoR            = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/TeemoR.png",

      TwistedFate       = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/TwistedFate.png",
      TwistedFateQ      = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/TwistedFateQ.png",
      TwistedFateW      = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/TwistedFateW.png",
      TwistedFateE      = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/TwistedFateE.png",
      TwistedFateR      = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/TwistedFateR.png",

      Vladimir          = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/Vladimir.png",
      VladimirQ         = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/VladimirQ.png",
      VladimirW         = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/VladimirW.png",
      VladimirE         = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/VladimirE.png",
      VladimirR         = "https://raw.githubusercontent.com/TheOppressor/TheBrutalizer/master/Icon/VladimirR.png",
}

--[[
    Chogath
]]
class "Chogath"

function Chogath:__init()
      self:SetSpells()
      self:Config()
      function OnTick() self:Tick() end
end
	
function Chogath:SetSpells()
      Q = {range = 950, delay = 0.625, radius = 250, speed = math.huge}
      W = {range = 650, delay = 0.5, radius = 210, speed = math.huge}
      E = {range = myHero.range + myHero.boundingRadius + 35 + 50}
      R = {range = 175 + myHero.boundingRadius + 35}
end

function Chogath:Config()
      tbChogath = MenuElement({id = "tbChogath", name = "The Brutalizer: v"..version.." [Cho'Gath]", type = MENU, leftIcon = Icon.Chogath})

      tbChogath:MenuElement({id = "Q", name = "Q - Rupture", leftIcon = Icon.ChogathQ, type = MENU})
      tbChogath:MenuElement({id = "W", name = "W - Feral Scream", leftIcon = Icon.ChogathW, type = MENU})
      tbChogath:MenuElement({id = "E", name = "E - Vorpal Spikes", leftIcon = Icon.ChogathE, type = MENU})
      tbChogath:MenuElement({id = "R", name = "R - Feast", leftIcon = Icon.ChogathR, type = MENU})

      tbChogath.Q:MenuElement({id = "", name = "...", type = SPACE})

      tbChogath.W:MenuElement({id = "", name = "...", type = SPACE})

      tbChogath.E:MenuElement({id = "AA", name = "Only after AA (if in range)", value = true})

      tbChogath.R:MenuElement({id = "", name = "...", type = SPACE})
end

function Chogath:Tick()
      if myHero.dead then return end
      local mode = GetMode()
      self:AutoR()
      if mode == "Combo" and tb.Combo.Enable:Value() and MPpercent(myHero) >= tb.Combo.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Combo()
      elseif mode == "Harass" and tb.Harass.Enable:Value() and MPpercent(myHero) >= tb.Harass.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Harass()
      elseif mode == "Clear" and tb.Laneclear.Enable:Value() and MPpercent(myHero) >= tb.Laneclear.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Laneclear()
      elseif mode == "Lasthit" and tb.Lasthit.Enable:Value() and MPpercent(myHero) >= tb.Lasthit.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Lasthit()
      elseif mode == "Flee" and tb.Flee.Enable:Value() and MPpercent(myHero) >= tb.Flee.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Flee()
      end
end

function Chogath:AutoR()
      if Game.CanUseSpell(_R) == 0 then
            for i = 1, Game.HeroCount() do
                  local hero = Game.Hero(i)
                  local Rlevel = myHero:GetSpellData(_R).level
                  local level = myHero.levelData.lvl
                  local baseHealth = ({574.4, 632, 692.4, 755.6, 821.6, 890.4, 962, 1036.4, 1113.6, 1193.6, 1276.4, 1362, 1450.4, 1541.6, 1635.6, 1732.4, 1832, 1934.4})[level]
                  local bonusHealth = myHero.maxHealth - baseHealth
                  local baseDmg = ({300,475,650})[Rlevel]
                  local damage = baseDmg + myHero.ap * 0.5 + bonusHealth * 0.1
                  if hero and hero.team ~= myHero.team and ValidTarget(hero) and damage > hero.health then
                        self:Rlogic(hero)
                  end
            end
      end
end

function Chogath:Combo()
      if tb.Combo.Q:Value() then
            local target = GetTarget(Q.range,1)
            self:Qlogic(target)
      end
      if tb.Combo.W:Value() then
            local target = GetTarget(W.range,1)
            self:Wlogic(target)
      end
      if tb.Combo.E:Value() then
            local target = GetTarget(E.range,1)
            self:Elogic(target)
      end
end

function Chogath:Harass()
      if tb.Harass.Q:Value() then
            local target = GetTarget(Q.range,1)
            self:Qlogic(target)
      end
      if tb.Harass.W:Value() then
            local target = GetTarget(W.range,1)
            self:Wlogic(target)
      end
      if tb.Harass.E:Value() then
            local target = GetTarget(E.range,1)
            self:Elogic(target)
      end
end

function Chogath:Laneclear()
      if tb.Laneclear.W:Value() then
            for i = 1, Game.MinionCount() do
                  local minion = Game.Minion(i)
                  if minion and minion.team ~= myHero.team and ValidTarget(minion) and EnemyMinionsAround(minion.pos, W.radius) >= tb.Laneclear.Minions:Value() then
                        self:Wlogic(minion)
                  end
            end
      end
      if tb.Laneclear.E:Value() then
            for i = 1, Game.MinionCount() do
                  local minion = Game.Minion(i)
                  if minion and minion.team ~= myHero.team and ValidTarget(minion) then
                        self:Elogic(minion)
                  end
            end
      end
      if tb.Laneclear.Q:Value() then
            for i = 1, Game.MinionCount() do
                  local minion = Game.Minion(i)
                  if minion and minion.team ~= myHero.team and ValidTarget(minion) and EnemyMinionsAround(minion.pos, Q.radius) >= tb.Laneclear.Minions:Value() then
                        self:Qlogic(minion)
                  end
            end
      end
end

function Chogath:Lasthit()
      if tb.Lasthit.R:Value() then
            for i = 1, Game.MinionCount() do
                  local minion = Game.Minion(i)
                  local level = myHero.levelData.lvl
                  local baseHealth = ({574.4, 632, 692.4, 755.6, 821.6, 890.4, 962, 1036.4, 1113.6, 1193.6, 1276.4, 1362, 1450.4, 1541.6, 1635.6, 1732.4, 1832, 1934.4})[level]
                  local bonusHealth = myHero.maxHealth - baseHealth
                  local damage = 1000 + myHero.ap * 0.5 + bonusHealth * 0.1
                  if minion and minion.team ~= myHero.team and ValidTarget(minion) and damage > minion.health then
                        self:Rlogic(minion)
                  end
            end
      end
end

function Chogath:Flee()
      if tb.Flee.Q:Value() then
            for i = 1, Game.HeroCount() do
                  local hero = Game.Hero(i)
                  if hero and hero.team ~= myHero.team and ValidTarget(hero) then
                        self:Qlogic(hero)
                  end
            end
      end
end

function Chogath:Qlogic(target)
      if Game.CanUseSpell(_Q) == 0 then
            if target and target.type == Obj_AI_Hero then
                  if target.team ~= myHero.team and ValidTarget(target) then
                        local CastPos, hitChance = GetPrediction(target, myHero.pos, Q)
                        if hitChance and hitChance >= 1 and GetDistance(CastPos,myHero.pos) <= Q.range then
                              Control.CastSpell(HK_Q, CastPos)
                        end
                  end
            end
            if target and target.type == Obj_AI_Minion and GetDistance(target.pos,myHero.pos) <= Q.range then
                  Control.CastSpell(HK_Q, target.pos)
            end
      end
end

function Chogath:Wlogic(target)
      if Game.CanUseSpell(_W) == 0 then
            if target and target.type == Obj_AI_Hero then
                  if target.team ~= myHero.team and ValidTarget(target) then
                        local CastPos, hitChance = GetPrediction(target, myHero.pos, W)
                        if hitChance and hitChance >= 1 and GetDistance(CastPos,myHero.pos) <= W.range then
                              Control.CastSpell(HK_W, CastPos)
                        end
                  end
            end
            if target and target.type == Obj_AI_Minion and GetDistance(target.pos,myHero.pos) <= W.range then
                  Control.CastSpell(HK_W, target.pos)
            end
      end
end

function Chogath:Elogic(target)
      if target and GetDistance(target.pos,myHero.pos) <= E.range and Game.CanUseSpell(_E) == 0 then
            if tbChogath.E.AA:Value() and myHero.attackData.state ~= STATE_WINDDOWN and GetDistance(target.pos,myHero.pos) <= myHero.range + myHero.boundingRadius + 35 then
                  return
            end
            Control.CastSpell(HK_E)
      end
end

function Chogath:Rlogic(target)
      if target and GetDistance(target.pos,myHero.pos) <= R.range and Game.CanUseSpell(_R) == 0 then
            Control.CastSpell(HK_R,target)
      end
end

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
      if mode == "Combo" and tb.Combo.Enable:Value() and MPpercent(myHero) >= tb.Combo.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Combo()
      elseif mode == "Harass" and tb.Harass.Enable:Value() and MPpercent(myHero) >= tb.Harass.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Harass()
      elseif mode == "Clear" and tb.Laneclear.Enable:Value() and MPpercent(myHero) >= tb.Laneclear.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Laneclear()
      elseif mode == "Lasthit" and tb.Lasthit.Enable:Value() and MPpercent(myHero) >= tb.Lasthit.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Lasthit()
      elseif mode == "Flee" and tb.Flee.Enable:Value() and MPpercent(myHero) >= tb.Flee.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
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
      if EnemyHeroesAround(myHero.pos, 1800) ~= 0 then
            if HPpercent(myHero) <= tbKayle.R.HP:Value() then
                  Control.CastSpell(HK_R, myHero)
            end
      end
      for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and hero.team == myHero.team and ValidTarget(hero) and not hero.isMe and GetDistance(hero.pos,myHero.pos) <= R.range then
                  if EnemyHeroesAround(hero.pos, 1800) ~= 0 then
                        if HPpercent(hero) <= tbKayle.R.AHP:Value() and tbKayle.R[hero.charName]:Value() then
                              Control.CastSpell(HK_R, hero)
                        end
                  end
            end
      end
end

function Kayle:AutoW()
      if EnemyHeroesAround(myHero.pos, 1800) ~= 0 then
            if HPpercent(myHero) <= tbKayle.W.HP:Value() then
                  Control.CastSpell(HK_W, myHero)
            end
      end
      for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and hero.team == myHero.team and ValidTarget(hero) and not hero.isMe and GetDistance(hero.pos,myHero.pos) <= W.range then
                  if EnemyHeroesAround(hero.pos, 1800) ~= 0 then
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
            self:Qlogic(target)
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
            self:Qlogic(target)
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
                        self:Qlogic(minion)
                  end
            end
      end
      if tb.Laneclear.E:Value() then
            for i = 1, Game.MinionCount() do
                  local minion = Game.Minion(i)
                  if minion and minion.team ~= myHero.team and ValidTarget(minion) and EnemyMinionsAround(minion.pos, E.spread) >= tb.Laneclear.Minions:Value() then
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
                  if minion and minion.team ~= myHero.team and ValidTarget(minion) and damage > minion.health then
                        self:Qlogic(minion)
                  end
            end
      end
end

function Kayle:Flee()
      if tb.Flee.Q:Value() then
            for i = 1, Game.HeroCount() do
                  local hero = Game.Hero(i)
                  if hero and hero.team ~= myHero.team and ValidTarget(hero) then
                        self:Qlogic(hero)
                  end
            end
      end
      if tb.Flee.W:Value() and Game.CanUseSpell(_W) == 0 then
            Control.CastSpell(HK_W,myHero)
      end
end

function Kayle:Qlogic(target)
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
      if mode == "Combo" and tb.Combo.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Combo()
      elseif mode == "Harass" and tb.Harass.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Harass()
      elseif mode == "Clear" and tb.Laneclear.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Laneclear()
      elseif mode == "Flee" and tb.Flee.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Flee()
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
      if tb.Laneclear.E:Value() then
            for i = 1, Game.MinionCount() do
                  local minion = Game.Minion(i)
                  if minion and minion.team == 300 and ValidTarget(minion) then
                        self:Elogic(minion)
                  end
            end
      end
      if tb.Laneclear.Q:Value() then
            for i = 1, Game.MinionCount() do
                  local minion = Game.Minion(i)
                  if minion and minion.team ~= myHero.team and ValidTarget(minion) and EnemyMinionsAround(minion.pos, Q.effectradius) >= tb.Laneclear.Minions:Value() then
                        self:Qlogic(minion)
                  end
            end
      end
end

function Quinn:Flee()
      if tb.Flee.Q:Value() then
            for i = 1, Game.HeroCount() do
                  local hero = Game.Hero(i)
                  if hero and hero.team ~= myHero.team and ValidTarget(hero) then
                        self:Qlogic(hero)
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
    Teemo
]]
class "Teemo"

function Teemo:__init()
      self:SetSpells()
      self:Config()
      function OnTick() self:Tick() end
end

function Teemo:SetSpells()
      Q = {range = 680}
      W = {range = 0}
      E = {range = 0}
      R = {range = 900, radius = 200, speed = math.huge, delay = 1.25}
end
	
function Teemo:Config()
      tbTeemo = MenuElement({id = "tbTeemo", name = "The Brutalizer: v"..version.." [Teemo]", type = MENU, leftIcon = Icon.Teemo})

      tbTeemo:MenuElement({id = "Q", name = "Q - Blinding Dart", leftIcon = Icon.TeemoQ, type = MENU})
      tbTeemo:MenuElement({id = "W", name = "W - Move Quick", leftIcon = Icon.TeemoW, type = MENU})
      tbTeemo:MenuElement({id = "E", name = "E - Toxic Shot", leftIcon = Icon.TeemoE, type = MENU})
      tbTeemo:MenuElement({id = "R", name = "R - Noxious Trap", leftIcon = Icon.TeemoR, type = MENU})

      tbTeemo.Q:MenuElement({id = "AA", name = "Only after AA (if in range)", value = true})
      for i = 1, Game.HeroCount() do
            local enemy = Game.Hero(i)
            if enemy and enemy.team ~= myHero.team then
                  tbTeemo.Q:MenuElement({id = enemy.charName, name = enemy.charName, value = true, leftIcon = "https://raw.githubusercontent.com/definitelynotgod/Zestorer/master/HeroIcons/"..enemy.charName..".png"})
            end
      end

      tbTeemo.W:MenuElement({id = "MS", name = "Only if enemy ms is higher", value = false})

      tbTeemo.E:MenuElement({id = "", name = "...", type = SPACE})

      tbTeemo.R:MenuElement({id = "AA", name = "Only after AA (if in range)", value = true})
end

function Teemo:Tick()
      if myHero.dead then return end
      local mode = GetMode()
      if mode == "Combo" and tb.Combo.Enable:Value() and MPpercent(myHero) >= tb.Combo.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Combo()
      elseif mode == "Harass" and tb.Harass.Enable:Value() and MPpercent(myHero) >= tb.Harass.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Harass()
      elseif mode == "Clear" and tb.Laneclear.Enable:Value() and MPpercent(myHero) >= tb.Laneclear.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Laneclear()
      elseif mode == "Lasthit" and tb.Lasthit.Enable:Value() and MPpercent(myHero) >= tb.Lasthit.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Lasthit()
      elseif mode == "Flee" and tb.Flee.Enable:Value() and MPpercent(myHero) >= tb.Flee.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Flee()
      end
end

function Teemo:Combo()
      if tb.Combo.Q:Value() then
            local target = GetTarget(Q.range,1)
            self:Qlogic(target,true)
      end
      if tb.Combo.W:Value() then
            local target = GetTarget(850,1)
            self:Wlogic(target)
      end
      if tb.Combo.R:Value() then
            local target
            if myHero:GetSpellData(_R).level == 1 then
                  target = GetTarget(400,1)
            elseif myHero:GetSpellData(_R).level == 2 then
                  target = GetTarget(650,1)
            else
                  target = GetTarget(900,1)
            end
            self:Rlogic(target)
      end
end

function Teemo:Harass()
      if tb.Harass.Q:Value() then
            local target = GetTarget(Q.range,1)
            self:Qlogic(target,true)
      end
      if tb.Harass.W:Value() then
            local target = GetTarget(850,1)
            self:Wlogic(target)
      end
      if tb.Harass.R:Value() then
            local target
            if myHero:GetSpellData(_R).level == 1 then
                  target = GetTarget(400,1)
            elseif myHero:GetSpellData(_R).level == 2 then
                  target = GetTarget(650,1)
            else
                  target = GetTarget(900,1)
            end
            self:Rlogic(target)
      end 
end

function Teemo:Laneclear()
      if tb.Laneclear.Q:Value() then
            for i = 1, Game.MinionCount() do
                  local minion = Game.Minion(i)
                  if minion and minion.team == 300 and ValidTarget(minion) then
                        self:Qlogic(minion)
                  end
            end
      end
      if tb.Laneclear.R:Value() then
            for i = 1, Game.MinionCount() do
                  local minion = Game.Minion(i)
                  if minion and minion.team ~= myHero.team and ValidTarget(minion) and EnemyMinionsAround(minion.pos, R.radius) >= tb.Laneclear.Minions:Value() then
                        self:Rlogic(minion)
                  end
            end
      end
end

function Teemo:Lasthit()
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

function Teemo:Flee()
      if tb.Flee.W:Value() and Game.CanUseSpell(_W) == 0 then
            Control.CastSpell(HK_W)
      end
      if tb.Flee.R:Value() and Game.CanUseSpell(_R) == 0 and EnemyHeroesAround(myHero.pos, 450) ~= 0 then
            Control.CastSpell(HK_R,myHero)
      end
end

function Teemo:Qlogic(target)
      if target and GetDistance(target.pos,myHero.pos) <= Q.range and Game.CanUseSpell(_Q) == 0 then
            if tbTeemo.Q.AA:Value() and myHero.attackData.state ~= STATE_WINDDOWN and GetDistance(target.pos,myHero.pos) <= myHero.range + myHero.boundingRadius + 35 then
                  return
            end
            if target.type == Obj_AI_Hero and not tbTeemo.Q[target.charName]:Value() then return end
            Control.CastSpell(HK_Q, target)
      end
end

function Teemo:Wlogic(target)
      if target and Game.CanUseSpell(_W) == 0 then
            if GetDistance(target.pos,myHero.pos) > 650 then
                  if tbTeemo.W.MS:Value() and myHero.ms > target.ms then return end
                Control.CastSpell(HK_W,myHero)
            end
      end
end

function Teemo:Rlogic(target)
      local Rrange
      if myHero:GetSpellData(_R).level == 1 then
            Rrange = 400
      elseif myHero:GetSpellData(_R).level == 2 then
            Rrange = 650
      else
            Rrange = 900
      end
      if target and Game.CanUseSpell(_R) == 0 then
            if tbTeemo.R.AA:Value() and myHero.attackData.state ~= STATE_WINDDOWN and GetDistance(target.pos,myHero.pos) <= myHero.range + myHero.boundingRadius + 35 then
                  return
            end
            if target.type == Obj_AI_Hero then
                  if target.team ~= myHero.team and ValidTarget(target) then
                        local CastPos, hitChance = GetPrediction(target, myHero.pos, R)
                        if hitChance and hitChance >= 2 and GetDistance(CastPos,myHero.pos) <= Rrange then
                              Control.CastSpell(HK_R, CastPos)
                        end
                  end
            end
            if target.type == Obj_AI_Minion and GetDistance(target.pos,myHero.pos) <= Rrange then
                  Control.CastSpell(HK_R, target.pos)
            end
      end
end

--[[
    TwistedFate
]]
class "TwistedFate"

function TwistedFate:__init()
      self:SetSpells()
      self:Config()
      function OnTick() self:Tick() end
end

function TwistedFate:SetSpells()
      Q = {range = 1450, delay = 0.25, radius = 40, speed = 1000}
      W = {range = 1100, red = "redcardlock", blue = "bluecardlock", gold = "goldcardlock", select = "pickacard"}
      E = {range = 0}
      R = {range = 0}
end
	
function TwistedFate:Config()
      tbTwistedFate = MenuElement({id = "tbTwistedFate", name = "The Brutalizer: v"..version.." [Twisted Fate]", type = MENU, leftIcon = Icon.TwistedFate})

      tbTwistedFate:MenuElement({id = "Q", name = "Q - Wild Cards", leftIcon = Icon.TwistedFateQ, type = MENU})
      tbTwistedFate:MenuElement({id = "W", name = "W - Pick a Card", leftIcon = Icon.TwistedFateW, type = MENU})
      tbTwistedFate:MenuElement({id = "E", name = "E - Stacked Deck", leftIcon = Icon.TwistedFateE, type = MENU})
      tbTwistedFate:MenuElement({id = "R", name = "R - Destiny", leftIcon = Icon.TwistedFateR, type = MENU})

      tbTwistedFate.Q:MenuElement({id = "W", name = "Priorize W", value = true})

      tbTwistedFate.W:MenuElement({id = "S", name = "Blue/Red slider clear [?]", value = 80, min = 0, max = 100, tooltip = "Blue under and Red over MP%"})

      tbTwistedFate.E:MenuElement({id = "", name = "...", type = SPACE})

      tbTwistedFate.R:MenuElement({id = "W", name = "Auto Gold Card", value = true})
end

function TwistedFate:Tick()
      if myHero.dead then return end
      local mode = GetMode()
      self:AutoGoldGate()
      if mode == "Combo" and tb.Combo.Enable:Value() and MPpercent(myHero) >= tb.Combo.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Combo()
      elseif mode == "Harass" and tb.Harass.Enable:Value() and MPpercent(myHero) >= tb.Harass.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Harass()
      elseif mode == "Clear" and tb.Laneclear.Enable:Value() and MPpercent(myHero) >= tb.Laneclear.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Laneclear()
      elseif mode == "Flee" and tb.Flee.Enable:Value() and MPpercent(myHero) >= tb.Flee.Mana:Value() and myHero.attackData.state ~= STATE_WINDUP then
            self:Flee()
      end
end

function TwistedFate:AutoGoldGate()
      if Game.CanUseSpell(_W) == 0 and HasBuff(myHero,"gate") and tbTwistedFate.R.W:Value() then
            local wName = myHero:GetSpellData(_W).name:lower()
            if wName == W.select or wName == W.gold then
                  Control.CastSpell(HK_W)
            end
      end
end

function TwistedFate:Combo()
      local wName = myHero:GetSpellData(_W).name:lower()
      if wName == W.gold then
            Control.CastSpell(HK_W)
      end
      if tb.Combo.W:Value() then
            local target = GetTarget(W.range,1)
            self:Wlogic(target)
      end
      if tb.Combo.Q:Value() then
            local target = GetTarget(Q.range,1)
            self:Qlogic(target)
      end
end

function TwistedFate:Harass()
      local wName = myHero:GetSpellData(_W).name:lower()
      if wName == W.gold then
            Control.CastSpell(HK_W)
      end
      if tb.Harass.W:Value() then
            local target = GetTarget(W.range,1)
            self:Wlogic(target)
      end
      if tb.Harass.Q:Value() then
            local target = GetTarget(Q.range,1)
            self:Qlogic(target)
      end
end

function TwistedFate:Laneclear()
      local wName = myHero:GetSpellData(_W).name:lower()
      if MPpercent(myHero) > tbTwistedFate.W.S:Value() and wName == W.red then
            Control.CastSpell(HK_W)
      elseif MPpercent(myHero) <= tbTwistedFate.W.S:Value() and wName == W.blue then
            Control.CastSpell(HK_W)
      end
      
      if tb.Laneclear.Q:Value() then
            for i = 1, Game.MinionCount() do
                  local minion = Game.Minion(i)
                  if minion and minion.team ~= myHero.team and ValidTarget(minion) and GetMinionCollisionCount(myHero.pos, minion.pos, Q.radius, minion) + 1 >= tb.Laneclear.Minions:Value() then
                        self:Qlogic(minion)
                  end
            end
      end
      if tb.Laneclear.W:Value() then
            for i = 1, Game.MinionCount() do
                  local minion = Game.Minion(i)
                  if minion and minion.team ~= myHero.team and ValidTarget(minion) then
                        self:Wlogic(minion)
                  end
            end
      end
end

function TwistedFate:Flee()
      local wName = myHero:GetSpellData(_W).name:lower()
      if wName == W.gold then
            Control.CastSpell(HK_W)
      end
      for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and hero.team ~= myHero.team and ValidTarget(hero) then
                  if tb.Flee.W:Value() then
                        self:Wlogic(hero)
                  end
                  if _G.SDK then
                        if _G.SDK.Orbwalker:CanAttack() and HasBuff(myHero,"goldcardpreattack") and GetDistance(hero.pos,myHero.pos) <= W.range then
                              Control.Attack(hero)
                        end
                  end
            end
      end
end

function TwistedFate:Qlogic(target)
      if Game.CanUseSpell(_Q) == 0 then
            if target and target.type == Obj_AI_Hero then
                  if target.team ~= myHero.team and ValidTarget(target) then
                        local CastPos, hitChance = GetPrediction(target, myHero.pos, Q)
                        if hitChance and hitChance >= 2 and GetDistance(CastPos,myHero.pos) <= Q.range then
                              if tbTwistedFate.Q.W:Value() and GetDistance(target.pos,myHero.pos) <= W.range then 
                                    if myHero:GetSpellData(_W).currentCd <= 2 or not IsImmobile(target, 0) then
                                          return
                                    end
                              end
                              Control.CastSpell(HK_Q, CastPos)
                        end
                  end
            end
            if target and target.type == Obj_AI_Minion and GetDistance(target.pos,myHero.pos) <= Q.range then
                  Control.CastSpell(HK_Q, target.pos)
            end
      end
end

function TwistedFate:Wlogic(target)
      if Game.CanUseSpell(_W) == 0 then
            local wName = myHero:GetSpellData(_W).name:lower()
            if target and GetDistance(target.pos,myHero.pos) <= W.range and wName == W.select then
                  Control.CastSpell(HK_W)
            end
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
      E = {range = 600, delay = 0, radius = 80, speed = math.huge}
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
      if mode == "Combo" and tb.Combo.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP and not Control.IsKeyDown(HK_E) then
            self:Combo()
      elseif mode == "Harass" and tb.Harass.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP and not Control.IsKeyDown(HK_E) then
            self:Harass()
      elseif mode == "Clear" and tb.Laneclear.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP and not Control.IsKeyDown(HK_E) then
            self:Laneclear()
      elseif mode == "Lasthit" and tb.Lasthit.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP and not Control.IsKeyDown(HK_E) then
            self:Lasthit()
      elseif mode == "Flee" and tb.Flee.Enable:Value() and myHero.attackData.state ~= STATE_WINDUP and not Control.IsKeyDown(HK_E) then
            self:Flee()
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
      if tb.Combo.Q:Value() then
            local target = GetTarget(Q.range,1)
            self:Qlogic(target)
      end
      if tb.Combo.W:Value() then
            local target = GetTarget(W.range,1)
            self:Wlogic(target)
      end
      if tb.Combo.E:Value() then
            local target = GetTarget(E.range,1)
            self:Elogic(target)
      end
end

function Vladimir:Harass()
      if tb.Harass.R:Value() then
            self:Rlogic()
      end
      if tb.Harass.Q:Value() then
            local target = GetTarget(Q.range,1)
            self:Qlogic(target)
      end
      if tb.Harass.W:Value() then
            local target = GetTarget(W.range,1)
            self:Wlogic(target)
      end
      if tb.Harass.E:Value() then
            local target = GetTarget(E.range,1)
            self:Elogic(target)
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
                  if minion and minion.team ~= myHero.team and ValidTarget(minion) and EnemyMinionsAround(myHero.pos, E.range) >= tb.Laneclear.Minions:Value() then
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

function Vladimir:Flee()
      if tb.Flee.W:Value() and Game.CanUseSpell(_W) == 0 and EnemyHeroesAround(myHero.pos, W.range) ~= 0 then
            Control.CastSpell(HK_W)
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
      ["Chogath"] = {Q = 950, W = 650, E = myHero.range + myHero.boundingRadius + 35 + 50, R = 175 + myHero.boundingRadius + 35},
      ["Kayle"] = {Q = 650, W = 900, E = 525 + myHero.boundingRadius + 35, R = 900},
      ["Quinn"] = {Q = 1025, W = 2100, E = 675, R = 0},
      ["Teemo"] = {Q = 680, W = 0, E = 0, R = 1 },
      ["TwistedFate"] = {Q = 1450, W = myHero.range + myHero.boundingRadius + 35, E = 0, R = 5500},
      ["Vladimir"] = {Q = 600, W = 300, E = 600, R = 700},
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
      if tb.Draw.Q.Enable:Value() and Game.CanUseSpell(_Q) == 0 and range[myHero.charName].Q > 0 then
            local Width = tb.Draw.Q.Width:Value()
            local Alpha = tb.Draw.Q.Alpha:Value()
            local Red = tb.Draw.Q.Red:Value()
            local Green = tb.Draw.Q.Green:Value()
            local Blue = tb.Draw.Q.Blue:Value()
		Draw.Circle(myHero.pos, range[myHero.charName].Q, Width, Draw.Color(Alpha,Red,Green,Blue))
	end
	if tb.Draw.W.Enable:Value() and Game.CanUseSpell(_W) == 0 and range[myHero.charName].W > 0 then
            local Width = tb.Draw.W.Width:Value()
            local Alpha = tb.Draw.W.Alpha:Value()
            local Red = tb.Draw.W.Red:Value()
            local Green = tb.Draw.W.Green:Value()
            local Blue = tb.Draw.W.Blue:Value()
		Draw.Circle(myHero.pos, range[myHero.charName].W, Width, Draw.Color(Alpha,Red,Green,Blue))
	end
	if tb.Draw.E.Enable:Value() and Game.CanUseSpell(_E) == 0 and range[myHero.charName].E > 0 then
            local Width = tb.Draw.E.Width:Value()
            local Alpha = tb.Draw.E.Alpha:Value()
            local Red = tb.Draw.E.Red:Value()
            local Green = tb.Draw.E.Green:Value()
            local Blue = tb.Draw.E.Blue:Value()
		Draw.Circle(myHero.pos, range[myHero.charName].E, Width, Draw.Color(Alpha,Red,Green,Blue))
      end
      if tb.Draw.R.Enable:Value() and Game.CanUseSpell(_R) == 0 and range[myHero.charName].R > 0 then
            local Width = tb.Draw.R.Width:Value()
            local Alpha = tb.Draw.R.Alpha:Value()
            local Red = tb.Draw.R.Red:Value()
            local Green = tb.Draw.R.Green:Value()
            local Blue = tb.Draw.R.Blue:Value()
            if myHero.charName == "Teemo" then
                  local Rrange
                  if myHero:GetSpellData(_R).level == 1 then
                        Rrange = 400
                  elseif myHero:GetSpellData(_R).level == 2 then
                        Rrange = 650
                  else
                        Rrange = 900
                  end
                  Draw.Circle(myHero.pos, Rrange, Width, Draw.Color(Alpha,Red,Green,Blue))
            elseif myHero.charName == "TwistedFate" then
                  Draw.CircleMinimap(myHero.pos, range[myHero.charName].R, Width - 1, Draw.Color(Alpha,Red,Green,Blue))
            else
                  Draw.Circle(myHero.pos, range[myHero.charName].R, Width, Draw.Color(Alpha,Red,Green,Blue))
            end
	end
end