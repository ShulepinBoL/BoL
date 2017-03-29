if myHero.charName ~= "Lucian" then return end

local function Alert(text, name)
    if not name then name = "Shulepin's Lucian " end
    print("<b><font color=\"#ffb10a\">"..name.."- <font color=\"#ffffff\"><b>"..text) 
end

local ScriptVersion = "0.2"
local LeagueVersion = "7.6"
local ScriptAuthor = "Shulepin"

local AUTOUPDATE = true
local UPDATE_HOST = "raw.githubusercontent.com"
local UPDATE_PATH = "/ShulepinBoL/BoL/master/Lucian/ShulepinLucian.lua".."?rand="..math.random(1,10000)
local UPDATE_FILE_PATH = SCRIPT_PATH..GetCurrentEnv().FILE_NAME
local UPDATE_URL = "https://"..UPDATE_HOST..UPDATE_PATH

if AUTOUPDATE then
	local ServerData = GetWebResult(UPDATE_HOST,"/ShulepinBoL/BoL/master/Lucian/ShulepinLucian.version")
	if ServerData then
		ServerVersion = type(tonumber(ServerData)) == "number" and tonumber(ServerData) or nil
		if ServerVersion then
			if tonumber(ScriptVersion) < ServerVersion then
				Alert("New version available "..ServerVersion)
				Alert("Updating, please don't press F9")
				DelayAction(function() DownloadFile(UPDATE_URL, UPDATE_FILE_PATH, function () Alert("Successfully updated. ("..ScriptVersion.." => "..ServerVersion.."), press F9 twice to load the updated version.") end) end, 2)
				return
			else
				DelayAction(function() Alert("You have got the latest version ("..ServerVersion..")") end, 4)
			end
		end
	else
		Alert("Error downloading version info")
	end
end

if not _G.UPLloaded then
        if FileExist(LIB_PATH .. "/UPL.lua") then
                require("UPL")
                _G.UPL = UPL()
        else 
                print("Downloading UPL, please don't press F9")
                DelayAction(function() DownloadFile("https://raw.github.com/nebelwolfi/BoL/master/Common/UPL.lua".."?rand="..math.random(1,10000), LIB_PATH.."UPL.lua", function () print("Successfully downloaded UPL. Press F9 twice.") end) end, 3) 
                return
        end
    end

if FileExist(LIB_PATH .. "/UOL.lua") then
        require("UOL")
else 
        print("Downloading UOL, please don't press F9")
        DownloadFile("https://raw.github.com/nebelwolfi/BoL/master/Common/UOL.lua".."?rand="..math.random(1,10000), LIB_PATH.."UOL.lua", function () print("Successfully downloaded UOL. Press F9 twice.") return end) 
        return
end

function OnLoad()
	Lucian()
	Alert("Loaded!")
end

class "Lucian"

function Lucian:__init()
	self:Vars()
	self:Menu()
	self:Events()
	self:SkinChanger()
end

function Lucian:Vars()
	self.TS = TargetSelector(TARGET_LESS_CAST, 1500, DAMAGE_PHYSICAL, true)
	self.TS.name = "Target Selector"
	self.Minions = minionManager(MINION_ENEMY, 1000, myHero, MINION_SORT_MINHEALTH_ASC)

	self.Q    = { range = 650                                                                                                }
        self.QExt = { range = 900 , delay = 0.35, speed = math.huge, width = 25, collision = false, aoe = false, type = "linear" }
        self.W    = { range = 1000, delay = 0.30, speed = 1600     , width = 80, collision = true , aoe = true , type = "linear" }
        self.E    = { range = 425                                                                                                }
        self.R    = { range = 1200, delay = 0.10, speed = 2500     , width = 110                                                 }

        self.Q.IsReady = function() return myHero:CanUseSpell(_Q) == READY end
        self.W.IsReady = function() return myHero:CanUseSpell(_W) == READY end
        self.E.IsReady = function() return myHero:CanUseSpell(_E) == READY end
        self.R.IsReady = function() return myHero:CanUseSpell(_R) == READY end

        self.Q.GetDamage = function(unit) return myHero:CalcDamage(unit, (45 + 35 * myHero:GetSpellData(_Q).level + myHero.addDamage * ((50 + 10 * myHero:GetSpellData(_Q).level)/100))) end
        self.W.GetDamage = function(unit) return myHero:CalcDamage(unit, (20 + 40 * myHero:GetSpellData(_W).level + myHero.ap * 0.9)) end

        self.HavePassive = false
	self.LastCastTime = 0
