--------------------------------------------------------------------

local Player = math.__player

--------------------------------------------------------------------

if Player then

	world.sendEntityMessage(Player.id(), 'rexactions.open')

end

--------------------------------------------------------------------