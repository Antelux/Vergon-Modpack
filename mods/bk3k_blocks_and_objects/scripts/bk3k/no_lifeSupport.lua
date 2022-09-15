--incorporate the life support patch changes in case the mad tulip mod is present
Init_personal_life_support_system = function() end
Update_personal_life_support_system = function() end

is_shipworld = function()
  return world.getProperty("ship.fuel") ~= nil
end

function is_ownShip()
  return (player.worldId() == player.ownShipWorldId())
end