end

function Lucian:Menu()
	self.Config = scriptConfig("Shulepin's Lucian", "Lucian")
	--         
	self.Config:addSubMenu("[Lucian] Combo", "Combo")
	self.Config.Combo:addSubMenu("[Q] Piercing Light", "Q")
	self.Config.Combo.Q:addParam("Use", "Use Q In Combo", SCRIPT_PARAM_ONOFF, true)
	self.Config.Combo.Q:addParam("Use2", "Use Extended Q In Combo", SCRIPT_PARAM_ONOFF, true)
	self.Config.Combo:addSubMenu("[W] Ardent Blaze", "W")
	self.Config.Combo.W:addParam("Use", "Use W In Combo", SCRIPT_PARAM_ONOFF, true)
	self.Config.Combo.W:addParam("Fast", "Use Fast W In Combo", SCRIPT_PARAM_ONOFF, true)
	self.Config.Combo:addSubMenu("[E] Relentless Pursuit", "E")
	self.Config.Combo.E:addParam("Use", "Use E In Combo", SCRIPT_PARAM_ONOFF, true)
	self.Config.Combo.E:addParam("Mode", "E Mode", SCRIPT_PARAM_LIST, 1, {"Side", "Mouse", "Target"})
	self.Config.Combo.E:addParam("Range", "E Dash Range", SCRIPT_PARAM_SLICE, 225, 100, 425, 5)
	--
	self.Config:addSubMenu("[Lucian] Last Hit", "LastHit")
	self.Config.LastHit:addSubMenu("[Q] Piercing Light", "Q")
	self.Config.LastHit.Q:addParam("Use", "Last Hit With Q", SCRIPT_PARAM_ONOFF, true)
	self.Config.LastHit:addParam("Mana", "Min. Mana(%) For Last Hit", SCRIPT_PARAM_SLICE, 60, 0, 100, 1)
	--
	self.Config:addSubMenu("[Lucian] Harass", "Harass")
	self.Config.Harass:addSubMenu("[Q] Piercing Light", "Q")
	self.Config.Harass.Q:addParam("Use", "Use Q In Harass", SCRIPT_PARAM_ONOFF, true)
	self.Config.Harass.Q:addParam("Use2", "Use Extended Q In Harass", SCRIPT_PARAM_ONOFF, true)
	self.Config.Harass:addSubMenu("[W] Ardent Blaze", "W")
	self.Config.Harass.W:addParam("Use", "Use W In Harass", SCRIPT_PARAM_ONOFF, true)
	self.Config.Harass:addSubMenu("White List For Harass", "WhiteList")
	for i, enemy in pairs(GetEnemyHeroes()) do
		if not enemy.charName:lower():find("dummy") then
			self.Config.Harass.WhiteList:addParam("S"..enemy.charName, "Use Harass On: "..enemy.charName, SCRIPT_PARAM_ONOFF, true)
		end
	end
	self.Config.Harass:addParam("Mana", "Min. Mana(%) For Harass", SCRIPT_PARAM_SLICE, 60, 0, 100, 1)
	--
	self.Config:addSubMenu("[Lucian] Auto Harass", "AutoHarass")
	self.Config.AutoHarass:addSubMenu("[Q] Piercing Light", "Q")
	self.Config.AutoHarass.Q:addParam("Use2", "Auto Harass With Extended Q", SCRIPT_PARAM_ONOFF, true)
	self.Config.AutoHarass:addSubMenu("White List For Auto Harass", "WhiteList")
	for i, enemy in pairs(GetEnemyHeroes()) do
		if not enemy.charName:lower():find("dummy") then
			self.Config.AutoHarass.WhiteList:addParam("S"..enemy.charName, "Use Harass On: "..enemy.charName, SCRIPT_PARAM_ONOFF, true)
		end
	end
	self.Config.AutoHarass:addParam("Mana", "Min. Mana(%) For Auto Harass", SCRIPT_PARAM_SLICE, 60, 0, 100, 1)
	self.Config.AutoHarass:addParam("Key", "Auto Harass Toggle Key", SCRIPT_PARAM_ONKEYTOGGLE, true, string.byte("M"))
	--
	self.Config:addSubMenu("[Lucian] Lane Clear", "LaneClear")
	self.Config.LaneClear:addSubMenu("[Q] Piercing Light", "Q")
	self.Config.LaneClear.Q:addParam("Use", "Lane Clear With Q", SCRIPT_PARAM_ONOFF, true)
	self.Config.LaneClear:addSubMenu("[W] Ardent Blaze", "W")
	self.Config.LaneClear.W:addParam("Use", "Lane Clear With W", SCRIPT_PARAM_ONOFF, true)
	self.Config.LaneClear:addSubMenu("[E] Relentless Pursuit", "E")
	self.Config.LaneClear.E:addParam("Use", "Lane Clear With E", SCRIPT_PARAM_ONOFF, true)
	self.Config.LaneClear.E:addParam("Mode", "E Mode", SCRIPT_PARAM_LIST, 1, {"Side", "Mouse", "Target"})
	self.Config.LaneClear.E:addParam("Range", "E Dash Range", SCRIPT_PARAM_SLICE, 225, 100, 425, 5)
	self.Config.LaneClear:addParam("Mana", "Min. Mana(%) For Lane Clear", SCRIPT_PARAM_SLICE, 60, 0, 100, 1)
	--
	self.Config:addSubMenu("[Lucian] Jungle Clear", "JungleClear")
	self.Config.JungleClear:addSubMenu("[Q] Piercing Light", "Q")
	self.Config.JungleClear.Q:addParam("Use", "Jungle Clear With Q", SCRIPT_PARAM_ONOFF, true)
	self.Config.JungleClear:addSubMenu("[W] Ardent Blaze", "W")
	self.Config.JungleClear.W:addParam("Use", "Jungle Clear With W", SCRIPT_PARAM_ONOFF, true)
	self.Config.JungleClear:addSubMenu("[E] Relentless Pursuit", "E")
	self.Config.JungleClear.E:addParam("Use", "Jungle Clear With E", SCRIPT_PARAM_ONOFF, true)
	self.Config.JungleClear.E:addParam("Mode", "E Mode", SCRIPT_PARAM_LIST, 1, {"Side", "Mouse", "Target"})
	self.Config.JungleClear.E:addParam("Range", "E Dash Range", SCRIPT_PARAM_SLICE, 225, 100, 425, 5)
	self.Config.JungleClear:addParam("Mana", "Min. Mana(%) For Jungle Clear", SCRIPT_PARAM_SLICE, 60, 0, 100, 1)
	--
	self.Config:addSubMenu("[Lucian] Kill Secure", "KS")
	self.Config.KS:addSubMenu("[Q] Piercing Light", "Q")
	self.Config.KS.Q:addParam("Use", "KS With Q", SCRIPT_PARAM_ONOFF, true)
	self.Config.KS:addSubMenu("[W] Ardent Blaze", "W")
	self.Config.KS.W:addParam("Use", "KS With W", SCRIPT_PARAM_ONOFF, true)
	self.Config.KS:addSubMenu("White List For KS", "WhiteList")
	for i, enemy in pairs(GetEnemyHeroes()) do
		if not enemy.charName:lower():find("dummy") then
			self.Config.KS.WhiteList:addParam("S"..enemy.charName, "Use KS On: "..enemy.charName, SCRIPT_PARAM_ONOFF, true)
		end
	end
	self.Config.KS:addParam("Use", "Use KS", SCRIPT_PARAM_ONOFF, true)
	--
	self.Config:addSubMenu("[Lucian] Drawings", "Draw")
	self.Config.Draw:addSubMenu("[Q] Piercing Light", "Q")
	self.Config.Draw.Q:addParam("Range", "Draw Q Range", SCRIPT_PARAM_ONOFF, true)
	self.Config.Draw.Q:addParam("Color", "Q Color", SCRIPT_PARAM_COLOR, {100, 255, 255, 255})
	self.Config.Draw.Q:addParam("Range2", "Draw Extended Q Range", SCRIPT_PARAM_ONOFF, true)
	self.Config.Draw.Q:addParam("Color2", "Extended Q Color", SCRIPT_PARAM_COLOR, {100, 255, 255, 255})
	self.Config.Draw.Q:addParam("Rec", "Draw Q Rectangle", SCRIPT_PARAM_ONOFF, true)
	self.Config.Draw.Q:addParam("Color3", "Rectangle Q Color", SCRIPT_PARAM_COLOR, {100, 255, 255, 255})
	self.Config.Draw:addSubMenu("[W] Ardent Blaze", "W")
	self.Config.Draw.W:addParam("Range", "Draw W Range", SCRIPT_PARAM_ONOFF, true)
	self.Config.Draw.W:addParam("Color", "W Color", SCRIPT_PARAM_COLOR, {100, 255, 255, 255})
	self.Config.Draw:addSubMenu("[E] Relentless Pursuit", "E")
	self.Config.Draw.E:addParam("Range", "Draw E Range", SCRIPT_PARAM_ONOFF, true)
	self.Config.Draw.E:addParam("Color", "E Color", SCRIPT_PARAM_COLOR, {100, 255, 255, 255})
	self.Config.Draw:addSubMenu("[R] The Culling", "R")
	self.Config.Draw.R:addParam("Range", "Draw R Range", SCRIPT_PARAM_ONOFF, true)
	self.Config.Draw.R:addParam("Color", "R Color", SCRIPT_PARAM_COLOR, {100, 255, 255, 255})
	self.Config.Draw:addParam("Disable", "Disable All Drawings", SCRIPT_PARAM_ONOFF, false)
	--
	self.Config:addSubMenu("[Lucian] Skin Changer", "Skin")
	self.Config.Skin:addParam("List", myHero.charName .. " Skins", SCRIPT_PARAM_LIST, 1, {"Classic", "Hired Gun Lucian", "Striker Lucian", "Yellow Chroma", "Red Chroma", "Blue Chroma", "PROJECT: Lucian", "Heartseeker Lucian"})
	self.Config.Skin:setCallback("List", function() self:SkinChanger() end)
	--
	self.Config:addSubMenu("[Lucian] Walljumper", "Wall")
	self.Config.Wall:addParam("Key", "Walljump Key", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("G"))
	--
	self.Config:addSubMenu("[Lucian] Target Selector", "TS")
	self.Config.TS:addTS(self.TS)
	self.Config:addSubMenu("[Lucian] Orbwalker", "Orb")
	UOL:AddToMenu(self.Config.Orb) 
	UPL:AddToMenu(self.Config, "[Lucian] Prediction")
	UPL:AddSpell(_Q, self.QExt)
	UPL:AddSpell(_W, self.W)
	UPL:AddSpell(_R, self.R)
	--
	self.Config:addSubMenu("[Lucian] Script Info", "Info")
	self.Config.Info:addParam("info1", "Script Version: ", 5, ScriptVersion) 
	self.Config.Info:addParam("info2", "League Version: ", 5, LeagueVersion)
	self.Config.Info:addParam("info3", "Script Author: ", 5, ScriptAuthor)
	--
