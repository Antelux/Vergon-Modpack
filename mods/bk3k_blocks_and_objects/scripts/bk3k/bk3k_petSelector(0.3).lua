--this is a script addon for techstations.  It allows the pet to be selected based upon the nearest player's race on init().
--toDo : 
  --detect other mods that alter pets and account for their intent.
  --fill out mod racial pets


--bk3k_pet = { init = init, update = update }

local runOnce
local real_update
local petLess_update
local set_params
local set_petParams
local set_petType
local ownerSpecies
local set_owner
local send_messages
local load_worldProperties
local commit_worldProperties
local clearPet
local is_shipWorld
local weightedChoice
local makeString


function init()
  message.setHandler("activateShip", function()
    animator.playSound("shipUpgrade")
    self.dialog = config.getParameter("dialog.wakeUp")
    self.dialogTimer = 0.0
    self.dialogInterval = 5.0
    self.drawMoreIndicator = true
    object.setOfferedQuests({})
  end)

  message.setHandler("wakePlayer", function()
    self.dialog = config.getParameter("dialog.wakePlayer")
    self.dialogTimer = 0.0
    self.dialogInterval = 14.0
    self.drawMoreIndicator = false
    object.setOfferedQuests({})
  end)
  
  message.setHandler("clearPet", function()
    clearPet()
    --so cruel
  end)

  self.spawnOffset = config.getParameter("spawnOffset", {0, 2})
  
  storage.state = storage.state or false  --this will mark if the object has been placed in a previous session.
  storage.playerMessages = {}  --no attempt to preserve, may change mind
  storage.messageLife = 0
  storage.playerDelay = 1.50
  
  storage.maxInputNode = ( #(config.getParameter("inputNodes", {})) - 1 )
  storage.maxOutputNode = ( #(config.getParameter("outputNodes", {})) - 1 )
    --standard LUA tables start at 1 instead of 0.  Starbound assignes the first node to 0 despite this.

  storage.out0 = (storage.maxOutputNode > -1)
  storage.out1 = (storage.maxOutputNode > 0)
  
  storage.alt_interaction = config.getParameter("alt_interaction") or config.getParameter("interaction")
  --storage.propertyChange = false
  --sb.logInfo("\nPet Selector Loaded\ninit() ended\n")
end


runOnce = function(dt)
  sb.logInfo("\nPet Selector\nrunOnce() start\n")
  
  --this is something that will take the place of update for a tic
  --because you you need to wait til after the player entitiy exist before you can do what needs done.
     
  local alreadySet = load_worldProperties("bk3k_petSpawner")  --thus function returns a boolean besides setting things
  
  if storage.worldProperties.noPet then
    _ENV.update = petLess_update
    return
  elseif not alreadySet then
    if storage.messageLife > 0 then
      storage.messageLife = storage.messageLife - dt
    else
      send_messages("is_own_shipWorld")
    end
    
    storage.worldProperties.ownerSpecies = ownerSpecies()
    
    if storage.worldProperties.ownerSpecies then
      set_petType()  --this sets some storage.worldProperties when not already determined
      commit_worldProperties("bk3k_petSpawner")
    else
      --try again later
      return
    end
  end
    
  sb.logInfo("Pet Selector\nrunOnce was a success\n")
  storage.state = true
  _ENV.update = real_update
end


local __ = [[
playerDelay = function(dt)
  --this is only needed for brand new players directly after generation.
  if storage.state and (storage.playerDelay > 0) then
    storage.playerDelay = storage.playerDelay - dt
  else
    storage.playerDelay = nil
    update = runOnce
  end

end
]]

--------------------
if not (storage and storage.state) then
  update = runOnce
end
--------------------

real_update = function(dt)
  if (self.petId == nil) or not world.entityExists(self.petId) then
    self.petId = world.spawnMonster(storage.worldProperties.petType, object.toAbsolutePosition(self.spawnOffset), storage.worldProperties.petParams)
    world.callScriptedEntity(self.petId, "setAnchor", entity.id())
  end
  
  if self.dialogTimer then
    self.dialogTimer = math.max(self.dialogTimer - dt, 0.0)
    if self.dialogTimer == 0 and not sayNext() then
      self.dialogTimer = nil
    end
  end
  
  if self.dialogTimer == nil then
    object.setOfferedQuests(config.getParameter("offeredQuests"))
  end
end


petLess_update = function(dt)
    if self.dialogTimer then
    self.dialogTimer = math.max(self.dialogTimer - dt, 0.0)
    if self.dialogTimer == 0 and not sayNext() then
      self.dialogTimer = nil
    end
  end
  
  if self.dialogTimer == nil then
    object.setOfferedQuests(config.getParameter("offeredQuests"))
  end
end


set_params = function(params, insert, replace, default)
  replace = replace or {}
  insert = insert or {}
  default = default or {}
    
  for k, v in pairs(insert) do
    if params[k] == nil then 
      params[k] = v 
    end
  end
  
  for k, v in pairs(default) do
    if params[k] == nil then
      params[k] = v
    end
  end
  
  for k, v in pairs(replace) do
    params[k] = v
  end
  
  return params
end


set_petParams = function(petGroup, insert, replace)
  local default = { level = math.max(world.threatLevel(), 1) }
  local params = petGroup[storage.selector][3] or {}
  replace = replace or {}
  insert = insert or {}
      
  return set_params(params, insert, replace, default)
end


set_petType = function()
  local all_petGroups = root.assetJson("/spawning.config:petGroups")
  local petGroup = all_petGroups[storage.worldProperties.ownerSpecies] or "default"
    --"default" would account for yet unsupported races.  They would be nil entries.
  storage.selector = storage.selector or weightedChoice(petGroup)
  local petType = petGroup[storage.selector][2] or "petcat"
  
  storage.worldProperties.petType = petType
  storage.worldProperties.selector = selector
  storage.worldProperties.petParams = set_petParams(petGroup)
end


ownerSpecies = function()
  if storage.worldProperties and storage.worldProperties.ownerSpecies then
    return storage.worldProperties.ownerSpecies
  else
    local playerId = set_owner()
    if playerId then
      return world.entitySpecies(playerId) or "default"
      --if for some reason a species identifier cannot be returned, set to "default"
    else
      return false
    end
  end
end


set_owner = function()
  --I'd like to find a better way to know who "owns" a shipworld
  --possibly something under world.getProperty("owner_etc")
  --but considering this imprints into the world shortly after ship world generation,
    --I can't imagine anyone but the player being the target.
  sb.logInfo("\nPet Selector\nset_owner() start")
  
  local bs = [[
  local args = { 
    includedTypes = {"player"},
    order = "nearest",
    callScript = "is_own_shipWorld"
  }
  local owner = world.entityQuery(object.position(), 5000, args)
  
  local dump = makeString(owner, "owner", "\nset_owner()\n")
  sb.logInfo(dump)
  ]]  --THIS DOESN'T WORK!  It won't call the script.  Client/server context issue?
  
  for playerId, message in pairs(storage.playerMessages) do
    if message:finished() and message:result() and world.entityExists(playerId) then
      local UUID = world.entityUniqueId(playerId)
      storage.worldProperties.ownerUUID = UUID world.entityUniqueId(playerId)
      --may come in handy later?  I assume this will never change
      sb.logInfo("\nplayer finally found with ID " .. playerId .. "\n")
      return playerId
    end        
  end
  
  return false
  
end


send_messages = function(message)
  local allPlayers = world.players()
  for _, p in ipairs(allPlayers) do
    if world.entityExists(p) then 
      storage.playerMessages[p] = world.sendEntityMessage(p, message)
    end
  end
  storage.messageLife = math.fRandom(1.25, 1.75)  --why random?  why not?
end


load_worldProperties = function(what_storageTable)
  --don't store your things under anything generic.  Make a unique name for the purpose.
  storage.worldProperties = storage.worldProperties or {}
  local wProperties = world.getProperty(what_storageTable)
  
  if storage.worldProperties and wProperties then
    --possible to merge properties from multiple storage tables.  The last loaded would over-write conflicting indexes.
    for k, v in pairs(wProperties) do
      storage.worldProperties[k] = v
    end
    --storage.propertyChange = true
  elseif wProperties then
    storage.worldProperties = wProperties
  end
  
  local dump = makeString(storage.worldProperties, "storage.worldProperties", "\nload_worldProperties( " .. what_storageTable .. " )\n")
  dump = dump .. makeString(wProperties, "wProperties", "")
  dump = dump .. "\nentityId : " .. tostring(entity.id()) .. "\n"
  sb.logInfo(dump)
  
  return wProperties ~= nil
  --return if properties already exist, otherwise they still need set.
end


commit_worldProperties = function(what_storageTable)
  --I don't want to imprint this stuff on non-shipworlds for multiplayer reasons
    --I don't want to act like anyone "owns" non-shipworlds.
    --A side effect might be the pet could change on non-shipworlds
  if is_shipWorld() then
    world.setProperty(what_storageTable, storage.worldProperties)
  end
end


clearPet = function(replacet)  --not yet called, reserving option.  Also untested.
  replace = replace or false
  storage.worldProperties.petType = nil
  storage.worldProperties.petParams = nil
  --you now need to set this!
  
  if world.entityExists(self.petId) then
    --local pos = world.entityPosition(self.petId)
    world.callScriptedEntity(self.petId, "die")
    --world.spawnItem()  --might have it drop meat :D 
    --but want to build a drop table first and a "thoughtful" message from S.A.I.L.
  end
  
  self.petId = nil
  
  if replace == false then
    _ENV.update = petLess_update
    storage.worldProperties.noPet = true
    commit_worldProperties("bk3k_petSpawner")
  end
end


onInputNodeChange = function(args)
--@tab args Map of:
--{
--  node = <(int) index of the node that is changing>
--  level = <new level of the node>
--}

  if object.getInputNodeLevel(0) then
    storage.altInteraction = true
  else  
    storage.altInteraction = false
  end
  
end


onNodeConnectionChange = function(args)

end


is_shipWorld = function()
  return world.getProperty("ship.fuel") ~= nil
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


math.fRandom = function(fMin, fMax, precision)
  --precision should be 10, 100, 1000, etc with a zero for every digit you want in precision
  --if not utilized, default to 100
  precision = precision or 100
  --this returns a random float number between min and max
  --with the exception that the arguments with be effectively reduced to 2 digits of precision.
  
  return math.random( math.floor(fMin * precision), math.floor(fMax * precision) ) / precision
end


makeString = function(someTable, baseName, str)--debug purposes only
  str = str or ""
  local isEmpty = true
  
  if someTable == nil then
    str = str .. baseName .. " : nil\n"
    return str
  end
  
  local blank = function(v)
    for _, __ in pairs(v) do
      return false
    end
    return true
  end
  
  for k, v in pairs(someTable) do
    isEmpty = false
    if type(v) == "table" then
      if (#v == 2) and (type(v[1]) == "number") and (type(v[2]) == "number") then  --coordinate table
        str = str .. baseName .. "." .. tostring(k) .. " : {" .. v[1] .. ", " .. v[2]  .. "}\n"
      elseif blank(v) then
        str = str .. baseName .. "." .. tostring(k) .. " : { }\n"
      else
        str = str .. makeString(v , baseName .. "." .. tostring(k), "") --.. "\n"
        --recursive calls don't necessarily need the original string because the main function will still have it
      end

    elseif (type(v) == "string") then
      str = str .. baseName .. "." .. tostring(k) .. " : \"" .. v .. "\"\n"
    elseif not (type(v) == "function") then
      str = str .. baseName .. "." .. tostring(k) .. " : " .. tostring(v) .. "\n"
    end
  end
  
  if isEmpty then
    str = str .. baseName .. " : { }\n"
  end
  
  return str
end