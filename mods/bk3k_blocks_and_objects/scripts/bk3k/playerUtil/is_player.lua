--this file may not be a part of this mod, but is here for now.  More of a concept at this point.

--I was thinking that some possibilities exist that some races might not treat others equally for immersion purposes. For example it seems likely that hylotl might be weary around florans, some tribal florans might want to eat "meat" species, etc


local is_player = function(args)
  local match = true
  local ID = player.id()
  args = args or {}
  
  if args.species then
    match = match and player.species() == arg.race
  end
  if args.gender then 
    match = match and player.gender() == args.gender
  end
  if args.howRich then
    for currency, amount in pairs(args.howRich.currencies) do
      match = match and (world.entityCurrency(ID, currency) or 0) >= amount
    end
  end
  if args.tasty then
    local tastyConfig = root.assetJson("hunger.config:foodConfig") or false
      --toDo, tentative location could change.
    local howTasty = 0
    local valid = tastyConfig and tastyConfig.source[args.tasty.perspective]
        
    if valid then
      local perspective = tastyConfig.source[args.tasty.perspective] --who is asking, for example "floran"
      howTasty = perspective[player.species()] or 0
        --how tasty is the player's species?
    end
    match = match and howTasty >= args.tasty.howTasty
  end
  if args.owner then
  
  end
  if args.faction then
  
  end
  if args.custom then
  
  end
    
  return match
end



local is_UUID = function(UUIDs)
  --for returning only players matching a UUID
end