end

function Lucian:Events()
	AddTickCallback(function() self:Tick() end)
	AddDrawCallback(function() self:Draw() end)
	AddCastSpellCallback(function(spell) self:CastSpell(spell) end)
	AddProcessAttackCallback(function(unit, spell) self:ProcessAttack(unit, spell) end)
end

function Lucian:Tick()
	self.TS:update()
	self.Minions:update()
	self:TickCombo()
	self:TickLastHit()
	self:TickHarass()
	self:TickAutoHarass()
	self:TickKS()
	self:Walljumper()
end

function Lucian:CastSpell(spell)
        if spell == _Q or spell == _W or spell == _E then
		self.HavePassive = true
		self.LastCastTime = GetTickCount()
	end
	if spell == _E then
		UOL:ResetAA()
	end
end

function Lucian:ProcessAttack(unit, spell)
	self:ProcessAttackCombo(unit, spell)
	self:ProcessAttackLaneClear(unit, spell)
	self:ProcessAttackJungleClear(unit, spell)
end

function Lucian:Draw()
	if myHero.dead or self.Config.Draw.Disable then return end

	if self.Config.Draw.Q.Range and self.Q.IsReady() then
		DrawCircle3D(myHero.x, myHero.y, myHero.z, self.Q.range, 2, ARGB(self.Config.Draw.Q.Color[1], self.Config.Draw.Q.Color[2], self.Config.Draw.Q.Color[3], self.Config.Draw.Q.Color[4]), 75)
	end
	if self.Config.Draw.Q.Range2 and self.Q.IsReady() then
		DrawCircle3D(myHero.x, myHero.y, myHero.z, self.QExt.range, 2, ARGB(self.Config.Draw.Q.Color2[1], self.Config.Draw.Q.Color2[2], self.Config.Draw.Q.Color2[3], self.Config.Draw.Q.Color2[4]), 75)
	end
	if self.Config.Draw.W.Range and self.W.IsReady() then
		DrawCircle3D(myHero.x, myHero.y, myHero.z, self.W.range, 2, ARGB(self.Config.Draw.W.Color[1], self.Config.Draw.W.Color[2], self.Config.Draw.W.Color[3], self.Config.Draw.W.Color[4]), 75)
	end
	if self.Config.Draw.E.Range and self.E.IsReady() then
		DrawCircle3D(myHero.x, myHero.y, myHero.z, self.E.range, 2, ARGB(self.Config.Draw.E.Color[1], self.Config.Draw.E.Color[2], self.Config.Draw.E.Color[3], self.Config.Draw.E.Color[4]), 75)
	end
	if self.Config.Draw.R.Range and self.R.IsReady() then
		DrawCircle3D(myHero.x, myHero.y, myHero.z, self.R.range, 2, ARGB(self.Config.Draw.R.Color[1], self.Config.Draw.R.Color[2], self.Config.Draw.R.Color[3], self.Config.Draw.R.Color[4]), 75)
	end

	if self.Config.Wall.Key then
		local pos1 = self:VectorExtend(Vector(myHero), Vector(mousePos), self.E.range)
	        local pos2 = self:VectorExtend(Vector(myHero), Vector(mousePos), myHero.boundingRadius) 
	        if IsWall(D3DXVECTOR3(pos1.x, pos1.y, pos1.z)) then
		        DrawCircle3D(pos1.x, pos1.y, pos1.z, 150, 2, ARGB(255, 255, 0, 0), 75)
		        DrawText("E Pos", 25, WorldToScreen(D3DXVECTOR3(pos1.x, pos1.y, pos1.z)).x-25, WorldToScreen(D3DXVECTOR3(pos1.x, pos1.y, pos1.z)).y, ARGB(255, 255, 0, 0))
	        else
		        DrawCircle3D(pos1.x, pos1.y, pos1.z, 150, 2, ARGB(255, 255, 255, 255), 75)
		        DrawText("E Pos", 25, WorldToScreen(D3DXVECTOR3(pos1.x, pos1.y, pos1.z)).x-25, WorldToScreen(D3DXVECTOR3(pos1.x, pos1.y, pos1.z)).y, ARGB(255, 255, 255, 255))
	        end
        end

	local target = self.TS.target
	if target == nil then return end
	if self.Config.Draw.Q.Rec and self.Q.IsReady() then
	        self:DrawRectangleOutline(Vector(myHero), Vector(self:VectorExtend(Vector(myHero), Vector(target), self.Q.range)), self.QExt.width, ARGB(self.Config.Draw.Q.Color3[1], self.Config.Draw.Q.Color3[2], self.Config.Draw.Q.Color3[3], self.Config.Draw.Q.Color3[4]))
	        self:DrawRectangleOutline(Vector(myHero), Vector(self:VectorExtend(Vector(myHero), Vector(target), self.QExt.range)), self.QExt.width, ARGB(self.Config.Draw.Q.Color3[1], self.Config.Draw.Q.Color3[2], self.Config.Draw.Q.Color3[3], self.Config.Draw.Q.Color3[4]))
	end
