--I was doing this through hooks, but in this case it is just too messy.  It isn't a good solution for this scenario.
local is_shipWorld

onInteraction = function()
  local ship = is_shipWorld()
  if self.dialogTimer then
    sayNext()
  elseif ship() and storage.altInteraction then  --S.A.I.L. shouldn't get called off the ship.
    return alt_interaction
  elseif ship then
    return config.getParameter("interactAction")
  else
    return nil
  end
end
--I wanted onInteraction to be changed - Pet mods or no.
--In some cases this will be replaced... again.


if hasPet and math.fRandom == nil then
  --if hasPet() is missing then a mod is present that either removes pets like "No Pets"
    --or untethers them from the techstations like "Purchasable Pets"
  --Either abort the pet selector scripts.
  
  --require("/scripts/bk3k/bk3k_petSelector(0.3).lua")
end


local modEnvironment = function(whatKey)
  local modEnvironment = root.assetJson("/player.config:modEnvironment")
  return whatMod and modEnvironment[whatKey] or false
end


is_shipWorld = function()
  return world.getProperty("ship.fuel") ~= nil
end