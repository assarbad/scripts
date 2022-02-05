
cl_display_hud = 1
cl_drunken_cam = 0
ThirdPersonView = 0
--p_model = "objects/characters/pmodels/hero/hero.cgf"

--Input:BindCommandToKey('#Movie:StopAllCutScenes()',"F7",1);
--Input:BindCommandToKey("\\SkipCutScene","F7",1);

-- Developer Cheat keys ---

--- non standard key bindings ---
-- Please NEWER use F9,F10 keys (reserved for debug purposes) (Vlad)

--Input:BindCommandToKey("#SwitchCameraMode()","f1",1);
-- Input:BindCommandToKey("#r_GetScreenShot=1","f12",1); -- this is now bindable
Input:BindCommandToKey("#ToggleAIInfo()","f11",1);

--Input:BindCommandToKey("#ToggleScreenshotMode()","f11",1);

Input:BindCommandToKey("#ToggleNewDesignerMode(10,15,0)","f4",1);

-- to be removed
Input:BindCommandToKey("#GotoNextSpawnpoint()","f2",1);
Input:BindCommandToKey("#MoreAmmo()","o",1);
Input:BindCommandToKey("#AllWeapons()","p",1);
Input:BindAction("SAVEPOS", "f9", "default");
Input:BindAction("LOADPOS", "f10", "default");
Input:BindCommandToKey("#ToggleNewDesignerMode(40,120,1)","f3",1);
Input:BindCommandToKey("#System:ShowDebugger();", "f8", 1);

-- to be removed

-- removed
--Input:BindCommandToKey("#Game.Save()","f5",1);
--Input:BindCommandToKey("#Game.Load()","f6",1);
--Input:BindCommandToKey("#DefaultSpeed()","=",1);
--Input:BindCommandToKey("#DecreaseSpeed()","<",1);
--Input:BindCommandToKey("#IncreaseSpeed()",">",1);
--Input:BindCommandToKey("#p_single_step_mode=1-p_single_step_mode","[",1);
--Input:BindCommandToKey("#p_do_step=1","]",1);
--Input:BindCommandToKey("#TCM()",".",1);
--Input:BindCommandToKey("#e_hires_screenshoot=4","f10",1);
-- removed


--- temp variables for functions below ---
prev_speed_walk=p_speed_walk;
prev_speed_run=p_speed_run;

prev_speed_walk2=p_speed_walk;
prev_speed_run2=p_speed_run;

default_speed_walk=p_speed_walk;
default_speed_run=p_speed_run;

screenshotmode=0;


function ToggleAIInfo()
	
	if (not aiinfo) then
		aiinfo=1;
	else
		aiinfo=1-aiinfo;
	end

	if (aiinfo==1) then
		ai_debugdraw=1;
		ai_drawplayernode=1;
		ai_area_info=1;
	else
		ai_debugdraw=0;
		ai_drawplayernode=0;
		ai_area_info=0;
	end
end

function GotoNextSpawnpoint()

	Hud:AddMessage("[NEXT]: next spawn point");

	local pt;
	pt=Server:GetNextRespawnPoint();

	if(not pt)then												-- last respawn point or there are no respawn points
		pt=Server:GetFirstRespawnPoint();		-- try to get the first one
	end

	if(pt)then														-- if there is one
		Game:ForceEntitiesToSleep();

		_localplayer:SetPos(pt);
		_localplayer:SetAngles({ x = pt.xA, y = pt.yA, z = pt.zA });
	end
end

function SetPlayerPos()
	local p=_localplayer
	p:SetPos({x=100,y=100,z=300});
end