end

function Lucian:ProcessAttackCombo(unit, spell)
	if unit.isMe and spell.name:lower():find("attack") then
		self.HavePassive = false
		if spell and spell.target and spell.target.valid and spell.target.type == "AIHeroClient" then
			if UOL:GetOrbWalkMode() == "Combo" then
				if self.Q.IsReady() and self.Config.Combo.Q.Use then self:CastQ(spell.target, self.Config.Combo.Q.Use)
				elseif self.E.IsReady() and self.Config.Combo.E.Use then self:CastE(spell.target, self.Config.Combo.E.Use, self.Config.Combo.E.Mode, self.Config.Combo.E.Range)
				elseif self.W.IsReady() and self.Config.Combo.W.Use then self:CastW(spell.target, self.Config.Combo.W.Use, self.Config.Combo.W.Fast)
				end
			end
		end
	end
end

function Lucian:ProcessAttackLaneClear(unit, spell)
	if unit.isMe and spell.name:lower():find("attack") then
		self.HavePassive = false
		if spell and spell.target and spell.target.valid and spell.target.type == "obj_AI_Minion" and spell.target.name:lower():find("minion_") then
			if UOL:GetOrbWalkMode() == "LaneClear" and (100 * myHero.mana / myHero.maxMana) >= self.Config.LaneClear.Mana then
				if self.Q.IsReady() and self.Config.LaneClear.Q.Use then self:CastQ(spell.target, self.Config.LaneClear.Q.Use) 
				elseif self.E.IsReady() and self.Config.LaneClear.E.Use then self:CastE(spell.target, self.Config.LaneClear.E.Use, self.Config.LaneClear.E.Mode, self.Config.LaneClear.E.Range)
				elseif self.W.IsReady() and self.Config.LaneClear.W.Use then self:CastW(spell.target, self.Config.LaneClear.W.Use, true)
			        end
			end
		end
	end
