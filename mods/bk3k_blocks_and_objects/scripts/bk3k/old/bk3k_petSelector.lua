--this is a script addon for techstations.  It allows the pet to be selected based upon the nearest player's race on init().
--toDo : 
  --detect other mods that alter pets and account for their intent.
  --fill out mod racial pets

math.fRandom = function(fMin, fMax, precision)
  --precision should be 10, 100, 1000, etc with a zero for every digit you want in precision
  --if not utilized, default to 100
  precision = precision or 100
  --this returns a random float number between min and max
  --with the exception that the arguments with be effectively reduced to 2 digits of precision.
  
  return math.random( math.floor(fMin * precision), math.floor(fMax * precision) ) / precision
end


bk3k_pet = {
  init = init,
  update = update
}


init = function()
  ----( world properties
  local wProperties = world.getProperty("bk3k_petSpawner")
  if wProperties then 
    storage.worldProperties = wProperties
  else
    storage.worldProperties = {}
  end
  ----)
  
  storage.petGroups = storage.petGroups or root.assetJson("/spawning.config:petGroups")
  storage.ownerSpecies = storage.ownerSpecies or set_ownerSpecies()
  
  set_petType()
  storage.petParams = storage.petParams or storage.worldProperties.petParams or set_petParams()
  bk3k_pet.init()
    --vanilla init()
  bk3k_pet.post_init()
end


bk3k_pet.post_init = function() 

  set_petType() --because the vanilla init() edits self.monsterType without looking for a value first
                --this will have less work to do the second time anyhow
  
  if is_shipWorld() then
    --I don't want to imprint this stuff on non-shipworlds for multiplayer reasons
      --I don't want to act like anyone "owns" non-shipworlds.
      --A side effect might be the pet could change on non-shipworlds
    world.setProperty("bk3k_petSpawner", storage.worldProperties)
  end
      
end


update = function(dt)
  if self.petId and not world.entityExists(self.petId) then
    self.petId = nil
  end
  
  if not self.petId then
    self.petId = world.spawnMonster(self.monsterType, object.toAbsolutePosition(self.spawnOffset), storage.petParams)
    world.callScriptedEntity(self.petId, "setAnchor", entity.id())
  end
  
  bk3k_pet.update(dt)
end


set_petParams = function(insert)
  insert = insert or {}
  local default = {
    level = math.max(world.threatLevel(), 1)
  }
  
  local params = storage.petGroups[storage.ownerSpecies][storage.selector][3]
  for k, v in pairs(insert) do
    if params[k] == nil then 
      params[k] = v 
    end
  end
  
  for i, d in pairs(default) do
    if params[i] == nil then
      params[i] = d
    end
  end
  storage.petParams = params
  
  storage.worldProperties.petParams = params
    
  
end


set_petType = function()
  if storage.worldProperties and storage.worldProperties.petType then
    self.monsterType = storage.worldProperties.petType
    return
  end
  
  local petGroup = storage.petGroups[storage.ownerSpecies] or "default"
    --"default" would account for yet unsupported races.  They would be nil entries.
  selector = storage.selector or weightedChoice(petGroup)
  local petType = petGroup[selector][2] or "petcat"
  
  self.monsterType = petType
  storage.worldProperties.petType = petType
  storage.selector = selector
  storage.worldProperties.selector = selector
end


set_ownerSpecies = function()
  if storage.worldProperties and storage.worldProperties.ownerSpecies then
    return storage.worldProperties.ownerSpecies
  end
  
  --I'd like to find a better way to know who "owns" a shipworld
  --possibly something under world.getProperty("owner_etc")
  --but considering this imprints into the world shortly after ship world generation,
    --I can't imagine anyone but the player being the target.
  
  local players = world.playerQuery(object.position(), 5000, { order = "nearest" })
  local playerId = players[1]
  local species = world.entitySpecies(playerId) or "default"
    --if for some reason a species identifier cannot be returned, set to "default"
  local UUID = world.entityUniqueId(playerId)
  
  storage.worldProperties.ownerSpecies = species
  storage.worldProperties.ownerUUID = UUID --may come in handy later?  I assume this will never change
  
  return species
end


clearPet = function()  --not yet called, reserving option.  Also untested.
  storage.worldProperties.petType = nil
  storage.worldProperties.petParams = nil
  --you now need to set this!
  
  if world.entityExists(self.petId) then
    --local pos = world.entityPosition(self.petId)
    world.callScriptedEntity(self.petId, "die")
    --world.spawnItem()  --might have it drop meat :D 
      --but want to build a drop table first
  end
  self.petId = nil
end


weightedChoice = function(group)
  local groups = #group
  if groups == 1 then
    return 1
  end
  
  local weight = 0
  
  for _, iWeight in ipairs(group) do
    weight = weight + iWeight[1]
  end

  local winner = math.fRandom(0, weight)
  
  local i = 0
  local set = {}
  while i < groups do
    i = i + 1
    set = group[i]
    winner = winner - set[1]
    if winner < 0 then
      return i
    end
    
  end
  
  --failsafe for fRandom return of 0.00, return last group
  return #group
end

  
is_shipWorld = function()
  return world.getProperty("ship.fuel") ~= nil
end