-- replacement for ToggleSuperDesignerMode() and ToggleDesignerMode()
--
-- USAGE:
--  deactivate designer mode: (nil,nil,0)
--  old super designer mode (with collision): (40,120,1)
--  old designer mode (without collision): (10,15,0)
--  change values: call with (nil,nil,0) then with the new values (0.., 0.., 0/1)
--
function ToggleNewDesignerMode( speedwalk, speedrun, withcollide )

	if(SuperDesignerMode_Save1~=nil or speedwalk==nil) then
		Hud:AddMessage("[CHEAT]: Designer fly mode OFF");

		p_speed_walk = SuperDesignerMode_Save1;
		p_speed_run = SuperDesignerMode_Save2;
		_localplayer.DynProp.gravity = SuperDesignerMode_Save3;
		_localplayer.DynProp.inertia = SuperDesignerMode_Save4;
		_localplayer.DynProp.swimming_gravity = SuperDesignerMode_Save5;
		_localplayer.DynProp.swimming_inertia = SuperDesignerMode_Save6;
		_localplayer.DynProp.air_control = SuperDesignerMode_Save7;
		_localplayer.cnt:SetDynamicsProperties( _localplayer.DynProp );
		SuperDesignerMode_Save1=nil;

		-- activate collision, parameter is 0 or 1
		_localplayer:ActivatePhysics(1);

	else
		Hud:AddMessage("[CHEAT]: Designer fly mode ON");

		SuperDesignerMode_Save1 = p_speed_walk;
		SuperDesignerMode_Save2 = p_speed_run;
		SuperDesignerMode_Save3 = _localplayer.DynProp.gravity;
		SuperDesignerMode_Save4 = _localplayer.DynProp.inertia;
		SuperDesignerMode_Save5 = _localplayer.DynProp.swimming_gravity;
		SuperDesignerMode_Save6 = _localplayer.DynProp.swimming_inertia;
		SuperDesignerMode_Save7 = _localplayer.DynProp.air_control;

		p_speed_walk = speedwalk;
		p_speed_run = speedrun;
		_localplayer.DynProp.gravity=0.0;
		_localplayer.DynProp.inertia=0.0;
		_localplayer.DynProp.swimming_gravity=0.0;
		_localplayer.DynProp.swimming_inertia=0.0;
		_localplayer.DynProp.air_control=1.0;
		_localplayer.cnt:SetDynamicsProperties( _localplayer.DynProp );

		-- deactivate collision, parameter is 0 or 1
		_localplayer:ActivatePhysics(withcollide);
	end
end

function ToggleScreenshotMode()

	if(screenshotmode~=0) then
		System:LogToConsole("SCREENSHOTMODE OFF-->SWITCH TO NORMAL");
		screenshotmode=0;
		hud_crosshair = "1"
		cl_display_hud = "1"
		r_NoDrawNear = "0"
		ai_ignoreplayer = "0"
		ai_soundperception = "1"
		r_DisplayInfo = "1"
	else
		System:LogToConsole("SCREENSHOTMODE ON");
		screenshotmode=1;
		hud_crosshair = "0"
		cl_display_hud = "0"
		r_NoDrawNear = "1"
		ai_ignoreplayer = "1"
		ai_soundperception = "0"
		r_DisplayInfo = "0"
	end
end

-- function DecreaseSpeed()

-- 	if tonumber(p_speed_walk)>5 then
-- 		p_speed_walk=p_speed_walk-5;
-- 		p_speed_run=p_speed_run-5;
-- 		Hud:AddMessage("Decreased player speed by 5");
-- 		System:LogToConsole("Decreased player speed by 5");
-- 	else
-- 		Hud:AddMessage("You can not go any slower!");
-- 		System:LogToConsole("You can not go any slower!");
-- 	end 
-- end

-- function IncreaseSpeed()

-- 	if tonumber(p_speed_walk)<500 then
-- 		p_speed_walk=p_speed_walk+5;
-- 		p_speed_run=p_speed_run+5;
-- 		Hud:AddMessage("Increased player speed by 5");
-- 		System:LogToConsole("Increased player speed by 5");
-- 	else
-- 		Hud:AddMessage("You can not go any faster!");
-- 		System:LogToConsole("You can not go any faster!");
-- 	end 
-- end

-- function DefaultSpeed()

-- 	p_speed_walk=default_speed_walk;
-- 	p_speed_run=default_speed_run;
-- 	System:LogToConsole("Player speed reset");
-- end

function TeleportToSpawn(n)
	local player = _localplayer;
	local pos = Server:GetRespawnPoint("Respawn"..n);
	if pos then
		player:SetPos(pos);
		player:SetAngles({ x = pos.xA, y = pos.yA, z = pos.zA });
	end
end


-- Give the player the passed weapon, load it if neccesary
function AddWeapon(Name)

	Game:AddWeapon(Name)
	for i, CurWeapon in WeaponClassesEx do
		if (i == Name) then
			_localplayer.cnt:MakeWeaponAvailable(CurWeapon.id);
		end
		AmmoGalore()
	end
end

function AmmoGalore()
	if _localplayer then
		for k, v in _localplayer.Ammo do
			_localplayer.Ammo[k] = 999
		end
	end
end