end

function Lucian:ProcessAttackJungleClear(unit, spell)
	if unit.isMe and spell.name:lower():find("attack") then
		self.HavePassive = false
		if spell and spell.target and spell.target.valid and spell.target.type == "obj_AI_Minion" and spell.target.name:lower():find("sru_") then
			if UOL:GetOrbWalkMode() == "LaneClear" and (100 * myHero.mana / myHero.maxMana) >= self.Config.JungleClear.Mana then
				if self.Q.IsReady() and self.Config.JungleClear.Q.Use then self:CastQ(spell.target, self.Config.JungleClear.Q.Use)
				elseif self.E.IsReady() and self.Config.JungleClear.E.Use then self:CastE(spell.target, self.Config.JungleClear.E.Use, self.Config.JungleClear.E.Mode, self.Config.JungleClear.E.Range)
				elseif self.W.IsReady() and self.Config.JungleClear.W.Use then self:CastW(spell.target, self.Config.JungleClear.W.Use, true)
				end
			end
		end
	end
end

function Lucian:TickCombo()
	local target = self.TS.target
	if target == nil then return end
	if UOL:GetOrbWalkMode() == "Combo" then
		self:CastQExt(target, self.Config.Combo.Q.Use2)
	end
end

function Lucian:TickLastHit()
	if UOL:GetOrbWalkMode() == "LastHit" then
		if (100 * myHero.mana / myHero.maxMana) >= self.Config.LastHit.Mana then
			for i, minion in pairs(self.Minions.objects) do
				if minion and minion.valid and not minion.dead and GetDistance(minion) <= self.Q.range and minion.health < self.Q.GetDamage(minion) and UOL:CanAttack() then
					self:CastQ(minion, self.Config.LastHit.Q.Use)
				end
			end
		end
	end
