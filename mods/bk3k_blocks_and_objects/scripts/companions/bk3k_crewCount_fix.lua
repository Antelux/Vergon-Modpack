local sr_init = init
local sr_update = update

--I'm hooking init and update
--The purpose of doing so is to make the ship upgradable at shipLevel * 2 crew 
--instead of forcing the player to max out the crew first.  Especially since I have set a maximum crew of 200!
--This is necessary to enable non-illegal upgrading again

function init(args)
  sr_init(args)
  storage.sr_upgradeTimer = 20.5
  storage.upgradeUnlockCount = (math.max( (player.shipUpgrades().shipLevel - 2), 1) * 2) - 1
    --The ship has 2 crew threw level 3, therefore treat 0-3 as 1
    --the -1 offset so I can use > instead of >= just to be cheap
  storage.ownShipWorldId = player.ownShipWorldId()
  
end

function update(dt)
  sr_update(dt)
  
  if storage.sr_upgradeTimer > 0 then
    storage.sr_upgradeTimer = storage.sr_upgradeTimer - dt
  else 
    if player.worldId() == storage.ownShipWorldId and recruitSpawner:crewSize() > storage.upgradeUnlockCount then
      grantNextLicense()
    end
    storage.sr_upgradeTimer = 62
  end
end