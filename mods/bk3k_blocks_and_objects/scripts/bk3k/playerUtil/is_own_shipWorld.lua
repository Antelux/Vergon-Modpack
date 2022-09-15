--all this does is add a reliable way to find out if a player owns the shipwold.  That makes for a reasonable way to determine if they should be allowed to operate a shield generator, captain's chair, go through special access doors, etc.  Any sort of privaleged functions.

--The greatest benefit is being able to make mechanics which allow players to have potentially untrustworthy folk on their ship without fear.

local bk3k_ownShip_init = init

init = function(...)
  message.setHandler("is_own_shipWorld", function() return (player.worldId() == player.ownShipWorldId()) end)
  bk3k_ownShip_init(...)
end

--I might consider similar mechanics for "owning" other worlds, but maybe that should be a seperate mod.