end

function Lucian:TickHarass()
	local target = self.TS.target
	if target == nil then return end
	if UOL:GetOrbWalkMode() == "Harass" then
		if (100 * myHero.mana / myHero.maxMana) >= self.Config.Harass.Mana and self.Config.Harass.WhiteList["S"..target.charName] then
			self:CastQ(target, self.Config.Harass.Q.Use)
			self:CastQExt(target, self.Config.Harass.Q.Use2)
			self:CastW(target, self.Config.Harass.W.Use, false)
		end
	end
end

function Lucian:TickAutoHarass()
	local target = self.TS.target
	if target == nil then return end
	if self.Config.AutoHarass.Key then
		if (100 * myHero.mana / myHero.maxMana) >= self.Config.AutoHarass.Mana and self.Config.AutoHarass.WhiteList["S"..target.charName] then
		        self:CastQExt(target, self.Config.AutoHarass.Q.Use2)
	        end
        end
end

function Lucian:TickKS()
	if self.Config.KS.Use then
		for i, enemy in pairs(GetEnemyHeroes()) do
			if ValidTarget(enemy) and self.Config.KS.WhiteList["S"..enemy.charName] then
				if enemy.health < self.Q.GetDamage(enemy) then
					self:CastQ(enemy, self.Config.KS.Q.Use)
				end
				if enemy.health < self.W.GetDamage(enemy) then
					self:CastW(enemy, self.Config.KS.W.Use, false)
				end
			end
		end
	end
