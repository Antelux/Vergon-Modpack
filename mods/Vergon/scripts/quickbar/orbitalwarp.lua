--------------------------------------------------------------------

math.__orbitalWarp = math.__orbitalWarp or {
	
	lastWarpTime = 0

}

--------------------------------------------------------------------

local OrbitalWarp = math.__orbitalWarp
local Player      = math.__player

--------------------------------------------------------------------

local TimeNow = os.clock()

--------------------------------------------------------------------

if Player and ((TimeNow - OrbitalWarp.lastWarpTime) >= 5) then

	OrbitalWarp.lastWarpTime = TimeNow

	if Player.worldId():find('^ClientShipWorld:') then

		Player.warp('OrbitedWorld', 'beam')

	else

		Player.warp('OwnShip', 'beam')

	end

end

--------------------------------------------------------------------