--doing something a little different here.  In many cases I'm not calling functions instantly.
--I'm setting a value for update to decide if they need called.
--That value is then made false by the function itself.
--This is to cut down on the amount of instructions per run of update()
local ancientPlatforms_update = update
local objectPos_update


function extraInit()
  objectPos_update()
  updateAnimation(false)
end


function update(dt) --called at the end of update()
  if storage.state then
    objectPos_update()
  end
  ancientPlatforms_update(dt)
  
end


objectPos_update = function()
  --this will change plenty if I include more connection profiles... which I probably will
  local doorPosition = "posC"
  local offset = {1, 0}
  local objectToEast, objectToWest, westCheck, eastCheck
    
  westCheck = cMath.add(storage.corners.upperRight, offset )
  eastCheck = cMath.sub(storage.corners.upperLeft, offset )
  
  objectToEast = string.find(world.material(eastCheck, "foreground") or "null", "metamaterial")
  objectToWest = string.find(world.material(westCheck, "foreground") or "null", "metamaterial")
      
  if objectToEast and objectToWest then
    doorPosition = "posC"   --This is a center
  elseif objectToEast then
    doorPosition = "posW"   --This is a western piece
  elseif objectToWest then
    doorPosition = "posE"   --This is a eastern piece
  else
    doorPosition = "posA"   --This is a stand alone piece
  end
    
  if storage.previous_doorPosition ~= doorPosition then
    storage.previous_doorPosition = doorPosition
    animator.setGlobalTag("doorPos", doorPosition)
    animator.setAnimationState("doorState", "open", true)
  else
    animator.setAnimationState("doorState", "open", false)
  end
  self.do_objectPos_update = false
end