end

function Lucian:Walljumper()
	if self.Config.Wall.Key then
		local p1 = myHero + (Vector(mousePos) - myHero):normalized() * 200
                local p2 = myHero + (Vector(mousePos) - myHero):normalized() * self.E.range
                local p3 = myHero + (Vector(mousePos) - myHero):normalized() * myHero.boundingRadius
                if IsWall(D3DXVECTOR3(p1.x, p1.y, p1.z)) then
                        if not IsWall(D3DXVECTOR3(p2.x, p2.y, p2.z)) and mousePos.y-myHero.y < 225 then
                                CastSpell(_E, p2.x, p2.z)
                                myHero:MoveTo(p2.x, p2.z)
                        else
                                myHero:MoveTo(p3.x, p3.z)
                        end
                else
                        myHero:MoveTo(p1.x, p1.z)
                end
	end
end

function Lucian:CastQ(target, menu)
	if menu and self.Q.IsReady() and ValidTarget(target, self.Q.range) then
		CastSpell(_Q, target)
	end
end

function Lucian:CastQExt(target, menu)
	local CastPosition = UPL:Predict(_Q, myHero, target)
        if not menu or CastPosition == nil then return end
        local targetPos = self:VectorExtend(Vector(myHero), Vector(CastPosition), self.QExt.range)

        if self.Q.IsReady() and ValidTarget(target) and GetDistance(CastPosition) <= self.QExt.range then
    	        for i, minion in pairs(self.Minions.objects) do
    		        if minion and not minion.dead and minion.team ~= myHero.team and ValidTarget(minion, self.Q.range) then
    			        local minionPos = self:VectorExtend(Vector(myHero), Vector(minion), self.QExt.range)
    			        if GetDistance(targetPos, minionPos) <= self.QExt.width then
    				        CastSpell(_Q, minion)
    			        end
    		        end
    	        end
        end
