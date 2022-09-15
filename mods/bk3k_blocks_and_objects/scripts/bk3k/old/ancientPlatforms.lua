--doing something a little different here.  In many cases I'm not calling functions instantly.
--I'm setting a value for update to decide if they need called.
--That value is then made false by the function itself.
--This is to cut down on the amount of instructions per run of update()
local ancientPlatforms_update = update

function extraInit()
  storage.connectedPos = storage.connectedPos or {}
  storage.connectedIDs = storage.connectedIDs or {}
  
  storage.touchPoints = {
    west = { cMath.add(storage.corners.lowerRight, {1, 0}), cMath.add(storage.corners.upperRight, {1, 0}) },
    east = { cMath.add(storage.corners.lowerLeft, {-1, 0}), cMath.add(storage.corners.upperLeft, {-1, 0}) }
  }
  
  storage.objectSize = cMath.size(storage.corners.upperLeft, storage.corners.lowerRight)
  storage.matchScan = {
    cMath.sub(storage.corners.lowerLeft, storage.objectSize),
    cMath.add(storage.corners.upperRight, storage.objectSize)
    }
  
  local dump = makeString(storage, "storage", "\nafter defining storage.matchSize\n")
  --sb.logInfo(dump)
  
  if ((#storage.connectedIDs) < 1) then
    --local tableHolder = cMath.encircle(storage.doorPosition, storage.objectSize)
    --local tableHolder = cMath.encircle(storage.center, storage.objectSize)
    
    --storage.touchPoints = storage.touchPoints or { tableHolder[3], tableHolder[7]} 
      --for now only considering point directly to the east and to the west so disreguarding all other results
        --but may later add slanted profiles, etc
    --findMatch()
    self.do_findMatch = true
    self.do_objectPos_update = false
  else
    self.do_findMatch = false
    self.do_objectPos_update = true
  end
  self.matchTimer = math.random(1, 20) / 100
    --intention is that not all platforms will attempt to connect at the same time.

  message.setHandler("connect", function(entityID, external) connect(entityID, external) end)
  message.setHandler("disconnect", function(entityID, external) disconnect(entityID, external) end)
  message.setHandler("sameObject", function(objectName) sameObject(objectName) end)
  objectPos_update()
end


function update(dt) --called at the end of update()
  if self.matchTimer > 0 then
    self.matchTimer = self.matchTimer - dt
    ancientPlatforms_update(dt)
  elseif self.do_findMatch then
    findMatch()
  elseif self.do_objectPos_update then
    objectPos_update()
  else
    ancientPlatforms_update(dt)
    update = function(dt) --yes this function will slim itself at that point
    ----(
      if self.do_objectPos_update then
        objectPos_update()
      else
        ancientPlatforms_update(dt)
      end
    end
    ----)
  end
end


function findMatch()
  if (#storage.connectedIDs > 0) then
    self.do_findMatch = false
    return
  end

  storage.connectedIDs = {}
  storage.connectedPos = {}
  local matchTable = {}
  local obj = {}
  local pos = storage.doorPosition or object.position()
  for direction, point in pairs(storage.touchPoints) do
    --world.objectAt(pos)
    --mObjects[k] = world.callScriptedEntity("sameObject", storage.objectName)
    obj = world.objectQuery(storage.matchScan[1], storage.matchScan[2],
    --obj = world.objectQuery(point[1], point[2],
      {
        callScript = "sameObject",
        callScriptArgs = {storage.objectName, point},
        withoutEntityId = entity.id(),
        boundMode = "metaboundbox"
        --boundMode = "position"
      })
    if (#obj > 0) then
      matchTable[#matchTable + 1] = obj[1]
      storage.connectedPos[direction] = true
    elseif (#obj > 1) then
      local dump = L.makeString(obj, "obj", "\nunexpected multiple returns from world.objectQuery")
      sb.logInfo(dump)
    end

  end

  for _, matchID in ipairs(matchTable) do
    connect(matchID, false)
  end

  self.do_findMatch = false
end


function sameObject(objectName, point)
  return storage.objectName == objectName and doorOccupies_everySpace(point)
end


function connect(entityID, external)
  sb.logInfo("\n\nancientPlatform connect start\nexternal : ".. tostring(external).."\nMy entityID : " .. tostring(entity.id()) .."\nConnecting to entityID : " .. tostring(entityID))
  local index = #storage.connectedIDs + 1
  storage.connectedIDs[index] = entityID
  --storage.connectedPos[index] = world.entityPosition(entityID)

  if not external then
    world.callScriptedEntity(entityID, "connect", entity.id(), true)
  end

  self.do_objectPos_update = true
  sb.logInfo("\n\nancientPlatform connect end\n\n")
end


function disconnect(entityID, external)
  sb.logInfo("\n\nancientPlatform disconnect start for entity " .. tostring(entity.id()) .. "\nfunction recieved\n entityID: ".. tostring(entityID) .. "\nexternal: " .. tostring(external) .. "\n\n" )
  local valid = world.entityExists(entityID)
    
  if not external and valid then
    world.callScriptedEntity(entityID, "disconnect", entity.id(), true)
  end
  
  local _comment = [[storage.connectedIDs = removeValue_fromList(storage.connectedIDs, entityID)
  if valid then
    local loc = world.entityPosition(entityID)
    --storage.connectedPos = removeValue_fromList(storage.connectedPos, loc)
    sb.logInfo("\n\nancientPlatform disconnect end successful for entity " .. tostring(entity.id()) .. "\n\n")
  else
    sb.logInfo("\n\nancientPlatform disconnect failed because entityID "  .. tostring(entityID) .. " never matched any entry in storage.connectedIDs.\nOwn ID is " .. object.id() .."\n\n")
    local index
    for k,v in ipairs(storage.connectedIDs) do
      if (v == entityID) then
        index = k
        break
      end
    end
    --storage.connectedPos = removeKey_fromList(storage.connectedPos, index)
  end
  ]]
  
  findMatch()
  self.do_objectPos_update = true
end


function die()
  for _, entity in ipairs(storage.connectedIDs) do
    if world.entityExists(entity) then
      world.callScriptedEntity(entity, "disconnect", entity.id(), true)
    end
  end
end


function objectPos_update()
  --this will change plenty if I include more connection profiles... which I probably will
  local _c1 = [[
  local directions = {}
  local doorPosition
  local objectToEast = false
  local objectToWest = false
    
  for i, pos in ipairs(storage.connectedPos) do
    directions[i] = cMath.coDirection(storage.doorPosition, pos)
    if (directions[i] == "E") then
      objectToEast = true
    elseif (directions[i] == "W") then
      objectToWest = true
    else
      local e, r = cMath.coDirection(storage.doorPosition, pos)
      sb.logInfo("This shouldn't happen\n for entityID : " .. tostring(entityID) .. "during objectPosUpdate directions[i] was ".. directions[i] .."\n" .. tostring(e[1]) .. ", " .. tostring(e[2]))
    end
  end
  ]]
  
  local c2 = [[
  if storage.connectedPos["west"] and storage.connectedPos["east"] then
    doorPosition = "posC"   --This is a center
  elseif storage.connectedPos["east"] then
    doorPosition = "posW"   --This is a western piece
  elseif storage.connectedPos["west"] then
    doorPosition = "posE"   --This is a eastern piece
  else
    doorPosition = "posA"   --This is a stand alone piece
  end
  ]]
  
  doorPositions = "posC"

  animator.setGlobalTag("doorPos", doorPosition)
  updateAnimation(storage.state)
  self.do_objectPos_update = false
end


function removeValue_fromList(t, purge)
  local retTable = {}
  local offset = 0
  for k, v in ipairs(t) do
    if v == purge then
      offet = offset + 1
    else
      retTable[k - offset] = v
    end
  end  
  return retTable, offset   --return the table, and how many elements removed
end

function removeKey_fromList(t, key)
  local retTable = {}
  local offset = 0
  for k, v in ipairs(t) do
    if k == key then
      offet = offset + 1
    else
      retTable[k - offset] = v
    end
  end  
  return retTable
end