-- automatic doors 4.2
-- basic code by Chucklefish, additional code by lornlynx (with some help from Healthire), greatly reworked and updated by bk3k
    --well at this point not much Chucklefish code remains, but it got us started and provided a good reference.

require("/scripts/bk3k/bk3k-cMath2d(0.21).lua")
require("/scripts/bk3k/bk3kLogger(0.2).lua")

local initMessage
local initPackages
local initIncludedTypes
local initDoorStuff
local noAutomatic
local doorException
--local updateMaterialSpaces
local updateCollisionAndWires
local updateInteractive
--local updateAnimation
local updateLight
local secureControl
local onInputMultiNodeChange
local anyInputNodeConnected
--local initMaterialSpaces
--local buildMaterialSpaces
--local setMaterialSpaces
local setDirection
local hasCapability
local doorOccupiesSpace
local doorOccupies_everySpace
local lockDoor
local unlockDoor
local realCloseDoor
local closeDoor
local openDoor
local realOpenDoor
local scan
local autoOpen
local autoClose
local setDirectionNPC
--local makeString

extraFunction = function() end  --blank function called by update.  If more features needed for specialty purposes
                                  --overwrite/replace with an actual function
                                  --just put this script sooner on the list
extraInit = function() end


init = function()
  --toDo: unlock requirements(obviously optional)
  --can use universe flags and/or world properties
  --thus you have have doors unlock after quests in remote locations


  --self.doDebug = false or config.getParameter("debugObject", false)
  --change to false for release versions!  Or you'll have HUGE logs!
  initMessage()
  storage.id = entity.id()
  storage.doorPosition = object.position()
  initPackages()

  if not storage.quickCheck then
    storage.spaces = object.spaces()
    storage.quickCheck = initDoorStuff()
    --L.dump(L.dumpTable, L.context)

    storage.objectName = config.getParameter("objectName", "door")

   --boolean values
    storage.postInit = false
    storage.defaultLocked = config.getParameter("defaultlocked", false)
    storage.locked = ( storage.defaultLocked or config.getParameter("locked", false) )
    storage.defaultInteractive =  config.getParameter("interactive", true)
    --storage.wireOpened = false
    --storage.wireControlled = object.isInputNodeConnected(0)
    storage.state = storage.state or ((config.getParameter("defaultState", "closed") == "open") and not storage.locked)
    storage.playerOpened = false
    storage.playerClosed = false
    storage.doorException = doorException()  --check if door is part of exception list
    storage.noAuto = noAutomatic()
    storage.noNPCuse = config.getParameter("noNPCuse", false)
      --this is for doors that NPCs must never be allowed to open
        --special case use such as not really a "door" in the traditional sense
        --sort of thing which would be triggered by missions/AI/etc.


    --numeric values
    storage.maxInputNode = ( #(config.getParameter("inputNodes", {})) - 1 )
    storage.maxOutputNode = ( #(config.getParameter("outputNodes", {})) - 1 )
    --standard LUA tables start at 1 instead of 0.  Starbound assignes the first node to 0 despite this.

    storage.out0 = (storage.maxOutputNode > -1)
    storage.out1 = (storage.maxOutputNode > 0)


    --string values
    storage.openingAnimation_stateName = config.getParameter("openingAnimation", "open")
    --if doors have an opening animation cycle and frames seperate from the "open" state
      --my doors use "opening"
    storage.lockingAnimation_stateName = config.getParameter("lockingAnimation", "closed")
    --if they have an actual locked animation and frames, use instead of "closed" when locked
      --my doors use "locked"
    storage.lockedAnimation_stateName = config.getParameter("lockedAnimation", "closed")
    storage.boundVar = config.getParameter("detectBoundMode", "CollisionArea")


    --table values
    storage.lightColors = storage.lightColors or {
      config.getParameter("openLight", {0,0,0,0}),
      config.getParameter("closedLight", {0,0,0,0})
      }

    storage.proximityOut = false
    storage.interactAction = config.getParameter("interactAction")
    storage.interactData = config.getParameter("interactData")
  end


  self.closeCooldown = 0
  self.openCooldown = 0
  self.npcClosed = false

  anyInputNodeConnected()
  setDirection(storage.doorDirection or object.direction())
  initMaterialSpaces()
  --L.dump(L.dumpTable, {"After calling initMaterialSpaces"})
  updateCollisionAndWires()
  --called only in init(), will call updateMaterialSpaces() after completion


  if storage.state and not (storage.locked or storage.wireControlled or storage.wireOpened) then
    realOpenDoor(storage.doorDirection)
  elseif storage.locked then
    lockDoor()
  else
    onInputMultiNodeChange()
    updateAnimation(not storage.state)
  end

  updateInteractive()
  initIncludedTypes() --things we'll regularily scan for

  
  
  --L.context[1] = "End of "
  --L.dump(L.dumpTable, L.context)
  storage.postInit = true
  extraInit()
  
  --local dump = makeString(storage, "storage", "\n")
  --sb.logInfo(dump)
end


initMessage = function()
  message.setHandler("openDoor", function() openDoor() end)   --vanilla NPCs use
  message.setHandler("lockDoor", function() lockDoor() end)   --vanilla NPCs use
  message.setHandler("closeDoor", function() closeDoor() end)
  message.setHandler("unlockDoor", function() unlockDoor() end)
  message.setHandler("auto", function() storage.noAuto = false end)
  message.setHandler("noAuto", function() storage.noAuto = true end)
  message.setHandler("stored_parameters", function() return storage end)
  --this may get far bigger which is why I moved it to its own function
  --eventually there should be a way to change the behavior of doors from a console etc
    --this is probably the mechanism
  
end


initPackages = function()  --added
  cMath = {}
  setmetatable(cMath, { __index = _ENV["bk3kcMath2d0.21"] })
  L = {}
  local comment1 = [[
  if self.doDebug then --this avoids the need to comment out a million items every time we're ready to release
    --setmetatable (L, {__index =_ENV.bk3kLogger})
    L = _ENV.bk3kLogger
    L.context = {"Beginning of ", "init()", " for object: ", tostring(storage.id), " at location ", cMath.cString(storage.doorPosition), " - " }
      --[1], [2] is mostly all I'd want to swap
    L.dumpTable = {storage = storage, self = self}    --setmetatable(L.dumpTable.storage, { __index = _ENV.storage })  --adds an index named 'storage' to L.dumpTable
    --setmetatable(L.dumpTable.self, { __index = _ENV.self })      --adds an index named 'self' to L.dumpTable
      --you COULD just do L.dump({storage, self}, L.context) but
      --L.dump(L.dumpTable, L.context) preserves the table names in the logs.
  else
    --setmetatable (L, {__index =_ENV.bk3kLogger.blankPackage()})
    L = _ENV.bk3kLogger.blankPackage()
      --nothing but empty tables/values and functions as such would not cause errors when called
  end
  ]]

end


initIncludedTypes = function()  --added
  storage.scanTargets = storage.scanTargets or config.getParameter("scanTargets", {"player", "vehicle"})
  if not (#storage.scanTargets > 0) or not (type(storage.scanTargets) == "table") then
    storage.scanTargets = {"player", "vehicle"}
  end
end


initDoorStuff = function()  --added
  --replaces a disorganized cluster of other functions
  --should make the flow of the code easier to parse and be slightly more efficient

  storage.queryRadius = config.getParameter("queryOpenRadius", 5)
    --this value may get overwritten later because scans start from center, so radius can't be less than half
    --else it can't detect across whole door if the door is rather large

  storage.realSpaces = {}
  local clamp = cMath.floor(storage.doorPosition)
  for k, v in ipairs(storage.spaces) do
    storage.realSpaces[k] = cMath.add(v, clamp)
  end

  local highX = cMath.highX(storage.realSpaces)
  local lowX = cMath.lowX(storage.realSpaces)
  local highY = cMath.highY(storage.realSpaces)
  local lowY = cMath.lowY(storage.realSpaces)

  storage.corners = {
    upperRight = {highX, highY},
    lowerRight = {highX, lowY},
    upperLeft = {lowX, highY},
    lowerLeft = {lowX, lowY}
  } --may not represent actual corners, but outer dimensions in oddly shaped objects
                        --a fact we could easily determine at this point by feeding each "corner" to doorOccupiesSpace()
                        --if we needed to know it

  storage.center =  {
    (highX + lowX) / 2,
    (highY + lowY) / 2
  }

  local xDist = highX - lowX
  local yDist = highY - lowY
  local hD = config.getParameter("horizontal_door", nil)  --this can override the detected value

  if hD or ((xDist > yDist) and (hD ~= false)) then --may look redundant, but it isn't
    if (storage.queryRadius < (xDist / 2)) then
      storage.queryRadius = xDist / 2
    end
    if not config.getParameter("platformDoors", false) then  --if set then the radius is the true center
      storage.queryCenter = cMath.subY(storage.center, {_, storage.queryRadius})
    else
      storage.queryCenter = storage.center
    end
    --L.dump({storage.queryCenter}, {"after door was determined to be horizontal"})
    storage.isHorizontal = true
  else
    if (storage.queryRadius < (yDist / 2)) then
      storage.queryRadius = yDist / 2
    end
    storage.queryCenter = storage.center
    --L.dump({storage.queryCenter}, {"after door was determined to not be horizontal"})
    storage.isHorizontal = false
  end

  storage.scanBox = config.getParameter("scanBox", nil)
  if storage.scanBox then
    --at this point storage.scanBox would have 2 relative positions represending bound corners
    --and we're going to swap that for real positions
    storage.scanBox[1] = cMath.add(storage.scanBox[1], storage.center)
    storage.scanBox[2] = cMath.add(storage.scanBox[2], storage.center)

  end

  return true
    --always return true to set storage.quickCheck and if set this function shouldn't run at all
    --in the event that all the storage variables remain set it would just be a waste of CPU cycles.
end


noAutomatic = function() --added, called by init()
  return (storage.doorException or storage.defaultLocked or config.getParameter("noAutomaticDoors", false))
end


doorException = function() --added, called by noAutomatic()
  --I'd prefer to load this from JSON, but don't know that Starbound would allow access beyond current object
  --so manual table loading it is!  This seems more managable in case more exceptions get added.
  local doorTable = {
    castlehiddentrapdoor = true,
    castlehiddendoor = true,
    templehiddentrapdoor = true,
    pilch_horizdoor = true,
    dirttrapdoor = true,
    stonedoor = true,
    ancientlightplatform = true,
    ancienthiddenplatform = true,
    templepressureplatform = true
  }
  
  return doorTable[storage.objectName] or false

end


-----------pure initialization above, mostly actions below

onNodeConnectionChange = function(args)
  local wasControlled = storage.wireControlled
  anyInputNodeConnected()
  updateInteractive()
  onInputMultiNodeChange()
  updateCollisionAndWires()

  if (storage.wireControlled ~= wasControlled) then
    updateAnimation(storage.state)
  end

end


anyInputNodeConnected = function() --called from init() and onNodeConnectionChange()
  storage.anyInputNodeConnected = false
  local n = 0
  while (n <= storage.maxInputNode) do
    if object.isInputNodeConnected(n) then
      storage.anyInputNodeConnected = true
      break
    end
    n = n + 1
  end

  if (storage.maxInputNode >= 0) then
    storage.wireControlled = object.isInputNodeConnected(0)
  else
    storage.wireControlled = false
  end
  if storage.out0 then
    storage.noAutoClose = object.isOutputNodeConnected(0)  --output not input!
    if storage.out1 then
      storage.proximityOut = object.isOutputNodeConnected(1)
    end
  else
    storage.noAutoClose = false
  end
end


onInputNodeChange = function(args)  --modified
-- @tab args Map of:
--    {
--      node = <(int) index of the node that is changing>
--      level = <new level of the node>
--    }
  if (storage.maxInputNode > 0) then
    --delegate to another function
    onInputMultiNodeChange(args)
    return
  end

  if args.level then
    storage.wireOpened = true
    realOpenDoor(storage.doorDirection)
  else
    storage.wireOpened = false
    realCloseDoor()
    --trying this out
    animator.setAnimationState("doorState", storage.lockingAnimation_stateName)
  end
end


onInputMultiNodeChange = function(args) --added

  if storage.defaultLocked then
    --delegate to another function
    secureControl()
    return
  end

  local wasOpen = storage.state
  storage.wireOpened = false
  local n = 0
  while (n <= storage.maxInputNode) do
    if object.getInputNodeLevel(n) then
      storage.wireOpened = true
      break  --no need to continue if found any active wire
    end
    n = n + 1
  end

  if storage.wireOpened then
    if not storage.state then
      realOpenDoor(storage.doorDirection)
    end
  elseif storage.anyInputNodeConnected then
    realCloseDoor()
  end
end


secureControl = function()  --added, probably will be replaced by better implimentation later
  --this requires multiple inputs to open, else lock
  if object.getInputNodeLevel(0) and object.getInputNodeLevel(1) then
    unlockDoor()
    realOpenDoor(storage.doorDirection)
  else
    lockDoor()
  end
  --I may expand this later to demand wire inputs that conform to a pattern.  Such as having 8 input nodes,
  --and only opening when only the correct nodes are activated at once, perhaps in sequence!
  --For now think of this as a built-in AND switch
end


onInteraction = function(args)
  if storage.locked or storage.wireControlled then
    if storage.interactAction then
      return {storage.interactAction, storage.interactData}
    else
      animator.playSound("locked")
      return
    end
  end

  --because storage.state will soon flip value
  storage.playerClosed = storage.state
  storage.playerOpened = not storage.state

  if not storage.state then
    if storage.isHorizontal then
      -- give the door a cooldown before closing again
      realOpenDoor(args.source[2])
      self.closeCooldown = 2  --increased cooldown
    else
      realOpenDoor(args.source[1])
      self.closeCooldown = 0
    end
  else
    realCloseDoor()
  end

end


updateLight = function()
  if storage.state then
    object.setLightColor(storage.lightColors[1])
  else
    object.setLightColor(storage.lightColors[2])
  end
end


updateAnimation = function(wasOpen)
  local aState = ""

  if (storage.state ~= wasOpen) then
    if storage.state then --door opening
      aState = storage.openingAnimation_stateName
      animator.playSound("open")
    else  --door closing/locking
      if storage.locked or storage.wireControlled then
        aState = storage.lockingAnimation_stateName
      else
        aState = "closing" --already vanilla supported transition state
      end
      animator.playSound("close")
    end
  else --door is not opening nor closing
    if storage.state then
      aState = "open"
    elseif storage.locked or storage.wireControlled then
      aState = storage.lockedAnimation_stateName
    else
      aState = "closed"
    end
  end

  animator.setAnimationState("doorState", aState)
end


updateInteractive = function()
  local interacive = (storage.defaultInteractive and not (storage.wireControlled or storage.defaultLocked or storage.locked)) or storage.interactAction ~= nil
  
  object.setInteractive(interacive)
end


updateCollisionAndWires = function()
  updateMaterialSpaces()
  if storage.state then
    object.setMaterialSpaces(storage.openMaterialSpaces)
  else
    object.setMaterialSpaces(storage.closedMaterialSpaces)
  end

  if storage.out0 then
    object.setOutputNodeLevel(0, storage.state)
  end
end


updateMaterialSpaces = function() -- added
  if storage.closedMatSpacesDefined then
    return
  elseif storage.wireControlled then
    storage.closedMaterialSpaces = storage.matTableClosed[2] --"metamaterial:lockedDoor"
  else
    storage.closedMaterialSpaces = storage.matTableClosed[1] --"metamaterial:door"
  end
end


initMaterialSpaces = function(metaMatC, metaMatO)  --added
  --forget the vanilla idea of reading attributes and rebuilding tables every time
  --lets just build and store full material tables at init() time
  --and switch between them as needed with updateMaterialSpaces()

  storage.openMaterialSpaces = config.getParameter("openMaterialSpaces", {})
  storage.closedMaterialSpaces = config.getParameter("closedMaterialSpaces", {})
  storage.closedMatSpacesDefined = ( (#storage.closedMaterialSpaces) > 0 )
  storage.matTableClosed = storage.matTableClosed or { {}, {} }
  storage.matTableOpen = storage.matTableOpen or { {}, {} }

  if not storage.closedMatSpacesDefined then
    metaMatC = metaMatC or config.getParameter("closedMaterials", {"metamaterial:door", "metamaterial:lockedDoor"})
      --^^these are just lists of available metaMaterials per state
    local j = 1
    local count = #metaMatC

    while (j <= count) do
    storage.matTableClosed[j] = buildMaterialSpaces(storage.spaces, metaMatC[j])
      --for _, space in ipairs(storage.spaces) do
        --table.insert(storage.matTableClosed[j], {space, metaMatC[j]})
      --end
      j = j + 1
    end
  else
     storage.matTableClosed[1] = storage.closedMaterialSpaces
     storage.matTableClosed[2] = storage.closedMaterialSpaces
  end
  
  if not (#storage.openMaterialSpaces > 0) then
    local j = 1
    metaMatO = metaMatO or config.getParameter("openMaterials", {})
    local count = #metaMatO
    if (count > 0) then --openMaterialSpaces won't be redefined if no defined mats
      while (j <= count) do
        for _, space in ipairs(storage.spaces) do
          storage.matTableOpen[j] = buildMaterialSpaces(storage.spaces, metaMato[j])
        end
        j = j + 1
      end
    end
    table.insert(storage.matTableOpen, { } )
      --add an extra blank table element at the end for when clearing is desirable
    storage.openMaterialSpaces = storage.matTableOpen[1]
  else  
    storage.matTableOpen[1] = storage.openMaterialSpaces
  end
end


buildMaterialSpaces = function(spaces, material)
  local retTable = {}
  for i, space in ipairs(spaces) do
    retTable[i] = {space, material}
  end
  return retTable
end


setMaterialSpaces = function(whatState, whatMaterialTableIndex) --added
  --most doors won't need this and probably only gets called externally through messenging system only by entities
  --which understand the specific door and thus what materials are available at what index

  if (whatState == "open") then
    storage.openMaterialSpaces = storage.matTableOpen[i]
  elseif (whatState == "closed") then
    storage.closedMaterialSpaces = storage.matTableClosed[i]
  end
end


setDirection = function(direction)  --one of the few NOT changed!
  storage.doorDirection = direction
  animator.setGlobalTag("doorDirection", direction < 0 and "Left" or "Right")
end


hasCapability = function(capability)
  --this is called by
  --scripts/actions/movement.lua
  --scripts/pathing.lua
  if capability == "automaticDoor" then
    return not (storage.noAuto or object.isInputNodeConnected(0))
  elseif capability == "objectInterfacing" then
    return config.getParameter("objectInterfacing", false)
    --note that Automatic Doors will NOT be handling this sort of thing.  A seperate script will.
    --This will only inform other mod objects of these capabilities.
  elseif storage.noNPCuse then
    return false
  elseif capability == 'lockedDoor' then
    return storage.locked
  elseif storage.wireControlled or storage.wireOpened or storage.locked then
    return false
  elseif capability == 'door' then
    return true
  elseif capability == 'closedDoor' then
    return not storage.state
  elseif capability == 'openDoor' then
    return storage.state
  else
    return false
  end
end


doorOccupiesSpace = function(position)
  --used by objects/spawner/colonydeed/scanner.lua and called quite often
  --altered implimentation avoids needlessly repeating the same calculations countless times
  local clamp = cMath.floor(position)

  for _, space in ipairs(storage.realSpaces) do
    if cMath.match(clamp, space) then
      return true
    end
  end
  return false
end


doorOccupies_everySpace = function(positions)
  for _, position in ipairs(positions) do
    if not doorOccupiesSpace(position) then
      return false
    end
  end
  return true
end


lockDoor = function()
  if storage.noNPCuse then  --special use
    return false
  end

  --going to try this and make sure it doesn't break any missions!  Don't "think" it will if called postInit()
  --doing this to potentially cut off stupid NPC behavior at outpost etc
    --(locking wired doors that should be opened by proximity sensors etc)

  if storage.postInit and object.isOutputNodeConnected(0) then
    --no "locking" wire controlled doors.
    onInputMultiNodeChange()
    return
  end

  --below code is fine
  local wasOpen = storage.state
  if (not storage.locked) and (self.closeCooldown <= 0) then

    storage.locked = true

    if storage.state then
      storage.state = false
    else
      --no need to close door etc, just change animation state
    end
  end
  updateCollisionAndWires()
  updateAnimation(wasOpen)
  updateLight()

end


unlockDoor = function()
  local wasOpen = storage.state
  storage.locked = false
  updateInteractive()
  updateAnimation(wasOpen)
  return true --don't know why, but vanilla does this return
end


realCloseDoor = function()
  -- only close door when cooldown is zero
  --if storage.state and (self.closeCooldown <= 0) then
  local wasOpen = storage.state
  storage.state = false
  updateCollisionAndWires()
  updateAnimation(wasOpen)
  updateLight()
  -- world.debugText("Close!", object.position(), "red")
end


closeDoor = function()
  --all internal functions will use realCloseDoor()
  --see openDoor() for why
if storage.wireControlled then return end
  self.npcClosed = true
  self.openCooldown = 2
  realCloseDoor()
end


openDoor = function(direction)
  --all internal functions will use realOpenDoor()
  --therefore if this is called, we know it is externally sourced and can take extra measures

  unlockDoor()
  self.closeCooldown = 2
  if (direction == nil) then
    setDirectionNPC()
  end
  realOpenDoor(direction)
end


realOpenDoor = function(direction)
  local wasOpen = storage.state
  if not storage.state then
    storage.state = true
    setDirection((direction == nil or direction * object.direction() < 0) and -1 or 1)
  end

  updateCollisionAndWires()
  updateAnimation(wasOpen)
  updateLight()
  -- world.debugText("Open!", object.position(), "red")
end


scan = function(incl, excl)
  --incl should be a table of strings
  --excl should in most cases be storage.id which is just a stored return from object.id()
  local results
  local didFind

  if storage.scanBox then
    results = world.entityQuery(storage.scanBox[1],
      storage.scanBox[2], {
        withoutEntityId = excl,
        includedTypes = incl,
        boundMode = storage.boundVar
        })
  else
    results = world.entityQuery(storage.queryCenter,
      storage.queryRadius, {
        withoutEntityId = excl,
        includedTypes = incl,
        boundMode = storage.boundVar
        })
  end

  didFind = (#results > 0)

  if storage.proximityOut then
    if (self.previousFound ~= didFind) then
      --this check prevents attempting updating the node state when the node didn't actually change!
      object.setOutputNodeLevel(1, didFind)
    end
    self.previousFound = didFind
  end
    --if the door has output node(1) that's currently wired, then output if any scan target found
      --as defined by "scanTargets" or defaults to {"player", "vehicle"}
    --this is regardless of the actual door being open or closed

  return results, didFind
end


-- Main function, is running constantly with delta t time interval, functions esentially like an infinite while loop
--
update = function(dt)
  local objectIdsOpen
  local targetsFound

  -- lowers cooldown with each cycle
  if self.closeCooldown > 0 then
    self.closeCooldown = self.closeCooldown - dt
  end
  if self.openCooldown > 0 then
    self.openCooldown = self.openCooldown - dt
  end

  --everything remaining is used to make doors automatic, and therefore should be skipped
  --when automatic functionality is undesirable.  No automatic when wired to input 1, opened by wire,
  --don't need automatic functionality when door opened from ANY wire input or locked
  if storage.noAuto or (storage.wireControlled and not self.npcClosed) or storage.locked then
    if storage.proximityOut then
      scan(storage.scanTargets, storage.id)
      --calling scan even though doors aren't automatic, disreguarding results so that wire node(1) gets updated
    end
    return
  elseif self.npcClosed and storage.wireControlled and (self.openCooldown <= 0) then
    --onInputNodeChange()
    setDirectionNPC()
    onInputMultiNodeChange()  --should open the door if still approriate per wire input at that point
    self.closeCooldown = 0.05
    self.openCooldown = 0.05
    self.npcClosed = false
    if storage.proximityOut then
      scan(storage.scanTargets, storage.id)
    end
    return
  end

  objectIdsOpen, targetsFound = scan(storage.scanTargets, storage.id)

  if targetsFound then
    autoOpen(objectIdsOpen)
  else
    -- resetting toggle once player gets out of range
    storage.playerClosed = false
    if not storage.noAutoClose then
      --found some doors in missions with only wired outputs!
      --this will prevent doors with wired outputNode(0) from autoClosing when player opened
      storage.playerOpened = false
    end

    autoClose()
  end

  extraFunction() --by default this is a blank function
end


autoOpen = function(objectIdsOpen)
  if storage.playerClosed or storage.state or (self.openCooldown > 0) then
    return
  end
  -- query for player at door proximity
  local playerPosition = world.entityPosition(objectIdsOpen[1])
  -- sb.loginfo("Player detected!")
  -- open door in direction depending on position of the player

  storage.playerOpened = false

  if not storage.isHorizontal then
    realOpenDoor( cMath.xTravel(storage.doorPosition, playerPosition) )
	  -- sb.loginfo("direction: %d", playerPosition[1] - object.position()[1])
  else
    realOpenDoor( cMath.yTravel(storage.doorPosition, playerPosition) )
    self.closeCooldown = 2
    --added a small timer
    -- sb.loginfo("direction: %d", playerPosition[1] - object.position()[1])
  end
end


autoClose = function()
  if (self.closeCooldown > 0) or not storage.state or storage.playerOpened or storage.wireOpened then
    return
  end
  local npcIds --disable for NPC's, close when opened by player
  local foundNPC


  local npcIds, foundNPC = scan({"NPC"}, storage.id)
  -- check for NPCs in a smaller radius

    -- prevents door spasming
  if foundNPC and not storage.isHorizontal then
    return
  end


  realCloseDoor()
  storage.playerClosed = false
end


setDirectionNPC = function()
  --special case function corrects direction if NPC opened door or will be nearest when opening
  local ncpIds
  local foundNPC
  npcIds, foundNPC = scan({"NPC"}, storage.id)
  if not foundNPC then
    return  --in theory an NPC may move before this is called
  end
  local npcPosition = world.entityPosition(npcIds[1])

  if not storage.isHorizontal then
    setDirection( cMath.xTravel(storage.doorPosition, npcPosition) )
  else
    setDirection( cMath.yTravel(storage.doorPosition, npcPosition) )
  end
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