function MoreAmmo()
	if _localplayer then
		AmmoGalore()
		_localplayer.cnt.ammo=999;

		Hud:AddMessage("[CHEAT]: Give 999 ammo");
		System:LogToConsole("\001CHEAT: Give 999 ammo");
	else 
		Hud:AddMessage("[CHEAT]: no ammo today");
	end
end

function AllWeapons()
	AddWeapon("AG36");
	AddWeapon("Falcon");
	AddWeapon("SniperRifle");
	AddWeapon("MP5");
	AddWeapon("RL");
	AddWeapon("Shotgun");
	AddWeapon("OICW");
	AddWeapon("P90");
	AddWeapon("M4");

	-- _localplayer.cnt:GiveBinoculars(1);
	_localplayer.cnt:GiveFlashLight(1);
	AmmoGalore()

	Hud:AddMessage("[CHEAT]: Give all weapons");
	System:LogToConsole("\001CHEAT: Give All weapons");
end

default_speeds = nil

function AccelerateSpeedsBy(val, factor)
	if _localplayer then
		-- Save default speeds
		if default_speeds == nil then
			default_speeds = {}
			for k, v in _localplayer.move_params do
				if (strfind(k, "speed_")) then
					default_speeds[k] = v
				end
			end
		end
		local f = factor or 1.0
		for k, v in _localplayer.move_params do
			if (strfind(k, "speed_")) then
				_localplayer.move_params[k] = (_localplayer.move_params[k] * f) + val
			end
		end
		_localplayer.cnt:SetMoveParams(_localplayer.move_params)
	end
end

function ShowSpeeds(descr)
	if _localplayer then
		local speedstr = ""
		for k, v in _localplayer.move_params do
			if (strfind(k, "speed_")) and not (strfind(k, "_back") or strfind(k, "_strafe")) then 
				speedstr = speedstr .. format(" %s=%.1f, ", k, _localplayer.move_params[k])
			end
		end
		Hud:AddMessage(format("[CHEAT]: Current %sspeeds:" .. speedstr, descr or ""));
	end
end

function GoFaster()
	AccelerateSpeedsBy(0.5, nil)
	ShowSpeeds("faster ")
end

function GoSlower()
	AccelerateSpeedsBy(-0.5, nil)
	ShowSpeeds("slower ")
end

function DefaultSpeeds()
	if (default_speeds ~= nil) and _localplayer then
		for k, v in _localplayer.move_params do
			if (strfind(k, "speed_")) then
				_localplayer.move_params[k] = default_speeds[k]
			end
		end
		_localplayer.cnt:SetMoveParams(_localplayer.move_params)
		ShowSpeeds("default ")
	end
end
Input:BindCommandToKey("#DefaultSpeeds()","=",1);
Input:BindCommandToKey("#GoSlower()","<",1);
Input:BindCommandToKey("#GoFaster()",">",1);

function GodLike_Client_OnTimerCustom(self)
	if (Hud and self == _localplayer) then
		self.cnt.health = self.cnt.max_health
		self.cnt.armor = self.cnt.max_armor
		self.cnt.stamina = 100
	end
end

function ToggleGod()
	if (Hud and _localplayer) then
		if _localplayer.Client_OnTimerCustom == nil then
			_localplayer.Client_OnTimerCustom = GodLike_Client_OnTimerCustom
			_localplayer.NoFallDamage = 1
			Hud:AddMessage("[CHEAT]: (Say in Homer Simpson's voice) I am invincible!");
			DefaultSpeeds()
			AccelerateSpeedsBy(0, 2.5)
		else
			_localplayer.Client_OnTimerCustom = nil
			_localplayer.NoFallDamage = nil
			DefaultSpeeds()
			Hud:AddMessage("[CHEAT]: ... and back to mortal");
		end
	end
end
Input:BindCommandToKey("#ToggleGod()","backspace",1);

-- Heat vision aka Cryvision
function ToggleCryvision()
	local cv = getglobal("r_Cryvision")
	if (cv==0) then
		setglobal("r_Cryvision", 1)
	else
		setglobal("r_Cryvision", 0)
	end
	cv = getglobal("r_Cryvision")
	if (cv==0) then
		System:LogToConsole("Cryvision OFF");
		Hud:AddMessage("[CHEAT]: Cryvision OFF");
	else
		System:LogToConsole("Cryvision ON");
		Hud:AddMessage("[CHEAT]: Cryvision ON");
	end
end
Input:BindCommandToKey("#ToggleCryvision()","i",1);