end

function Lucian:CastW(target, menu, fast)
	if menu and self.W.IsReady() and ValidTarget(target, self.W.range) then
		if not fast then
			local CastPosition, HitChance, HeroPosition = UPL:Predict(_W, myHero, target)
                        if CastPosition and HitChance > 0 then
                                CastSpell(_W, CastPosition.x, CastPosition.z)
                        end
		else
			CastSpell(_W, target.x, target.z)
		end
	end
end

function Lucian:CastE(target, menu, mode, range)
	if menu and self.E.IsReady() and ValidTarget(target) then
		if mode == 1 then
			local Center1 = Vector(myHero)
	                local Center2 = Vector(target)
	                local Radius1 = myHero.range
	                local Radius2 = 525
	                local OUT1, OUT2 = self:CircleCircleIntersection(Center1, Center2, Radius1, Radius2)
	                if OUT1 or OUT2 then
	        	        local Pos = self:VectorExtend(Vector(myHero), Vector(self:ClosestToMouse(OUT1, OUT2)), range)
	        	        CastSpell(_E, Pos.x, Pos.z)
	                end
		elseif mode == 2 then
			local Pos = self:VectorExtend(Vector(myHero), Vector(mousePos), range)
			CastSpell(_E, Pos.x, Pos.z)
		elseif mode == 3 then
			local Pos = self:VectorExtend(Vector(myHero), Vector(target), range)
			CastSpell(_E, Pos.x, Pos.z)
		end
	end
end

function Lucian:CircleCircleIntersection(c1, c2, r1, r2)
	local D = GetDistance(c1, c2)
	if D > r1 + r2 or D <= math.abs(r1 - r2) then
		return nil
	end
	local A = (r1 * r2 - r2 * r1 + D * D) / (2 * D)
	local H = math.sqrt(r1 * r1 - A * A)
	local Direction = (c2 - c1):normalized()
	local PA = c1 + A * Direction
	local S1 = PA + H * Direction:perpendicular()
	local S2 = PA - H * Direction:perpendicular()	
	return S1, S2
end

function Lucian:VectorExtend(v1, v2, distance)
        return v1 + distance * (v2 - v1):normalized()
end

function Lucian:ClosestToMouse(p1, p2)
	if GetDistance(mousePos, p1) > GetDistance(mousePos, p2) then return p2 else return p1 end
end

function Lucian:DrawRectangleOutline(startPos, endPos, width, color)
    local c1 = startPos+Vector(Vector(endPos)-startPos):perpendicular():normalized()*width
    local c2 = startPos+Vector(Vector(endPos)-startPos):perpendicular2():normalized()*width
    local c3 = endPos+Vector(Vector(startPos)-endPos):perpendicular():normalized()*width
    local c4 = endPos+Vector(Vector(startPos)-endPos):perpendicular2():normalized()*width
    DrawLine3D(c1.x,c1.y,c1.z,c2.x,c2.y,c2.z,math.ceil(width/100),color)
    DrawLine3D(c2.x,c2.y,c2.z,c3.x,c3.y,c3.z,math.ceil(width/100),color)
    DrawLine3D(c3.x,c3.y,c3.z,c4.x,c4.y,c4.z,math.ceil(width/100),color)
    DrawLine3D(c1.x,c1.y,c1.z,c4.x,c4.y,c4.z,math.ceil(width/100),color)
end

function Lucian:SkinChanger()
	SetSkin(myHero, self.Config.Skin.List - 1)
end
